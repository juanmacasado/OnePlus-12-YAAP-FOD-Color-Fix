#!/usr/bin/env sh
# Static verification: required files present, shell syntax valid,
# no forbidden runtime behavior, and the ZIP builds and tests clean.
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
MODULE="$ROOT/module"

required="module.prop customize.sh service.sh skip_mount README.md CHANGELOG.md LICENSE"
for f in $required; do
  test -e "$MODULE/$f" || {
    echo "Missing: $f" >&2
    exit 1
  }
done

sh -n "$MODULE/customize.sh"
sh -n "$MODULE/service.sh"

if grep -RniE 'setenforce|magiskpolicy|supolicy|ctl\.restart|stop[[:space:]]+surfaceflinger|iris_configs\.xml|msm_drm\.ko|dtbo' \
  "$MODULE/customize.sh" "$MODULE/service.sh"; then
  echo "Forbidden runtime token found" >&2
  exit 1
fi

version=$(sed -n 's/^version=//p' "$MODULE/module.prop")
ZIP="$ROOT/dist/OP12-FOD-Color-Fix-$version.zip"

python3 "$ROOT/scripts/build.py" >/dev/null
python3 -m zipfile -t "$ZIP"
sha256sum "$ZIP"

echo "Verification passed."
