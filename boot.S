/*
 * MyOS 引导扇区 (512 字节)
 *
 * 职责：
 *   1. 建立实模式的段寄存器与栈
 *   2. 通过 BIOS int 13h 把内核从第 2 个扇区读到 0x1000
 *   3. 输出启动信息后跳转到内核
 *
 * 汇编语法：GNU as (AT&T)，16 位实模式。
 */

.code16
.section .text
.global _start

_start:
    cli
    xorw %ax, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %ss
    movw $0x7c00, %sp
    sti

    movb %dl, boot_drive        /* 保存 BIOS 传来的启动盘号 */
    movw $msg_loading, %si
    call print_string

    movb $0x00, %ah             /* 复位磁盘 */
    movb boot_drive, %dl
    int  $0x13

    movw $0x0000, %ax
    movw %ax, %es               /* ES = 0 */
    movw $0x1000, buf_ptr       /* 内核载入地址 0000:1000 */
    movb $2, sec_num            /* 从第 2 个扇区开始 */
    movb $16, sec_left          /* 逐扇区读取 16 个扇区 */

read_loop:
    movw buf_ptr, %bx
    movb $0x02, %ah             /* 读扇区 */
    movb $0x01, %al
    movb $0x00, %ch             /* 柱面 0 */
    movb sec_num, %cl
    movb $0x00, %dh             /* 磁头 0 */
    movb boot_drive, %dl
    int  $0x13
    jc   disk_error
    addw $0x200, buf_ptr         /* 指向下一个扇区缓冲区 */
    incb sec_num
    decb sec_left
    jnz  read_loop

    movw $msg_ok, %si
    call print_string
    ljmp $0x0000, $0x1000        /* 跳转到内核入口 */

disk_error:
    movw $msg_err, %si
    call print_string
1:
    hlt
    jmp 1b

/* ---------- 字符输出：同时送 VGA 文本模式与 COM1 串口 ---------- */
putc:
    pushw %ax
    movb $0x0e, %ah
    movw $0x0007, %bx
    int  $0x10
    popw %ax
    pushw %ax
    call serial_putc
    popw %ax
    ret

serial_putc:
    pushw %ax
    pushw %bx
    pushw %dx
    movb %al, %bl
    movw $0x3fd, %dx            /* 等待发送保持寄存器空 */
1:
    inb  %dx, %al
    testb $0x20, %al
    jz   1b
    movw $0x3f8, %dx
    movb %bl, %al
    outb %al, %dx
    popw %dx
    popw %bx
    popw %ax
    ret

print_string:
    pushw %si
    pushw %ax
1:
    lodsb
    testb %al, %al
    jz    2f
    call putc
    jmp   1b
2:
    popw %ax
    popw %si
    ret

/* ------------------------------ 数据 ------------------------------ */
msg_loading:
    .asciz "\r\nMyOS booting...\r\n"
msg_ok:
    .asciz "Kernel loaded, jumping to 0x1000.\r\n"
msg_err:
    .asciz "Disk read error!\r\n"
boot_drive:
    .byte 0
buf_ptr:
    .word 0
sec_num:
    .byte 0
sec_left:
    .byte 0

    .org 510
    .word 0xaa55
