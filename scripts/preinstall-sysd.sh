#!/usr/bin/env bash

lsblk

echo "Enter Root partition:"
read ROOT

echo "Enter Swap partition:"
read SWAP

echo "Enter EFI partition:"
read EFI


while true; do
    echo "Choose Bootloader"
    echo "1. Systemdboot"
    echo "2. GRUB"
    read BOOT

    # Check if input is either 1 or 2
    if [[ $BOOT == 1 || $BOOT == 2 ]]; then
        break
    else
        echo "Enter either 1 or 2."
    fi
done

# format
mkfs.ext4 -L "ROOT" "${ROOT}"
mkswap "${SWAP}"
mkfs.fat -F 32 -n "EFISYSTEM" "${EFI}"

# mount
mount -t ext4 "${ROOT}" /mnt
swapon "${SWAP}"
mount -t fat "${EFI}" /mnt/boot

# mirrors
curl https://archlinux.org/mirrorlist/?country=AU&protocol=http&protocol=https&ip_version=4

pacstrap -K /mnt base linux linux-firmware intel-ucode networkmanager sof-firmware nano base-devel git curl

genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
ln -sf /usr/share/zoneinfo/Australia/Adelaide /etc/localtime
hwclock --systohc
sed -i 's/^#en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_AU.UTF-8" >> /etc/locale.conf
sed -i 's/^#[extra]/[extra]' /etc/pacman.conf
sed -i 's/^#Include = /etc/pacman.d/mirrorlist/Include = /etc/pacman.d/mirrorlist' /etc/pacman.conf

echo atops-btw >> /etc/hostname

passwd

useradd -m atops
passwd atops
usermod -aG wheel atops
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

if [[ $BOOT == 1 ]]; then
bootctl install --path=/boot
echo "default arch.conf" >> /mnt/boot/loader/loader.conf
cat <<EOF > /mnt/boot/loader/entries/arch.conf
title  Arch Linux
linux  /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=${ROOT} rw
EOF
else
    pacman -S grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id="Linux Boot Manager"
    grub-mkconfig -o /boot/grub/grub.cfg
fi


systemctl enable NetworkManager

exit
umount -R /mnt

echo "-----REBOOT-----"