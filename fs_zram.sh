#! /bin/zsh

# Setup zram for swap
print_color "33" "Setting up zram for swap..."

# Process the user-specified zram size
if [[ $zram_size =~ ^([0-9]+)[Gg]$ ]]; then
    # Convert GB to MB
    zram_size_mb=$((${BASH_REMATCH[1]} * 1024))
    print_color "33" "Converting ${BASH_REMATCH[1]}GB to ${zram_size_mb}MB for zram swap"
elif [[ $zram_size =~ ^([0-9]+)[Mm]$ ]]; then
    # Already in MB
    zram_size_mb=${BASH_REMATCH[1]}
    print_color "33" "Using ${zram_size_mb}MB for zram swap"
else
    # Fallback to automatic calculation if something went wrong
    print_color "31" "Invalid zram size format: $zram_size. Falling back to automatic calculation."
    
    # Calculate zram size (half of RAM, max 8GB)
    ram_size_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    ram_size_mb=$((ram_size_kb / 1024))
    zram_size_mb=$((ram_size_mb / 2))

    # Cap at 8GB (8192MB)
    if [ $zram_size_mb -gt 8192 ]; then
        zram_size_mb=8192
    fi

    print_color "33" "Detected RAM: ${ram_size_mb}MB, allocating ${zram_size_mb}MB for zram swap"
fi

# Install required packages to chroot environment
print_color "33" "Installing zram-generator in the new system..."
install_packages zram-generator

# Create zram configuration file
print_color "33" "Creating zram configuration..."
cat > /mnt/etc/systemd/zram-generator.conf << EOF
[zram0]
zram-size = ${zram_size_mb}MB
compression-algorithm = zstd
swap-priority = 100
EOF

print_color "32" "zram swap setup complete. Will be activated on first boot." 