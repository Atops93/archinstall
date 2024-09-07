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
yay -S xorg-xinit xorg-server firefox wget curl lynx gcc glava thunar gvfs picom openssh flameshot alacritty btop htop qemu-full rofi dxvk-bin cava cmatrix-git

sudo echo "[chaotic-aur]" >> /etc/pacman.conf
sudo echo "Include = /etc/pacman.d/chaotic-mirrorlist" >> /etc/pacman.conf

####################################################################
#### I DID SAY AFTER ALL, THIS IS MY METHOD OF SETTING SHIT UP! ####
####################################################################

echo "1 Clone my dwm & use alacritty?"
echo "2 Install kde without display manager? They are bloat."
if [[1]] ; then
	sudo pacman -S libx11 libxft libxinerama && git clone https://github.com/atops93/ato-dwm && cd ato-dwm && cd dwm && sudo make clean install && ./install.sh
echo "3 Clone "
echo "4 Clone "
echo "5 Clone "










if [[1]] ; then
	git clone https://github.com/atops93/ato-dwm && cd ato-dwm && ./install.sh
if [[2]] ; then
	sudo pacman -S plasma-desktop
if [[3]] ; then





	echo "THE END"
	rm -rf ato-post-setup.sh
	exit
