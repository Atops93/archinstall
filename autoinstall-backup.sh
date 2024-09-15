#!/usr/bin/env bash

###################################################
#				ATOPS ARCHINSTALL!				  #
###################################################

# mirrors
lynx https://archlinux.org/mirrorlist/?country=AU&protocol=https&ip_version=4&use_mirror_status=on

sleep 30

mv mirrorlist /etc/pacman.d/mirrorlist
vim /etc/pacman.d/mirrorlist

sleep 30

echo "Are you using btrfs? (y/n)"
echo "If y then the script will install the btrfs-progs pkg as it is needed on btrfs file systems"
	if 

# Core packages
pacstrap /mnt base linux linux-firmware linux-headers intel-ucode networkmanager sof-firmware neovim base-devel git

genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt

# Locale
ln -sf /usr/share/zoneinfo/Australia/Adelaide /mnt/etc/localtime
arch-chroot /mnt hwclock --systohc
sed 's/^#en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/' -i /mnt/etc/locale.gen
sed 's/#en_AU ISO-8859-1/en_AU ISO-8859-1/' -i /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo 'LANG=en_AU.UTF-8' > /mnt/etc/locale.conf


# Hostname
if [ "$hostname" = "" ]; then
		echo -n "Enter a hostname dummy: "; read -r hostname
fi
echo "$hostname" > /mnt/etc/hostname

# Setting up user
echo "Root password?"
	until arch-chroot /mnt passwd; do
		echo "Set a password u dumbass."
	done

echo "Enter your user: "
until $USER; do
	echo "Enter a user stupid"; read -r USER
 done
useradd -m $USER

echo "Enter user password:"
passwd $USER

usermod -aG wheel $USER
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

# Multilib
sed -i 's/^#[multilib]/[multilib]' /etc/pacman.conf
sed -i 's/^#Include = /etc/pacman.d/mirrorlist/Include = /etc/pacman.d/mirrorlist' /etc/pacman.conf

echo "Installing GRUB to the disk of the RootFS."
	if [ "$uefi" = "true" ]; then
		echo "installing efibootmgr"
		arch-chroot /mnt pacman -S grub efibootmgr
		echo "installing grub"
		if ! arch-chroot /mnt grub-install --efi-directory=/boot; then
			echo "ERROR: grub-install failed! Its either womp womp or skill issue, Most likely skill issue."
			sleep 30
		fi

	sed 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/' -i /mnt/etc/default/grub
	arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg


# Network
arch-chroot /mnt systemctl enable NetworkManager

echo "Are you finished?"
		cat << EOF
(1) Reboot & Continue to post install script?
(2) Use terminal to fix anything? If so do ctrl+D or ctrl+C.
EOF
if [[1]] ; then
		umount -R /mnt
		sleep 5
		reboot
