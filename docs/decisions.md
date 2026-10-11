# Design Decisions

Status: agreed with owner, 2026-08-20.

## D1 — Device records, PC computes
The ESP32 terminal is the source of truth for **raw punches only**
`(seq, epoch, employee_id, slot_id, direction, method, flags)`.
Employees, schedules, payroll rules, and reports live on the Windows PC (SQLite).
The device never computes lateness or overtime.

**Why:** keeps firmware small and stable; rule changes never require a reflash.

## D2 — Cloud sync: DEFERRED, out of scope

Originally: the Flutter app would append rows to a permanent Google Sheet via
`spreadsheets.values.append`, with the device posting to a Google Apps Script
Web App when the PC was off.

**Dropped from scope on 2026-08-24 at the owner's request.** Nothing was built;
no code ever referenced it.

Reporting is served instead by the local timesheet and the .xlsx export, which
work offline and need no Google account, OAuth client or deployed script.

The reasoning is kept because it still holds if this comes back:

- Drive's file-update API replaces whole file contents, so "keep updating one
  xlsx" from the device would mean rebuilding and re-uploading the entire
  workbook every time. Sheets `append` is genuinely incremental.
- An Apps Script Web App avoids OAuth and RSA-JWT signing in firmware
  entirely, which is otherwise a serious amount of work on an ESP32.

## D3 — Arabic rendered on the PC, blitted on the device
Employee names are rasterised to 128x16 monochrome bitmaps by the Flutter app
(using Flutter's real text engine, correct shaping + RTL) and shipped with the
user record. Static UI strings are pre-rendered into a build-time atlas.
Device-side text rendering is a plain bitmap blit; no shaper in firmware.

Cost: 256 bytes/user at 1bpp (128x16). 50 users = 12.5 KB.

The panel is 1bpp, so names are 1-bit. Arabic aliases worse than Latin at one
bit -- thin strokes and diacritics get chunky -- so the PC-side rasteriser
should hint/threshold deliberately rather than naively downsampling a greyscale
render. Bold-ish weights at 16 px read better than light ones here.

**Why:** Arabic needs contextual glyph shaping (4 forms per letter) + RTL.
An on-device shaper is ~500 lines and still looks worse.

## D4 — Templates stored on sensor, backed up twice
FPM12 holds templates and does 1:N matching internally (fast). Every template
is additionally `UpChar`-ed to ESP flash **and** to the PC database.
A dead sensor is replaced by re-flashing templates, not re-enrolling 50 people.

## D5 — Multi-finger enrolment + manager manual entry
One employee maps to **several** sensor slots, so the mapping is
`slot_id -> (employee_id, finger_label)`, not 1:1.
Failed reads are resolved by a manager entering the punch in the Flutter app,
with a reason and an audit record. Manual punches stay flagged in all reports.

Per-employee **failed-match counter** is surfaced on the dashboard so a
degrading fingerprint is caught before it becomes a daily problem.

## D6 — IN/OUT by auto-toggle with override
Device tracks each employee's last direction and flips it. TTP223 forces a
direction for the next scan; the LCD shows the pending mode.
On boot the device asks the PC for today's state; if the PC is unreachable it
reconstructs state from its own event log.

## D11 — Display is a 1.3" SH1106 128x64 I2C OLED (revises D3, reopens D7)
Confirmed part: 1.3 inch, 128x64, white, I2C, **SH1106** controller.
(Earlier assumed 1.5" SSD1327 -- corrected.) Consequences:

**Good.** The display leaves the SPI bus entirely, so it no longer contends
with ENC28J60 traffic. Net pin cost is -1 (frees CS/DC/RST, costs SDA/SCL).
Confirmed present at 0x3C by the boot I2C scan.

**SH1106 column offset.** SH1106 has 132 columns of RAM behind a 128-pixel
panel, so every write needs a 2-column offset (`OLED_COL_OFFSET`). Driving it
with an SSD1306 driver appears to work but shifts the image 2 px and wraps the
right edge. This is the single most common SH1106 bug.

**Bad: burn-in.** An attendance terminal shows near-static content 24 hours a
day. Without mitigation the idle screen ghosts permanently within a year or
two. Mitigations are now defaults: dim after 20 s idle, blank after 120 s,
periodic pixel-shift of the idle layout, wake on TTP223 touch or finger-detect.
The touch button therefore has a second job beyond forcing IN/OUT.

**Bandwidth: a non-issue.** A 128x64 1bpp frame is 1024 bytes, ~23 ms at
400 kHz, so ~40 fps full-frame. Partial updates become an optimisation rather
than a requirement. Framebuffer is 1 KB of RAM, down from 8 KB.

**Layout budget.** 64 px tall is tight: realistically a 12 px status strip plus
either three 16 px lines or one 24 px name line and one status line. Screens
must be designed to that, not scaled down from a larger mock.

## D7 — No RTC; bounded time error instead
**REOPENED by D11.** With the OLED on I2C, a DS3231 shares that bus at **zero
additional GPIO cost** (~$1.50). For a system whose entire output is
timestamps, a hardware clock that survives power loss is now cheap enough that
I recommend adding one. The no-RTC behaviour below stays as the fallback when
no RTC is detected on the bus.

Time comes from SNTP and/or the PC over LAN. Last-known-good time is persisted
to NVS every 60 s. After a power cut, punches taken before re-sync are written
with a `PROVISIONAL_TIME` flag and shown for review in the app.

**Why:** no spare GPIO on the C3 pinout, and both time sources are normally
present. Revisit if a hardware clock is wanted (needs I2C + 2 pins).

## D8 — Scheduling: all modes supported
The Flutter app supports fixed-store-hours, per-employee fixed shifts,
rotating rosters, and flexible hours-only, as one model:

    ScheduleTemplate (type: fixed | flexible | roster)
      -> ShiftDefinition (start, end, break, grace_in, grace_out, days_of_week)
    EmployeeSchedule (employee, template, effective_from, effective_to)
    RosterEntry (employee, date, shift)   # rotating overrides

Resolution precedence: RosterEntry > EmployeeSchedule > store default.

## D9 — Language
English by default, Arabic available as a toggle with full RTL mirroring on
both the PC app and the device LCD.

## D10 - Board and Ethernet part (resolved)
Owner has both ESP32-C3 and ESP32-WROOM-32, plus an ENC28J60.

- **Board: ESP32-WROOM-32.** Dual core lets fingerprint matching (~1 s per scan)
  run on core 1 while Ethernet/TLS stay responsive on core 0; the C3 would stall
  both on one core. Also 520 KB RAM vs 400 KB, and ~20 GPIO vs 13.
  C3 kept as spare; pin map is Kconfig-driven so both build from one source.
- **Ethernet: ENC28J60** (on hand). Not in ESP-IDF core -- pulled from the
  component registry. W5500 remains a drop-in upgrade (same wiring, 100 Mbps,
  better maintained) if the ENC28J60 proves flaky; switching is a Kconfig flip.

## D12 — ENC28J60 driver vendored and patched

The registry driver (`espressif/enc28j60` v1.1.0) is copied into
`firmware/components/enc28j60` with two changes, both marked
`LOCAL MODIFICATION` in the source.

**Why.** This build hit four distinct ENC28J60 faults: a corrupted receive
pointer, a wedged receive path, lost transmit interrupts, and finally
`ECON1.TXRTS` stuck asserted ("last transmit still in progress"). The last one
is decisive -- the transmit engine genuinely locks, which is errata #12.

Upstream services the chip **only** when the INT pin is asserted, and applies
the errata #12 `TXRST` workaround **only** from a `TXERIF` interrupt. On this
hardware INT idles high and never fires, so neither ever runs: the link comes
up, nothing can be sent, and no recovery path executes.

**Changes.**
1. `CONFIG_ENC28J60_POLL_MS` (default 20 ms) makes the driver also wake on a
   timer and read the interrupt flags over SPI. Interrupts still work and still
   shorten the wait, so this is a floor, not a replacement -- and it makes the
   INT wire optional.
2. The task checks `ECON1.TXRTS` directly and pulses `TXRST` when it stays set
   across three polls, recovering a locked transmitter without needing an
   interrupt.

**Cost.** We now own this driver. Registry updates must be re-applied by hand;
the component README records both edits.

**Still recommended:** the W5500. Its driver is in ESP-IDF core, it is
100 Mbps, it needs none of these workarounds, and it drops into the same
wiring. This patch makes the fitted part usable; it does not make it good.

## Open
- **O3** Exact LCD controller + interface; FPM12 baud, capacity, logic level.
- **O4** ESP-IDF version: only v6.1-beta1 is provisioned on this machine.
  v5.5.1 stable recommended for a production device (see docs/toolchain.md).
