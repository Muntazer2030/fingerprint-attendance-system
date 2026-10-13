#pragma once
/* Small records in raw sectors of the "storage" partition.
 *
 * Used instead of NVS for anything new: NVS is 24 KB and the employee name
 * bitmaps already take most of it. Each record owns whole 4 KB sectors and
 * carries a CRC'd header that is written last, so a power cut mid-write reads
 * back as "nothing stored", never as garbage.
 *
 * Sector map -- keep it here so two owners never collide:
 *   0      notify settings      (notify.c)
 *   1..3   notify roster        (notify.c)
 *   4      Wi-Fi credentials    (net_wifi.c)
 */

#include <stddef.h>
#include <stdint.h>
#include "esp_err.h"

#define STORE_SECTOR_SIZE 4096
#define STORE_HDR_SIZE    12

#define STORE_NOTIFY_CFG    0
#define STORE_NOTIFY_ROSTER 1
#define STORE_NOTIFY_ROSTER_SECTORS 3
#define STORE_WIFI          4

esp_err_t store_init(void);

esp_err_t store_write(int sector, int nsectors, const void *data, uint32_t len);

/* ESP_ERR_NOT_FOUND for an empty or damaged record. */
esp_err_t store_read(int sector, void *data, uint32_t max, uint32_t *len);

esp_err_t store_erase(int sector, int nsectors);
