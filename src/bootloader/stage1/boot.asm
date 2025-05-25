org 0x7c00
bits 16


%define ENDL 0x0D, 0x0A

jmp short start
nop

bdb_oem:                        db 'MSWIN4.1'    
dbd_bytes_per_sector:           dw 512
dbd_sectors_per_cluster:		db 1
dbd_reserved_sectors:			dw 1
dbd_fat_count:					db 2
dbd_dir_entries_count:			dw 0E0h
dbd_total_sectors:				dw 2880
bpb_media_descriptor_type:		db 0F0h
dbd_sectors_per_fat:			dw 9	
dbd_sectors_per_track:			dw 18
dbd_heads:						dw 2
dbd_hidden_sectors:				dd 0
dbd_large_sector_count:			dd 0

ebr_drive_number:				db 0
								db 0
ebr_signature:					db 29h
ebr_volume_id:					db 12h,34h,56h,78h
ebr_volume_label:				db 'ZERO OS    '   ;11bytes
ebr_system_id:					db 'FAT12   '      ;8bytes


;code goes here




start: 
	;set data segment
	mov ax,0
	mov ds,ax
	mov es,ax

	;setup stack
	mov ss,ax
	mov sp,0x7C00          ;where we loaded in memory

	push es
	push word .after
	retf

.after:
	;read from floppy disk
	mov [ebr_drive_number],dl

	;show loading message
	mov si,msg_loading
	call puts

	push es
	mov ah,08h
	int 13h
	jc floppy_error
	pop es

	and cl,0x3F
	xor ch,ch
	mov [dbd_sectors_per_track],cx

	inc dh
	mov [dbd_heads],dh

	; read FAT root directory
	mov ax,[dbd_sectors_per_fat]
	mov bl,[dbd_fat_count]
	xor bh,bh
	mul bx
	add ax,[dbd_reserved_sectors]
	push ax

	; compute the size of root directory
	mov ax,[dbd_sectors_per_fat]
	shl ax,5
	xor dx,dx
	div word [dbd_bytes_per_sector]

	test dx,dx
	jz .root_dir_after
	inc ax

.root_dir_after:
	mov cl,al    ; number of sector to read
	pop ax		 ; LBA of root directory 	
	mov dl,[ebr_drive_number]  
	mov bx, buffer          ;es:bx = buffer
	call disk_read

	;search kernel.bin
	xor  bx,bx
	mov di,buffer

.search_kernel:
	mov si,file_stage2_bin
	mov cx,11
	push di
	repe cmpsb
	pop di
	je .found_kernel

	add di,32
	inc bx
	cmp bx,[dbd_dir_entries_count]
	jl .search_kernel

	jmp kernel_not_found_error

.found_kernel:

	; di :the address of the entry
	mov ax,[di+26]
	mov [stage2_cluster],ax

	; load the FAT
	mov ax,[dbd_reserved_sectors]
	mov bx,buffer
	mov cl,[dbd_sectors_per_fat]
	mov dl,[ebr_drive_number]
	call disk_read

	;read the kernel and process FAT chain
	mov bx, KERNEL_LOAD_SEGMENT
	mov es, bx
	mov bx, KERNEL_LOAD_OFFSET
.load_kernel_loop:
	mov ax,[stage2_cluster]
	add ax,31

	mov cl,1
	mov dl,[ebr_drive_number]
	call disk_read

	add bx,[dbd_bytes_per_sector]

	mov ax,[stage2_cluster]
	mov cx,3
	mul cx
	mov cx,2
	div cx

	mov si,buffer
	add si,ax
	mov ax,[ds:si]

	or dx,dx
	jz .even

.odd:
	shr ax,4
	jmp .next_cluster_after


.even:
	and ax,0xFFF

.next_cluster_after:
	cmp ax,0x0FF8
	jae .read_finish

	mov [stage2_cluster],ax
	jmp .load_kernel_loop

.read_finish:
	mov dl,[ebr_drive_number]
	mov ax,KERNEL_LOAD_SEGMENT
	mov ds,ax
	mov es,ax
	jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

	jmp wait_key_and_reboot

	cli
	hlt


	; Error handlers

floppy_error:
	mov si,msg_read_error
	call puts
	jmp wait_key_and_reboot

kernel_not_found_error:
	mov si,msg_kernel_not_found
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah,0
	int 16h
	jmp 0FFFFh:0
.halt:
	cli
	hlt

;
; Prints a string to the screen
; Params:
;   - ds:si points to string
;
puts:
    ; save registers we will modify
    push si
    push ax
    push bx

.loop:
    lodsb               ; loads next character in al
    or al, al           ; verify if next character is null?
    jz .done

    mov ah, 0x0E        ; call bios interrupt
    mov bh, 0           ; set page number to 0
    int 0x10

    jmp .loop

.done:
    pop bx
    pop ax
    pop si    
    ret

	
;
; Disk routines
;

;
; Converts an LBA address to a CHS address
; Parameters:
;   - ax: LBA address
; Returns:
;   - cx [bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder
;   - dh: head
;
lba_to_chs:
	push ax
	push dx
	
	xor dx,dx            				; dx = 0
	div word [dbd_sectors_per_track]	; ax = LBA / SectorPerTrack
										; dx = LBA % SectorPerTrack
	inc dx
	mov cx,dx

	xor dx,dx
	div word [dbd_heads]

	mov dh,dl
	mov ch,al
	shl ah,6
	or cl,ah

	pop ax
	mov dl,al
	pop ax
	ret

;reload sectors from disk
;	- ax : LBA add
;	- cl : number of sectors to read
;	- dl : drive number
;	- es :bx :memory add

disk_read:
	push ax
	push bx
	push cx
	push dx
	push di

	push cx
	call lba_to_chs
	pop ax
	mov ah,02h
	mov di,3

.retry:
	pusha
	stc
	int 13h
	jnc .done
	
	;read failed
	popa
	call disk_reset
	
	dec di
	test di,di
	jnz .retry

.fail:
	jmp floppy_error

.done:
	popa

	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret

disk_reset:
	pusha
	mov ah,0
	stc
	int 13h
	jc floppy_error
	popa
	ret

msg_loading: db 'loading...',ENDL,0
msg_read_error: db 'read from disk failed!',ENDL,0
msg_kernel_not_found: db 'STAGE2.BIN not found',ENDL,0
file_stage2_bin: db 'STAGE2  BIN'
stage2_cluster:   dw 0

KERNEL_LOAD_SEGMENT: equ 0x2000
KERNEL_LOAD_OFFSET:  equ 0
times 510-($-$$) db 0
dw 0AA55h
buffer: