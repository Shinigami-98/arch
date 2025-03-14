#!/bin/bash
# Format the partitions

# Removed redundant btrfs-progs installation (now in system_configure.sh)

print_color "33" "Formatting partitions..."
mkfs.fat -F32 $EFI_PARTITION
mkfs.btrfs -f $ROOT_PARTITION

# Handle swap based on SWAP_TYPE
if [[ "$SWAP_TYPE" == "partition" && -n "$SWAP_PARTITION" ]]; then
    print_color "33" "Formatting swap partition..."
    mkswap $SWAP_PARTITION
fi

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
