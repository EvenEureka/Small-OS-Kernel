; kernel.asm - 自制简单操作系统内核

; 内核入口点
[org 0] ; 内核加载地址，这里假设为 0x1000
jmp 0x1000:section_bootloader

; 显示版权信息 不加0就会把这里定义的字符串全部打印；0AH 0DH实现换行
copyright_message db "Lyw_OS v1.0 (C) 2023 by Yiwen Lu 21211160",0AH,0DH,0
; 错误输入提示符
error_message db "Bad command or file name",0AH,0DH,0
; 输入日期提示符
input_date_message db "Input date (yyyymmdd): ",0AH,0DH,0
; 输入时间提示符
input_time_message db "Input time (hhmmss): ",0AH,0DH,0
; 命令提示符
prompt_message db "> ",0
; 程序结束提示
quit_message db "Program terminated, please exit",0AH,0DH,0
; 定义时间和日期使用的字符
hour db 0
minute db 0
second db 0
day db 0
month db 0
year db 0
cen db 0
;char1 db 8 dup(0) ;创建一个8字节的数组，用于暂存日期
;char2 db 6 dup(0) ;创建一个6字节的数组，用于暂存时间
char1 db 0,0,0,0,0,0,0,0
char2 db 0,0,0,0,0,0

section_bootloader:
    ; 初始化段寄存器
    mov ax, cs
    mov ds, ax
    mov es, ax

    call new_line
    ; 初始化屏幕和显示版权信息
    mov si,copyright_message
    call print_string

    xor si,si
 
    call get_date 
    call print_date

    mov al,' '
    call print_char

    call get_time
    call print_time

    ; 主要交互菜单
    call menu

menu:
    ; 可能没有menu 我想仿照window终端做一个
    ; 先显示命令提示符
    push ax
    call new_line
    mov al,'>'
    call print_char

    ; 读取用户输入的命令
    call read_command
    pop ax
    ; 无限循环
    ; jmp menu

read_command:
    ; 读取用户输入的命令函数
    ; 键盘输入d 显示当前日期： 输入新日期：(年月日) 
    ; 键盘输入t 显示当前时间： 输入新时间：(时分秒)
    ; 键盘输入enter键 直接读取下一条命令
    ; 键盘输入q 退出系统
    push ax
    mov ah,0h ; 功能号0h - 从键盘读取一个字符
    int 16h ; 调用BIOS中断读取一个字符
    ; 检查用户输入的字符
    cmp al,'d' ; 输入d
    je display_date
    cmp al,'t' ; 输入t
    je display_time
    cmp al,13 ; 输入enter键
    je menu
    cmp al,'q' ; 输入q
    je quit
    ; 如果输入的不是d t enter q 则提示输入错误
    mov si, error_message
    call print_string

    pop ax
    ret

quit: 
    call new_line
    mov si, quit_message
    call print_string
display_date:
    call new_line
    ; 显示当前日期
    call print_date

    call new_line
    ; 提示用户输入新日期
    mov si, input_date_message
    call print_string

    call new_line
    ; 读取并更新用户输入的新日期
    call read_date

    call new_line
    ; 显示新日期
    call get_date2
    call print_date
    ; 读取下一条命令
    ;jmp next_command
    ; 他应该没有ret
    jmp menu
    ret

display_time:
    call new_line
    ; 显示当前时间
    call print_time

    call new_line
    ; 提示用户输入新时间
    mov si, input_time_message
    call print_string

    call new_line
    ; 读取并更新用户输入的新时间
    call read_time


    call new_line
    ; 显示新时间
    call get_time2
    call print_time
    ; 读取下一条命令
    ;jmp next_command
    ; 他应该没有ret
    jmp menu 
    ret

read_date:
    ; 先读取新日期到数组char1 读取时每一个字节只存一个字符
    push ax
    push bx
    push cx
    mov cx,8 ; cx代表还需读入字符个数
    mov bl,8
    xor si,si
.loop:
    mov ah,0 ;0号功能读取字符,输入后字符的ascii码放在al中
    int 16h
    dec cx ; cx--
    cmp al,bl ; 检查是否按下退格键  bl里的值是8
    je .backspace
    cmp al,13 ; 检查是否按下回车键
    je menu
    sub al,'0' ; 将输入的字符转换为BCD码
    mov [char1+si],al ; 将读取的字符存储到相应的变量
    inc si
    cmp cx,0
    je .done ; 所有字符都读完了
    jmp .loop
.backspace:
    cmp si,0 ;检查是否已经没有字符需要删除
    je .loop
    dec si
    inc cx ; cx++
    mov al,' ' ; 用空格字符覆盖被删除的字符
    mov ah,0eh
    int 10h
    mov al,8
    mov ah,0eh
    int 10h
    jmp .loop
.done:
    pop cx
    pop bx
    pop ax
    call update_date
    ret


update_date:
    push ax 
    mov si,0 
.loop:
    mov al,[char1+si] ; 高位
    mov ah,[char1+si+1] ; 低位
    ; char1里面存的就是ascii码
    ; 合并成一个字节的BCD格式
    shl al,4 ; 高位数字左移4位
    or al,ah ; 低位合并到高位
    cmp si,0 
    je .store_cen
    cmp si,2 
    je .store_year
    cmp si,4 
    je .store_month
    cmp si,6 
    je .store_day
.store_cen:
    mov [cen],al
    inc si  
    inc si  
    jmp .loop
.store_year:
    mov [year],al
    inc si  
    inc si  
    jmp .loop
.store_month:
    mov [month],al
    inc si  
    inc si  
    jmp .loop
.store_day:
    mov [day],al
    jmp .done
.done:
    pop ax 
    call update_date_to_bios
    ret

update_date_to_bios:
    ; 更新日期到BIOS cx dx的数据是要存的，不能放到栈里
    push ax

    mov ah,05h ; 功能号04h - 设置系统日期
    mov ch,[cen] ; 将变量cen的值存入ch
    mov cl,[year] ; 将变量year的值存入cl
    mov dh,[month] ; 将变量month的值存入dh
    mov dl,[day] ; 将变量day的值存入dl
    clc ; CF=0 时钟在走 
    int 1Ah ; 调用BIOS中断设置系统日期

    pop ax
    ret

read_time:
    ; 先读取新时间到数组char2 读取时每一个字节只存一个字符
    push ax
    push bx
    push cx
    mov cx,6 ; cx代表还需读入字符个数
    xor si,si
    mov bl,8
    ;lea di,[char2] ; 存储时间的变量
.loop:
    mov ah,0 ;0号功能读取字符,输入后字符的ascii码放在al中
    int 16h
    dec cx ; cx--
    cmp al,bl ; 检查是否按下退格键
    je .backspace
    cmp al,13 ; 检查是否按下回车键
    je menu
    sub al,'0' ; 将输入的字符转换为BCD码
    mov [char2+si],al ; 将读取的字符存储到相应的变量
    inc si
    cmp cx,0
    je .done ; 所有字符都读完了
    jmp .loop
.backspace:
    cmp si,0 ;检查是否已经没有字符需要删除
    je .loop
    dec si
    inc cx ; cx++
    mov al,' ' ; 用空格字符覆盖被删除的字符
    mov ah,0eh
    int 10h
    mov al,8
    mov ah,0eh
    int 10h
    jmp .loop
.done:
    pop cx
    pop bx
    pop ax
    call update_time
    ret

update_time:
    push ax 
    mov si,0 
.loop:
    mov al,[char2+si] ; 高位
    mov ah,[char2+si+1] ; 低位
    ; char2面存的就是ascii码
    ; 合并成一个字节的BCD格式
    shl al,4 ; 高位数字左移4位
    or al,ah ; 低位合并到高位
    cmp si,0 
    je .store_hour
    cmp si,2 
    je .store_minute
    cmp si,4 
    je .store_second
.store_hour:
    mov [hour],al
    inc si  
    inc si  
    jmp .loop
.store_minute:
    mov [minute],al
    inc si  
    inc si  
    jmp .loop
.store_second:
    mov [second],al
    jmp .done
.done:
    pop ax 
    call update_time_to_bios
    ret  

update_time_to_bios:
    ; 更新时间到BIOS
    push ax
    mov ah,03h ; 功能号02h - 设置系统时间
    mov ch,[hour] ; 将变量hour的值存入ch
    mov cl,[minute] ; 将变量minute的值存入cl
    mov dh,[second] ; 将变量second的值存入dh
    clc 
    int 1Ah ; 调用BIOS中断设置系统时间
    pop ax
    ret

print_string:
    push ax
    push bx
    push cx
    push dx
    ; 打印字符串
    mov ah,0eh
.loop:
    mov al,[si]
    cmp al,0
    je .done
    mov bh,0
    mov bl,7 ;黑底白字
    int 10h
    inc si
    jmp .loop
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

get_time:
    ; 获取时间
    ;push ax
    mov ah, 02h     
    int 1Ah         
    ; 此时CH＝BCD码格式的小时 CL＝BCD码格式的分钟 DH＝BCD码格式的秒 DL＝00H—标准时间，否则，夏令时 CF＝0—时钟在走，否则，时钟停止
    mov [hour], ch
    mov [minute], cl
    mov [second], dh
    ;pop ax
    ret

get_time2:
    mov [hour], ch
    mov [minute], cl
    mov [second], dh
    ret

get_date:
    ; 获取日期
    ;push ax
    mov ah, 04h     
    int 1Ah  
    ; 此时CH＝BCD码格式的世纪 CL＝BCD码格式的年 DH＝BCD码格式的月 DL＝BCD码格式的日 CF＝0—时钟在走，否则，时钟停止
    mov [cen], ch
    mov [year], cl 
    mov [month], dh
    mov [day], dl
    ;pop ax
    ret

get_date2:
    mov [cen], ch
    mov [year], cl 
    mov [month], dh
    mov [day], dl
    ret

print_time:
    push ax
    ; 1. 将时间转换为十进制
    ; 2. 打印时间
    ;mov dl,0 ; 从第0列开始打印
    mov al,[hour]
    call bcd_to_dec
    mov al,":"
    call print_char
    mov al,[minute]
    call bcd_to_dec
    mov al,":"
    call print_char
    mov al,[second]
    call bcd_to_dec
    pop ax
    ret

print_date:
    push ax
    ; 1. 将日期转换为十进制
    ; 2. 打印日期
    mov al,[cen]
    call bcd_to_dec
    mov al,[year]
    call bcd_to_dec
    mov al,"/"
    call print_char
    mov al,[month]
    call bcd_to_dec
    mov al,"/"
    call print_char
    mov al,[day]
    call bcd_to_dec
    pop ax
    ret


bcd_to_dec:
    ; 将BCD码转换为十进制 现在这8个二进制在al中
    push ax 
    push bx 
    mov ah,al  
    shr al,4 ; 右移4位,得到高位对应4个二进制码
    add al,'0' ; 将al转换为ASCII码
    call print_char ; 打印高位字符 
    and ah,0fh ; 与0fh相与,得到低位对应4个二进制码
    xor al,al
    mov al,ah ; 将低位移动到al
    add al,'0' ; 将al转换为ASCII码
    call print_char ; 打印低位字符
    pop bx
    pop ax
    ret 

print_char:
    ; 打印一个字符 存储在al里 dec转换完一个打印一个字符
    push ax
    push bx
    push cx
    mov ah,0eh ; ah = 0eh 表示显示字符
    mov bh,0 ; bh = 0 表示显示页号
    mov bl,7 ; bl = 7 表示显示颜色
    mov cx,1 ; cx = 1 表示显示字符个数
    int 10h ; 调用BIOS中断显示字符

    pop cx
    pop bx
    pop ax
    ret    

new_line:
    push ax
    mov al,0AH
    call print_char
    mov al,0DH
    call print_char
    pop ax
    ret 
