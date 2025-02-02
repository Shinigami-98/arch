#!/bin/bash
set -e

# Configuration
COUNTRY="Germany"
LABEL="Legion -- X"
MKINITCPIO_CONF="/etc/mkinitcpio.conf"
GRUB_CONF="/etc/default/grub"
GRUB_BACKUP_CONF="/etc/default/grub.bak"

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "\e[${color}m${message}\e[0m"
}

# Function to handle errors
error_handler() {
    print_color "31" "Error occurred on line $1"
    exit 1
}

# Function to safely install packages
install_packages() {
    local packages=("$@")
    print_color "33" "Installing packages: ${packages[*]}"
    if ! arch-chroot /mnt pacman -S --noconfirm --needed "${packages[@]}"; then
        print_color "31" "Failed to install packages: ${packages[*]}"
        exit 1
    fi
    print_color "32" "Successfully installed packages: ${packages[*]}"
}

# Function to safely install base packages using pacstrap
install_base_packages() {
    local packages=("$@")
    print_color "33" "Installing base packages using pacstrap: ${packages[*]}"
    if ! pacstrap -K -P /mnt "${packages[@]}"; then
        print_color "31" "Failed to install base packages: ${packages[*]}"
        exit 1
    fi
    print_color "32" "Successfully installed base packages: ${packages[*]}"
}

# Function to safely install packages outside chroot
install_packages_host() {
    local packages=("$@")
    print_color "33" "Installing packages: ${packages[*]}"
    if ! pacman -S --noconfirm --needed "${packages[@]}"; then
        print_color "31" "Failed to install packages: ${packages[*]}"
        exit 1
    fi
    print_color "32" "Successfully installed packages: ${packages[*]}"
}

# Function to show partitions and ask for partition type
show_partitions_and_ask() {
    echo "Current disk layout:"
    lsblk
    echo
    print_color "36" "What type of partition are you using?"
    print_color "33" "1) NVMe (e.g., /dev/nvme0n1)"
    print_color "33" "2) SATA/IDE (e.g., /dev/sda, /dev/sdb, etc.)"
    print_color "33" "3) VDA (Virtual Disk)"
    print_color "33" "4) Other"
    read -p "Enter your choice [1-4]: " partition_type

    case $partition_type in
        1)
            BOOT_DISK="/dev/nvme0n1"
            EFI_PARTITION="${BOOT_DISK}p1"
            ROOT_PARTITION="${BOOT_DISK}p2"
            SWAP_PARTITION="${BOOT_DISK}p3"
            ;;
        2)
            print_color "36" "Available SATA/IDE disks:"
            lsblk -ndo NAME,TYPE | grep disk | grep -E 'sd[a-z]'
            read -p "Enter the SATA/IDE disk (e.g., sda, sdb): " sata_disk
            BOOT_DISK="/dev/${sata_disk}"
            EFI_PARTITION="${BOOT_DISK}1"
            ROOT_PARTITION="${BOOT_DISK}2"
            SWAP_PARTITION="${BOOT_DISK}3"
            ;;
        3)
            BOOT_DISK="/dev/vda"
            EFI_PARTITION="${BOOT_DISK}1"
            ROOT_PARTITION="${BOOT_DISK}2"
            SWAP_PARTITION="${BOOT_DISK}3"
            ;;
        4)
            read -p "Enter the boot disk (e.g., /dev/vda): " BOOT_DISK
            read -p "Enter the EFI partition (e.g., ${BOOT_DISK}1): " EFI_PARTITION
            read -p "Enter the root partition (e.g., ${BOOT_DISK}2): " ROOT_PARTITION
            read -p "Enter the swap partition (e.g., ${BOOT_DISK}3): " SWAP_PARTITION
            ;;
        *)
            print_color "31" "Invalid choice. Exiting."
            exit 1
            ;;
    esac
}

print_color "36" "Starting Arch Linux installation..."

read -p "Do you want to sync mirrors for faster downloads? (y/n): " sync_mirrors
# Call the function to show partitions and ask for partition type
show_partitions_and_ask

# Gather all user inputs at the beginning
read -p "Enter the hostname for this machine: " HOSTNAME

read -p "Do you want to create new partitions? (y/n): " create_partitions
if [[ $create_partitions =~ ^[Yy]$ ]]; then
    read -p "Enter size for EFI partition (e.g., 1G) [default: 1G]: " efi_size
    efi_size=${efi_size:-1G}
    read -p "Enter size for root partition (e.g., 250G): " root_size
    read -p "Enter size for swap partition (e.g., 4G): " swap_size
fi

read -p "Do you have an NVIDIA GPU? (y/n): " has_nvidia
read -p "Do you want to install SDDM (Simple Desktop Display Manager)? (y/n): " install_sddm
if [[ $install_sddm =~ ^[Yy]$ ]]; then
    read -p "Do you want to install Plasma (KDE Desktop Environment)? (y/n): " install_plasma
    read -p "Do you want to install Xorg? (y/n): " install_xorg
fi

# Choose kernel
choose_kernel() {
    while true; do
        echo "Please select a Linux kernel to install:"
        echo "1) linux"
        echo "2) linux-lts"
        echo "3) linux-zen"
        echo -n "Enter your choice [1-3]: "
        read choice
        case $choice in
            1) KERNEL="linux"; break;;
            2) KERNEL="linux-lts"; break;;
            3) KERNEL="linux-zen"; break;;
            *) echo "Invalid choice. Please choose again.";;
        esac
    done
}
choose_kernel
KERNEL_HEADERS="${KERNEL}-headers"

# Set password for root user
while true; do
    read -s -p "Enter password for root user: " ROOT_PASSWORD
    echo
    read -s -p "Confirm password for root user: " ROOT_PASSWORD_CONFIRM
    echo
    if [[ "$ROOT_PASSWORD" == "$ROOT_PASSWORD_CONFIRM" ]]; then
        break
    else
        print_color "31" "Passwords do not match. Please try again."
    fi
done

# Create a new user
echo "Setting up new user..."
while true; do
    read -p "Enter the username for the new user: " NEW_USER
    if [[ -z "$NEW_USER" ]]; then
        print_color "31" "Username cannot be empty. Please try again."
    else
        break
    fi
done

# Ask for user password
while true; do
    read -s -p "Enter password for $NEW_USER: " USER_PASSWORD
    echo
    read -s -p "Confirm password for $NEW_USER: " USER_PASSWORD_CONFIRM
    echo
    if [[ "$USER_PASSWORD" == "$USER_PASSWORD_CONFIRM" ]]; then
        break
    else
        print_color "31" "Passwords do not match. Please try again."
    fi
done

# Proceed with the rest of the script using the gathered inputs
loadkeys us
timedatectl set-ntp true
if [ $? -eq 0 ]; then
    print_color "32" "NTP synchronization enabled successfully."
else
    print_color "31" "Failed to enable NTP synchronization."
    exit 1
fi

configure_pacman() {
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
}
configure_pacman
sync

install_packages_host rsync

cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

if [[ $sync_mirrors =~ ^[Yy]$ ]]; then
    print_color "33" "Updating mirror list..."
    reflector -a 6 -c "$COUNTRY" -p https --sort rate --save /etc/pacman.d/mirrorlist
    print_color "32" "Mirror list updated successfully."
else
    print_color "33" "Skipping mirror sync."
fi

print_color "33" "Installing necessary packages..."
install_packages_host gptfdisk btrfs-progs glibc

umount -R /mnt 2>/dev/null || true

if [[ $create_partitions =~ ^[Yy]$ ]]; then
    # Use gdisk to create the partitions
    print_color "33" "Creating partitions..."
    print_color "36" "Please enter the sizes for each partition."

    # Validate user inputs
    if ! [[ $efi_size =~ ^[0-9]+[GgMm]$ ]] || ! [[ $root_size =~ ^[0-9]+[GgMm]$ ]] || ! [[ $swap_size =~ ^[0-9]+[GgMm]$ ]]; then
        print_color "31" "Invalid size format. Please use the format (e.g., 1G, 250G)."
        exit 1
    fi

    gdisk $BOOT_DISK << EOF
o
y
n
1

+${efi_size}
ef00
n
2

+${root_size}
8300
n
3

+${swap_size}
8200
w
y
EOF
else
    print_color "33" "Skipping partition creation. Using existing partitions."
fi

# Format the partitions (moved outside the if statement)
print_color "33" "Formatting partitions..."
mkfs.fat -F32 $EFI_PARTITION
mkfs.btrfs -f $ROOT_PARTITION
mkswap $SWAP_PARTITION

# Mount the partitions and create subvolumes
print_color "33" "Creating and mounting BTRFS subvolumes..."
mount $ROOT_PARTITION /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@snapshots

umount -R /mnt

# Updated mount options for better SSD performance
mount -o noatime,compress-force=zstd:3,ssd,space_cache=v2,subvol=@ $ROOT_PARTITION /mnt
mount --mkdir -o noatime,compress-force=zstd:3,ssd,space_cache=v2,subvol=@home $ROOT_PARTITION /mnt/home
mount --mkdir -o noatime,compress-force=zstd:3,ssd,space_cache=v2,subvol=@log $ROOT_PARTITION /mnt/var/log
mount --mkdir -o noatime,compress-force=zstd:3,ssd,space_cache=v2,subvol=@snapshots $ROOT_PARTITION /mnt/.snapshots

swapon $SWAP_PARTITION

mount --mkdir $EFI_PARTITION /mnt/boot/EFI

print_color "33" "Installing base system..."

# Choose terminal emulator
print_color "36" "Please select a terminal emulator to install:"
echo "1) Alacritty"
echo "2) Kitty"
echo "3) Custom"
echo "4) None"
while true; do
    read -p "Enter your choice [1-4]: " terminal_choice
    case $terminal_choice in
        1) TERMINAL="alacritty"; break;;
        2) TERMINAL="kitty"; break;;
        3) 
            read -p "Enter the name of the terminal package you want to install: " TERMINAL
            break;;
        4) TERMINAL=""; break;;
        *) echo "Invalid choice. Please try again.";;
    esac
done

# Define base packages with conditional terminal
BASE_PACKAGES=(base base-devel "$KERNEL" "$KERNEL_HEADERS" linux-firmware sof-firmware networkmanager grub efibootmgr os-prober micro git wget bluez pipewire)
if [[ -n "$TERMINAL" ]]; then
    BASE_PACKAGES+=("$TERMINAL")
fi

install_base_packages "${BASE_PACKAGES[@]}"

print_color "33" "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

print_color "32" "Base system installation complete!"
print_color "33" "Please review /mnt/etc/fstab before rebooting."
print_color "36" "You can now chroot into the new system with: arch-chroot /mnt"

# Set timezone and clock
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Kathmandu /etc/localtime
arch-chroot /mnt hwclock --systohc --utc

# Generate locale
arch-chroot /mnt sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
arch-chroot /mnt locale-gen
echo LANG=en_US.UTF-8 > /mnt/etc/locale.conf
echo KEYMAP=us > /mnt/etc/vconsole.conf
echo $HOSTNAME > /mnt/etc/hostname

# Set the root password
echo "Setting password for root user..."
echo "root:$ROOT_PASSWORD" | arch-chroot /mnt chpasswd

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

# Install GRUB
install_grub() {
    print_color "32" "Installing GRUB for EFI..."
    if ! mountpoint -q /mnt/boot/EFI; then
        mkdir -p /mnt/boot/EFI
        mount $EFI_PARTITION /mnt/boot/EFI
    fi
    install_packages efibootmgr
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/EFI --bootloader-id="$LABEL"

    install_packages os-prober
    echo "Enabling os-prober in GRUB configuration..."
    arch-chroot /mnt sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
    echo "Generating GRUB configuration..."
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

# Call the function to install GRUB
install_grub

# Update package database
if ! arch-chroot /mnt pacman -Syy --noconfirm --needed; then
    print_color "31" "Failed to update package database"
    exit 1
fi

# Backup and modify mkinitcpio.conf
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

if [[ $has_nvidia =~ ^[Yy]$ ]]; then
    print_color "32" "Installing NVIDIA drivers and configuring the system..."
    NVIDIA_PACKAGES=(nvidia-dkms libglvnd opencl-nvidia nvidia-utils lib32-libglvnd lib32-opencl-nvidia lib32-nvidia-utils nvidia-settings)
    install_packages "${NVIDIA_PACKAGES[@]}"
    NVIDIA_MODULES=("nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm")

    # Modify mkinitcpio.conf to add NVIDIA modules after existing modules
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

    # Create or modify /etc/modprobe.d/nvidia.conf
    print_color "33" "Adding NVIDIA options to /etc/modprobe.d/nvidia.conf"
    echo "options nvidia_drm modeset=1 fbdev=1" | arch-chroot /mnt tee /etc/modprobe.d/nvidia.conf > /dev/null
else
    print_color "33" "Skipping NVIDIA setup."
fi

if [[ $install_sddm =~ ^[Yy]$ ]]; then
    print_color "32" "Installing SDDM..."
    install_packages sddm
    print_color "32" "Enabling SDDM service..."
    arch-chroot /mnt systemctl enable sddm

    if [[ $install_xorg =~ ^[Yy]$ ]]; then
        print_color "32" "Installing minimal Xorg for KDE..."
        XORG_PACKAGES=(xorg-server xorg-xinit xorg-xrandr xorg-xsetroot)
        install_packages "${XORG_PACKAGES[@]}"
    else
        print_color "33" "Skipping Xorg installation."
    fi

    if [[ $install_plasma =~ ^[Yy]$ ]]; then
        print_color "32" "Installing Plasma..."
        PLASMA_PACKAGES=(plasma-desktop sddm-kcm)
        install_packages "${PLASMA_PACKAGES[@]}"

        print_color "32" "Installing KDE Control Modules..."
        KDE_PACKAGES=(fastfetch discover dolphin ark bluez firewalld kde-gtk-config breeze-gtk kdeconnect kdeplasma-addons bluedevil kgamma kscreen plasma-firewall plasma-browser-integration plasma-nm plasma-pa plasma-sdk plasma-systemmonitor power-profiles-daemon kwallet-pam)
        install_packages "${KDE_PACKAGES[@]}"

        print_color "32" "Installing common fonts..."
        FONT_PACKAGES=(ttf-liberation ttf-dejavu noto-fonts noto-fonts-emoji noto-fonts-cjk ttf-roboto ttf-roboto-mono ttf-droid ttf-opensans ttf-hack ttf-fira-code ttf-fira-mono ttf-cascadia-code adobe-source-code-pro-fonts adobe-source-sans-fonts adobe-source-serif-fonts)
        install_packages "${FONT_PACKAGES[@]}"
    else
        print_color "33" "Skipping Plasma installation."
    fi
else
    print_color "33" "Skipping SDDM installation."
fi

# Enable necessary services
print_color "32" "Enabling necessary services..."
arch-chroot /mnt /bin/bash -c "systemctl enable NetworkManager"
arch-chroot /mnt /bin/bash -c "systemctl enable bluetooth"
arch-chroot /mnt /bin/bash -c "systemctl enable fstrim.timer"

arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

sync
