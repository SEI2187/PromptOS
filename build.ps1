# PromptOS Build Script (Windows)
# This script assembles the bootloader and creates a bootable ISO

# Configuration
$BuildDir = "build"
$IsoFile = "promptos.iso"

# Check for required tools and provide detailed setup instructions
function Check-Requirements {
    Write-Host "Checking required tools..."
    $MissingTools = $false
    
    # Check for NASM
    if (!(Get-Command nasm -ErrorAction SilentlyContinue)) {
        Write-Host "`nNASM is not installed or not in PATH. Please follow these steps:`n"
        Write-Host "1. Download NASM from https://www.nasm.us"
        Write-Host "2. Install NASM to a location like 'C:\Program Files\NASM'"
        Write-Host "3. Add NASM to PATH:"
        Write-Host "   a. Open System Properties (Win + R, type 'sysdm.cpl')"
        Write-Host "   b. Click 'Environment Variables'"
        Write-Host "   c. Under 'System Variables', find and select 'Path'"
        Write-Host "   d. Click 'Edit' and add the NASM installation directory"
        Write-Host "   e. Click 'OK' on all windows"
        Write-Host "4. Open a new PowerShell window after setting PATH`n"
        $MissingTools = $true
    }
    
    # Check for oscdimg (part of Windows ADK)
    if (!(Get-Command oscdimg -ErrorAction SilentlyContinue)) {
        Write-Host "`noscdimg is not found. Please follow these steps to install Windows ADK:`n"
        Write-Host "1. Download Windows ADK from:"
        Write-Host "   https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install"
        Write-Host "2. Run the installer and select 'Deployment Tools'"
        Write-Host "3. Add Windows ADK Deployment Tools to PATH:"
        Write-Host "   a. Open System Properties (Win + R, type 'sysdm.cpl')"
        Write-Host "   b. Click 'Environment Variables'"
        Write-Host "   c. Under 'System Variables', find and select 'Path'"
        Write-Host "   d. Click 'Edit' and add:"
        Write-Host "      'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg'"
        Write-Host "   e. Click 'OK' on all windows"
        Write-Host "4. Open a new PowerShell window after setting PATH`n"
        $MissingTools = $true
    }
    
    if ($MissingTools) {
        Write-Host "Please install the missing tools and update PATH before running this script again."
        exit 1
    }
}

# Create build directory structure
function Create-BuildStructure {
    Write-Host "Creating build directory structure..."
    New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
    New-Item -ItemType Directory -Force -Path "$BuildDir\boot" | Out-Null
}

# Build bootloader
function Build-Bootloader {
    Write-Host "Assembling bootloader..."
    nasm -f bin bootloader\boot.asm -o "$BuildDir\boot\boot.bin"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to assemble bootloader"
        exit 1
    }
}

# Create ISO image
function Create-ISO {
    Write-Host "Creating ISO image..."
    oscdimg -b "$BuildDir\boot\boot.bin" -o -h -u2 "$BuildDir" "$IsoFile"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to create ISO image"
        exit 1
    }
}

# Main build process
Write-Host "Starting PromptOS build process..."

Check-Requirements
Create-BuildStructure
Build-Bootloader
Create-ISO

Write-Host ""
Write-Host "Build complete! ISO image created as $IsoFile"
Write-Host ""
Write-Host "To run in VMware:"
Write-Host "1. Open VMware"
Write-Host "2. Create a new virtual machine"
Write-Host "3. Choose 'Custom' configuration"
Write-Host "4. Select 'Other' as guest OS, version: Other 64-bit"
Write-Host "5. Name the VM 'PromptOS'"
Write-Host "6. Select $IsoFile as the installation media"
Write-Host "7. Allocate at least 512MB RAM"
Write-Host "8. Create a small virtual disk (1GB is enough)"
Write-Host "9. Click 'Finish' and power on the VM"