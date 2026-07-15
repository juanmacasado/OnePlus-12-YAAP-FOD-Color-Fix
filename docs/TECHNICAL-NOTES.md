# Technical notes — investigation and root cause

**Target device:** OnePlus 12 (`waffle`)
**Development context:** YAAP Android 16, OnePlus/OPlus display stack,
Pixelworks Iris7, KernelSU/SukiSU with Hybrid Mount available
**Outcome:** standalone module `op12_fod_color_fix`

---

## 1. Objective

Correct a color-state regression triggered by the optical
fingerprint-on-display sequence. The visible symptom was that the desired
saturated/wide-looking color state could be present after boot, but was lost
after the screen/FOD unlock cycle.

The issue was not limited to a custom Enhanced profile. It also occurred with
the ROM's stock Saturated mode, so it was not merely a bug in the custom
display-mode application.

The final requirement was a professional, independently distributable module
that:

- addresses only the FOD color regression;
- consumes no persistent CPU or battery;
- does not restart SurfaceFlinger;
- does not alter SELinux;
- does not replace DTBO, a kernel module, framework files, applications, or
  `/odm`/`vendor` content;
- does not depend on OverlayFS or Hybrid Mount;
- can coexist with a separate Native/Wide AMOLED display-mode module.

## 2. Original symptom and baseline

Relevant observed state:

```text
Iris7 Service: IRIS_SERVICE_MODE_BYPASS
Hardware: BYPASS
CurrentColorMode: 7
CurrentRenderIntent: 307
```

SurfaceFlinger identified the active Android color mode as sRGB mode `7`, while
YAAP used render intent `307` for its Saturated path.

At boot, before the first screen-off/unlock cycle, the display could look more
vivid and closer to the desired Wide AMOLED gamut. After locking and unlocking
with the fingerprint reader, that appearance was lost.

Because the same effect occurred in stock Saturated mode, the problem was
localized to the common OPlus FOD/display path rather than only to the custom
display-mode application.

## 3. Chronology of the investigation

### 3.1 Pixelworks and compositor baseline

The active display stack exposed Pixelworks Iris7, but the service and hardware
were in BYPASS mode. The logical mode remained `7 / 307` even when the visible
color rendering changed. This established an important distinction:

- the Android/Iris mode numbers could remain unchanged;
- the actual panel/DSPP/loading-effect state could still be altered by FOD.

### 3.2 Initial `libclstc_fod_color.so` hypothesis

Static analysis found `/odm/lib64/libclstc_fod_color.so` in the compositor-side
FOD color path. The library contained logic around:

- `OnScreenFingerprintIcon`;
- framebuffer/FOD status;
- UCSC/CSC and 3D LUT handling;
- saved and previous FOD state.

YAAP exposed layer names based on `UdfpsControllerOverlay`, not the expected
`OnScreenFingerprintIcon`. A reversible binary test was prepared that changed
only the same-length matcher:

```text
OnScreenFingerprintIcon -> UdfpsControllerOverlay
```

The branch did not become the final fix. During validation, the live ODM
library remained the original file because the module payload/layout was not
mounted as expected under the active Hybrid Mount configuration. In addition,
the report that stock Saturated mode suffered the same regression weakened the
idea that a custom layer-name mismatch alone explained the whole problem.

This branch is retained as historical investigation, not as the recommended
solution. Artifact hashes are recorded in
[evidence/HISTORICAL-HASHES.md](evidence/HISTORICAL-HASHES.md).

### 3.3 Kernel and device-tree analysis

The active panel was identified as:

```text
qcom,mdss_dsi_panel_AA545_P_3_A0005_dsc_cmd
```

The fingerprint type was:

```text
fp_type = 0x188 = 392
```

The Local HBM feature bit is `0x10`, which is absent from `0x188`. Therefore,
this device used the optical FOD path without Local HBM.

The active device tree included:

```text
oplus,ofp-need-to-bypass-gamut
```

Kernel symbols and source analysis showed the relevant OPlus OFP path:

- `oplus_ofp_need_to_bypass_pq`
- `oplus_ofp_bypass_dspp_gamut`
- `oplus_ofp_need_pcc_change`
- `oplus_ofp_set_dspp_pcc_feature`
- HBM handling and restoration functions

The analysis indicated that, for this non-LHBM optical path, FOD could request
PQ/DSPP gamut bypass while the fingerprint illumination sequence was active.
The HBM-off path restored the stored seed mode through the OPlus panel seed
logic. The stored seed value was observed as `0`.

A kernel source patch was identified:

- base: `a61545faf58f2b5c731954ddb5fef484aed4ea69`
- patched commit: `163f3cb903fedf41161b7b1bacb062769e523749`
- subject: `display: preserve DSPP gamut during FOD test`

The conceptual source change was to preserve DSPP gamut instead of assigning a
null payload in the FOD bypass path.

This was strong root-cause evidence, but compiling/replacing `msm_drm.ko` was
not suitable for the final public module.

### 3.4 DTBO experiment

A one-byte DTBO experiment was constructed and audited to disable the boolean
property by renaming:

```text
oplus,ofp-need-to-bypass-gamut
```

to the same-length:

```text
oplus,ofp-need-to-bypass-gamuX
```

Scope:

- active DTBO table entry: index 9;
- exactly one byte changed in the full image;
- no offsets, sizes, structures, or property values changed.

This was a boot-critical experimental route and was not incorporated into the
final FOD module. The recovered record proves construction and static audit,
not a successful on-device result. Image hashes are recorded in
[evidence/HISTORICAL-HASHES.md](evidence/HISTORICAL-HASHES.md).

### 3.5 Separate Native-gamut overlay branch

A separate zero-daemon module was developed to remap:

```xml
<ColorMode ColorMode="7" RenderIntent="307">28</ColorMode>
```

to:

```xml
<ColorMode ColorMode="7" RenderIntent="307">1</ColorMode>
```

in `/odm/etc/iris_configs.xml`.

This branch forces the Native hardware gamut mapping and is conceptually
separate from the FOD color-state workaround.

A later combined test module contained both the Native XML overlay and the
boot-time `seed=101` write. The combined module proved useful during
development, but it was deliberately split so the FOD correction could be
distributed independently.

### 3.6 Decisive runtime test

The decisive manual test produced:

```text
=== PRECHECK ===
Enforcing
1
=== SEED BEFORE ===
0

=== APPLY LOADING EFFECT MODE 1 ===
write_rc=0

=== MODE AFTER ===
101

=== DISPLAY STATE ===
 CurrentColorMode: 7 CurrentRenderIntent: 307

=== FINAL SELINUX ===
Enforcing
1
```

Immediately after the write, the expected colors returned, and they remained
correct after another fingerprint unlock.

This established that:

- the kernel interface accepted the write;
- the visible colors returned;
- the logical display state did not need to change from `7 / 307`;
- the correction survived a subsequent fingerprint unlock;
- SELinux stayed Enforcing;
- no SurfaceFlinger restart was necessary.

This was the basis of the final standalone module. The full recorded output is
in [evidence/DECISIVE-RUNTIME-OUTPUT.md](evidence/DECISIVE-RUNTIME-OUTPUT.md).

## 4. Meaning of `101`

`101` is not an Android `ColorMode` value.

In this OPlus sysfs interface it represents applying loading-effect mode `1`
through the `seed` control path. The readback becomes `101`, while the
Pixelworks/Android color mode can remain `7 / 307`.

That distinction explains why the fix can restore the visible panel state
without changing the display-mode selection.

## 5. Final module architecture

Archive root:

```text
module.prop
customize.sh
service.sh
skip_mount
README.md
CHANGELOG.md
LICENSE
```

Runtime sequence:

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

No process remains running.

### Explicit exclusions

The final FOD-only module contains none of the following:

- `iris_configs.xml`;
- `/system`, `/vendor`, or `/odm` overlay payload;
- Hybrid Mount or OverlayFS rule;
- SELinux policy or state change;
- `setenforce`, `magiskpolicy`, or `supolicy`;
- DTBO image;
- `msm_drm.ko`;
- framework JAR, APK, or native library;
- SurfaceFlinger restart;
- composer-service restart;
- event monitor;
- polling loop;
- persistent daemon.

## 6. Compatibility and limitations

Validated development target:

- OnePlus 12;
- YAAP Android 16;
- OPlus display sysfs exposing `/sys/kernel/oplus_display/seed`;
- optical FOD path;
- module manager capable of running `service.sh`.

The installer intentionally checks for the required sysfs node. Presence of the
node is necessary but does not prove that every ROM/kernel interprets `101`
identically.

The module is a workaround for the observed OPlus display state. The deeper
upstream correction belongs in the kernel/device-tree display path, where FOD
gamut bypass and seed restoration are handled.

## Upstream bug-report summary

### Title

OnePlus 12 optical FOD path loses the active gamut state after fingerprint
unlock

### Description

On the OnePlus 12 panel `AA545_P_3_A0005`, `fp_type=0x188` selects the optical
fingerprint path without Local HBM. The active device tree enables
`oplus,ofp-need-to-bypass-gamut`.

During the FOD/HBM sequence, the OPlus display driver bypasses DSPP gamut/PCC.
The restored seed state is `0`, after which the visible saturated/native-like
color state is lost even though the logical Pixelworks state remains
`CurrentColorMode=7`, `CurrentRenderIntent=307`.

Applying loading-effect mode 1 with:

```sh
printf 101 > /sys/kernel/oplus_display/seed
```

restores the expected colors and they remain correct after another fingerprint
unlock.

The issue also occurs with the ROM's stock Saturated mode, not only with a
custom Enhanced/Native profile.

### Candidate upstream directions

- preserve DSPP gamut during the non-LHBM optical FOD path; or
- restore the correct loading-effect/seed state after HBM off rather than seed
  state `0`; or
- remove the `oplus,ofp-need-to-bypass-gamut` property for this panel only if
  hardware validation confirms it is unnecessary.

The public FOD module is a one-shot workaround, not a substitute for the kernel
fix.
