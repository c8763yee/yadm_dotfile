#!/bin/bash

# A script to download or clone the Linux kernel source code from kernel.org.
# It defaults to downloading the tarball for the currently running kernel version.

# Exit immediately if a command fails.
set -e

##
# Shows usage information and exits.
##
usage() {
	printf "Usage: %s --method download <version>\n" "$0"
	printf "       %s --method git <tree>\n" "$0"
	printf "\n"
	printf "Options:\n"
	printf "  --method download <version>  : Download and extract specific kernel version tarball\n"
	printf "  --method git <tree>          : Clone or pull a kernel git tree (default: torvalds/linux)\n"
	printf "\n"
	printf "Examples:\n"
	printf "  %s --method download 6.5.3\n" "$0"
	printf "  %s --method git\n" "$0"
	printf "  %s --method git stable/linux\n" "$0"
	printf "  %s --method git next/linux-next\n" "$0"
	exit 1
}

# --- Argument Parsing ---

METHOD="download"
POSITIONAL=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	--method)
		METHOD="${2,,}"
		shift 2 || usage
		if [[ "$METHOD" != "git" && "$METHOD" != "download" ]]; then
			printf "❌ Error: --method requires an argument (git|download), got '%s'\n\n" "$METHOD"
			usage
		fi
		;;
	-*)
		printf "❌ Error: Unknown option: %s\n\n" "$1"
		usage
		;;
	*)
		POSITIONAL="$1"
		shift
		;;
	esac
done

# --- Main Logic ---

mkdir -p "$HOME/linux-kernel/"

case "$METHOD" in
download)
	# --- Download Method ---
	VERSION="${POSITIONAL:-$(uname -r | cut -d'-' -f1)}"

	printf "Kernel Version: %s\n" "$VERSION"
	printf "Method: download\n\n"

	if ! command -v wget &>/dev/null; then
		printf "❌ Error: 'wget' is required for the download method. Please install it.\n"
		exit 1
	fi

	if [[ $(echo "$VERSION" | cut -d'.' -f3) == '0' ]]; then
		VERSION=$(echo "$VERSION" | cut -d'.' -f1,2)
	fi

	# Get the major version number (e.g., '6' from '6.5.3')
	MAJOR=$(echo "$VERSION" | cut -d'.' -f1)
	MINOR=$(echo "$VERSION" | cut -d'.' -f2)
	VERSION_SHORT=$([[ $MAJOR -lt 3 || ($MAJOR -eq 3 && $MINOR -eq 0) ]] && echo "v${MAJOR}.${MINOR}" || echo "v${MAJOR}.x")

	URL="https://cdn.kernel.org/pub/linux/kernel/${VERSION_SHORT}/linux-${VERSION}.tar.xz"
	TARBALL="$HOME/linux-kernel/linux-${VERSION}.tar.xz"
	EXTRACT_DIR="$HOME/linux-kernel/linux-${VERSION}"

	# Check if already extracted
	if [ -d "$EXTRACT_DIR" ]; then
		printf "⚠️  Directory '%s' already exists. Skipping download.\n" "$EXTRACT_DIR"
		exit 0
	fi

	printf "Downloading source tarball from:\n%s\n\n" "$URL"
	wget -O "$TARBALL" -c "$URL"

	printf "\n✅ Download complete. Extracting...\n"
	tar -xf "$TARBALL" -C "$HOME/linux-kernel/"

	printf "✅ Extraction complete. Removing tarball...\n"
	rm "$TARBALL"
	printf "✅ Success! Kernel source extracted to: %s\n" "$EXTRACT_DIR"
	;;

git)
	# --- Git Clone/Pull Method ---
	TREE="${POSITIONAL:-torvalds/linux}"

	printf "Method: git\n"
	printf "Tree: %s\n\n" "$TREE"

	if ! command -v git &>/dev/null; then
		printf "❌ Error: 'git' is required for the git method. Please install it.\n"
		exit 1
	fi

	GIT_URL="https://git.kernel.org/pub/scm/linux/kernel/git/${TREE}.git"
	DIR_NAME="$HOME/linux-kernel/${TREE//\//-}"

	if [ -d "$DIR_NAME" ]; then
		printf "📁 Directory '%s' exists. Pulling latest changes...\n" "$DIR_NAME"
		cd "$DIR_NAME"
		git pull
		printf "\n✅ Success! Repository updated.\n"
	else
		printf "Cloning kernel repository into '%s'...\n" "$DIR_NAME"
		git clone "$GIT_URL" "$DIR_NAME"
		printf "\n✅ Success! Kernel source cloned into: %s\n" "$DIR_NAME"
	fi
	;;

*)
	usage
	;;
esac

exit 0
