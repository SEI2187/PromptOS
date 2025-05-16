; PromptOS Bootloader
; Stage 1 bootloader - loads Stage 2 and provides basic system initialization

[BITS 16]                       ; We start in 16-bit real mode
[ORG 0x7C00]                    ; BIOS loads us at this address

STAGE2_LOAD_SEGMENT EQU 0x2000  ; Where we'll load stage 2
STAGE2_LOAD_OFFSET  EQU 0x0000

start:
    cli                         ; Disable interrupts
    xor ax, ax                  ; Zero AX register
    mov ds, ax                  ; Set DS=0
    mov es, ax                  ; Set ES=0
    mov ss, ax                  ; Set SS=0
    mov sp, 0x7C00             ; Set up stack pointer
    sti                         ; Enable interrupts

    ; Print boot message
    mov si, boot_msg
    call print_string

    ; Load Stage 2
    mov ax, STAGE2_LOAD_SEGMENT
    mov es, ax                  ; ES:BX = where to load stage 2
    xor bx, bx

    mov ah, 0x02               ; BIOS read sector function
    mov al, 6                  ; Number of sectors to read
    mov ch, 0                  ; Cylinder 0
    mov cl, 2                  ; Start from sector 2
    mov dh, 0                  ; Head 0
    mov dl, [boot_drive]       ; Drive number
    int 0x13                   ; BIOS interrupt
    jc disk_error              ; If carry flag set, error occurred

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