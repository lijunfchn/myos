#!/usr/bin/env bash
#
# 在没有 root 权限、系统也没装 QEMU 的情况下，
# 把 QEMU 及其依赖以 .deb 形式下载并解包到项目的 .qemu/ 目录。
# 只下载需要的包，不修改系统。
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/.qemu"
DEBS="$DEST/debs"

mkdir -p "$DEBS" "$DEST"
cd "$DEBS"

# QEMU 本体、公共模块、固件(BIOS/VGA BIOS) 及其共享库依赖
PKGS="qemu-system-x86 qemu-system-common qemu-system-data seabios \
libpmem1 libfdt1 librdmacm1 libibverbs1 libslirp0 liburing2 libaio1 \
libndctl6 libdaxctl1 libnl-route-3-200"

echo "==> 下载依赖包到 $DEBS"
for p in $PKGS; do
    if ls "${p}"_*.deb >/dev/null 2>&1 || ls "${p}"-*.deb >/dev/null 2>&1; then
        echo "    [已有] $p"
        continue
    fi
    echo "    [下载] $p"
    apt-get download "$p"
done

echo "==> 解包到 $DEST/root"
rm -rf "$DEST/root"
mkdir -p "$DEST/root"
for f in ./*.deb; do
    dpkg-deb -x "$f" "$DEST/root"
done

echo "==> 整理目录结构"
mkdir -p "$DEST/bin" "$DEST/lib" "$DEST/modules" "$DEST/share"

cp "$DEST/root/usr/bin/qemu-system-x86_64" "$DEST/bin/"
cp -a "$DEST/root/usr/lib/x86_64-linux-gnu/." "$DEST/lib/"
if [ -d "$DEST/root/usr/lib/x86_64-linux-gnu/qemu" ]; then
    cp -a "$DEST/root/usr/lib/x86_64-linux-gnu/qemu/." "$DEST/modules/"
fi
[ -d "$DEST/root/usr/share/qemu" ]    && cp -a "$DEST/root/usr/share/qemu/."    "$DEST/share/"
[ -d "$DEST/root/usr/share/seabios" ] && cp -a "$DEST/root/usr/share/seabios/." "$DEST/share/"

echo
echo "完成！本地 QEMU: $DEST/bin/qemu-system-x86_64"
echo "现在可以运行： ./run.sh            (图形窗口)"
echo "            ./run.sh --nographic (串口/终端)"
echo "            ./run.sh --demo      (自动演示，无需手动输入)"
