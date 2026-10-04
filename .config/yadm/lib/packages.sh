# Package-manager primitives shared by bootstrap stages.
configure_taiwan_mirror() {
	case "$DISTRO" in
	arch)
		# reflector itself must be installed from the bootstrap image's current
		# mirror before we can replace mirrorlist. Restrict generated entries to
		# HTTP(S); never select rsync/FTP mirrors.
		if ! command -v reflector >/dev/null 2>&1; then
			sudo pacman -Sy --noconfirm --needed reflector
		fi
		sudo reflector \
			--country Taiwan \
			--protocol http,https \
			--latest 20 \
			--sort rate \
			--save /etc/pacman.d/mirrorlist
		;;
	debian)
		local -a apt_sources=(
			/etc/apt/sources.list
			/etc/apt/sources.list.d/*.list
			/etc/apt/sources.list.d/*.sources
		)
		local file
		for file in "${apt_sources[@]}"; do
			[[ -f "$file" ]] || continue
			sudo sed -Ei \
				-e 's#https?://deb\.debian\.org/debian/?#https://mirror.twds.com.tw/debian/#g' \
				-e 's#https?://security\.debian\.org/debian-security/?#https://mirror.twds.com.tw/debian-security/#g' \
				"$file"
		done
		;;
	ubuntu)
		local -a apt_sources=(
			/etc/apt/sources.list
			/etc/apt/sources.list.d/*.list
			/etc/apt/sources.list.d/*.sources
		)
		local file
		for file in "${apt_sources[@]}"; do
			[[ -f "$file" ]] || continue
			sudo sed -Ei \
				-e 's#https?://([[:alnum:]-]+\.)?archive\.ubuntu\.com/ubuntu/?#https://tw.archive.ubuntu.com/ubuntu/#g' \
				-e 's#https?://security\.ubuntu\.com/ubuntu/?#https://tw.archive.ubuntu.com/ubuntu/#g' \
				"$file"
		done
		;;
	fedora)
		# Fedora 44+ uses DNF5. Repo override files modify the existing repo IDs
		# without duplicating them. TWDS is registered in Fedora MirrorManager
		# and provides HTTP(S); pin HTTPS here to satisfy the protocol policy.
		sudo mkdir -p /etc/dnf/repos.override.d
		sudo tee /etc/dnf/repos.override.d/99-yadm-taiwan.repo >/dev/null <<'EOF'
[fedora]
baseurl=https://mirror.twds.com.tw/fedora/fedora/linux/releases/$releasever/Everything/$basearch/os/
metalink=
mirrorlist=

[fedora-debuginfo]
baseurl=https://mirror.twds.com.tw/fedora/fedora/linux/releases/$releasever/Everything/$basearch/debug/tree/
metalink=
mirrorlist=

[updates]
baseurl=https://mirror.twds.com.tw/fedora/fedora/linux/updates/$releasever/Everything/$basearch/
metalink=
mirrorlist=

[updates-debuginfo]
baseurl=https://mirror.twds.com.tw/fedora/fedora/linux/updates/$releasever/Everything/$basearch/debug/
metalink=
mirrorlist=
EOF
		;;
	raspbian | msys2)
		# Not part of the current x86-64 QEMU matrix. Leave their upstream
		# configuration untouched until those targets have a tested TW mirror.
		;;
	*)
		echo "不支援的 distro: $DISTRO" >&2
		return 1
		;;
	esac
}

pkg_update() {
	configure_taiwan_mirror
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

# 一次解析整份套件清單，避免 N 次 subprocess

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
