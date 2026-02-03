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

# 只在第一次進入 zsh session 時執行一次
if [ -z "$SETUP_PORTPROXY_DONE" ]; then
	setup_portproxy
	export SETUP_PORTPROXY_DONE=1
fi
