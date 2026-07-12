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
RUNTIME_DIR="$STATE_DIR/bin"
AUTOSTART_FILE="$STATE_DIR/autostart.list"
mkdir -p "$STACK_DIR" "$RUNTIME_DIR" "$DATA_ROOT/openlist/rootfs"
: > "$AUTOSTART_FILE"
ensure_state() { mkdir -p "$STACK_DIR" "$DATA_ROOT"; }
load_config() { :; }

cat > "$STACK_DIR/openlist.conf" <<EOF
IMAGE=openlistteam/openlist:latest
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
grep -F '<openlist> </bin/true>' "$calls"
if grep -F '<-c>' "$calls"; then
  echo 'apply 不应向 DockRoot 传入会被误解析的 -c' >&2
  exit 1
fi
grep -Fx 'openlist' "$AUTOSTART_FILE"
test -d "$STATE_DIR/volumes/openlist"

rm -rf "$DATA_ROOT/openlist/rootfs"
apply_stack openlist
grep -F 'pull_image <openlistteam/openlist:latest> <openlist>' "$calls"

mkdir -p "$DATA_ROOT/incomplete"
cleanup_state > "$temp_dir/preview"
test -d "$DATA_ROOT/incomplete"
grep -F "$DATA_ROOT/incomplete" "$temp_dir/preview"
cleanup_state --yes >/dev/null
test ! -e "$DATA_ROOT/incomplete"

DATA_ROOT=/
if cleanup_state --yes >/dev/null 2>&1; then
  echo '危险 DATA_ROOT 不应允许清理' >&2
  exit 1
fi
