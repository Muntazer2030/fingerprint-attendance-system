#pragma once
/* Telegram notifications, sent by the terminal itself so they keep arriving
 * with the PC switched off.
 *
 * The device still knows nothing about shifts on its own (D1). The PC pushes a
 * "roster" -- names as text plus the expected start time per employee for the
 * next couple of weeks -- and that is all lateness and the daily summary are
 * judged against. No roster for a day means no late alerts and a summary that
 * only lists who came in.
 *
 * Everything here lives in the raw "storage" partition, not NVS: NVS is 24 KB
 * and the name bitmaps already take most of it. */

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "esp_err.h"

#define NOTIFY_TOKEN_MAX 80
#define NOTIFY_CHAT_MAX  24

typedef struct {
    bool    enabled;
    bool    each_punch;      /* one message per check-in/out              */
    bool    late;            /* a message when a first check-in is late   */
    int16_t summary_min;     /* local minute of the day, -1 = no summary  */
    char    bot_token[NOTIFY_TOKEN_MAX];
    char    chat_id[NOTIFY_CHAT_MAX];
} notify_cfg_t;

typedef struct {
    uint32_t sent;
    uint32_t failed;
    uint32_t dropped;        /* queue full, or gave up after retries       */
    uint32_t queued;
    uint32_t last_ok_epoch;
    uint32_t roster_version; /* opaque, chosen by the PC; 0 = none         */
    uint16_t roster_days;
    uint16_t roster_names;
    uint32_t roster_first_day; /* yyyymmdd, 0 = none                       */
    uint32_t roster_last_day;
    char     last_error[96];
} notify_status_t;

esp_err_t notify_init(void);

void      notify_get_cfg(notify_cfg_t *out);
esp_err_t notify_set_cfg(const notify_cfg_t *in);

/* Forgets the bot, the chat and the roster. */
esp_err_t notify_reset(void);

/* Called after a punch is safely in the event log. Never blocks: the work is
 * handed to the notifier task. */
void notify_punch(uint16_t employee, bool out, uint32_t epoch, uint32_t seq,
                  bool provisional);

esp_err_t notify_test(void);
esp_err_t notify_summary_now(void);

/* names: repeated { u16 id, u8 len, len bytes UTF-8 }
 * days:  repeated { u32 yyyymmdd, u16 n, n x { u16 id, i16 start_min, u8 grace,
 *                   u8 reserved } }   start_min -1 = expected, no fixed start
 * All little-endian. Validated before it replaces the stored roster. */
esp_err_t notify_set_roster(uint32_t version, const uint8_t *names, size_t nlen,
                            const uint8_t *days, size_t dlen);

void notify_get_status(notify_status_t *out);
