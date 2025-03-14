# Install GRUB
arch-chroot /mnt pacman -S --noconfirm grub efibootmgr

print_color "32" "Installing GRUB for EFI..."
if ! mountpoint -q /mnt/boot/EFI; then
    mkdir -p /mnt/boot/EFI
    mount $EFI_PARTITION /mnt/boot/EFI
fi
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/EFI --bootloader-id="$LABEL"

arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg