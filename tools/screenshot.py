#!/usr/bin/env python3
"""Fetch and render what the terminal's OLED is currently showing.

Checking a 128x64 layout by describing it in words does not work. This pulls
the actual framebuffer over the API and prints it, so alignment, overlap and
clipping are visible rather than inferred.

    python tools/screenshot.py --ip 192.168.137.102 --token <token>
    python tools/screenshot.py --ip ... --token ... --png screen.png

Set ATT_IP and ATT_TOKEN to skip the flags.
"""

import argparse
import base64
import json
import os
import sys
import urllib.request


def fetch(ip: str, token: str) -> dict:
    req = urllib.request.Request(f"http://{ip}/api/v1/screen")
    req.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(req, timeout=8) as r:
        return json.loads(r.read().decode())


def unpack(raw: bytes, width: int, height: int) -> list[list[int]]:
    """Page-major to a row-major pixel grid.

    Byte (page * width + x) holds eight vertically stacked pixels, LSB at the
    top -- the SH1106/SSD1306 memory layout, not a normal raster.
    """
    pixels = [[0] * width for _ in range(height)]
    pages = height // 8
    for page in range(pages):
        for x in range(width):
            byte = raw[page * width + x]
            for bit in range(8):
                if byte & (1 << bit):
                    pixels[page * 8 + bit][x] = 1
    return pixels


def as_text(pixels, width, height) -> str:
    """Two rows per line using half-block characters, so the aspect ratio in a
    terminal roughly matches the panel."""
    out = ["+" + "-" * width + "+"]
    for y in range(0, height, 2):
        line = []
        for x in range(width):
            top = pixels[y][x]
            bot = pixels[y + 1][x] if y + 1 < height else 0
            line.append(" ▀▄█"[(top << 1) | bot] if (top or bot) else " ")
        out.append("|" + "".join(line) + "|")
    out.append("+" + "-" * width + "+")
    return "\n".join(out)


def write_png(path, pixels, width, height, scale=4):
    """Minimal greyscale PNG so no imaging dependency is needed."""
    import struct
    import zlib

    raw = bytearray()
    for y in range(height):
        for _ in range(scale):
            raw.append(0)  # filter: none
            for x in range(width):
                v = 0xFF if pixels[y][x] else 0x10
                raw.extend([v] * scale)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data +
                struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR",
                 struct.pack(">IIBBBBB", width * scale, height * scale, 8, 0, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ip", default=os.environ.get("ATT_IP"))
    ap.add_argument("--token", default=os.environ.get("ATT_TOKEN"))
    ap.add_argument("--png")
    args = ap.parse_args()

    if not args.ip or not args.token:
        print("need --ip and --token (or ATT_IP / ATT_TOKEN)", file=sys.stderr)
        return 2

    data = fetch(args.ip, args.token)
    width, height = data["width"], data["height"]
    raw = base64.b64decode(data["framebuffer_b64"])

    expected = width * height // 8
    if len(raw) != expected:
        print(f"expected {expected} bytes, got {len(raw)}", file=sys.stderr)
        return 1

    pixels = unpack(raw, width, height)
    print(as_text(pixels, width, height))

    lit = sum(sum(row) for row in pixels)
    print(f"{width}x{height}, {lit} pixels lit ({lit * 100 // (width * height)}%)")

    if args.png:
        write_png(args.png, pixels, width, height)
        print("wrote", args.png)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
