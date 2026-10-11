# Wiring — ESP32-WROOM-32

Source for the fingerprint spec: vendor page for the FPM12 / F40 optical module
(ecity-iq.com, product 12240).

## FPM12 fingerprint sensor

Confirmed from the vendor page:

| Spec | Value |
|---|---|
| Supply | **3.8 – 7.0 V, 5 V preferred** |
| UART baud | **57600** default |
| Capacity | **1000 templates** |
| Recognition | < 1 s |
| FAR | < 0.001% |
| Wires | 6 (2 of them optional touch) |

Capacity is far beyond what we need — 64 staff x 3 fingers = 192 slots.

| Wire | Function | ESP32 |
|---|---|---|
| Red | VCC | **5 V** (not 3.3 V — below spec minimum) |
| Black | GND | GND |
| White | RX (into sensor) | GPIO **17** (ESP TX) |
| Green | TX (out of sensor) | GPIO **16** (ESP RX) — see hazard below |
| Blue | Touch VCC (optional) | 3.3 V |
| Yellow | Touch signal (optional) | GPIO **34** (input-only) |

The touch wires confirm the sensor has a hardware finger-detect output, so the
firmware can idle instead of polling the sensor. That is what `PIN_FPM_DETECT`
is for.

### Logic level: MEASURED AT 3.3 V -- direct connection is safe

Measured on the green (TX) wire with the sensor powered at 5 V and TX
disconnected: **3.3 V idle**. So the module runs 3.3 V logic on a 5 V supply,
as the R307/ZFM-20 family usually does. No level shifter needed; TX, RX and the
yellow touch line connect straight to the ESP32.

The original concern is kept below for reference, since a replacement sensor
from a different batch should be re-measured rather than assumed.

### (Reference) why the level had to be checked

The sensor must be powered at 5 V, but the vendor page does not state the UART
logic level. Both directions are in question:

- If the sensor's TX idles at **5 V**, it will over-voltage GPIO16 (a 3.3 V pin).
- If the sensor's RX truly needs 5 V logic, the ESP32's 3.3 V TX may not reach
  its input-high threshold (0.7 x 5 V = 3.5 V) and comms will be flaky.

Most modules in this family (R307 / ZFM-20 lineage) use 3.3 V logic even on a
5 V supply, but do not assume it.

**Measure before connecting.** Power the sensor from 5 V, leave TX
disconnected, and measure the green wire against GND with a multimeter. UART
idles high:

- **~3.3 V** -> wire directly, both directions safe.
- **~5 V** -> insert a level shifter (BSS138-based 4-channel board, ~$1) on
  TX, RX, and the yellow touch line. A bare resistor divider on the sensor
  TX -> ESP RX line is an acceptable minimum, but does nothing for the other
  direction.

Apply the same check to the yellow touch signal before wiring it to GPIO34.

## ENC28J60 Ethernet

Confirmed as the 10-pin module: CLK, NT, WOL, SO, SI, SCK, CS, RST, VCC, GND.

| Module | ESP32 | Note |
|---|---|---|
| VCC | **3.3 V** | see warning below |
| GND | GND | |
| SCK | GPIO 18 | |
| SI | GPIO 23 | Serial **In** = MOSI |
| SO | GPIO 19 | Serial **Out** = MISO |
| CS | GPIO 5 | |
| RST | GPIO 26 | |
| NT | GPIO 4 | this is INT |
| CLK | *unconnected* | ENC28J60 clock output, unused |
| WOL | *unconnected* | Wake-on-LAN output, unused |

**3.3 V ONLY.** The 10-pin module has no onboard regulator. 5 V destroys it.
(The larger board with an integrated RJ45 and a regulator does accept 5 V --
this one does not.)

SI/SO are easy to swap because the silkscreen does not say MOSI/MISO.
SI <- ESP MOSI, SO -> ESP MISO.

ENC28J60 draws ~180 mA peaks; give it a solid 3.3 V rail and a 100 uF bulk cap
near the module or you will see random link drops.

### Diagnosing

`enc28j60: revision: 0` followed by `wrong chip ID` means the SPI reads came
back all zeros -- nothing is answering on the bus. Valid ENC28J60 silicon
revisions are 1-7 (commonly 4-6). Revision 0 is therefore always wiring or
power, never software. Check VCC first, then SI/SO orientation.

## OLED -- 1.3" 128x64 SH1106 (4-pin I2C)

| Module | ESP32 |
|---|---|
| VCC | **3.3 V** (not 5 V — its pull-ups would drive 5 V onto GPIO21/22) |
| GND | GND |
| SDA | GPIO 21 |
| SCK (= SCL) | GPIO 22 |

Confirmed working: the boot I2C scan reports `0x3C  OLED`.

If a future module scans as nothing, add 4.7 kOhm pull-ups from SDA and SCL to
3.3 V. The ESP32's internal pull-ups (~45 kOhm) are too weak for 400 kHz.

Driver note: SH1106, not SSD1306. It has 132 columns of RAM behind a 128-pixel
panel, so writes carry a 2-column offset. An SSD1306 driver renders shifted by
2 px with the right edge wrapped.

## Remaining

| Part | ESP32 |
|---|---|
| TTP223 OUT | GPIO 35 (input-only) — configure module for active-LOW idle-HIGH |
| Buzzer | GPIO 32 (drive a passive buzzer through a transistor) |
| Status LED | GPIO 25 via 330 Ohm |
| DS3231 RTC (optional) | shares SDA 21 / SCL 22, addr 0x68 |

## Power

The FPM12 needs 5 V while everything else runs at 3.3 V. Feed the board from a
5 V supply (USB or barrel jack), take 5 V for the sensor from VIN/5V, and let
the onboard regulator supply 3.3 V for the OLED, ENC28J60 and TTP223. Budget
~400 mA peak total.

---

# Wiring — ESP32-C3 SuperMini

The SuperMini breaks out thirteen pins: **GPIO0–GPIO10, GPIO20, GPIO21**.
GPIO18/19 are the native USB pins and are not on the header — which is exactly
why 20/21 are free here: the console goes over USB-C, not a UART.

Twelve of the thirteen are used. GPIO9 is left alone; it is the BOOT button.

| Peripheral | Wire | GPIO |
|---|---|---|
| ENC28J60 | SCK | **4** |
| | SI (MOSI) | **6** |
| | SO (MISO) | **5** |
| | CS | **7** |
| | NT (INT) | **10** |
| | RST | **3** |
| OLED SH1106 | SDA | **0** |
| | SCL | **1** |
| FPM12 | red — VCC | **5V** pad (USB VBUS) |
| | black — GND | GND |
| | white — RX into sensor | **20** (ESP TX) |
| | green — TX out of sensor | **21** (ESP RX) |
| | blue — touch circuit supply | **3V3** pad, *not* 5V |
| | yellow — touch / finger detect out | **2** |
| TTP223 | OUT | **8** |
| Buzzer | — | **not fitted**, no pin left |
| Status LED | — | **not fitted** |

## Two things that differ from the WROOM board

**The console is on USB, not UART0.** `sdkconfig.c3supermini` sets
`CONFIG_ESP_CONSOLE_USB_SERIAL_JTAG=y`. Without it IDF puts the console on
GPIO20/21 — the same pads as the sensor — and the sensor never answers.

The monitor still works, but it attaches to the board's own USB CDC port, which
takes a **different COM number** than a USB-serial bridge did. Windows names it
"USB Serial Device". When the monitor stops working after a hardware change,
check the number before anything else:

```powershell
Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match 'COM\d+' } |
    Select-Object Name, Status
```

The port also drops and re-enumerates on every chip reset, so `idf.py monitor`
sometimes needs restarting rather than reconnecting.

**GPIO2, 8 and 9 are strapping pins**, and GPIO2 carries the sensor's yellow
detect output. This was expected to stop the board booting, since GPIO2 is
sampled at reset and the touch output idles low. **It does not** -- verified on
this hardware with blue on 3V3 and yellow on GPIO2: the board boots, the sensor
answers, and `use_finger_detect` works. The line evidently does not hold the pin
low hard enough or long enough to matter here.

Keep it in mind rather than acting on it: if this board ever stops booting after
a change near the sensor, GPIO2 is the first thing to check, and the test is to
hold a finger on the platen across a reset. Ditto GPIO8 and the TTP223 -- normal
boot ignores GPIO8, but download boot needs it high, so unplug that wire if
flashing will not start.

**ETH RST is not wired** on this build (`ATT_PIN_ETH_RST=-1`). The ENC28J60
watchdog can therefore log a wedge but cannot hardware-reset the chip out of it.
If the ENC28J60 starts wedging in service, wiring RST to a free pin restores
that recovery path.

## Power

The FPM12 still needs **5 V**; 3.3 V is below its 3.8 V minimum and it simply
stays mute. Take the red wire from the SuperMini's `5V` pad, which carries USB
VBUS. Everything else runs off `3V3`.

The onboard 3.3 V regulator is small. The ENC28J60 peaks around 180 mA, and the
470 µF bulk capacitor draws a large inrush at power-up. If the board browns out
or resets when the link comes up, feed the Ethernet module from its own 3.3 V
supply and share only the ground.
