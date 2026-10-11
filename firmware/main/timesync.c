/* Clock management without an RTC.
 *
 * The terminal has no battery-backed clock, so after a power cut it wakes up
 * in 1970. Three mechanisms keep that from poisoning the attendance record:
 *
 *   1. The current time is written to NVS once a minute. On boot it is
 *      restored, so the clock starts roughly right instead of absurd. The
 *      worst-case error is however long the unit was powered off.
 *   2. A restored time is explicitly NOT treated as authoritative. Punches
 *      recorded against it carry EV_FLAG_PROVISIONAL so the PC can surface
 *      them for review rather than silently trusting them.
 *   3. SNTP and the PC both correct the clock. Whichever arrives first wins;
 *      from then on punches are unflagged.
 *
 * Events already written keep their provisional flag even after the clock is
 * corrected -- rewriting history in an append-only attendance log would be
 * worse than reporting the uncertainty.
 */

#include <time.h>
#include <sys/time.h>
#include <inttypes.h>
#include "timesync.h"
#include "esp_log.h"
#include "esp_netif_sntp.h"
#include "esp_timer.h"
#include "nvs.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "time";

#define NVS_NS      "time"
#define NVS_KEY     "last"
#define SAVE_EVERY_S 60
#define PLAUSIBLE_EPOCH 1600000000   /* Sep 2020 -- anything below is unset */

static time_source_t s_source;

bool timesync_is_authoritative(void)
{
    return s_source == TIME_SRC_NTP || s_source == TIME_SRC_PC;
}

time_source_t timesync_source(void) { return s_source; }

const char *timesync_source_str(void)
{
    switch (s_source) {
    case TIME_SRC_NTP:      return "ntp";
    case TIME_SRC_PC:       return "pc";
    case TIME_SRC_RESTORED: return "restored";
    default:                return "none";
    }
}

void timesync_note_external_set(void)
{
    s_source = TIME_SRC_PC;
    ESP_LOGI(TAG, "clock set by client, now authoritative");
}

static void save_now(void)
{
    time_t now = time(NULL);
    if (now < PLAUSIBLE_EPOCH) {
        return;
    }
    nvs_handle_t h;
    if (nvs_open(NVS_NS, NVS_READWRITE, &h) != ESP_OK) {
        return;
    }
    nvs_set_u32(h, NVS_KEY, (uint32_t)now);
    nvs_commit(h);
    nvs_close(h);
}

static void restore(void)
{
    nvs_handle_t h;
    if (nvs_open(NVS_NS, NVS_READONLY, &h) != ESP_OK) {
        return;
    }
    uint32_t saved = 0;
    esp_err_t err = nvs_get_u32(h, NVS_KEY, &saved);
    nvs_close(h);

    if (err != ESP_OK || saved < PLAUSIBLE_EPOCH) {
        ESP_LOGW(TAG, "no stored time - punches are provisional until sync");
        return;
    }

    struct timeval tv = { .tv_sec = (time_t)saved };
    settimeofday(&tv, NULL);
    s_source = TIME_SRC_RESTORED;
    ESP_LOGW(TAG, "restored clock to %" PRIu32 " (stale, still provisional)", saved);
}

static void on_ntp_sync(struct timeval *tv)
{
    s_source = TIME_SRC_NTP;
    ESP_LOGI(TAG, "ntp sync: %" PRId64, (int64_t)tv->tv_sec);
    save_now();
}

static void keeper_task(void *arg)
{
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(SAVE_EVERY_S * 1000));
        save_now();
    }
}

esp_err_t timesync_start(void)
{
    restore();

    esp_sntp_config_t cfg = ESP_NETIF_SNTP_DEFAULT_CONFIG("pool.ntp.org");
    cfg.start = true;
    cfg.sync_cb = on_ntp_sync;
    /* Without internet this simply never fires, which is a supported state --
     * the PC can still set the clock over the LAN. */
    esp_err_t err = esp_netif_sntp_init(&cfg);
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "sntp init failed (%s); relying on the PC for time",
                 esp_err_to_name(err));
    }

    xTaskCreate(keeper_task, "timekeeper", 2560, NULL, 3, NULL);
    ESP_LOGI(TAG, "source=%s", timesync_source_str());
    return ESP_OK;
}
