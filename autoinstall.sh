#!/bin/bash -e
ourself="$PWD/$0"
if [ "$(uname -a | grep -v Linux)" != "" ]; then
	echo "Why are you not on Linux?"
	exit 1
fi

hostname_initial="$(cat /etc/hostname)"
if [ -f /etc/motd ]; then
	awk '/iwctl/ && /nmcli/ && /utility/ && /Wi-Fi, authenticate to the wireless network using the/' /etc/motd
fi
awkRet=$?

isArchISO=false
if [ "$hostname_initial" = "archiso" ] && [ "$awkRet" = "0" ]; then
	isArchISO=true
fi



if [ "$(tty)" != "/dev/tty1" ]; then
	# set stuff up
	systemctl disable --now getty@tty1
	
	# boot up a new instance on TTY1
	setsid sh -c 'exec /autosetup.sh <> /dev/tty1 >&0 2>&1'
	exit 0
fi

dots() {
	echo -ne "$1"
	sleep 0.25
	echo -n "$2"
	sleep 0.25
	echo -n "$2"
	sleep 0.25
	echo -n "$2"
	sleep 0.25
}
echo "Techflash autosetup script v0.0.3"
echo -e "\e[1;33m======= WARNING!!! =======\e[0m"
echo "This script will set up your PC exactly like I set up mine."
echo "If you're not sure about this, please back out now.  I'll give you 5 seconds."
dots "\e[32m5" "."
dots "4" "."
dots "\e[1;33m3" "."
dots "\e[0;33m2" "."
dots "\e[31m1" "!"
echo -e "\x1b[0m"



toBytes() {
	echo $1 | sed 's/.*/\L\0/;s/t/Xg/;s/g/Xm/;s/m/Xk/;s/k/X/;s/b//;s/X/ *1024/g' | bc
}

###########################################
#                                         #
#   I N - I N S T A L L E R   S E T U P   #
#                                         #
###########################################



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

		echo "Would you like to change any of these?"
		cat << EOF
1. EFI System Partition
2. RootFS
3. Swap
4. Drop to a shell to examine the situation
5. Looks Good!

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
		mkfs.ext4 "$rootfs"
	fi

	if [ "$format_esp" = "y" ]; then
		wipefs -a "$esp"
		mkfs.vfat -F32 "$esp"
	fi

	# All disks are formatted.  Mount them.

	# Clear out any old data in /mnt
	# shellcheck disable=SC2115
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

	echo "Setting up base system."
	# enable color & parallel downloads in pacman.conf
	sed 's/#Color/Color/' -i /etc/pacman.conf
	sed 's/#ParallelDownloads = 5/ParallelDownloads = 25/' -i /etc/pacman.conf

	until [ "$useCache" = "y" ] || [ "$useCache" = "n" ]; do
		echo -n "Are you on the LAN and would like to use the package caching server? (y/n)"; read -r useCache
	done
	
	until [ "$useTesting" = "y" ] || [ "$useTesting" = "n" ]; do
		echo -n "Would you like to use the testing repos? (y/n)"; read -r useTesting
	done

	if [ "$useCache" = "y" ]; then
		# could resolved
		rm /etc/resolv.conf
		cat << EOF > /etc/resolv.conf
search shack.techflash.wtf
nameserver 172.16.5.254
EOF
	fi

	# FAST PATH!  If both are no, don't modify the file at all!
	if [ "$useCache" = "y" ] || [ "$useTesting" = "y" ]; then
		# remove all lines after and including the line that maches '[core-testing]'.
		if [ "$useCache" = "y" ]; then
			# If the user wanted testing repos, we modify it after this.
			sed -n '/\[core-testing\]/q;p' -i /etc/pacman.conf
			cat << EOF >> /etc/pacman.conf
#[core-testing]
#Server = http://arch:9129/repo/archlinux/\$repo/os/\$arch

[core]
Server = http://arch:9129/repo/archlinux/\$repo/os/\$arch

#[extra-testing]
#Server = http://arch:9129/repo/archlinux/\$repo/os/\$arch

[extra]
Server = http://arch:9129/repo/archlinux/\$repo/os/\$arch
EOF
		fi

		if [ "$useTesting" = "y" ]; then
			# It's ugly, but it works
			cp /etc/pacman.conf file.txt
			perl -p -e 's/#\[core-testing\]\n/[core-testing]\n/' file.txt > file2.txt
			sed 's/#Server/Server/' -i file2.txt
			sed 's/#Include/Include/' -i file2.txt
			mv file2.txt file.txt

			perl -p -e 's/#\[extra-testing\]\n/[extra-testing]\n/' file.txt > file2.txt
			sed 's/#Server/Server/' -i file2.txt
			sed 's/#Include/Include/' -i file2.txt
			# Move it into the original
			rm file.txt
			mv file2.txt /etc/pacman.conf
		fi


		if [ "$useCache" = "y" ]; then
			# add the original footer back, we deleted it before.
			cat << EOF >> /etc/pacman.conf

# If you want to run 32 bit applications on your x86_64 system,
# enable the multilib repositories as required here.

#[multilib-testing]
#Include = /etc/pacman.d/mirrorlist

#[multilib]
#Include = /etc/pacman.d/mirrorlist

# An example of a custom package repository.  See the pacman manpage for
# tips on creating your own repositories.
#[custom]
#SigLevel = Optional TrustAll
#Server = file:///home/custompkgs
EOF
		fi
	fi

#echo "Setting up MY mirrors."
#setupMirrors

#setupMirrors() {
#    echo "Setting up mirrors for Australia..."
#
#    # Backup the current mirrorlist
#    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
#
    # Fetch Australian mirrors, uncomment them, and rank by speed
#    curl -s "https://archlinux.org/mirrorlist/?country=AU&protocol=http&protocol=https&ip_version=4" | 
#        sed -e 's/^#Server/Server/' -e '/^#/d' > /etc/pacman.d/mirrorlist
#
#    # Optionally rank mirrors by speed
#    if command -v rankmirrors > /dev/null; then
#        echo "Ranking the mirrors by speed..."
#        rankmirrors -n 5 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist
#    fi

#    echo "Mirrors setup complete!"
#}

	echo "pacman.conf set up.  running \`pacstrap'."

	# install core packages
	pacstrap -K /mnt base linux linux-firmware grub linux-headers sof-firmware btrfs-progs

	# copy our pacman config over
	cp /etc/pacman.conf /mnt/etc/pacman.conf

	# make an fstab
	genfstab /mnt >> /mnt/etc/fstab

	# set the timezone
	ln -sf /usr/share/zoneinfo/Australia/Adelaide /mnt/etc/localtime
	
	# set the clock
	arch-chroot /mnt hwclock --systohc

	# set up locale.gen
	sed 's/#en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/' -i /mnt/etc/locale.gen
	sed 's/#en_AU ISO-8859-1/en_AU ISO-8859-1/' -i /mnt/etc/locale.gen

	# generate the locales
	arch-chroot /mnt locale-gen

	# set up the locale config
	echo 'LANG=en_AU.UTF-8' > /mnt/etc/locale.conf


	# set the system hostname
	
	if [ "$hostname" = "" ]; then
		echo -n "Enter the hostname mate: "; read -r hostname
	fi
	echo "$hostname" > /mnt/etc/hostname

	# disable fallback initramfs
	sed "s/PRESETS=\('default' 'fallback'\)'/PRESETS='default'/" -i /mnt/etc/mkinitcpio.d/linux.preset

	# remove the fallback-related lines
	head -n -5 /mnt/etc/mkinitcpio.d/linux.preset > tmp
	mv tmp /mnt/etc/mkinitcpio.d/linux.preset

	# remove old initramfs's
	rm /mnt/boot/init*

	# rebuild the new, only default initramfs
	arch-chroot /mnt mkinitcpio -P

	echo "Set the root password"
	until arch-chroot /mnt passwd; do
		echo "Idiot, setup your root password."
	done

	echo "Installing GRUB to the disk of the RootFS."
	if [ "$uefi" = "true" ]; then
		echo "installing efibootmgr"
		arch-chroot /mnt pacman -S --noconfirm --needed efibootmgr
		echo "installing grub"
		if ! arch-chroot /mnt grub-install --efi-directory=/boot/efi; then
			echo "ERROR: grub-install failed! Womp Womp. Well you gotta exit script and see what ur skill issue is."
			sleep 30
		fi

	else
		arch-chroot /mnt grub-install $(partToDisk "$rootfs")
	fi
	sed 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/' -i /mnt/etc/default/grub
	sed 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet net.ifnames=0 biosdevname=0"/' -i /mnt/etc/default/grub
			
	arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

	arch-chroot /mnt pacman -S networkmanager --noconfirm --needed

	echo "Enabling NetworkManager and disabling systemd-networkd and resolved."
	arch-chroot /mnt systemctl disable systemd-networkd
	arch-chroot /mnt systemctl disable systemd-resolved
	arch-chroot /mnt systemctl enable NetworkManager

	echo "Setting up install script to start after this is finished."
	cp "$ourself" /mnt/autosetup.sh

	# just in case
	chmod +x /mnt/autosetup.sh

	cat << EOF > /mnt/etc/systemd/system/autosetup.service
[Service]
User=root
ExecStart=/autosetup.sh --rm

[Install]
WantedBy=default.target
EOF
	until [ "$autostart" = "y" ] || [ "$autostart" = "n" ]; do
		echo -n "If you will not have networking by default on boot (Wi-Fi), it would be unwise to start the remainder of the setup automatically. Would you like it to start automatically after reboot?  (y/n)"
		read -r autostart
	done
	
	if [ "$autostart" = "y" ]; then
		arch-chroot /mnt systemctl enable autosetup
	fi

	echo "Rebooting!"
	echo "Once restarted there will be a script that will run, DON'T interupt it until finished!"
	sleep 3
	reboot
}



###########################################
#                                         #
#   I N S T A L L E D   O S   S E T U P   #
#                                         #
###########################################


# This is reachable via the variable call
# shellcheck disable=SC2317
#desktopSetup() {
	pacman -S --noconfirm --needed sudo base-devel \
	pipewire pipewire-pulse pavucontrol
	
	echo "Adding user & sudo setup"
	
	if ! grep sudo /etc/group; then
		groupadd -r sudo
	fi
	
	sed -i 's/# %sudo	ALL=(ALL:ALL) ALL/%sudo	ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers

	if ! [ -d /home/atops ] || [ "$(su - atops -c groups 2>/dev/null | grep users | grep sudo | grep video | grep render)" == "" ]; then
		useradd -m atops -c Atops -G users,sudo,video,render
	fi
	echo "Enter the password for the new user"
	passwd atops

	echo "Running dotfiles setup"
	su - atops -c "mkdir -p src"
	chsh -s /bin/zsh atops
	
	if ! [ -d /home/atops/src/dotfiles ]; then
		su - atops -c "git clone https://github.com/techflashYT/dotfiles src/dotfiles"
	else
		su - atops -c "cd src/dotfiles; git pull"
	fi
	su - atops -c "cd src/dotfiles; ./install.sh"


	echo "Adding autologin to getty config"
	mkdir -p /etc/systemd/system/getty@tty1.service.d
	cat << EOF > /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\\\u' --noclear --autologin atops %I \$TERM
EOF
#}

# shellcheck disable=SC2317
mainSetup() {
	export TERM=linux
	echo "Checking networking config..."
	echo "fix networking config?"

	echo "No DNS set up.  Go fix it yourself"
	sleep 2
	nmtui
	echo "Restarting NetworkManager"
	systemctl restart NetworkManager

	echo -e "\n\e[0mInstalling..."
	if [ "$(id -u)" != "0" ]; then
		echo -e "\e[31mERROR: You must be root to run this script"
		exit 1
	fi

#	until [ "$setuptype" = "desktop" ] || [ "$setuptype" = "server" ]; do
#		echo -n "Setup type?  \"desktop\" or \"server\": "; read -r setuptype
#	done
	echo "Installing packages..."
	pacman -S --needed --noconfirm git rsync htop
#	"${setuptype}"Setup

	echo "DONE!  Restarting getty in 5 seconds!"
	sleep 5

	systemctl disable autosetup
	systemctl daemon-reload
	systemctl enable --now getty@tty1

	if [ "$1" = "--rm" ]; then
		rm "$ourself"
	fi
	exit 0
}

if [ "$isArchISO" = "true" ]; then
	installerSetup
	exit 0
fi

mainSetup "$1"
exit 0
