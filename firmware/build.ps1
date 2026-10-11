# Build helper -- activates ESP-IDF and works around the EIM offline-mirror trap.
# Usage:  .\build.ps1            (build)
#         .\build.ps1 flash monitor -p COM7
#
# The working config lives in firmware/sdkconfig and builds into build/.
# As of 2026-08-23 that is the ESP32-C3 SuperMini: target esp32c3, board
# profile ATT_BOARD_C3, console on USB Serial/JTAG, fpm tx=20 rx=21 detect=2,
# eth rst=-1. Going back to the WROOM means "idf.py set-target esp32", which
# regenerates sdkconfig -- keep a copy of this one first.
param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Rest)

. C:\Espressif\tools\Microsoft.v6.1.PowerShell_profile.ps1 | Out-Null

# EIM points the component manager at a local mirror; that makes managed
# dependencies silently resolve to nothing. See docs/toolchain.md.
Remove-Item Env:\IDF_COMPONENT_LOCAL_STORAGE_URL -ErrorAction SilentlyContinue

if (-not $Rest -or $Rest.Count -eq 0) { $Rest = @('build') }
idf.py -B build @Rest
