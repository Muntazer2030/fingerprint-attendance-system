/* Attendance state machine.
 *
 * On a dual-core part this runs on core 1, so that a fingerprint match -- which
 * takes the better part of a second -- never starves the Ethernet driver and
 * HTTP server on core 0. That split is the main reason the WROOM-32 was chosen
 * over the C3. On a single-core part the task is unpinned; see attend_start().
 */

#include <string.h>
#include <time.h>
#include <inttypes.h>
#include "attend.h"
#include "board.h"
#include "fpm.h"
#include "users.h"
#include "evlog.h"
#include "oled.h"
#include "timesync.h"
#include "cfg.h"
#include "net_eth.h"
#include "evlog.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "driver/gpio.h"
#include "driver/ledc.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "attend";

#define TONE_CH     LEDC_CHANNEL_0
#define TONE_TIMER  LEDC_TIMER_0
#define RESULT_HOLD_MS 2500
/* At a 120 ms poll that is ~0.6 s of steady level before a press counts. */
#define TOUCH_DEBOUNCE_SAMPLES 5
/* An operator who walks away must not leave the terminal unable to record
 * attendance, so enrolment is bounded. */
#define ENROLL_TIMEOUT_MS  45000
#define ENROLL_RESULT_MS   3000

static enroll_state_t s_estate = ENROLL_IDLE;
/* Whether the task should be *running* enrolment, kept separate from the
 * reported state so the app can still read "stored"/"failed" after the device
 * has gone back to accepting punches. */
static bool s_enroll_active;
static int64_t s_enroll_deadline_us;   /* whole-session limit  */
static int64_t s_enroll_hold_us;       /* how long to show the result */
static uint32_t s_session;
static uint16_t s_enroll_emp, s_enroll_slot;
static uint8_t  s_enroll_finger;
static const char *s_edetail = "";

static bool s_forced_dir_set, s_forced_dir_out;
static int64_t s_result_until_us;
static char s_result_line[24];
static ui_string_t s_result_str = STR_COUNT;
static uint16_t s_result_emp;
static bool s_result_out, s_result_ok;
static int64_t s_last_activity_us;

/* -------------------------------------------------------------- buzzer -- */

static void tone_init(void)
{
    if (PIN_BUZZER < 0) {
        return;               /* no buzzer fitted on this board */
    }
    ledc_timer_config_t t = {
        .speed_mode = LEDC_LOW_SPEED_MODE,
        .duty_resolution = LEDC_TIMER_10_BIT,
        .timer_num = TONE_TIMER,
        .freq_hz = 2700,
        .clk_cfg = LEDC_AUTO_CLK,
    };
    ledc_timer_config(&t);

    ledc_channel_config_t c = {
        .gpio_num = PIN_BUZZER,
        .speed_mode = LEDC_LOW_SPEED_MODE,
        .channel = TONE_CH,
        .timer_sel = TONE_TIMER,
        .duty = 0,
        .hpoint = 0,
    };
    ledc_channel_config(&c);
}

static void tone(uint32_t hz, int ms)
{
    if (PIN_BUZZER < 0 || !cfg()->buzzer) {
        return;               /* not fitted, or the operator silenced it */
    }
    ledc_set_freq(LEDC_LOW_SPEED_MODE, TONE_TIMER, hz);
    ledc_set_duty(LEDC_LOW_SPEED_MODE, TONE_CH, 512);
    ledc_update_duty(LEDC_LOW_SPEED_MODE, TONE_CH);
    vTaskDelay(pdMS_TO_TICKS(ms));
    ledc_set_duty(LEDC_LOW_SPEED_MODE, TONE_CH, 0);
    ledc_update_duty(LEDC_LOW_SPEED_MODE, TONE_CH);
}

static void beep_ok(void)   { tone(2200, 80); }
static void beep_err(void)  { tone(700, 250); }
static void beep_step(void) { tone(1600, 50); }

/* ------------------------------------------------------------- display -- */

/* Blits an uploaded string bitmap when the app has pushed one, otherwise
 * falls back to the built-in ASCII font. That fallback is what keeps a freshly
 * flashed device usable before the app has ever connected. */
static void draw_str(int y, ui_string_t which, const char *fallback)
{
    const uint8_t *bmp = cfg_get_string(which);
    if (bmp) {
        oled_blit(0, y, UI_STRING_W, UI_STRING_H, bmp);
        return;
    }
    int w = oled_text_width(fallback, 1);
    oled_text((OLED_W - w) / 2, y + 4, fallback);
}

static bool clock_valid(void)
{
    return time(NULL) > 1600000000;
}

/* Formats the clock per the operator's choice. Events are always stored UTC;
 * this only affects what the panel shows. */
static void local_clock(char *hm, size_t hmn, char *suffix, size_t sn)
{
    suffix[0] = '\0';
    if (!clock_valid()) {
        snprintf(hm, hmn, "--:--");
        return;
    }

    time_t t = time(NULL) + cfg()->tz_offset_min * 60;
    struct tm tm;
    gmtime_r(&t, &tm);

    int hour = tm.tm_hour;
    if (cfg()->time_12h) {
        snprintf(suffix, sn, "%s", hour < 12 ? "AM" : "PM");
        hour %= 12;
        if (hour == 0) {
            hour = 12;   /* midnight and noon are 12, not 0 */
        }
    }

    if (cfg()->show_seconds) {
        snprintf(hm, hmn, "%d:%02d:%02d", hour, tm.tm_min, tm.tm_sec);
    } else {
        snprintf(hm, hmn, "%02d:%02d", hour, tm.tm_min);
    }
}

static void date_line(char *out, size_t n)
{
    static const char *MON[] = {"JAN","FEB","MAR","APR","MAY","JUN",
                                "JUL","AUG","SEP","OCT","NOV","DEC"};
    static const char *DOW[] = {"SUN","MON","TUE","WED","THU","FRI","SAT"};
    if (!clock_valid()) {
        if (n) {
            out[0] = 0;
        }
        return;
    }
    time_t t = time(NULL) + cfg()->tz_offset_min * 60;
    struct tm tm;
    gmtime_r(&t, &tm);
    snprintf(out, n, "%s %02d %s", DOW[tm.tm_wday % 7], tm.tm_mday,
             MON[tm.tm_mon % 12]);
}

/* Small link glyph instead of the old inverted strip. Three ascending bars
 * when we have an address, a crossed box when we do not -- readable at a
 * glance and it does not swallow a whole row of the panel. */
static void draw_net_icon(int x, int y)
{
    if (net_eth_got_ip()) {
        oled_fill_rect(x,     y + 4, 2, 3, true);
        oled_fill_rect(x + 3, y + 2, 2, 5, true);
        oled_fill_rect(x + 6, y,     2, 7, true);
    } else {
        oled_rect(x, y, 8, 7);
        for (int i = 0; i < 7; i++) {
            oled_pixel(x + i, y + i, true);
        }
    }
}

/* The chip states what the next scan will record. In FIXED mode that is a
 * fact, so it is always shown; in AUTO mode the direction depends on which
 * employee scans and is not knowable yet, so the chip is omitted rather than
 * filled with something staff cannot act on. */
static void draw_header(void)
{
    evlog_stats_t st;
    evlog_get_stats(&st);

    int right = OLED_W;
    if (st.pending > 0) {
        /* The ring holds ~40k, so cap the label rather than widen the buffer:
         * an exact five-digit backlog tells nobody anything the app cannot. */
        char n[8];
        if (st.pending > 999) {
            snprintf(n, sizeof(n), "999+");
        } else {
            snprintf(n, sizeof(n), "%u", (unsigned)st.pending);
        }
        right -= oled_text_width(n, 1);
        oled_text(right, 2, n);
        right -= 3;
    }
    draw_net_icon(right - 9, 2);

    oled_hline(0, 12, OLED_W);
}

static void draw_idle(void)
{
    char hm[12], suffix[4], date[20];
    local_clock(hm, sizeof(hm), suffix, sizeof(suffix));
    date_line(date, sizeof(date));

    oled_clear();

    /* 64 px:
     *    0..6   network line: link glyph, IP, backlog
     *    7..9   padding
     *   10..25  mode strip
     *      27   rule
     *   31..51  clock at 3x
     *   55..61  date
     *
     * The network line owns a row of its own because the mode strip is centred
     * and "CHECK IN" alone spans x=40..87. The address is drawn in the 3x5
     * face, which fits it in 54 px rather than 90 and keeps it visibly
     * secondary to the mode. The clock stays at 3x -- that was the point of
     * dropping the "place finger" line. */

    draw_net_icon(1, 0);
    {
        evlog_stats_t st;
        evlog_get_stats(&st);

        /* The address is on the panel because a terminal nobody can reach is a
         * support call, and reading it off the screen beats fetching a laptop
         * and a USB cable. Only shown once DHCP has actually answered -- the
         * glyph already says when it has not. */
        if (net_eth_got_ip()) {
            /* Centred against the 7 px glyph: the small face is 5 tall. */
            oled_text_small(12, 1, net_eth_ip());
        }

        if (st.pending > 0) {
            /* Right-aligned so it never walks into the address. Kept in the
             * 5x7 face: a backlog is something to act on, unlike the address,
             * and "255.255.255.255" now ends at x=65 with room to spare. */
            char n[8];
            if (st.pending > 999) {
                snprintf(n, sizeof(n), "999+");
            } else {
                snprintf(n, sizeof(n), "%u", (unsigned)st.pending);
            }
            oled_text(OLED_W - oled_text_width(n, 1), 0, n);
        }
    }

    if (cfg()->dir_mode == CFG_DIR_FIXED) {
        /* Drawn plainly, NOT inverted. Inverting the strip lights every
         * background pixel in a 128x16 block -- a glaring slab with a small
         * dark hole where the text is. A rule underneath separates it instead. */
        draw_str(10, cfg()->dir_out ? STR_MODE_OUT : STR_MODE_IN,
                 cfg()->dir_out ? "CHECK OUT" : "CHECK IN");
        oled_hline(0, 27, OLED_W);
    }

    /* 3x normally, but "12:34:56 PM" is 8 glyphs and would overflow, so fall
     * back to 2x when seconds are switched on rather than clipping. */
    int sw = suffix[0] ? (oled_text_width(suffix, 1) + 3) : 0;
    int scale = 3;
    if (oled_text_width(hm, scale) + sw > OLED_W) {
        scale = 2;
    }

    int w = oled_text_width(hm, scale);
    int x = (OLED_W - (w + sw)) / 2;
    if (x < 0) {
        x = 0;
    }

    /* Bottom-align the suffix to the clock so AM/PM sits on the baseline
     * rather than floating at the top of the digits. */
    const int clock_y = 31;
    oled_text_scaled(x, clock_y, hm, scale);
    if (suffix[0]) {
        oled_text(x + w + 3, clock_y + 7 * scale - 7, suffix);
    }

    if (date[0]) {
        oled_text((OLED_W - oled_text_width(date, 1)) / 2, 55, date);
    }

    oled_flush();
}

static void draw_result(void)
{
    uint8_t bmp[USERS_NAME_BITMAP_BYTES];
    size_t len = sizeof(bmp);

    oled_clear();
    draw_header();

    /* The employee name dominates: it is the one thing the person in front of
     * the device actually needs to confirm. */
    if (s_result_emp && users_get_name(s_result_emp, bmp, &len) == ESP_OK &&
        len == USERS_NAME_BITMAP_BYTES) {
        oled_blit(0, 14, 128, 16, bmp);
    } else if (s_result_emp) {
        int w = oled_text_width(s_result_line, 2);
        oled_text_scaled((OLED_W - w) / 2, 14, s_result_line, 2);
    }

    if (s_result_ok) {
        char hm[12], suffix[4];
        local_clock(hm, sizeof(hm), suffix, sizeof(suffix));

        draw_str(36, s_result_out ? STR_OUT : STR_IN,
                 s_result_out ? "OUT" : "IN");
        oled_invert_rect(0, 35, OLED_W, 15);

        int w = oled_text_width(hm, 1);
        oled_text((OLED_W - w) / 2, 53, hm);
    } else if (s_result_str < STR_COUNT) {
        draw_str(38, s_result_str, s_result_line);
    } else {
        oled_text((OLED_W - oled_text_width(s_result_line, 1)) / 2, 42,
                  s_result_line);
    }

    oled_flush();
}

static void draw_enroll(void)
{
    oled_clear();
    draw_header();

    draw_str(12, STR_ENROLLING, "ENROLLING");

    char line[24];
    snprintf(line, sizeof(line), "ID %u  F%u", s_enroll_emp, s_enroll_finger);
    int w = oled_text_width(line, 1);
    oled_text((OLED_W - w) / 2, 30, line);

    ui_string_t which = STR_PLACE_FINGER;
    const char *fallback = "";
    switch (s_estate) {
    case ENROLL_WAIT_FINGER: which = STR_PLACE_FINGER; fallback = "PLACE FINGER"; break;
    case ENROLL_LIFT_FINGER: which = STR_LIFT_FINGER;  fallback = "LIFT FINGER";  break;
    case ENROLL_WAIT_AGAIN:  which = STR_PLACE_AGAIN;  fallback = "PLACE AGAIN";  break;
    case ENROLL_MERGING:     which = STR_SAVING;       fallback = "SAVING...";    break;
    case ENROLL_STORED:      which = STR_SAVED;        fallback = "SAVED";        break;
    case ENROLL_FAILED:      which = STR_FAILED;       fallback = s_edetail;      break;
    default: break;
    }
    draw_str(44, which, fallback);

    /* Three-step progress pips, so the user can see how far through they are. */
    int step = (s_estate == ENROLL_WAIT_FINGER) ? 0
             : (s_estate == ENROLL_LIFT_FINGER || s_estate == ENROLL_WAIT_AGAIN) ? 1
             : 2;
    for (int i = 0; i < 3; i++) {
        int x = OLED_W / 2 - 14 + i * 12;
        if (i <= step) {
            oled_fill_rect(x, OLED_H - 5, 8, 3, true);
        } else {
            oled_rect(x, OLED_H - 5, 8, 3);
        }
    }

    oled_flush();
}

/* OLED burn-in mitigation (D11): dim, then blank, then nudge the origin so a
 * static idle screen cannot ghost itself into the panel over months. */
static void apply_idle_policy(void)
{
    int idle_s = (int)((esp_timer_get_time() - s_last_activity_us) / 1000000);

    if (cfg()->idle_off_s > 0 && idle_s > cfg()->idle_off_s) {
        oled_display_on(false);
        return;
    }
    oled_display_on(true);

    if (cfg()->idle_dim_s > 0 && idle_s > cfg()->idle_dim_s) {
        oled_set_contrast(cfg()->brightness / 8 + 1);
    } else {
        oled_set_contrast(cfg()->brightness);
    }

    /* A slow 3-position wander is invisible in use but spreads the wear. */
    int phase = (int)((esp_timer_get_time() / 60000000) % 3);
    oled_set_shift(phase, 0);
}

static void wake(void)
{
    s_last_activity_us = esp_timer_get_time();
}

/* --------------------------------------------------------------- touch -- */

static void poll_touch(void)
{
    /* GPIO35 is input-only and has no internal pull, so an unconnected TTP223
     * leaves the line floating and it reads as noise -- which showed up as the
     * direction override flipping several times a second on its own. Require
     * the level to hold steady across several polls before believing it, and
     * let an operator switch the input off entirely. */
    static bool stable;      /* last accepted level      */
    static bool candidate;   /* level we are waiting on  */
    static int  agree;       /* consecutive matching samples */

    if (!cfg()->use_touch_button) {
        return;
    }

    bool now = gpio_get_level(PIN_TOUCH) != 0;

    if (now != candidate) {
        candidate = now;
        agree = 0;
        return;
    }
    if (++agree < TOUCH_DEBOUNCE_SAMPLES) {
        return;               /* not settled yet */
    }
    if (candidate == stable) {
        return;               /* settled on what we already had */
    }
    stable = candidate;

    if (!stable) {
        return;               /* act on press, not release */
    }

    wake();
    if (cfg()->dir_mode == CFG_DIR_FIXED) {
        cfg_toggle_direction();
        beep_step();
        ESP_LOGI(TAG, "terminal now checking %s", cfg()->dir_out ? "OUT" : "IN");
        return;
    }

    /* AUTO mode keeps the three-way override: force OUT, force IN, back to
     * automatic for the next scan. */
    if (!s_forced_dir_set) {
        s_forced_dir_set = true;
        s_forced_dir_out = true;
    } else if (s_forced_dir_out) {
        s_forced_dir_out = false;
    } else {
        s_forced_dir_set = false;
    }
    beep_step();
    ESP_LOGI(TAG, "direction override: %s",
             !s_forced_dir_set ? "auto" : (s_forced_dir_out ? "OUT" : "IN"));
}

/* ---------------------------------------------------------------- scan -- */

/* STR_COUNT means "no uploaded phrase for this", e.g. a bare employee id. */
static void show_result(bool ok, uint16_t emp, bool out,
                        ui_string_t which, const char *text)
{
    s_result_ok = ok;
    s_result_emp = emp;
    s_result_out = out;
    s_result_str = which;
    snprintf(s_result_line, sizeof(s_result_line), "%s", text);
    s_result_until_us = esp_timer_get_time() + RESULT_HOLD_MS * 1000;
    wake();
}

static void scan_step(void)
{
    /* With the sensor's wake wire unconnected, GPIO34 floats (input-only pins
     * have no internal pull), so the detect line reads noise and the sensor
     * ends up being imaged continuously -- which is what makes its LED flash.
     * Operators who cannot wire it set use_finger_detect = 0 and we poll. */
    if (cfg()->use_finger_detect && !fpm_finger_present()) {
        return;
    }
    if (fpm_gen_img() != ESP_OK) {
        return;                 /* no usable image yet -- keep waiting */
    }
    wake();

    if (fpm_img2tz(FPM_BUF1) != ESP_OK) {
        ESP_LOGW(TAG, "img2tz: %s", fpm_confirm_str(fpm_last_confirm()));
        show_result(false, 0, false, STR_TRY_AGAIN, "TRY AGAIN");
        beep_err();
        return;
    }

    uint16_t slot = 0, score = 0;
    esp_err_t err = fpm_search(FPM_BUF1, &slot, &score);
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "no match (%s)", fpm_confirm_str(fpm_last_confirm()));
        show_result(false, 0, false, STR_NOT_KNOWN, "NOT RECOGNISED");
        beep_err();
        return;
    }

    uint16_t emp = users_slot_owner(slot);
    if (emp == 0) {
        /* Sensor holds a template the registry does not know about -- happens
         * if the two got out of sync. Better to refuse than to log a punch
         * against nobody. */
        ESP_LOGW(TAG, "slot %u matched but is unassigned", slot);
        show_result(false, 0, false, STR_UNASSIGNED, "UNASSIGNED");
        beep_err();
        return;
    }

    emp_entry_t *e = users_get(emp);
    uint32_t now = (uint32_t)time(NULL);

    if (e && e->last_epoch && (now - e->last_epoch) < cfg()->dup_window_s) {
        ESP_LOGI(TAG, "duplicate punch for %u suppressed", emp);
        show_result(true, emp, e->last_dir != 0, STR_ALREADY_DONE, "ALREADY DONE");
        beep_step();
        return;
    }

    /* FIXED: whatever the terminal currently displays, for everyone.
     * AUTO:   flip this employee from their own last punch (D6), with the
     *         button able to force a single scan. */
    bool out;
    if (cfg()->dir_mode == CFG_DIR_FIXED) {
        out = cfg()->dir_out;
    } else if (s_forced_dir_set) {
        out = s_forced_dir_out;
        s_forced_dir_set = false;       /* override applies once */
    } else {
        out = e ? (e->last_dir == 0) : false;
    }

    event_rec_t rec = {
        .epoch    = now,
        .employee = emp,
        .slot     = slot,
        /* Provisional unless the clock was confirmed by NTP or the PC this
         * boot. A time merely restored from NVS is plausible but unverified,
         * so those punches stay flagged for review (D7). */
        .flags    = (uint8_t)((out ? EV_FLAG_OUT : 0) |
                              (timesync_is_authoritative() ? 0 : EV_FLAG_PROVISIONAL)),
        .method   = EV_METHOD_FINGER,
    };
    if (evlog_append(&rec) != ESP_OK) {
        show_result(false, emp, out, STR_FAILED, "STORE FAILED");
        beep_err();
        return;
    }
    users_record_punch(emp, out ? 1 : 0, now);

    ESP_LOGI(TAG, "punch seq=%" PRIu32 " emp=%u slot=%u score=%u %s%s",
             rec.seq, emp, slot, score, out ? "OUT" : "IN",
             timesync_is_authoritative() ? "" : " (provisional time)");

    char line[24];
    snprintf(line, sizeof(line), "ID %u", emp);
    show_result(true, emp, out, STR_COUNT, line);
    beep_ok();
}

/* -------------------------------------------------------------- enrol -- */

static void enroll_finish(enroll_state_t final, const char *detail)
{
    s_estate = final;
    s_edetail = detail;
    s_enroll_hold_us = esp_timer_get_time() + ENROLL_RESULT_MS * 1000;
}

static void enroll_fail(const char *why)
{
    enroll_finish(ENROLL_FAILED, why);
    ESP_LOGW(TAG, "enrolment failed: %s", why);
    beep_err();
}

static void enroll_step(void)
{
    if (esp_timer_get_time() > s_enroll_deadline_us) {
        enroll_fail("timed out");
        return;
    }

    switch (s_estate) {
    case ENROLL_WAIT_FINGER:
        if (fpm_gen_img() != ESP_OK) {
            return;
        }
        if (fpm_img2tz(FPM_BUF1) != ESP_OK) {
            enroll_fail(fpm_confirm_str(fpm_last_confirm()));
            return;
        }
        beep_step();
        s_estate = ENROLL_LIFT_FINGER;
        break;

    case ENROLL_LIFT_FINGER:
        /* Without this gate the second capture reuses the first image and
         * RegModel merges a finger with itself, producing a weak template. */
        if (fpm_gen_img() == ESP_ERR_NOT_FOUND) {
            s_estate = ENROLL_WAIT_AGAIN;
        }
        break;

    case ENROLL_WAIT_AGAIN:
        if (fpm_gen_img() != ESP_OK) {
            return;
        }
        if (fpm_img2tz(FPM_BUF2) != ESP_OK) {
            enroll_fail(fpm_confirm_str(fpm_last_confirm()));
            return;
        }
        beep_step();
        s_estate = ENROLL_MERGING;
        break;

    case ENROLL_MERGING: {
        esp_err_t err = fpm_reg_model();
        if (err == ESP_ERR_INVALID_STATE) {
            enroll_fail("fingers did not match");
            return;
        }
        if (err != ESP_OK) {
            enroll_fail(fpm_confirm_str(fpm_last_confirm()));
            return;
        }

        uint16_t slot = users_slot_alloc(s_enroll_emp, s_enroll_finger);
        if (slot == UINT16_MAX) {
            enroll_fail("sensor library full");
            return;
        }
        if (fpm_store(FPM_BUF1, slot) != ESP_OK) {
            users_slot_release(slot);
            enroll_fail(fpm_confirm_str(fpm_last_confirm()));
            return;
        }
        s_enroll_slot = slot;
        enroll_finish(ENROLL_STORED, "");
        ESP_LOGI(TAG, "enrolled employee %u finger %u into slot %u",
                 s_enroll_emp, s_enroll_finger, slot);
        beep_ok();
        break;
    }

    default:
        break;
    }
}

/* ---------------------------------------------------------------- task -- */

static void attend_task(void *arg)
{
    tone_init();

    gpio_config_t touch = {
        .pin_bit_mask = PIN_MASK(PIN_TOUCH),
        .mode = GPIO_MODE_INPUT,
    };
    gpio_config(&touch);

    wake();

    while (1) {
        poll_touch();

        if (s_enroll_active) {
            wake();
            bool running = (s_estate > ENROLL_IDLE && s_estate < ENROLL_STORED);
            if (running) {
                enroll_step();
            } else if (esp_timer_get_time() > s_enroll_hold_us) {
                /* Result has been on screen long enough. Hand the device back
                 * to attendance; s_estate stays put so a late poll from the
                 * app still sees the outcome. */
                s_enroll_active = false;
                ESP_LOGI(TAG, "enrolment finished (%s), resuming scanning",
                         attend_enroll_state_str(s_estate));
                continue;
            }
            draw_enroll();
        } else if (esp_timer_get_time() < s_result_until_us) {
            draw_result();
        } else {
            draw_idle();
            scan_step();
        }

        apply_idle_policy();
        vTaskDelay(pdMS_TO_TICKS(120));
    }
}

esp_err_t attend_start(void)
{
    /* On the WROOM-32, core 1 keeps ~1 s fingerprint matches away from the
     * network stack on core 0. The C3 has one core, and asking FreeRTOS to pin
     * to core 1 there is a hard assert, not a no-op -- so let the scheduler
     * place it. The sensor waits yield rather than spin, and the Ethernet task
     * runs at a higher priority, so a single core still works. */
#if portNUM_PROCESSORS > 1
    const BaseType_t core = 1;
#else
    const BaseType_t core = tskNO_AFFINITY;
#endif

    BaseType_t ok = xTaskCreatePinnedToCore(attend_task, "attend", 5120, NULL,
                                            5, NULL, core);
    return ok == pdPASS ? ESP_OK : ESP_ERR_NO_MEM;
}

esp_err_t attend_enroll_begin(uint16_t employee, uint8_t finger, uint32_t *session)
{
    if (s_enroll_active) {
        return ESP_ERR_INVALID_STATE;
    }
    if (!users_get(employee)) {
        return ESP_ERR_NOT_FOUND;
    }
    s_enroll_emp = employee;
    s_enroll_finger = finger;
    s_enroll_slot = 0;
    s_edetail = "";
    s_session = (uint32_t)(esp_timer_get_time() & 0x7FFFFFFF);
    s_estate = ENROLL_WAIT_FINGER;
    s_enroll_active = true;
    s_enroll_deadline_us = esp_timer_get_time() + ENROLL_TIMEOUT_MS * 1000;
    *session = s_session;
    ESP_LOGI(TAG, "enrolment %" PRIu32 " started for employee %u finger %u",
             s_session, employee, finger);
    return ESP_OK;
}

void attend_enroll_status(uint32_t *session, enroll_state_t *state,
                          uint16_t *slot, const char **detail)
{
    *session = s_session;
    *state = s_estate;
    *slot = s_enroll_slot;
    *detail = s_edetail;
}

esp_err_t attend_enroll_cancel(uint32_t session)
{
    if (session != s_session) {
        return ESP_ERR_NOT_FOUND;
    }
    s_enroll_active = false;
    s_estate = ENROLL_IDLE;
    s_edetail = "cancelled";
    return ESP_OK;
}

const char *attend_enroll_state_str(enroll_state_t s)
{
    switch (s) {
    case ENROLL_IDLE:        return "idle";
    case ENROLL_WAIT_FINGER: return "waiting_finger";
    case ENROLL_LIFT_FINGER: return "lift_finger";
    case ENROLL_WAIT_AGAIN:  return "waiting_finger_again";
    case ENROLL_MERGING:     return "merging";
    case ENROLL_STORED:      return "stored";
    case ENROLL_FAILED:      return "failed";
    default:                 return "unknown";
    }
}

void attend_force_direction(bool out)
{
    s_forced_dir_set = true;
    s_forced_dir_out = out;
    wake();
}
