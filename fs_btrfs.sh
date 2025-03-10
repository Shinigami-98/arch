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