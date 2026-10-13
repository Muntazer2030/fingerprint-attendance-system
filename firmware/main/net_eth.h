#pragma once
#include "esp_err.h"
#include "esp_netif.h"
#include <stdbool.h>
#include <stdint.h>

/* Brings up ENC28J60 over SPI and attaches it to an esp_netif with DHCP.
 * Returns once the driver is started; the link may still be down. */
esp_err_t net_eth_start(void);

/* True once an address is assigned -- a DHCP lease, or the static fallback,
 * which applies even with no cable. Pair with net_eth_link_up(). */
bool net_eth_got_ip(void);

/* The Ethernet interface, for choosing the default route. NULL if Ethernet
 * failed to start. */
esp_netif_t *net_eth_netif(void);

/* True while the PHY reports carrier. */
bool net_eth_link_up(void);

/* Logs link/DHCP state, with wiring hints once it has been failing a while. */
void net_eth_log_status(void);

/* How many times the watchdog has had to reset a wedged ENC28J60. A climbing
 * count means signal integrity or power, not software. */
uint32_t net_eth_reset_count(void);

/* Samples the ENC28J60 INT line. The driver arms a falling-edge interrupt, but
 * the chip asserts INT as a *level*, so a missed edge stalls transmits forever
 * rather than degrading. Reading the pin separates the two failure modes:
 *
 *   stuck low  -> the chip is asserting an interrupt nobody is servicing;
 *                 an edge was missed (or the line is shorted low)
 *   stuck high -> the chip never asserts; INT is unwired or on the wrong pin
 *
 * Returns -1 if no INT pin is configured. */
int net_eth_int_level(void);
bool net_eth_int_stuck_low(void);

/* Dotted-quad of the current lease, or "0.0.0.0". Not thread-safe to hold. */
const char *net_eth_ip(void);
