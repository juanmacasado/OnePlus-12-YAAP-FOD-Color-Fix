# OnePlus 12 YAAP FOD Color Fix

[![CI](https://github.com/juanmacasado/OnePlus-12-YAAP-FOD-Color-Fix/actions/workflows/ci.yml/badge.svg)](https://github.com/juanmacasado/OnePlus-12-YAAP-FOD-Color-Fix/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/juanmacasado/OnePlus-12-YAAP-FOD-Color-Fix)](https://github.com/juanmacasado/OnePlus-12-YAAP-FOD-Color-Fix/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A minimal, zero-daemon KernelSU/Magisk module that fixes the display color
regression triggered by the optical fingerprint-on-display (FOD) sequence on
the OnePlus 12 (`waffle`).

## The problem

On the OnePlus 12 running YAAP (Android 16), the panel's color state degrades
after the under-display fingerprint reader is shown on screen: the vivid,
saturated appearance present right after boot is lost, and it does not come
back until the device is either **rebooted** or **unlocked without using the
fingerprint reader**.

The regression is not specific to custom color profiles — it also affects the
ROM's stock **Saturated** mode, which localizes the bug to the common OPlus
FOD/display kernel path rather than to any user-side configuration.

## Root cause (short version)

The panel uses the optical FOD path without Local HBM (`fp_type=0x188`), and
the active device tree enables `oplus,ofp-need-to-bypass-gamut`. During the
FOD/HBM illumination sequence the OPlus display driver bypasses the DSPP
gamut/PCC state; when HBM turns off, the driver restores seed state `0`,
discarding the visible color state. The logical Android/Pixelworks mode never
changes (`CurrentColorMode=7`, `CurrentRenderIntent=307`), which is why the
regression is invisible to SurfaceFlinger.

The validated runtime workaround is to re-apply loading-effect mode 1 through
the OPlus sysfs seed control:

```sh
printf 101 > /sys/kernel/oplus_display/seed
```

The full investigation — Pixelworks Iris7 baseline, kernel/device-tree
analysis, discarded branches, and the decisive runtime test — is documented in
[docs/TECHNICAL-NOTES.md](docs/TECHNICAL-NOTES.md).

## What the module does

```text
KernelSU/Magisk starts service.sh
        |
        v
wait until sys.boot_completed == 1
        |
        v
sleep 5 seconds
        |
        v
verify /sys/kernel/oplus_display/seed is writable
        |
        v
printf 101 > /sys/kernel/oplus_display/seed
        |
        v
exit
```

One sysfs write after boot; then no resident process, so **zero ongoing CPU or
battery cost**. The corrected color state survives subsequent fingerprint
unlocks.

### What it deliberately does *not* do

- No overlay payload over `/system`, `/vendor`, or `/odm`
- No DTBO or kernel-module (`msm_drm.ko`) replacement
- No SurfaceFlinger or composer restart
- No event monitor, polling loop, or persistent daemon

It coexists cleanly with a separate Native/Wide-AMOLED display-mode module.

## Requirements

- OnePlus 12 — or a compatible device/kernel exposing
  `/sys/kernel/oplus_display/seed` (the installer checks for it and aborts if
  absent)
- Root via KernelSU, SukiSU, Magisk, or another manager that executes
  `service.sh`
- Developed and validated on YAAP Android 16

## Installation

Download the ZIP from the
[latest release](https://github.com/juanmacasado/OnePlus-12-YAAP-FOD-Color-Fix/releases/latest)
and install it from your root manager, then reboot.

From a terminal with KernelSU/SukiSU:

```sh
adb push OP12-FOD-Color-Fix-v1.0.2.zip /sdcard/Download/
adb shell su -c 'ksud module install /sdcard/Download/OP12-FOD-Color-Fix-v1.0.2.zip'
adb reboot
```

### Verify

After the reboot:

```sh
adb shell su -c 'cat /sys/kernel/oplus_display/seed'
```

Expected output: `101`.

### Disable / remove

Use the root manager, or:

```sh
su -c 'touch /data/adb/modules/op12_fod_color_fix/disable'   # disable
su -c 'touch /data/adb/modules/op12_fod_color_fix/remove'    # remove
su -c reboot
```

No partition rollback is needed — the module never touches a physical
partition.

## Building from source

```sh
python3 scripts/build.py    # deterministic ZIP in dist/
sh scripts/verify.sh        # static checks + build + ZIP integrity
```

The build is reproducible: the same source tree always produces the same
bytes, and a `.sha256` file is emitted next to the ZIP.

## Compatibility and limitations

Presence of the sysfs node is necessary but does not guarantee that every
ROM/kernel interprets seed value `101` identically; the module was validated
on the OnePlus 12 panel `AA545_P_3_A0005` under YAAP Android 16.

This is a **workaround**, not the upstream fix. The proper correction belongs
in the kernel/device-tree display path where FOD gamut bypass and seed
restoration are handled — see the upstream bug-report summary in
[docs/TECHNICAL-NOTES.md](docs/TECHNICAL-NOTES.md#upstream-bug-report-summary).

## Disclaimer

This project requires a rooted device and writes to a kernel sysfs interface.
It is provided as is, without warranty of any kind; use it at your own risk.
Not affiliated with, or endorsed by, OnePlus, OPPO, Pixelworks, or the YAAP
project.

## License

[MIT](LICENSE) © 2026 Juanma Casado. This repository contains only original
work — no proprietary OnePlus/OPlus binaries, firmware images, or
configuration files are redistributed.
