# OnePlus 12 YAAP FOD Color Fix

A minimal KernelSU/Magisk-compatible module for the OnePlus 12 display stack.

## Purpose

Some OnePlus 12 custom-ROM/kernel combinations lose the expected display color
state after the optical fingerprint-on-display sequence. The validated runtime
workaround is to apply loading-effect mode 1 through:

```sh
printf 101 > /sys/kernel/oplus_display/seed
```

The module waits until Android reports a completed boot, waits five additional
seconds, writes the value once, and exits.

## Design

- One one-shot sysfs write after boot
- No persistent process or polling loop
- No files mounted over `/system`, `/vendor`, or `/odm`
- No DTBO or kernel-module replacement
- No SurfaceFlinger or composer restart
- Compatible with a separate Native display-mode module

## Requirements

- OnePlus 12 or a compatible device/kernel exposing:
  `/sys/kernel/oplus_display/seed`
- Root through KernelSU, SukiSU, Magisk, or another compatible module manager
- A module manager that executes `service.sh`

## Installation

Install the ZIP through the root manager and reboot.

Terminal installation with KernelSU/SukiSU:

```sh
su -c 'ksud module install /sdcard/Download/OP12-FOD-Color-Fix-v1.0.2.zip'
su -c reboot
```

## Verification

After reboot:

```sh
su -c 'cat /sys/kernel/oplus_display/seed'
```

The expected value is `101`.

## Removal

Disable or remove the module in the root manager and reboot. The module does
not modify a read-only partition, so no partition restoration is required.

## Scope

This module addresses only the fingerprint-related color-state workaround. It
does not force Native/Wide AMOLED gamut and does not replace `iris_configs.xml`.

## Source

<https://github.com/juanmacasado/OnePlus-12-YAAP-FOD-Color-Fix>
