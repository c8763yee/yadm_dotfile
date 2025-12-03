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
	printf "       %s --method git\n" "$0"
	printf "\n"
	printf "Options:\n"
	printf "  --method download <version>  : Download and extract specific kernel version tarball\n"
	printf "  --method git                 : Clone or pull the mainline kernel git repository\n"
	printf "\n"
	printf "Examples:\n"
	printf "  %s --method download 6.5.3\n" "$0"
	printf "  %s --method git\n" "$0"
	exit 1
}

# --- Argument Parsing ---

METHOD="download"
VERSION=$(uname -r | cut -d'-' -f 1)

while [[ $# -gt 0 ]]; do
	case "$1" in
	--method)
		if [[ -n "$2" ]] && [[ "$2" != -* ]]; then
			METHOD=$(echo "$2" | tr '[:upper:]' '[:lower:]')
			shift 2
			if [[ "$METHOD" != "git" && "$METHOD" != "download" ]]; then
				printf "❌ Error: -  -method requires an argument (git|download), got %s\n\n", "$METHOD"
				usage
			fi
		fi
		;;
	-*)
		printf "❌ Error: Unknown option: %s\n\n" "$1"
		usage
		;;
	*)
		VERSION="$1"
		shift
		;;
	esac
done

# Validate method
if [[ -z "$METHOD" ]]; then
	printf "❌ Error: --method is required\n\n"
	usage
fi

if [[ "$METHOD" != "download" ]] && [[ "$METHOD" != "git" ]]; then
	printf "❌ Error: Invalid method '%s'. Use 'download' or 'git'\n\n" "$METHOD"
	usage
fi

# Validate version for download method
if [[ "$METHOD" == "download" ]] && [[ -z "$VERSION" ]]; then
	printf "❌ Error: Version is required for download method\n\n"
	usage
fi

# Git method doesn't need version
if [[ "$METHOD" == "git" ]] && [[ -n "$VERSION" ]]; then
	printf "⚠️  Warning: Version parameter ignored for git method\n\n"
fi

# --- Main Logic ---

mkdir -p "$HOME/linux-kernel/"

case "$METHOD" in
download)
	# --- Download Method ---
	printf "Kernel Version: %s\n" "$VERSION"
	printf "Method: download\n\n"

	if ! command -v wget &>/dev/null; then
		printf "❌ Error: 'wget' is required for the download method. Please install it.\n"
		exit 1
	fi

	# Get the major version number (e.g., '6' from '6.5.3')
	MAJOR_VERSION=$(echo "$VERSION" | cut -d'.' -f1)

	URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR_VERSION}.x/linux-${VERSION}.tar.xz"
	TARBALL="$HOME/linux-kernel/linux-${VERSION}.tar.xz"
	EXTRACT_DIR="$HOME/linux-kernel/linux-${VERSION}"

	# Check if already extracted
	if [ -d "$EXTRACT_DIR" ]; then
		printf "⚠️  Directory '%s' already exists. Skipping download.\n" "$EXTRACT_DIR"
		exit 0
	fi

	printf "Downloading source tarball from:\n%s\n\n" "$URL"
	wget -O "$TARBALL" -c "$URL"

	if [ $? -ne 0 ]; then
		printf "\n❌ Download failed. Please check the version number and your network connection.\n"
		exit 1
	fi

	printf "\n✅ Download complete. Extracting...\n"
	tar -xf "$TARBALL" -C "$HOME/linux-kernel/"

	if [ $? -eq 0 ]; then
		printf "✅ Extraction complete. Removing tarball...\n"
		rm "$TARBALL"
		printf "✅ Success! Kernel source extracted to: %s\n" "$EXTRACT_DIR"
	else
		printf "❌ Extraction failed.\n"
		exit 1
	fi
	;;

git)
	# --- Git Clone/Pull Method ---
	printf "Method: git\n\n"

	if ! command -v git &>/dev/null; then
		printf "❌ Error: 'git' is required for the git method. Please install it.\n"
		exit 1
	fi

	GIT_URL="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
	DIR_NAME="$HOME/linux-kernel/linux-git"

	if [ -d "$DIR_NAME" ]; then
		printf "📁 Directory '%s' exists. Pulling latest changes...\n" "$DIR_NAME"
		cd "$DIR_NAME"
		git pull

		if [ $? -eq 0 ]; then
			printf "\n✅ Success! Repository updated.\n"
		else
			printf "\n❌ Git pull failed.\n"
			exit 1
		fi
	else
		printf "Cloning mainline kernel repository into '%s'...\n" "$DIR_NAME"
		git clone "$GIT_URL" "$DIR_NAME"

		if [ $? -eq 0 ]; then
			printf "\n✅ Success! Kernel source cloned into: %s\n" "$DIR_NAME"
		else
			printf "\n❌ Git clone failed.\n"
			exit 1
		fi
	fi
	;;
esac

exit 0
