#!/bin/bash

# PromptOS Build Script
# This script assembles the bootloader and creates a bootable ISO

# Required tools:
# - nasm (Netwide Assembler)
# - mkisofs or genisoimage
# - qemu-system-x86_64 (for testing)

# Exit on any error
set -e

# Create build directory
BUILD_DIR="build"
mkdir -p "$BUILD_DIR"/boot

# Assemble bootloader
echo "Assembling bootloader..."
nasm -f bin bootloader/boot.asm -o "$BUILD_DIR"/boot/boot.bin

# Create ISO image
echo "Creating ISO image..."
mkisofs -o promptos.iso \
    -b boot/boot.bin \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -R -J -v -T "$BUILD_DIR"

echo "Build complete! ISO image created as promptos.iso"
echo ""
echo "To run in VMware:"
echo "1. Open VMware"
echo "2. Create a new virtual machine"
echo "3. Choose 'Custom' configuration"
echo "4. Select 'Other' as guest OS, version: Other 64-bit"
echo "5. Name the VM 'PromptOS'"
echo "6. Select promptos.iso as the installation media"
echo "7. Allocate at least 512MB RAM"
echo "8. Create a small virtual disk (1GB is enough)"
echo "9. Click 'Finish' and power on the VM"