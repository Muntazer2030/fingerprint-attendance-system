#pragma once
/* Clock management. See docs/decisions.md D7 -- there is no hardware RTC, so
 * the design bounds the error rather than pretending it does not exist. */

#include <stdbool.h>
#include <stdint.h>
#include "esp_err.h"

typedef enum {
    TIME_SRC_NONE = 0,   /* never set: punches must be flagged provisional  */
    TIME_SRC_RESTORED,   /* recovered from NVS: plausible but stale         */
    TIME_SRC_PC,         /* set by the Flutter client over the LAN          */
    TIME_SRC_NTP,        /* confirmed against an internet time server       */
} time_source_t;

esp_err_t timesync_start(void);

/* True only when the clock was confirmed by NTP or the PC *this boot*.
 * A time restored from NVS deliberately does NOT count -- it is roughly right
 * but unverified, and events recorded against it stay provisional. */
bool timesync_is_authoritative(void);

time_source_t timesync_source(void);
const char *timesync_source_str(void);

/* Called by the API when a client sets the clock. */
void timesync_note_external_set(void);
