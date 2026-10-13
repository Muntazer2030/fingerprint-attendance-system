/* HTTP API for the Flutter client. See docs/protocol.md.
 *
 * Two things here are load-bearing and easy to get wrong:
 *
 * CORS. The web client runs in a browser, and because we require an
 * Authorization header every request is "non-simple", so Chrome always sends
 * an OPTIONS preflight first. Without a wildcard OPTIONS handler the browser
 * reports a bare network error and never surfaces the 401, which is
 * miserable to debug. Access-Control-Max-Age matters too: without it Chrome
 * re-preflights every single request, doubling round-trips on a 10 Mbps link.
 *
 * Auth. Preflights carry no Authorization header by definition, so OPTIONS
 * must bypass the token check. Everything else must not.
 */

#include <inttypes.h>
#include <string.h>
#include <stdlib.h>
#include <sys/time.h>
#include "api_server.h"
#include "esp_log.h"
#include "esp_http_server.h"
#include "esp_system.h"
#include "esp_random.h"
#include "esp_app_desc.h"
#include "esp_idf_version.h"
#include "esp_timer.h"
#include "nvs.h"
#include "cJSON.h"
#include "board.h"
#include "evlog.h"
#include "net_eth.h"
#include "fpm.h"
#include "users.h"
#include "attend.h"
#include "timesync.h"
#include "cfg.h"
#include "oled.h"
#include "notify.h"
#include "net_wifi.h"
#include "mbedtls/base64.h"

static const char *TAG = "api";

#define NVS_NS        "att"
#define NVS_KEY_TOKEN "token"
#define TOKEN_HEX_LEN 32
#define MAX_EVENTS_PER_REQUEST 100

static char s_token[TOKEN_HEX_LEN + 1];
static httpd_handle_t s_server;

/* ---------------------------------------------------------------- token -- */

static void token_load_or_create(void)
{
    nvs_handle_t h;
    size_t len = sizeof(s_token);

    if (nvs_open(NVS_NS, NVS_READWRITE, &h) != ESP_OK) {
        ESP_LOGE(TAG, "nvs unavailable, using an ephemeral token");
        goto generate;
    }
    if (nvs_get_str(h, NVS_KEY_TOKEN, s_token, &len) == ESP_OK &&
        strlen(s_token) == TOKEN_HEX_LEN) {
        nvs_close(h);
        return;
    }

generate:
    for (int i = 0; i < TOKEN_HEX_LEN; i++) {
        s_token[i] = "0123456789abcdef"[esp_random() & 0xF];
    }
    s_token[TOKEN_HEX_LEN] = '\0';

    if (nvs_set_str(h, NVS_KEY_TOKEN, s_token) == ESP_OK) {
        nvs_commit(h);
    }
    nvs_close(h);
    ESP_LOGW(TAG, "generated new device token: %s", s_token);
}

const char *api_server_token(void) { return s_token; }

/* ----------------------------------------------------------------- cors -- */

static void add_cors(httpd_req_t *req)
{
    httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
    httpd_resp_set_hdr(req, "Access-Control-Allow-Headers", "Authorization, Content-Type");
    httpd_resp_set_hdr(req, "Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS");
    httpd_resp_set_hdr(req, "Access-Control-Max-Age", "86400");
}

/* Preflights never carry Authorization, so they must answer before auth. */
static esp_err_t options_handler(httpd_req_t *req)
{
    add_cors(req);
    httpd_resp_set_status(req, "204 No Content");
    return httpd_resp_send(req, NULL, 0);
}

static bool authorized(httpd_req_t *req)
{
    char hdr[16 + TOKEN_HEX_LEN + 1];
    if (httpd_req_get_hdr_value_str(req, "Authorization", hdr, sizeof(hdr)) != ESP_OK) {
        return false;
    }
    if (strncmp(hdr, "Bearer ", 7) != 0) {
        return false;
    }
    return strcmp(hdr + 7, s_token) == 0;
}

static esp_err_t deny(httpd_req_t *req)
{
    add_cors(req);
    httpd_resp_set_status(req, "401 Unauthorized");
    httpd_resp_set_type(req, "application/json");
    return httpd_resp_sendstr(req, "{\"error\":\"unauthorized\"}");
}

static esp_err_t send_json(httpd_req_t *req, cJSON *root)
{
    char *body = cJSON_PrintUnformatted(root);
    cJSON_Delete(root);
    if (!body) {
        httpd_resp_set_status(req, "500 Internal Server Error");
        return httpd_resp_sendstr(req, "{\"error\":\"oom\"}");
    }
    add_cors(req);
    httpd_resp_set_type(req, "application/json");
    esp_err_t err = httpd_resp_sendstr(req, body);
    free(body);
    return err;
}

static cJSON *events_summary(void)
{
    evlog_stats_t st;
    evlog_get_stats(&st);

    cJSON *o = cJSON_CreateObject();
    cJSON_AddNumberToObject(o, "head", st.head_seq);
    cJSON_AddNumberToObject(o, "ack", st.ack_seq);
    cJSON_AddNumberToObject(o, "pending", st.pending);
    cJSON_AddNumberToObject(o, "oldest", st.oldest_seq);
    cJSON_AddNumberToObject(o, "capacity", st.capacity);
    cJSON_AddBoolToObject(o, "overflow", st.overflow);
    return o;
}

/* ------------------------------------------------------------- handlers -- */

static esp_err_t info_get(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);

    const esp_app_desc_t *app = esp_app_get_description();
    time_t now = time(NULL);

    cJSON *o = cJSON_CreateObject();
    cJSON_AddStringToObject(o, "device", CONFIG_LWIP_LOCAL_HOSTNAME);
    cJSON_AddStringToObject(o, "board", BOARD_NAME);
    cJSON_AddStringToObject(o, "eth", ETH_CHIP_NAME);
    cJSON_AddStringToObject(o, "display", OLED_NAME);
    cJSON_AddStringToObject(o, "fw_version", app->version);
    cJSON_AddStringToObject(o, "idf", IDF_VER);
    cJSON_AddNumberToObject(o, "uptime_s", esp_timer_get_time() / 1000000);
    cJSON_AddStringToObject(o, "ip", net_active_ip());
    cJSON_AddStringToObject(o, "net", net_active_iface());
    cJSON_AddNumberToObject(o, "epoch", (double)now);
    cJSON_AddBoolToObject(o, "time_synced", timesync_is_authoritative());
    cJSON_AddStringToObject(o, "time_source", timesync_source_str());
    cJSON_AddItemToObject(o, "events", events_summary());
    return send_json(req, o);
}

static esp_err_t health_get(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);

    cJSON *o = cJSON_CreateObject();
    cJSON_AddBoolToObject(o, "eth_link", net_eth_link_up());
    cJSON_AddBoolToObject(o, "has_ip", net_any_got_ip());
    cJSON_AddStringToObject(o, "ip", net_active_ip());
    cJSON_AddStringToObject(o, "net", net_active_iface());
    cJSON_AddNumberToObject(o, "heap_free", esp_get_free_heap_size());
    cJSON_AddNumberToObject(o, "heap_min", esp_get_minimum_free_heap_size());
    cJSON_AddNumberToObject(o, "uptime_s", esp_timer_get_time() / 1000000);
    /* Climbing means the ENC28J60 keeps wedging -- signal integrity or power,
     * not software. Worth showing on the dashboard rather than only in logs. */
    cJSON_AddNumberToObject(o, "eth_resets", net_eth_reset_count());
    cJSON_AddNumberToObject(o, "eth_int_level", net_eth_int_level());
    cJSON_AddItemToObject(o, "events", events_summary());
    return send_json(req, o);
}

static esp_err_t events_get(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);

    uint32_t since = 0;
    size_t limit = MAX_EVENTS_PER_REQUEST;

    char query[64];
    if (httpd_req_get_url_query_str(req, query, sizeof(query)) == ESP_OK) {
        char val[16];
        if (httpd_query_key_value(query, "since", val, sizeof(val)) == ESP_OK) {
            since = strtoul(val, NULL, 10);
        }
        if (httpd_query_key_value(query, "limit", val, sizeof(val)) == ESP_OK) {
            size_t n = strtoul(val, NULL, 10);
            if (n > 0 && n < limit) {
                limit = n;
            }
        }
    }

    event_rec_t *recs = calloc(limit, sizeof(event_rec_t));
    if (!recs) {
        add_cors(req);
        httpd_resp_set_status(req, "503 Service Unavailable");
        return httpd_resp_sendstr(req, "{\"error\":\"oom\"}");
    }

    size_t got = 0;
    evlog_read_since(since, recs, limit, &got);

    cJSON *arr = cJSON_CreateArray();
    for (size_t i = 0; i < got; i++) {
        const event_rec_t *r = &recs[i];
        cJSON *e = cJSON_CreateObject();
        cJSON_AddNumberToObject(e, "seq", r->seq);
        cJSON_AddNumberToObject(e, "epoch", r->epoch);
        cJSON_AddNumberToObject(e, "employee_id", r->employee);
        cJSON_AddNumberToObject(e, "slot", r->slot);
        cJSON_AddStringToObject(e, "direction", (r->flags & EV_FLAG_OUT) ? "out" : "in");
        cJSON_AddStringToObject(e, "method",
                                r->method == EV_METHOD_MANUAL ? "manual" :
                                r->method == EV_METHOD_PIN    ? "pin" : "finger");
        cJSON_AddBoolToObject(e, "manual", !!(r->flags & EV_FLAG_MANUAL));
        cJSON_AddBoolToObject(e, "provisional_time", !!(r->flags & EV_FLAG_PROVISIONAL));
        cJSON_AddItemToArray(arr, e);
    }
    free(recs);

    cJSON *o = cJSON_CreateObject();
    cJSON_AddItemToObject(o, "events", arr);
    cJSON_AddNumberToObject(o, "count", got);
    cJSON_AddItemToObject(o, "stats", events_summary());
    return send_json(req, o);
}

/* Reads the whole body into a NUL-terminated buffer, refusing anything larger
 * than [max]. Most bodies are tiny; the roster is the exception. */
static char *read_body_max(httpd_req_t *req, int max)
{
    if (req->content_len <= 0 || req->content_len > max) {
        return NULL;
    }
    char *buf = malloc(req->content_len + 1);
    if (!buf) {
        return NULL;
    }
    int off = 0;
    while (off < req->content_len) {
        int n = httpd_req_recv(req, buf + off, req->content_len - off);
        if (n <= 0) {
            free(buf);
            return NULL;
        }
        off += n;
    }
    buf[off] = '\0';
    return buf;
}

static char *read_body(httpd_req_t *req) { return read_body_max(req, 1024); }

static esp_err_t bad_request(httpd_req_t *req, const char *why)
{
    add_cors(req);
    httpd_resp_set_status(req, "400 Bad Request");
    httpd_resp_set_type(req, "application/json");
    char msg[96];
    snprintf(msg, sizeof(msg), "{\"error\":\"%s\"}", why);
    return httpd_resp_sendstr(req, msg);
}

static esp_err_t ack_post(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);

    char *body = read_body(req);
    if (!body) return bad_request(req, "missing body");

    cJSON *in = cJSON_Parse(body);
    free(body);
    if (!in) return bad_request(req, "malformed json");

    cJSON *seq = cJSON_GetObjectItem(in, "through_seq");
    if (!cJSON_IsNumber(seq)) {
        cJSON_Delete(in);
        return bad_request(req, "through_seq required");
    }
    uint32_t through = (uint32_t)seq->valuedouble;
    cJSON_Delete(in);

    esp_err_t err = evlog_ack(through);
    if (err != ESP_OK) {
        return bad_request(req, "ack failed");
    }

    cJSON *o = cJSON_CreateObject();
    cJSON_AddItemToObject(o, "events", events_summary());
    return send_json(req, o);
}

static esp_err_t time_post(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);

    char *body = read_body(req);
    if (!body) return bad_request(req, "missing body");

    cJSON *in = cJSON_Parse(body);
    free(body);
    if (!in) return bad_request(req, "malformed json");

    cJSON *epoch = cJSON_GetObjectItem(in, "epoch");
    if (!cJSON_IsNumber(epoch) || epoch->valuedouble < 1600000000) {
        cJSON_Delete(in);
        return bad_request(req, "epoch required, must be a plausible time");
    }
    struct timeval tv = { .tv_sec = (time_t)epoch->valuedouble };
    cJSON_Delete(in);

    settimeofday(&tv, NULL);
    timesync_note_external_set();
    ESP_LOGI(TAG, "clock set to %" PRId64 " by client", (int64_t)tv.tv_sec);

    cJSON *o = cJSON_CreateObject();
    cJSON_AddNumberToObject(o, "epoch", (double)tv.tv_sec);
    cJSON_AddBoolToObject(o, "time_synced", true);
    cJSON_AddStringToObject(o, "time_source", timesync_source_str());
    return send_json(req, o);
}

/* Returns exactly what the panel is displaying, so a layout can be inspected
 * instead of described. */
static esp_err_t screen_get(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);

    const uint8_t *fb = oled_framebuffer();
    size_t n = oled_framebuffer_size();

    size_t cap = ((n + 2) / 3) * 4 + 1;
    char *b64 = malloc(cap);
    if (!b64) {
        add_cors(req);
        httpd_resp_set_status(req, "503 Service Unavailable");
        return httpd_resp_sendstr(req, "{\"error\":\"oom\"}");
    }
    size_t out_len = 0;
    if (mbedtls_base64_encode((unsigned char *)b64, cap, &out_len, fb, n) != 0) {
        free(b64);
        return bad_request(req, "encode failed");
    }
    b64[out_len] = 0;

    cJSON *o = cJSON_CreateObject();
    cJSON_AddNumberToObject(o, "width", OLED_W);
    cJSON_AddNumberToObject(o, "height", OLED_H);
    cJSON_AddStringToObject(o, "format", "page-major-1bpp");
    cJSON_AddStringToObject(o, "framebuffer_b64", b64);
    free(b64);
    return send_json(req, o);
}

/* ---------------------------------------------------------------- reset -- */

/* Destructive, so it is deliberately explicit: the caller names exactly what
 * to clear, and "all" is not the default. The device token is never touched --
 * regenerating it would lock the app out of the device it just wiped. */
static esp_err_t reset_post(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);

    char *body = read_body(req);
    if (!body) return bad_request(req, "missing body");
    cJSON *in = cJSON_Parse(body);
    free(body);
    if (!in) return bad_request(req, "malformed json");

    cJSON *jscope = cJSON_GetObjectItem(in, "scope");
    if (!cJSON_IsString(jscope)) {
        cJSON_Delete(in);
        return bad_request(req, "scope required: events, fingerprints, config or all");
    }
    const char *scope = jscope->valuestring;
    bool all = (strcmp(scope, "all") == 0);

    bool did_events = false, did_prints = false, did_config = false;

    if (all || strcmp(scope, "events") == 0) {
        if (evlog_erase_all() != ESP_OK) {
            cJSON_Delete(in);
            return bad_request(req, "could not erase the event log");
        }
        did_events = true;
    }

    if (all || strcmp(scope, "fingerprints") == 0) {
        /* Order matters: wipe the sensor library first, then the registry.
         * If the registry went first we would lose the slot list and leave
         * orphaned templates that still match but map to nobody. */
        fpm_empty();
        users_clear_all();
        did_prints = true;
    }

    if (all || strcmp(scope, "config") == 0) {
        cfg_reset();
        notify_reset();
        net_wifi_reset();
        did_config = true;
    }

    cJSON_Delete(in);

    if (!did_events && !did_prints && !did_config) {
        return bad_request(req, "unknown scope");
    }

    ESP_LOGW(TAG, "reset performed: events=%d fingerprints=%d config=%d",
             did_events, did_prints, did_config);

    cJSON *o = cJSON_CreateObject();
    cJSON_AddBoolToObject(o, "events_cleared", did_events);
    cJSON_AddBoolToObject(o, "fingerprints_cleared", did_prints);
    cJSON_AddBoolToObject(o, "config_reset", did_config);
    cJSON_AddItemToObject(o, "events", events_summary());
    return send_json(req, o);
}

/* --------------------------------------------------------------- config -- */

static cJSON *config_json(void)
{
    const device_cfg_t *c = cfg();
    cJSON *o = cJSON_CreateObject();
    cJSON_AddStringToObject(o, "language", c->lang == CFG_LANG_AR ? "ar" : "en");
    cJSON_AddBoolToObject(o, "time_12h", c->time_12h);
    cJSON_AddBoolToObject(o, "show_seconds", c->show_seconds);
    cJSON_AddNumberToObject(o, "tz_offset_min", c->tz_offset_min);
    cJSON_AddNumberToObject(o, "brightness", c->brightness);
    cJSON_AddBoolToObject(o, "buzzer", c->buzzer);
    cJSON_AddNumberToObject(o, "dup_window_s", c->dup_window_s);
    cJSON_AddNumberToObject(o, "idle_dim_s", c->idle_dim_s);
    cJSON_AddNumberToObject(o, "idle_off_s", c->idle_off_s);
    cJSON_AddBoolToObject(o, "use_finger_detect", c->use_finger_detect);
    cJSON_AddBoolToObject(o, "use_touch_button", c->use_touch_button);
    cJSON_AddStringToObject(o, "direction_mode",
                            c->dir_mode == CFG_DIR_AUTO ? "auto" : "fixed");
    cJSON_AddStringToObject(o, "direction", c->dir_out ? "out" : "in");
    cJSON_AddBoolToObject(o, "has_strings", cfg_has_strings());
    cJSON_AddNumberToObject(o, "string_slots", STR_COUNT);
    return o;
}

static esp_err_t config_get(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);
    return send_json(req, config_json());
}

/* Partial update: any field left out keeps its current value, so the app can
 * change one setting without having to send the whole struct back. */
static esp_err_t config_post(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);

    char *body = read_body(req);
    if (!body) return bad_request(req, "missing body");
    cJSON *in = cJSON_Parse(body);
    free(body);
    if (!in) return bad_request(req, "malformed json");

    device_cfg_t next = *cfg();
    cJSON *v;

    if ((v = cJSON_GetObjectItem(in, "language")) && cJSON_IsString(v)) {
        next.lang = (strcmp(v->valuestring, "ar") == 0) ? CFG_LANG_AR : CFG_LANG_EN;
    }
    if ((v = cJSON_GetObjectItem(in, "time_12h")) && cJSON_IsBool(v)) {
        next.time_12h = cJSON_IsTrue(v);
    }
    if ((v = cJSON_GetObjectItem(in, "show_seconds")) && cJSON_IsBool(v)) {
        next.show_seconds = cJSON_IsTrue(v);
    }
    if ((v = cJSON_GetObjectItem(in, "tz_offset_min")) && cJSON_IsNumber(v)) {
        next.tz_offset_min = (int16_t)v->valuedouble;
    }
    if ((v = cJSON_GetObjectItem(in, "brightness")) && cJSON_IsNumber(v)) {
        next.brightness = (uint8_t)v->valuedouble;
    }
    if ((v = cJSON_GetObjectItem(in, "buzzer")) && cJSON_IsBool(v)) {
        next.buzzer = cJSON_IsTrue(v);
    }
    if ((v = cJSON_GetObjectItem(in, "dup_window_s")) && cJSON_IsNumber(v)) {
        next.dup_window_s = (uint16_t)v->valuedouble;
    }
    if ((v = cJSON_GetObjectItem(in, "idle_dim_s")) && cJSON_IsNumber(v)) {
        next.idle_dim_s = (uint16_t)v->valuedouble;
    }
    if ((v = cJSON_GetObjectItem(in, "idle_off_s")) && cJSON_IsNumber(v)) {
        next.idle_off_s = (uint16_t)v->valuedouble;
    }
    if ((v = cJSON_GetObjectItem(in, "use_finger_detect")) && cJSON_IsBool(v)) {
        next.use_finger_detect = cJSON_IsTrue(v);
    }
    if ((v = cJSON_GetObjectItem(in, "use_touch_button")) && cJSON_IsBool(v)) {
        next.use_touch_button = cJSON_IsTrue(v);
    }
    if ((v = cJSON_GetObjectItem(in, "direction_mode")) && cJSON_IsString(v)) {
        next.dir_mode = (strcmp(v->valuestring, "auto") == 0) ? CFG_DIR_AUTO
                                                              : CFG_DIR_FIXED;
    }
    if ((v = cJSON_GetObjectItem(in, "direction")) && cJSON_IsString(v)) {
        next.dir_out = (strcmp(v->valuestring, "out") == 0);
    }
    cJSON_Delete(in);

    if (cfg_update(&next) != ESP_OK) {
        return bad_request(req, "could not persist config");
    }
    return send_json(req, config_json());
}

/* Uploads one rendered UI phrase. The device cannot shape Arabic (D3), so the
 * app rasterises every on-screen string and posts them here whenever the
 * display language changes. */
static esp_err_t strings_post(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);

    char *body = read_body(req);
    if (!body) return bad_request(req, "missing body");
    cJSON *in = cJSON_Parse(body);
    free(body);
    if (!in) return bad_request(req, "malformed json");

    cJSON *jslot = cJSON_GetObjectItem(in, "slot");
    cJSON *jb = cJSON_GetObjectItem(in, "bitmap_b64");
    if (!cJSON_IsNumber(jslot) || !cJSON_IsString(jb)) {
        cJSON_Delete(in);
        return bad_request(req, "slot and bitmap_b64 required");
    }

    int slot = (int)jslot->valuedouble;
    if (slot < 0 || slot >= STR_COUNT) {
        cJSON_Delete(in);
        return bad_request(req, "slot out of range");
    }

    uint8_t bmp[UI_STRING_BYTES];
    size_t out_len = 0;
    int rc = mbedtls_base64_decode(bmp, sizeof(bmp), &out_len,
                                   (const unsigned char *)jb->valuestring,
                                   strlen(jb->valuestring));
    cJSON_Delete(in);
    if (rc != 0 || out_len != UI_STRING_BYTES) {
        return bad_request(req, "bitmap_b64 must decode to 256 bytes");
    }

    if (cfg_set_string((ui_string_t)slot, bmp, out_len) != ESP_OK) {
        return bad_request(req, "could not store string");
    }

    cJSON *o = cJSON_CreateObject();
    cJSON_AddNumberToObject(o, "slot", slot);
    cJSON_AddBoolToObject(o, "stored", true);
    return send_json(req, o);
}

/* ---------------------------------------------------------------- users -- */

static esp_err_t users_get_h(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);

    cJSON *arr = cJSON_CreateArray();
    uint16_t cur = 0;
    emp_entry_t e;
    while (users_next(&cur, &e)) {
        cJSON *o = cJSON_CreateObject();
        cJSON_AddNumberToObject(o, "employee_id", e.id);
        cJSON_AddBoolToObject(o, "active", e.active);
        cJSON_AddStringToObject(o, "last_direction", e.last_dir ? "out" : "in");
        cJSON_AddNumberToObject(o, "last_epoch", e.last_epoch);
        cJSON_AddNumberToObject(o, "fail_count", e.fail_count);
        cJSON_AddNumberToObject(o, "fingers", users_slot_count_for(e.id));
        cJSON_AddItemToArray(arr, o);
    }

    cJSON *slots = cJSON_CreateArray();
    uint16_t sc = 0, slot, emp;
    uint8_t finger;
    while (users_slot_next(&sc, &slot, &emp, &finger)) {
        cJSON *o = cJSON_CreateObject();
        cJSON_AddNumberToObject(o, "slot", slot);
        cJSON_AddNumberToObject(o, "employee_id", emp);
        cJSON_AddNumberToObject(o, "finger", finger);
        cJSON_AddItemToArray(slots, o);
    }

    cJSON *root = cJSON_CreateObject();
    cJSON_AddItemToObject(root, "employees", arr);
    cJSON_AddItemToObject(root, "slots", slots);
    cJSON_AddNumberToObject(root, "slots_used", users_slots_used());
    cJSON_AddNumberToObject(root, "slots_total", CONFIG_ATT_MAX_SLOTS);
    return send_json(req, root);
}

static esp_err_t users_post_h(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);

    char *body = read_body(req);
    if (!body) return bad_request(req, "missing body");
    cJSON *in = cJSON_Parse(body);
    free(body);
    if (!in) return bad_request(req, "malformed json");

    cJSON *jid = cJSON_GetObjectItem(in, "employee_id");
    if (!cJSON_IsNumber(jid) || jid->valuedouble < 1 || jid->valuedouble > 65535) {
        cJSON_Delete(in);
        return bad_request(req, "employee_id required");
    }
    uint16_t id = (uint16_t)jid->valuedouble;

    cJSON *jact = cJSON_GetObjectItem(in, "active");
    bool active = cJSON_IsBool(jact) ? cJSON_IsTrue(jact) : true;

    esp_err_t err = users_upsert(id, active);
    if (err != ESP_OK) {
        cJSON_Delete(in);
        return bad_request(req, err == ESP_ERR_NO_MEM ? "employee table full"
                                                      : "upsert failed");
    }

    /* Name bitmap is optional: 128x16 1bpp, already shaped and RTL-ordered by
     * the Flutter app so the device never reasons about Arabic (D3). */
    cJSON *jb = cJSON_GetObjectItem(in, "name_bitmap_b64");
    if (cJSON_IsString(jb) && jb->valuestring) {
        uint8_t bmp[USERS_NAME_BITMAP_BYTES];
        size_t out_len = 0;
        int rc = mbedtls_base64_decode(bmp, sizeof(bmp), &out_len,
                                       (const unsigned char *)jb->valuestring,
                                       strlen(jb->valuestring));
        if (rc != 0 || out_len != USERS_NAME_BITMAP_BYTES) {
            cJSON_Delete(in);
            return bad_request(req, "name_bitmap_b64 must decode to 256 bytes");
        }
        users_set_name(id, bmp, out_len);
    }
    cJSON_Delete(in);

    cJSON *o = cJSON_CreateObject();
    cJSON_AddNumberToObject(o, "employee_id", id);
    cJSON_AddNumberToObject(o, "fingers", users_slot_count_for(id));
    return send_json(req, o);
}

static esp_err_t users_delete_h(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);

    char query[48], val[12];
    if (httpd_req_get_url_query_str(req, query, sizeof(query)) != ESP_OK ||
        httpd_query_key_value(query, "employee_id", val, sizeof(val)) != ESP_OK) {
        return bad_request(req, "employee_id query param required");
    }
    uint16_t id = (uint16_t)strtoul(val, NULL, 10);

    /* Templates must leave the sensor too, otherwise the next enrolment
     * inherits them and punches land on the wrong person. */
    uint16_t cur = 0, slot, emp;
    uint8_t finger;
    while (users_slot_next(&cur, &slot, &emp, &finger)) {
        if (emp == id) {
            fpm_delete(slot, 1);
        }
    }

    if (users_remove(id) != ESP_OK) {
        return bad_request(req, "unknown employee_id");
    }

    cJSON *o = cJSON_CreateObject();
    cJSON_AddNumberToObject(o, "employee_id", id);
    cJSON_AddBoolToObject(o, "deleted", true);
    return send_json(req, o);
}

/* --------------------------------------------------------------- enrol -- */

static cJSON *enroll_json(void)
{
    uint32_t session;
    enroll_state_t st;
    uint16_t slot;
    const char *detail;
    attend_enroll_status(&session, &st, &slot, &detail);

    cJSON *o = cJSON_CreateObject();
    cJSON_AddNumberToObject(o, "session_id", session);
    cJSON_AddStringToObject(o, "state", attend_enroll_state_str(st));
    if (st == ENROLL_STORED) {
        cJSON_AddNumberToObject(o, "slot", slot);
    }
    if (st == ENROLL_FAILED) {
        cJSON_AddStringToObject(o, "reason", detail);
    }
    return o;
}

static esp_err_t enroll_start_h(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);

    char *body = read_body(req);
    if (!body) return bad_request(req, "missing body");
    cJSON *in = cJSON_Parse(body);
    free(body);
    if (!in) return bad_request(req, "malformed json");

    cJSON *jid = cJSON_GetObjectItem(in, "employee_id");
    cJSON *jf  = cJSON_GetObjectItem(in, "finger");
    if (!cJSON_IsNumber(jid)) {
        cJSON_Delete(in);
        return bad_request(req, "employee_id required");
    }
    uint16_t id = (uint16_t)jid->valuedouble;
    uint8_t finger = cJSON_IsNumber(jf) ? (uint8_t)jf->valuedouble : 0;
    cJSON_Delete(in);

    uint32_t session = 0;
    esp_err_t err = attend_enroll_begin(id, finger, &session);
    if (err == ESP_ERR_INVALID_STATE) {
        return bad_request(req, "an enrolment is already running");
    }
    if (err == ESP_ERR_NOT_FOUND) {
        return bad_request(req, "create the employee first");
    }
    if (err != ESP_OK) {
        return bad_request(req, "could not start enrolment");
    }
    return send_json(req, enroll_json());
}

static esp_err_t enroll_get_h(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);
    return send_json(req, enroll_json());
}

static esp_err_t enroll_cancel_h(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);

    char query[48], val[16];
    uint32_t session = 0;
    if (httpd_req_get_url_query_str(req, query, sizeof(query)) == ESP_OK &&
        httpd_query_key_value(query, "session_id", val, sizeof(val)) == ESP_OK) {
        session = strtoul(val, NULL, 10);
    }
    if (attend_enroll_cancel(session) != ESP_OK) {
        return bad_request(req, "session_id does not match the active enrolment");
    }
    return send_json(req, enroll_json());
}

/* ------------------------------------------------------------- notify -- */

/* The bot token is never sent back in full: anyone holding it can post as the
 * bot. The app shows the last few characters to confirm which one is set. */
static cJSON *notify_json(void)
{
    notify_cfg_t c;
    notify_status_t st;
    notify_get_cfg(&c);
    notify_get_status(&st);

    cJSON *o = cJSON_CreateObject();
    cJSON_AddBoolToObject(o, "enabled", c.enabled);
    cJSON_AddBoolToObject(o, "each_punch", c.each_punch);
    cJSON_AddBoolToObject(o, "late", c.late);
    cJSON_AddNumberToObject(o, "summary_minute", c.summary_min);
    cJSON_AddStringToObject(o, "chat_id", c.chat_id);
    size_t tl = strlen(c.bot_token);
    cJSON_AddBoolToObject(o, "has_bot_token", tl > 0);
    cJSON_AddStringToObject(o, "bot_token_hint", tl > 4 ? c.bot_token + tl - 4 : "");

    cJSON_AddNumberToObject(o, "sent", st.sent);
    cJSON_AddNumberToObject(o, "failed", st.failed);
    cJSON_AddNumberToObject(o, "dropped", st.dropped);
    cJSON_AddNumberToObject(o, "queued", st.queued);
    cJSON_AddNumberToObject(o, "last_ok_epoch", st.last_ok_epoch);
    cJSON_AddStringToObject(o, "last_error", st.last_error);
    cJSON_AddNumberToObject(o, "roster_version", st.roster_version);
    cJSON_AddNumberToObject(o, "roster_days", st.roster_days);
    cJSON_AddNumberToObject(o, "roster_names", st.roster_names);
    cJSON_AddNumberToObject(o, "roster_first_day", st.roster_first_day);
    cJSON_AddNumberToObject(o, "roster_last_day", st.roster_last_day);
    return o;
}

static esp_err_t notify_get_h(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);
    return send_json(req, notify_json());
}

/* Partial update, like /config. An empty bot_token clears it. */
static esp_err_t notify_post_h(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);

    char *body = read_body(req);
    if (!body) return bad_request(req, "missing body");
    cJSON *in = cJSON_Parse(body);
    free(body);
    if (!in) return bad_request(req, "malformed json");

    notify_cfg_t c;
    notify_get_cfg(&c);
    cJSON *v;
    if ((v = cJSON_GetObjectItem(in, "enabled")) && cJSON_IsBool(v)) {
        c.enabled = cJSON_IsTrue(v);
    }
    if ((v = cJSON_GetObjectItem(in, "each_punch")) && cJSON_IsBool(v)) {
        c.each_punch = cJSON_IsTrue(v);
    }
    if ((v = cJSON_GetObjectItem(in, "late")) && cJSON_IsBool(v)) {
        c.late = cJSON_IsTrue(v);
    }
    if ((v = cJSON_GetObjectItem(in, "summary_minute")) && cJSON_IsNumber(v)) {
        c.summary_min = (int16_t)v->valuedouble;
    }
    if ((v = cJSON_GetObjectItem(in, "chat_id")) && cJSON_IsString(v)) {
        if (strlen(v->valuestring) >= sizeof(c.chat_id)) {
            cJSON_Delete(in);
            return bad_request(req, "chat_id too long");
        }
        strcpy(c.chat_id, v->valuestring);
    }
    if ((v = cJSON_GetObjectItem(in, "bot_token")) && cJSON_IsString(v)) {
        if (strlen(v->valuestring) >= sizeof(c.bot_token)) {
            cJSON_Delete(in);
            return bad_request(req, "bot_token too long");
        }
        strcpy(c.bot_token, v->valuestring);
    }
    cJSON_Delete(in);

    if (notify_set_cfg(&c) != ESP_OK) {
        return bad_request(req, "could not store settings");
    }
    return send_json(req, notify_json());
}

static esp_err_t notify_test_h(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);
    if (notify_test() != ESP_OK) {
        return bad_request(req, "notifier busy or not running");
    }
    return send_json(req, notify_json());
}

static esp_err_t notify_summary_h(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);
    if (notify_summary_now() != ESP_OK) {
        return bad_request(req, "notifier busy or not running");
    }
    return send_json(req, notify_json());
}

/* Names as text and who is expected when, for the next couple of weeks. The
 * PC sends it only when it changed, and the terminal judges lateness and the
 * daily summary against it -- the PC can be off in between. */
static esp_err_t roster_post_h(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);

    char *body = read_body_max(req, 20 * 1024);
    if (!body) return bad_request(req, "missing or oversized body");
    cJSON *in = cJSON_Parse(body);
    free(body);
    if (!in) return bad_request(req, "malformed json");

    cJSON *jv = cJSON_GetObjectItem(in, "version");
    cJSON *jn = cJSON_GetObjectItem(in, "names_b64");
    cJSON *jd = cJSON_GetObjectItem(in, "days_b64");
    cJSON *jtz = cJSON_GetObjectItem(in, "tz_offset_min");
    if (!cJSON_IsNumber(jv) || !cJSON_IsString(jn) || !cJSON_IsString(jd)) {
        cJSON_Delete(in);
        return bad_request(req, "version, names_b64 and days_b64 required");
    }

    size_t nb = strlen(jn->valuestring), db = strlen(jd->valuestring);
    uint8_t *names = malloc(nb * 3 / 4 + 4);
    uint8_t *days = malloc(db * 3 / 4 + 4);
    size_t nlen = 0, dlen = 0;
    esp_err_t err = ESP_ERR_INVALID_ARG;
    if (names && days &&
        mbedtls_base64_decode(names, nb * 3 / 4 + 4, &nlen,
                              (const unsigned char *)jn->valuestring, nb) == 0 &&
        mbedtls_base64_decode(days, db * 3 / 4 + 4, &dlen,
                              (const unsigned char *)jd->valuestring, db) == 0) {
        err = notify_set_roster((uint32_t)jv->valuedouble, names, nlen, days, dlen);
    }
    free(names);
    free(days);

    /* The local date is what "today" means for lateness and the summary, so
     * the PC keeps the terminal's offset in step with its own (DST included). */
    if (err == ESP_OK && cJSON_IsNumber(jtz)) {
        int16_t tz = (int16_t)jtz->valuedouble;
        if (tz != cfg()->tz_offset_min) {
            device_cfg_t next = *cfg();
            next.tz_offset_min = tz;
            cfg_update(&next);
        }
    }
    cJSON_Delete(in);

    if (err != ESP_OK) {
        return bad_request(req, err == ESP_ERR_INVALID_SIZE ? "roster too large"
                                                            : "roster rejected");
    }
    return send_json(req, notify_json());
}

/* --------------------------------------------------------------- wifi -- */

static const char *wifi_state_str(net_wifi_state_t s)
{
    switch (s) {
    case NET_WIFI_CONNECTING: return "connecting";
    case NET_WIFI_CONNECTED:  return "connected";
    case NET_WIFI_FAILED:     return "failed";
    default:                  return "off";
    }
}

/* The password is write-only, like the bot token. */
static cJSON *wifi_json(void)
{
    net_wifi_status_t st;
    net_wifi_get_status(&st);
    cJSON *o = cJSON_CreateObject();
    cJSON_AddBoolToObject(o, "configured", st.configured);
    cJSON_AddStringToObject(o, "ssid", st.ssid);
    cJSON_AddStringToObject(o, "state", wifi_state_str(st.state));
    cJSON_AddStringToObject(o, "ip", st.ip);
    cJSON_AddNumberToObject(o, "rssi", st.rssi);
    cJSON_AddStringToObject(o, "last_error", st.last_error);
    cJSON_AddStringToObject(o, "active", net_active_iface());
    cJSON_AddBoolToObject(o, "eth_link", net_eth_link_up());
    return o;
}

static esp_err_t wifi_get_h(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);
    return send_json(req, wifi_json());
}

/* { "ssid": "...", "password": "..." }. An empty ssid forgets the network. */
static esp_err_t wifi_post_h(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);

    char *body = read_body(req);
    if (!body) return bad_request(req, "missing body");
    cJSON *in = cJSON_Parse(body);
    free(body);
    if (!in) return bad_request(req, "malformed json");

    cJSON *js = cJSON_GetObjectItem(in, "ssid");
    cJSON *jp = cJSON_GetObjectItem(in, "password");
    if (!cJSON_IsString(js)) {
        cJSON_Delete(in);
        return bad_request(req, "ssid required");
    }
    esp_err_t err = net_wifi_set_credentials(
        js->valuestring, cJSON_IsString(jp) ? jp->valuestring : "");
    cJSON_Delete(in);
    if (err == ESP_ERR_INVALID_ARG) {
        return bad_request(req, "ssid up to 32 bytes; password empty or 8-64");
    }
    if (err != ESP_OK) {
        return bad_request(req, "could not store wifi settings");
    }
    return send_json(req, wifi_json());
}

static esp_err_t wifi_scan_h(httpd_req_t *req)
{
    if (!authorized(req)) return deny(req);

    net_wifi_ap_t *aps = calloc(20, sizeof(net_wifi_ap_t));
    if (!aps) {
        add_cors(req);
        httpd_resp_set_status(req, "503 Service Unavailable");
        return httpd_resp_sendstr(req, "{\"error\":\"oom\"}");
    }
    size_t n = 0;
    esp_err_t err = net_wifi_scan(aps, 20, &n);
    if (err != ESP_OK) {
        free(aps);
        return bad_request(req, "scan failed - wifi busy connecting, try again");
    }
    cJSON *arr = cJSON_CreateArray();
    for (size_t i = 0; i < n; i++) {
        cJSON *a = cJSON_CreateObject();
        cJSON_AddStringToObject(a, "ssid", aps[i].ssid);
        cJSON_AddNumberToObject(a, "rssi", aps[i].rssi);
        cJSON_AddBoolToObject(a, "secure", aps[i].secure);
        cJSON_AddItemToArray(arr, a);
    }
    free(aps);
    cJSON *o = cJSON_CreateObject();
    cJSON_AddItemToObject(o, "networks", arr);
    return send_json(req, o);
}

/* ---------------------------------------------------------------- start -- */

static const httpd_uri_t URIS[] = {
    { .uri = "/api/v1/info",       .method = HTTP_GET,  .handler = info_get   },
    { .uri = "/api/v1/health",     .method = HTTP_GET,  .handler = health_get },
    { .uri = "/api/v1/events",     .method = HTTP_GET,  .handler = events_get },
    { .uri = "/api/v1/events/ack", .method = HTTP_POST, .handler = ack_post   },
    { .uri = "/api/v1/time",       .method = HTTP_POST, .handler = time_post  },
    { .uri = "/api/v1/users",         .method = HTTP_GET,    .handler = users_get_h     },
    { .uri = "/api/v1/users",         .method = HTTP_POST,   .handler = users_post_h    },
    { .uri = "/api/v1/users",         .method = HTTP_DELETE, .handler = users_delete_h  },
    { .uri = "/api/v1/enroll",        .method = HTTP_GET,    .handler = enroll_get_h    },
    { .uri = "/api/v1/enroll/start",  .method = HTTP_POST,   .handler = enroll_start_h  },
    { .uri = "/api/v1/enroll/cancel", .method = HTTP_POST,   .handler = enroll_cancel_h },
    { .uri = "/api/v1/config",        .method = HTTP_GET,    .handler = config_get      },
    { .uri = "/api/v1/config",        .method = HTTP_POST,   .handler = config_post     },
    { .uri = "/api/v1/strings",       .method = HTTP_POST,   .handler = strings_post    },
    { .uri = "/api/v1/reset",         .method = HTTP_POST,   .handler = reset_post      },
    { .uri = "/api/v1/screen",        .method = HTTP_GET,    .handler = screen_get      },
    { .uri = "/api/v1/notify",         .method = HTTP_GET,  .handler = notify_get_h     },
    { .uri = "/api/v1/notify",         .method = HTTP_POST, .handler = notify_post_h    },
    { .uri = "/api/v1/notify/test",    .method = HTTP_POST, .handler = notify_test_h    },
    { .uri = "/api/v1/notify/summary", .method = HTTP_POST, .handler = notify_summary_h },
    { .uri = "/api/v1/roster",         .method = HTTP_POST, .handler = roster_post_h    },
    { .uri = "/api/v1/wifi",           .method = HTTP_GET,  .handler = wifi_get_h       },
    { .uri = "/api/v1/wifi",           .method = HTTP_POST, .handler = wifi_post_h      },
    { .uri = "/api/v1/wifi/scan",      .method = HTTP_GET,  .handler = wifi_scan_h      },
};

esp_err_t api_server_start(void)
{
    token_load_or_create();

    httpd_config_t cfg = HTTPD_DEFAULT_CONFIG();
    /* Derived from the route table plus the wildcard OPTIONS catch-all, with
     * room to grow. Hard-coding this to the exact route count silently drops
     * the last registration -- which was the preflight handler, so every
     * browser request came back 405 and the whole app stopped working. */
    cfg.max_uri_handlers = (sizeof(URIS) / sizeof(URIS[0])) + 8;
    cfg.lru_purge_enable = true;
    cfg.uri_match_fn = httpd_uri_match_wildcard;   /* needed for the OPTIONS catch-all */
    cfg.stack_size = 8192;                          /* cJSON is stack-hungry */

    esp_err_t err = httpd_start(&s_server, &cfg);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "httpd_start failed: %s", esp_err_to_name(err));
        return err;
    }

    for (size_t i = 0; i < sizeof(URIS) / sizeof(URIS[0]); i++) {
        esp_err_t rerr = httpd_register_uri_handler(s_server, &URIS[i]);
        if (rerr != ESP_OK) {
            ESP_LOGE(TAG, "route %s failed to register: %s",
                     URIS[i].uri, esp_err_to_name(rerr));
        }
    }

    /* Registered last so the specific routes above win the match. Losing this
     * one breaks every browser request, so do not let it fail quietly. */
    const httpd_uri_t preflight = {
        .uri = "/*", .method = HTTP_OPTIONS, .handler = options_handler
    };
    esp_err_t perr = httpd_register_uri_handler(s_server, &preflight);
    if (perr != ESP_OK) {
        ESP_LOGE(TAG, "CORS preflight handler NOT registered (%s) - the web "
                      "app will fail every request with 405",
                 esp_err_to_name(perr));
    }

    ESP_LOGI(TAG, "listening on port %d, token %s", cfg.server_port, s_token);
    return ESP_OK;
}
