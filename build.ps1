# PromptOS Build Script (Windows)
# This script assembles the bootloader and creates a bootable ISO

# Configuration
$BuildDir = "build"
$IsoFile = "promptos.iso"
$NASMPath = "C:\Program Files\NASM\nasm.exe"
$OscdimgPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
$KernelVersion = "5.15"
$KernelSourceURL = "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$KernelVersion.tar.xz"
$WSLDistro = "Ubuntu"

# Check for required tools and provide detailed setup instructions
function Check-Requirements {
    Write-Host "Checking required tools..."
    $MissingTools = $false
    
    # Check for WSL
    $wslCheck = wsl --list
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`nWindows Subsystem for Linux (WSL) is not installed`n"
        Write-Host "Please follow these steps to install WSL:`n"
        Write-Host "1. Open PowerShell as Administrator"
        Write-Host "2. Run: wsl --install"
        Write-Host "3. Restart your computer"
        Write-Host "4. Complete the Ubuntu setup when it launches`n"
        $MissingTools = $true
    } else {
        Write-Host "Found WSL installation"
    }
    
    # Check for NASM
    if (-not (Test-Path -Path $NASMPath -PathType Leaf)) {
        Write-Host "`nNASM is not found at expected location: $NASMPath`n"
        Write-Host "Please follow these steps to install NASM:`n"
        Write-Host "1. Download NASM from https://www.nasm.us"
        Write-Host "2. Install NASM to 'C:\Program Files\NASM'"
        Write-Host "3. Run this script again after installation`n"
        $MissingTools = $true
    } else {
        Write-Host "Found NASM at: $NASMPath"
    }
    
    # Check for oscdimg
    if (-not (Test-Path -Path $OscdimgPath -PathType Leaf)) {
        Write-Host "`noscdimg is not found at expected location: $OscdimgPath`n"
        Write-Host "Please follow these steps to install Windows ADK:`n"
        Write-Host "1. Download Windows ADK from:"
        Write-Host "   https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install"
        Write-Host "2. Run the installer and select 'Deployment Tools'"
        Write-Host "3. Run this script again after installation`n"
        $MissingTools = $true
    } else {
        Write-Host "Found oscdimg at: $OscdimgPath"
    }
    
    if ($MissingTools) {
        Write-Host "Please fix the tool issues mentioned above and run this script again."
        exit 1
    }
}

# Create build directory structure
function Create-BuildStructure {
    Write-Host "Creating build directory structure..."
    New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
    New-Item -ItemType Directory -Force -Path "$BuildDir\boot" | Out-Null
    New-Item -ItemType Directory -Force -Path "$BuildDir\kernel" | Out-Null
}

# Download and compile Linux kernel
function Build-Kernel {
    Write-Host "Building Linux kernel..."
    $kernelDir = "$BuildDir\kernel"
    $kernelArchive = "linux-$KernelVersion.tar.xz"
    $kernelSource = "linux-$KernelVersion"

    Push-Location $kernelDir

    # Download kernel source if not exists
    if (-not (Test-Path $kernelArchive)) {
        Write-Host "Downloading Linux kernel source..."
        Invoke-WebRequest -Uri $KernelSourceURL -OutFile $kernelArchive
    }

    # Extract kernel source
    if (-not (Test-Path $kernelSource)) {
        Write-Host "Extracting kernel source..."
        wsl tar xf $kernelArchive
    }

    # Copy our kernel config
    Copy-Item "..\..\kernel\kernel_config" "$kernelSource\.config"

    # Build kernel using WSL
    Write-Host "Compiling kernel (this may take a while)..."
    Push-Location $kernelSource
    wsl -d $WSLDistro -e bash -c "
        sudo apt-get update && \
        sudo apt-get install -y build-essential flex bison libssl-dev libelf-dev && \
        make -j$(nproc) && \
        cp arch/x86/boot/bzImage ../../boot/vmlinuz"
    Pop-Location

    Pop-Location

    if (-not (Test-Path "$BuildDir\boot\vmlinuz")) {
        Write-Host "Error: Kernel compilation failed"
        exit 1
    }

    Write-Host "Successfully built kernel"
}

# Build bootloader
function Build-Bootloader {
    Write-Host "Assembling bootloader..."
    $bootloaderPath = Join-Path $PSScriptRoot "bootloader\boot.asm"
    
    # Verify bootloader source exists
    if (-not (Test-Path -Path $bootloaderPath -PathType Leaf)) {
        Write-Host "Error: Bootloader source not found at: $bootloaderPath"
        Write-Host "Please ensure the bootloader source file exists in the correct location."
        exit 1
    }
    
    $outputPath = Join-Path $BuildDir "boot\boot.bin"
    Write-Host "Compiling bootloader from: $bootloaderPath"
    Write-Host "Output will be written to: $outputPath"
    
    $nasmArgs = @(
        "-f", "bin",           # Output format: flat binary
        "-w+all",              # Enable all warnings
        "-o", $outputPath,     # Output file
        $bootloaderPath        # Input file
    )
    
    $process = Start-Process -FilePath $NASMPath -ArgumentList $nasmArgs -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Host "Error: Failed to assemble bootloader. Please check the following:"
        Write-Host "1. The bootloader source file is valid"
        Write-Host "2. You have write permissions to $outputPath"
        Write-Host "3. The NASM installation is working correctly"
        exit 1
    }
    
    # Verify the output was created
    if (-not (Test-Path -Path $outputPath -PathType Leaf)) {
        Write-Host "Error: Bootloader binary was not created at: $outputPath"
        exit 1
    }
    
    Write-Host "Successfully assembled bootloader"
}

# Create ISO image
function Create-ISO {
    Write-Host "Creating ISO image..."
    $bootBinPath = Join-Path $BuildDir "boot\boot.bin"
    
    # Verify boot binary exists
    if (-not (Test-Path -Path $bootBinPath -PathType Leaf)) {
        Write-Host "Error: Boot binary not found at: $bootBinPath"
        Write-Host "Please ensure the bootloader was compiled successfully."
        exit 1
    }
    
    Write-Host "Using boot binary from: $bootBinPath"
    Write-Host "Creating ISO file: $IsoFile"
    
    # Convert paths to proper format for oscdimg
    $bootBinPathFormatted = $bootBinPath.Replace('\', '\\')

    $oscdimgArgs = @(
        "-bootdata:2#p0,e,b$bootBinPathFormatted#pEF,e,b$bootBinPathFormatted",  # Boot data with proper path
        "-u1",                    # ISO9660 + Joliet format
        $BuildDir,                 # Source directory
        $IsoFile                   # Output ISO file
    )
    
    $process = Start-Process -FilePath $OscdimgPath -ArgumentList $oscdimgArgs -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Host "Error: Failed to create ISO image. Please check:"
        Write-Host "1. The boot binary is valid"
        Write-Host "2. You have write permissions for $IsoFile"
        Write-Host "3. The Windows ADK installation is working correctly"
        exit 1
    }
    
    # Verify ISO was created
    if (-not (Test-Path -Path $IsoFile -PathType Leaf)) {
        Write-Host "Error: ISO file was not created at: $IsoFile"
        exit 1
    }
    
    Write-Host "Successfully created ISO image"
    Write-Host "ISO file size: $((Get-Item $IsoFile).Length) bytes"
}

# Main build process
Write-Host "Starting PromptOS build process..."

Check-Requirements
Create-BuildStructure
Build-Kernel
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