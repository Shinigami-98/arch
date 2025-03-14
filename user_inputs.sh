#!/bin/bash
sync_mirrors=$(get_yes_no "Do you want to sync mirrors for faster downloads?")

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

KERNEL_HEADERS="${KERNEL}-headers"

has_nvidia=$(get_yes_no "Do you have an NVIDIA GPU?")
install_xorg=$(get_yes_no "Do you want to install Xorg?")
install_grub=$(get_yes_no "Do you want to install GRUB?")

# Ask for GRUB label if user wants to install GRUB
if [[ $install_grub =~ ^[Yy]$ ]]; then
    # Set a default label
    default_label="Arch Linux"
    
    # Ask for custom label
    read -p "Enter GRUB bootloader label [$default_label]: " custom_label
    
    # Use the custom label if provided, otherwise use the default
    LABEL=${custom_label:-"$default_label"}
    
    print_color "32" "GRUB will be installed with label: $LABEL"
fi

install_sddm=$(get_yes_no "Do you want to install SDDM (Simple Desktop Display Manager)?")
install_plasma=$(get_yes_no "Do you want to install Plasma (KDE Desktop Environment)?")

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
            while true; do
                read -p "Enter the name of the terminal package you want to install: " TERMINAL
                if [[ -z "$TERMINAL" ]]; then
                    print_color "31" "Terminal package name cannot be empty. Please try again."
                else
                    break
                fi
            done
            break;;
        4) TERMINAL=""; break;;
        *) print_color "31" "Invalid choice. Please try again.";;
    esac
done

while true; do
    read -p "Enter the hostname for this machine: " HOSTNAME
    if [[ -z "$HOSTNAME" ]]; then
        print_color "31" "Hostname cannot be empty. Please try again."
    elif [[ ! "$HOSTNAME" =~ ^[a-zA-Z0-9][-a-zA-Z0-9]*$ ]]; then
        print_color "31" "Invalid hostname format. Please use only letters, numbers, and hyphens, and start with a letter or number."
    else
        break
    fi
done


allow_empty_root_password=$(get_yes_no "Do you want no root login ?")

if [[ $allow_empty_root_password =~ ^[Yy]$ ]]; then
    print_color "33" "⚠️ Root login will be disabled (empty password)."
    ROOT_PASSWORD=""
    ROOT_PASSWORD_CONFIRM=""
else
    while true; do
        read -s -p "Enter password for root user: " ROOT_PASSWORD
        echo
        read -s -p "Confirm password for root user: " ROOT_PASSWORD_CONFIRM
        echo
        if [[ -z "$ROOT_PASSWORD" ]]; then
            print_color "31" "Password cannot be empty. Please try again."
        elif [[ "$ROOT_PASSWORD" == "$ROOT_PASSWORD_CONFIRM" ]]; then
            break
        else
            print_color "31" "Passwords do not match. Please try again."
        fi
    done
fi

echo "Setting up new user..."
while true; do
    read -p "Enter the username for the new user: " NEW_USER
    if [[ -z "$NEW_USER" ]]; then
        print_color "31" "Username cannot be empty. Please try again."
    elif [[ ! "$NEW_USER" =~ ^[a-z][-a-z0-9_]*$ ]]; then
        print_color "31" "Invalid username format. Username must start with a lowercase letter and can only contain lowercase letters, numbers, hyphens, and underscores."
    else
        break
    fi
done

while true; do
    read -s -p "Enter password for $NEW_USER: " USER_PASSWORD
    echo
    if [[ -z "$USER_PASSWORD" ]]; then
        print_color "31" "Password cannot be empty. Please try again."
        continue
    fi
    
    read -s -p "Confirm password for $NEW_USER: " USER_PASSWORD_CONFIRM
    echo
    if [[ "$USER_PASSWORD" == "$USER_PASSWORD_CONFIRM" ]]; then
        break
    else
        print_color "31" "Passwords do not match. Please try again."
    fi
done