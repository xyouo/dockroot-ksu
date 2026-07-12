#!/usr/bin/env bash

set -euo pipefail

required=(
  module/module.prop
  module/customize.sh
  module/service.sh
  module/bin/drctl
  module/bin/dockroot-exec
  module/system/bin/drctl
  scripts/package.sh
  README.md
  LICENSE
)

for file in "${required[@]}"; do
  test -s "$file" || { echo "缺少文件：$file" >&2; exit 1; }
done

grep -q '^id=dockroot_ksu$' module/module.prop
grep -q 'DOCKROOT_SHA256=' module/bin/drctl
grep -q 'RURI_SHA256=' module/bin/drctl
grep -q '只支持 host 网络' module/bin/drctl

bash -n module/customize.sh
bash -n module/service.sh
bash -n module/bin/drctl
bash -n module/bin/dockroot-exec
bash -n module/system/bin/drctl
bash -n scripts/package.sh
bash tests/test-drctl.sh
bash tests/test-stacks.sh
