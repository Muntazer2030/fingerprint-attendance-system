/* Telegram notifications. See notify.h for what the PC has to provide.
 *
 * Three things shape this file:
 *
 * The scan loop must never wait on the internet. A TLS handshake to Telegram
 * takes a second or two on this part and the ENC28J60 link is not always
 * healthy, so notify_punch() only posts to a queue and a low-priority task
 * does the rest -- including deciding whether the punch was late, which needs
 * a read of today's events.
 *
 * Messages are best effort. Attendance is already safe in the event log; a
 * notification that cannot be delivered after a few tries is dropped and
 * counted, not retried forever while newer ones pile up behind it.
 *
 * Storage writes put the header last. A power cut part-way through leaves an
 * erased header, which reads as "nothing stored" rather than as garbage.
 */

#include <inttypes.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "notify.h"
#include "cfg.h"
#include "evlog.h"
#include "net_wifi.h"
#include "store.h"
#include "cJSON.h"
#include "esp_crt_bundle.h"
#include "esp_http_client.h"
#include "esp_log.h"
#include "esp_system.h"
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/semphr.h"
#include "freertos/task.h"

static const char *TAG = "notify";

/* ----------------------------------------------------------- storage -- */

/* Records live in the shared raw-sector store; see store.h for the map. */
#define CFG_SECTOR      STORE_NOTIFY_CFG
#define ROSTER_SECTOR   STORE_NOTIFY_ROSTER
#define ROSTER_SECTORS  STORE_NOTIFY_ROSTER_SECTORS
#define ROSTER_MAX (ROSTER_SECTORS * STORE_SECTOR_SIZE - STORE_HDR_SIZE)

/* ------------------------------------------------------------- state -- */

typedef struct {
    uint8_t  enabled, each_punch, late, reserved;
    int16_t  summary_min;
    uint16_t reserved2;
    uint32_t summary_sent_day;     /* yyyymmdd of the last summary sent */
    char     bot_token[NOTIFY_TOKEN_MAX];
    char     chat_id[NOTIFY_CHAT_MAX];
} stored_cfg_t;

/* Roster record: { u32 version, u16 names_len, u16 days_len, names, days } */
#define ROSTER_HDR 8

static SemaphoreHandle_t s_lock;
static stored_cfg_t s_cfg;
static uint8_t *s_roster;          /* heap copy of the stored record */
static uint32_t s_roster_len;
static notify_status_t s_status;

typedef enum { EV_PUNCH, EV_TEST, EV_SUMMARY } ev_type_t;

typedef struct {
    uint8_t  type;
    uint8_t  out;
    uint8_t  provisional;
    uint16_t employee;
    uint32_t epoch;
    uint32_t seq;
} notify_ev_t;

#define QUEUE_DEPTH 32
static QueueHandle_t s_queue;

static void set_error(const char *fmt, const char *detail)
{
    xSemaphoreTake(s_lock, portMAX_DELAY);
    snprintf(s_status.last_error, sizeof(s_status.last_error), fmt,
             detail ? detail : "");
    xSemaphoreGive(s_lock);
}

static uint16_t rd16(const uint8_t *p) { return (uint16_t)(p[0] | (p[1] << 8)); }
static uint32_t rd32(const uint8_t *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) |
           ((uint32_t)p[3] << 24);
}

/* ------------------------------------------------------------ roster -- */

/* Walks a days blob. Returns false if it is malformed. */
static bool days_valid(const uint8_t *d, size_t len, uint16_t *ndays,
                       uint32_t *first, uint32_t *last)
{
    size_t p = 0;
    uint16_t n = 0;
    *first = *last = 0;
    while (p < len) {
        if (p + 6 > len) {
            return false;
        }
        uint32_t day = rd32(d + p);
        uint16_t cnt = rd16(d + p + 4);
        p += 6;
        if (p + (size_t)cnt * 6 > len || day < 20000101 || day > 21001231) {
            return false;
        }
        p += (size_t)cnt * 6;
        if (!*first || day < *first) *first = day;
        if (day > *last) *last = day;
        n++;
    }
    *ndays = n;
    return true;
}

static bool names_valid(const uint8_t *d, size_t len, uint16_t *count)
{
    size_t p = 0;
    uint16_t n = 0;
    while (p < len) {
        if (p + 3 > len || p + 3 + d[p + 2] > len) {
            return false;
        }
        p += 3 + d[p + 2];
        n++;
    }
    *count = n;
    return true;
}

static void roster_parts(const uint8_t **names, size_t *nlen,
                         const uint8_t **days, size_t *dlen)
{
    *names = *days = NULL;
    *nlen = *dlen = 0;
    if (!s_roster || s_roster_len < ROSTER_HDR) {
        return;
    }
    *nlen = rd16(s_roster + 4);
    *dlen = rd16(s_roster + 6);
    *names = s_roster + ROSTER_HDR;
    *days = *names + *nlen;
}

static void roster_stats_locked(void)
{
    const uint8_t *names, *days;
    size_t nlen, dlen;
    roster_parts(&names, &nlen, &days, &dlen);
    s_status.roster_version = s_roster ? rd32(s_roster) : 0;
    names_valid(names, nlen, &s_status.roster_names);
    days_valid(days, dlen, &s_status.roster_days, &s_status.roster_first_day,
               &s_status.roster_last_day);
}

/* Copies the employee's name, or "#id" if the PC never sent one. */
static void name_of(uint16_t id, char *out, size_t n)
{
    xSemaphoreTake(s_lock, portMAX_DELAY);
    const uint8_t *names, *days;
    size_t nlen, dlen;
    roster_parts(&names, &nlen, &days, &dlen);
    size_t p = 0;
    while (names && p + 3 <= nlen) {
        uint8_t l = names[p + 2];
        if (rd16(names + p) == id) {
            size_t c = l < n - 1 ? l : n - 1;
            memcpy(out, names + p + 3, c);
            out[c] = '\0';
            xSemaphoreGive(s_lock);
            return;
        }
        p += 3 + l;
    }
    xSemaphoreGive(s_lock);
    snprintf(out, n, "#%u", id);
}

/* -1: no roster covers this date. 0: not expected. 1: expected. */
static int sched_of(uint32_t day, uint16_t id, int16_t *start, uint8_t *grace)
{
    int result = -1;
    xSemaphoreTake(s_lock, portMAX_DELAY);
    const uint8_t *names, *days;
    size_t nlen, dlen;
    roster_parts(&names, &nlen, &days, &dlen);
    size_t p = 0;
    while (days && p + 6 <= dlen) {
        uint32_t d = rd32(days + p);
        uint16_t cnt = rd16(days + p + 4);
        p += 6;
        if (d == day) {
            result = 0;
            for (uint16_t i = 0; i < cnt; i++) {
                const uint8_t *e = days + p + (size_t)i * 6;
                if (rd16(e) == id) {
                    *start = (int16_t)rd16(e + 2);
                    *grace = e[4];
                    result = 1;
                    break;
                }
            }
            break;
        }
        p += (size_t)cnt * 6;
    }
    xSemaphoreGive(s_lock);
    return result;
}

/* Everyone expected on [day]: fills ids/starts/graces, returns the count or
 * -1 when no roster covers it. */
static int expected_on(uint32_t day, uint16_t *ids, int16_t *starts,
                       uint8_t *graces, int max)
{
    int result = -1;
    xSemaphoreTake(s_lock, portMAX_DELAY);
    const uint8_t *names, *days;
    size_t nlen, dlen;
    roster_parts(&names, &nlen, &days, &dlen);
    size_t p = 0;
    while (days && p + 6 <= dlen) {
        uint32_t d = rd32(days + p);
        uint16_t cnt = rd16(days + p + 4);
        p += 6;
        if (d == day) {
            result = 0;
            for (uint16_t i = 0; i < cnt && result < max; i++) {
                const uint8_t *e = days + p + (size_t)i * 6;
                ids[result] = rd16(e);
                starts[result] = (int16_t)rd16(e + 2);
                graces[result] = e[4];
                result++;
            }
            break;
        }
        p += (size_t)cnt * 6;
    }
    xSemaphoreGive(s_lock);
    return result;
}

/* -------------------------------------------------------------- time -- */

static bool clock_valid(void) { return time(NULL) > 1600000000; }

static time_t local_of(time_t utc) { return utc + cfg()->tz_offset_min * 60; }

static uint32_t date_key(time_t utc)
{
    time_t l = local_of(utc);
    struct tm tm;
    gmtime_r(&l, &tm);
    return (uint32_t)((tm.tm_year + 1900) * 10000 + (tm.tm_mon + 1) * 100 +
                      tm.tm_mday);
}

static int minute_of_day(time_t utc)
{
    time_t l = local_of(utc);
    struct tm tm;
    gmtime_r(&l, &tm);
    return tm.tm_hour * 60 + tm.tm_min;
}

static time_t day_start(time_t utc) { return utc - (local_of(utc) % 86400); }

static void hhmm(time_t utc, char *out, size_t n)
{
    int m = minute_of_day(utc);
    snprintf(out, n, "%02d:%02d", m / 60, m % 60);
}

/* ---------------------------------------------------- today's events -- */

#define MAX_TRACK CONFIG_ATT_MAX_EMPLOYEES

typedef struct {
    uint16_t id;
    uint8_t  in_now;        /* last punch was IN */
    uint32_t first_in;      /* 0 = no IN yet     */
} act_t;

/* Collects who did what between [from, to). Records at or after [stop_seq]
 * are skipped, so a punch can be judged against the ones before it. Looks back
 * at most a few thousand records -- far more than a store makes in a day. */
static int scan_day(time_t from, time_t to, uint32_t stop_seq, act_t *acts,
                    int max)
{
    evlog_stats_t st;
    evlog_get_stats(&st);
    if (st.head_seq == 0) {
        return 0;
    }

    const size_t page = 50;
    event_rec_t *buf = malloc(page * sizeof(event_rec_t));
    if (!buf) {
        return 0;
    }

    int n = 0;
    uint32_t since = st.head_seq > 3000 ? st.head_seq - 3000 : 0;
    for (;;) {
        size_t got = 0;
        if (evlog_read_since(since, buf, page, &got) != ESP_OK || got == 0) {
            break;
        }
        for (size_t i = 0; i < got; i++) {
            const event_rec_t *r = &buf[i];
            since = r->seq;
            if (stop_seq && r->seq >= stop_seq) {
                continue;
            }
            if (r->employee == 0 || (time_t)r->epoch < from ||
                (time_t)r->epoch >= to) {
                continue;
            }
            int k = 0;
            while (k < n && acts[k].id != r->employee) k++;
            if (k == n) {
                if (n == max) continue;
                acts[n++] = (act_t){ .id = r->employee };
            }
            bool out = r->flags & EV_FLAG_OUT;
            if (!out && !acts[k].first_in) {
                acts[k].first_in = r->epoch;
            }
            acts[k].in_now = !out;
        }
        if (got < page) {
            break;
        }
    }
    free(buf);
    return n;
}

/* ---------------------------------------------------------- telegram -- */

typedef enum { SEND_OK, SEND_RETRY, SEND_GIVE_UP } send_result_t;

static send_result_t tg_send(const char *text)
{
    stored_cfg_t c;
    xSemaphoreTake(s_lock, portMAX_DELAY);
    c = s_cfg;
    xSemaphoreGive(s_lock);

    if (!c.bot_token[0] || !c.chat_id[0]) {
        set_error("%s", "bot token or chat id not set");
        return SEND_GIVE_UP;
    }
    if (!net_any_got_ip()) {
        set_error("%s", "no network");
        return SEND_RETRY;
    }
    /* A TLS session needs a few tens of KB. Better to wait than to starve the
     * HTTP server the PC syncs through. */
    if (esp_get_free_heap_size() < 50000) {
        set_error("%s", "low memory");
        return SEND_RETRY;
    }

    char url[160];
    snprintf(url, sizeof(url), "https://api.telegram.org/bot%s/sendMessage",
             c.bot_token);

    cJSON *o = cJSON_CreateObject();
    cJSON_AddStringToObject(o, "chat_id", c.chat_id);
    cJSON_AddStringToObject(o, "text", text);
    cJSON_AddBoolToObject(o, "disable_web_page_preview", true);
    char *body = cJSON_PrintUnformatted(o);
    cJSON_Delete(o);
    if (!body) {
        set_error("%s", "out of memory");
        return SEND_RETRY;
    }

    esp_http_client_config_t hc = {
        .url = url,
        .method = HTTP_METHOD_POST,
        .timeout_ms = 15000,
        .crt_bundle_attach = esp_crt_bundle_attach,
        .buffer_size = 1024,
        .buffer_size_tx = 1024,
    };
    esp_http_client_handle_t h = esp_http_client_init(&hc);
    if (!h) {
        free(body);
        set_error("%s", "http client init failed");
        return SEND_RETRY;
    }
    esp_http_client_set_header(h, "Content-Type", "application/json");

    send_result_t result = SEND_RETRY;
    int len = (int)strlen(body);
    esp_err_t err = esp_http_client_open(h, len);
    if (err != ESP_OK) {
        set_error("connect failed: %s", esp_err_to_name(err));
        goto done;
    }
    if (esp_http_client_write(h, body, len) != len) {
        set_error("%s", "write failed");
        goto done;
    }
    /* No answer at all (timeout, connection reset) is transient: the link on
     * this hardware is not always healthy. Only an actual HTTP status from
     * Telegram can say "this will never work". */
    if (esp_http_client_fetch_headers(h) < 0) {
        set_error("%s", "no response from telegram");
        goto done;
    }
    int status = esp_http_client_get_status_code(h);
    if (status <= 0) {
        set_error("%s", "no response from telegram");
        goto done;
    }

    char resp[384];
    int got = esp_http_client_read_response(h, resp, sizeof(resp) - 1);
    resp[got > 0 ? got : 0] = '\0';

    if (status == 200) {
        result = SEND_OK;
    } else {
        /* Telegram explains itself in "description": a wrong token is 401,
         * an unknown chat 400. Neither gets better by retrying. */
        const char *why = NULL;
        cJSON *r = cJSON_Parse(resp);
        cJSON *d = r ? cJSON_GetObjectItem(r, "description") : NULL;
        if (cJSON_IsString(d)) why = d->valuestring;
        char msg[96];
        snprintf(msg, sizeof(msg), "telegram %d: %s", status, why ? why : "");
        set_error("%s", msg);
        cJSON_Delete(r);
        result = (status == 429 || status >= 500) ? SEND_RETRY : SEND_GIVE_UP;
    }

done:
    esp_http_client_close(h);
    esp_http_client_cleanup(h);
    free(body);
    return result;
}

/* Sends with a few spaced retries, then gives up and counts it. */
static void deliver(const char *text)
{
    static const int backoff_s[] = { 5, 15, 30, 60 };
    for (int attempt = 0;; attempt++) {
        send_result_t r = tg_send(text);
        xSemaphoreTake(s_lock, portMAX_DELAY);
        if (r == SEND_OK) {
            s_status.sent++;
            s_status.last_ok_epoch = (uint32_t)time(NULL);
            s_status.last_error[0] = '\0';
        } else {
            s_status.failed++;
        }
        xSemaphoreGive(s_lock);

        if (r != SEND_RETRY) {
            if (r == SEND_GIVE_UP) {
                xSemaphoreTake(s_lock, portMAX_DELAY);
                s_status.dropped++;
                xSemaphoreGive(s_lock);
            }
            return;
        }
        if (attempt == (int)(sizeof(backoff_s) / sizeof(backoff_s[0]))) {
            ESP_LOGW(TAG, "giving up on a message: %s", s_status.last_error);
            xSemaphoreTake(s_lock, portMAX_DELAY);
            s_status.dropped++;
            xSemaphoreGive(s_lock);
            return;
        }
        vTaskDelay(pdMS_TO_TICKS(backoff_s[attempt] * 1000));
    }
}

/* -------------------------------------------------------- composition -- */

static bool arabic(void) { return cfg()->lang == CFG_LANG_AR; }

/* Appends to a fixed buffer and never overruns it. Telegram caps a message at
 * 4096 characters; a store this size stays well under, but a cut message is
 * still better than none. */
typedef struct {
    char  *buf;
    size_t cap, len;
} sb_t;

static void sb_add(sb_t *b, const char *fmt, ...)
    __attribute__((format(printf, 2, 3)));

static void sb_add(sb_t *b, const char *fmt, ...)
{
    if (b->len + 1 >= b->cap) {
        return;
    }
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(b->buf + b->len, b->cap - b->len, fmt, ap);
    va_end(ap);
    if (n < 0) {
        return;
    }
    b->len += (size_t)n;
    if (b->len < b->cap) {
        return;
    }

    /* Cut. vsnprintf may have split a multi-byte character -- Arabic is two
     * bytes a letter -- and Telegram rejects the whole message as invalid
     * UTF-8 if so. Back up to the start of the last character and drop it
     * unless it is complete. */
    size_t end = b->cap - 1;
    size_t lead = end;
    while (lead > 0 && ((uint8_t)b->buf[lead - 1] & 0xC0) == 0x80) {
        lead--;
    }
    if (lead > 0) {
        uint8_t c = (uint8_t)b->buf[lead - 1];
        size_t need = c >= 0xF0 ? 4 : c >= 0xE0 ? 3 : c >= 0xC0 ? 2 : 1;
        if (end - (lead - 1) < need) {
            end = lead - 1;
        }
    }
    b->buf[end] = '\0';
    b->len = b->cap - 1;   /* full: later sb_add calls are ignored */
}

static void handle_punch(const notify_ev_t *ev)
{
    stored_cfg_t c;
    xSemaphoreTake(s_lock, portMAX_DELAY);
    c = s_cfg;
    xSemaphoreGive(s_lock);

    int late_min = 0;
    if (!ev->out && c.late && clock_valid()) {
        int16_t start = -1;
        uint8_t grace = 0;
        if (sched_of(date_key(ev->epoch), ev->employee, &start, &grace) == 1 &&
            start >= 0) {
            /* Lateness is about arriving, so only the first IN of the day
             * counts -- coming back from lunch is not "late". Same rule as
             * the app's timesheet: past the grace, the whole delay counts. */
            act_t acts[MAX_TRACK];
            int n = scan_day(day_start(ev->epoch), ev->epoch + 1, ev->seq, acts,
                             MAX_TRACK);
            bool earlier_in = false;
            for (int i = 0; i < n; i++) {
                if (acts[i].id == ev->employee && acts[i].first_in) {
                    earlier_in = true;
                }
            }
            int over = minute_of_day(ev->epoch) - start;
            if (!earlier_in && over > grace) {
                late_min = over;
            }
        }
    }

    if (!c.each_punch && late_min == 0) {
        return;
    }

    char name[64], t[16], text[200];
    name_of(ev->employee, name, sizeof(name));
    hhmm(ev->epoch, t, sizeof(t));
    sb_t b = { .buf = text, .cap = sizeof(text) };

    if (arabic()) {
        if (ev->out) {
            sb_add(&b, "🔴 %s — خروج %s", name, t);
        } else if (late_min) {
            sb_add(&b, "🟠 %s — دخول %s · متأخر %d دقيقة", name, t, late_min);
        } else {
            sb_add(&b, "🟢 %s — دخول %s", name, t);
        }
        if (ev->provisional) sb_add(&b, " (الوقت غير مؤكد)");
    } else {
        if (ev->out) {
            sb_add(&b, "🔴 %s — OUT %s", name, t);
        } else if (late_min) {
            sb_add(&b, "🟠 %s — IN %s · %d min late", name, t, late_min);
        } else {
            sb_add(&b, "🟢 %s — IN %s", name, t);
        }
        if (ev->provisional) sb_add(&b, " (time unverified)");
    }
    deliver(text);
}

static void handle_summary(void)
{
    if (!clock_valid()) {
        set_error("%s", "summary skipped: clock not set");
        return;
    }
    time_t now = time(NULL);
    uint32_t today = date_key(now);

    act_t *acts = calloc(MAX_TRACK, sizeof(act_t));
    uint16_t *ids = calloc(MAX_TRACK, sizeof(uint16_t));
    int16_t *starts = calloc(MAX_TRACK, sizeof(int16_t));
    uint8_t *graces = calloc(MAX_TRACK, sizeof(uint8_t));
    char *text = malloc(3800);
    if (!acts || !ids || !starts || !graces || !text) {
        set_error("%s", "summary: out of memory");
        goto out;
    }

    int nact = scan_day(day_start(now), now + 1, 0, acts, MAX_TRACK);
    int nexp = expected_on(today, ids, starts, graces, MAX_TRACK);
    bool ar = arabic();

    /* Someone whose shift starts after the summary time is not absent yet --
     * an afternoon shift must not show up in a lunchtime summary. A flexible
     * shift (no start) counts as due. */
    int now_min = minute_of_day(now);
#define NOT_DUE_YET(i) (starts[i] >= 0 && starts[i] > now_min)

    /* Counts first, so the headline is right before the lists are built. */
    int present = 0, late = 0, absent = 0, still_in = 0, extra = 0;
    for (int i = 0; i < nexp; i++) {
        const act_t *a = NULL;
        for (int k = 0; k < nact; k++) {
            if (acts[k].id == ids[i] && acts[k].first_in) a = &acts[k];
        }
        if (!a) {
            if (!NOT_DUE_YET(i)) absent++;
            continue;
        }
        present++;
        if (starts[i] >= 0 &&
            minute_of_day(a->first_in) - starts[i] > graces[i]) {
            late++;
        }
    }
    for (int k = 0; k < nact; k++) {
        if (acts[k].in_now) still_in++;
        bool expected = false;
        for (int i = 0; i < nexp; i++) {
            if (ids[i] == acts[k].id) expected = true;
        }
        if (!expected && acts[k].first_in && nexp >= 0) extra++;
    }

    sb_t b = { .buf = text, .cap = 3800 };
    sb_add(&b, ar ? "📋 ملخص الحضور — %02u/%02u/%04u\n"
                  : "📋 Attendance — %04u-%02u-%02u\n",
           ar ? (unsigned)(today % 100) : (unsigned)(today / 10000),
           (unsigned)((today / 100) % 100),
           ar ? (unsigned)(today / 10000) : (unsigned)(today % 100));

    char name[64], t[16];

    if (nexp < 0) {
        sb_add(&b, ar ? "لم يُرسل الكمبيوتر جدول اليوم. من حضر:\n"
                      : "No schedule from the PC for today. Who came in:\n");
        for (int k = 0; k < nact; k++) {
            if (!acts[k].first_in) continue;
            name_of(acts[k].id, name, sizeof(name));
            hhmm(acts[k].first_in, t, sizeof(t));
            sb_add(&b, "• %s — %s\n", name, t);
        }
        goto send;
    }

    sb_add(&b, ar ? "حاضر %d · متأخر %d · غائب %d\n"
                  : "Present %d · Late %d · Absent %d\n",
           present, late, absent);

    if (late) {
        sb_add(&b, ar ? "\n⏰ المتأخرون\n" : "\n⏰ Late\n");
        for (int i = 0; i < nexp; i++) {
            for (int k = 0; k < nact; k++) {
                if (acts[k].id != ids[i] || !acts[k].first_in || starts[i] < 0) {
                    continue;
                }
                int over = minute_of_day(acts[k].first_in) - starts[i];
                if (over <= graces[i]) continue;
                name_of(ids[i], name, sizeof(name));
                hhmm(acts[k].first_in, t, sizeof(t));
                sb_add(&b, ar ? "• %s — %s (+%d د)\n" : "• %s — %s (+%d min)\n",
                       name, t, over);
            }
        }
    }

    if (absent) {
        sb_add(&b, ar ? "\n❌ الغائبون\n" : "\n❌ Absent\n");
        for (int i = 0; i < nexp; i++) {
            bool came = false;
            for (int k = 0; k < nact; k++) {
                if (acts[k].id == ids[i] && acts[k].first_in) came = true;
            }
            if (came || NOT_DUE_YET(i)) continue;
            name_of(ids[i], name, sizeof(name));
            sb_add(&b, "• %s\n", name);
        }
    }

    if (still_in) {
        sb_add(&b, ar ? "\n🕒 لم يسجّلوا الخروج\n" : "\n🕒 Not checked out\n");
        for (int k = 0; k < nact; k++) {
            if (!acts[k].in_now) continue;
            name_of(acts[k].id, name, sizeof(name));
            sb_add(&b, "• %s\n", name);
        }
    }

    if (extra) {
        sb_add(&b, ar ? "\n➕ حضروا في يوم راحة\n" : "\n➕ Came on a day off\n");
        for (int k = 0; k < nact; k++) {
            bool expected = false;
            for (int i = 0; i < nexp; i++) {
                if (ids[i] == acts[k].id) expected = true;
            }
            if (expected || !acts[k].first_in) continue;
            name_of(acts[k].id, name, sizeof(name));
            hhmm(acts[k].first_in, t, sizeof(t));
            sb_add(&b, "• %s — %s\n", name, t);
        }
    }

#undef NOT_DUE_YET
send:
    deliver(text);
out:
    free(acts);
    free(ids);
    free(starts);
    free(graces);
    free(text);
}

/* Once a day at the chosen minute. A summary more than three hours overdue --
 * the terminal was off at the time -- is skipped rather than sent at night. */
static void maybe_summary(void)
{
    stored_cfg_t c;
    xSemaphoreTake(s_lock, portMAX_DELAY);
    c = s_cfg;
    xSemaphoreGive(s_lock);

    if (!c.enabled || c.summary_min < 0 || !clock_valid()) {
        return;
    }
    time_t now = time(NULL);
    uint32_t today = date_key(now);
    int m = minute_of_day(now);
    if (c.summary_sent_day == today || m < c.summary_min ||
        m - c.summary_min > 180) {
        return;
    }

    xSemaphoreTake(s_lock, portMAX_DELAY);
    s_cfg.summary_sent_day = today;
    stored_cfg_t save = s_cfg;
    xSemaphoreGive(s_lock);
    /* Recorded before sending, so a reboot mid-send cannot repeat it. */
    store_write(CFG_SECTOR, 1, &save, sizeof(save));
    handle_summary();
}

static void notify_task(void *arg)
{
    notify_ev_t ev;
    for (;;) {
        if (xQueueReceive(s_queue, &ev, pdMS_TO_TICKS(10000)) == pdTRUE) {
            switch (ev.type) {
            case EV_PUNCH:
                handle_punch(&ev);
                break;
            case EV_TEST: {
                char text[160];
                char t[16] = "--:--";
                if (clock_valid()) hhmm(time(NULL), t, sizeof(t));
                snprintf(text, sizeof(text),
                         arabic() ? "✅ رسالة تجريبية من جهاز الحضور (%s)"
                                  : "✅ Test message from the attendance "
                                    "terminal (%s)",
                         t);
                deliver(text);
                break;
            }
            case EV_SUMMARY:
                handle_summary();
                break;
            }
        }
        maybe_summary();
    }
}

/* ---------------------------------------------------------------- api -- */

static esp_err_t enqueue(const notify_ev_t *ev)
{
    if (!s_queue) {
        return ESP_ERR_INVALID_STATE;
    }
    if (xQueueSend(s_queue, ev, 0) != pdTRUE) {
        xSemaphoreTake(s_lock, portMAX_DELAY);
        s_status.dropped++;
        xSemaphoreGive(s_lock);
        return ESP_ERR_NO_MEM;
    }
    return ESP_OK;
}

void notify_punch(uint16_t employee, bool out, uint32_t epoch, uint32_t seq,
                  bool provisional)
{
    if (!s_queue || !s_cfg.enabled || (!s_cfg.each_punch && !s_cfg.late)) {
        return;
    }
    notify_ev_t ev = {
        .type = EV_PUNCH,
        .out = out,
        .provisional = provisional,
        .employee = employee,
        .epoch = epoch,
        .seq = seq,
    };
    enqueue(&ev);
}

esp_err_t notify_test(void)
{
    notify_ev_t ev = { .type = EV_TEST };
    return enqueue(&ev);
}

esp_err_t notify_summary_now(void)
{
    notify_ev_t ev = { .type = EV_SUMMARY };
    return enqueue(&ev);
}

void notify_get_cfg(notify_cfg_t *out)
{
    xSemaphoreTake(s_lock, portMAX_DELAY);
    out->enabled = s_cfg.enabled;
    out->each_punch = s_cfg.each_punch;
    out->late = s_cfg.late;
    out->summary_min = s_cfg.summary_min;
    memcpy(out->bot_token, s_cfg.bot_token, sizeof(out->bot_token));
    memcpy(out->chat_id, s_cfg.chat_id, sizeof(out->chat_id));
    xSemaphoreGive(s_lock);
}

esp_err_t notify_set_cfg(const notify_cfg_t *in)
{
    xSemaphoreTake(s_lock, portMAX_DELAY);
    s_cfg.enabled = in->enabled;
    s_cfg.each_punch = in->each_punch;
    s_cfg.late = in->late;
    s_cfg.summary_min = (in->summary_min >= 0 && in->summary_min < 1440)
                            ? in->summary_min : -1;
    memcpy(s_cfg.bot_token, in->bot_token, sizeof(s_cfg.bot_token));
    s_cfg.bot_token[sizeof(s_cfg.bot_token) - 1] = '\0';
    memcpy(s_cfg.chat_id, in->chat_id, sizeof(s_cfg.chat_id));
    s_cfg.chat_id[sizeof(s_cfg.chat_id) - 1] = '\0';
    stored_cfg_t save = s_cfg;
    xSemaphoreGive(s_lock);

    ESP_LOGI(TAG, "config: enabled=%d each=%d late=%d summary=%d chat=%s",
             save.enabled, save.each_punch, save.late, save.summary_min,
             save.chat_id);
    return store_write(CFG_SECTOR, 1, &save, sizeof(save));
}

esp_err_t notify_set_roster(uint32_t version, const uint8_t *names, size_t nlen,
                            const uint8_t *days, size_t dlen)
{
    uint16_t nn, nd;
    uint32_t first, last;
    if (nlen > 0xFFFF || dlen > 0xFFFF || !names_valid(names, nlen, &nn) ||
        !days_valid(days, dlen, &nd, &first, &last)) {
        return ESP_ERR_INVALID_ARG;
    }
    size_t total = ROSTER_HDR + nlen + dlen;
    if (total > ROSTER_MAX) {
        return ESP_ERR_INVALID_SIZE;
    }

    uint8_t *rec = malloc(total);
    if (!rec) {
        return ESP_ERR_NO_MEM;
    }
    rec[0] = version & 0xFF;
    rec[1] = (version >> 8) & 0xFF;
    rec[2] = (version >> 16) & 0xFF;
    rec[3] = (version >> 24) & 0xFF;
    rec[4] = nlen & 0xFF;
    rec[5] = (nlen >> 8) & 0xFF;
    rec[6] = dlen & 0xFF;
    rec[7] = (dlen >> 8) & 0xFF;
    memcpy(rec + ROSTER_HDR, names, nlen);
    memcpy(rec + ROSTER_HDR + nlen, days, dlen);

    esp_err_t err = store_write(ROSTER_SECTOR, ROSTER_SECTORS, rec, total);
    if (err != ESP_OK) {
        free(rec);
        return err;
    }

    xSemaphoreTake(s_lock, portMAX_DELAY);
    free(s_roster);
    s_roster = rec;
    s_roster_len = total;
    roster_stats_locked();
    xSemaphoreGive(s_lock);

    ESP_LOGI(TAG, "roster v%" PRIu32 ": %u names, %u days (%" PRIu32 "..%" PRIu32 ")",
             version, nn, nd, first, last);
    return ESP_OK;
}

esp_err_t notify_reset(void)
{
    xSemaphoreTake(s_lock, portMAX_DELAY);
    memset(&s_cfg, 0, sizeof(s_cfg));
    s_cfg.summary_min = -1;
    free(s_roster);
    s_roster = NULL;
    s_roster_len = 0;
    memset(&s_status, 0, sizeof(s_status));
    xSemaphoreGive(s_lock);

    ESP_LOGW(TAG, "telegram settings and roster cleared");
    esp_err_t err = store_erase(CFG_SECTOR, 1);
    if (err == ESP_OK) {
        err = store_erase(ROSTER_SECTOR, ROSTER_SECTORS);
    }
    return err;
}

void notify_get_status(notify_status_t *out)
{
    xSemaphoreTake(s_lock, portMAX_DELAY);
    *out = s_status;
    xSemaphoreGive(s_lock);
    out->queued = s_queue ? (uint32_t)uxQueueMessagesWaiting(s_queue) : 0;
}

esp_err_t notify_init(void)
{
    s_lock = xSemaphoreCreateMutex();
    s_cfg.summary_min = -1;

    if (store_init() != ESP_OK) {
        ESP_LOGE(TAG, "storage partition missing - notifications disabled");
        return ESP_ERR_NOT_FOUND;
    }

    stored_cfg_t c;
    uint32_t len = 0;
    if (store_read(CFG_SECTOR, &c, sizeof(c), &len) == ESP_OK &&
        len == sizeof(c)) {
        c.bot_token[sizeof(c.bot_token) - 1] = '\0';
        c.chat_id[sizeof(c.chat_id) - 1] = '\0';
        s_cfg = c;
    }

    uint8_t *rec = malloc(ROSTER_MAX);
    if (rec && store_read(ROSTER_SECTOR, rec, ROSTER_MAX, &len) == ESP_OK &&
        len >= ROSTER_HDR && ROSTER_HDR + rd16(rec + 4) + rd16(rec + 6) == len) {
        s_roster = realloc(rec, len);
        s_roster_len = len;
        rec = NULL;
    }
    free(rec);
    roster_stats_locked();

    s_queue = xQueueCreate(QUEUE_DEPTH, sizeof(notify_ev_t));
    /* Low priority: below the scan loop and the HTTP server. The stack is for
     * the TLS handshake, which runs on it. */
    if (!s_queue ||
        xTaskCreate(notify_task, "notify", 10240, NULL, 3, NULL) != pdPASS) {
        ESP_LOGE(TAG, "could not start the notifier");
        return ESP_ERR_NO_MEM;
    }

    ESP_LOGI(TAG, "telegram %s, chat %s, roster %u days / %u names",
             s_cfg.enabled ? "on" : "off",
             s_cfg.chat_id[0] ? s_cfg.chat_id : "-", s_status.roster_days,
             s_status.roster_names);
    return ESP_OK;
}
