#pragma once
/* LAN HTTP API. Contract lives in docs/protocol.md. */

#include "esp_err.h"

esp_err_t api_server_start(void);

/* Bearer token this device expects. Generated and persisted to NVS on first
 * boot; the Flutter app is given it during pairing. */
const char *api_server_token(void);
