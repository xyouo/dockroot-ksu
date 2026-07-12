#!/system/bin/sh

MODDIR=${0%/*}
"$MODDIR/bin/drctl" boot >/dev/null 2>&1 &

