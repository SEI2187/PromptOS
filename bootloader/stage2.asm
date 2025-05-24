; PromptOS Stage 2 Bootloader
; Handles Linux kernel loading and boot protocol

[BITS 16]                       ; Start in 16-bit real mode
[ORG 0x0000]                    ; We are loaded at segment 0x2000 by stage 1

; Linux boot protocol constants
BOOT_SIGNATURE     EQU 0xAA55   ; Boot signature
SETUP_SECTS        EQU 4        ; Number of setup sectors
SYSSIZE            EQU 0x8000   ; Size of protected-mode code in paragraphs
BOOTPARAM_ADDR     EQU 0x90000  ; Boot parameter block address
KERNEL_LOAD_ADDR   EQU 0x100000 ; Where to load the kernel (1MB)
INITRD_LOAD_ADDR   EQU 0x800000 ; Where to load the initrd (8MB)
STACK_SEGMENT      EQU 0x9000   ; Stack segment

start:
    ; Set up segments and stack
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ax, STACK_SEGMENT
    mov ss, ax
    mov sp, 0xFFFF             ; Set up stack pointer

    ; Print stage 2 message
    mov si, stage2_msg
    call print_string

    ; Enable A20 line
    call enable_a20
    jc a20_error

    ; Load GDT
    cli                         ; Disable interrupts
    lgdt [gdt_descriptor]       ; Load GDT descriptor

    ; Switch to protected mode
    mov eax, cr0
    or eax, 1                   ; Set protected mode bit
    mov cr0, eax

    ; Jump to 32-bit code
    jmp 0x08:protected_mode     ; Far jump to code segment

; Function: enable_a20
; Enables A20 line using BIOS
enable_a20:
    mov ax, 0x2401              ; A20 enable function
    int 0x15                    ; BIOS interrupt
    jnc .done                   ; If successful, return
    stc                         ; Set carry flag on error
.done:
    ret

; Function: print_string
; Input: SI points to string
print_string:
    pusha
    mov ah, 0x0E               ; BIOS teletype function
.loop:
    lodsb                      ; Load next character
    test al, al                ; Check for end of string (0)
    jz .done                   ; If zero, we're done
    int 0x10                   ; Print character
    jmp .loop
.done:
    popa
    ret

a20_error:
    mov si, a20_error_msg
    call print_string
    jmp $                      ; Infinite loop

[BITS 32]                       ; 32-bit protected mode code
protected_mode:
    ; Set up segment registers
    mov ax, 0x10               ; Data segment selector
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Set up stack
    mov esp, 0x90000

    ; Set up boot parameters
    mov eax, BOOTPARAM_ADDR
    mov dword [eax], 0x197      ; Header signature (HdrS)
    mov word [eax+0x1F1], 0x0   ; Boot protocol version 2.00
    mov byte [eax+0x210], 0x80  ; Type of loader: boot protocol 2.00+
    mov byte [eax+0x211], 0x00  ; Loader flags
    mov dword [eax+0x218], INITRD_LOAD_ADDR  ; ramdisk_image
    mov dword [eax+0x21C], 0    ; ramdisk_size (to be filled)
    mov dword [eax+0x228], 0    ; cmd_line_ptr

    ; Load kernel
    mov edi, KERNEL_LOAD_ADDR
    ; TODO: Implement actual kernel loading from disk

    ; Jump to kernel
    mov eax, KERNEL_LOAD_ADDR
    jmp eax

    ; Should never reach here
    cli
    hlt

; Global Descriptor Table
gdt_start:
    ; Null descriptor
    dd 0x0
    dd 0x0

    ; Code segment descriptor
    dw 0xFFFF                   ; Limit (bits 0-15)
    dw 0x0                      ; Base (bits 0-15)
    db 0x0                      ; Base (bits 16-23)
    db 10011010b               ; Access byte
    db 11001111b               ; Flags + Limit (bits 16-19)
    db 0x0                      ; Base (bits 24-31)

    ; Data segment descriptor
    dw 0xFFFF                   ; Limit (bits 0-15)
    dw 0x0                      ; Base (bits 0-15)
    db 0x0                      ; Base (bits 16-23)
    db 10010010b               ; Access byte
    db 11001111b               ; Flags + Limit (bits 16-19)
    db 0x0                      ; Base (bits 24-31)
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; GDT size
    dd gdt_start                ; GDT address

; Data
stage2_msg db 'PromptOS Stage 2 Bootloader...', 13, 10, 0
a20_error_msg db 'A20 Line Enable Failed!', 13, 10, 0