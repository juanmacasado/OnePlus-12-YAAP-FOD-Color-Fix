#!/system/bin/sh

SEED_NODE="/sys/kernel/oplus_display/seed"

until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 2
done

sleep 5

[ -w "$SEED_NODE" ] || exit 0
printf 101 > "$SEED_NODE"

exit 0
