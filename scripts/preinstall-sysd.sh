#!/usr/bin/env bash

lsblk

echo "Enter Root partition:"
read ROOT

echo "Enter Swap partition:"
read SWAP

echo "Enter EFI partition:"
read EFI

# format
mkfs.ext4 -L "ROOT" "${ROOT}"
mkswap "${SWAP}"
mkfs.fat -F 32 -n "EFISYSTEM" "${EFI}"

# mount
mount -t ext4 "${ROOT}" /mnt
swapon "${SWAP}"
mount -t fat "${EFI}" /mnt/boot

# mirrors
lynx https://archlinux.org/mirrorlist/?country=AU&protocol=http&protocol=https&ip_version=4

pacstrap -K /mnt base linux linux-firmware intel-ucode networkmanager sof-firmware nano

genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
sed -i 's/^#en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_AU.UTF-8" >> /etc/locale.conf
sed -i 's/^#[extra]/[extra]' /etc/pacman.conf
sed -i 's/^#Include = /etc/pacman.d/mirrorlist/Include = /etc/pacman.d/mirrorlist' /etc/pacman.conf

echo "hostname?"
read $hostname
if ! [ $hostname ]
then
  hostname="arch"
fi

echo $hostname >> /etc/hostname

passwd

pacman -Syu base-devel git efibootmgr

useradd -m atops
passwd atops
usermod -aG wheel atops
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers


bootctl install --path /mnt/boot
echo "default arch.conf" >> /mnt/boot/loader/loader.conf
cat <<EOF > /mnt/boot/loader/entries/arch.conf
title  Arch Linux
linux  /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=${ROOT} rw
EOF

systemctl enable NetworkManager

exit
umount -R /mnt

echo "-----REBOOT-----"