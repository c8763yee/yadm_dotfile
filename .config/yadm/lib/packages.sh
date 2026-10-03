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
	awk -v distro="$DISTRO" '
		FNR == NR {
			line = $0
			if (line ~ /^[[:space:]]*#/ || line ~ /^[[:space:]]*$/)
				next
			if (line !~ /^[[:space:]]/ && line ~ /:[[:space:]]*$/) {
				current = line
				sub(/:[[:space:]]*$/, "", current)
				next
			}
			if (current != "" && line ~ /^[[:space:]]+/) {
				sub(/^[[:space:]]+/, "", line)
				sep = index(line, ":")
				if (!sep)
					next
				key = substr(line, 1, sep - 1)
				value = substr(line, sep + 1)
				gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
				gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
				if (key == distro)
					alias[current] = value
			}
			next
		}
		{
			pkg = $0
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", pkg)
			if (pkg == "" || pkg ~ /^#/)
				next
			value = (pkg in alias) ? alias[pkg] : pkg
			if (value != "" && value != "~")
				print value
		}
	' "$PACKAGES_DIR/aliases.yaml" "$pkg_file"
}

install_packages() {
	local pkg_file="$1"
	local -a pkgs
	mapfile -t pkgs < <(resolve_packages "$pkg_file")
	[[ ${#pkgs[@]} -gt 0 ]] && pkg_install "${pkgs[@]}"
}

install_yay() {
	command -v yay >/dev/null 2>&1 && return 0
	sudo pacman -S --noconfirm --needed base-devel
	rm -rf /tmp/yay
	git clone https://aur.archlinux.org/yay.git /tmp/yay
	pushd /tmp/yay || return 1
	makepkg -si --noconfirm
	popd || return 1
}
