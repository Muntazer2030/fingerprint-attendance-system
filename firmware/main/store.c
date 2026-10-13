/* Raw-sector record store. See store.h. */

#include "store.h"
#include "esp_log.h"
#include "esp_partition.h"
#include "esp_rom_crc.h"

static const char *TAG = "store";

#define STORE_MAGIC 0x314E4754u   /* "TGN1" -- kept from notify.c's records */

typedef struct {
    uint32_t magic;
    uint32_t len;
    uint32_t crc;
} store_hdr_t;

_Static_assert(sizeof(store_hdr_t) == STORE_HDR_SIZE, "header size");

static const esp_partition_t *s_part;

esp_err_t store_init(void)
{
    if (s_part) {
        return ESP_OK;
    }
    s_part = esp_partition_find_first(ESP_PARTITION_TYPE_DATA,
                                      ESP_PARTITION_SUBTYPE_DATA_SPIFFS,
                                      "storage");
    if (!s_part) {
        ESP_LOGE(TAG, "storage partition missing");
        return ESP_ERR_NOT_FOUND;
    }
    return ESP_OK;
}

esp_err_t store_write(int sector, int nsectors, const void *data, uint32_t len)
{
    if (!s_part) {
        return ESP_ERR_NOT_FOUND;
    }
    if (len + sizeof(store_hdr_t) > (uint32_t)nsectors * STORE_SECTOR_SIZE) {
        return ESP_ERR_INVALID_SIZE;
    }
    size_t off = (size_t)sector * STORE_SECTOR_SIZE;
    esp_err_t err = esp_partition_erase_range(
        s_part, off, (size_t)nsectors * STORE_SECTOR_SIZE);
    if (err != ESP_OK) {
        return err;
    }
    store_hdr_t h = {
        .magic = STORE_MAGIC,
        .len = len,
        .crc = esp_rom_crc32_le(0, data, len),
    };
    err = esp_partition_write(s_part, off + sizeof(h), data, len);
    if (err == ESP_OK) {
        err = esp_partition_write(s_part, off, &h, sizeof(h));
    }
    return err;
}

esp_err_t store_read(int sector, void *data, uint32_t max, uint32_t *len)
{
    if (!s_part) {
        return ESP_ERR_NOT_FOUND;
    }
    size_t off = (size_t)sector * STORE_SECTOR_SIZE;
    store_hdr_t h;
    if (esp_partition_read(s_part, off, &h, sizeof(h)) != ESP_OK ||
        h.magic != STORE_MAGIC || h.len > max) {
        return ESP_ERR_NOT_FOUND;
    }
    if (esp_partition_read(s_part, off + sizeof(h), data, h.len) != ESP_OK ||
        esp_rom_crc32_le(0, data, h.len) != h.crc) {
        return ESP_ERR_NOT_FOUND;
    }
    *len = h.len;
    return ESP_OK;
}

esp_err_t store_erase(int sector, int nsectors)
{
    if (!s_part) {
        return ESP_ERR_NOT_FOUND;
    }
    return esp_partition_erase_range(s_part,
                                     (size_t)sector * STORE_SECTOR_SIZE,
                                     (size_t)nsectors * STORE_SECTOR_SIZE);
}
