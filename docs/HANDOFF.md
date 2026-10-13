# Handoff

Attendance and departure system for a 10â€“50 staff retail store.
ESP32 terminal (fingerprint + OLED + Ethernet) plus a Flutter admin app.

Read [decisions.md](decisions.md) first â€” it records *why* things are the way
they are. [protocol.md](protocol.md) is the deviceâ†”PC contract,
[wiring.md](wiring.md) the harness, [toolchain.md](toolchain.md) the build traps.

---

## 1. Current state

**Firmware: functionally complete.** ~460 KB, 71% of the OTA slot free.
Everything below is verified on real hardware unless marked otherwise.

| Subsystem | State |
|---|---|
| ENC28J60 Ethernet + DHCP | works, but see Â§4 â€” this is the problem area |
| Event ring log (40,960 records) | works; survives power cycles |
| SH1106 128Ã—64 OLED | works |
| FPM12 fingerprint | works â€” enrols, matches, records punches |
| HTTP API + CORS | works; verified end to end with curl |
| Runtime config in NVS | works; verified by writing and re-reading |
| Arabic UI via uploaded bitmaps | works |
| Time sync (SNTP + PC) | works |
| Attendance state machine | works |

**App: Windows desktop is the target and is verified end to end.** 119 unit
tests, a full end-to-end run of the real Windows build against
`tools/mock_terminal.py`, `flutter analyze` clean, `flutter build windows
--release` succeeds. On Windows the database is a real SQLite file.

| Area | State |
|---|---|
| Discovery (own adapters + ARP, ~3.5 s) | works, verified E2E |
| Employees: names, edit, remove-keeps-history | works, verified E2E |
| Events from local DB, manual punch, correction | works, verified E2E |
| Sync with ack; survives manual punches and log resets | works, verified E2E |
| Device settings incl. CHECK IN / OUT mode | works, verified E2E |
| Shift rules + timesheet (+ upcoming / at-work days) | works |
| .xlsx export (Arabic RTL) | works, verified E2E |
| Arabic/English + RTL, dark mode | works, screenshots checked |
| Wi-Fi fallback when Ethernet is unplugged (D15), set from Device -> Wi-Fi | app + mock + widget tests 2026-10-13; firmware compiles, **not yet run on hardware** |
| Telegram alerts sent by the terminal (D14): per punch, late, daily summary | app side + mock verified 2026-10-12; firmware compiles, **not yet run on hardware** |
| App password (lock on open, lock button, set/change/remove in Settings) | works; tested, checked in the web build (2026-10-12) |
| Payroll: wages, overtime pay, late/absence cuts, bonuses/advances, mark paid (frozen), .xlsx | works; unit + widget tested, checked in the web build (2026-10-11). Policy in decisions.md D13 |

### Fixed on 2026-09-30 (keep these fixed)

- A manual punch stopped all later syncing: `highWaterSeq` counted manual rows.
- Clearing the terminal's log restarted its numbering at 1, so sync stalled
  and then overwrote history. Fixed twice: firmware keeps counting across an
  erase (`evlog.c` floor), and the app detects a restart and renumbers
  (`device_seq_base` in the `Meta` table).
- The scanner took any router answering 200 for the terminal, and relocation
  saved it. It now requires the terminal's exact 401 body.
- One keystroke in a token field made the app "configured". Host and token now
  go live together only via `Settings.setConnection` after a successful probe.
- Deleting an employee dropped their history from past timesheets (now a soft
  delete), and assigning a shift rewrote everyone's past (now closes/opens
  assignments from today).
- `setState(() => _future = ...)` returns a Future and asserts; it was in
  `AsyncPage`, so the dashboard asserted every 10 s in debug.
- Snackbars rendered on the outer shell Scaffold and covered page buttons;
  each page now has its own `ScaffoldMessenger`.

---

## 2. Running it

```bash
# firmware â€” user flashes; do not run flash/monitor for them, COM3 is usually busy
cd "D:\New folder (3)\fingerprint_check_in_out\firmware"
.\build.ps1 build
.\build.ps1 flash monitor -p COM3

# app
cd "D:\New folder (3)\fingerprint_check_in_out\app"
flutter run -d windows
flutter test
flutter analyze
flutter build windows --release   # ship build\windows\x64\runner\Release\ (whole folder)

# end to end, without hardware: a mock terminal on the ICS adapter, then the
# real Windows app driven through every page (screenshots in build\e2e_shots)
python tools\mock_terminal.py --host 192.168.137.1
flutter test integration_test -d windows
```

The mock speaks the firmware's API exactly (routes, JSON, the 401 body the
scanner keys on, sequence rules, enrolment states). Its token is a test value
in the script. Restart it between E2E runs; it keeps state in memory.

`build.ps1` exists because the EIM installer sets
`IDF_COMPONENT_LOCAL_STORAGE_URL` to a local mirror, which makes managed
dependencies silently resolve to nothing. It clears that first. **Do not call
`idf.py` directly** without doing the same.

Two more toolchain facts, both cost time before:
- `idf.py build` does **not** reliably re-parse Kconfig. After editing
  `Kconfig.projbuild`, run `idf.py reconfigure` or a new `CONFIG_*` comes back
  "undeclared".
- Back-to-back builds in one shell command hit a ninja lock error. Delete
  `build\.ninja_lock` and re-run; it is not a real failure.

### Device

Token: `[device-token]` (in NVS, survives reflash; cleared by
`erase-flash` or a `config`/`all` reset).
Address is DHCP and moves constantly â€” it has been on `192.168.137.x` and
`192.168.0.x`. The app finds it automatically; from a shell use
`arp -a | findstr [device-mac]`.

### Seeing the screen

Do not reason about the 128Ã—64 layout in your head â€” that caused several
rounds of shipping broken layouts.

```bash
python tools\screenshot.py --ip <ip> --token <token>   # real device framebuffer
python tools\simulate_screen.py --mode in --strings    # render locally, no flash
```

`simulate_screen.py` parses the font out of `oled.c` and mirrors `draw_idle()`.
**If you change the layout in `attend.c`, change it there too** or it lies.

---

## 3. Layout of the repo

```
firmware/main/      attend.c   state machine + all screen drawing
                    api_server.c  HTTP API (routes table at the bottom)
                    cfg.c      runtime config + uploaded string bitmaps
                    evlog.c    16-byte event ring in raw flash
                    fpm.c      FPM12 EF01 protocol
                    oled.c     SH1106 driver + drawing primitives
                    net_eth.c  Ethernet, DHCP fallback, wedge watchdog
                    users.c    employee/slot registry
                    timesync.c clock with provisional-time handling
firmware/components/enc28j60/  VENDORED and patched â€” see its README
app/lib/data/       api_client, database (drift), sync_service,
                    device_scanner, name_raster, device_strings, settings
app/lib/domain/     attendance_rules (pure calculation), timesheet,
                    timesheet_report, xlsx_writer (hand-rolled, RTL)
app/lib/ui/         shell, connecting, dashboard, employees, events,
                    timesheet, shifts, device, settings, theme
tools/              api.ps1, screenshot.py, simulate_screen.py
```

### Things that will bite

- **`ui_string_t` in `cfg.h` and `DeviceString` in `device_strings.dart` are a
  wire contract.** Slot numbers must match. Append only. A test enforces it.
- **`max_uri_handlers` must exceed the route count.** Sizing it exactly dropped
  the wildcard OPTIONS handler, so every browser request 405'd and the whole app
  broke. Registration failures are now logged.
- **AppScope wraps the Navigator** (`MaterialApp.builder`), not `home`. It
  used to wrap `home`, which made every pushed page and dialog unable to
  reach it (Timesheet -> Shifts crashed). `test/app_scope_test.dart` guards it.
- **The `storage` partition has a sector map** in `firmware/main/store.h`.
  Add new records there; never write sectors another module owns.
- **"Ethernet is up" means link AND address** (`net_wifi.c` eth_usable).
  `net_eth_got_ip()` alone is true with no cable once the static fallback
  fires. Use `net_any_got_ip()` / `net_active_ip()` for "is it online".
- **The roster's binary layout is a wire contract** between
  `roster_push.dart` and `notify.c` (documented in protocol.md and
  notify.h). `test/roster_push_test.dart` parses it the way the C does.
- **App password is a lock, not encryption.** Settings stores a salted,
  iterated SHA-256 (`app_password` in shared preferences); the database itself
  is not encrypted. Forgotten password: close the app and delete the
  `flutter.app_password` entry from
  `%APPDATA%\com.store\attendance_admin\shared_preferences.json` (keep the
  rest; it holds the device address and token). Dialogs must receive Settings
  through their constructor: they sit above `AppScope` on the navigator, and a
  lookup there returned null and crashed Save once.
- **A paid month is a snapshot, not a calculation.** `PayrollRepository.load`
  returns the frozen JSON for any month in `PayrollRuns`; changing
  `Payroll.compute` does not change months already paid, by design. Edits to a
  paid month throw `MonthClosedException`.
- **Amounts in the payroll UI are wrapped in LTR isolates** (`_Money`) with a
  no-break space before the currency. Without the isolate Arabic reorders
  "−400.00 EGP"; without the no-break space the label wraps.
- **Commit before ack.** `sync_service` stores punches locally *then* acks.
  Reversing that loses attendance on a crash.
- **`draw_str` blits a 128Ã—16 bitmap when uploaded, else ASCII.** Do not invert a
  whole strip after blitting â€” it lights every background pixel.

---

## 4. Open problems

### ENC28J60 â€” the main one

Four distinct faults so far: corrupted receive pointer, wedged receive, lost
transmit interrupts, and `ECON1.TXRTS` stuck (errata #12 transmit lock-up).

The INT line reads **idle high while transmits stall** â€” the chip never asserts
an interrupt. Either the NT wire to GPIO4 is bad, or it needs a 10 kÎ© pull-up
to 3.3 V. Hardware, not software.

Mitigations in place: a ping watchdog that hardware-resets the chip after three
failures, and the vendored driver now polls every 20 ms instead of depending on
INT, plus recovers a locked transmitter itself.

**Recommendation, repeatedly given and still standing: fit a W5500.** Same
wiring, in-core ESP-IDF driver, 100 Mbps, none of these errata. Switching is a
Kconfig flip â€” `ATT_ETH_W5500` â€” plus deleting the vendored component. A user
who prefers to keep the ENC28J60 has been told the cost; do not re-litigate it
unprompted, but do report `eth_resets` climbing.

### Smaller

- **Enrolment sometimes fails** with "failed to combine character files" â€” the
  two scans would not merge. Now bounded (45 s timeout, releases the device).
- **AM/PM stays Latin in Arabic.** Needs Øµ/Ù… as two more string slots, or use
  24-hour. User was asked which; no answer yet.
- **Sensor capacity is 240 templates, not the 1000 advertised.** 80 staff at
  3 fingers each. Fine for this store, but it is a hard ceiling.
- **The `evlog.c` sequence floor fix is compiled but not yet flashed.** On
  2026-10-11 the project moved to a new PC with ESP-IDF v6.1 and it built
  cleanly there (old build output kept in `firmware/build_oldpc`). Until it is
  flashed, the app's own reset detection covers the old firmware.
- **The export goes straight to Documents** and overwrites a file of the same
  name. A save dialog (`file_selector`) would be friendlier.

---

## 5. What is left

Cloud sync was **dropped from scope** (see decisions.md D2). Reporting is the
local timesheet plus the .xlsx export; no Google account is involved.

Remaining, roughly in order of value:

Done on 2026-09-30: manual punch entry, punch time correction (both on the
Events page, reason required, audited), and the Windows build.

1. **Flash the `evlog.c` fix** (built 2026-10-11, see Â§4).
2. **Roster editing.** `RosterEntries` is read by the resolver and covered by
   tests, but the shift editor only handles standing assignments -- no calendar
   for per-date overrides.
3. **WebSocket live push** so the dashboard updates on a scan instead of
   polling. Purely cosmetic; correctness never depended on it.
4. **OTA firmware upload** from the app. The partition table already reserves
   two 1.5 MB slots for it.
5. **Save dialog for exports** instead of writing straight to Documents.

## 6. Working with this user

- **They flash the device themselves** and paste the boot log back. Hand over
  the command; do not run flash/monitor.
- **Their logs are the best diagnostic** and have repeatedly contained the real
  answer â€” the 240-template capacity, the INT line state, the handler-table
  overflow.
- They are building a real product for a real shop. Blunt trade-offs land
  better than reassurance.
- Do not remove things they did not ask you to remove. That happened with the
  "place finger" prompt and was rightly called out.
