#pragma once
/* Attendance state machine: owns the fingerprint sensor, the display and the
 * buzzer. Runs on its own task so a ~1 s match never stalls the network. */

#include <stdint.h>
#include <stdbool.h>
#include "esp_err.h"

typedef enum {
    ENROLL_IDLE = 0,
    ENROLL_WAIT_FINGER,
    ENROLL_LIFT_FINGER,
    ENROLL_WAIT_AGAIN,
    ENROLL_MERGING,
    ENROLL_STORED,
    ENROLL_FAILED,
} enroll_state_t;

esp_err_t attend_start(void);

/* Begins an enrolment. Only one runs at a time; returns ESP_ERR_INVALID_STATE
 * if another is in progress. */
esp_err_t attend_enroll_begin(uint16_t employee, uint8_t finger, uint32_t *session);

/* Current enrolment state. slot is meaningful only in ENROLL_STORED. */
void attend_enroll_status(uint32_t *session, enroll_state_t *state,
                          uint16_t *slot, const char **detail);

esp_err_t attend_enroll_cancel(uint32_t session);

const char *attend_enroll_state_str(enroll_state_t s);

/* Forces the next punch's direction, as the touch button does. */
void attend_force_direction(bool out);
