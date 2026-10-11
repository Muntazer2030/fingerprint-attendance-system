#pragma once
/* FPM12 optical fingerprint sensor (R307 / ZFM-20 family, EF01 protocol).
 * UART at 57600, 3.3 V logic on a 5 V supply -- see docs/wiring.md. */

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include "esp_err.h"

/* A character-file buffer inside the sensor. Enrolment needs both. */
#define FPM_BUF1 1
#define FPM_BUF2 2

/* Templates are 512 bytes in this family. Backed up to flash and to the PC
 * so a dead sensor is a swap, not 50 re-enrolments (decision D4). */
#define FPM_TEMPLATE_BYTES 512

typedef struct {
    uint16_t status;
    uint16_t sys_id;
    uint16_t capacity;      /* how many templates the library holds */
    uint16_t security;      /* 1..5, higher = stricter matching */
    uint32_t address;
    uint16_t packet_size;   /* bytes: 32 / 64 / 128 / 256 */
    uint32_t baud;
} fpm_params_t;

esp_err_t fpm_init(void);

/* True when the sensor's hardware finger-detect line is asserted. Lets the
 * app idle instead of polling the sensor over UART. */
bool fpm_finger_present(void);

/* Bring-up diagnostic for "the sensor does not answer". Sweeps every baud the
 * FPM12 supports and logs the raw bytes seen at each, so a dead wire, a swapped
 * pair and a wrong baud can be told apart. ESP_OK means it answered, and
 * *found_baud is the rate that worked; ESP_ERR_TIMEOUT means total silence;
 * ESP_ERR_INVALID_RESPONSE means bytes arrived but never formed a frame. */
esp_err_t fpm_probe(uint32_t *found_baud, bool *swapped);

esp_err_t fpm_read_params(fpm_params_t *out);
esp_err_t fpm_template_count(uint16_t *out);

/* Capture. Returns ESP_ERR_NOT_FOUND when no finger is on the platen -- that
 * is the normal idle result, not a fault. */
esp_err_t fpm_gen_img(void);

/* Turn the captured image into a character file in the given buffer. */
esp_err_t fpm_img2tz(uint8_t buf);

/* Combine buffers 1 and 2 into a template. ESP_ERR_INVALID_STATE means the
 * two scans did not come from the same finger. */
esp_err_t fpm_reg_model(void);

esp_err_t fpm_store(uint8_t buf, uint16_t page);
esp_err_t fpm_load(uint8_t buf, uint16_t page);
esp_err_t fpm_delete(uint16_t page, uint16_t count);
esp_err_t fpm_empty(void);

/* 1:N match against the library. ESP_ERR_NOT_FOUND = no match. */
esp_err_t fpm_search(uint8_t buf, uint16_t *page, uint16_t *score);

/* Template backup / restore. out must hold FPM_TEMPLATE_BYTES. */
esp_err_t fpm_up_char(uint8_t buf, uint8_t *out, size_t *len);
esp_err_t fpm_down_char(uint8_t buf, const uint8_t *in, size_t len);

/* Raw confirmation code from the last exchange, for logging. */
uint8_t fpm_last_confirm(void);
const char *fpm_confirm_str(uint8_t code);
