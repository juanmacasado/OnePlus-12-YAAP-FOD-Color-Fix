#!/system/bin/sh
# shellcheck disable=SC2034,SC2154

SKIPUNZIP=0
SEED_NODE="/sys/kernel/oplus_display/seed"

ui_print "***************************************"
ui_print " OnePlus 12 YAAP FOD Color Fix v1.0.2"
ui_print "***************************************"
ui_print "- Checking the required kernel interface"

if [ ! -e "$SEED_NODE" ]; then
  abort "! Missing kernel node: $SEED_NODE"
fi

if [ ! -w "$SEED_NODE" ]; then
  abort "! Kernel node is not writable: $SEED_NODE"
fi

ui_print "- Compatible kernel interface detected"
ui_print "- The fix will be applied once after boot"
ui_print "- No overlays or background daemon are used"

set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/customize.sh" 0 0 0755
set_perm "$MODPATH/module.prop" 0 0 0644
set_perm "$MODPATH/README.md" 0 0 0644
set_perm "$MODPATH/CHANGELOG.md" 0 0 0644
set_perm "$MODPATH/LICENSE" 0 0 0644
set_perm "$MODPATH/skip_mount" 0 0 0644
