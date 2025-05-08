# Arch Linux Installation Scripts

An automated and interactive Arch Linux installation framework that simplifies the installation process with various customization options.

## Overview

This project provides a collection of shell scripts designed to automate the Arch Linux installation process. It guides users through a series of configuration choices, offering flexibility for different hardware setups, file systems, desktop environments, and more.

## Features

- **Interactive Installation**: Guided prompts for essential configuration options
- **Flexible Partitioning**: Support for various partitioning schemes
- **Multiple Filesystem Support**: 
  - Ext4
  - Btrfs
  - XFS
  - zRAM
- **Kernel Options**: Choose between standard, LTS, or Zen kernels
- **Desktop Environment Support**: Focused on KDE Plasma with SDDM
- **Hardware-specific Configurations**: Special handling for NVIDIA GPUs
- **GRUB Configuration**: Automated GRUB bootloader setup

## Prerequisites

- A bootable Arch Linux installation media
- Internet connection
- Basic knowledge of Linux and partitioning concepts

## Usage

1. Boot into the Arch Linux live environment
2. Clone this repository: `git clone https://github.com/shinigami-98/arch`
3. Navigate to the project directory: `cd arch`
4. Make the main script executable: `chmod +x main.sh`
5. Run the installation script: `./main.sh`
6. Follow the interactive prompts to customize your installation

## Script Descriptions

- `main.sh` - The primary script that orchestrates the installation process
- `user_inputs.sh` - Handles user configuration choices
- `variable.file` - Contains configuration variables and package lists
- `env.sh` - Sets up environment variables and utility functions
- `partition.sh` - Manages disk partitioning
- `fs_ext.sh` - Ext4 filesystem setup
- `fs_btrfs.sh` - Btrfs filesystem setup
- `fs_xfs.sh` - XFS filesystem setup
- `fs_zram.sh` - zRAM configuration
- `pre_configure.sh` - Initial system configuration
- `system_configure.sh` - Post-installation system configuration
- `install_grub.sh` - GRUB bootloader installation
- `nvidia.sh` - NVIDIA GPU setup
- `sddm.sh` - SDDM display manager configuration

## Customization

The scripts provide multiple customization points:
- Kernel selection (standard, LTS, or Zen)
- Filesystem selection
- Partition layout
- Desktop environment options
- GPU driver configuration
- Additional package installation

## Contributions

Contributions are welcome! Please feel free to submit a Pull Request.

## Disclaimer

These scripts are provided as-is with no warranty. Always backup important data before performing system installations.
