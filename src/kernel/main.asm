org 0x0
bits 16


%define ENDL 0x0D,0x0A

start: 
	;print
	mov si,msg_hello
	call puts

.halt:
	cli
	hlt
;print a string to the screen
; params:
; ds:si points to string

puts:
	push si
	push ax
	push bx
	
.loop:
	lodsb
	or al,al
	jz .done

	mov ah,0x0E    ;calls bios interupt
	mov bh,0
	int 0x10
	
	jmp .loop

.done:
	pop bx
	pop ax
	pop si
	ret

msg_hello: db 'Hello world from KERNEL!', ENDL, 0
