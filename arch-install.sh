#!/bin/bash
set -euo pipefail

usage() { echo "Usage: $0 [-lbx]" 1>&2; exit 1; }

laptop=0
bios=0
x86=0

while getopts lbx o; do
	case "${o}" in
		l)
			laptop=1
			;;
		b)
			bios=1
			;;
		x)
			x86=1
			;;
		?)
			usage
			;;
	esac
done

# Test internet connection
ping -c 3 archlinux.org

lsblk
echo ">> What disk do you want to format?"
read disk
echo ">> Create the following partitions:"
if [ $bios = 0 ]; then
	echo ">>     - /efi   'EFI system partition' >512 MB"
fi
echo ">>     - [SWAP] 'Linux swap'		  >4 GB"
echo ">>     - /      'Linux'                Remainder of the device"
echo ">> Press any key to continue..."
read
cfdisk $disk
echo ">> Give partition ending for / ($disk<this>):"
read root
echo ">> Give partition ending for swap ($disk<this>):"
read swap
if [ $bios = 0 ]; then
	echo ">> Give partition ending for /efi ($disk<this>):"
	read efi
fi

echo ">> Formating and mounting partitions..."
mkfs.ext4 $disk$root
mount $disk$root /mnt
if [ $bios = 0 ]; then
	mkfs.fat -F 32 $disk$efi
	mount --mkdir $disk$efi /mnt/boot
fi
mkswap $disk$swap
swapon $disk$swap

echo ">> Running reflector..."
reflector --save /etc/pacman.d/mirrorlist --country Poland,Germany --protocol https --latest 10 --sort rate

echo ">> Runnning pacstrap..."
pacstrap -K /mnt base linux linux-firmware

echo ">> Running genfstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo ">> Copying mirrorlist..."
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

chrootfunc () {
	set -euo pipefail
	echo ">> Give time zone (Region/City): "
	read timezone
	ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime

	echo ">> Running hwclock..."
	hwclock --systohc

	echo ">> Setting up locale..."
	echo "KEYMAP=pl" > /etc/vconsole.conf
	echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
	echo "LANG=en_US.UTF-8" > /etc/locale.conf
	locale-gen

	echo ">> Give hostname for this pc: "
	read host
	echo "$host" > /etc/hostname

	echo ">> Give username: "
	read username
	useradd -m $username
	passwd $username
	usermod -aG wheel $username

	echo ">> Configuring pacman..."
	echo "[options]
	HoldPkg = pacman glibc
	Architecture = auto

	Color
	ILoveCandy
	CheckSpace
	ParallelDownloads = 5
	DownloadUser = alpm

	SigLevel = Required DatabaseOptional
	LocalFileSigLevel = Optional

	[core]
	Include = /etc/pacman.d/mirrorlist

	[extra]
	Include = /etc/pacman.d/mirrorlist

	[community]
	Include = /etc/pacman.d/mirrorlist

	[multilib]
	Include = /etc/pacman.d/mirrorlist" > /etc/pacman.conf
	pacman -Sy

	echo ">> Setting up network..."
	if [ $laptop = 1 ]; then
		pacman --needed --noconfirm -S iwd
		systemctl enable iwd
	fi
	pacman --needed --noconfirm -S dhcpcd
	systemctl enable dhcpcd
	systemctl enable systemd-timesyncd
	systemctl enable systemd-networkd
	systemctl enable systemd-resolved

	echo ">> Installing grub..."
	if [ $bios = 1 ]; then
		pacman --needed --noconfirm -S grub
		grub-install --target=i386-pc $disk
	else
		if [ $x86 = 1 ]; then
			pacman --needed --noconfirm -S grub efibootmgr
			grub-install --target=i386-efi --efi-directory=/boot --bootloader-id=GRUB
		else
			pacman --needed --noconfirm -S grub efibootmgr
			grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
		fi
	fi
	grub-mkconfig -o /boot/grub/grub.cfg

	echo ">> Installing yay..."
	pacman --needed --noconfirm -S base-devel git go
	echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers
	su -c "git clone https://aur.archlinux.org/yay.git /tmp/yay" $username
	cd /tmp/yay
	sudo -u $username makepkg
	pacman --noconfirm -U yay-*.pkg.tar.zst

	dotfilesfunc () {
		echo ">> Cloning dotfiles..."
		git clone --bare https://github.com/akinhet/dotfiles.git /home/$username/.cfg
		function config() {
			/usr/bin/git --git-dir=/home/$username/.cfg/ --work-tree=/home/$username/ $@
		}
		config pull
		config checkout
		if [ $? != 0 ]; then
			echo ">> Removing old files"
			config checkout 2>&1 | grep -E "\s+\." | awk {'print $1'} | xargs -I{} rm /home/$username/{}
		fi;
		config checkout
		config config status.showUntrackedFiles no
	}
	pacman --needed --noconfirm -S eza bat neovim pcmanfm nitrogen volumeicon blueman lxqt-policykit
	pacman --needed --noconfirm -S libxfixes libxi libxt
	sudo -u $username bash -c "
	git clone https://aur.archlinux.org/xbanish.git /tmp/xbanish
	cd /tmp/xbanish
	makepkg
	"
	pacman --noconfirm -U /tmp/xbanish/*.pkg.tar.zst
	sudo -u $username bash -c "
	$(declare -pf dotfilesfunc)
	$(declare -p username)
	dotfilesfunc
	"
	echo ">> Configuring neovim..."
	sudo -u $username bash -c "curl -fLo /home/$username/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
	sudo -u $username nvim -c PlugInstall -c qa

	echo ">> Configuring gtk..."
	pacman --needed --noconfirm -S papirus-icon-theme setconf
	sudo -u $username bash -c "
	git clone https://aur.archlinux.org/matcha-gtk-theme.git /tmp/matcha
	cd /tmp/matcha
	makepkg
	"
	pacman --noconfirm -U /tmp/matcha/*.pkg.tar.zst

	echo ">> Creating default directories..."
	pacman --needed --noconfirm -S xdg-user-dirs
	xdg-user-dirs-update

	echo ">> Installing Xorg..."
	pacman --needed --noconfirm -S xorg xf86-video-intel xorg-xinit ly
	systemctl enable ly

	echo ">> Installing pipewire..."
	pacman --needed --noconfirm -S pipewire pipewire-audio pipewire-alsa pipewire-pulse wireplumber pavucontrol
	sudo -u $username mkdir -p /home/$username/.config/systemd/user/default.target.wants
	ln -s /usr/lib/systemd/user/pipewire-pulse.service "/home/$username/.config/systemd/user/default.target.wants/pipewire-pulse.service"
	ln -s /usr/lib/systemd/user/pipewire-pulse.socket "/home/$username/.config/systemd/user/default.target.wants/pipewire-pulse.socket"

	echo ">> Installing dwm..."
	pacman --needed --noconfirm -S ttf-sourcecodepro-nerd maim xclip brightnessctl
	sudo -u $username bash -c "
	cd
	mkdir git
	git clone https://github.com/akinhet/dwm.git git/dwm
	cd git/dwm
	git checkout laptop
	make
	"
	cd /home/$username/git/dwm
	make install

	echo ">> Installing dmenu..."
	sudo -u $username bash -c "
	cd
	git clone https://github.com/akinhet/dmenu.git git/dmenu
	cd git/dmenu
	make
	"
	cd /home/$username/git/dmenu
	make install

	echo ">> Installing slstatus..."
	sudo -u $username bash -c "
	cd
	git clone https://github.com/akinhet/slstatus.git git/slstatus
	cd git/slstatus
	git checkout laptop
	make
	"
	cd /home/$username/git/slstatus
	make install

	echo ">> Installing other programs..."
	pacman --needed --noconfirm -S alacritty ttf-ubuntu-mono-nerd nsxiv nnn lazygit xarchiver gimp dunst qbittorrent vlc mpv
	pacman --needed --noconfirm -S electron34 debugedit
	sudo -u $username bash -c "
	git clone https://aur.archlinux.org/vesktop-bin.git /tmp/vesktop-bin
	cd /tmp/vesktop-bin
	makepkg
	"
	pacman --noconfirm -U /tmp/vesktop-bin/*.pkg.tar.zst
	pacman --needed --noconfirm -S curl freetype2 giflib gtest libjpeg-turbo libpng libwebp lua nodejs pixman sdl2-compat sdl2_image tinyxml2 zlib cmake git ninja patch
	sudo -u $username bash -c "
	git clone https://aur.archlinux.org/libresprite-bin.git /tmp/libresprite
	cd /tmp/libresprite
	makepkg
	"
	pacman --noconfirm -U /tmp/libresprite/*.pkg.tar.zst

	echo ">> Installing zen-browser..."
	pacman --needed --noconfirm -S gtk3 mailcap nss ttf-dejavu ffmpeg libnotify dbus-glib
	sudo -u $username bash -c "
	git clone https://aur.archlinux.org/zen-browser-bin.git /tmp/zen-browser-bin
	cd /tmp/zen-browser-bin
	makepkg
	"
	pacman --noconfirm -U /tmp/zen-browser-bin/*.pkg.tar.zst

	echo ">> Installing xlock..."
	pacman --needed --noconfirm -S xlockmore
	echo "[Unit]
	Description=Lock
	Before=sleep.target

	[Service]
	User=$username
	Environment=DISPLAY=:0
	ExecStart=/sbin/xlock -mode matrix

	[Install]
	WantedBy=sleep.target
	" > /etc/systemd/system/lock.service
	systemctl enable lock
}

echo ">> Chrooting into /mnt..."
arch-chroot /mnt bash -c "
$(declare -pf chrootfunc)
$(declare -p bios laptop disk x86)
chrootfunc
"

echo ">> You can safely reboot now."
