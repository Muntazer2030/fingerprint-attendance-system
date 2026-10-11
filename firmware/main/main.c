/* Attendance terminal -- bring-up.
 * Verifies the flash layout, brings up I2C/display/event log/Ethernet, and
 * shows a live status screen. */

#include <inttypes.h>
#include <stdio.h>
#include "esp_log.h"
#include "esp_system.h"
#include "esp_partition.h"
#include "esp_app_desc.h"
#include "nvs_flash.h"
#include "driver/i2c_master.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "board.h"
#include "net_eth.h"
#include "evlog.h"
#include "oled.h"
#include "api_server.h"
#include "fpm.h"
#include "users.h"
#include "attend.h"
#include "cfg.h"
#include "timesync.h"

static const char *TAG = "att";

static i2c_master_bus_handle_t s_i2c;

static void report_partition(const char *label, esp_partition_type_t type,
                             esp_partition_subtype_t subtype, const char *name)
{
    const esp_partition_t *p = esp_partition_find_first(type, subtype, name);
    if (!p) {
        ESP_LOGE(TAG, "  %-8s MISSING", label);
        return;
    }
    ESP_LOGI(TAG, "  %-8s off=0x%06" PRIx32 " size=%" PRIu32 " KB",
             label, p->address, p->size / 1024);
}

static esp_err_t i2c_start(void)
{
    i2c_master_bus_config_t cfg = {
        .i2c_port = I2C_NUM_0,
        .sda_io_num = PIN_I2C_SDA,
        .scl_io_num = PIN_I2C_SCL,
        .clk_source = I2C_CLK_SRC_DEFAULT,
        .glitch_ignore_cnt = 7,
        .flags.enable_internal_pullup = true,
    };
    return i2c_new_master_bus(&cfg, &s_i2c);
}

/* Bus scan -- identifies the OLED address and any RTC without needing the
 * module markings. */
static void i2c_scan(void)
{
    ESP_LOGI(TAG, "i2c scan (sda=%d scl=%d):", PIN_I2C_SDA, PIN_I2C_SCL);
    int found = 0;
    for (uint8_t addr = 0x08; addr < 0x78; addr++) {
        if (i2c_master_probe(s_i2c, addr, 50) == ESP_OK) {
            const char *guess = "?";
            if (addr == 0x3C || addr == 0x3D) guess = "OLED";
            else if (addr == 0x68)            guess = "DS3231 / RTC";
            ESP_LOGI(TAG, "   0x%02X  %s", addr, guess);
            found++;
        }
    }
    if (!found) {
        ESP_LOGW(TAG, "   no devices -- check wiring and pull-ups");
    }
}

#if CONFIG_ATT_EVLOG_SELFTEST
/* Exercises the ring log against real flash: append, read back, verify CRC and
 * sequence continuity. */
static void evlog_selftest(void)
{
    evlog_stats_t before, after;
    evlog_get_stats(&before);

    const int N = 3;
    uint32_t first = 0;
    for (int i = 0; i < N; i++) {
        event_rec_t r = {
            .epoch    = 1766217600 + i,
            .employee = (uint16_t)(100 + i),
            .slot     = (uint16_t)i,
            .flags    = (i & 1) ? EV_FLAG_OUT : 0,
            .method   = EV_METHOD_FINGER,
        };
        if (evlog_append(&r) != ESP_OK) {
            ESP_LOGE(TAG, "selftest: append %d failed", i);
            return;
        }
        if (i == 0) {
            first = r.seq;
        }
    }

    event_rec_t back[8];
    size_t got = 0;
    if (evlog_read_since(first - 1, back, 8, &got) != ESP_OK) {
        ESP_LOGE(TAG, "selftest: read failed");
        return;
    }

    bool ok = (got >= (size_t)N);
    for (size_t i = 0; ok && i < (size_t)N; i++) {
        if (back[i].seq != first + i || back[i].employee != 100 + i) {
            ok = false;
        }
    }

    evlog_get_stats(&after);
    ESP_LOGI(TAG, "evlog selftest: %s (wrote %d, read %u, head %" PRIu32
                  " -> %" PRIu32 ")",
             ok ? "PASS" : "FAIL", N, (unsigned)got,
             before.head_seq, after.head_seq);
}
#endif

void app_main(void)
{
    esp_err_t err = nvs_flash_init();
    if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        err = nvs_flash_init();
    }
    ESP_ERROR_CHECK(err);

    const esp_app_desc_t *app = esp_app_get_description();
    ESP_LOGI(TAG, "attendance terminal %s", app->version);
    ESP_LOGI(TAG, "board=%s eth=%s cores=%d",
             BOARD_NAME, ETH_CHIP_NAME, portNUM_PROCESSORS);
    ESP_LOGI(TAG, "heap=%" PRIu32 " bytes", esp_get_free_heap_size());

    ESP_LOGI(TAG, "flash layout:");
    report_partition("nvs",     ESP_PARTITION_TYPE_DATA, ESP_PARTITION_SUBTYPE_DATA_NVS,    NULL);
    report_partition("ota_0",   ESP_PARTITION_TYPE_APP,  ESP_PARTITION_SUBTYPE_APP_OTA_0,   NULL);
    report_partition("ota_1",   ESP_PARTITION_TYPE_APP,  ESP_PARTITION_SUBTYPE_APP_OTA_1,   NULL);
    report_partition("storage", ESP_PARTITION_TYPE_DATA, ESP_PARTITION_SUBTYPE_DATA_SPIFFS, "storage");

    const esp_partition_t *ev = esp_partition_find_first(
        ESP_PARTITION_TYPE_DATA, (esp_partition_subtype_t)0x40, "events");
    if (ev) {
        ESP_LOGI(TAG, "  %-8s off=0x%06" PRIx32 " size=%" PRIu32 " KB -> %" PRIu32 " events",
                 "events", ev->address, ev->size / 1024, ev->size / EVENT_RECORD_BYTES);
    } else {
        ESP_LOGE(TAG, "  events   MISSING");
    }

    ESP_LOGI(TAG, "pins: spi(clk=%d mosi=%d miso=%d) eth(cs=%d int=%d) "
                  "i2c(sda=%d scl=%d) fpm(tx=%d rx=%d) touch=%d buzzer=%d",
             PIN_SPI_SCLK, PIN_SPI_MOSI, PIN_SPI_MISO, PIN_ETH_CS, PIN_ETH_INT,
             PIN_I2C_SDA, PIN_I2C_SCL, PIN_FPM_TX, PIN_FPM_RX, PIN_TOUCH, PIN_BUZZER);
    ESP_LOGI(TAG, "display: %s %dx%d @%dbpp, framebuffer %d bytes",
             OLED_NAME, OLED_W, OLED_H, OLED_BPP, OLED_FB_BYTES);

    cfg_init();

    if (i2c_start() != ESP_OK) {
        ESP_LOGE(TAG, "i2c bus init failed");
    } else {
        i2c_scan();
        if (oled_init(s_i2c) != ESP_OK) {
            ESP_LOGE(TAG, "display init failed");
        }
    }

    if (fpm_init() == ESP_OK) {
        fpm_params_t fp;
        esp_err_t ferr = fpm_read_params(&fp);
        if (ferr == ESP_OK) {
            uint16_t used = 0;
            fpm_template_count(&used);
            ESP_LOGI(TAG, "fingerprint: capacity=%u used=%u security=%u "
                          "packet=%uB baud=%" PRIu32,
                     fp.capacity, used, fp.security, fp.packet_size, fp.baud);
            if (fp.capacity < CONFIG_ATT_MAX_SLOTS) {
                ESP_LOGW(TAG, "sensor holds %u templates but %d slots are "
                              "configured - reduce ATT_MAX_SLOTS",
                         fp.capacity, CONFIG_ATT_MAX_SLOTS);
            }
        } else {
            ESP_LOGE(TAG, "fingerprint sensor not responding (%s)",
                     esp_err_to_name(ferr));

            /* Sweep the baud rates before blaming the wiring -- the three
             * causes look identical from a single timeout. */
            uint32_t baud = 0;
            bool swapped = false;
            esp_err_t perr = fpm_probe(&baud, &swapped);
            if (perr == ESP_OK) {
                if (swapped) {
                    ESP_LOGE(TAG, "  it answers only with the pair exchanged:"
                                  " set ATT_PIN_FPM_TX=%d ATT_PIN_FPM_RX=%d,"
                                  " or swap the two wires",
                             PIN_FPM_RX, PIN_FPM_TX);
                }
                if (baud != CONFIG_ATT_FPM_BAUD) {
                    ESP_LOGE(TAG, "  it is at %" PRIu32 " baud, not %d --"
                                  " set ATT_FPM_BAUD to match", baud,
                             CONFIG_ATT_FPM_BAUD);
                }
            } else if (perr == ESP_ERR_INVALID_RESPONSE) {
                ESP_LOGE(TAG, "  bytes arrive but never form a frame, in"
                              " either orientation:");
                ESP_LOGE(TAG, "    the ground is not shared with the sensor,"
                              " or a pad is picking up another signal");
            } else {
                ESP_LOGE(TAG, "  nothing at all arrives on GPIO%d, at any baud:",
                         PIN_FPM_RX);
                ESP_LOGE(TAG, "    red(VCC)->5V  -- 3.3V is below the 3.8V"
                              " minimum, the sensor stays mute");
                ESP_LOGE(TAG, "    black(GND)->GND, green(TX)->GPIO%d,"
                              " white(RX)->GPIO%d", PIN_FPM_RX, PIN_FPM_TX);
            }
        }
    }

    if (evlog_init() != ESP_OK) {
        ESP_LOGE(TAG, "event log unavailable - punches cannot be stored");
    } else {
#if CONFIG_ATT_EVLOG_SELFTEST
        evlog_selftest();
#endif
    }

    /* Deliberately non-fatal. The terminal's job is to record attendance; it
     * buffers ~40k events locally and syncs when the network returns. A dead
     * Ethernet module must not stop staff clocking in. */
    if (net_eth_start() != ESP_OK) {
        ESP_LOGW(TAG, "running offline - events will buffer until network returns");
    }

    timesync_start();

    if (api_server_start() != ESP_OK) {
        ESP_LOGE(TAG, "api server failed to start");
    }

    users_init();
    if (attend_start() != ESP_OK) {
        ESP_LOGE(TAG, "attendance task failed to start");
    }

    while (1) {
        net_eth_log_status();
        vTaskDelay(pdMS_TO_TICKS(30000));
    }
}
