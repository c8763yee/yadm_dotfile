#!/bin/bash

PACKAGES=(
	zsh
	git
	curl
	neovim
	wget
	bc
	bear
	tmux
	fzf
	ripgrep
	clang
	gcc
	nodejs
	npm
	luarocks
	s-tui
	pre-commit
	msmtp
	mutt
	fastfetch

	# kernel build (common name across distros)
	bison
	flex
	cpio
	perl
	make
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
		install_yay
		$BASE_DIR/Scripts/extra/arch.sh
		;;
	debian | ubuntu)
		$BASE_DIR/Scripts/extra/debian.sh
		;;
	fedora)
		$BASE_DIR/Scripts/extra/fedora.sh
		;;
	*)
		echo "No extra packages for $distro"
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
	ln -sf $BASE_DIR/Config/swaylock $XDG_CONFIG_HOME

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

	# install skills/mcps

	## zhtw-mcp
	git clone https://github.com/sysprog21/zhtw-mcp.git
	pushd zhtw-mcp
	make
	claude mcp add zhtw-mcp -- target/release/zhtw-mcp
	popd

	## pensieve
	# 1. Install skill
	git clone -b main https://github.com/kingkongshot/Pensieve.git .claude/skills/pensieve

	# 2. Initialize (create user data directories, seed default content, generate SKILL.md router file)
	bash .claude/skills/pensieve/.src/scripts/init-project-data.sh

	# 3. Install Claude hooks (required for Claude Code users, skip for other clients)
	claude plugin marketplace add kingkongshot/Pensieve#claude-plugin
	claude plugin install pensieve@kingkongshot-marketplace --scope project

}

function apply_crontab() {
	# reset and apply from crontab file
	crontab <(cat /dev/null)
	crontab $BASE_DIR/Config/crontab
}

function main() {
	check_dotfile
	setup_claude_code
	install_required_packages
	install_extra_package
	install_oh_my_tmux
	setup_zsh
	move_config
	apply_crontab
}

is_sourced() {
	if [ -n "$BASH_VERSION" ]; then
		[[ "${BASH_SOURCE[0]}" != "${0}" ]]
	elif [ -n "$ZSH_VERSION" ]; then
		[[ "$zsh_eval_context" == *file* ]]
	else
		[[ "$0" == *"sh" ]]
	fi
}

# 2. 執行主程式前判斷
if is_sourced; then
	echo "$0 sourced"
else
	main
fi
echo Done
