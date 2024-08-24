#!/usr/bin/env bash

partEsp() {
	if [ "$uefi" = "true" ]; then
		until [[ "$esp" == "/dev/"* ]] && [ -b "$esp" ]; do
			echo -n "EFI System Partiton: "; read -r esp
		done

		until [ "$format_esp" = "y" ] || [ "$format_esp" = "n" ]; do
			echo -n "Format? "; read -r format_esp
		done
	fi
}
partRoot() {
	until [[ "$rootfs" == "/dev/"* ]] && [ -b "$rootfs" ]; do
		echo -n "Rootfs: "; read -r rootfs
	done
	until [ "$format_rootfs" = "y" ] || [ "$format_rootfs" = "n" ]; do
		echo -n "Format? "; read -r format_rootfs
	done
}
partSwap() {
	until { [[ "$swap" == "/dev/"* ]] && [ -b "$swap" ]; }; do
		if [ "$swap" = "none" ]; then
			format_swap="N/A"
			break;
		fi

		if [[ "$swap" =~ ^/[-_/a-zA-Z0-9]*$ ]]; then
			case "$swap" in
				/dev* | /sys* | /proc* | /tmp* | /run* | /var/tmp* | /var/run* | /boot* | /usr* | /bin* | /lib* | /etc* | /home* | /opt* | /root* | /sbin* | /srv*)
					echo "This is a reserved directory.  Please choose something else for your swapfile/partition."
					swap=""
					continue ;;
				*)
					swapfile=true
					format_swap="N/A"

					until [ "$validSize" = true ]; do
						read -rp "Enter file size: " input_size
						# Convert input to lowercase and remove 'b' if present
						input_size=${input_size,,}
						input_size=${input_size//b/}

						# Convert input to bytes
						size_in_bytes=$(toBytes $input_size)

						# Check if size is a multiple of 4MB
						if (( $size_in_bytes % (4*1024*1024) == 0 )); then
							swapfileSize4MB=$(( $size_in_bytes / (4*1024*1024) ))
							validSize=true
						else
							echo "Invalid size"
						fi
					done
					unset validSize input_size size_in_bytes

					break;
					;;
			esac
		fi
		echo -n "Swap: "; read -r swap
	done
	until [ "$swapfile" = "true" ] || [ "$swap" = "none" ] || [ "$format_swap" = "y" ] || [ "$format_swap" = "n" ]; do
		echo -n "Format? "; read -r format_swap
	done
}


partToDisk() {
	if [[ "$1" == "/dev/nvme"* ]] || [[ "$1" == "/dev/mmcblk"* ]]; then
		echo "${1//p[0-9]/}"
	elif [[ "$1" = "/dev/sd"* ]] || [[ "$1" = "/dev/vd"* ]]; then
		echo "${1//[0-9]}"
	fi
}

installerSetup() {
	echo "In the Arch Linux installer.  Autoinstalling."
	if [ -d /sys/firmware/efi ] && [ -f /sys/firmware/efi/runtime ] && [ -f /sys/firmware/efi/systab ]; then
		echo "Detected UEFI machine."
		uefi=true
	fi

	echo "Please input your partitions.  I trust you've already created & sized them to your liking."

	partEsp
	partRoot
	partSwap

	until [ "$goodParts" = "true" ]; do
		echo "To review:"
		if [ "$uefi" = "true" ]; then
			echo "ESP: $esp; Format=$format_esp"
		fi
		echo "RootFS: $rootfs; Format=$format_rootfs"
		echo -n "Swap: $swap; Format=$format_swap"
		if [ "$swapfile" = "true" ]; then
			echo -n "; Size=$(($swapfileSize4MB * 4))MB"
		fi
		echo

    		lsblk
		echo "Would you like to change any of these?"
		cat << EOF
1. EFI System Partition
2. RootFS
3. Swap
4. Use terminal to fix anything?
5. Continue Installer

EOF
		echo -n "Pick one: "; read -r choice
		case "$choice" in
			"1")
				if [ "$uefi" != "true" ]; then
					echo "Not a UEFI system."
					continue
				fi
				unset esp format_esp
				partEsp
				;;
			"2")
				unset rootfs format_rootfs
				partRoot
				;;
			"3")
				unset swap swapfile swapfileSize4MB format_swap
				partSwap
				;;
			"4")
				echo "Ctrl+D or \"exit\" to get back to the script!"
				zsh
				;;
			"5")
				goodParts=true
		esac
	done
	echo "Alright, installer commencing now!"
	# Unmount any disks that may be mounted
	
	umount -R /mnt &> /dev/null
	# swapoff the swap partition
	if [[ "$swap" = "/dev/"* ]]; then
		if swapon | grep "$swap"; then
			swapoff "$swap"
		fi
	fi

	# unmount rootfs
	if mount | grep "$rootfs" &> /dev/null; then
		umount "$rootfs"
	fi

	# unmount ESP
	if [ "$uefi" = "true" ] && mount | grep "$esp" &> /dev/null; then
		umount "$esp"
	fi


	# All disk are unmounted, format any necessary.
	if [ "$format_swap" = "y" ]; then
		wipefs -a "$swap"
		mkswap "$swap"
	fi

	if [ "$format_rootfs" = "y" ]; then
		wipefs -a "$rootfs"
		mkfs.btrfs "$rootfs"
	fi

	if [ "$format_esp" = "y" ]; then
		wipefs -a "$esp"
		mkfs.vfat -F32 "$esp"
	fi

	# All disks are formatted.  Mount them.

	# Clear out any old data in /mnt
	rm -rf /mnt/*

	mount "$rootfs" /mnt
	fstrim /mnt

	if [ "$uefi" = "true" ]; then
		mount "$esp" /mnt/boot --mkdir
	fi

	if [ "$swapfile" = "true" ] && [ "$swap" != "none" ]; then
		# make swapfile
		echo "Making swapfile..."
		dd if=/dev/zero of=/mnt/"$swap" bs=4M count="$swapfileSize4MB" status=progress
		mkswap /mnt/"$swap"
	fi

	if [ "$swap" != "none" ]; then
		if [ "$swapfile" != "true" ]; then
			swapon "$swap"
		else
			swapon "/mnt/$swap"
		fi
	fi

# mirrors
lynx https://archlinux.org/mirrorlist/?country=AU&protocol=https&ip_version=4&use_mirror_status=on

sleep 30

sudo mv mirrorlist /etc/pacman.d/mirrorlist

vi /etc/pacman.d/mirrorlist

sleep 30

# Core packages
pacstrap /mnt base linux linux-firmware linux-headers intel-ucode networkmanager sof-firmware neovim base-devel git

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt

# Locale
ln -sf /usr/share/zoneinfo/Australia/Adelaide /etc/localtime
hwclock --systohc
sed -i 's/^#en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
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

echo "[chaotic-aur]" >> /etc/pacman.conf
echo "Include = /etc/pacman.d/chaotic-mirrorlist" >> /etc/pacman.conf

echo "Installing GRUB to the disk of the RootFS."
	if [ "$uefi" = "true" ]; then
		echo "installing efibootmgr"
		arch-chroot /mnt pacman -S grub efibootmgr
		echo "installing grub"
		if ! arch-chroot /mnt grub-install --efi-directory=/boot; then
			echo "ERROR: grub-install failed! Its either womp womp or skill issue, Most likely skill issue."
			sleep 30
		fi

	sed 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=1/' -i /mnt/etc/default/grub
	arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg


# Network
systemctl enable NetworkManager

echo "Are you finished?"
		cat << EOF
(1) Reboot & Continue to post install script?
(2) Use terminal to fix anything? ctrl+D or ctrl+C?
EOF
if [[1]] ; then
		umount -R /mnt
		sleep 5
		reboot
