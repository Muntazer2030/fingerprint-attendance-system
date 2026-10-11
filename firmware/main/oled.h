#pragma once
/* SH1106 / SSD1306-family 128x64 mono OLED over I2C. See docs/decisions.md D11. */

#include <stdint.h>
#include <stdbool.h>
#include "esp_err.h"
#include "driver/i2c_master.h"

esp_err_t oled_init(i2c_master_bus_handle_t bus);

/* All drawing happens in RAM; nothing reaches the panel until oled_flush(). */
void oled_clear(void);
void oled_pixel(int x, int y, bool on);
void oled_fill_rect(int x, int y, int w, int h, bool on);

/* 5x7 glyphs on a 6x8 cell. Returns the x just past the text. */
int  oled_text(int x, int y, const char *s);

/* Same glyphs blown up by an integer factor -- used for the clock, which has
 * to be readable from across a room. Returns the x just past the text. */
int  oled_text_scaled(int x, int y, const char *s, int scale);

/* Pixel width the given string would occupy, for centring. */
int  oled_text_width(const char *s, int scale);

/* A 3x5 face for digits and '.', for lines too long for the 5x7 one.
 * Other characters advance without drawing. */
int  oled_text_small(int x, int y, const char *s);
int  oled_text_small_width(const char *s);

/* Inverts every pixel in the rectangle. Cheaper and clearer than a second
 * font for highlighted rows. */
void oled_invert_rect(int x, int y, int w, int h);

void oled_hline(int x, int y, int w);
void oled_vline(int x, int y, int h);
void oled_rect(int x, int y, int w, int h);

/* 1bpp bitmap, row-major, MSB first. This is how Arabic names arrive from the
 * PC already shaped and RTL-ordered (D3) -- the device never shapes text. */
void oled_blit(int x, int y, int w, int h, const uint8_t *bits);

esp_err_t oled_flush(void);

/* Raw framebuffer, page-major: byte (page * width + x) holds 8 vertical
 * pixels, LSB topmost. Exposed so the app can fetch exactly what the panel is
 * showing -- checking a 128x64 layout by describing it over a serial log is
 * hopeless, and this makes it verifiable. */
const uint8_t *oled_framebuffer(void);
size_t oled_framebuffer_size(void);

/* Burn-in control (D11). Contrast is 0-255. */
esp_err_t oled_set_contrast(uint8_t level);
esp_err_t oled_display_on(bool on);

/* Shifts the whole framebuffer origin by a pixel or two so a static idle
 * screen does not ghost into the panel over months. */
void oled_set_shift(int dx, int dy);
