echo "Make sure to connect to the internet on setup again so pkgs can be installed."
echo "(1) I'm Connected to the Net bozo"
echo "(2) Exit by ctrl + c or ctrl + D & connect to wifi then open script again."

###############################
#	  TESTING CONNECTION	  #
###############################
ping archlinux.org

git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd
yay -S firefox wget curl lynx gcc repo rsync glava thunar gvfs picom openssh flameshot alacritty btop htop qemu-full edk2-ovmf rofi dxvk-bin cava cmatrix-git jellyfin nginx cmus dosfstools mtools cmake pipewire lib32-pipewire wireplumber fastfetch meson musl p7zip unzip 

#sudo echo "[chaotic-aur]" >> /etc/pacman.conf
#sudo echo "Include = /etc/pacman.d/chaotic-mirrorlist" >> /etc/pacman.conf

##################################################################
####  I DID SAY AT THE START THIS IS MY METHOD OF SETTING UP  ####
##################################################################

echo "(1) Clone my dwm & use alacritty?" READ dwm
echo "(2) Install kde without display manager & use startx instead?"
echo "(3) Clone "
echo "(4) Clone "
echo "(5) Clone "










if [[1]] ; then
	sudo pacman -S xorg xorg-server xorg-xinit && git clone https://github.com/atops93/ato-dwm && cd ato-dwm && chmod +x install.sh && ./install.sh
if [[2]] ; then
	sudo pacman -S plasma-desktop && 
if [[3]] ; then





	echo "THE END"
	rm -rf ato-post-setup.sh
	exit
