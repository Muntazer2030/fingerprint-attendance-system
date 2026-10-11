#pragma once
/* Employee and sensor-slot registry, persisted in NVS.
 *
 * One employee maps to SEVERAL slots -- staff enrol 2-3 fingers each because
 * optical readers fail on wet or worn hands (decision D5). So the mapping is
 * slot -> employee, never the reverse. */

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include "esp_err.h"

#define USERS_NAME_BITMAP_BYTES 256   /* 128x16 1bpp, shaped on the PC (D3) */

typedef struct {
    uint16_t id;          /* 0 = unused row */
    uint8_t  active;
    uint8_t  last_dir;    /* 0 = last punch was IN, 1 = OUT */
    uint32_t last_epoch;  /* used for duplicate suppression */
    uint16_t fail_count;  /* failed matches; surfaced on the dashboard (D5) */
    uint16_t pad;
} emp_entry_t;

esp_err_t users_init(void);

/* --- slots ------------------------------------------------------------- */

/* Employee owning a sensor slot, or 0 if the slot is free. */
uint16_t users_slot_owner(uint16_t slot);

/* Lowest free slot, or UINT16_MAX when the sensor library is full. */
uint16_t users_slot_alloc(uint16_t employee, uint8_t finger);

esp_err_t users_slot_release(uint16_t slot);
uint16_t  users_slot_count_for(uint16_t employee);
uint16_t  users_slots_used(void);

/* Walks occupied slots. Start with *cursor = 0; returns false when done. */
bool users_slot_next(uint16_t *cursor, uint16_t *slot, uint16_t *employee, uint8_t *finger);

/* --- employees --------------------------------------------------------- */

emp_entry_t *users_get(uint16_t id);
esp_err_t    users_upsert(uint16_t id, bool active);
esp_err_t    users_remove(uint16_t id);      /* also frees the employee's slots */
uint16_t     users_count(void);
bool         users_next(uint16_t *cursor, emp_entry_t *out);

/* Name bitmaps arrive from the Flutter app already shaped and RTL-ordered. */
esp_err_t users_set_name(uint16_t id, const uint8_t *bitmap, size_t len);
esp_err_t users_get_name(uint16_t id, uint8_t *out, size_t *len);

/* --- punch bookkeeping ------------------------------------------------- */

esp_err_t users_record_punch(uint16_t id, uint8_t dir, uint32_t epoch);
esp_err_t users_note_failure(uint16_t id);

/* Forgets every employee and slot mapping. The caller is responsible for
 * clearing the sensor library too, or the templates would be orphaned. */
esp_err_t users_clear_all(void);

/* Persists the tables. Called automatically by the mutators. */
esp_err_t users_commit(void);
