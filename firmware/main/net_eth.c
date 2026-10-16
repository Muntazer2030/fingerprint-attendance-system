/* ENC28J60 Ethernet bring-up.
 *
 * ENC28J60 quirks that drive the setup below:
 *   - No on-chip MAC address, so one must be assigned explicitly.
 *   - No auto-negotiation; duplex has to be forced.
 *   - Silicon errata make SPI clocks below 8 MHz unreliable.
 *   - CS hold time must be calculated from the chosen clock.
 */

#include <string.h>
#include "net_eth.h"
#include "board.h"
#include "esp_log.h"
#include "esp_mac.h"
#include "esp_eth.h"
#include "esp_eth_enc28j60.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "driver/spi_master.h"
#include "driver/gpio.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"
#include "ping/ping_sock.h"

static const char *TAG = "eth";

static void hard_reset_chip(void);
static void start_watchdog(void);
static void start_dhcp_fallback_timer(void);

#define ENC28J60_SPI_CLOCK_MHZ 8

static esp_netif_t *s_eth_netif;
static bool s_got_ip;
static bool s_link_up;
static bool s_static;
static esp_eth_handle_t s_eth;
static uint32_t s_resets;
static int64_t s_start_us;
static char s_ip[16] = "0.0.0.0";

/* The static fallback address is a guess: it only works when the cable goes
 * to a PC sharing its connection on 192.168.137.x. Until the gateway answers
 * on it, it does not count as being online. */
static bool s_gw_seen;
static int64_t s_static_since_us;
static esp_timer_handle_t s_fallback_timer;

/* Ask DHCP again this long after falling back, while nothing answers. */
#define DHCP_RETRY_US (60LL * 1000000)

static void on_eth_event(void *arg, esp_event_base_t base, int32_t id, void *data)
{
    uint8_t mac[6];
    esp_eth_handle_t eth = *(esp_eth_handle_t *)data;

    switch (id) {
    case ETHERNET_EVENT_CONNECTED:
        esp_eth_ioctl(eth, ETH_CMD_G_MAC_ADDR, mac);
        s_link_up = true;
        ESP_LOGI(TAG, "link up, mac %02x:%02x:%02x:%02x:%02x:%02x",
                 mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
        /* The fallback is only decided with a cable in, so the clock starts
         * now -- not at boot, when the cable may not have been there yet. */
        if (!s_got_ip) {
            start_dhcp_fallback_timer();
        }
        break;
    case ETHERNET_EVENT_DISCONNECTED:
        ESP_LOGW(TAG, "link down");
        s_link_up = false;
        s_got_ip = false;
        strcpy(s_ip, "0.0.0.0");
        break;
    case ETHERNET_EVENT_START:
        ESP_LOGI(TAG, "driver started");
        break;
    case ETHERNET_EVENT_STOP:
        ESP_LOGI(TAG, "driver stopped");
        break;
    default:
        break;
    }
}

static void on_got_ip(void *arg, esp_event_base_t base, int32_t id, void *data)
{
    const ip_event_got_ip_t *ev = (const ip_event_got_ip_t *)data;
    const esp_netif_ip_info_t *ip = &ev->ip_info;

    snprintf(s_ip, sizeof(s_ip), IPSTR, IP2STR(&ip->ip));
    s_got_ip = true;
    ESP_LOGI(TAG, "%s: ip=%s mask=" IPSTR " gw=" IPSTR,
             s_static ? "static fallback" : "dhcp lease",
             s_ip, IP2STR(&ip->netmask), IP2STR(&ip->gw));
}

/* DHCP is not guaranteed. A terminal that silently drops off the network
 * because the router's DHCP server hiccuped is a site visit, so self-assign a
 * known address instead and keep serving. */
static void dhcp_fallback_cb(void *arg)
{
    if (s_got_ip || !s_eth_netif) {
        return;
    }
    /* No cable, no point: assigning an address here used to make an unplugged
     * terminal look online. The link-up event re-arms this timer. */
    if (!s_link_up) {
        return;
    }

    esp_netif_ip_info_t ip = {0};
    if (esp_netif_str_to_ip4(CONFIG_ATT_NET_STATIC_IP, &ip.ip) != ESP_OK ||
        esp_netif_str_to_ip4(CONFIG_ATT_NET_STATIC_NETMASK, &ip.netmask) != ESP_OK ||
        esp_netif_str_to_ip4(CONFIG_ATT_NET_STATIC_GW, &ip.gw) != ESP_OK) {
        ESP_LOGE(TAG, "static fallback address is malformed, staying on DHCP");
        return;
    }

    esp_netif_dhcpc_stop(s_eth_netif);
    s_static = true;
    s_gw_seen = false;
    s_static_since_us = esp_timer_get_time();
    if (esp_netif_set_ip_info(s_eth_netif, &ip) != ESP_OK) {
        s_static = false;
        ESP_LOGE(TAG, "failed to apply static fallback");
        return;
    }

    /* set_ip_info raises IP_EVENT_ETH_GOT_IP, so on_got_ip publishes state. */
    ESP_LOGW(TAG, "no DHCP lease after %ds - falling back to static",
             CONFIG_ATT_NET_DHCP_TIMEOUT_S);
}

/* (Re)starts the countdown to the static fallback. One timer, re-armed --
 * this used to create a new timer on every call. */
static void start_dhcp_fallback_timer(void)
{
    if (CONFIG_ATT_NET_DHCP_TIMEOUT_S <= 0) {
        return;
    }
    if (!s_fallback_timer) {
        const esp_timer_create_args_t args = {
            .callback = dhcp_fallback_cb,
            .name = "dhcp_fallback",
        };
        if (esp_timer_create(&args, &s_fallback_timer) != ESP_OK) {
            return;
        }
    }
    esp_timer_stop(s_fallback_timer);   /* not running is fine */
    esp_timer_start_once(s_fallback_timer,
                         (uint64_t)CONFIG_ATT_NET_DHCP_TIMEOUT_S * 1000000ULL);
}

/* Leaves the static fallback and asks DHCP again. Before this existed the
 * fallback was permanent until a reboot: a router that was slow at boot, or a
 * cable plugged in later, left the terminal stuck on 192.168.137.50. */
static void retry_dhcp(void)
{
    if (!s_eth_netif) {
        return;
    }
    s_static = false;
    s_got_ip = false;
    s_gw_seen = false;
    strcpy(s_ip, "0.0.0.0");
    esp_err_t err = esp_netif_dhcpc_start(s_eth_netif);
    if (err != ESP_OK && err != ESP_ERR_ESP_NETIF_DHCP_ALREADY_STARTED) {
        ESP_LOGW(TAG, "dhcp restart failed: %s", esp_err_to_name(err));
    }
    start_dhcp_fallback_timer();
}

/* --- wedge recovery -----------------------------------------------------
 *
 * The ENC28J60 can corrupt its own receive-buffer pointer. When that happens
 * the driver reads a bogus frame length, the SPI layer rejects the oversized
 * transfer ("txdata transfer > host maximum"), and the receive path fails
 * forever -- link still up, no traffic, errors scrolling. Nothing over SPI
 * clears it; only a hardware reset does.
 *
 * So the terminal checks itself: ping the gateway periodically, and if several
 * consecutive attempts fail while the link is up, cycle the chip. Punches keep
 * recording locally throughout (that path never touches Ethernet); this only
 * restores syncing.
 */

static SemaphoreHandle_t s_ping_done;
static volatile uint32_t s_ping_replies;

static void ping_success(esp_ping_handle_t h, void *arg) { s_ping_replies++; }

static void ping_end(esp_ping_handle_t h, void *arg)
{
    xSemaphoreGive(s_ping_done);
}

/* True when the gateway answered at least once. */
static bool gateway_reachable(void)
{
    if (!s_eth_netif) {
        return false;
    }
    esp_netif_ip_info_t ip;
    if (esp_netif_get_ip_info(s_eth_netif, &ip) != ESP_OK || ip.gw.addr == 0) {
        return false;
    }

    ip_addr_t target = { .type = IPADDR_TYPE_V4 };
    target.u_addr.ip4.addr = ip.gw.addr;

    esp_ping_config_t cfg = ESP_PING_DEFAULT_CONFIG();
    cfg.target_addr = target;
    cfg.count = 3;
    cfg.timeout_ms = 1000;
    cfg.interval_ms = 300;

    esp_ping_callbacks_t cbs = {
        .on_ping_success = ping_success,
        .on_ping_end = ping_end,
        .cb_args = NULL,
    };

    esp_ping_handle_t ping = NULL;
    if (esp_ping_new_session(&cfg, &cbs, &ping) != ESP_OK) {
        return true;   /* cannot test -- do not punish the link for it */
    }

    s_ping_replies = 0;
    if (esp_ping_start(ping) != ESP_OK) {
        esp_ping_delete_session(ping);
        return true;
    }

    /* Bounded wait: count * (timeout + interval) plus slack. */
    xSemaphoreTake(s_ping_done, pdMS_TO_TICKS(6000));
    esp_ping_stop(ping);
    esp_ping_delete_session(ping);

    return s_ping_replies > 0;
}

static void recover(void)
{
    s_resets++;
    ESP_LOGW(TAG, "ethernet unresponsive - resetting ENC28J60 (reset #%" PRIu32 ")",
             s_resets);

    esp_eth_stop(s_eth);
    vTaskDelay(pdMS_TO_TICKS(100));
    hard_reset_chip();

    if (esp_eth_start(s_eth) != ESP_OK) {
        /* The chip is gone rather than merely confused. Rebooting is the only
         * remaining option, and it is safe: the event log is on flash and the
         * PC re-pulls from its own high-water mark. */
        ESP_LOGE(TAG, "restart failed - rebooting");
        esp_restart();
    }
    s_start_us = esp_timer_get_time();
    /* Back to DHCP too: resetting the chip used to keep the static address
     * with DHCP still switched off. */
    retry_dhcp();
}

static void watchdog_task(void *arg)
{
    int strikes = 0;

    while (1) {
        vTaskDelay(pdMS_TO_TICKS(CONFIG_ATT_ETH_WATCHDOG_S * 1000));

        /* A down link is the cable's problem, not the chip's. */
        if (!s_link_up || !s_got_ip) {
            strikes = 0;
            continue;
        }

        if (gateway_reachable()) {
            s_gw_seen = true;
            strikes = 0;
            continue;
        }

        /* On the fallback address with nothing ever answering, there may
         * simply be no 192.168.137.x network on this cable -- the gateway is
         * our own guess. Resetting the chip cannot conjure one up (this used
         * to reset it every ~100 s, forever). Ask DHCP again instead. */
        if (s_static && !s_gw_seen) {
            strikes = 0;
            if (esp_timer_get_time() - s_static_since_us > DHCP_RETRY_US) {
                ESP_LOGW(TAG, "nothing answers on the fallback address - "
                              "asking DHCP again");
                retry_dhcp();
            }
            continue;
        }

        if (++strikes >= 3) {
            if (net_eth_int_stuck_low()) {
                ESP_LOGW(TAG, "INT (GPIO%d) held low - the chip is asserting an "
                              "interrupt that is never serviced", PIN_ETH_INT);
            } else if (net_eth_int_level() == 1) {
                ESP_LOGW(TAG, "INT (GPIO%d) idle high - check the NT wire",
                         PIN_ETH_INT);
            }
            recover();
            strikes = 0;
        } else {
            ESP_LOGW(TAG, "gateway unreachable (%d/3, INT=%d)",
                     strikes, net_eth_int_level());
        }
    }
}

static void start_watchdog(void)
{
    if (CONFIG_ATT_ETH_WATCHDOG_S <= 0) {
        return;
    }
    s_ping_done = xSemaphoreCreateBinary();
    xTaskCreate(watchdog_task, "eth_wdt", 4096, NULL, 4, NULL);
}

uint32_t net_eth_reset_count(void) { return s_resets; }

int net_eth_int_level(void)
{
    if (PIN_ETH_INT < 0) {
        return -1;
    }
    return gpio_get_level(PIN_ETH_INT);
}

bool net_eth_int_stuck_low(void)
{
    if (PIN_ETH_INT < 0) {
        return false;
    }
    /* A healthy line idles high and dips briefly. Twenty samples over 100 ms
     * without a single high reading means it is not being serviced. */
    for (int i = 0; i < 20; i++) {
        if (gpio_get_level(PIN_ETH_INT)) {
            return false;
        }
        vTaskDelay(pdMS_TO_TICKS(5));
    }
    return true;
}

/* RST is a whole-chip reset, so the PHY layer must not own it. Pulsing it
 * manually is what makes recovery possible at all: a corrupted receive-buffer
 * pointer inside the ENC28J60 cannot be cleared over SPI, only by reset. */
static bool s_rst_configured;

static void hard_reset_chip(void)
{
    if (PIN_ETH_RST < 0) {
        return;
    }
    /* Configure once. Re-running gpio_config on every recovery trips the pin
     * reservation check and logs "conflict found for GPIO[26]". */
    if (!s_rst_configured) {
        gpio_config_t rst_cfg = {
            .pin_bit_mask = PIN_MASK(PIN_ETH_RST),
            .mode = GPIO_MODE_OUTPUT,
        };
        ESP_ERROR_CHECK(gpio_config(&rst_cfg));
        s_rst_configured = true;
    }
    gpio_set_level(PIN_ETH_RST, 0);
    vTaskDelay(pdMS_TO_TICKS(10));
    gpio_set_level(PIN_ETH_RST, 1);
    vTaskDelay(pdMS_TO_TICKS(50));   /* datasheet: ~50 ms to become ready */
}

esp_err_t net_eth_start(void)
{
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());

    /* The ENC28J60 driver registers a per-pin ISR for INT, which requires the
     * shared GPIO ISR service to already exist. IDF does not install it for us.
     * ESP_ERR_INVALID_STATE just means someone else got there first. */
    esp_err_t isr_err = gpio_install_isr_service(0);
    if (isr_err != ESP_OK && isr_err != ESP_ERR_INVALID_STATE) {
        ESP_LOGE(TAG, "gpio isr service install failed: %s", esp_err_to_name(isr_err));
        return isr_err;
    }

    hard_reset_chip();

    spi_bus_config_t buscfg = {
        .miso_io_num = PIN_SPI_MISO,
        .mosi_io_num = PIN_SPI_MOSI,
        .sclk_io_num = PIN_SPI_SCLK,
        .quadwp_io_num = -1,
        .quadhd_io_num = -1,
    };
    ESP_ERROR_CHECK(spi_bus_initialize(SPI2_HOST, &buscfg, SPI_DMA_CH_AUTO));

    spi_device_interface_config_t devcfg = {
        .mode = 0,
        .clock_speed_hz = ENC28J60_SPI_CLOCK_MHZ * 1000 * 1000,
        .spics_io_num = PIN_ETH_CS,
        .queue_size = 20,
        .cs_ena_posttrans = enc28j60_cal_spi_cs_hold_time(ENC28J60_SPI_CLOCK_MHZ),
    };

    eth_enc28j60_config_t enc_cfg = ETH_ENC28J60_DEFAULT_CONFIG(SPI2_HOST, &devcfg);
    enc_cfg.int_gpio_num = PIN_ETH_INT;

    eth_mac_config_t mac_cfg = ETH_MAC_DEFAULT_CONFIG();
    mac_cfg.rx_task_stack_size = 4096;
    esp_eth_mac_t *mac = esp_eth_mac_new_enc28j60(&enc_cfg, &mac_cfg);
    if (!mac) {
        ESP_LOGE(TAG, "mac alloc failed");
        return ESP_FAIL;
    }

    eth_phy_config_t phy_cfg = ETH_PHY_DEFAULT_CONFIG();
    phy_cfg.autonego_timeout_ms = 0;   /* ENC28J60 cannot auto-negotiate */
    phy_cfg.reset_gpio_num = -1;       /* its internal PHY has no reset pin;
                                        * the module's RST is a chip reset and
                                        * must not be driven by the PHY layer */
    esp_eth_phy_t *phy = esp_eth_phy_new_enc28j60(&phy_cfg);
    if (!phy) {
        ESP_LOGE(TAG, "phy alloc failed");
        return ESP_FAIL;
    }

    esp_eth_config_t eth_cfg = ETH_DEFAULT_CONFIG(mac, phy);
    esp_eth_handle_t eth = NULL;
    esp_err_t err = esp_eth_driver_install(&eth_cfg, &eth);
    if (err != ESP_OK) {
        /* Almost always wiring or power, not software. "revision: 0" means the
         * SPI reads came back as zeros, i.e. nothing is answering on the bus. */
        ESP_LOGE(TAG, "ENC28J60 not responding (%s)", esp_err_to_name(err));
        ESP_LOGE(TAG, "  check: VCC on 3.3V (NOT 5V), SI->GPIO%d, SO->GPIO%d,",
                 PIN_SPI_MOSI, PIN_SPI_MISO);
        ESP_LOGE(TAG, "         SCK->GPIO%d, CS->GPIO%d, NT->GPIO%d, RST->GPIO%d",
                 PIN_SPI_SCLK, PIN_ETH_CS, PIN_ETH_INT, PIN_ETH_RST);
        ESP_LOGW(TAG, "continuing without network - punches still record locally");
        mac->del(mac);
        phy->del(phy);
        return err;
    }

    /* The module has no MAC of its own; derive a stable one from the ESP32. */
    uint8_t mac_addr[6];
    ESP_ERROR_CHECK(esp_read_mac(mac_addr, ESP_MAC_ETH));
    ESP_ERROR_CHECK(esp_eth_ioctl(eth, ETH_CMD_S_MAC_ADDR, mac_addr));

    /* No auto-negotiation, so state the duplex explicitly. */
    eth_duplex_t duplex = ETH_DUPLEX_HALF;
    ESP_ERROR_CHECK(esp_eth_ioctl(eth, ETH_CMD_S_DUPLEX_MODE, &duplex));

    esp_netif_config_t netif_cfg = ESP_NETIF_DEFAULT_ETH();
    s_eth_netif = esp_netif_new(&netif_cfg);
    ESP_ERROR_CHECK(esp_netif_attach(s_eth_netif, esp_eth_new_netif_glue(eth)));

    ESP_ERROR_CHECK(esp_event_handler_register(ETH_EVENT, ESP_EVENT_ANY_ID, on_eth_event, NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_ETH_GOT_IP, on_got_ip, NULL));

    s_eth = eth;
    s_start_us = esp_timer_get_time();
    ESP_ERROR_CHECK(esp_eth_start(eth));
    start_dhcp_fallback_timer();
    start_watchdog();
    ESP_LOGI(TAG, "started: spi2 clk=%d mosi=%d miso=%d cs=%d int=%d rst=%d @%d MHz",
             PIN_SPI_SCLK, PIN_SPI_MOSI, PIN_SPI_MISO,
             PIN_ETH_CS, PIN_ETH_INT, PIN_ETH_RST, ENC28J60_SPI_CLOCK_MHZ);
    return ESP_OK;
}

bool net_eth_got_ip(void) { return s_got_ip; }

void net_eth_note_reachable(void) { s_gw_seen = true; }

bool net_eth_usable(void)
{
    return s_link_up && s_got_ip && (!s_static || s_gw_seen);
}
esp_netif_t *net_eth_netif(void) { return s_eth_netif; }
bool net_eth_link_up(void) { return s_link_up; }
const char *net_eth_ip(void) { return s_ip; }

void net_eth_log_status(void)
{
    if (s_got_ip) {
        ESP_LOGI(TAG, "link up, ip=%s%s", s_ip, s_static ? " (static)" : "");
        return;
    }

    int secs = (int)((esp_timer_get_time() - s_start_us) / 1000000);

    if (s_link_up) {
        ESP_LOGW(TAG, "link up but no DHCP lease after %ds", secs);
        ESP_LOGW(TAG, "  a PC ethernet port is not a DHCP server - use a router,");
        ESP_LOGW(TAG, "  enable Windows Internet Connection Sharing, or rely on");
        ESP_LOGW(TAG, "  the static fallback (%s) at %ds",
                 CONFIG_ATT_NET_STATIC_IP, CONFIG_ATT_NET_DHCP_TIMEOUT_S);
        return;
    }

    if (secs < 5) {
        return;   /* ENC28J60 takes ~2 s to establish carrier */
    }
    ESP_LOGW(TAG, "no link after %ds", secs);
    if (secs > 15) {
        ESP_LOGW(TAG, "  1. cable seated at both ends? link LED on the module?");
        ESP_LOGW(TAG, "  2. ENC28J60 is 10BASE-T only and cannot auto-negotiate.");
        ESP_LOGW(TAG, "     Some gigabit-only ports refuse to fall back to 10 Mbps.");
        ESP_LOGW(TAG, "     Try an older 10/100 switch between it and the router.");
        ESP_LOGW(TAG, "  3. straight-through cable to a switch/router port, not a PC.");
    }
}
