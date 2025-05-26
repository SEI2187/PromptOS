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
KERNEL_CMDLINE_ADDR EQU 0x92000 ; Kernel command line address

; Boot parameters structure offsets
BP_SETUP_SECTS     EQU 0x1F1    ; Offset of setup_sects in boot params
BP_SYSSIZE         EQU 0x1F4    ; Offset of syssize in boot params
BP_BOOTFLAG        EQU 0x1FE    ; Offset of boot_flag in boot params
BP_TYPE_OF_LOADER  EQU 0x210    ; Offset of type_of_loader in boot params
BP_LOADFLAGS       EQU 0x211    ; Offset of loadflags in boot params
BP_CODE32_START    EQU 0x214    ; Offset of code32_start in boot params

start:
    ; Set up segments and stack
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ax, STACK_SEGMENT
    mov ss, ax
    mov sp, 0xFFFF             ; Set up stack pointer

    ; Initialize boot parameters
    mov ax, BOOTPARAM_ADDR >> 4
    mov es, ax
    xor di, di
    mov cx, 4096
    xor al, al
    rep stosb                  ; Clear boot parameter block

    ; Set up boot parameters
    mov byte [es:BP_SETUP_SECTS], SETUP_SECTS
    mov dword [es:BP_SYSSIZE], SYSSIZE
    mov word [es:BP_BOOTFLAG], BOOT_SIGNATURE
    mov byte [es:BP_TYPE_OF_LOADER], 0xFF  ; Custom bootloader
    mov byte [es:BP_LOADFLAGS], 0x01      ; LOADED_HIGH flag
    mov dword [es:BP_CODE32_START], KERNEL_LOAD_ADDR

    ; Copy kernel command line
    mov ax, KERNEL_CMDLINE_ADDR >> 4
    mov es, ax
    xor di, di
    mov si, kernel_cmdline
    call copy_string

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

    ; Load the kernel
    mov ax, 0x1000
    mov es, ax
    xor bx, bx

    ; Read kernel setup sectors
    mov ah, 0x02
    mov al, SETUP_SECTS
    mov ch, 0
    mov cl, 10          ; Start after bootloader and stage2
    mov dh, 0
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    ; Read kernel protected mode code
    mov ax, KERNEL_LOAD_ADDR >> 4
    mov es, ax
    xor bx, bx

    mov ah, 0x02
    mov al, 127         ; Read remaining sectors
    mov ch, 0
    mov cl, 14          ; Start after setup sectors
    mov dh, 0
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    ; Jump to 32-bit code
    jmp 0x08:protected_mode     ; Far jump to code segment

; Function: enable_a20
; Enables A20 line using BIOS
enable_a20:
    ; Try BIOS method first
    mov ax, 0x2401              ; A20 enable function
    int 0x15                    ; BIOS interrupt
    jnc .done                   ; If successful, return

    ; Try keyboard controller method
    cli                         ; Disable interrupts
    call .wait_input
    mov al, 0xAD                ; Disable keyboard
    out 0x64, al

    call .wait_input
    mov al, 0xD0                ; Read output port
    out 0x64, al

    call .wait_output
    in al, 0x60                 ; Read output port value
    push ax                     ; Save output port value

    call .wait_input
    mov al, 0xD1                ; Write output port
    out 0x64, al

    call .wait_input
    pop ax                      ; Restore output port value
    or al, 2                    ; Set A20 bit
    out 0x60, al

    call .wait_input
    mov al, 0xAE                ; Enable keyboard
    out 0x64, al

    call .wait_input
    sti                         ; Enable interrupts
    clc                         ; Clear carry flag

.done:
    ret

.wait_input:
    in al, 0x64                 ; Read status
    test al, 2                  ; Test input buffer full
    jnz .wait_input
    ret

.wait_output:
    in al, 0x64                 ; Read status
    test al, 1                  ; Test output buffer full
    jz .wait_output
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
    mov dword [eax], 0x53726448 ; Header signature (HdrS)
    mov word [eax+0x1F1], 0x207 ; Boot protocol version 2.07
    mov byte [eax+0x210], 0x80  ; Type of loader: boot protocol 2.00+
    mov byte [eax+0x211], 0x01  ; Loader flags: LOADED_HIGH
    mov dword [eax+0x214], 0    ; kernel_start
    mov dword [eax+0x218], INITRD_LOAD_ADDR  ; ramdisk_image
    mov dword [eax+0x21C], 0    ; ramdisk_size (to be filled)
    mov dword [eax+0x228], KERNEL_CMDLINE_ADDR ; cmd_line_ptr
    mov dword [eax+0x22C], 0    ; initrd_size_max

    ; Load kernel setup sectors
    mov eax, 0x02                ; BIOS read sectors function
    mov cx, SETUP_SECTS          ; Number of sectors to read
    mov bx, 0x1000              ; Temporary buffer for setup sectors
    mov dl, [boot_drive]         ; Drive number
    mov dh, 0                    ; Head 0
    mov ch, 0                    ; Cylinder 0
    mov cl, 2                    ; Start from sector 2
    int 0x13                     ; BIOS disk interrupt
    jc kernel_load_error         ; If carry flag set, error occurred

    ; Load protected-mode kernel
    mov eax, 0x02                ; BIOS read sectors function
    mov cx, [0x1000 + 0x1F4]    ; Read protected-mode kernel size
    mov bx, 0x10000             ; Temporary buffer
    mov dl, [boot_drive]         ; Drive number
    mov dh, 0                    ; Head 0
    mov ch, 0                    ; Cylinder 0
    mov cl, 6                    ; Start from sector 6
    int 0x13                     ; BIOS disk interrupt
    jc kernel_load_error         ; If carry flag set, error occurred

    ; Copy kernel to high memory
    mov esi, 0x10000            ; Source: temporary buffer
    mov edi, KERNEL_LOAD_ADDR    ; Destination: final kernel location
    mov ecx, [0x1000 + 0x1F4]   ; Size of protected-mode kernel
    shl ecx, 4                  ; Convert to bytes (multiply by 16)
    rep movsb                    ; Copy kernel

    ; Copy setup sectors to high memory
    mov esi, 0x1000             ; Source: temporary buffer
    mov edi, KERNEL_LOAD_ADDR    ; Destination: final kernel location
    mov ecx, SETUP_SECTS * 512   ; Number of bytes to copy
    rep movsb                    ; Copy setup sectors

    ; Load initrd
    mov eax, 0x02                ; BIOS read sectors function
    mov cx, 32                   ; Number of sectors for initrd (adjust as needed)
    mov bx, INITRD_LOAD_ADDR     ; Buffer to load into
    mov dl, [boot_drive]         ; Drive number
    mov dh, 0                    ; Head 0
    mov ch, 0                    ; Cylinder 0
    mov cl, 6                    ; Start from sector 6 (after kernel)
    int 0x13                     ; BIOS disk interrupt
    jc initrd_load_error         ; If carry flag set, error occurred

    ; Set up command line
    mov esi, kernel_cmdline      ; Source: command line string
    mov edi, KERNEL_CMDLINE_ADDR ; Destination: command line buffer
    mov ecx, cmdline_len         ; Length of command line
    rep movsb                    ; Copy command line
    mov byte [edi], 0           ; Null terminate

    ; Update boot parameters
    mov eax, BOOTPARAM_ADDR
    mov dword [eax+0x228], 0x92000  ; Set command line pointer
    mov dword [eax+0x21C], 0x100000 ; Set initrd size (adjust as needed)

    ; Jump to kernel entry point
    mov eax, KERNEL_LOAD_ADDR
    add eax, 0x1000              ; Kernel entry point offset
    jmp eax

    ; Should never reach here
    cli
    hlt

kernel_load_error:
    mov si, kernel_error_msg
    call print_string
    jmp $

initrd_load_error:
    mov si, initrd_error_msg
    call print_string
    jmp $

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
kernel_error_msg db 'Kernel Load Failed!', 13, 10, 0
initrd_error_msg db 'InitRD Load Failed!', 13, 10, 0
kernel_cmdline db 'root=/dev/ram0 init=/sbin/init console=tty0', 0
cmdline_len equ $ - kernel_cmdline
boot_drive db 0

; Function: copy_string
; Input: DS:SI = source string, ES:DI = destination
copy_string:
    push ax
.loop:
    lodsb
    stosb
    test al, al
    jnz .loop
    pop ax
    ret