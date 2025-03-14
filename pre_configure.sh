loadkeys us
timedatectl set-ntp true
if [ $? -eq 0 ]; then
    print_color "32" "NTP synchronization enabled successfully."
else
    print_color "31" "Failed to enable NTP synchronization."
    exit 1
fi

print_color "33" "Configuring pacman..."
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
print_color "33" "Updating pacman database..."
if ! pacman -Syy; then
    print_color "31" "Failed to update pacman database."
    exit 1
fi
sync

install_packages_host rsync gptfdisk glibc

cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
if [[ $sync_mirrors =~ ^[Yy]$ ]]; then
    print_color "33" "Updating mirror list..."
    reflector -a 6 -c "$COUNTRY" -p https --sort rate --save /etc/pacman.d/mirrorlist
    print_color "32" "Mirror list updated successfully."
else
    print_color "33" "Skipping mirror sync."
fi