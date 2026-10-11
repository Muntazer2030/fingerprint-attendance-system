/* Runtime configuration and uploaded UI string bitmaps. */

#include <string.h>
#include "cfg.h"
#include "esp_log.h"
#include "nvs.h"
#include "sdkconfig.h"
#include "board.h"

static const char *TAG = "cfg";

#define NVS_NS      "cfg"
#define KEY_BLOB    "dev"
#define KEY_STR_FMT "s%d"

static device_cfg_t s_cfg;

/* Kept resident: 17 slots x 256 B is 4.3 KB, and the alternative is an NVS
 * read on every frame. */
static uint8_t s_strings[STR_COUNT][UI_STRING_BYTES];
static bool s_have[STR_COUNT];

const device_cfg_t *cfg(void) { return &s_cfg; }

static void set_defaults(void)
{
    s_cfg = (device_cfg_t){
        .lang = CFG_LANG_EN,
        .time_12h = 0,
        .tz_offset_min = CONFIG_ATT_TZ_OFFSET_MIN,
        .brightness = 0x80,
        .buzzer = 1,
        .dup_window_s = CONFIG_ATT_DUP_WINDOW_S,
        .idle_dim_s = CONFIG_ATT_OLED_IDLE_DIM_S,
        .idle_off_s = CONFIG_ATT_OLED_IDLE_OFF_S,
        .use_finger_detect = (PIN_FPM_DETECT >= 0) ? 1 : 0,
        .use_touch_button = 1,
        .dir_mode = CFG_DIR_FIXED,
        .dir_out = 0,
        .show_seconds = 0,
    };
}

static void clamp(device_cfg_t *c)
{
    if (c->lang > CFG_LANG_AR) c->lang = CFG_LANG_EN;
    if (c->dir_mode > CFG_DIR_AUTO) c->dir_mode = CFG_DIR_FIXED;
    if (c->brightness < 1) c->brightness = 1;
    if (c->tz_offset_min < -720) c->tz_offset_min = -720;
    if (c->tz_offset_min > 840) c->tz_offset_min = 840;
    if (c->dup_window_s > 3600) c->dup_window_s = 3600;
    /* Leaving the panel lit forever is a burn-in hazard (D11), but it is the
     * operator's call, so allow it and just say so. */
    if (c->idle_off_s == 0 && c->idle_dim_s == 0) {
        ESP_LOGW(TAG, "idle dim and blank both disabled - burn-in risk");
    }
}

static void load_strings(nvs_handle_t h)
{
    for (int i = 0; i < STR_COUNT; i++) {
        char key[8];
        snprintf(key, sizeof(key), KEY_STR_FMT, i);
        size_t len = UI_STRING_BYTES;
        s_have[i] = (nvs_get_blob(h, key, s_strings[i], &len) == ESP_OK &&
                     len == UI_STRING_BYTES);
    }
}

esp_err_t cfg_init(void)
{
    set_defaults();

    nvs_handle_t h;
    if (nvs_open(NVS_NS, NVS_READONLY, &h) != ESP_OK) {
        ESP_LOGI(TAG, "no stored config, using defaults");
        return ESP_OK;
    }

    device_cfg_t stored;
    size_t len = sizeof(stored);
    if (nvs_get_blob(h, KEY_BLOB, &stored, &len) == ESP_OK &&
        len == sizeof(stored)) {
        s_cfg = stored;
        clamp(&s_cfg);
    }
    load_strings(h);
    nvs_close(h);

    int have = 0;
    for (int i = 0; i < STR_COUNT; i++) {
        if (s_have[i]) have++;
    }
    ESP_LOGI(TAG, "lang=%s clock=%s tz=%+d strings=%d/%d",
             s_cfg.lang == CFG_LANG_AR ? "ar" : "en",
             s_cfg.time_12h ? "12h" : "24h",
             s_cfg.tz_offset_min, have, STR_COUNT);
    return ESP_OK;
}

esp_err_t cfg_update(const device_cfg_t *in)
{
    if (!in) {
        return ESP_ERR_INVALID_ARG;
    }
    device_cfg_t next = *in;
    clamp(&next);
    s_cfg = next;

    nvs_handle_t h;
    esp_err_t err = nvs_open(NVS_NS, NVS_READWRITE, &h);
    if (err != ESP_OK) {
        return err;
    }
    err = nvs_set_blob(h, KEY_BLOB, &s_cfg, sizeof(s_cfg));
    if (err == ESP_OK) {
        err = nvs_commit(h);
    }
    nvs_close(h);

    ESP_LOGI(TAG, "updated: lang=%s clock=%s tz=%+d bright=%u buzzer=%u",
             s_cfg.lang == CFG_LANG_AR ? "ar" : "en",
             s_cfg.time_12h ? "12h" : "24h", s_cfg.tz_offset_min,
             s_cfg.brightness, s_cfg.buzzer);
    return err;
}

esp_err_t cfg_toggle_direction(void)
{
    device_cfg_t next = s_cfg;
    next.dir_out = !next.dir_out;
    return cfg_update(&next);
}

esp_err_t cfg_set_string(ui_string_t which, const uint8_t *bitmap, size_t len)
{
    if (which >= STR_COUNT || !bitmap || len != UI_STRING_BYTES) {
        return ESP_ERR_INVALID_ARG;
    }
    memcpy(s_strings[which], bitmap, UI_STRING_BYTES);
    s_have[which] = true;

    nvs_handle_t h;
    esp_err_t err = nvs_open(NVS_NS, NVS_READWRITE, &h);
    if (err != ESP_OK) {
        return err;
    }
    char key[8];
    snprintf(key, sizeof(key), KEY_STR_FMT, (int)which);
    err = nvs_set_blob(h, key, bitmap, UI_STRING_BYTES);
    if (err == ESP_OK) {
        err = nvs_commit(h);
    }
    nvs_close(h);
    return err;
}

const uint8_t *cfg_get_string(ui_string_t which)
{
    if (which >= STR_COUNT || !s_have[which]) {
        return NULL;
    }
    return s_strings[which];
}

esp_err_t cfg_reset(void)
{
    set_defaults();
    memset(s_strings, 0, sizeof(s_strings));
    memset(s_have, 0, sizeof(s_have));

    nvs_handle_t h;
    esp_err_t err = nvs_open(NVS_NS, NVS_READWRITE, &h);
    if (err != ESP_OK) {
        return err;
    }
    err = nvs_erase_all(h);
    if (err == ESP_OK) {
        err = nvs_commit(h);
    }
    nvs_close(h);
    ESP_LOGW(TAG, "config and uploaded strings reset to defaults");
    return err;
}

bool cfg_has_strings(void)
{
    for (int i = 0; i < STR_COUNT; i++) {
        if (s_have[i]) {
            return true;
        }
    }
    return false;
}
