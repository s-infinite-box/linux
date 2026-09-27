#!/usr/bin/env bash
# Fedora 主机的可选准备步骤：仅下载并解包，不运行 RPM 安装脚本或修改系统。
set -euo pipefail
ref_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mkdir -p "$ref_dir/.tools/rpms"
dnf --setopt="cachedir=$ref_dir/.tools/dnf-cache" \
    --setopt="logdir=$ref_dir/.tools/dnf-log" \
    --repo=fedora --repo=updates download --arch=x86_64 \
    --destdir="$ref_dir/.tools/rpms" \
    flex bison elfutils-libelf-devel elfutils-libelf zlib-ng-compat-devel busybox
cd "$ref_dir/.tools"
for package in rpms/*.rpm; do
    rpm2cpio "$package" | cpio -idmu --quiet --no-absolute-filenames
done
file usr/bin/busybox
