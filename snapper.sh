set -e

# Configuration
COUNTRY="Singapore"
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

read -p "Do you want to set up zram for swap? (y/n): " setup_zram
if [[ $setup_zram =~ ^[Yy]$ ]]; then
    while true; do
        read -p "Enter desired zram size in GB (e.g., 4 for 4GB, or 'ram' to match RAM size): " zram_size
        if [[ "$zram_size" == "ram" ]] || [[ "$zram_size" =~ ^[0-9]+$ ]]; then
            break
        else
            print_color "31" "Please enter a valid number or 'ram'"
        fi
    done
fi

read -p "Do you want to set up Snapper for system snapshots? (y/n): " setup_snapper

if [[ $setup_zram =~ ^[Yy]$ ]]; then
    print_color "32" "Setting up zram for swap..."
    print_color "33" "Debug: Testing environment..."
    if pwd; then
        print_color "32" "Environment is accessible"
    else
        print_color "31" "Cannot access environment"
        exit 1
    fi

    # Install zram-generator with error checking
    if ! pacman -S --noconfirm zram-generator; then
        print_color "31" "Failed to install zram-generator. Check if environment is properly set up."
        exit 1
    fi

    # Configure zram with user-specified size
    echo "[zram0]" > /etc/systemd/zram-generator.conf
    if [[ "$zram_size" == "ram" ]]; then
        echo "zram-size = ram" >> /etc/systemd/zram-generator.conf
    else
        echo "zram-size = ${zram_size}096" >> /etc/systemd/zram-generator.conf
    fi
    echo "compression-algorithm = zstd" >> /etc/systemd/zram-generator.conf

    # Enable zram swap with top priority
    systemctl enable --now systemd-zram-setup@zram0.service
    echo "/dev/zram0 none swap defaults,pri=100 0 0" >> /etc/fstab

    print_color "32" "Zram swap set up successfully with top priority."
else
    print_color "33" "Skipping zram setup."
fi

# Move the snapper setup implementation here (after zram setup)
if [[ $setup_snapper =~ ^[Yy]$ ]]; then
    print_color "32" "Setting up Snapper for BTRFS snapshots..."

    # Install necessary packages including GUI tools
    pacman -S --noconfirm snapper snap-pac grub-btrfs

    # Create snapper config for root
    snapper -c root create-config /

    # Set correct permissions for snapshots directory
    chmod 750 /.snapshots
    chown :wheel /.snapshots

    # Modify default snapper configuration according to Arch Wiki
    sed -i 's/^TIMELINE_MIN_AGE="1800"/TIMELINE_MIN_AGE="1800"/' /etc/snapper/configs/root
    sed -i 's/^TIMELINE_LIMIT_HOURLY="10"/TIMELINE_LIMIT_HOURLY="5"/' /etc/snapper/configs/root
    sed -i 's/^TIMELINE_LIMIT_DAILY="10"/TIMELINE_LIMIT_DAILY="7"/' /etc/snapper/configs/root
    sed -i 's/^TIMELINE_LIMIT_WEEKLY="0"/TIMELINE_LIMIT_WEEKLY="0"/' /etc/snapper/configs/root
    sed -i 's/^TIMELINE_LIMIT_MONTHLY="10"/TIMELINE_LIMIT_MONTHLY="0"/' /etc/snapper/configs/root
    sed -i 's/^TIMELINE_LIMIT_YEARLY="10"/TIMELINE_LIMIT_YEARLY="0"/' /etc/snapper/configs/root

    # Set up snapshot cleanup
    sed -i 's/^NUMBER_LIMIT="50"/NUMBER_LIMIT="10"/' /etc/snapper/configs/root
    sed -i 's/^NUMBER_MIN_AGE="1800"/NUMBER_MIN_AGE="1800"/' /etc/snapper/configs/root

    # Set ALLOW_USERS and ALLOW_GROUPS in snapper config
    sed -i 's/^ALLOW_USERS=""/ALLOW_USERS="'"$NEW_USER"'"/' /etc/snapper/configs/root
    sed -i 's/^ALLOW_GROUPS=""/ALLOW_GROUPS="wheel"/' /etc/snapper/configs/root

    # Configure pacman hooks for automatic snapshots
    mkdir -p /etc/pacman.d/hooks
    cat > /etc/pacman.d/hooks/50-bootbackup.hook << 'EOF'
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Path
Target = usr/lib/modules/*/vmlinuz

[Action]
Depends = rsync
Description = Backing up /boot...
When = PreTransaction
Exec = /usr/bin/rsync -a --delete /boot /.bootbackup
EOF

    cat > /etc/pacman.d/hooks/95-snapshot.hook << 'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Creating Snapper snapshot...
Depends = snapper
When = PreTransaction
Exec = /usr/bin/snapper --no-dbus create -d "pacman transaction"
EOF

    # Enable and start snapper timeline and cleanup services
    systemctl enable --now snapper-timeline.timer
    systemctl enable --now snapper-cleanup.timer

    # Create grub-btrfs config directory and enable its service
    mkdir -p /etc/grub.d/41_snapshots-btrfs
    systemctl enable grub-btrfsd

    # Create the first snapshot
    snapper -c root create -d "Initial snapshot"

    print_color "32" "Snapper setup complete with Arch Wiki recommended configuration:"
    print_color "33" "- 5 hourly snapshots"
    print_color "33" "- 7 daily snapshots"
    print_color "33" "- 0 weekly snapshots"
    print_color "33" "- 0 monthly snapshots"
    print_color "33" "- 0 yearly snapshots"
    print_color "33" "- Maximum of 10 snapshots for number cleanup"
    print_color "33" "- Automatic snapshots before package operations"
    print_color "33" "- Boot backup before kernel updates"
    print_color "33" "- Initial snapshot created"
    print_color "33" "- Snapshots will be available in GRUB menu"
    print_color "33" "- GUI tools installed: snapper-gui and btrfs-assistant"
else
    print_color "33" "Skipping Snapper setup."
fi

sync
