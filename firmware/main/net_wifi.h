#pragma once
/* Wi-Fi as a fallback for when the Ethernet cable is not connected.
 *
 * Ethernet stays the primary link. Wi-Fi starts only after Ethernet has had no
 * usable connection (link AND address) for a while, and stops again once
 * Ethernet has been back for a minute -- so a brief cable wiggle does not make
 * the terminal hop between addresses. The credentials are set from the app,
 * typically while it is still reachable over Ethernet.
 *
 * Also the one place that answers "is the terminal online, and at what
 * address", whichever interface that is. */

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "esp_err.h"

#define NET_WIFI_SSID_MAX 33   /* 32 + NUL */
#define NET_WIFI_PASS_MAX 65   /* 64 + NUL */

typedef enum {
    NET_WIFI_OFF = 0,      /* not configured, or Ethernet is fine */
    NET_WIFI_CONNECTING,
    NET_WIFI_CONNECTED,
    NET_WIFI_FAILED,       /* still retrying; see last_error */
} net_wifi_state_t;

typedef struct {
    bool             configured;
    char             ssid[NET_WIFI_SSID_MAX];
    net_wifi_state_t state;
    char             ip[16];
    int8_t           rssi;          /* dBm, 0 when not connected */
    char             last_error[48];
} net_wifi_status_t;

typedef struct {
    char   ssid[NET_WIFI_SSID_MAX];
    int8_t rssi;
    bool   secure;
} net_wifi_ap_t;

/* Call after net_eth_start(). Loads saved credentials and starts the task
 * that decides when Wi-Fi should be on. */
esp_err_t net_wifi_start(void);

/* An empty ssid forgets the network. An empty password means an open one;
 * otherwise WPA needs at least 8 characters. */
esp_err_t net_wifi_set_credentials(const char *ssid, const char *password);

void net_wifi_get_status(net_wifi_status_t *out);

/* Blocks for a few seconds while the radio listens. Works whether or not
 * Wi-Fi is currently in use. */
esp_err_t net_wifi_scan(net_wifi_ap_t *out, size_t max, size_t *count);

/* Forgets the credentials (config reset). */
esp_err_t net_wifi_reset(void);

/* --- whichever interface is up ------------------------------------------ */

bool        net_any_got_ip(void);
const char *net_active_ip(void);     /* "0.0.0.0" when offline        */
const char *net_active_iface(void);  /* "eth", "wifi" or "none"       */
