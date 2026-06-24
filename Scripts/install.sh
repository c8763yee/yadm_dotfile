#!/bin/bash

BASE_DIR="${1:-$HOME}"
SCRIPTS_DIR="$BASE_DIR/Scripts"
PACKAGES_DIR="$SCRIPTS_DIR/packages"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

. /etc/os-release
DISTRO="$ID"

pkg_update() {
	case "$DISTRO" in
	arch) sudo pacman -Syu --noconfirm ;;
	msys2) pacman -Syu --noconfirm ;;
	debian | ubuntu | raspbian) sudo apt update ;;
	fedora) sudo dnf update -y ;;
	*) echo "不支援的 distro: $DISTRO" && exit 1 ;;
	esac
}

pkg_install() {
	case "$DISTRO" in
	arch) sudo pacman -S --noconfirm --needed "$@" ;;
	msys2) pacman -S --noconfirm "$@" ;;
	debian | ubuntu | raspbian) sudo apt install -y "$@" ;;
	fedora) sudo dnf install -y "$@" ;;
	esac
}

# 一次 Python 呼叫解析整份套件清單，避免 N 次 subprocess
resolve_packages() {
	local pkg_file="$1"
	python3 - "$DISTRO" "$PACKAGES_DIR/aliases.yaml" "$pkg_file" <<'PYEOF'
import sys, pathlib

distro = sys.argv[1]
aliases_file = pathlib.Path(sys.argv[2])
pkg_file = pathlib.Path(sys.argv[3])

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

for line in pkg_file.read_text().splitlines():
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

install_hyde() {
	local hyde_dir="$BASE_DIR/HyDE"
	if [[ ! -d $hyde_dir ]]; then
		# 首次：完整安裝 (預設等同 -irs：install + restore + service)
		git clone --depth 1 https://github.com/HyDE-Project/HyDE "$hyde_dir"
		bash "$hyde_dir/Scripts/install.sh"
	else
		# 更新：拉取最新並只還原設定 (-r restore)
		git -C "$hyde_dir" pull
		bash "$hyde_dir/Scripts/install.sh" -r
	fi
}

# 把 custom/powerdraw 注入每個 waybar layout 的最右欄位 (冪等)
inject_waybar_powerdraw() {
	python3 - "$XDG_CONFIG_HOME/waybar/layouts" "$HOME/.local/share/waybar/layouts" <<'PYEOF'
import sys, os, json

MODULE = "custom/powerdraw"

def strip_jsonc(text):
    out = []
    i, n = 0, len(text)
    in_str = False
    esc = False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
            i += 1
        elif c == "/" and i + 1 < n and text[i + 1] == "/":
            i += 2
            while i < n and text[i] != "\n":
                i += 1
        elif c == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)

def drop_trailing_commas(text):
    res = []
    in_str = False
    esc = False
    for idx, c in enumerate(text):
        if in_str:
            res.append(c)
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            continue
        if c == '"':
            in_str = True
            res.append(c)
        elif c == ",":
            j = idx + 1
            while j < len(text) and text[j] in " \t\r\n":
                j += 1
            if j < len(text) and text[j] in "}]":
                continue  # 丟掉這個 trailing comma
            res.append(c)
        else:
            res.append(c)
    return "".join(res)

def target_list(data):
    """回傳該放 powerdraw 的 list (最右 group 的 modules，或 modules-right 本身)。"""
    mr = data.get("modules-right")
    if not isinstance(mr, list):
        return None
    if not mr:
        return mr  # 空的 right 區段，直接放成唯一最右模組
    last = mr[-1]
    if isinstance(last, str) and last.startswith("group/"):
        grp = data.get(last)
        if isinstance(grp, dict) and isinstance(grp.get("modules"), list):
            return grp["modules"]
    return mr

for layout_dir in sys.argv[1:]:
    if not os.path.isdir(layout_dir):
        continue
    for root, _, files in os.walk(layout_dir):
        for fn in files:
            if not fn.endswith(".jsonc"):
                continue
            path = os.path.join(root, fn)
            try:
                raw = open(path, encoding="utf-8").read()
                data = json.loads(drop_trailing_commas(strip_jsonc(raw)))
            except Exception as e:
                print(f"skip {path}: {e}")
                continue
            tgt = target_list(data)
            if tgt is None or MODULE in tgt:
                continue
            tgt.append(MODULE)
            with open(path, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
                f.write("\n")
            print(f"injected {MODULE} -> {path}")
PYEOF
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
		install_hyde
		;;
	Kde)
		install_packages "$wm_txt"
		sudo systemctl enable sddm
		[[ "$DISTRO" == "arch" ]] &&
			sudo cp /etc/xdg/menus/arch-applications.menu /etc/xdg/menus/applications.menu &&
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

	# HyDE 的 00-hyde.zsh 是其 conf.d 載入鏈的明確標記；其餘 DE 使用
	# repository 的完整 Zsh 設定。
	if [[ -f "$XDG_CONFIG_HOME/zsh/conf.d/00-hyde.zsh" ]]; then
		ln -sf "$BASE_DIR/Config/zsh/.zshenv" "$XDG_CONFIG_HOME/zsh/conf.d/custom.zsh"
		[[ -f "$XDG_CONFIG_HOME/zsh/plugin.zsh" ]] && sed -i 's/return 1//' "$XDG_CONFIG_HOME/zsh/plugin.zsh"
	else
		ln -sf "$BASE_DIR/Config/zsh" "$XDG_CONFIG_HOME"
	fi
}

move_config() {
	local class="$1"

	ln -sf "$BASE_DIR/Config/nvim" "$XDG_CONFIG_HOME"
	ln -sf "$BASE_DIR/Config/gdb/.gdbinit" "$BASE_DIR/.gdbinit"
	ln -sf "$BASE_DIR/Config/git/.gitconfig" "$HOME/.gitconfig"

	if [[ $class == "Hyprland" ]]; then
		# waybar: 自訂 powerdraw 模組 + 腳本，並注入各 layout 最右欄位
		mkdir -p "$XDG_CONFIG_HOME/waybar/modules" "$XDG_CONFIG_HOME/waybar/scripts"
		ln -sf "$BASE_DIR/Config/waybar/custom-powerdraw.jsonc" "$XDG_CONFIG_HOME/waybar/modules/"
		ln -sf "$BASE_DIR/Config/waybar/scripts/get_power.sh" "$XDG_CONFIG_HOME/waybar/scripts/"
		ln -sf "$BASE_DIR/Config/waybar/scripts/power_daemon.sh" "$XDG_CONFIG_HOME/waybar/scripts/"
		inject_waybar_powerdraw

		ln -sf "$BASE_DIR/Config/hypr/userprefs.conf" "$XDG_CONFIG_HOME/hypr/userprefs.conf"
		ln -sf "$BASE_DIR/Config/hypr/custom" "$XDG_CONFIG_HOME/hypr"
	else
		if [[ $class == "Niri" ]]; then
			ln -sf "$BASE_DIR/Config/niri" "$XDG_CONFIG_HOME"
			ln -sf "$BASE_DIR/Config/waybar" "$XDG_CONFIG_HOME"
			ln -sf "$BASE_DIR/Config/foot" "$XDG_CONFIG_HOME"
			ln -sf "$BASE_DIR/Config/swaylock" "$XDG_CONFIG_HOME"
		fi

		ln -sf "$BASE_DIR/Config/fastfetch" "$XDG_CONFIG_HOME"
	fi
}

setup_claude_code() {
	curl -fsSL https://claude.ai/install.sh | bash
	curl -fsSL https://bun.sh/install | bash

	[[ ! -d zhtw-mcp ]] && git clone https://github.com/sysprog21/zhtw-mcp.git || git -C zhtw-mcp pull
	pushd zhtw-mcp || exit
	make
	claude mcp add --scope user zhtw-mcp -- target/release/zhtw-mcp
	popd || exit

	ln -sf "$BASE_DIR/Config/claude/"* ~/.claude

	git clone -b main https://github.com/kingkongshot/Pensieve.git .claude/skills/pensieve
	bash .claude/skills/pensieve/.src/scripts/init-project-data.sh
	claude plugin marketplace add kingkongshot/Pensieve#claude-plugin
	claude plugin install pensieve@kingkongshot-marketplace --scope user
}

setup_codex() {
	mkdir -p "$HOME/.codex"
	ln -sf "$BASE_DIR/Config/codex/AGENTS.md" "$HOME/.codex/AGENTS.md"
}

apply_crontab() {
	local desired="$BASE_DIR/Config/crontab"
	local current merged
	local begin="# >>> dotfile managed crontab >>>"
	local end="# <<< dotfile managed crontab <<<"

	[[ -f $desired ]] || return
	current=$(mktemp) || return 1
	merged=$(mktemp) || {
		rm -f "$current"
		return 1
	}

	crontab -l 2>/dev/null >"$current" || :
	awk -v begin="$begin" -v end="$end" '
		NR == FNR { desired[$0] = 1; next }
		$0 == begin { managed = 1; next }
		managed && $0 == end { managed = 0; next }
		!managed && !desired[$0] { print }
	' "$desired" "$current" >"$merged"
	{
		cat "$merged"
		printf '%s\n' "$begin"
		cat "$desired"
		printf '%s\n' "$end"
	} | crontab -
	local status=${PIPESTATUS[1]}
	rm -f "$current" "$merged"
	return "$status"
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

move_exec() {
	mkdir -p $HOME/.local/bin

	cp -r $BASE_DIR/Exec/user/* $HOME/.local/bin
	sudo cp -r $BASE_DIR/Exec/root/* /usr/bin
}

# 安裝 systemd unit：Service/user -> 使用者層，Service/root -> 系統層，並 enable
install_services() {
	local user_dir="$BASE_DIR/Service/user"
	local root_dir="$BASE_DIR/Service/root"

	if compgen -G "$user_dir/*.service" >/dev/null 2>&1 ||
		compgen -G "$user_dir/*.timer" >/dev/null 2>&1 ||
		compgen -G "$user_dir/*.socket" >/dev/null 2>&1; then
		mkdir -p "$XDG_CONFIG_HOME/systemd/user"
		cp "$user_dir"/*.{service,timer,socket} "$XDG_CONFIG_HOME/systemd/user/" 2>/dev/null
		systemctl --user daemon-reload
		for unit in "$user_dir"/*.{service,timer,socket}; do
			[[ -e $unit ]] && systemctl --user enable --now "$(basename "$unit")"
		done
	fi

	if compgen -G "$root_dir/*.service" >/dev/null 2>&1 ||
		compgen -G "$root_dir/*.timer" >/dev/null 2>&1 ||
		compgen -G "$root_dir/*.socket" >/dev/null 2>&1; then
		sudo cp "$root_dir"/*.{service,timer,socket} /etc/systemd/system/ 2>/dev/null
		sudo systemctl daemon-reload
		for unit in "$root_dir"/*.{service,timer,socket}; do
			[[ -e $unit ]] && sudo systemctl enable --now "$(basename "$unit")"
		done
	fi
}
main() {
	local class
	class=$(yadm config local.class 2>/dev/null || echo "Base")

	check_dotfile "$1"
	setup_claude_code
	setup_codex
	install_required_packages
	install_wm_packages "$class"
	install_oh_my_tmux
	setup_zsh
	move_config "$class"
	apply_crontab
	move_exec
	install_services
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
