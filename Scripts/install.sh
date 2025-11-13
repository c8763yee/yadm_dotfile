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
	mkdir -p $XDG_CONFIG_HOME/tmux
	ln -s $BASE_DIR/Config/tmux.conf $XDG_CONFIG_HOME/tmux/.tmux.conf
	ln -s $BASE_DIR/Config/tmux/.tmux.conf.local $XDG_CONFIG_HOME/tmux/.tmux.conf.local
}

function setup_zsh() {
	# Change default shell to zsh
	if [[ $SHELL != *"zsh"* ]]; then
		chsh -s $(which zsh)
	fi
}

function move_config() {
	ln -s $BASE_DIR/Config/zsh $XDG_CONFIG_HOME
	ln -s $BASE_DIR/Config/nvim $XDG_CONFIG_HOME
	ln -s $BASE_DIR/Config/hypr $XDG_CONFIG_HOME
	ln -s $BASE_DIR/Config/waybar $XDG_CONFIG_HOME
	ln -s $BASE_DIR/Config/gdb/.gdbinit $BASE_DIR/.gdbinit
	
	ln -s $BASE_DIR/Config/git/.gitconfig ~/.gitconfig
}

function check_dotfile() {
	BASE_DIR=${1:-$HOME} # $HOME is for yadm bootstrap
	if [[ ! -d $BASE_DIR/Config ]]; then
		git clone https://github.com/c8763yee/yadm_dotfile .dotfile
		BASE_DIR=${PWD}/.dotfile
	fi
}
function main() {
	check_dotfile
	install_required_packages
	install_oh_my_tmux
	setup_zsh
	install_yay
	move_config
}

main
echo "Done"
