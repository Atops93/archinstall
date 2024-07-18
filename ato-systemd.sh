#!/usr/bin/env bash

lsblk
read lsblk

echo "Enter Root partition: "
read ROOT

echo "Enter Swap partition: "
read SWAP

echo "Enter EFI partition: "
read EFI

echo "Choose a Desktop Environment"
echo "1. None"
echo "2. KDE"

# format
mkfs.ext4 -L "ROOT" "${ROOT}"
mkswap "${SWAP}"
mkfs.fat -F 32 -n "EFISYSTEM" "${EFI}"

# mount
mount -t ext4 "${ROOT}" /mnt
swapon "${SWAP}"
mount -t fat "${EFI}" /mnt/boot/

# mirrors


# packages
pacstrap -K /mnt base linux linux-firmware intel-ucode sof-firmware networkmanager nano

genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf

passwd

pacman -Syu base-devel git efibootmgr

useradd -m atops
passwd atops
usermod -aG wheel atops


bootctl install --path /mnt/boot
echo "default arch.conf" >> /mnt/boot/loader/loader.conf
cat <<EOF > /mnt/boot/loader/entries/arch.conf
title  Arch Linux
linux  /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=${ROOT} rw
EOF

echo "-----REBOOT-----"