/*
 * MyOS 内核 (加载并运行于物理地址 0x1000)
 *
 * 运行在 x86 实模式，直接使用 BIOS 调用完成显示与键盘输入，
 * 同时支持 COM1 串口，便于在无图形界面 (qemu -nographic) 下演示。
 *
 * 提供极简命令行，支持命令：help / about / clear
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

    movb $0x03, %al             /* 80x25 彩色文本模式 */
    movb $0x00, %ah
    int  $0x10

    movw $banner, %si
    call print_string

main_loop:
    movw $prompt, %si
    call print_string
    movw $buffer, %di
    call read_line
    movw $buffer, %si
    call handle_command
    jmp  main_loop

/* ---------- 字符输出：VGA + 串口 ---------- */
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
    movw $0x3fd, %dx
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

/* ---------- 读入一个字符：优先串口，其次键盘 ---------- */
getc:
    movw $0x3fd, %dx
    inb  %dx, %al
    testb $0x01, %al            /* 串口有数据？ */
    jnz  1f
    movb $0x01, %ah             /* 键盘有按键？ */
    int  $0x16
    jnz  2f
    jmp  getc
1:
    movw $0x3f8, %dx
    inb  %dx, %al
    ret
2:
    movb $0x00, %ah
    int  $0x16
    ret

/* ---------- 读入一行，支持回车与退格 ---------- */
read_line:
    pushw %ax
    pushw %bx
    pushw %di
    movw %di, %bx
1:
    call getc
    cmpb $0x0d, %al             /* 回车 CR */
    je   3f
    cmpb $0x0a, %al             /* 换行 LF（来自管道/串口） */
    je   3f
    cmpb $0x08, %al
    je   2f
    cmpb $0x20, %al
    jb   1b
    cmpw $buffer_end, %di
    jae  1b
    stosb
    call putc
    jmp  1b
2:
    cmpw %bx, %di
    jbe  1b
    decw %di
    movb $0x08, %al
    call putc
    movb $' ', %al
    call putc
    movb $0x08, %al
    call putc
    jmp  1b
3:
    movb $0x00, (%di)
    movw $newline, %si
    call print_string
    popw %di
    popw %bx
    popw %ax
    ret

/* ---------- 命令分发 ---------- */
handle_command:
    pushw %si
    pushw %di

    movw $cmd_help, %di
    call streq
    testw %ax, %ax
    jnz  do_help

    movw $cmd_about, %di
    call streq
    testw %ax, %ax
    jnz  do_about

    movw $cmd_clear, %di
    call streq
    testw %ax, %ax
    jnz  do_clear

    movw $cmd_empty, %di
    call streq
    testw %ax, %ax
    jnz  hc_done

    movw $msg_unknown, %si
    call print_string
    jmp  hc_done

do_help:
    movw $msg_help, %si
    call print_string
    jmp  hc_done
do_about:
    movw $msg_about, %si
    call print_string
    jmp  hc_done
do_clear:
    movb $0x03, %al
    movb $0x00, %ah
    int  $0x10
hc_done:
    popw %di
    popw %si
    ret

/* ---------- 字符串比较：相等返回 AX=1 ---------- */
streq:
    pushw %si
    pushw %di
1:
    movb (%si), %al
    cmpb (%di), %al
    jne  2f
    testb %al, %al
    jz   3f
    incw %si
    incw %di
    jmp  1b
2:
    xorw %ax, %ax
    popw %di
    popw %si
    ret
3:
    movw $1, %ax
    popw %di
    popw %si
    ret

/* ------------------------------ 数据 ------------------------------ */
banner:
    .ascii "\r\n\r\n  ==================================\r\n"
    .ascii "        Welcome to MyOS 0.1\r\n"
    .ascii "     a tiny bare-metal operating system\r\n"
    .ascii "  ==================================\r\n"
    .asciz "  Type 'help' to list commands.\r\n\r\n"
prompt:
    .asciz "MyOS> "
newline:
    .asciz "\r\n"
msg_help:
    .asciz "  Commands: help  about  clear\r\n"
msg_about:
    .asciz "  MyOS: a 512-byte boot sector + kernel on bare metal.\r\n"
msg_unknown:
    .asciz "  Unknown command. Type 'help'.\r\n"
cmd_help:
    .asciz "help"
cmd_about:
    .asciz "about"
cmd_clear:
    .asciz "clear"
cmd_empty:
    .asciz ""
buffer:
    .space 64
buffer_end:
