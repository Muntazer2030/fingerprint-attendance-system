#pragma once
/* Runtime device configuration, owned by the Flutter app and persisted in NVS.
 *
 * Everything here used to be a Kconfig constant. Anything an operator might
 * reasonably want to change without a reflash belongs in this struct instead;
 * the Kconfig values now only supply first-boot defaults. */

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include "esp_err.h"

#define CFG_LANG_EN 0
#define CFG_LANG_AR 1

#define CFG_DIR_FIXED 0
#define CFG_DIR_AUTO  1

typedef struct {
    uint8_t  lang;             /* CFG_LANG_* -- picks which string set to blit */
    uint8_t  time_12h;         /* 1 = 12-hour clock with AM/PM                 */
    int16_t  tz_offset_min;    /* display only; events stay UTC                */
    uint8_t  brightness;       /* OLED contrast, 1-255                         */
    uint8_t  buzzer;           /* 0 silences the terminal                      */
    uint16_t dup_window_s;
    uint16_t idle_dim_s;       /* 0 disables (burn-in risk)                    */
    uint16_t idle_off_s;
    uint8_t  use_finger_detect;/* 0 = poll the sensor instead of the wake pin  */
    uint8_t  use_touch_button; /* 0 = ignore the TTP223 input entirely         */

    /* How the direction of a punch is decided.
     *
     * FIXED  - the terminal is in one mode at a time and everyone who scans
     *          gets it. The button switches modes. The screen can therefore
     *          always state truthfully what the next scan will record.
     * AUTO   - each employee is flipped from their own last punch. Smarter,
     *          but the direction is unknowable until the match completes, so
     *          the screen cannot show it in advance.
     */
    uint8_t  dir_mode;
    uint8_t  dir_out;          /* FIXED mode: 0 = checking IN, 1 = checking OUT */
    uint8_t  show_seconds;
} device_cfg_t;

esp_err_t cfg_init(void);
const device_cfg_t *cfg(void);

/* Applies and persists. Fields are validated and clamped. */
esp_err_t cfg_update(const device_cfg_t *in);

/* Flips the FIXED-mode direction and persists it. Used by the touch button. */
esp_err_t cfg_toggle_direction(void);

/* --- UI string bitmaps ---------------------------------------------------
 *
 * The device cannot shape Arabic (D3), so every on-screen phrase is rendered
 * to a 1bpp raster by the app and uploaded here. Slots are fixed so firmware
 * can reference them by name; the app re-uploads the whole set when the
 * language changes. Falls back to the built-in ASCII font when a slot is
 * empty, which keeps a freshly flashed device usable. */

typedef enum {
    STR_PLACE_FINGER = 0,
    STR_WELCOME,
    STR_IN,
    STR_OUT,
    STR_TRY_AGAIN,
    STR_NOT_KNOWN,
    STR_ALREADY_DONE,
    STR_UNASSIGNED,
    STR_ENROLLING,
    STR_LIFT_FINGER,
    STR_PLACE_AGAIN,
    STR_SAVING,
    STR_SAVED,
    STR_FAILED,
    STR_NO_TIME,
    STR_FORCED_IN,
    STR_FORCED_OUT,
    /* What the terminal is currently set to record. Full-width like the rest,
     * because a corner chip cannot hold shaped Arabic. */
    STR_MODE_IN,
    STR_MODE_OUT,
    STR_COUNT,
} ui_string_t;

#define UI_STRING_W     128
#define UI_STRING_H     16
#define UI_STRING_BYTES (UI_STRING_W * UI_STRING_H / 8)

esp_err_t cfg_set_string(ui_string_t which, const uint8_t *bitmap, size_t len);

/* Returns NULL when the slot has never been uploaded. */
const uint8_t *cfg_get_string(ui_string_t which);
bool cfg_has_strings(void);

/* Restores factory defaults and discards every uploaded string bitmap. */
esp_err_t cfg_reset(void);
