arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Kathmandu /etc/localtime
arch-chroot /mnt hwclock --systohc --utc

# Generate locale
arch-chroot /mnt sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
arch-chroot /mnt locale-gen
echo LANG=en_US.UTF-8 > /mnt/etc/locale.conf
echo KEYMAP=us > /mnt/etc/vconsole.conf
echo $HOSTNAME > /mnt/etc/hostname

# Handle root account based on user choice
if [[ $allow_empty_root_password =~ ^[Yy]$ ]]; then
    print_color "33" "Disabling root login for security..."
    # Lock the root account
    arch-chroot /mnt passwd -l root
else
    print_color "32" "Setting password for root user..."
    echo "root:$ROOT_PASSWORD" | arch-chroot /mnt chpasswd
fi

# Create the new user
arch-chroot /mnt useradd -m -G wheel,storage,power -s /bin/bash "$NEW_USER"

# Set the user password
echo "$NEW_USER:$USER_PASSWORD" | arch-chroot /mnt chpasswd

print_color "32" "User $NEW_USER has been created and added to the wheel group."

print_color "32" "Configuring sudoers..."
# Configure sudoers
arch-chroot /mnt sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
arch-chroot /mnt sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Set read permissions for pacman.conf
print_color "32" "Setting read permissions for pacman.conf..."
arch-chroot /mnt chmod 644 /etc/pacman.conf