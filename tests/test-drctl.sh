#!/usr/bin/env bash

set -euo pipefail

export DRCTL_SOURCE_ONLY=1
# shellcheck source=../module/bin/drctl
source module/bin/drctl

assert_eq() {
  expected=$1
  actual=$2
  test "$expected" = "$actual" || {
    echo "期望：$expected" >&2
    echo "实际：$actual" >&2
    exit 1
  }
}

assert_eq 'docker.io/library/alpine:latest' "$(normalize_image 'library/alpine:latest')"
assert_eq 'docker.io/library/alpine:latest' "$(normalize_image 'alpine:latest')"
assert_eq 'ghcr.io/example/app:latest' "$(normalize_image 'ghcr.io/example/app:latest')"

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
DATA_ROOT="$temp_dir"
mkdir -p "$DATA_ROOT/alpine"
touch "$DATA_ROOT/alpine/partial-layer"
cleanup_incomplete_destination alpine
test ! -e "$DATA_ROOT/alpine"

mkdir -p "$DATA_ROOT/healthy/rootfs"
cleanup_incomplete_destination healthy
test -d "$DATA_ROOT/healthy/rootfs"

