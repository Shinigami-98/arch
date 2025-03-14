#!/bin/bash
set -e

echo "Starting bootstrap process for Arch Linux installation scripts..."
source variable.file
source env.sh
source partition.sh
source user_inputs.sh

print_color "36" "Starting Arch Linux installation..."

source pre_configure.sh

if [[ $create_partitions =~ ^[Yy]$ ]]; then
    umount -R /mnt 2>/dev/null || true
    # Start with common partitioning commands
    gdisk_commands="o\ny\nn\n1\n\n+${efi_size}\nef00\nn\n2\n\n+${root_size}\n8300"
    # Handle different partition scenarios based on home and swap configuration
    current_partition=3
    # Add home partition if separate_home is true
    if [[ $SEPARATE_HOME = true ]]; then
        gdisk_commands="${gdisk_commands}\nn\n${current_partition}\n\n+${home_size}\n8300"
        current_partition=$((current_partition + 1))
    fi
    # Add swap partition only if traditional swap is selected
    if [[ $SWAP_TYPE == "partition" ]]; then
        gdisk_commands="${gdisk_commands}\nn\n${current_partition}\n\n+${swap_size}\n8200"
    fi
    # Finalize gdisk commands
    gdisk_commands="${gdisk_commands}\nw\ny"
    # Execute gdisk with the constructed commands
    echo -e "$gdisk_commands" | gdisk $BOOT_DISK
    print_color "32" "Partitioning completed successfully."
    print_color "33" "New partition layout:"
    lsblk $BOOT_DISK
fi
source $FILESYSTEM_SCRIPT

install_base_packages "${BASE_PACKAGES[@]}" "$KERNEL" "$KERNEL_HEADERS"

print_color "33" "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
print_color "32" "Base system installation complete!"

source system_configure.sh

if [[ $install_grub =~ ^[Yy]$ ]]; then
    source install_grub.sh
else
    print_color "33" "Skipping GRUB installation."
fi

# Only configure Btrfs-specific settings if the filesystem is Btrfs
if [[ $FILESYSTEM == "Btrfs" ]]; then
    print_color "33" "Configuring Btrfs-specific settings in mkinitcpio.conf..."
    print_color "33" "Backing up $MKINITCPIO_CONF to $MKINITCPIO_CONF.bak"
    if ! cp "$MKINITCPIO_CONF" "$MKINITCPIO_CONF.bak"; then
        print_color "31" "Failed to back up mkinitcpio.conf."
        exit 1
    fi

    if ! grep -q "btrfs" "$MKINITCPIO_CONF"; then
        print_color "33" "Adding btrfs module to mkinitcpio.conf"
        arch-chroot /mnt sed -i 's/^MODULES=(/MODULES=(btrfs /' "$MKINITCPIO_CONF"
    fi
    arch-chroot /mnt sed -i 's/ fsck//' "$MKINITCPIO_CONF"
fi

if [[ $install_xorg =~ ^[Yy]$ ]]; then
    print_color "32" "Installing minimal Xorg for KDE..."
    install_packages "${XORG_PACKAGES[@]}"
else
    print_color "33" "Skipping Xorg installation."
fi

if [[ $has_nvidia =~ ^[Yy]$ ]]; then
    source nvidia.sh
else
    print_color "33" "Skipping NVIDIA setup."
fi

if [[ $install_sddm =~ ^[Yy]$ ]]; then
    source sddm.sh
else
    print_color "33" "Skipping SDDM installation."
fi

print_color "32" "Installing common fonts..."
install_packages "${FONT_PACKAGES[@]}"

# Enable necessary services
print_color "32" "Enabling necessary services..."
arch-chroot /mnt systemctl enable NetworkManager
arch-chroot /mnt systemctl enable bluetooth
arch-chroot /mnt systemctl enable fstrim.timer

# Generate GRUB config only once
if [[ $install_grub =~ ^[Yy]$ ]]; then
    print_color "33" "Generating GRUB configuration..."
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
fi

print_color "32" "Installation Complete.............."

sync
