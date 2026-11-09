# Shared bootstrap state. This file defines data only; it performs no actions.
BASE_DIR="${BASE_DIR:-$HOME}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
PACKAGES_DIR="$XDG_CONFIG_HOME/yadm/packages"
OS=$(uname -s)
case "$OS" in
    Linux) . /etc/os-release; DISTRO="$ID" ;;
    Darwin) DISTRO=macos ;;
    *) echo "不支援的 OS: $OS" >&2; return 1 ;;
esac
