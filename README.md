# MyOS —— 一个最小的 x86 操作系统

这是一个在 x86 裸机上运行的极简操作系统：没有 Linux、没有文件系统，
只有 **一个 512 字节的引导扇区** + **一个几百字节的内核**，
由 BIOS 直接加载并执行，启动后提供一个可交互的小型命令行。

```
BIOS ──加载──> boot.S (0x7C00, 512B) ──读盘──> kernel.S (0x1000) ──> MyOS> 命令行
```

## 目录结构

| 文件 | 说明 |
| --- | --- |
| `boot.S` | 引导扇区（512 字节）。初始化实模式、通过 BIOS `int 13h` 逐扇区把内核读到 `0x1000`，然后跳转。 |
| `kernel.S` | 内核。清屏、打印欢迎信息，提供 `help` / `about` / `clear` 命令，支持键盘与串口输入。 |
| `Makefile` | 用 GNU `as` / `ld` / `objcopy` 构建可引导镜像 `myos.img`。 |
| `run.sh` | 构建并运行（自动寻找系统 QEMU 或项目内的本地 QEMU）。 |
| `tools/get-qemu.sh` | 在没有 root、系统没装 QEMU 时，把 QEMU 以 `.deb` 形式下载解包到 `.qemu/`。 |

## 构建

只需 binutils（`as`、`ld`、`objcopy`，一般都自带）：

```bash
make
```

产物：

* `boot.bin` —— 正好 512 字节，末尾是魔数 `0x55AA`
* `kernel.bin` —— 内核二进制
* `myos.img` —— 可引导磁盘镜像：扇区 0 = 引导扇区，扇区 1 起 = 内核

## 运行

### 有 root 权限 / 已装 QEMU

```bash
sudo apt install qemu-system-x86    # 若尚未安装
./run.sh              # 弹出 QEMU 图形窗口，直接在 MyOS> 下敲命令
./run.sh --nographic  # 串口连到终端（Ctrl-A 然后 x 退出）
./run.sh --demo       # 自动演示，无需手动输入
```

也可以直接用 Makefile：

```bash
make run             # 图形界面
make run-nographic   # 终端串口
```

### 没有 root 权限（本仓库演示环境）

```bash
./tools/get-qemu.sh   # 下载并解包 QEMU 到 .qemu/，不改动系统
./run.sh --demo       # 自动演示
```

`run.sh` 会自动设置 `LD_LIBRARY_PATH`、`QEMU_MODULE_DIR` 和固件目录，
使用项目里的 `.qemu/bin/qemu-system-x86_64`。

## 演示效果

```
MyOS booting...
Kernel loaded, jumping to 0x1000.

  ==================================
        Welcome to MyOS 0.1
     a tiny bare-metal operating system
  ==================================
  Type 'help' to list commands.

MyOS> help
  Commands: help  about  clear
MyOS> about
  MyOS: a 512-byte boot sector + kernel on bare metal.
MyOS> hello
  Unknown command. Type 'help'.
MyOS> clear
MyOS> about
  MyOS: a 512-byte boot sector + kernel on bare metal.
```

## 实现要点

* **引导扇区**：`-Ttext 0x7c00` 链接，`.org 510` + `.word 0xaa55` 保证正好 512 字节且能被 BIOS 识别。
* **加载内核**：`int 13h` 每次只读 1 个扇区并循环（在 SeaBIOS 下一次读多个扇区不会写入目标内存，逐扇区最稳）。
* **输入输出**：同时写 VGA 文本模式和 COM1 串口，因此 `-nographic` 下也能完整演示。
* **回车处理**：兼容 CR(`0x0d`) 与 LF(`0x0a`)，所以管道/串口喂命令也能正常结束一行。

## 清理

```bash
make clean          # 删除构建产物
rm -rf .qemu        # 删除本地 QEMU（若用 tools/get-qemu.sh 安装）
```
