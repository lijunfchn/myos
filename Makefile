# MyOS 构建脚本
#
#   make        构建可引导镜像 myos.img
#   make run    用 QEMU 启动（图形窗口 + 串口）
#   make run-nographic  无图形界面，纯串口演示
#   make clean  清理产物

AS       := as
LD       := ld
OBJCOPY  := objcopy
QEMU     ?= qemu-system-x86_64

ASFLAGS  := --32
LDFLAGS  := -m elf_i386

all: myos.img

boot.o: boot.S
	$(AS) $(ASFLAGS) -o $@ $<

kernel.o: kernel.S
	$(AS) $(ASFLAGS) -o $@ $<

boot.elf: boot.o
	$(LD) $(LDFLAGS) -Ttext 0x7c00 -o $@ $<

kernel.elf: kernel.o
	$(LD) $(LDFLAGS) -Ttext 0x1000 -o $@ $<

boot.bin: boot.elf
	$(OBJCOPY) -O binary $< $@

kernel.bin: kernel.elf
	$(OBJCOPY) -O binary $< $@

# 镜像布局：扇区 0 = 引导扇区，扇区 1.. = 内核
myos.img: boot.bin kernel.bin
	dd if=/dev/zero        of=$@ bs=512 count=64 2>/dev/null
	dd if=boot.bin         of=$@ bs=512 seek=0 conv=notrunc 2>/dev/null
	dd if=kernel.bin       of=$@ bs=512 seek=1 conv=notrunc 2>/dev/null
	@echo "built $@ ($$(stat -c%s $@) bytes)"

run: myos.img
	$(QEMU) -drive file=myos.img,format=raw,if=ide,index=0 -boot c

run-nographic: myos.img
	$(QEMU) -nographic -monitor none -drive file=myos.img,format=raw,if=ide,index=0 -boot c

clean:
	rm -f *.o *.elf *.bin *.img
