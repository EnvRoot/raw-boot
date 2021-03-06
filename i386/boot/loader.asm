bits 16
org 0x600

%define __lba__						1
%define __length__				(((__end__-__start__+0x1ff) & ~0x1ff) / 512)

%define __kernel_lba__		(__lba__ + __length__)

__start__:
mov byte [drive], dl
call cpu_enter_unreal

mov dword [transfer_packet_lba], __kernel_lba__
mov dword [transfer_packet_length], 1
mov byte [transfer_packet_drive], dl
mov word [transfer_packet_buffer512], __end__
mov dword [transfer_packet_location], __end__+0x200
call read_chs

mov eax, [__end__+12]
sub eax, [__end__+8]
mov ebx, 0x200
call round_up
xor edx, edx
div ebx
mov ebx, [__end__+16]
mov dword [kernel_address], ebx
mov ebx, [__end__+8]

mov dl, [drive]
mov dword [transfer_packet_lba], __kernel_lba__
mov dword [transfer_packet_length], eax
mov byte [transfer_packet_drive], dl
mov word [transfer_packet_buffer512], __end__
mov dword [transfer_packet_location], ebx
call read_chs

mov edi, __end__
call get_memory_map_alt

mov eax, jmp_to_kernel
call cpu_enter_protected

cpu_enter_unreal:
	cli
	push ds
	lgdt [gdt_unreal_ptr]
	mov eax, cr0
	or al, 1
	mov cr0, eax
	jmp $+2
	mov bx, 0x08
	mov ds, bx
	and al, 0xfe
	mov cr0, eax
	pop ds
	sti
	ret

get_memory_map:
	xor esi, esi
	push eax
	push ebx
	push ecx
	push edx
	xor ebx, ebx
	get_memory_map_cycle:
		mov eax, 0xe820
		mov ecx, 0x18
		mov edx, 0x534d4150
		int 0x15
		jc get_memory_map_error
		test ebx, ebx
		jz get_memory_map_end
		add di, 0x18
		inc esi
		jmp get_memory_map_cycle
	get_memory_map_end:
		pop edx
		pop ecx
		pop ebx
		pop eax
		ret
	get_memory_map_error:
		pop edx
		pop ecx
		pop ebx
		pop eax
		call get_memory_map_alt
		ret

get_memory_map_alt:
	xor esi, esi
	push eax
	push ebx
	push ecx
	push edx
	get_memory_map_alt_1:
		clc
		xor eax, eax
		int 0x12
		jc get_memory_map_alt_2
		shl eax, 0x0a
		mov dword [es:di], 0
		mov dword [es:di+4], 0
		mov dword [es:di+8], eax
		mov dword [es:di+12], 0
		mov dword [es:di+16], 1
		mov dword [es:di+20], 10b
		add di, 0x18
		inc esi
	get_memory_map_alt_2:
		get_memory_map_alt_2_1:
			mov eax, 0xe801
			xor ebx, ebx
			xor ecx, ecx
			xor edx, edx
			int 0x15
			jc get_memory_map_alt_end
			test edx, edx
			jnz get_memory_map_alt_2_2
			mov ebx, edx
		get_memory_map_alt_2_2:
			shl edx, 0x10
			mov dword [es:di], 0x01000000
			mov dword [es:di+4], 0
			mov dword [es:di+8], edx
			mov dword [es:di+12], 0
			mov dword [es:di+16], 1
			mov dword [es:di+20], 10b
			add di, 0x18
			inc esi
	get_memory_map_alt_end:
		pop edx
		pop ecx
		pop ebx
		pop eax
		ret

; eax - value
; ebx - alignment
round_up:
	push ebx
	dec ebx
	add eax, ebx
	not ebx
	and eax, ebx
	pop ebx
	ret

; Function to convert LBA to CHS
; Input:
; EAX - lba
; DL - drive
; Output:
; EAX(AX) - cylinder(0-1023)
; EBX(BX) - sector(1-63)
; ECX(CX) - head(0-255)
convert_lba_to_chs:
	push di
	push es
	push edx

	push eax					; Get drive parameters; LBA
	xor di, di
	mov es, di
	mov ah, 8
	int 0x13					; DH = number of heads - 1, CL & 0x3f - SPT
	inc dh
	and cl, 0x3f
	mov byte [convert_lba_to_chs_heads], dh
	mov byte [convert_lba_to_chs_sectors], cl
	pop eax					; LBA
	mov ebx, 0	; Get temp value and sector
	mov edx, 0
	mov bl, [convert_lba_to_chs_sectors]
	div ebx
	inc edx
	mov byte [convert_lba_to_chs_sector], dl	; sector
	xor ebx, ebx ; Get head and cylinder
	xor edx, edx
	mov bl, [convert_lba_to_chs_heads]
	div ebx
	xor ebx, ebx
	and eax, 0x3ff
	mov bl, [convert_lba_to_chs_sector] ; sector
	xchg edx, ecx			 ; head
	pop edx
	pop es
	pop di
	ret
	convert_lba_to_chs_sectors:		db 0	; Sectors per Track
	convert_lba_to_chs_heads:	db 0	; Number of heads
	convert_lba_to_chs_sector:	db 0

; Function to format CHS to int 13h CHS
; Input
; AX - cylinder
; BX - sector
; CX - head
; Output:
; DH - head
; 	 [f|e|d|c|b|a|9|8|7|6|5|4|3|2|1|0] <- bits
; CX - [c|c|c|c|c|c|c|c|C|c|s|s|s|s|s|s]
; 	 [c - cylinder; C - high bit; s - sector]
format_chs:
	and ax, 0x3ff
	and bx, 0x3f
	mov dh, cl			; head
	mov ch, al				; cylinder(0:7)
	shr ax, 2
	and ax, 0xc0
	mov cl, al				; cylinder(8:9)
	or cl, bl				; sector
	ret

read_chs:
	pusha
	mov eax, [transfer_packet_lba]
	mov dl, [transfer_packet_drive]
	call convert_lba_to_chs
	call format_chs
	mov bx, [transfer_packet_buffer512]
	mov esi, [transfer_packet_location]
	read_chs_cycle:
		mov eax, [transfer_packet_length]
		test eax, eax
		jz read_chs_done
		mov ax, 0x0201
		int 0x13
		jc read_chs_error

		push cx
		mov cx, 0x80
		and edi, 0xffff
		mov edi, ebx
		read_chs_cycle_transfer:
			mov eax, [edi]
			mov dword [esi], eax
			add edi, 4
			add esi, 4
			loop read_chs_cycle_transfer
		pop cx

		cmp cl, 0x3f
		jl read_chs_cycle_cl

		cmp dh, 0xff
		jl read_chs_cycle_dh
		inc ch
		and cl, 0xc0
	read_chs_cycle_dh:
		inc dh
	read_chs_cycle_cl:
		inc cl
		dec dword [transfer_packet_length]
		jmp read_chs_cycle
	read_chs_error:
		popa
		mov ah, 1
		ret
	read_chs_done:
		popa
		mov ah, 0
		ret

cpu_enter_protected:
	mov dword [cpu_enter_protected_address], eax
	cli
	lgdt [gdt_protected_ptr]
	mov eax, cr0
	or al, 1
	mov cr0, eax
	jmp gdt_protected_code-gdt_protected_null:cpu_enter_protected_done
	cpu_enter_protected_done:
	[bits 32]
	mov eax, [cpu_enter_protected_address]
	jmp eax
	[bits 16]
	cpu_enter_protected_address:	dd	0

gdt_unreal:
	gdt_unreal_ptr:
		dw gdt_unreal_end - gdt_unreal_null - 1
		dd gdt_unreal_null
	gdt_unreal_null:	dq 0
	gdt_unreal_data:	dq 0xcf92000000ffff
	gdt_unreal_end:

transfer_packet:
	transfer_packet_lba:				dd 0
	transfer_packet_length:			dd 0
	transfer_packet_drive:			db 0
	transfer_packet_location:		dd 0
	transfer_packet_buffer512:	dw 0

gdt_protected:
	gdt_protected_ptr:
		dw gdt_protected_end - gdt_protected_null - 1
		dd gdt_protected_null
	gdt_protected_null:	dq 0
	gdt_protected_code:	dq 0xcf9a000000ffff
	gdt_protected_data:	dq 0xcf92000000ffff
	gdt_protected_end:

[bits 32]
jmp_to_kernel:
	mov ax, 0x10
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax
	jmp dword [kernel_address]

kernel_address:		dd 0
drive:						db 0
times 0x400-$+$$	db 0
__end__:
