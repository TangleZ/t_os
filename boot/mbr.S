%include "boot.inc"

SECTION MBR vstart=0x7c00
	mov ax,cs
	mov ds,ax
	mov es,ax
	mov ss,ax
	mov fs,ax
	mov sp,0x7c00 ; set stack pointer reg
	mov ax,0xb800
	mov gs,ax

     ;利用int 0x10 的0x06号功能实现清屏
	mov ax, 0600h
	mov bx, 0700h
	mov cx, 0
	mov dx, 184fh

	int 10h

	mov byte [gs:0x00], '1'
	mov byte [gs:0x01], 0xA4

	mov byte [gs:0x02], ' '
	mov byte [gs:0x03], 0xA4

	mov byte [gs:0x04], 'M'
	mov byte [gs:0x05], 0xA4

	mov byte [gs:0x06], 'B'
	mov byte [gs:0x07], 0xA4

	mov byte [gs:0x08], 'R'
	mov byte [gs:0x09], 0xA4

	;disk opration
	mov eax, LOADER_START_SECTOR
	mov bx, LOADER_BASE_ADDR
	mov cx, 4  ; read sector nums
	call rd_disk_m_16

        jmp LOADER_BASE_ADDR + 0x310

; func: read disk n sectors
rd_disk_m_16:
	; eax=LBA 扇区号
	; bx＝将数据写入的内存地址
	; ex ＝读入的扇区数
	mov esi, eax
	mov di, cx

	; read disk
	; step 1: set the num of sectors
	mov dx, 0x1f2
	mov al, cl
	out dx, al

	; restore ax
	mov eax, esi

	; step2: set LBA addr
	mov dx, 0x1f3 ; low LBA addr
	out dx, al

	mov dx, 0x1f4 ; mid LBA addr
	mov cl, 8
	shr eax, cl
	out dx, al
	
	mov dx, 0x1f5 ; port: high LBA addr
	shr eax, cl
	out dx, al

	shr eax, cl
	and al, 0x0f ; lba 24 ~ 27bit
	or al, 0xe0 ; set 4 ~ 7bit is 1110 for lba mode
	mov dx, 0x1f6 ; port: device
	out dx, al 

	; step3: writing read cmd(0x20) to port 0x1f7
	mov dx, 0x1f7
	mov al, 0x20
	out dx, al

	; setp4: check disk status
.not_ready:
	; now dx == 0x1f7
	nop
	in al, dx
	and al, 0x88 ; the 4bit show disk is ready 
		     ; the 7bit show disk is busy
	cmp al, 0x08
	jnz .not_ready

	; step5: read data from port 0x1f0
	mov ax, di ; di keeps the num of sectors
	mov dx, 256
	mul dx ; ax is the multiply default para
	mov cx, ax ; read one word data from disk every time
		   ; cx keeps how many times we need to read
		   ; ecx is the loop default para 
	mov dx, 0x1f0
.go_on_read:
	in ax, dx
	mov [bx], ax ; bx keeps the mem addr we want to copy to
	add bx, 2 ; move mem addr
	loop .go_on_read
	ret 

        times 510-($-$$) db 0
        db 0x55,0xaa
