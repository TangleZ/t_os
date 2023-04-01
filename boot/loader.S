%include "boot.inc" 
section loader vstart=LOADER_BASE_ADDR ;0x900
LOADER_STACK_TOP equ LOADER_BASE_ADDR
;jmp loader_start

GDT_BASE: dd 0x0000_0000
	  dd 0x0000_0000

CODE_DESC: dd 0x0000_FFFF
	   dd DESC_CODE_HIGH4

DATA_STACK_DESC: dd 0x0000_FFFF
		 dd DESC_DATA_HIGH4

VIDEO_DESC: dd 0x8000_0007 ;limit=(0xbffff - 0xb8000) / 4K = 0x7
	    dd DESC_VIDEO_HIGH4 ;now dp1 is 0

GDT_SIZE equ $ - GDT_BASE
GDT_LIMIT equ GDT_SIZE - 1

times 60 dq 0 ;for empty desc space

SELECTOR_CODE equ (0x0001 << 3) + TI_GDT + RPL0
SELECTOR_DATA equ (0x0002 << 3) + TI_GDT + RPL0
SELECTOR_VIDEO equ (0x0003 << 3) + TI_GDT + RPL0

total_mem_bytes dd 0

;gdt pointer
gdt_ptr dw GDT_LIMIT
	dd GDT_BASE

; algined
ards_buf times 244 db 0
ards_nr dw 0 ;record the num of ARDS

loadermsg db '2 loader in real.'

loader_start:
; INT 0x10 function num: 0x13 func desc: print strings

	mov sp, LOADER_BASE_ADDR
	mov bp, loadermsg ; ES:BP = string addr
	mov cx, 17 ; cx = len of string
	mov ax, 0x1301 ;ah = 13, al = 01
	mov bx, 0x001f ;front setting
	mov dx, 0x1800 ;postion
	int 0x10

; int 15h eax = e820h, edx = 'SMPA' to get mem info
	xor ebx, ebx
	mov edx, 0x534d4150
	mov di, ards_buf
.e820_mem_get_loop:
	mov eax, 0x0000e820
	mov ecx, 20 ;ARDS descip size
	int 0x15
	jc .e820_failed_so_try_e801 ;error occur if cf is 1
	add di, cx
	inc word [ards_nr]
	cmp ebx, 0
	jnz .e820_mem_get_loop

	mov cx, [ards_nr]
	mov ebx, ards_buf
	xor edx, edx
.find_max_mem_area:
	mov eax, [ebx]
	add eax, [ebx+8]
	add ebx, 20
	cmp edx, eax
;boble sort, find the biggest
	jge .next_ards
	mov edx, eax ;edx is sum mem size
.next_ards:
	loop .find_max_mem_area
	jmp .mem_get_ok

.e820_failed_so_try_e801:
	jmp $

.mem_get_ok:
	mov [total_mem_bytes], edx 

; ready to protect mode
	; open a20
	in al, 0x92
	or al, 0000_0010B
	out 0x92, al

	; load GDT
	lgdt [gdt_ptr]

	; set cr0:pe is 1
	mov eax, cr0
	or eax, 0x00000001
	mov cr0, eax

	jmp dword SELECTOR_CODE:p_mode_start  ;flush pipeline

[bits 32]
p_mode_start:
	mov ax, SELECTOR_DATA
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov esp, LOADER_STACK_TOP
	mov ax, SELECTOR_VIDEO
	mov gs, ax

	mov byte [gs:160], 'P'

	call setup_page

	sgdt [gdt_ptr]

	; gdt 描述符中视频段描述符中的段基址＋OxcOOOOOOO
	mov ebx, [gdt_ptr + 2] ;ebx = gdt base 
	or dword [ebx + 0x18 + 4], 0xc0000000 ;0x18 = 3th * 8byte(one section desc)
	; [ebx + 0x18 + 4] is video section base addr

	add dword [gdt_ptr + 2], 0xc0000000

	add esp, 0xc0000000

	;load page dir addr to cr3
	mov eax, PAGE_DIR_TABLE_POS
	mov cr3, eax

	;open cr0:pg bit
	mov eax, cr0
	or eax, 0x80000000
	mov cr0, eax

	;reload gdt ptr
	lgdt [gdt_ptr]

	mov byte [gs:160], 'V' 

	jmp $

; ---------------- setup page -----------------------
setup_page:
	; clear page dir space
	mov ecx, 4096
	mov esi, 0
.clear_page_dir:
	mov byte [PAGE_DIR_TABLE_POS + esi], 0
	inc esi
	loop .clear_page_dir

;start to create PDE
.create_pde:
	mov eax, PAGE_DIR_TABLE_POS
	add eax, 0x1000 ;first page table
	mov ebx, eax

	or eax, PG_US_U | PG_RW_W | PG_P
	mov [PAGE_DIR_TABLE_POS + 0x0], eax ;the fisrt page dir
	mov [PAGE_DIR_TABLE_POS + 0xc00], eax ;the 768th page dir

	sub eax, 0x1000
	mov [PAGE_DIR_TABLE_POS + 0xffc], eax ;the last(1023th) page dir entry pointer to page dir base

;crate PTE, only low 1M memory
	mov ecx, 256 ;1M mem/4K(page size) = 256
	mov esi, 0
	mov edx, PG_US_U | PG_RW_W | PG_P
.create_pte:
	mov [ebx + esi * 4], edx ;ebx = 0x101000, the first page table addr
	add edx, 4096
	inc esi
	loop .create_pte

;create kernel other PDE 
	mov eax, PAGE_DIR_TABLE_POS
	add eax, 0x2000 ; eax = the second page table addr
	or eax, PG_US_U | PG_RW_W | PG_P
	mov ebx, PAGE_DIR_TABLE_POS
	mov ecx, 254 ; 范围为第 769-1022 的所有目录项, 768(0xc00/4), 1023(0xffc/4)
	mov esi, 769
.create_kernel_pde:
	mov [ebx + esi * 4], eax
	inc esi
	add eax, 0x1000
	loop .create_kernel_pde
	ret

