# Package-manager primitives shared by bootstrap stages.
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
	arch) sudo pacman -S --noconfirm --needed "$@" --overwrite "*";;
	msys2) pacman -S --noconfirm "$@" ;;
	debian | ubuntu | raspbian) sudo apt install -y "$@" ;;
	fedora) sudo dnf install -y --skip-unavailable "$@" ;;
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
