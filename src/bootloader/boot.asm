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
	jmp main

puts:
	push si
	push ax
	
.loop:
	lodsb
	or al,al
	jz .done

	mov ah,0x0e    ;calls bios interupt
	int 0x10
	jmp .loop

.done:
	pop ax
	pop si
	ret
	
main:
	;set data segment
	mov ax,0
	mov ds,ax
	mov es,ax

	;setup stack
	mov ss,ax
	mov sp,0x7C00          ;where we loaded in memory

	;read from floppy disk
	mov [ebr_drive_number],dl
	mov ax,1
	mov cl,1
	mov bx,0x7E00     ;should after the bootloader
	call disk_read

	;print hello world message
	mov si,msg_hello
	call puts
	
	cli
	hlt


;Error handlers
floppy_error:
	mov si,msg_read_error
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah,0
	int 16h
	jmp 0FFFFh:0
.halt:
	cli
	hlt


; Disk routines

; Convert LBS to CHS
; params: ax: LBS address
; returns:
; cx [bits 0-5]:sector number
; cx [bits 6-15]: cylinder
; dh: header
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

msg_hello:db 'hello world!',ENDL,0
msg_read_error: db 'read from disk failed!',ENDL,0


times 510-($-$$) db 0
dw 0AA55h
