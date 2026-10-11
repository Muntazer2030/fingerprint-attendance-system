#pragma once
/* Pin map resolved from Kconfig. See docs/decisions.md O1 for board choice. */

#include "sdkconfig.h"

#define PIN_SPI_SCLK    CONFIG_ATT_PIN_SPI_SCLK
#define PIN_SPI_MOSI    CONFIG_ATT_PIN_SPI_MOSI
#define PIN_SPI_MISO    CONFIG_ATT_PIN_SPI_MISO
#define PIN_ETH_CS      CONFIG_ATT_PIN_ETH_CS
#define PIN_ETH_INT     CONFIG_ATT_PIN_ETH_INT
#define PIN_ETH_RST     CONFIG_ATT_PIN_ETH_RST
#define PIN_I2C_SDA     CONFIG_ATT_PIN_I2C_SDA
#define PIN_I2C_SCL     CONFIG_ATT_PIN_I2C_SCL
#define PIN_FPM_TX      CONFIG_ATT_PIN_FPM_TX
#define PIN_FPM_RX      CONFIG_ATT_PIN_FPM_RX
#define PIN_FPM_DETECT  CONFIG_ATT_PIN_FPM_DETECT
#define PIN_TOUCH       CONFIG_ATT_PIN_TOUCH
#define PIN_BUZZER      CONFIG_ATT_PIN_BUZZER
#define PIN_LED         CONFIG_ATT_PIN_LED

#if CONFIG_ATT_BOARD_WROOM32
#  define BOARD_NAME "ESP32-WROOM-32"
#elif CONFIG_ATT_BOARD_C3_SUPERMINI
#  define BOARD_NAME "ESP32-C3 SuperMini"
#elif CONFIG_ATT_BOARD_C3
#  define BOARD_NAME "ESP32-C3"
#else
#  define BOARD_NAME "unknown"
#endif

#if CONFIG_ATT_ETH_ENC28J60
#  define ETH_CHIP_NAME "ENC28J60"
#else
#  define ETH_CHIP_NAME "W5500"
#endif

#if CONFIG_ATT_OLED_SSD1327
#  define OLED_NAME   "SSD1327"
#  define OLED_W      128
#  define OLED_H      128
#  define OLED_BPP    4          /* 16-level greyscale: antialiased Arabic */
#elif CONFIG_ATT_OLED_SSD1309
#  define OLED_NAME   "SSD1309"
#  define OLED_W      128
#  define OLED_H      64
#  define OLED_BPP    1
#elif CONFIG_ATT_OLED_SH1106
#  define OLED_NAME   "SH1106"
#  define OLED_W      128
#  define OLED_H      64
#  define OLED_BPP    1
#  define OLED_COL_OFFSET 2      /* SH1106 RAM is 132 wide */
#else
#  define OLED_NAME   "SSD1306"
#  define OLED_W      128
#  define OLED_H      64
#  define OLED_BPP    1
#endif

#ifndef OLED_COL_OFFSET
#  define OLED_COL_OFFSET 0
#endif

#define OLED_FB_BYTES ((OLED_W * OLED_H * OLED_BPP) / 8)

/* gpio_config() takes a bit mask, but several pins here are legitimately -1
 * meaning "not fitted". Shifting by a negative count is undefined, and the
 * compiler rejects it outright even when a runtime guard would never let it
 * execute -- so mask the shift and yield 0 for absent pins. */
#define PIN_MASK(p) (((p) < 0) ? 0ULL : (1ULL << ((p) & 0x3F)))

/* Event log geometry -- see docs/protocol.md */
#define EVENT_RECORD_BYTES 16
