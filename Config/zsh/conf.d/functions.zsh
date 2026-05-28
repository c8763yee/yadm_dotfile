function killAll() {
	ps aux | grep $1 | awk '{print $2}' | xargs kill -9
}

function UPDATE() {
	# Update the system using alias based on distro in /etc/os-release
	case $(grep -oP '(?<=^ID=).+' /etc/os-release) in
		arch)
			pSyu $@ && ySyu $@
			;;
		debian|ubuntu)
			sudo apt update -y && sudo apt upgrade -y && sudo apt autoremove -y
			;;
		fedora)
			sudo dnf upgrade -y
			;;
		*)
			echo "Unknown distro"
			;;
	esac
	# Check if snap or flatpak or other package managers are installed
	if command -v snap; then
		sudo snap refresh
	fi

	if command -v flatpak; then
		flatpak --user update -y
	fi
}
# --- 自動設定 WSL2 portproxy ---

setup_portproxy() {
	# 只在 WSL 內執行(exclude ssh)
	if [[ -z $SSH_CONNECTION ]] && grep -qEi "(microsoft|wsl)" /proc/version &>/dev/null; then
		if [[ ! -f $HOME/.env ]]; then
			echo "[WSL PortProxy] $HOME/.env file not found, please create it first."
			return
		fi

		source $HOME/.env
		# 檢查目前是否已有正確的 portproxy
		EXISTING=$(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -Command "netsh interface portproxy show v4tov4" | grep -i "$WINIP" | grep "$WINPORT" | grep "$WSLIP" | grep "$WSLPORT")

		if [ -z "$EXISTING" ]; then
			echo "[WSL PortProxy] Setting up portproxy for $WINIP:$WINPORT -> $WSLIP:$WSLPORT..."

			# 刪除舊的（如果有）
			/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -Command "Start-Process netsh -ArgumentList 'interface portproxy delete v4tov4 listenport=$WINPORT listenaddress=$WINIP' -Verb RunAs"

			# 加入新的
			/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -Command "Start-Process netsh -ArgumentList 'interface portproxy add v4tov4 listenport=$WINPORT listenaddress=$WINIP connectport=$WSLPORT connectaddress=$WSLIP' -Verb RunAs"

			echo "[WSL PortProxy] Done."
		else
			echo "[WSL PortProxy] Already exists, skip."
		fi
	fi
}

function mkcd() {
	# Create a directory and change into it
	mkdir -p "$1" && cd "$1" || return
}

function psn(){
	ps aux | grep "$1"
}

function get-patch(){
	if [[ -z "$1" ]]; then
		echo "Usage: get-patch <lore-url|mbox-path>"
		return 1
	fi

	local input="$1"
	local mbox_file=""
	local tmpdir=""
	local title=""

	local msgid=""
	if [[ "$input" =~ ^https?://lore\.kernel\.org/ ]]; then
		msgid=$(echo "$input" | sed 's|https://lore\.kernel\.org/[^/]*/||; s|[/#].*||')
	elif [[ "$input" =~ ^https?:// ]]; then
		: # handled below
	elif [[ -f "$input" ]]; then
		: # local file, handled below
	elif [[ "$input" == *@* ]]; then
		msgid="$input"
	fi

	if [[ -n "$msgid" ]]; then
		tmpdir=$(mktemp -d /tmp/get-patch-XXXXXX)
		echo "Downloading $msgid via b4 ..."
		b4 am "$msgid" -o "$tmpdir" 2>&1 | grep -v '^$'
		local cover_file
		cover_file=$(print -l "$tmpdir"/*.cover(N) | head -1)
		mbox_file=$(ls "$tmpdir"/*.mbx 2>/dev/null | head -1)
		if [[ -z "$mbox_file" ]]; then
			echo "b4 produced no mbx file"
			rm -rf "$tmpdir"
			return 1
		fi
		# Derive series title from b4 filename: strip vN_YYYYMMDD_author_ prefix
		title=$(basename "$mbox_file" .mbx \
			| sed 's/^v[0-9]*_[0-9]\{8\}_[^_]*_//' \
			| tr '_' '-')
	elif [[ "$input" =~ ^https?:// ]]; then
		local tmpfile
		tmpfile=$(mktemp /tmp/patch-XXXXXX.mbox)
		echo "Downloading $input ..."
		if ! curl -fsSL "$input" -o "$tmpfile"; then
			echo "Download failed"
			rm -f "$tmpfile"
			return 1
		fi
		mbox_file="$tmpfile"
	else
		if [[ ! -f "$input" ]]; then
			echo "File not found: $input"
			return 1
		fi
		mbox_file="$input"
	fi

	# Fallback title from first patch Subject
	if [[ -z "$title" ]]; then
		local subject
		subject=$(grep -m1 '^Subject:' "$mbox_file" | sed 's/^Subject: *//')
		title=$(echo "$subject" \
			| sed 's/^\[[^]]*\] *//' \
			| tr ' /' '-_' \
			| tr -cd 'A-Za-z0-9_.-' \
			| cut -c1-80)
		[[ -z "$title" ]] && title="patch-$(date +%Y%m%d-%H%M%S)"
	fi

	local outdir="$HOME/patch/$title"
	mkdir -p "$outdir"

	echo "Splitting into $outdir ..."
	git mailsplit -o"$outdir" "$mbox_file"

	# Place cover letter as 0000-cover-letter.patch if available
	if [[ -n "${cover_file:-}" ]]; then
		cp "$cover_file" "$outdir/0000-cover-letter.patch"
	fi

	# Rename XXXX -> XXXX-<slug>.patch
	local f num subj slug
	for f in $(ls "$outdir"/[0-9][0-9][0-9][0-9] 2>/dev/null | sort -V); do
		[[ -f "$f" ]] || continue
		num=$(basename "$f")
		subj=$(grep -m1 '^Subject:' "$f" | sed 's/^Subject: *//')
		slug=$(echo "$subj" \
			| sed 's/^\[[^]]*\] *//' \
			| tr ' /' '-_' \
			| tr -cd 'A-Za-z0-9_.-' \
			| cut -c1-60)
		[[ -z "$slug" ]] && slug="patch"
		mv "$f" "$outdir/${num}-${slug}.patch"
	done

	echo "Done: $(ls "$outdir" | wc -l) patch(es) in $outdir"
	[[ -n "$tmpdir" ]] && rm -rf "$tmpdir"
	[[ -n "$tmpfile" ]] && rm -f "$tmpfile"
}

# 只在第一次進入 zsh session 時執行一次
if [ -z "$SETUP_PORTPROXY_DONE" ]; then
	setup_portproxy
	export SETUP_PORTPROXY_DONE=1
fi
