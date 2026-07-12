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
MODDIR=module
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
CHECK_PORT=5244
HEALTH_URL=http://127.0.0.1:5244/
EOF

calls="$temp_dir/calls"
run_dockroot() { { printf 'run_dockroot'; printf ' <%s>' "$@"; printf '\n'; } >> "$calls"; }
pull_image() { printf 'pull_image <%s> <%s>\n' "$1" "$2" >> "$calls"; }
autostart_add() { printf '%s\n' "$1" >> "$AUTOSTART_FILE"; }
autostart_remove() { :; }
require_runtime() { :; }

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

rm -f "$STACK_DIR/qinglong.conf"
create_stack qinglong 5900
grep -Fx 'IMAGE=whyour/qinglong:latest' "$STACK_DIR/qinglong.conf"
grep -Fx 'VOLUME=/data/adb/dockroot/volumes/qinglong:/ql/data' "$STACK_DIR/qinglong.conf"
grep -Fx 'ENV=QlPort=5900' "$STACK_DIR/qinglong.conf"
grep -Fx 'AUTOSTART=1' "$STACK_DIR/qinglong.conf"
grep -Fx 'ENV=QlGrpcPort=5501' "$STACK_DIR/qinglong.conf"
grep -Fx 'CHECK_PORT=5900' "$STACK_DIR/qinglong.conf"
grep -Fx 'CHECK_PORT=5501' "$STACK_DIR/qinglong.conf"
grep -Fx 'HEALTH_URL=http://127.0.0.1:5900/api/health' "$STACK_DIR/qinglong.conf"

# 生命周期：必须等待旧进程退出，并验证端口、卷和 HTTP 健康后才成功。
running=1
run_failed=0
run_dockroot() {
  case "${1:-} ${2:-}" in
    'stop openlist') running=0 ;;
    'run -d') [ "$run_failed" = 0 ] || return 1; running=1 ;;
  esac
  return 0
}
container_pids() { [ "$running" = 1 ] && echo 1234 || true; }
port_is_listening() { [ "$running" = 1 ]; }
port_listener() { [ "$running" = 1 ] && echo listener || true; }
volume_is_mounted() { [ "$running" = 1 ]; }
health_url_ok() { [ "$running" = 1 ]; }
sleep() { :; }

start_stack openlist

run_failed=1
if start_stack openlist >/dev/null 2>&1; then
  echo '底层启动失败时 start_stack 不应返回成功' >&2
  exit 1
fi

running=1
run_failed=0
container_pids() { echo 1234; }
if stop_stack openlist >/dev/null 2>&1; then
  echo '旧进程不退出时 stop_stack 不应返回成功' >&2
  exit 1
fi
