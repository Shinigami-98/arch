#! /bin/zsh

# Format the partitions
print_color "33" "Formatting partitions with ext4 filesystem..."
mkfs.fat -F32 $EFI_PARTITION
mkfs.ext4 $ROOT_PARTITION

# Format home partition only if it's separate from root
if [[ $SEPARATE_HOME = true ]]; then
    print_color "33" "Formatting separate home partition..."
    mkfs.ext4 $HOME_PARTITION
fi

# Format swap partition if using traditional swap
if [[ $SWAP_TYPE == "partition" ]]; then
    print_color "33" "Formatting swap partition..."
    mkswap $SWAP_PARTITION
fi

# Mount the partitions
print_color "33" "Mounting partitions..."
mount $ROOT_PARTITION /mnt

# Mount home partition or create home directory
if [[ $SEPARATE_HOME = true ]]; then
    mkdir -p /mnt/home
    mount $HOME_PARTITION /mnt/home
else
    print_color "33" "Creating /home directory on root partition..."
    mkdir -p /mnt/home
fi

# Create and mount EFI partition
mkdir -p /mnt/boot/EFI
mount $EFI_PARTITION /mnt/boot/EFI

# Enable swap if using traditional swap partition
if [[ $SWAP_TYPE == "partition" ]]; then
    swapon $SWAP_PARTITION
    print_color "32" "Swap activated."
elif [[ $SWAP_TYPE == "zram" ]]; then
    print_color "33" "zram will be configured later."
else
    print_color "33" "No swap configured as requested."
fi

print_color "32" "ext4 filesystem setup complete."
