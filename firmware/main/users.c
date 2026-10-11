/* Employee / slot registry backed by NVS.
 *
 * Both tables are small enough to keep resident and rewrite as single blobs:
 * 240 slots x 4 B = 960 B, and 64 employees x 12 B = 768 B. Name bitmaps are
 * 256 B each and live in their own per-employee keys so that adding a name
 * does not rewrite the whole table. */

#include <string.h>
#include "users.h"
#include "esp_log.h"
#include "nvs.h"
#include "sdkconfig.h"

static const char *TAG = "users";

#define NVS_NS       "users"
#define KEY_SLOTS    "slots"
#define KEY_EMPS     "emps"
#define MAX_SLOTS    CONFIG_ATT_MAX_SLOTS
#define MAX_EMPS     CONFIG_ATT_MAX_EMPLOYEES

typedef struct {
    uint16_t employee;   /* 0 = free */
    uint8_t  finger;
    uint8_t  pad;
} slot_entry_t;

static slot_entry_t s_slots[MAX_SLOTS];
static emp_entry_t  s_emps[MAX_EMPS];
static bool s_dirty;

static void name_key(uint16_t id, char *out, size_t n)
{
    snprintf(out, n, "n%u", (unsigned)id);
}

esp_err_t users_init(void)
{
    nvs_handle_t h;
    if (nvs_open(NVS_NS, NVS_READONLY, &h) != ESP_OK) {
        ESP_LOGI(TAG, "no registry yet, starting empty");
        return ESP_OK;
    }

    size_t len = sizeof(s_slots);
    if (nvs_get_blob(h, KEY_SLOTS, s_slots, &len) != ESP_OK) {
        memset(s_slots, 0, sizeof(s_slots));
    }
    len = sizeof(s_emps);
    if (nvs_get_blob(h, KEY_EMPS, s_emps, &len) != ESP_OK) {
        memset(s_emps, 0, sizeof(s_emps));
    }
    nvs_close(h);

    ESP_LOGI(TAG, "%u employees, %u/%d slots used",
             users_count(), users_slots_used(), MAX_SLOTS);
    return ESP_OK;
}

esp_err_t users_commit(void)
{
    if (!s_dirty) {
        return ESP_OK;
    }
    nvs_handle_t h;
    esp_err_t err = nvs_open(NVS_NS, NVS_READWRITE, &h);
    if (err != ESP_OK) {
        return err;
    }
    err = nvs_set_blob(h, KEY_SLOTS, s_slots, sizeof(s_slots));
    if (err == ESP_OK) {
        err = nvs_set_blob(h, KEY_EMPS, s_emps, sizeof(s_emps));
    }
    if (err == ESP_OK) {
        err = nvs_commit(h);
    }
    nvs_close(h);
    if (err == ESP_OK) {
        s_dirty = false;
    }
    return err;
}

/* --- slots ------------------------------------------------------------- */

uint16_t users_slot_owner(uint16_t slot)
{
    return (slot < MAX_SLOTS) ? s_slots[slot].employee : 0;
}

uint16_t users_slot_alloc(uint16_t employee, uint8_t finger)
{
    for (uint16_t i = 0; i < MAX_SLOTS; i++) {
        if (s_slots[i].employee == 0) {
            s_slots[i].employee = employee;
            s_slots[i].finger = finger;
            s_dirty = true;
            users_commit();
            return i;
        }
    }
    return UINT16_MAX;
}

esp_err_t users_slot_release(uint16_t slot)
{
    if (slot >= MAX_SLOTS) {
        return ESP_ERR_INVALID_ARG;
    }
    s_slots[slot].employee = 0;
    s_slots[slot].finger = 0;
    s_dirty = true;
    return users_commit();
}

uint16_t users_slot_count_for(uint16_t employee)
{
    uint16_t n = 0;
    for (uint16_t i = 0; i < MAX_SLOTS; i++) {
        if (s_slots[i].employee == employee) {
            n++;
        }
    }
    return n;
}

uint16_t users_slots_used(void)
{
    uint16_t n = 0;
    for (uint16_t i = 0; i < MAX_SLOTS; i++) {
        if (s_slots[i].employee) {
            n++;
        }
    }
    return n;
}

bool users_slot_next(uint16_t *cursor, uint16_t *slot, uint16_t *employee, uint8_t *finger)
{
    while (*cursor < MAX_SLOTS) {
        uint16_t i = (*cursor)++;
        if (s_slots[i].employee) {
            *slot = i;
            *employee = s_slots[i].employee;
            *finger = s_slots[i].finger;
            return true;
        }
    }
    return false;
}

/* --- employees --------------------------------------------------------- */

emp_entry_t *users_get(uint16_t id)
{
    if (id == 0) {
        return NULL;
    }
    for (int i = 0; i < MAX_EMPS; i++) {
        if (s_emps[i].id == id) {
            return &s_emps[i];
        }
    }
    return NULL;
}

esp_err_t users_upsert(uint16_t id, bool active)
{
    if (id == 0) {
        return ESP_ERR_INVALID_ARG;
    }
    emp_entry_t *e = users_get(id);
    if (!e) {
        for (int i = 0; i < MAX_EMPS; i++) {
            if (s_emps[i].id == 0) {
                e = &s_emps[i];
                memset(e, 0, sizeof(*e));
                e->id = id;
                break;
            }
        }
    }
    if (!e) {
        ESP_LOGE(TAG, "employee table full (%d)", MAX_EMPS);
        return ESP_ERR_NO_MEM;
    }
    e->active = active ? 1 : 0;
    s_dirty = true;
    return users_commit();
}

esp_err_t users_remove(uint16_t id)
{
    emp_entry_t *e = users_get(id);
    if (!e) {
        return ESP_ERR_NOT_FOUND;
    }

    /* Slots must go with the employee, or the next enrolment inherits their
     * fingerprints and punches land on the wrong person. */
    for (uint16_t i = 0; i < MAX_SLOTS; i++) {
        if (s_slots[i].employee == id) {
            s_slots[i].employee = 0;
            s_slots[i].finger = 0;
        }
    }
    memset(e, 0, sizeof(*e));
    s_dirty = true;

    nvs_handle_t h;
    if (nvs_open(NVS_NS, NVS_READWRITE, &h) == ESP_OK) {
        char key[8];
        name_key(id, key, sizeof(key));
        nvs_erase_key(h, key);
        nvs_commit(h);
        nvs_close(h);
    }
    return users_commit();
}

uint16_t users_count(void)
{
    uint16_t n = 0;
    for (int i = 0; i < MAX_EMPS; i++) {
        if (s_emps[i].id) {
            n++;
        }
    }
    return n;
}

bool users_next(uint16_t *cursor, emp_entry_t *out)
{
    while (*cursor < MAX_EMPS) {
        uint16_t i = (*cursor)++;
        if (s_emps[i].id) {
            *out = s_emps[i];
            return true;
        }
    }
    return false;
}

esp_err_t users_set_name(uint16_t id, const uint8_t *bitmap, size_t len)
{
    if (!users_get(id)) {
        return ESP_ERR_NOT_FOUND;
    }
    if (len != USERS_NAME_BITMAP_BYTES) {
        return ESP_ERR_INVALID_SIZE;
    }
    nvs_handle_t h;
    esp_err_t err = nvs_open(NVS_NS, NVS_READWRITE, &h);
    if (err != ESP_OK) {
        return err;
    }
    char key[8];
    name_key(id, key, sizeof(key));
    err = nvs_set_blob(h, key, bitmap, len);
    if (err == ESP_OK) {
        err = nvs_commit(h);
    }
    nvs_close(h);
    return err;
}

esp_err_t users_get_name(uint16_t id, uint8_t *out, size_t *len)
{
    nvs_handle_t h;
    esp_err_t err = nvs_open(NVS_NS, NVS_READONLY, &h);
    if (err != ESP_OK) {
        return err;
    }
    char key[8];
    name_key(id, key, sizeof(key));
    err = nvs_get_blob(h, key, out, len);
    nvs_close(h);
    return err;
}

esp_err_t users_clear_all(void)
{
    /* Drop the per-employee name bitmaps before the table, while we still
     * know which ids existed. */
    nvs_handle_t h;
    if (nvs_open(NVS_NS, NVS_READWRITE, &h) == ESP_OK) {
        for (int i = 0; i < MAX_EMPS; i++) {
            if (!s_emps[i].id) {
                continue;
            }
            char key[8];
            name_key(s_emps[i].id, key, sizeof(key));
            nvs_erase_key(h, key);
        }
        nvs_commit(h);
        nvs_close(h);
    }

    memset(s_slots, 0, sizeof(s_slots));
    memset(s_emps, 0, sizeof(s_emps));
    s_dirty = true;
    ESP_LOGW(TAG, "employee registry cleared");
    return users_commit();
}

/* --- punch bookkeeping ------------------------------------------------- */

esp_err_t users_record_punch(uint16_t id, uint8_t dir, uint32_t epoch)
{
    emp_entry_t *e = users_get(id);
    if (!e) {
        return ESP_ERR_NOT_FOUND;
    }
    e->last_dir = dir;
    e->last_epoch = epoch;
    e->fail_count = 0;      /* a good read clears the degradation counter */
    s_dirty = true;
    return users_commit();
}

esp_err_t users_note_failure(uint16_t id)
{
    emp_entry_t *e = users_get(id);
    if (!e) {
        return ESP_ERR_NOT_FOUND;
    }
    if (e->fail_count < UINT16_MAX) {
        e->fail_count++;
    }
    s_dirty = true;
    return ESP_OK;   /* deliberately not committed: too hot a path for NVS */
}
