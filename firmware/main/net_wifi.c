/* Wi-Fi fallback. See net_wifi.h.
 *
 * Things that are easy to get wrong here:
 *
 * "Ethernet is up" means link AND address. The Ethernet code self-assigns a
 * static address when DHCP never answers -- including with no cable at all --
 * so an address alone would keep Wi-Fi off forever on an unplugged terminal.
 *
 * The default route is set explicitly. A Wi-Fi station normally outranks
 * Ethernet in esp_netif's route priority; left alone, traffic would leave
 * over Wi-Fi even with the cable working. The manager task picks the default
 * interface itself every tick instead.
 *
 * Nothing goes to NVS. Wi-Fi's own NVS storage is off (NVS is nearly full with
 * name bitmaps); the credentials live in the raw storage partition.
 */

#include <stdlib.h>
#include <string.h>
#include "net_wifi.h"
#include "net_eth.h"
#include "store.h"
#include "sdkconfig.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_netif.h"
#include "esp_timer.h"
#include "esp_wifi.h"
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"
#include "freertos/task.h"

static const char *TAG = "wifi";

/* Ethernet must be gone this long before Wi-Fi starts, and back this long
 * before Wi-Fi stops. */
#define START_AFTER_US  (20LL * 1000000)
#define STOP_AFTER_US   (60LL * 1000000)
#define TICK_MS         2000

typedef struct {
    char ssid[NET_WIFI_SSID_MAX];
    char pass[NET_WIFI_PASS_MAX];
} creds_t;

static SemaphoreHandle_t s_lock;
static creds_t s_creds;
static bool s_creds_changed;

static esp_netif_t *s_netif;
static bool s_inited;
static bool s_started;      /* radio running                         */
static bool s_want;         /* manager wants a connection right now  */
static bool s_reconnect;    /* a connect attempt is due              */
static int64_t s_next_try_us;
static int s_failures;

static volatile bool s_got_ip;
static char s_ip[16] = "0.0.0.0";
static net_wifi_state_t s_state;
static char s_err[48];

/* ------------------------------------------------------------ helpers -- */

/* Link, address, and if the address is only the static guess, proof that
 * something answers on it. A terminal stuck on 192.168.137.50 on a network
 * that is not 192.168.137.x is offline, and Wi-Fi should take over. */
static bool eth_usable(void) { return net_eth_usable(); }

static void set_err(const char *e)
{
    snprintf(s_err, sizeof(s_err), "%s", e);
}

static const char *reason_text(uint8_t r)
{
    switch (r) {
    case WIFI_REASON_NO_AP_FOUND:              return "network not found";
    case WIFI_REASON_AUTH_FAIL:
    case WIFI_REASON_4WAY_HANDSHAKE_TIMEOUT:
    case WIFI_REASON_HANDSHAKE_TIMEOUT:        return "wrong password?";
    case WIFI_REASON_ASSOC_FAIL:
    case WIFI_REASON_CONNECTION_FAIL:          return "router refused the connection";
    case WIFI_REASON_BEACON_TIMEOUT:           return "signal lost";
    default:                                   return "disconnected";
    }
}

/* ------------------------------------------------------------- events -- */

static void on_wifi_event(void *arg, esp_event_base_t base, int32_t id,
                          void *data)
{
    if (base == WIFI_EVENT && id == WIFI_EVENT_STA_START) {
        /* The scan path also starts the radio; only connect when wanted. */
        if (s_want) {
            s_reconnect = true;
            s_next_try_us = 0;
        }
    } else if (base == WIFI_EVENT && id == WIFI_EVENT_STA_DISCONNECTED) {
        const wifi_event_sta_disconnected_t *d = data;
        s_got_ip = false;
        strcpy(s_ip, "0.0.0.0");
        if (s_want) {
            s_failures++;
            set_err(reason_text(d->reason));
            s_state = s_failures >= 3 ? NET_WIFI_FAILED : NET_WIFI_CONNECTING;
            /* 5 s, 10 s, 20 s ... capped at a minute. */
            int64_t backoff = 5LL << (s_failures > 4 ? 4 : s_failures - 1);
            if (backoff > 60) backoff = 60;
            s_next_try_us = esp_timer_get_time() + backoff * 1000000;
            s_reconnect = true;
            ESP_LOGW(TAG, "disconnected from \"%s\" (reason %u: %s), retry in %llds",
                     s_creds.ssid, d->reason, s_err, (long long)backoff);
        }
    } else if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) {
        const ip_event_got_ip_t *ev = data;
        snprintf(s_ip, sizeof(s_ip), IPSTR, IP2STR(&ev->ip_info.ip));
        s_got_ip = true;
        s_state = NET_WIFI_CONNECTED;
        s_failures = 0;
        s_err[0] = '\0';
        ESP_LOGI(TAG, "connected to \"%s\", ip=%s", s_creds.ssid, s_ip);
    } else if (base == IP_EVENT && id == IP_EVENT_STA_LOST_IP) {
        s_got_ip = false;
        strcpy(s_ip, "0.0.0.0");
    }
}

/* ------------------------------------------------------------- radio -- */

static esp_err_t ensure_init(void)
{
    if (s_inited) {
        return ESP_OK;
    }

    /* Below Ethernet (50), so the cable wins whenever both are up -- the
     * manager also sets the default explicitly, this is belt and braces. */
    esp_netif_inherent_config_t base = ESP_NETIF_INHERENT_DEFAULT_WIFI_STA();
    base.route_prio = 20;
    esp_netif_config_t ncfg = {
        .base = &base,
        .stack = ESP_NETIF_NETSTACK_DEFAULT_WIFI_STA,
    };
    s_netif = esp_netif_new(&ncfg);
    if (!s_netif) {
        return ESP_ERR_NO_MEM;
    }
    esp_netif_attach_wifi_station(s_netif);
    esp_wifi_set_default_wifi_sta_handlers();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    cfg.nvs_enable = 0;
    esp_err_t err = esp_wifi_init(&cfg);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "init failed: %s", esp_err_to_name(err));
        return err;
    }
    esp_wifi_set_storage(WIFI_STORAGE_RAM);
    esp_wifi_set_mode(WIFI_MODE_STA);
    esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, on_wifi_event, NULL);
    esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, on_wifi_event, NULL);
    esp_event_handler_register(IP_EVENT, IP_EVENT_STA_LOST_IP, on_wifi_event, NULL);
    s_inited = true;
    return ESP_OK;
}

static esp_err_t radio_on(void)
{
    if (s_started) {
        return ESP_OK;
    }
    esp_err_t err = esp_wifi_start();
    if (err != ESP_OK) {
        return err;
    }
#if CONFIG_IDF_TARGET_ESP32C3
    /* Many ESP32-C3 boards (the SuperMini in particular) have an antenna
     * layout that cannot associate at full power -- the classic symptom is
     * "network not found" a metre from the router. 8.5 dBm is the
     * well-known fix; range is still fine indoors. */
    esp_wifi_set_max_tx_power(34);   /* units of 0.25 dBm */
#endif
    s_started = true;
    return ESP_OK;
}

static void radio_off(void)
{
    if (!s_started) {
        return;
    }
    esp_wifi_disconnect();
    esp_wifi_stop();
    s_started = false;
    s_got_ip = false;
    strcpy(s_ip, "0.0.0.0");
}

static void apply_config(void)
{
    wifi_config_t wc = {0};
    memcpy(wc.sta.ssid, s_creds.ssid, strnlen(s_creds.ssid, sizeof(wc.sta.ssid)));
    memcpy(wc.sta.password, s_creds.pass,
           strnlen(s_creds.pass, sizeof(wc.sta.password)));
    wc.sta.threshold.authmode = s_creds.pass[0] ? WIFI_AUTH_WPA2_PSK
                                                : WIFI_AUTH_OPEN;
    /* Lets WPA3 routers in transition mode accept us too. */
    wc.sta.sae_pwe_h2e = WPA3_SAE_PWE_BOTH;
    esp_wifi_set_config(WIFI_IF_STA, &wc);
}

/* -------------------------------------------------------------- task -- */

static void manager_task(void *arg)
{
    int64_t eth_down_since = esp_timer_get_time();   /* boot counts as down */
    int64_t eth_up_since = 0;
    esp_netif_t *default_netif = NULL;

    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(TICK_MS));
        int64_t now = esp_timer_get_time();
        bool eth = eth_usable();
        if (eth) {
            if (!eth_up_since) eth_up_since = now;
            eth_down_since = 0;
        } else {
            if (!eth_down_since) eth_down_since = now;
            eth_up_since = 0;
        }

        xSemaphoreTake(s_lock, portMAX_DELAY);
        bool have = s_creds.ssid[0] != '\0';
        bool want;
        if (s_want) {
            want = have && !(eth && now - eth_up_since > STOP_AFTER_US);
        } else {
            want = have && !eth && now - eth_down_since > START_AFTER_US;
        }

        if (want && !s_want) {
            if (ensure_init() == ESP_OK) {
                ESP_LOGW(TAG, "no ethernet - switching to wifi \"%s\"",
                         s_creds.ssid);
                apply_config();
                s_want = true;
                s_failures = 0;
                s_state = NET_WIFI_CONNECTING;
                s_next_try_us = 0;
                if (s_started) {
                    s_reconnect = true;
                } else {
                    /* Connecting is only valid after STA_START; the event
                     * handler schedules it. */
                    s_reconnect = false;
                    radio_on();
                }
            }
        } else if (!want && s_want) {
            ESP_LOGI(TAG, "%s", have ? "ethernet is back - wifi off"
                                     : "wifi forgotten - off");
            s_want = false;
            radio_off();
            s_state = NET_WIFI_OFF;
            s_err[0] = '\0';
        } else if (s_want && s_creds_changed) {
            esp_wifi_disconnect();
            apply_config();
            s_failures = 0;
            s_state = NET_WIFI_CONNECTING;
            s_reconnect = true;
            s_next_try_us = 0;
        }
        s_creds_changed = false;

        if (s_want && s_started && s_reconnect && now >= s_next_try_us) {
            s_reconnect = false;
            esp_wifi_connect();
        }
        xSemaphoreGive(s_lock);

        /* Traffic (the PC, Telegram, NTP) follows the interface in use. */
        esp_netif_t *pick = (!eth && s_got_ip) ? s_netif : net_eth_netif();
        if (pick && pick != default_netif) {
            esp_netif_set_default_netif(pick);
            default_netif = pick;
        }
    }
}

/* --------------------------------------------------------------- api -- */

esp_err_t net_wifi_start(void)
{
    s_lock = xSemaphoreCreateMutex();
    store_init();

    creds_t c;
    uint32_t len = 0;
    if (store_read(STORE_WIFI, &c, sizeof(c), &len) == ESP_OK &&
        len == sizeof(c)) {
        c.ssid[sizeof(c.ssid) - 1] = '\0';
        c.pass[sizeof(c.pass) - 1] = '\0';
        s_creds = c;
    }

    if (xTaskCreate(manager_task, "wifi_mgr", 4096, NULL, 4, NULL) != pdPASS) {
        return ESP_ERR_NO_MEM;
    }
    ESP_LOGI(TAG, "fallback %s%s%s",
             s_creds.ssid[0] ? "to \"" : "not configured",
             s_creds.ssid, s_creds.ssid[0] ? "\"" : "");
    return ESP_OK;
}

esp_err_t net_wifi_set_credentials(const char *ssid, const char *password)
{
    if (!ssid || !password) {
        return ESP_ERR_INVALID_ARG;
    }
    size_t sl = strlen(ssid), pl = strlen(password);
    if (sl >= NET_WIFI_SSID_MAX || pl >= NET_WIFI_PASS_MAX ||
        (pl > 0 && pl < 8)) {
        return ESP_ERR_INVALID_ARG;
    }

    creds_t c = {0};
    memcpy(c.ssid, ssid, sl);
    memcpy(c.pass, password, pl);
    esp_err_t err = sl ? store_write(STORE_WIFI, 1, &c, sizeof(c))
                       : store_erase(STORE_WIFI, 1);
    if (err != ESP_OK) {
        return err;
    }

    xSemaphoreTake(s_lock, portMAX_DELAY);
    s_creds = c;
    s_creds_changed = true;
    xSemaphoreGive(s_lock);
    if (sl) {
        ESP_LOGI(TAG, "fallback network set to \"%s\"", c.ssid);
    } else {
        ESP_LOGI(TAG, "fallback network forgotten");
    }
    return ESP_OK;
}

esp_err_t net_wifi_reset(void) { return net_wifi_set_credentials("", ""); }

void net_wifi_get_status(net_wifi_status_t *out)
{
    memset(out, 0, sizeof(*out));
    xSemaphoreTake(s_lock, portMAX_DELAY);
    out->configured = s_creds.ssid[0] != '\0';
    memcpy(out->ssid, s_creds.ssid, sizeof(out->ssid));
    out->state = s_state;
    memcpy(out->ip, s_ip, sizeof(out->ip));
    memcpy(out->last_error, s_err, sizeof(out->last_error));
    bool connected = s_got_ip;
    xSemaphoreGive(s_lock);

    wifi_ap_record_t ap;
    if (connected && esp_wifi_sta_get_ap_info(&ap) == ESP_OK) {
        out->rssi = ap.rssi;
    }
}

esp_err_t net_wifi_scan(net_wifi_ap_t *out, size_t max, size_t *count)
{
    *count = 0;
    xSemaphoreTake(s_lock, portMAX_DELAY);
    esp_err_t err = ensure_init();
    bool was_started = s_started;
    if (err == ESP_OK) {
        err = radio_on();
    }
    xSemaphoreGive(s_lock);
    if (err != ESP_OK) {
        return err;
    }

    wifi_scan_config_t sc = { .show_hidden = false };
    err = esp_wifi_scan_start(&sc, true);   /* blocks ~2-3 s */

    uint16_t n = 0;
    wifi_ap_record_t *recs = NULL;
    if (err == ESP_OK) {
        esp_wifi_scan_get_ap_num(&n);
        if (n > 30) n = 30;
        recs = calloc(n ? n : 1, sizeof(*recs));
        if (!recs) {
            err = ESP_ERR_NO_MEM;
        } else {
            esp_wifi_scan_get_ap_records(&n, recs);
        }
    }

    if (err == ESP_OK) {
        /* One row per name, strongest first: a mesh shows up as several APs
         * with the same SSID, and the list is for choosing a name. */
        for (uint16_t i = 0; i < n; i++) {
            const char *ssid = (const char *)recs[i].ssid;
            if (!ssid[0]) continue;
            size_t k = 0;
            while (k < *count && strcmp(out[k].ssid, ssid) != 0) k++;
            if (k < *count) {
                if (recs[i].rssi > out[k].rssi) out[k].rssi = recs[i].rssi;
                continue;
            }
            if (*count == max) continue;
            snprintf(out[k].ssid, sizeof(out[k].ssid), "%s", ssid);
            out[k].rssi = recs[i].rssi;
            out[k].secure = recs[i].authmode != WIFI_AUTH_OPEN;
            (*count)++;
        }
        for (size_t a = 0; a < *count; a++) {
            for (size_t b = a + 1; b < *count; b++) {
                if (out[b].rssi > out[a].rssi) {
                    net_wifi_ap_t t = out[a];
                    out[a] = out[b];
                    out[b] = t;
                }
            }
        }
    }
    free(recs);

    /* Leave the radio as it was: scanning must not keep Wi-Fi on. */
    xSemaphoreTake(s_lock, portMAX_DELAY);
    if (!was_started && !s_want) {
        radio_off();
    }
    xSemaphoreGive(s_lock);
    return err;
}

bool net_any_got_ip(void) { return eth_usable() || s_got_ip; }

const char *net_active_ip(void)
{
    if (eth_usable()) return net_eth_ip();
    if (s_got_ip) return s_ip;
    return "0.0.0.0";
}

const char *net_active_iface(void)
{
    if (eth_usable()) return "eth";
    if (s_got_ip) return "wifi";
    return "none";
}
