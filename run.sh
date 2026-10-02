#!/usr/bin/env bash
#
# 构建并运行 MyOS。
#
#   ./run.sh              图形窗口启动（可手动输入命令）
#   ./run.sh --nographic  串口连到当前终端（Ctrl-A x 退出）
#   ./run.sh --demo       自动演示：依次执行 help / about / 未命令 / clear
#
set -euo pipefail

cd "$(dirname "$0")"

# -------------------------- 1. 选择 QEMU --------------------------
QEMU="${QEMU:-}"
LOCAL=0
if [ -z "$QEMU" ]; then
    if command -v qemu-system-x86_64 >/dev/null 2>&1; then
        QEMU="$(command -v qemu-system-x86_64)"
    elif [ -x ".qemu/bin/qemu-system-x86_64" ]; then
        QEMU="$PWD/.qemu/bin/qemu-system-x86_64"
        LOCAL=1
    else
        echo "错误：找不到 qemu-system-x86_64" >&2
        echo "  - 有 root:  sudo apt install qemu-system-x86" >&2
        echo "  - 无 root:  ./tools/get-qemu.sh   (下载到项目 .qemu/)" >&2
        exit 1
    fi
fi

QEMU_ARGS=()
if [ "$LOCAL" = 1 ]; then
    export LD_LIBRARY_PATH="$PWD/.qemu/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export QEMU_MODULE_DIR="$PWD/.qemu/modules"
    QEMU_ARGS+=(-L "$PWD/.qemu/share")
fi

# -------------------------- 2. 构建镜像 --------------------------
make

# -------------------------- 3. 磁盘与机器参数 --------------------------
# 用 IDE 硬盘承载镜像：扇区 0 = 引导扇区，扇区 1.. = 内核
DISK=(-drive "file=myos.img,format=raw,if=ide,index=0" -boot c -no-reboot -nic none)

MODE="${1:-graphic}"
case "$MODE" in
    --nographic)
        exec "$QEMU" "${QEMU_ARGS[@]}" -display none -serial stdio -monitor none "${DISK[@]}"
        ;;
    --demo)
        # 通过串口喂入一串命令，演示内置 shell
        printf 'help\nabout\nhello\nclear\nabout\n' | \
            "$QEMU" "${QEMU_ARGS[@]}" -display none -serial stdio -monitor none "${DISK[@]}"
        ;;
    *)
        exec "$QEMU" "${QEMU_ARGS[@]}" "${DISK[@]}"
        ;;
esac
