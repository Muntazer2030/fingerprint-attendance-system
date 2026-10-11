/* Event log: a circular array of fixed 16-byte records in a raw flash
 * partition. No filesystem, deliberately -- a corrupted FS would cost us the
 * attendance history, whereas a torn record here just fails CRC and is skipped.
 *
 * Layout. Records are written strictly in sequence order, so the slot holding
 * sequence S is always (S - 1) % capacity. That makes reads direct-indexed
 * rather than a search, and makes recovery after power loss a matter of
 * finding the highest valid sequence on the medium.
 *
 * Erase. Flash erases a 4096-byte sector at a time (256 records). The sector
 * is erased immediately before its first record is written, which keeps the
 * invariant that everything from the write cursor to the end of its sector is
 * erased and ready.
 */

#include <inttypes.h>
#include <string.h>
#include "evlog.h"
#include "esp_log.h"
#include "esp_partition.h"
#include "esp_rom_crc.h"
#include "nvs.h"
#include "nvs_flash.h"
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"

static const char *TAG = "evlog";

#define SECTOR_BYTES    4096
#define RECS_PER_SECTOR (SECTOR_BYTES / (int)sizeof(event_rec_t))
#define NVS_NS          "evlog"
#define NVS_KEY_ACK     "ack"
#define NVS_KEY_FLOOR   "floor"

static const esp_partition_t *s_part;
static uint32_t s_capacity;
static uint32_t s_head_seq;   /* highest sequence written; 0 = empty */
static uint32_t s_ack_seq;

/* Every sequence at or below this was erased on purpose. Sequence numbers are
 * never reused: erasing used to reset the counter to 0, so the next punch was
 * numbered 1 again -- and the PC, which files punches by sequence number,
 * either waited forever for numbers it had already passed or overwrote old
 * attendance with new. Now an erase keeps counting from where it was. */
static uint32_t s_floor_seq;
static bool     s_overflow;
static SemaphoreHandle_t s_lock;

static uint16_t rec_crc(const event_rec_t *r)
{
    return esp_rom_crc16_le(0, (const uint8_t *)r, sizeof(*r) - sizeof(r->crc));
}

static bool rec_valid(const event_rec_t *r)
{
    /* Erased flash is all 0xFF, which is not a legal sequence number. */
    if (r->seq == 0 || r->seq == 0xFFFFFFFF) {
        return false;
    }
    return r->crc == rec_crc(r);
}

static esp_err_t read_slot(uint32_t idx, event_rec_t *out)
{
    return esp_partition_read(s_part, (size_t)idx * sizeof(event_rec_t),
                              out, sizeof(*out));
}

/* Highest valid sequence on the medium, scanning a sector at a time.
 * 640 KB takes well under a second and only happens at boot; a binary search
 * over a wrapped sequence with possible gaps is far easier to get wrong. */
static uint32_t scan_head_seq(void)
{
    static event_rec_t buf[RECS_PER_SECTOR];
    uint32_t best = 0;

    for (uint32_t base = 0; base < s_capacity; base += RECS_PER_SECTOR) {
        uint32_t n = s_capacity - base;
        if (n > (uint32_t)RECS_PER_SECTOR) {
            n = RECS_PER_SECTOR;
        }
        if (esp_partition_read(s_part, (size_t)base * sizeof(event_rec_t),
                               buf, n * sizeof(event_rec_t)) != ESP_OK) {
            continue;
        }
        for (uint32_t i = 0; i < n; i++) {
            if (rec_valid(&buf[i]) && buf[i].seq > best) {
                best = buf[i].seq;
            }
        }
    }
    return best;
}

static void load_marks(void)
{
    s_ack_seq = 0;
    s_floor_seq = 0;
    nvs_handle_t h;
    if (nvs_open(NVS_NS, NVS_READONLY, &h) != ESP_OK) {
        return;
    }
    if (nvs_get_u32(h, NVS_KEY_ACK, &s_ack_seq) != ESP_OK) {
        s_ack_seq = 0;
    }
    if (nvs_get_u32(h, NVS_KEY_FLOOR, &s_floor_seq) != ESP_OK) {
        s_floor_seq = 0;
    }
    nvs_close(h);
}

/* First sequence that can still exist on the medium. */
static uint32_t first_live_seq(void)
{
    uint32_t oldest = (s_head_seq > s_capacity) ? s_head_seq - s_capacity + 1 : 1;
    return (oldest > s_floor_seq) ? oldest : s_floor_seq + 1;
}

esp_err_t evlog_init(void)
{
    s_part = esp_partition_find_first(ESP_PARTITION_TYPE_DATA,
                                      (esp_partition_subtype_t)0x40, "events");
    if (!s_part) {
        ESP_LOGE(TAG, "events partition not found");
        return ESP_ERR_NOT_FOUND;
    }
    if (s_part->size % SECTOR_BYTES != 0) {
        ESP_LOGE(TAG, "partition must be a whole number of 4K sectors");
        return ESP_ERR_INVALID_SIZE;
    }

    s_lock = xSemaphoreCreateMutex();
    if (!s_lock) {
        return ESP_ERR_NO_MEM;
    }

    s_capacity = s_part->size / sizeof(event_rec_t);
    load_marks();
    s_head_seq = scan_head_seq();
    /* Right after an erase the medium is empty, but numbering continues from
     * the floor rather than restarting at 1. */
    if (s_head_seq < s_floor_seq) {
        s_head_seq = s_floor_seq;
    }

    /* An ack ahead of the head means the partition was erased while the PC
     * still remembers old sequences. Trusting it would hide every event until
     * the counter caught up, so clamp. */
    if (s_ack_seq > s_head_seq) {
        ESP_LOGW(TAG, "ack %" PRIu32 " ahead of head %" PRIu32 ", clamping",
                 s_ack_seq, s_head_seq);
        s_ack_seq = s_head_seq;
    }

    s_overflow = (s_head_seq > s_capacity) && (s_ack_seq < s_head_seq - s_capacity);

    ESP_LOGI(TAG, "capacity=%" PRIu32 " head=%" PRIu32 " ack=%" PRIu32
                  " pending=%" PRIu32, s_capacity, s_head_seq, s_ack_seq,
             s_head_seq - s_ack_seq);
    return ESP_OK;
}

esp_err_t evlog_append(event_rec_t *rec)
{
    if (!s_part || !rec) {
        return ESP_ERR_INVALID_STATE;
    }

    xSemaphoreTake(s_lock, portMAX_DELAY);

    rec->seq = s_head_seq + 1;
    rec->crc = rec_crc(rec);

    uint32_t idx = (rec->seq - 1) % s_capacity;
    esp_err_t err;

    /* Entering a new sector means its old contents must go first. */
    if (idx % RECS_PER_SECTOR == 0) {
        err = esp_partition_erase_range(s_part,
                                        (size_t)idx * sizeof(event_rec_t),
                                        SECTOR_BYTES);
        if (err != ESP_OK) {
            ESP_LOGE(TAG, "sector erase at idx %" PRIu32 " failed: %s",
                     idx, esp_err_to_name(err));
            xSemaphoreGive(s_lock);
            return err;
        }
    }

    err = esp_partition_write(s_part, (size_t)idx * sizeof(event_rec_t),
                              rec, sizeof(*rec));
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "write at idx %" PRIu32 " failed: %s",
                 idx, esp_err_to_name(err));
        xSemaphoreGive(s_lock);
        return err;
    }

    s_head_seq = rec->seq;
    if (s_head_seq > s_capacity && s_ack_seq < s_head_seq - s_capacity) {
        if (!s_overflow) {
            ESP_LOGW(TAG, "ring wrapped past unacked data - oldest events lost");
        }
        s_overflow = true;
    }

    xSemaphoreGive(s_lock);
    return ESP_OK;
}

esp_err_t evlog_read_since(uint32_t since, event_rec_t *out, size_t max, size_t *count)
{
    if (!s_part || !out || !count) {
        return ESP_ERR_INVALID_STATE;
    }
    *count = 0;

    xSemaphoreTake(s_lock, portMAX_DELAY);

    uint32_t seq = since + 1;
    uint32_t oldest = first_live_seq();
    if (seq < oldest) {
        seq = oldest;   /* overwritten by the ring, or erased on purpose */
    }

    for (; seq <= s_head_seq && *count < max; seq++) {
        event_rec_t r;
        if (read_slot((seq - 1) % s_capacity, &r) != ESP_OK) {
            continue;
        }
        /* Guards against a torn write and against a stale pre-wrap slot. */
        if (!rec_valid(&r) || r.seq != seq) {
            continue;
        }
        out[(*count)++] = r;
    }

    xSemaphoreGive(s_lock);
    return ESP_OK;
}

esp_err_t evlog_ack(uint32_t seq)
{
    xSemaphoreTake(s_lock, portMAX_DELAY);
    if (seq > s_head_seq) {
        seq = s_head_seq;
    }
    if (seq <= s_ack_seq) {
        xSemaphoreGive(s_lock);
        return ESP_OK;              /* replayed ack, nothing to do */
    }
    s_ack_seq = seq;
    s_overflow = false;
    xSemaphoreGive(s_lock);

    nvs_handle_t h;
    esp_err_t err = nvs_open(NVS_NS, NVS_READWRITE, &h);
    if (err != ESP_OK) {
        return err;
    }
    err = nvs_set_u32(h, NVS_KEY_ACK, seq);
    if (err == ESP_OK) {
        err = nvs_commit(h);
    }
    nvs_close(h);
    return err;
}

esp_err_t evlog_erase_all(void)
{
    if (!s_part) {
        return ESP_ERR_INVALID_STATE;
    }

    xSemaphoreTake(s_lock, portMAX_DELAY);
    esp_err_t err = esp_partition_erase_range(s_part, 0, s_part->size);
    uint32_t keep = s_head_seq;
    if (err == ESP_OK) {
        /* Keep the counter: nothing is pending, and the next punch is
         * floor + 1, never 1 again. */
        s_floor_seq = keep;
        s_ack_seq = keep;
        s_overflow = false;
    }
    xSemaphoreGive(s_lock);

    if (err != ESP_OK) {
        return err;
    }

    /* Persist the floor, or the next boot finds an empty medium and starts
     * numbering from 1 after all. */
    nvs_handle_t h;
    esp_err_t nerr = nvs_open(NVS_NS, NVS_READWRITE, &h);
    if (nerr == ESP_OK) {
        nerr = nvs_set_u32(h, NVS_KEY_FLOOR, keep);
        if (nerr == ESP_OK) {
            nerr = nvs_set_u32(h, NVS_KEY_ACK, keep);
        }
        if (nerr == ESP_OK) {
            nerr = nvs_commit(h);
        }
        nvs_close(h);
    }
    if (nerr != ESP_OK) {
        ESP_LOGE(TAG, "could not persist the sequence floor (%s) - numbering "
                      "may restart after a reboot", esp_err_to_name(nerr));
    }

    ESP_LOGW(TAG, "event log erased; numbering continues after %" PRIu32, keep);
    return ESP_OK;
}

void evlog_get_stats(evlog_stats_t *out)
{
    if (!out) {
        return;
    }
    xSemaphoreTake(s_lock, portMAX_DELAY);
    out->capacity   = s_capacity;
    out->head_seq   = s_head_seq;
    out->oldest_seq = (s_head_seq > s_floor_seq) ? first_live_seq() : 0;
    out->ack_seq    = s_ack_seq;
    out->pending    = s_head_seq - s_ack_seq;
    out->overflow   = s_overflow;
    xSemaphoreGive(s_lock);
}
