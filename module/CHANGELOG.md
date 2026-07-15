# Changelog

## v1.0.2 — 2026-07-15

- Renamed the project to **OnePlus 12 YAAP FOD Color Fix** and moved the
  repository to `OnePlus-12-YAAP-FOD-Color-Fix`; update URLs adjusted
  accordingly. The internal module `id` is unchanged, so existing installs
  update in place.
- Trimmed the README design list to the points that matter to users.
- No functional changes to the fix itself.

## v1.0.1 — 2026-07-15

- First public GitHub release.
- Added `updateJson` to `module.prop` so root managers can offer in-app
  updates from this repository.
- No functional changes to the fix itself.

## v1.0.0 — 2026-06-27

- Initial standalone release.
- Waits for Android boot completion and an additional five seconds.
- Writes `101` once to `/sys/kernel/oplus_display/seed`.
- Exits immediately after applying the fix.
- Contains no overlay payload, SELinux policy, DTBO, kernel module, framework
  file, application, SurfaceFlinger restart, daemon, or polling loop.
