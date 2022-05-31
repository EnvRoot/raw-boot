bits 16
org 0x7c00

jmp 0:__reload_regs
__reload_regs:
mov ax, 0
mov ds, ax
mov es, ax
mov fs, ax
mov gs, ax
mov ss, ax
mov sp, 0x7c00
mov bp, sp

sti
cld

mov ah, 0x02
mov al, ((stage2_end-stage2_start) / 512) + ((stage2_end-stage2_start) % 512 != 0)
mov bx, 0x600
mov cx, 0x0002
mov dh, 0x00
int 0x13
jnc stg2_loaded
int 0x19
jmp $
stg2_loaded:
	call check_a20
	test ax, ax
	jnz stg2_loaded_jmp
	call enable_a20
	stg2_loaded_jmp:
	jmp 0x600

check_a20:
pushf
    push ds
    push es
    push di
    push si
    cli
    xor ax, ax
    mov es, ax
    not ax
    mov ds, ax
    mov di, 0x0500
    mov si, 0x0510
    mov al, byte [es:di]
    push ax
    mov al, byte [ds:si]
    push ax
    mov byte [es:di], 0x00
    mov byte [ds:si], 0xFF
    cmp byte [es:di], 0xFF
    pop ax
    mov byte [ds:si], al
    pop ax
    mov byte [es:di], al
    mov ax, 0
    je check_a20__exit
    mov ax, 1
check_a20__exit:
    pop si
    pop di
    pop es
    pop ds
    popf
    ret

enable_a20:
	pusha
	mov ax, 0x2402
	int 0x15
	jc enable_a20_kbd_ctrl
	test al, al
	jnz enable_a20_enabled
	mov ax, 0x2403
	int 0x15
	test bx, 2
	jnz enable_a20_port92
	test bx, 1
	jnz enable_a20_kbd_ctrl
	enable_a20_kbd_ctrl:
		cli
		call enable_a20_kbd_ctrl_wait
		mov al, 0xad
		out 0x64, al
		call enable_a20_kbd_ctrl_wait
		mov al, 0xd0
		out 0x64, al
		call enable_a20_kbd_ctrl_wait_2
		in al, 0x60
		push ax
		call enable_a20_kbd_ctrl_wait
		mov al, 0xd1
		out 0x64, al
		call enable_a20_kbd_ctrl_wait
		pop ax
		or al, 2
		out 0x60, al
		call enable_a20_kbd_ctrl_wait
		mov al, 0xae
		out 0x64, al
		call enable_a20_kbd_ctrl_wait
		sti
		jmp enable_a20_enabled
		enable_a20_kbd_ctrl_wait:
			in al,0x64
			test al, 2
			jnz enable_a20_kbd_ctrl_wait
			ret
		enable_a20_kbd_ctrl_wait_2:
			in al,0x64
			test al, 1
			jz enable_a20_kbd_ctrl_wait_2
			ret
	enable_a20_port92:
		in al, 0x92
		test al, 2
		jnz enable_a20_enabled
		or al, 2
		and al, 0xFE
		out 0x92, al
	enable_a20_enabled:
		popa
		mov al, 1
		ret


times 510-$+$$ db 0
dw 0xaa55

stage2_start:
incbin "loader.bin"
stage2_end:
