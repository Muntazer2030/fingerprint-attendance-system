#pragma once
/* Append-only power-fail-safe event log in raw flash. See docs/protocol.md. */

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include "esp_err.h"

/* flags bits */
#define EV_FLAG_OUT          (1u << 0)  /* clear = IN, set = OUT */
#define EV_FLAG_MANUAL       (1u << 1)  /* entered by a manager, not scanned */
#define EV_FLAG_PROVISIONAL  (1u << 2)  /* clock was not yet synced (D7)      */
#define EV_FLAG_DUP_SUPPRESS (1u << 3)  /* rejected repeat within dup window  */

/* method values */
#define EV_METHOD_FINGER 0
#define EV_METHOD_MANUAL 1
#define EV_METHOD_PIN    2

typedef struct __attribute__((packed)) {
    uint32_t seq;       /* monotonic, assigned by evlog_append */
    uint32_t epoch;     /* UTC seconds */
    uint16_t employee;  /* 0 = unmatched */
    uint16_t slot;      /* sensor template slot that matched */
    uint8_t  flags;
    uint8_t  method;
    uint16_t crc;       /* CRC-16 over the preceding 14 bytes */
} event_rec_t;

_Static_assert(sizeof(event_rec_t) == 16, "event record must stay 16 bytes");

typedef struct {
    uint32_t capacity;   /* total record slots in the partition */
    uint32_t head_seq;   /* highest sequence written, 0 if empty */
    uint32_t oldest_seq; /* lowest sequence still retained */
    uint32_t ack_seq;    /* highest sequence the PC confirmed storing */
    uint32_t pending;    /* head_seq - ack_seq */
    bool     overflow;   /* unacked records were overwritten */
} evlog_stats_t;

esp_err_t evlog_init(void);

/* Assigns seq and crc, then persists. rec->seq is set on return. */
esp_err_t evlog_append(event_rec_t *rec);

/* Copies up to max records with seq > since into out, oldest first. */
esp_err_t evlog_read_since(uint32_t since, event_rec_t *out, size_t max, size_t *count);

/* Records that the PC has durably stored everything up to seq. */
esp_err_t evlog_ack(uint32_t seq);

void evlog_get_stats(evlog_stats_t *out);

/* Erases every stored punch and restarts the sequence at 1. Irreversible --
 * only reachable from an explicit operator action in the app. */
esp_err_t evlog_erase_all(void);
