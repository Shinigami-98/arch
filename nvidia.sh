#!/bin/bash
print_color "32" "Installing NVIDIA drivers and configuring the system..."


install_packages "${NVIDIA_PACKAGES[@]}"


print_color "33" "Adding NVIDIA modules to mkinitcpio.conf"
arch-chroot /mnt sed -i '/^MODULES=/ s/)/'"${NVIDIA_MODULES[*]}"'&/' "$MKINITCPIO_CONF"

arch-chroot /mnt sed -i 's/ kms//' "$MKINITCPIO_CONF"

print_color "33" "Regenerating initramfs after adding NVIDIA modules"
arch-chroot /mnt mkinitcpio -P

print_color "33" "Backing up $GRUB_CONF to $GRUB_BACKUP_CONF"
if ! arch-chroot /mnt cp "$GRUB_CONF" "$GRUB_BACKUP_CONF"; then
    print_color "31" "Failed to back up GRUB configuration."
    exit 1
fi

GRUB_PARAMS="nvidia_drm.modeset=1 nvidia_drm.fbdev=1"
if ! grep -q "$GRUB_PARAMS" "$GRUB_CONF"; then
    print_color "33" "Adding parameters to GRUB_CMDLINE_LINUX_DEFAULT"
    arch-chroot /mnt sed -i "s/\(^GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\"/\1 $GRUB_PARAMS\"/" "$GRUB_CONF"
fi

print_color "33" "Adding NVIDIA options to /etc/modprobe.d/nvidia.conf"
echo "options nvidia_drm modeset=1 fbdev=1" | arch-chroot /mnt tee /etc/modprobe.d/nvidia.conf > /dev/null