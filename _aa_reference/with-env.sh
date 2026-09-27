#!/usr/bin/env bash
# 只为本实验进程补充项目内依赖，不修改宿主 PATH、Git 配置或系统软件包。
set -euo pipefail
ref_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ -d "$ref_dir/.tools/usr" ]]; then
    export PATH="$ref_dir/.tools/usr/bin:$PATH"
    export BISON_PKGDATADIR="$ref_dir/.tools/usr/share/bison"
    export HOSTCFLAGS="${HOSTCFLAGS:-} -I$ref_dir/.tools/usr/include"
    export HOSTLDFLAGS="${HOSTLDFLAGS:-} -L$ref_dir/.tools/usr/lib64"
    export PKG_CONFIG_PATH="$ref_dir/.tools/usr/lib64/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
fi
# 受限执行环境可能把新 clone 的属主映射为 nobody；仅信任本次明确创建的副本。
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0="$(cd -- "$ref_dir/.." && pwd)"
exec "$@"
