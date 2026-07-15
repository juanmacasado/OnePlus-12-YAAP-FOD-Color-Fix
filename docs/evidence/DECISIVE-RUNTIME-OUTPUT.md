# Recovered decisive runtime output

The decisive manual test was recorded as:

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

User observation immediately after the write:

```text
ha recuperado los colores
```

Follow-up after another fingerprint unlock:

```text
siguen correctos tras desbloquear
```

Interpretation:

- The write changed the kernel seed/loading-effect state from `0` to `101`.
- The expected colors returned without changing the Android/Iris logical mode,
  which remained `7 / 307`.
- The restored appearance survived a subsequent fingerprint unlock.
- SELinux remained Enforcing.
