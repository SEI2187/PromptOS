#!/bin/bash

# PromptOS Build Script (Linux)
# This script assembles the bootloader and creates a bootable ISO

# Configuration
BUILD_DIR="build"
ISO_FILE="promptos.iso"
KERNEL_VERSION="5.15"
KERNEL_SOURCE_URL="https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${KERNEL_VERSION}.tar.xz"

# Exit on any error
set -e

# Check for required tools
check_requirements() {
    echo "Checking required tools..."
    
    # Check for NASM
    if ! command -v nasm &> /dev/null; then
        echo "Error: NASM is not installed"
        echo "Please install it using your package manager:"
        echo "  For Ubuntu/Debian: sudo apt-get install nasm"
        echo "  For Fedora: sudo dnf install nasm"
        echo "  For Arch: sudo pacman -S nasm"
        exit 1
    else
        echo "Found NASM: $(nasm -v | head -n1)"
    fi
    
    # Check for mkisofs/genisoimage
    if command -v mkisofs &> /dev/null; then
        ISO_TOOL="mkisofs"
    elif command -v genisoimage &> /dev/null; then
        ISO_TOOL="genisoimage"
    else
        echo "Error: Neither mkisofs nor genisoimage is installed"
        echo "Please install one of them using your package manager:"
        echo "  For Ubuntu/Debian: sudo apt-get install genisoimage"
        echo "  For Fedora: sudo dnf install genisoimage"
        echo "  For Arch: sudo pacman -S cdrtools"
        exit 1
    fi
    echo "Found ISO tool: $ISO_TOOL"
    
    # Check for build essentials
    if ! command -v gcc &> /dev/null; then
        echo "Error: GCC is not installed"
        echo "Please install build essentials:"
        echo "  For Ubuntu/Debian: sudo apt-get install build-essential"
        echo "  For Fedora: sudo dnf group install 'Development Tools'"
        echo "  For Arch: sudo pacman -S base-devel"
        exit 1
    fi
    echo "Found GCC: $(gcc --version | head -n1)"
}

# Create build directory structure
create_build_structure() {
    echo "Creating build directory structure..."
    mkdir -p "$BUILD_DIR/boot"
    mkdir -p "$BUILD_DIR/kernel"
}

# Build kernel
build_kernel() {
    echo "Building Linux kernel..."
    cd "$BUILD_DIR/kernel"
    
    # Download kernel if not exists
    if [ ! -f "linux-${KERNEL_VERSION}.tar.xz" ]; then
        echo "Downloading Linux kernel source..."
        wget "$KERNEL_SOURCE_URL"
    fi
    
    # Extract kernel if not already extracted
    if [ ! -d "linux-${KERNEL_VERSION}" ]; then
        echo "Extracting kernel source..."
        tar xf "linux-${KERNEL_VERSION}.tar.xz"
    fi
    
    # Copy our kernel config
    cd "linux-${KERNEL_VERSION}"
    if [ ! -f "../kernel/kernel_config" ]; then
        echo "Error: Kernel config not found at: ../kernel/kernel_config"
        exit 1
    fi
    cp "../kernel/kernel_config" .config
    
    # Build kernel
    echo "Building kernel (this may take a while)..."
    make -j$(nproc)
    cd ..
}

# Build bootloader
build_bootloader() {
    echo "Assembling bootloader..."
    nasm -f bin bootloader/boot.asm -o "$BUILD_DIR/boot/boot.bin"
    nasm -f bin bootloader/stage2.asm -o "$BUILD_DIR/boot/stage2.bin"
}

# Create ISO
create_iso() {
    echo "Creating ISO image..."
    $ISO_TOOL -o "$ISO_FILE" \
        -b boot/boot.bin \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -R -J -v -T "$BUILD_DIR"
}

# Main build process
main() {
    echo "Starting PromptOS build process..."
    check_requirements
    create_build_structure
    build_kernel
    build_bootloader
    create_iso
    echo "Build complete! ISO image created as $ISO_FILE"
}

# Run the build
main
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