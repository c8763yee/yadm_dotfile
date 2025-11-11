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
	cd yay
	makepkg -si --noconfirm
}

function install_required_packages() {
	distro=$(cat /etc/os-release | grep -w "ID" | cut -d "=" -f 2 | tr -d '"')
	case $distro in
	"arch")
		sudo pacman -Syu --noconfirm
		sudo pacman -S --noconfirm ${PACKAGES[@]}

		# Extra packages
		install_yay
		sudo pacman -S --noconfirm lua51 rustup cargo rust-analyzer tree-sitter{,-cli} \
			hyprland hyprpaper swaylock waybar nwg-{look,displays,dock-hyprland}\
			gnome-keyring
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
	git clone https://github.com/gpakosz/.tmux.git
	mkdir -p $XDG_CONFIG_HOME/tmux
	ln -s .tmux/.tmux.conf $XDG_CONFIG_HOME/tmux/.tmux.conf
}

function setup_zsh() {
	# Change default shell to zsh
	if [[ $SHELL != *"zsh"* ]]; then
		chsh -s $(which zsh)
	fi
}

function move_config() {
	ln -s Config/zsh $HOME/.config/zsh
	ln -s Config/nvim $HOME/.config/nvim
	ln -s Config/tmux/.tmux.conf $XDG_CONFIG_HOME/tmux/.tmux.conf
	ln -s Config/gdb/.gdbinit $HOME/.gdbinit
	ln -s Config/hypr $XDG_CONFIG_HOME/hypr
	ln -s Config/waybar $XDG_CONFIG_HOME/waybar
}

function main() {
	install_required_packages
	install_oh_my_tmux
	setup_zsh
	move_config
}

main
echo "Done"
