#!/bin/bash
print_color "32" "Installing SDDM..."
install_packages sddm
print_color "32" "Enabling SDDM service..."
arch-chroot /mnt systemctl enable sddm


if [[ $install_plasma =~ ^[Yy]$ ]]; then
    print_color "32" "Installing Plasma..."
    install_packages "${PLASMA_PACKAGES[@]}"
    print_color "32" "Installing KDE Control Modules..."
    install_packages "${KDE_PACKAGES[@]}"
else
    print_color "33" "Skipping Plasma installation."
fi