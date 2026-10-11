/* FPM12 fingerprint sensor driver -- EF01 packet protocol.
 *
 * Frame layout, all multi-byte fields big-endian:
 *
 *   EF 01 | AA AA AA AA | PID | LEN_hi LEN_lo | payload... | SUM_hi SUM_lo
 *
 * LEN counts the payload plus the two checksum bytes. SUM is a plain 16-bit
 * additive checksum over PID, both LEN bytes and the payload -- the header and
 * address are excluded, which is a common source of "why does every packet
 * fail" when writing this from scratch.
 */

#include <stdio.h>
#include <string.h>
#include <inttypes.h>
#include "fpm.h"
#include "board.h"
#include "esp_log.h"
#include "driver/uart.h"
#include "driver/gpio.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "fpm";

/* The console and the sensor cannot share pads. On the C3 the console UART is
 * U0TXD/U0RXD -- GPIO21/20, exactly the pins the SuperMini has left over for
 * the sensor. Both peripherals will happily attach through the GPIO matrix, so
 * nothing fails at boot: the sensor's RX just reads the log output back and the
 * sensor looks dead. That cost a debugging session once. Refuse to build it.
 * sdkconfig.c3supermini moves the console to USB, which frees the pair. */
#if CONFIG_IDF_TARGET_ESP32C3 && CONFIG_ESP_CONSOLE_UART_DEFAULT
#  if PIN_FPM_TX == 20 || PIN_FPM_TX == 21 || PIN_FPM_RX == 20 || PIN_FPM_RX == 21
#    error "FPM UART is on GPIO20/21, which the console UART already owns. Build with SDKCONFIG_DEFAULTS including sdkconfig.c3supermini (CONFIG_ESP_CONSOLE_USB_SERIAL_JTAG=y)."
#  endif
#endif

#define UART_PORT   UART_NUM_1
#define FPM_ADDRESS 0xFFFFFFFFu

#define PID_COMMAND  0x01
#define PID_DATA     0x02
#define PID_ACK      0x07
#define PID_END_DATA 0x08

/* command codes */
#define CMD_GEN_IMG     0x01
#define CMD_IMG2TZ      0x02
#define CMD_SEARCH      0x04
#define CMD_REG_MODEL   0x05
#define CMD_STORE       0x06
#define CMD_LOAD        0x07
#define CMD_UP_CHAR     0x08
#define CMD_DOWN_CHAR   0x09
#define CMD_DELETE      0x0C
#define CMD_EMPTY       0x0D
#define CMD_READ_PARAMS 0x0F
#define CMD_TEMPL_COUNT 0x1D

#define RX_TIMEOUT_MS 2000
#define MAX_PAYLOAD   288

static uint8_t s_last_confirm;
/* Real library size, learned at init. The vendor page for this module
 * claims 1000 templates; the hardware reports 240. Always ask the chip. */
static uint16_t s_capacity;

uint8_t fpm_last_confirm(void) { return s_last_confirm; }

const char *fpm_confirm_str(uint8_t c)
{
    switch (c) {
    case 0x00: return "ok";
    case 0x01: return "packet receive error";
    case 0x02: return "no finger on sensor";
    case 0x03: return "imaging failed";
    case 0x06: return "image too messy";
    case 0x07: return "too few feature points";
    case 0x08: return "fingers do not match";
    case 0x09: return "no matching finger found";
    case 0x0A: return "failed to combine character files";
    case 0x0B: return "page id beyond library";
    case 0x0C: return "error reading template";
    case 0x0D: return "error uploading template";
    case 0x0E: return "cannot receive following packets";
    case 0x0F: return "error uploading image";
    case 0x10: return "failed to delete template";
    case 0x11: return "failed to clear library";
    case 0x15: return "no valid primary image";
    case 0x18: return "flash write error";
    case 0x20: return "address code incorrect";
    case 0x21: return "password must be verified";
    default:   return "unknown";
    }
}

/* ------------------------------------------------------------- transport -- */

static esp_err_t send_command(uint8_t cmd, const uint8_t *args, size_t arglen)
{
    uint8_t f[9 + 16 + 2];
    if (arglen > 16) {
        return ESP_ERR_INVALID_ARG;
    }

    size_t len = arglen + 3;   /* cmd + payload + 2 checksum bytes */
    size_t i = 0;

    f[i++] = 0xEF;
    f[i++] = 0x01;
    f[i++] = (FPM_ADDRESS >> 24) & 0xFF;
    f[i++] = (FPM_ADDRESS >> 16) & 0xFF;
    f[i++] = (FPM_ADDRESS >> 8) & 0xFF;
    f[i++] = FPM_ADDRESS & 0xFF;
    f[i++] = PID_COMMAND;
    f[i++] = (len >> 8) & 0xFF;
    f[i++] = len & 0xFF;
    f[i++] = cmd;
    memcpy(&f[i], args, arglen);
    i += arglen;

    /* Checksum spans PID, length and payload -- not the header or address. */
    uint16_t sum = 0;
    for (size_t k = 6; k < i; k++) {
        sum += f[k];
    }
    f[i++] = (sum >> 8) & 0xFF;
    f[i++] = sum & 0xFF;

    uart_flush_input(UART_PORT);
    int written = uart_write_bytes(UART_PORT, f, i);
    return (written == (int)i) ? ESP_OK : ESP_FAIL;
}

static esp_err_t read_exact(uint8_t *dst, size_t n, int timeout_ms)
{
    int got = uart_read_bytes(UART_PORT, dst, n, pdMS_TO_TICKS(timeout_ms));
    return (got == (int)n) ? ESP_OK : ESP_ERR_TIMEOUT;
}

/* Reads one frame. payload excludes the confirmation/first byte handling --
 * the caller gets the whole payload including the confirmation code. */
static esp_err_t recv_frame(uint8_t *pid, uint8_t *payload, size_t cap, size_t *plen)
{
    uint8_t hdr[9];

    /* Resynchronise on the 0xEF 0x01 header rather than assuming alignment;
     * a timed-out previous exchange can leave bytes in the pipe. */
    int64_t deadline_guard = 0;
    while (1) {
        if (read_exact(&hdr[0], 1, RX_TIMEOUT_MS) != ESP_OK) {
            return ESP_ERR_TIMEOUT;
        }
        if (hdr[0] != 0xEF) {
            if (++deadline_guard > 64) {
                return ESP_ERR_INVALID_RESPONSE;
            }
            continue;
        }
        if (read_exact(&hdr[1], 1, RX_TIMEOUT_MS) != ESP_OK) {
            return ESP_ERR_TIMEOUT;
        }
        if (hdr[1] == 0x01) {
            break;
        }
    }

    if (read_exact(&hdr[2], 7, RX_TIMEOUT_MS) != ESP_OK) {
        return ESP_ERR_TIMEOUT;
    }

    *pid = hdr[6];
    size_t len = ((size_t)hdr[7] << 8) | hdr[8];
    if (len < 2 || len - 2 > cap || len - 2 > MAX_PAYLOAD) {
        return ESP_ERR_INVALID_SIZE;
    }
    size_t n = len - 2;

    if (read_exact(payload, n, RX_TIMEOUT_MS) != ESP_OK) {
        return ESP_ERR_TIMEOUT;
    }

    uint8_t sumb[2];
    if (read_exact(sumb, 2, RX_TIMEOUT_MS) != ESP_OK) {
        return ESP_ERR_TIMEOUT;
    }

    uint16_t sum = hdr[6] + hdr[7] + hdr[8];
    for (size_t k = 0; k < n; k++) {
        sum += payload[k];
    }
    if (sum != (((uint16_t)sumb[0] << 8) | sumb[1])) {
        ESP_LOGW(TAG, "checksum mismatch");
        return ESP_ERR_INVALID_CRC;
    }

    *plen = n;
    return ESP_OK;
}

/* Maps the sensor's confirmation byte onto esp_err_t, keeping the two
 * "normal" outcomes distinguishable from real faults. */
static esp_err_t confirm_to_err(uint8_t c)
{
    s_last_confirm = c;
    switch (c) {
    case 0x00: return ESP_OK;
    case 0x02: return ESP_ERR_NOT_FOUND;        /* no finger -- idle, not a fault */
    case 0x09: return ESP_ERR_NOT_FOUND;        /* no match  -- normal outcome    */
    case 0x08: return ESP_ERR_INVALID_STATE;    /* scans were different fingers   */
    case 0x06:
    case 0x07:
    case 0x15: return ESP_ERR_INVALID_RESPONSE; /* poor image quality             */
    default:   return ESP_FAIL;
    }
}

/* Command, then a single ACK frame. Extra payload beyond the confirmation
 * byte is copied out when the caller wants it. */
static esp_err_t txn(uint8_t cmd, const uint8_t *args, size_t arglen,
                     uint8_t *extra, size_t extra_cap, size_t *extra_len)
{
    esp_err_t err = send_command(cmd, args, arglen);
    if (err != ESP_OK) {
        return err;
    }

    uint8_t pid = 0, payload[MAX_PAYLOAD];
    size_t n = 0;
    err = recv_frame(&pid, payload, sizeof(payload), &n);
    if (err != ESP_OK) {
        return err;
    }
    if (pid != PID_ACK || n < 1) {
        return ESP_ERR_INVALID_RESPONSE;
    }

    if (extra && extra_len) {
        size_t copy = n - 1;
        if (copy > extra_cap) {
            copy = extra_cap;
        }
        memcpy(extra, &payload[1], copy);
        *extra_len = copy;
    }
    return confirm_to_err(payload[0]);
}

/* ------------------------------------------------------------------ api -- */

esp_err_t fpm_init(void)
{
    const uart_config_t cfg = {
        .baud_rate = CONFIG_ATT_FPM_BAUD,
        .data_bits = UART_DATA_8_BITS,
        .parity    = UART_PARITY_DISABLE,
        .stop_bits = UART_STOP_BITS_1,
        .flow_ctrl = UART_HW_FLOWCTRL_DISABLE,
        .source_clk = UART_SCLK_DEFAULT,
    };
    ESP_ERROR_CHECK(uart_driver_install(UART_PORT, 1024, 0, 0, NULL, 0));
    ESP_ERROR_CHECK(uart_param_config(UART_PORT, &cfg));
    ESP_ERROR_CHECK(uart_set_pin(UART_PORT, PIN_FPM_TX, PIN_FPM_RX,
                                 UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE));

    if (PIN_FPM_DETECT >= 0) {
        gpio_config_t det = {
            .pin_bit_mask = PIN_MASK(PIN_FPM_DETECT),
            .mode = GPIO_MODE_INPUT,
        };
        gpio_config(&det);
    }

    ESP_LOGI(TAG, "uart%d tx=%d rx=%d @%d baud, detect=%d",
             UART_PORT, PIN_FPM_TX, PIN_FPM_RX, CONFIG_ATT_FPM_BAUD, PIN_FPM_DETECT);
    return ESP_OK;
}

/* One baud sweep in whatever pin orientation is currently set. */
static esp_err_t probe_sweep(uint32_t *found_baud)
{
    static const uint32_t RATES[] = {
        57600, 9600, 115200, 19200, 38400,   /* the rates actually shipped */
        28800, 48000, 67200, 76800, 86400, 96000, 105600,
    };

    uint8_t rx[32];
    int total = 0;

    for (size_t i = 0; i < sizeof(RATES) / sizeof(RATES[0]); i++) {
        if (uart_set_baudrate(UART_PORT, RATES[i]) != ESP_OK) {
            continue;
        }
        uart_flush_input(UART_PORT);

        /* Read-params is the cheapest command the sensor must always answer. */
        if (send_command(CMD_READ_PARAMS, NULL, 0) != ESP_OK) {
            continue;
        }

        int got = uart_read_bytes(UART_PORT, rx, sizeof(rx), pdMS_TO_TICKS(300));
        if (got <= 0) {
            ESP_LOGW(TAG, "  %6" PRIu32 " baud - silence", RATES[i]);
            continue;
        }
        total += got;

        char hex[3 * 16 + 1];
        int n = got < 16 ? got : 16;
        for (int k = 0; k < n; k++) {
            sprintf(&hex[k * 3], "%02X ", rx[k]);
        }
        hex[n * 3] = 0;

        if (got >= 2 && rx[0] == 0xEF && rx[1] == 0x01) {
            ESP_LOGW(TAG, "  %6" PRIu32 " baud - ANSWERED: %s", RATES[i], hex);
            if (found_baud) {
                *found_baud = RATES[i];
            }
            uart_flush_input(UART_PORT);
            return ESP_OK;
        }
        ESP_LOGW(TAG, "  %6" PRIu32 " baud - %d bytes, not a frame: %s",
                 RATES[i], got, hex);
    }

    return total ? ESP_ERR_INVALID_RESPONSE : ESP_ERR_TIMEOUT;
}

/* Bring-up probe, run only when the sensor did not answer.
 *
 * ESP_ERR_TIMEOUT cannot tell apart the real causes -- nothing on the RX wire,
 * the pair swapped, or the sensor sitting at a different rate -- and each needs
 * a completely different fix. So sweep every rate an FPM12 can be set to (its
 * baud register is N x 9600), in both pin orientations, and report the raw
 * bytes seen. Trying the swap here rather than asking for a rewire matters:
 * wire colours vary between batches, and each guess otherwise costs a flash
 * cycle. Nothing is driven into a wrong pin -- a UART TX pad that the sensor
 * is not listening to is simply ignored.
 *
 * Leaves the port at the orientation and rate that answered, or restores the
 * configured pair. */
esp_err_t fpm_probe(uint32_t *found_baud, bool *swapped)
{
    if (PIN_FPM_DETECT >= 0) {
        ESP_LOGW(TAG, "probe: detect line GPIO%d reads %d",
                 PIN_FPM_DETECT, gpio_get_level(PIN_FPM_DETECT));
    }

    ESP_LOGW(TAG, "probe: as wired, tx=GPIO%d rx=GPIO%d", PIN_FPM_TX, PIN_FPM_RX);
    esp_err_t first = probe_sweep(found_baud);
    if (first == ESP_OK) {
        if (swapped) {
            *swapped = false;
        }
        return ESP_OK;
    }

    ESP_LOGW(TAG, "probe: swapped, tx=GPIO%d rx=GPIO%d", PIN_FPM_RX, PIN_FPM_TX);
    uart_set_pin(UART_PORT, PIN_FPM_RX, PIN_FPM_TX,
                 UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE);
    esp_err_t second = probe_sweep(found_baud);
    if (second == ESP_OK) {
        if (swapped) {
            *swapped = true;
        }
        return ESP_OK;
    }

    uart_set_pin(UART_PORT, PIN_FPM_TX, PIN_FPM_RX,
                 UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE);
    uart_set_baudrate(UART_PORT, CONFIG_ATT_FPM_BAUD);

    return (first == ESP_ERR_INVALID_RESPONSE || second == ESP_ERR_INVALID_RESPONSE)
               ? ESP_ERR_INVALID_RESPONSE : ESP_ERR_TIMEOUT;
}

bool fpm_finger_present(void)
{
    if (PIN_FPM_DETECT < 0) {
        return true;   /* no detect line: caller must poll the sensor */
    }
    return gpio_get_level(PIN_FPM_DETECT) != 0;
}

esp_err_t fpm_read_params(fpm_params_t *out)
{
    uint8_t d[16];
    size_t n = 0;
    esp_err_t err = txn(CMD_READ_PARAMS, NULL, 0, d, sizeof(d), &n);
    if (err != ESP_OK) {
        return err;
    }
    if (n < 16) {
        return ESP_ERR_INVALID_SIZE;
    }

    out->status      = (d[0] << 8) | d[1];
    out->sys_id      = (d[2] << 8) | d[3];
    out->capacity    = (d[4] << 8) | d[5];
    out->security    = (d[6] << 8) | d[7];
    out->address     = ((uint32_t)d[8] << 24) | ((uint32_t)d[9] << 16) |
                       ((uint32_t)d[10] << 8) | d[11];
    out->packet_size = 32u << (((d[12] << 8) | d[13]) & 0x03);
    out->baud        = (uint32_t)(((d[14] << 8) | d[15]) * 9600);

    s_capacity = out->capacity;
    return ESP_OK;
}

esp_err_t fpm_template_count(uint16_t *out)
{
    uint8_t d[2];
    size_t n = 0;
    esp_err_t err = txn(CMD_TEMPL_COUNT, NULL, 0, d, sizeof(d), &n);
    if (err == ESP_OK && n >= 2) {
        *out = (d[0] << 8) | d[1];
    }
    return err;
}

esp_err_t fpm_gen_img(void)
{
    return txn(CMD_GEN_IMG, NULL, 0, NULL, 0, NULL);
}

esp_err_t fpm_img2tz(uint8_t buf)
{
    return txn(CMD_IMG2TZ, &buf, 1, NULL, 0, NULL);
}

esp_err_t fpm_reg_model(void)
{
    return txn(CMD_REG_MODEL, NULL, 0, NULL, 0, NULL);
}

esp_err_t fpm_store(uint8_t buf, uint16_t page)
{
    const uint8_t a[3] = { buf, (uint8_t)(page >> 8), (uint8_t)page };
    return txn(CMD_STORE, a, sizeof(a), NULL, 0, NULL);
}

esp_err_t fpm_load(uint8_t buf, uint16_t page)
{
    const uint8_t a[3] = { buf, (uint8_t)(page >> 8), (uint8_t)page };
    return txn(CMD_LOAD, a, sizeof(a), NULL, 0, NULL);
}

esp_err_t fpm_delete(uint16_t page, uint16_t count)
{
    const uint8_t a[4] = { (uint8_t)(page >> 8), (uint8_t)page,
                           (uint8_t)(count >> 8), (uint8_t)count };
    return txn(CMD_DELETE, a, sizeof(a), NULL, 0, NULL);
}

esp_err_t fpm_empty(void)
{
    return txn(CMD_EMPTY, NULL, 0, NULL, 0, NULL);
}

esp_err_t fpm_search(uint8_t buf, uint16_t *page, uint16_t *score)
{
    /* Searching beyond the library size returns "page id beyond library"
     * rather than a match, so use what the sensor actually reports. */
    uint16_t span = s_capacity ? s_capacity : CONFIG_ATT_MAX_SLOTS;
    const uint8_t a[5] = { buf, 0x00, 0x00,
                           (uint8_t)(span >> 8), (uint8_t)span };
    uint8_t d[4];
    size_t n = 0;
    esp_err_t err = txn(CMD_SEARCH, a, sizeof(a), d, sizeof(d), &n);
    if (err == ESP_OK && n >= 4) {
        *page  = (d[0] << 8) | d[1];
        *score = (d[2] << 8) | d[3];
    }
    return err;
}

esp_err_t fpm_up_char(uint8_t buf, uint8_t *out, size_t *len)
{
    esp_err_t err = txn(CMD_UP_CHAR, &buf, 1, NULL, 0, NULL);
    if (err != ESP_OK) {
        return err;
    }

    /* The sensor now streams data frames until one carries PID_END_DATA. */
    size_t total = 0;
    while (1) {
        uint8_t pid = 0, payload[MAX_PAYLOAD];
        size_t n = 0;
        err = recv_frame(&pid, payload, sizeof(payload), &n);
        if (err != ESP_OK) {
            return err;
        }
        if (pid != PID_DATA && pid != PID_END_DATA) {
            return ESP_ERR_INVALID_RESPONSE;
        }
        if (total + n > FPM_TEMPLATE_BYTES) {
            return ESP_ERR_INVALID_SIZE;
        }
        memcpy(out + total, payload, n);
        total += n;
        if (pid == PID_END_DATA) {
            break;
        }
    }
    *len = total;
    return ESP_OK;
}

esp_err_t fpm_down_char(uint8_t buf, const uint8_t *in, size_t len)
{
    esp_err_t err = txn(CMD_DOWN_CHAR, &buf, 1, NULL, 0, NULL);
    if (err != ESP_OK) {
        return err;
    }

    const size_t chunk = 128;
    size_t off = 0;
    while (off < len) {
        size_t n = len - off;
        if (n > chunk) {
            n = chunk;
        }
        bool last = (off + n >= len);

        uint8_t f[9 + chunk + 2];
        size_t i = 0;
        f[i++] = 0xEF;
        f[i++] = 0x01;
        f[i++] = (FPM_ADDRESS >> 24) & 0xFF;
        f[i++] = (FPM_ADDRESS >> 16) & 0xFF;
        f[i++] = (FPM_ADDRESS >> 8) & 0xFF;
        f[i++] = FPM_ADDRESS & 0xFF;
        f[i++] = last ? PID_END_DATA : PID_DATA;
        size_t plen = n + 2;
        f[i++] = (plen >> 8) & 0xFF;
        f[i++] = plen & 0xFF;
        memcpy(&f[i], in + off, n);
        i += n;

        uint16_t sum = 0;
        for (size_t k = 6; k < i; k++) {
            sum += f[k];
        }
        f[i++] = (sum >> 8) & 0xFF;
        f[i++] = sum & 0xFF;

        if (uart_write_bytes(UART_PORT, f, i) != (int)i) {
            return ESP_FAIL;
        }
        off += n;
    }
    return ESP_OK;
}
