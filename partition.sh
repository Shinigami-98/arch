# Function to handle yes/no inputs
get_yes_no() {
    local prompt="$1"
    local result
    
    while true; do
        read -p "$prompt (y/n): " result
        if [[ $result =~ ^[YyNn]$ ]]; then
            echo "$result"
            return 0
        else
            print_color "31" "Invalid input. Please enter 'y' or 'n'."
        fi
    done
}

# --- 1. PRE-INSTALLATION PHASE ---

# Display current system state
echo "Current disk layout:"
lsblk
echo

# --- 2. DISK PARTITIONING PREPARATION ---

while true; do
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
            break
            ;;
        2)
            print_color "36" "Available SATA/IDE disks:"
            lsblk -ndo NAME,TYPE | grep disk | grep -E 'sd[a-z]'
            read -p "Enter the SATA/IDE disk (e.g., sda, sdb): " sata_disk
            if [[ ! -b "/dev/${sata_disk}" ]]; then
                print_color "31" "Invalid disk. Please try again."
                continue
            fi
            BOOT_DISK="/dev/${sata_disk}"
            EFI_PARTITION="${BOOT_DISK}1"
            ROOT_PARTITION="${BOOT_DISK}2"
            break
            ;;
        3)
            BOOT_DISK="/dev/vda"
            if [[ ! -b "${BOOT_DISK}" ]]; then
                print_color "31" "VDA device not found. Please try again."
                continue
            fi
            EFI_PARTITION="${BOOT_DISK}1"
            ROOT_PARTITION="${BOOT_DISK}2"
            break
            ;;
        4)
            while true; do
                read -p "Enter the boot disk (e.g., /dev/vda): " BOOT_DISK
                if [[ ! -b "${BOOT_DISK}" ]]; then
                    print_color "31" "Device not found. Please try again."
                    continue
                fi
                break
            done
            
            while true; do
                read -p "Enter the EFI partition (e.g., ${BOOT_DISK}1): " EFI_PARTITION
                if [[ ! "${EFI_PARTITION}" =~ ^/dev/ ]]; then
                    EFI_PARTITION="/dev/${EFI_PARTITION}"
                fi
                break
            done
            
            while true; do
                read -p "Enter the root partition (e.g., ${BOOT_DISK}2): " ROOT_PARTITION
                if [[ ! "${ROOT_PARTITION}" =~ ^/dev/ ]]; then
                    ROOT_PARTITION="/dev/${ROOT_PARTITION}"
                fi
                break
            done
            
            break
            ;;
        *)
            print_color "31" "Invalid choice. Please try again."
            ;;
    esac
done

# Ask about partition layout
separate_home=$(get_yes_no "Do you want a separate partition for /home?")
if [[ $separate_home =~ ^[Yy]$ ]]; then
    print_color "32" "Using separate home partition."
    SEPARATE_HOME=true
    
    # Set up the home partition based on disk type
    case $partition_type in
        1)
            HOME_PARTITION="${BOOT_DISK}p3"
            ;;
        2|3)
            HOME_PARTITION="${BOOT_DISK}3"
            ;;
        4)
            while true; do
                read -p "Enter the home partition (e.g., ${BOOT_DISK}3): " HOME_PARTITION
                if [[ ! "${HOME_PARTITION}" =~ ^/dev/ ]]; then
                    HOME_PARTITION="/dev/${HOME_PARTITION}"
                fi
                break
            done
            ;;
    esac
else
    print_color "32" "Using root partition for /home."
    SEPARATE_HOME=false
    # Use the root partition for home
    HOME_PARTITION=$ROOT_PARTITION
fi

# Ask about swap configuration
while true; do
    print_color "36" "Choose swap configuration:"
    print_color "33" "1) Traditional swap partition"
    print_color "33" "2) zram (compressed swap in RAM, good for systems with 8GB+ RAM)"
    print_color "33" "3) No swap (not recommended)"
    read -p "Enter your choice [1-3]: " swap_choice
    
    case $swap_choice in
        1)
            SWAP_TYPE="partition"
            # Set up the swap partition based on disk type
            case $partition_type in
                1)
                    SWAP_PARTITION="${BOOT_DISK}p$([[ $SEPARATE_HOME = true ]] && echo 4 || echo 3)"
                    ;;
                2|3)
                    SWAP_PARTITION="${BOOT_DISK}$([[ $SEPARATE_HOME = true ]] && echo 4 || echo 3)"
                    ;;
                4)
                    while true; do
                        read -p "Enter the swap partition (e.g., ${BOOT_DISK}4): " SWAP_PARTITION
                        if [[ ! "${SWAP_PARTITION}" =~ ^/dev/ ]]; then
                            SWAP_PARTITION="/dev/${SWAP_PARTITION}"
                        fi
                        break
                    done
                    ;;
            esac
            break
            ;;
        2)
            SWAP_TYPE="zram"
            read -p "Enter size for zram swap (e.g., 4096M, 8192M) [default: 4096M]: " zram_size
            zram_size=${zram_size:-4096M}
            
            # Validate the zram size format
            if [[ ! $zram_size =~ ^[0-9]+[GgMm]$ ]]; then
                print_color "31" "Invalid size format. Please use the format (e.g., 4096M, 8192M)."
                continue
            fi
            
            print_color "32" "Using zram for swap with size: $zram_size"
            break
            ;;
        3)
            SWAP_TYPE="none"
            print_color "33" "⚠️ No swap will be configured. This is not recommended."
            confirm_no_swap=$(get_yes_no "Are you sure you want to continue without swap?")
            if [[ $confirm_no_swap =~ ^[Yy]$ ]]; then
                break
            else
                continue
            fi
            ;;
        *)
            print_color "31" "Invalid choice. Please try again."
            ;;
    esac
done

create_partitions=$(get_yes_no "Do you want to create new partitions?")

# Get partition sizes if creating new partitions
if [[ $create_partitions =~ ^[Yy]$ ]]; then
    while true; do
        print_color "36" "Please enter the sizes for each partition."
        
        read -p "Enter size for EFI partition (e.g., 1G) [default: 1G]: " efi_size
        efi_size=${efi_size:-1G}
        
        read -p "Enter size for root partition (e.g., 80G) [default: 80G]: " root_size
        root_size=${root_size:-80G}
        
        if [[ $SEPARATE_HOME = true ]]; then
            read -p "Enter size for home partition (e.g., 260G) [default: 260G]: " home_size
            home_size=${home_size:-260G}
        fi
        
        if [[ $SWAP_TYPE == "partition" ]]; then
            read -p "Enter size for swap partition (e.g., 8G) [default: 8G]: " swap_size
            swap_size=${swap_size:-8G}
        fi
        
        # Build validation regex based on selected options
        validation_regex="$efi_size =~ ^[0-9]+[GgMm]$ && $root_size =~ ^[0-9]+[GgMm]$"
        if [[ $SEPARATE_HOME = true ]]; then
            validation_regex="$validation_regex && $home_size =~ ^[0-9]+[GgMm]$"
        fi
        if [[ $SWAP_TYPE == "partition" ]]; then
            validation_regex="$validation_regex && $swap_size =~ ^[0-9]+[GgMm]$"
        fi
        
        if ! eval "[[ $validation_regex ]]"; then
            print_color "31" "Invalid size format. Please use the format (e.g., 1G, 50G). Let's try again."
            continue
        fi
        
        print_color "32" "Partition sizes confirmed:"
        print_color "33" "- EFI partition: $efi_size"
        print_color "33" "- Root partition: $root_size" 
        
        if [[ $SEPARATE_HOME = true ]]; then
            print_color "33" "- Home partition: $home_size"
        else
            print_color "33" "- Home directory: Using root partition"
        fi
        
        if [[ $SWAP_TYPE == "partition" ]]; then
            print_color "33" "- Swap partition: $swap_size"
        elif [[ $SWAP_TYPE == "zram" ]]; then
            print_color "33" "- Swap: Using zram with size: $zram_size"
        else
            print_color "33" "- Swap: None"
        fi
        
        confirm_sizes=$(get_yes_no "Are these sizes correct?")
        if [[ $confirm_sizes =~ ^[Yy]$ ]]; then
            break
        fi
    done
fi

# --- 2.1 FILESYSTEM SELECTION ---

while true; do
    print_color "36" "Choose filesystem for root and home partitions:"
    print_color "33" "1) ext4 - Good general purpose filesystem with solid reliability"
    print_color "33" "2) XFS - High performance filesystem, good for large files"
    print_color "33" "3) Btrfs - Modern filesystem with snapshots and subvolumes"
    read -p "Enter your choice [1-3]: " filesystem_choice
    
    case $filesystem_choice in
        1)
            FILESYSTEM="ext4"
            FILESYSTEM_SCRIPT="fs_ext.sh"
            break
            ;;
        2)
            FILESYSTEM="XFS"
            FILESYSTEM_SCRIPT="fs_xfs.sh"
            break
            ;;
        3)
            FILESYSTEM="Btrfs"
            FILESYSTEM_SCRIPT="fs_btrfs.sh"
            break
            ;;
        *)
            print_color "31" "Invalid choice. Please try again."
            ;;
    esac
done

print_color "32" "Selected filesystem: $FILESYSTEM"