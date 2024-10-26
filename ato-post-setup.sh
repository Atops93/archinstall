#!/bin/bash

echo "Make sure you are connected to the internet so packages can be installed."
echo "(1) I'm Connected to the Net!"
echo "(2) Exit with Ctrl+C or Ctrl+D, connect to WiFi, and rerun this script."

# Testing internet connection
echo "Testing internet connection..."
if ! ping -c 1 archlinux.org &>/dev/null; then
    echo "No internet connection. Please connect and try again."
    exit 1
else
    echo "Internet connection verified."
fi

# Install yay (AUR helper)
if ! command -v yay &>/dev/null; then
    echo "Installing yay..."
    git clone https://aur.archlinux.org/yay.git
    cd yay || exit
    makepkg -si --noconfirm
    cd ..
else
    echo "yay is already installed."
fi

# Install essential packages
echo "Installing packages..."
yay -S --noconfirm firefox wget curl lynx gcc rsync glava thunar gvfs picom \
    openssh flameshot alacritty btop qemu-full edk2-ovmf rofi dxvk-bin \
    cava cmatrix-git jellyfin cmus dosfstools mtools cmake pipewire \
    lib32-pipewire wireplumber fastfetch meson musl p7zip unzip

# Optional Chaotic-AUR setup (commented out)
# echo "Setting up Chaotic-AUR repository..."
# sudo tee -a /etc/pacman.conf <<EOL
# [chaotic-aur]
# Include = /etc/pacman.d/chaotic-mirrorlist
# EOL
# sudo pacman -Sy

# User prompt for environment setup
echo "Choose an environment setup option:"
echo "(1) Clone and install dwm setup with Alacritty"
echo "(2) Install KDE (no display manager, use startx)"
echo "(3) Placeholder for custom environment"
echo "(4) Placeholder for custom environment"
echo "(5) Placeholder for custom environment"
read -rp "Enter your choice [1-5]: " choice

case $choice in
    1)
        echo "Cloning and setting up dwm..."
        git clone https://github.com/atops93/ato-dwm
        cd ato-dwm || exit
        chmod +x install.sh
        ./install.sh
        cd ..
        ;;
    2)
        echo "Installing KDE..."
        sudo pacman -S --noconfirm plasma-desktop xorg-server xorg-xinit
        ;;
    3)
        echo "Custom environment setup placeholder 1"
        # Add any commands for custom environment setup here
        ;;
    4)
        echo "Custom environment setup placeholder 2"
        # Add any commands for custom environment setup here
        ;;
    5)
        echo "Custom environment setup placeholder 3"
        # Add any commands for custom environment setup here
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo "Setup complete! Reboot or restart your display manager as needed."

