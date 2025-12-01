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
	zsh
	git
	curl
	neovim
	wget
	tmux
	fzf
	ripgrep
	clang
	gcc
	nodejs
	npm
	luarocks
	yarn
	s-tui
	pre-commit
)

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
function install_yay() {
	sudo pacman -S --noconfirm base-devel
	git clone https://aur.archlinux.org/yay.git /tmp/yay
	pushd /tmp/yay || exit
	makepkg -si --noconfirm
	popd || exit
}

function install_required_packages() {
	distro=$(cat /etc/os-release | grep -w ID | cut -d = -f 2 | tr -d '')
	case $distro in
	arch)
		sudo pacman -Syu --noconfirm
		sudo pacman -S --noconfirm --needed ${PACKAGES[@]}

		;;
	msys2)
		pacman -Syu --noconfirm
		pacman -S --noconfirm ${PACKAGES[@]}
		;;
	debian | ubuntu)
		sudo apt update
		sudo apt install -y ${PACKAGES[@]}
		sudo apt install -y fd-find
		;;
	fedora)
		sudo dnf update -y
		sudo dnf install -y ${PACKAGES[@]}
		;;
	*)
		echo Unsupported distro
		exit 1
		;;
	esac
}

function install_extra_package() {
	case $distro in
	arch)
		sudo pacman -S --noconfirm --needed lua51 rustup cargo rust-analyzer tree-sitter{,-cli} \
			hyprland swaylock waybar nwg-{look,displays,dock-hyprland} gnome-keyring fd fastfetch wofi
		rustup install stable
		install_yay

		yay -S --noconfirm --needed awww-git
		;;
	msys2) ;;
	debian | ubuntu)
		sudo apt install -y fd-find
		;;
	fedora) ;;
	*)
		echo Unsupported distro
		exit 1
		;;
	esac
}
function install_oh_my_tmux() {
	# install in $XDG_CONFIG_HOME/tmux
	ln -sf $BASE_DIR/Config/tmux/tmux.conf $HOME/.tmux.conf
	ln -sf $BASE_DIR/Config/tmux/.tmux.conf.local $HOME/.tmux.conf.local

	if [[ ! -d $HOME/.tmux/plugins/tpm ]]; then
		mkdir -p $HOME/.tmux/plugins
		git clone https://github.com/tmux-plugins/tpm $HOME/.tmux/plugins/tpm
	fi
}

function setup_zsh() {
	# Change default shell to zsh
	if [[ $SHELL != *zsh* ]]; then
		chsh -s $(which zsh)
	fi
}

function move_config() {
	ln -sf $BASE_DIR/Config/zsh $XDG_CONFIG_HOME
	ln -sf $BASE_DIR/Config/nvim $XDG_CONFIG_HOME
	ln -sf $BASE_DIR/Config/hypr $XDG_CONFIG_HOME
	ln -sf $BASE_DIR/Config/waybar $XDG_CONFIG_HOME
	ln -sf $BASE_DIR/Config/kitty $XDG_CONFIG_HOME
	ln -sf $BASE_DIR/Config/fastfetch $XDG_CONFIG_HOME
	ln -sf $BASE_DIR/Config/awww $XDG_CONFIG_HOME

	ln -sf $BASE_DIR/Config/gdb/.gdbinit $BASE_DIR/.gdbinit
	ln -sf $BASE_DIR/Config/git/.gitconfig $HOME/.gitconfig
}

function check_dotfile() {
	BASE_DIR=${1:-$HOME} # $HOME is for yadm bootstrap
	if [[ ! -d $BASE_DIR/Config ]]; then
		BASE_DIR=$HOME/.dotfile
		git clone https://github.com/c8763yee/yadm_dotfile $BASE_DIR
		git -C $BASE_DIR submodule update --init
	fi
	yadm submodule update --init
}

function setup_claude_code() {
	curl -fsSL https://claude.ai/install.sh | bash
	cp -r $BASE_DIR/Config/prompts/prompts/claude/agents $BASE_DIR/Config/prompts/prompts/claude/CLAUDE.md $BASE_DIR/Config/prompts/prompts/claude/commands $HOME/.claude
}

function main() {
	check_dotfile
	setup_claude_code
	install_required_packages
	install_extra_package
	install_oh_my_tmux
	setup_zsh
	move_config
}

main
echo Done
