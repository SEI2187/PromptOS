; PromptOS Bootloader
; Stage 1 bootloader - loads Stage 2 and provides basic system initialization

; Multiboot header
MULTIBOOT_MAGIC    equ 0x1BADB002
MULTIBOOT_FLAGS    equ 0x00000003
MULTIBOOT_CHECKSUM equ -(MULTIBOOT_MAGIC + MULTIBOOT_FLAGS)

[BITS 32]
section .multiboot
align 4
    dd MULTIBOOT_MAGIC
    dd MULTIBOOT_FLAGS
    dd MULTIBOOT_CHECKSUM

section .text
global _start

_start:
    ; Set up stack
    mov esp, stack_top

    ; Save multiboot info pointer
    push ebx

    ; Print boot message
    mov si, boot_msg
    call print_string

    ; Reset disk system
    xor ax, ax
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    ; Load Stage 2
    mov ax, STAGE2_LOAD_SEGMENT
    mov es, ax                  ; ES:BX = where to load stage 2
    xor bx, bx

    ; Get drive parameters
    push es
    mov ah, 0x08               ; Get drive parameters function
    mov dl, [boot_drive]       ; Drive number
    int 0x13
    jc disk_error              ; Error getting drive parameters
    pop es

    mov di, 3                  ; Retry counter
.retry:
    mov ah, 0x02               ; BIOS read sector function
    mov al, 8                  ; Number of sectors to read (increased for stage2)
    mov ch, 0                  ; Cylinder 0
    mov cl, 2                  ; Start from sector 2
    mov dh, 0                  ; Head 0
    mov dl, [boot_drive]       ; Drive number
    int 0x13                   ; BIOS interrupt
    jnc .success               ; If no carry, read successful

    ; On error, reset disk and retry
    mov ah, 0x00               ; Reset disk function
    mov dl, [boot_drive]       ; Drive number
    int 0x13                   ; Reset disk system
    dec di                     ; Decrement retry counter
    jnz .retry                 ; Try again if retries remain
    jmp disk_error             ; All retries failed

.success:

    ; Jump to Stage 2
    jmp STAGE2_LOAD_SEGMENT:STAGE2_LOAD_OFFSET

disk_error:
    mov si, disk_error_msg
    call print_string
    jmp $                      ; Infinite loop

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

; Data
boot_msg db 'PromptOS Booting...', 13, 10, 0
disk_error_msg db 'Disk read error!', 13, 10, 0
boot_drive db 0

times 510-($-$$) db 0          ; Pad to 510 bytes
dw 0xAA55                      ; Boot signature