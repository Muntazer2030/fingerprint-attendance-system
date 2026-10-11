/* SH1106 / SSD1306 128x64 mono OLED driver.
 *
 * The two controllers are near-identical except for two things that both
 * produce a *blank or shifted* panel rather than an obvious error:
 *
 *   1. Charge pump. SSD1306 enables its internal boost with 0x8D,0x14.
 *      SH1106 uses 0xAD,0x8B. Send the wrong one and the panel stays dark
 *      even though every I2C transfer is ACKed.
 *   2. Column offset. SH1106 has 132 columns of RAM behind a 128-pixel panel,
 *      so writes start at column 2. Without it the image is shifted 2 px and
 *      the right edge wraps around to the left.
 */

#include <string.h>
#include "oled.h"
#include "board.h"
#include "esp_log.h"

static const char *TAG = "oled";

#define OLED_PAGES (OLED_H / 8)
#define CTRL_CMD   0x00
#define CTRL_DATA  0x40

static i2c_master_dev_handle_t s_dev;
static uint8_t s_fb[OLED_W * OLED_H / 8];
static int s_shift_x, s_shift_y;

static esp_err_t cmd(uint8_t c)
{
    const uint8_t buf[2] = { CTRL_CMD, c };
    return i2c_master_transmit(s_dev, buf, sizeof(buf), 100);
}

static esp_err_t cmd2(uint8_t c, uint8_t arg)
{
    esp_err_t err = cmd(c);
    return err == ESP_OK ? cmd(arg) : err;
}

esp_err_t oled_init(i2c_master_bus_handle_t bus)
{
    i2c_device_config_t dev_cfg = {
        .dev_addr_length = I2C_ADDR_BIT_LEN_7,
        .device_address  = CONFIG_ATT_OLED_ADDR,
        .scl_speed_hz    = CONFIG_ATT_I2C_FREQ_HZ,
    };
    esp_err_t err = i2c_master_bus_add_device(bus, &dev_cfg, &s_dev);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "bus add device failed: %s", esp_err_to_name(err));
        return err;
    }

    cmd(0xAE);              /* display off while we configure          */
    cmd2(0xD5, 0x80);       /* clock divide / oscillator frequency     */
    cmd2(0xA8, OLED_H - 1); /* multiplex ratio                         */
    cmd2(0xD3, 0x00);       /* display offset                          */
    cmd(0x40);              /* start line 0                            */

#if CONFIG_ATT_OLED_SH1106
    cmd2(0xAD, 0x8B);       /* SH1106 DC-DC on  (NOT SSD1306's 0x8D)   */
    cmd2(0x33, 0x00);       /* pump voltage 9.0 V                      */
#else
    cmd2(0x8D, 0x14);       /* SSD1306 charge pump on                  */
#endif

    cmd(0xA1);              /* segment remap: column 127 -> SEG0       */
    cmd(0xC8);              /* COM scan direction: reversed            */
    cmd2(0xDA, 0x12);       /* COM pins: alternative, no remap         */
    cmd2(0x81, 0x80);       /* contrast                                */
    cmd2(0xD9, 0x22);       /* pre-charge period                       */
    cmd2(0xDB, 0x35);       /* VCOMH deselect level                    */
    cmd(0xA4);              /* resume from RAM, not all-on             */
    cmd(0xA6);              /* normal, not inverted                    */

    oled_clear();
    err = oled_flush();
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "first flush failed: %s", esp_err_to_name(err));
        return err;
    }

    err = cmd(0xAF);        /* display on */
    ESP_LOGI(TAG, "%s %dx%d ready at 0x%02X (col offset %d)",
             OLED_NAME, OLED_W, OLED_H, CONFIG_ATT_OLED_ADDR, OLED_COL_OFFSET);
    return err;
}

void oled_clear(void)
{
    memset(s_fb, 0, sizeof(s_fb));
}

void oled_set_shift(int dx, int dy)
{
    s_shift_x = dx;
    s_shift_y = dy;
}

void oled_pixel(int x, int y, bool on)
{
    x += s_shift_x;
    y += s_shift_y;
    if (x < 0 || x >= OLED_W || y < 0 || y >= OLED_H) {
        return;
    }
    uint8_t *cell = &s_fb[(y / 8) * OLED_W + x];
    uint8_t bit = 1u << (y & 7);
    if (on) {
        *cell |= bit;
    } else {
        *cell &= (uint8_t)~bit;
    }
}

void oled_fill_rect(int x, int y, int w, int h, bool on)
{
    for (int j = 0; j < h; j++) {
        for (int i = 0; i < w; i++) {
            oled_pixel(x + i, y + j, on);
        }
    }
}

/* 5x7 font, ASCII 0x20-0x7E, column-major. Enough for status text and numbers;
 * Arabic never goes through here (D3 -- names arrive as bitmaps). */
static const uint8_t FONT5X7[][5] = {
    {0x00,0x00,0x00,0x00,0x00}, {0x00,0x00,0x5F,0x00,0x00},
    {0x00,0x07,0x00,0x07,0x00}, {0x14,0x7F,0x14,0x7F,0x14},
    {0x24,0x2A,0x7F,0x2A,0x12}, {0x23,0x13,0x08,0x64,0x62},
    {0x36,0x49,0x55,0x22,0x50}, {0x00,0x05,0x03,0x00,0x00},
    {0x00,0x1C,0x22,0x41,0x00}, {0x00,0x41,0x22,0x1C,0x00},
    {0x14,0x08,0x3E,0x08,0x14}, {0x08,0x08,0x3E,0x08,0x08},
    {0x00,0x50,0x30,0x00,0x00}, {0x08,0x08,0x08,0x08,0x08},
    {0x00,0x60,0x60,0x00,0x00}, {0x20,0x10,0x08,0x04,0x02},
    {0x3E,0x51,0x49,0x45,0x3E}, {0x00,0x42,0x7F,0x40,0x00},
    {0x42,0x61,0x51,0x49,0x46}, {0x21,0x41,0x45,0x4B,0x31},
    {0x18,0x14,0x12,0x7F,0x10}, {0x27,0x45,0x45,0x45,0x39},
    {0x3C,0x4A,0x49,0x49,0x30}, {0x01,0x71,0x09,0x05,0x03},
    {0x36,0x49,0x49,0x49,0x36}, {0x06,0x49,0x49,0x29,0x1E},
    {0x00,0x36,0x36,0x00,0x00}, {0x00,0x56,0x36,0x00,0x00},
    {0x00,0x08,0x14,0x22,0x41}, {0x14,0x14,0x14,0x14,0x14},
    {0x41,0x22,0x14,0x08,0x00}, {0x02,0x01,0x51,0x09,0x06},
    {0x32,0x49,0x79,0x41,0x3E}, {0x7E,0x11,0x11,0x11,0x7E},
    {0x7F,0x49,0x49,0x49,0x36}, {0x3E,0x41,0x41,0x41,0x22},
    {0x7F,0x41,0x41,0x22,0x1C}, {0x7F,0x49,0x49,0x49,0x41},
    {0x7F,0x09,0x09,0x09,0x01}, {0x3E,0x41,0x49,0x49,0x7A},
    {0x7F,0x08,0x08,0x08,0x7F}, {0x00,0x41,0x7F,0x41,0x00},
    {0x20,0x40,0x41,0x3F,0x01}, {0x7F,0x08,0x14,0x22,0x41},
    {0x7F,0x40,0x40,0x40,0x40}, {0x7F,0x02,0x0C,0x02,0x7F},
    {0x7F,0x04,0x08,0x10,0x7F}, {0x3E,0x41,0x41,0x41,0x3E},
    {0x7F,0x09,0x09,0x09,0x06}, {0x3E,0x41,0x51,0x21,0x5E},
    {0x7F,0x09,0x19,0x29,0x46}, {0x46,0x49,0x49,0x49,0x31},
    {0x01,0x01,0x7F,0x01,0x01}, {0x3F,0x40,0x40,0x40,0x3F},
    {0x1F,0x20,0x40,0x20,0x1F}, {0x3F,0x40,0x38,0x40,0x3F},
    {0x63,0x14,0x08,0x14,0x63}, {0x07,0x08,0x70,0x08,0x07},
    {0x61,0x51,0x49,0x45,0x43}, {0x00,0x7F,0x41,0x41,0x00},
    {0x02,0x04,0x08,0x10,0x20}, {0x00,0x41,0x41,0x7F,0x00},
    {0x04,0x02,0x01,0x02,0x04}, {0x40,0x40,0x40,0x40,0x40},
    {0x00,0x01,0x02,0x04,0x00}, {0x20,0x54,0x54,0x54,0x78},
    {0x7F,0x48,0x44,0x44,0x38}, {0x38,0x44,0x44,0x44,0x20},
    {0x38,0x44,0x44,0x48,0x7F}, {0x38,0x54,0x54,0x54,0x18},
    {0x08,0x7E,0x09,0x01,0x02}, {0x0C,0x52,0x52,0x52,0x3E},
    {0x7F,0x08,0x04,0x04,0x78}, {0x00,0x44,0x7D,0x40,0x00},
    {0x20,0x40,0x44,0x3D,0x00}, {0x7F,0x10,0x28,0x44,0x00},
    {0x00,0x41,0x7F,0x40,0x00}, {0x7C,0x04,0x18,0x04,0x78},
    {0x7C,0x08,0x04,0x04,0x78}, {0x38,0x44,0x44,0x44,0x38},
    {0x7C,0x14,0x14,0x14,0x08}, {0x08,0x14,0x14,0x18,0x7C},
    {0x7C,0x08,0x04,0x04,0x08}, {0x48,0x54,0x54,0x54,0x20},
    {0x04,0x3F,0x44,0x40,0x20}, {0x3C,0x40,0x40,0x20,0x7C},
    {0x1C,0x20,0x40,0x20,0x1C}, {0x3C,0x40,0x30,0x40,0x3C},
    {0x44,0x28,0x10,0x28,0x44}, {0x0C,0x50,0x50,0x50,0x3C},
    {0x44,0x64,0x54,0x4C,0x44}, {0x00,0x08,0x36,0x41,0x00},
    {0x00,0x00,0x7F,0x00,0x00}, {0x00,0x41,0x36,0x08,0x00},
    {0x08,0x08,0x2A,0x1C,0x08},
};

/* A 3x5 numeric face for lines that will not fit in the 5x7 one. The idle
 * screen's address line is the case: 15 characters beside the link glyph is
 * 90 px at 5x7, which collides with the centred mode strip, but 54 px here.
 *
 * Digits and '.' only, which is all an IPv4 address needs. Anything else
 * advances the cursor without drawing, so a stray character leaves a gap
 * rather than garbage. Columns are bit-packed low-bit-first, top row = bit 0. */
static const uint8_t FONT3X5[10][3] = {
    {0x1F, 0x11, 0x1F},   /* 0 */
    {0x12, 0x1F, 0x10},   /* 1 */
    {0x1D, 0x15, 0x17},   /* 2 */
    {0x15, 0x15, 0x1F},   /* 3 */
    {0x07, 0x04, 0x1F},   /* 4 */
    {0x17, 0x15, 0x1D},   /* 5 */
    {0x1F, 0x15, 0x1D},   /* 6 */
    {0x01, 0x01, 0x1F},   /* 7 */
    {0x1F, 0x15, 0x1F},   /* 8 */
    {0x07, 0x15, 0x1F},   /* 9 */
};

/* A full-width cell for '.' would waste 2 px fifteen times over, so the dot
 * advances 2 instead of 4. */
#define SMALL_ADV(c) (((c) == '.') ? 2 : 4)

int oled_text_small(int x, int y, const char *s)
{
    for (; *s; s++) {
        if (*s == '.') {
            oled_pixel(x, y + 4, true);
        } else if (*s >= '0' && *s <= '9') {
            const uint8_t *g = FONT3X5[*s - '0'];
            for (int col = 0; col < 3; col++) {
                for (int row = 0; row < 5; row++) {
                    if (g[col] & (1u << row)) {
                        oled_pixel(x + col, y + row, true);
                    }
                }
            }
        }
        x += SMALL_ADV(*s);
    }
    return x;
}

int oled_text_small_width(const char *s)
{
    int w = 0;
    for (; *s; s++) {
        w += SMALL_ADV(*s);
    }
    return w > 0 ? w - 1 : 0;   /* the trailing gap is not ink */
}

int oled_text(int x, int y, const char *s)
{
    for (; *s; s++) {
        unsigned char c = (unsigned char)*s;
        if (c < 0x20 || c > 0x7E) {
            c = '?';
        }
        const uint8_t *g = FONT5X7[c - 0x20];
        for (int col = 0; col < 5; col++) {
            for (int row = 0; row < 7; row++) {
                if (g[col] & (1u << row)) {
                    oled_pixel(x + col, y + row, true);
                }
            }
        }
        x += 6;
    }
    return x;
}

int oled_text_width(const char *s, int scale)
{
    int n = 0;
    for (const char *p = s; *p; p++) {
        n++;
    }
    return n * 6 * scale;
}

int oled_text_scaled(int x, int y, const char *s, int scale)
{
    if (scale <= 1) {
        return oled_text(x, y, s);
    }
    for (; *s; s++) {
        unsigned char c = (unsigned char)*s;
        if (c < 0x20 || c > 0x7E) {
            c = '?';
        }
        const uint8_t *g = FONT5X7[c - 0x20];
        for (int col = 0; col < 5; col++) {
            for (int row = 0; row < 7; row++) {
                if (!(g[col] & (1u << row))) {
                    continue;
                }
                /* Each source pixel becomes a scale x scale block. */
                for (int dy = 0; dy < scale; dy++) {
                    for (int dx = 0; dx < scale; dx++) {
                        oled_pixel(x + col * scale + dx, y + row * scale + dy, true);
                    }
                }
            }
        }
        x += 6 * scale;
    }
    return x;
}

void oled_invert_rect(int x, int y, int w, int h)
{
    for (int j = 0; j < h; j++) {
        int yy = y + j + s_shift_y;
        if (yy < 0 || yy >= OLED_H) {
            continue;
        }
        for (int i = 0; i < w; i++) {
            int xx = x + i + s_shift_x;
            if (xx < 0 || xx >= OLED_W) {
                continue;
            }
            s_fb[(yy / 8) * OLED_W + xx] ^= (uint8_t)(1u << (yy & 7));
        }
    }
}

void oled_hline(int x, int y, int w) { oled_fill_rect(x, y, w, 1, true); }
void oled_vline(int x, int y, int h) { oled_fill_rect(x, y, 1, h, true); }

void oled_rect(int x, int y, int w, int h)
{
    oled_hline(x, y, w);
    oled_hline(x, y + h - 1, w);
    oled_vline(x, y, h);
    oled_vline(x + w - 1, y, h);
}

void oled_blit(int x, int y, int w, int h, const uint8_t *bits)
{
    int stride = (w + 7) / 8;
    for (int row = 0; row < h; row++) {
        const uint8_t *line = bits + (size_t)row * stride;
        for (int col = 0; col < w; col++) {
            if (line[col >> 3] & (0x80u >> (col & 7))) {
                oled_pixel(x + col, y + row, true);
            }
        }
    }
}

esp_err_t oled_flush(void)
{
    /* One transfer per page: control byte plus a row of 128 columns. */
    uint8_t buf[1 + OLED_W];
    buf[0] = CTRL_DATA;

    for (int page = 0; page < OLED_PAGES; page++) {
        esp_err_t err = cmd(0xB0 | page);
        if (err != ESP_OK) {
            return err;
        }
        /* Column address is split across two commands, low nibble first. */
        cmd(0x00 | (OLED_COL_OFFSET & 0x0F));
        cmd(0x10 | (OLED_COL_OFFSET >> 4));

        memcpy(&buf[1], &s_fb[page * OLED_W], OLED_W);
        err = i2c_master_transmit(s_dev, buf, sizeof(buf), 100);
        if (err != ESP_OK) {
            return err;
        }
    }
    return ESP_OK;
}

const uint8_t *oled_framebuffer(void) { return s_fb; }
size_t oled_framebuffer_size(void) { return sizeof(s_fb); }

esp_err_t oled_set_contrast(uint8_t level)
{
    return cmd2(0x81, level);
}

esp_err_t oled_display_on(bool on)
{
    return cmd(on ? 0xAF : 0xAE);
}
