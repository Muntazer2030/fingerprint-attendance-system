# Toolchain Notes (this machine)

## What is installed

Moved to a new PC on 2026-10-11 (repo now at `D:\New folder (3)\fingerprint_check_in_out`).

| Tool | Version | Location |
|---|---|---|
| ESP-IDF | **v6.1** (EIM, provisioned) | `C:\esp\v6.1\esp-idf`, tools in `C:\Espressif\tools` |
| Flutter | 3.47.7 stable / Dart 3.13.5 | `C:\flutter\bin` (user PATH) |
| Python | 3.14 (system); IDF has its own 3.13 venv | on PATH |
| CMake / Ninja | bundled with IDF | `C:\Espressif\tools` |
| Visual Studio | Community 2026 + "Desktop development with C++" | needed for `flutter build windows` |

Windows **Developer Mode** must be on (`start ms-settings:developers`) or
Flutter refuses to build with plugins (needs symlinks).

## Activating ESP-IDF

The EIM installer does NOT use the classic `export.sh` layout. Use the
PowerShell profile instead:

    . C:\Espressif\tools\Microsoft.v6.1.PowerShell_profile.ps1

## TRAP: component manager resolves nothing

The EIM profile sets

    IDF_COMPONENT_LOCAL_STORAGE_URL = file://C:\Espressif\tools

which points the component manager at a local **offline mirror**. Managed
dependencies (e.g. `espressif/enc28j60`) then silently fail to resolve --
`managed_components/` stays empty, no `dependencies.lock` is written, and the
build still reports "Project build complete" because nothing referenced the
missing component yet.

**Always clear it before building:**

    Remove-Item Env:\IDF_COMPONENT_LOCAL_STORAGE_URL -ErrorAction SilentlyContinue

`firmware/build.ps1` does this for you. Verify a dependency really landed by
checking that `firmware/managed_components/` is non-empty and that
`build/esp-idf/<component>/*.a` exists -- not by trusting the build summary.

## Verified working

- Target `esp32` (WROOM-32), custom 4 MB partition table accepted.
- App image 139,840 bytes; 91% of the 1.5 MB OTA slot free.
- `espressif/enc28j60` v1.1.0 (declares `idf: >=4.4`) compiles against v6.1-beta1:
  `esp_eth_mac_enc28j60.c.obj`, `esp_eth_phy_enc28j60.c.obj`, `libespressif__enc28j60.a`.

## Components removed from IDF core in 6.x

v6.x moved several things out of the tree and into the component registry.
Each one surfaces as `Failed to resolve component '<name>'` at cmake time and
is fixed by adding it to `main/idf_component.yml`, not by changing REQUIRES.

| Was in core (5.x) | Now |
|---|---|
| `json` (cJSON) | `espressif/cjson` |
| SPI Ethernet: `w5500`, `dm9051`, `ksz8851snl` | registry components |
| `enc28j60` | `espressif/enc28j60` (was an example even in 5.x) |

Also moved rather than removed: `esp_app_desc.h` now needs an explicit
`esp_app_format` in REQUIRES, and `driver/gpio.h` needs `esp_driver_gpio`.

Current managed dependencies:

    dependencies:
      idf: ">=5.0"
      espressif/enc28j60: "^1.1.0"
      espressif/cjson: "^1.7.19"

## Kconfig edits need an explicit reconfigure

`idf.py build` does not reliably re-parse `Kconfig.projbuild` after an edit, so
a freshly added `CONFIG_*` comes back "undeclared" at compile time even though
the Kconfig is correct. Run `idf.py reconfigure` after touching Kconfig.

## IDF version recommendation

v6.1-beta1 builds everything we need today, so it is not blocking. Still, for a
device meant to run unattended for years I would move to **v5.5.1 stable**:

- v6.x already moved APIs under us once (`esp_app_desc.h` needed an explicit
  `esp_app_format` REQUIRES) and split drivers into many `esp_hal_*` components.
- SPI Ethernet drivers were removed from core in 6.x; `ETH_SPI_ETHERNET_W5500`
  is an unknown Kconfig symbol there.
- Espressif may still change APIs before 6.1 final.
- The Ethernet/TLS path is exactly where ENC28J60 is already known to be flaky;
  debugging that on a beta IDF means guessing whether a bug is ours or theirs.

To switch, install v5.5.x with EIM and point `build.ps1` at its profile.
