#!/usr/bin/env bash

set -euo pipefail

export DRCTL_SOURCE_ONLY=1
# shellcheck source=../module/bin/drctl
source module/bin/drctl

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
STATE_DIR="$temp_dir/state"
STACK_DIR="$STATE_DIR/stacks"
DATA_ROOT="$STATE_DIR/data"
AUTOSTART_FILE="$STATE_DIR/autostart.list"
mkdir -p "$STACK_DIR" "$DATA_ROOT/openlist/rootfs"
: > "$AUTOSTART_FILE"

cat > "$STACK_DIR/openlist.conf" <<EOF
IMAGE=openlistteam/openlist:latest-aio
AUTOSTART=1
VOLUME=$STATE_DIR/volumes/openlist:/opt/openlist/data
ENV=UMASK=022
EOF

calls="$temp_dir/calls"
run_dockroot() { { printf 'run_dockroot'; printf ' <%s>' "$@"; printf '\n'; } >> "$calls"; }
pull_image() { printf 'pull_image <%s> <%s>\n' "$1" "$2" >> "$calls"; }
autostart_add() { printf '%s\n' "$1" >> "$AUTOSTART_FILE"; }
autostart_remove() { :; }

apply_stack openlist
grep -F 'run_dockroot <run> <--renew> <-v>' "$calls"
grep -F "<$STATE_DIR/volumes/openlist:/opt/openlist/data>" "$calls"
grep -F '<-e> <UMASK=022>' "$calls"
grep -F '<openlist> </bin/sh> <-c> <true>' "$calls"
grep -Fx 'openlist' "$AUTOSTART_FILE"
test -d "$STATE_DIR/volumes/openlist"

rm -rf "$DATA_ROOT/openlist/rootfs"
apply_stack openlist
grep -F 'pull_image <openlistteam/openlist:latest-aio> <openlist>' "$calls"

mkdir -p "$DATA_ROOT/incomplete"
touch "$RUNTIME_DIR/old.download.123" 2>/dev/null || true
cleanup_state > "$temp_dir/preview"
test -d "$DATA_ROOT/incomplete"
grep -F "$DATA_ROOT/incomplete" "$temp_dir/preview"
cleanup_state --yes >/dev/null
test ! -e "$DATA_ROOT/incomplete"
