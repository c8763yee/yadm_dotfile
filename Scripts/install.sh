#!/bin/bash

: <<COMMENT
This script is used to install the required packages for yadm bootstrap

Available distro: Arch, Debian, Fedora, Ubuntu
Package:
- yadm
- git
- curl
- zsh
- neovim
- wget
- tmux
- vim plugins required package

Plugin
- oh-my-zsh
- zsh-autosuggestions
- zsh-syntax-highlighting
- zsh-completions
- powerlevel10k
- linux_config
- oh-my-tmux
COMMENT

PACKAGES=(
	"zsh"
	"git"
	"curl"
	"neovim"
	"wget"
	"tmux"
	"fzf"
	"ripgrep"
	"clang"
	"gcc"
	"nodejs"
	"npm"
	"luarocks"
	"yarn"
	"s-tui"
	"pre-commit"
)

function install_yay(){
	sudo pacman -S --noconfirm base-devel
	git clone https://aur.archlinux.org/yay.git
	pushd yay
	makepkg -si --noconfirm
	popd
}

function install_required_packages() {
	distro=$(cat /etc/os-release | grep -w "ID" | cut -d "=" -f 2 | tr -d '"')
	case $distro in
	"arch")
		sudo pacman -Syu --noconfirm
		sudo pacman -S --noconfirm --needed ${PACKAGES[@]}

		# Extra packages
		sudo pacman -S --noconfirm --needed lua51 rustup cargo rust-analyzer tree-sitter{,-cli} \
			hyprland hyprpaper swaylock waybar nwg-{look,displays,dock-hyprland}\
			gnome-keyring fd
		rustup install stable
		;;
    "msys2")
		pacman -Syu --noconfirm
		pacman -S --noconfirm ${PACKAGES[@]}
        ;;
	"debian" | "ubuntu")
		sudo apt update
		sudo apt install -y ${PACKAGES[@]}
		sudo apt install -y fd-find
		;;
	"fedora")
		sudo dnf update -y
		sudo dnf install -y ${PACKAGES[@]}
		;;
	*)
		echo "Unsupported distro"
		exit 1
		;;
	esac
}

function install_oh_my_tmux(){
	# install in $XDG_CONFIG_HOME/tmux
	if [[ -f $XDG_CONFIG_HOME/tmux/.tmux.conf ]]; then
		echo "Oh My Tmux is already installed."
		return
	fi
	echo "Installing Oh My Tmux..."
	rm -rf .tmux
	git clone https://github.com/gpakosz/.tmux.git
	mkdir -p $XDG_CONFIG_HOME/tmux
	ln -s $PWD/.tmux/.tmux.conf $XDG_CONFIG_HOME/tmux/.tmux.conf
}

function setup_zsh() {
	# Change default shell to zsh
	if [[ $SHELL != *"zsh"* ]]; then
		chsh -s $(which zsh)
	fi
}

function move_config() {
	ln -s $HOME/Config/zsh $XDG_CONFIG_HOME
	ln -s $HOME/Config/nvim $XDG_CONFIG_HOME
	ln -s $HOME/Config/tmux/.tmux.conf.local $XDG_CONFIG_HOME/tmux/.tmux.conf.local
	ln -s $HOME/Config/hypr $XDG_CONFIG_HOME
	ln -s $HOME/Config/waybar $XDG_CONFIG_HOME
	ln -s $HOME/Config/gdb/.gdbinit $HOME/.gdbinit
}

function main() {
	install_required_packages
	install_oh_my_tmux
	setup_zsh
	install_yay
	move_config
}

main
echo "Done"
