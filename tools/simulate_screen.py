#!/usr/bin/env python3
"""Reproduce the terminal's OLED framebuffer on the PC.

Mirrors the drawing primitives in firmware/main/oled.c and the layout in
draw_idle() so a 128x64 screen can be inspected without flashing. The font is
parsed straight out of oled.c rather than copied, so it cannot drift.

    python tools/simulate_screen.py
    python tools/simulate_screen.py --mode out --strings
"""

import argparse
import re
import pathlib
import sys

# The Windows console defaults to cp1252, which cannot encode block glyphs.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

W, H = 128, 64
OLED = pathlib.Path(__file__).resolve().parents[1] / "firmware/main/oled.c"


def load_font():
    src = OLED.read_text(encoding="utf-8")
    body = src[src.index("static const uint8_t FONT5X7"):]
    body = body[body.index("{"): body.index("};") + 1]
    rows = re.findall(r"\{([^{}]+)\}", body)[1:]  # first match is the outer brace
    glyphs = []
    for r in rows:
        vals = [int(v.strip(), 16) for v in r.split(",") if v.strip()]
        if len(vals) == 5:
            glyphs.append(vals)
    return glyphs


FONT = load_font()


class Screen:
    def __init__(self):
        self.px = [[0] * W for _ in range(H)]

    def pixel(self, x, y, on=True):
        if 0 <= x < W and 0 <= y < H:
            self.px[y][x] = 1 if on else 0

    def fill_rect(self, x, y, w, h, on=True):
        for j in range(h):
            for i in range(w):
                self.pixel(x + i, y + j, on)

    def rect(self, x, y, w, h):
        self.fill_rect(x, y, w, 1)
        self.fill_rect(x, y + h - 1, w, 1)
        self.fill_rect(x, y, 1, h)
        self.fill_rect(x + w - 1, y, 1, h)

    def invert_rect(self, x, y, w, h):
        for j in range(h):
            for i in range(w):
                xx, yy = x + i, y + j
                if 0 <= xx < W and 0 <= yy < H:
                    self.px[yy][xx] ^= 1

    def text(self, x, y, s, scale=1):
        for ch in s:
            c = ord(ch)
            if c < 0x20 or c > 0x7E:
                c = ord("?")
            g = FONT[c - 0x20]
            for col in range(5):
                for row in range(7):
                    if g[col] & (1 << row):
                        if scale == 1:
                            self.pixel(x + col, y + row)
                        else:
                            self.fill_rect(x + col * scale, y + row * scale,
                                           scale, scale)
            x += 6 * scale
        return x

    def blit_placeholder(self, y, label):
        """Stands in for an uploaded 128x16 bitmap: the app centres the text
        inside the strip, so approximate that with a centred box."""
        w = min(W - 8, len(label) * 7)
        x0 = (W - w) // 2
        # Rough stand-in for shaped Arabic: strokes, not a solid bar.
        for i in range(0, w, 7):
            self.fill_rect(x0 + i, y + 4, 4, 2)
            self.fill_rect(x0 + i + 1, y + 6, 2, 5)

    def show(self):
        out = ["+" + "-" * W + "+"]
        for y in range(0, H, 2):
            line = []
            for x in range(W):
                t, b = self.px[y][x], self.px[y + 1][x] if y + 1 < H else 0
                line.append([" ", "▄", "▀", "█"][(t << 1) | b])
            out.append("|" + "".join(line) + "|")
        out.append("+" + "-" * W + "+")
        return "\n".join(out)


def text_width(s, scale=1):
    return len(s) * 6 * scale


# mirrors FONT3X5 in oled.c -- columns bit-packed low-bit-first, top row = bit 0
FONT3X5 = [
    (0x1F, 0x11, 0x1F), (0x12, 0x1F, 0x10), (0x1D, 0x15, 0x17),
    (0x15, 0x15, 0x1F), (0x07, 0x04, 0x1F), (0x17, 0x15, 0x1D),
    (0x1F, 0x15, 0x1D), (0x01, 0x01, 0x1F), (0x1F, 0x15, 0x1F),
    (0x07, 0x15, 0x1F),
]


def small_adv(ch):
    return 2 if ch == "." else 4


def text_small(scr, x, y, s):
    for ch in s:
        if ch == ".":
            scr.pixel(x, y + 4)
        elif ch.isdigit():
            g = FONT3X5[int(ch)]
            for col in range(3):
                for row in range(5):
                    if g[col] & (1 << row):
                        scr.pixel(x + col, y + row)
        x += small_adv(ch)
    return x


def text_small_width(s):
    w = sum(small_adv(c) for c in s)
    return w - 1 if w else 0


def draw_net_icon(scr, x, y, connected=True):
    if connected:
        scr.fill_rect(x, y + 4, 2, 3)
        scr.fill_rect(x + 3, y + 2, 2, 5)
        scr.fill_rect(x + 6, y, 2, 7)
    else:
        scr.rect(x, y, 8, 7)
        for i in range(7):
            scr.pixel(x + i, y + i)


def draw_str(scr, y, label, have_bitmap):
    if have_bitmap:
        scr.blit_placeholder(y, label)
        return
    scr.text((W - text_width(label)) // 2, y + 4, label)


def draw_idle(scr, *, mode_out, strings, clock="12:34", suffix="PM",
              date="SUN 21 AUG", pending=3, ip="192.168.137.214"):
    # --- mirrors draw_idle() in attend.c ---
    draw_net_icon(scr, 1, 0)
    if ip:
        text_small(scr, 12, 1, ip)
    if pending > 0:
        n = "999+" if pending > 999 else str(pending)
        scr.text(W - text_width(n), 0, n)

    draw_str(scr, 10, "CHECK OUT" if mode_out else "CHECK IN", strings)
    scr.fill_rect(0, 27, W, 1)

    sw = (text_width(suffix) + 3) if suffix else 0
    scale = 3
    if text_width(clock, scale) + sw > W:
        scale = 2

    w = text_width(clock, scale)
    x = max((W - (w + sw)) // 2, 0)

    clock_y = 31
    scr.text(x, clock_y, clock, scale)
    if suffix:
        scr.text(x + w + 3, clock_y + 7 * scale - 7, suffix)

    scr.text((W - text_width(date)) // 2, 55, date)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=["in", "out"], default="in")
    ap.add_argument("--strings", action="store_true",
                    help="simulate uploaded Arabic bitmaps rather than the ASCII fallback")
    ap.add_argument("--clock", default="12:34")
    ap.add_argument("--suffix", default="PM")
    ap.add_argument("--pending", type=int, default=3)
    ap.add_argument("--ip", default="192.168.137.214",
                    help='address on the network line; "" for no lease yet')
    args = ap.parse_args()

    scr = Screen()
    draw_idle(scr, mode_out=args.mode == "out", strings=args.strings,
              clock=args.clock, suffix=args.suffix, pending=args.pending,
              ip=args.ip)
    print(scr.show())


if __name__ == "__main__":
    main()
