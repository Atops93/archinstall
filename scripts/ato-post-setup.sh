git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd
sudo pacman -Syu xorg-xinit xorg-server firefox curl

echo "1. Clone my dwm & use startx in terminal?"
echo "2. Install plasma?


IF - 1. git clone https://github.com/atops93/ato-dwm
IF - 2. sudo pacman -Syu plasma-desktop