#!/bin/zsh
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
