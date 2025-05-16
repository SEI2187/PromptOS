# PromptOS Bootloader

This directory contains the custom bootloader implementation for PromptOS.

## Components

- `stage1/` - First stage bootloader (MBR)
- `stage2/` - Second stage bootloader
- `config/` - Bootloader configuration files
- `utils/` - Bootloader utilities and tools

## Features

- UEFI and Legacy BIOS support
- Kernel loading and initialization
- Basic system configuration
- Boot menu interface

## Implementation Details

### Stage 1
- Implements the Master Boot Record (MBR)
- Loads Stage 2 bootloader
- Basic hardware initialization

### Stage 2
- Kernel loading and execution
- Memory management setup
- Initial ramdisk loading
- Boot parameter handling

## Building

Detailed build instructions will be provided as development progresses.

## Configuration

Bootloader configuration options and customization details will be documented here.