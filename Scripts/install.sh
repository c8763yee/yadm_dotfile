#!/bin/bash

BASE_DIR="${1:-$HOME}"
SCRIPTS_DIR="$BASE_DIR/Scripts"
PACKAGES_DIR="$SCRIPTS_DIR/packages"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

. /etc/os-release
DISTRO="$ID"

pkg_update() {
    case "$DISTRO" in
        arch)                   sudo pacman -Syu --noconfirm ;;
        msys2)                  pacman -Syu --noconfirm ;;
        debian|ubuntu|raspbian) sudo apt update ;;
        fedora)                 sudo dnf update -y ;;
        *) echo "不支援的 distro: $DISTRO" && exit 1 ;;
    esac
}

pkg_install() {
    case "$DISTRO" in
        arch)                   sudo pacman -S --noconfirm --needed "$@" ;;
        msys2)                  pacman -S --noconfirm "$@" ;;
        debian|ubuntu|raspbian) sudo apt install -y "$@" ;;
        fedora)                 sudo dnf install -y "$@" ;;
    esac
}

# 一次 Python 呼叫解析整份套件清單，避免 N 次 subprocess
resolve_packages() {
    local pkg_file="$1"
    python3 - "$DISTRO" "$PACKAGES_DIR/aliases.yaml" < "$pkg_file" <<'PYEOF'
import sys, pathlib

distro = sys.argv[1]
aliases_file = pathlib.Path(sys.argv[2])

aliases = {}
current_pkg = None
for line in aliases_file.read_text().splitlines():
    line = line.rstrip()
    if not line.startswith(" ") and line.endswith(":"):
        current_pkg = line[:-1].strip()
        aliases[current_pkg] = {}
    elif current_pkg and ":" in line:
        key, _, val = line.strip().partition(":")
        aliases[current_pkg][key.strip()] = val.strip()

for line in sys.stdin:
    pkg = line.strip()
    if not pkg or pkg.startswith("#"):
        continue
    if pkg in aliases:
        resolved = aliases[pkg].get(distro, pkg)
        if resolved and resolved != "~":
            print(resolved)
    else:
        print(pkg)
PYEOF
}

install_packages() {
    local pkg_file="$1"
    local -a pkgs
    mapfile -t pkgs < <(resolve_packages "$pkg_file")
    [[ ${#pkgs[@]} -gt 0 ]] && pkg_install "${pkgs[@]}"
}

install_yay() {
    sudo pacman -S --noconfirm base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    pushd /tmp/yay || exit
    makepkg -si --noconfirm
    popd || exit
}

install_required_packages() {
    pkg_update
    install_packages "$PACKAGES_DIR/base.txt"

    case "$DISTRO" in
        arch)
            sudo systemctl enable --now cronie
            ;;
        fedora)
            sudo dnf --enablerepo=fedora-debuginfo,updates-debuginfo install kernel-debuginfo
            ;;
    esac
}

install_wm_packages() {
    local class="$1"
    local wm_txt="$PACKAGES_DIR/wm/${class,,}.txt"
    [[ ! -f "$wm_txt" ]] && return

    case "$class" in
        Hyprland)
            [[ "$DISTRO" != "arch" ]] && echo "Hyprland 僅支援 Arch Linux，跳過 WM 安裝" && return
            install_yay
            install_packages "$wm_txt"
            yay -S --noconfirm --needed $(grep -v '^#' "$PACKAGES_DIR/wm/hyprland-aur.txt")
            rustup install stable
            sudo cp /etc/xdg/menus/arch-applications.menu /etc/xdg/menus/applications.menu
            kbuildsycoca6 --noincremental
            ;;
        Kde)
            install_packages "$wm_txt"
            sudo systemctl enable sddm
            [[ "$DISTRO" == "arch" ]] && \
                sudo cp /etc/xdg/menus/arch-applications.menu /etc/xdg/menus/applications.menu && \
                kbuildsycoca6 --noincremental
            ;;
        Niri)
            [[ "$DISTRO" != "arch" ]] && echo "Niri 僅支援 Arch Linux，跳過 WM 安裝" && return
            install_yay
            install_packages "$wm_txt"
            yay -S --noconfirm --needed $(grep -v '^#' "$PACKAGES_DIR/wm/niri-aur.txt")
            sudo systemctl enable --now cronie
            ;;
    esac
}

install_oh_my_tmux() {
    ln -sf "$BASE_DIR/Config/tmux/tmux.conf" "$HOME/.tmux.conf"
    ln -sf "$BASE_DIR/Config/tmux/.tmux.conf.local" "$HOME/.tmux.conf.local"
    if [[ ! -d $HOME/.tmux/plugins/tpm ]]; then
        mkdir -p "$HOME/.tmux/plugins"
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    fi
}

setup_zsh() {
    [[ $SHELL != *zsh* ]] && chsh -s "$(which zsh)"
}

move_config() {
    local class="$1"

    ln -sf "$BASE_DIR/Config/zsh"              "$XDG_CONFIG_HOME"
    ln -sf "$BASE_DIR/Config/nvim"             "$XDG_CONFIG_HOME"
    ln -sf "$BASE_DIR/Config/fastfetch"        "$XDG_CONFIG_HOME"
    ln -sf "$BASE_DIR/Config/gdb/.gdbinit"     "$BASE_DIR/.gdbinit"
    ln -sf "$BASE_DIR/Config/git/.gitconfig"   "$HOME/.gitconfig"

    case "$class" in
        Hyprland)
            ln -sf "$BASE_DIR/Config/hypr"      "$XDG_CONFIG_HOME"
            ln -sf "$BASE_DIR/Config/waybar"    "$XDG_CONFIG_HOME"
            ln -sf "$BASE_DIR/Config/kitty"     "$XDG_CONFIG_HOME"
            ln -sf "$BASE_DIR/Config/awww"      "$XDG_CONFIG_HOME"
            ln -sf "$BASE_DIR/Config/swaylock"  "$XDG_CONFIG_HOME"
            ;;
        Niri)
            ln -sf "$BASE_DIR/Config/niri"      "$XDG_CONFIG_HOME"
            ln -sf "$BASE_DIR/Config/waybar"    "$XDG_CONFIG_HOME"
            ln -sf "$BASE_DIR/Config/foot"      "$XDG_CONFIG_HOME"
            ln -sf "$BASE_DIR/Config/swaylock"  "$XDG_CONFIG_HOME"
            ;;
    esac
}

setup_claude_code() {
    curl -fsSL https://claude.ai/install.sh | bash

    git clone https://github.com/sysprog21/zhtw-mcp.git
    pushd zhtw-mcp || exit
    make
    claude mcp add --scope user zhtw-mcp -- target/release/zhtw-mcp
    popd || exit

    git clone -b main https://github.com/kingkongshot/Pensieve.git .claude/skills/pensieve
    bash .claude/skills/pensieve/.src/scripts/init-project-data.sh
    claude plugin marketplace add kingkongshot/Pensieve#claude-plugin
    claude plugin install pensieve@kingkongshot-marketplace --scope user
    cp -r "$BASE_DIR/Config/claude/"* ~/.claude
}

apply_crontab() {
    crontab <(cat /dev/null)
    crontab "$BASE_DIR/Config/crontab"
}

check_dotfile() {
    BASE_DIR="${1:-$HOME}"
    if [[ ! -d $BASE_DIR/Config ]]; then
        BASE_DIR=$HOME/.dotfile
        git clone https://github.com/c8763yee/yadm_dotfile "$BASE_DIR"
        git -C "$BASE_DIR" submodule update --init
    fi
    yadm submodule update --init
}

main() {
    local class
    class=$(yadm config local.class 2>/dev/null || echo "Base")

    check_dotfile "$1"
    setup_claude_code
    install_required_packages
    install_wm_packages "$class"
    install_oh_my_tmux
    setup_zsh
    move_config "$class"
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

if is_sourced; then
    echo "$0 sourced"
else
    main "$@"
fi
echo Done
