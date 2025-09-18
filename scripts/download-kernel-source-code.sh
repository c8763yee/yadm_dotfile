#!/bin/bash

# A script to download or clone the Linux kernel source code from kernel.org.
# It defaults to downloading the tarball for the currently running kernel version.

# Exit immediately if a command fails.
set -e

##
# Shows usage information and exits.
##
usage() {
    printf "Usage: %s [<version>] [download|git]\n" "$0"
    printf "  <version>     : Kernel version (e.g., 6.5.3). Defaults to the running kernel.\n"
    printf "  [download|git]: Method to use. 'download' (default) gets the tarball, 'git' clones the tag.\n"
    exit 1
}

# --- Argument Parsing ---

# Default to current kernel version if $1 is not set.
# The 'cut' command strips suffixes like '-arch1-1' or '-generic'.
VERSION="${1:-$(uname -r | cut -d'-' -f1)}"

# Default to 'download' method if $2 is not set, and convert to lowercase.
METHOD=$(echo "${2:-download}" | tr '[:upper:]' '[:lower:]')

# --- Main Logic ---

printf "Kernel Version: %s\n" "$VERSION"
printf "Method: %s\n\n" "$METHOD"

# Get the major version number (e.g., '6' from '6.5.3')
MAJOR_VERSION=$(echo "$VERSION" | cut -d'.' -f1)

mkdir -p $HOME/linux-kernel/
case "$METHOD" in
    download)
        # --- Download Method ---
        if ! command -v wget &> /dev/null; then
            printf "❌ Error: 'wget' is required for the download method. Please install it.\n"
            exit 1
        fi

        URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR_VERSION}.x/linux-${VERSION}.tar.xz"
        FILENAME="$HOME/linux-kernel/linux-${VERSION}.tar.xz"

        printf "Downloading source tarball from:\n%s\n" "$URL"
        wget -O $FILENAME -c "$URL" # -c allows resuming a partial download

        if [ $? -eq 0 ]; then
            printf "\n✅ Success! File saved as %s.\n" "$FILENAME"
            printf "   To extract, run: tar -xf %s\n" "$FILENAME"
        else
            printf "\n❌ Download failed. Please check the version number and your network connection.\n"
            exit 1
        fi
        ;;

    git)
        # --- Git Clone Method ---
        if ! command -v git &> /dev/null; then
            printf "❌ Error: 'git' is required for the git method. Please install it.\n"
            exit 1
        fi

        GIT_URL="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
        TAG="v${VERSION}"
        DIR_NAME="$HOME/linux-kernel/linux-${VERSION}"

        if [ -d "$DIR_NAME" ]; then
            printf "⚠️  Directory '%s' already exists. Skipping clone.\n" "$DIR_NAME"
            exit 0
        fi

        printf "Cloning tag '%s' into directory '%s'...\n" "$TAG" "$DIR_NAME"
        # A shallow clone is much faster and smaller as it omits the full commit history.
        git clone --depth 1 --branch "$TAG" "$GIT_URL" "$DIR_NAME"

        if [ $? -eq 0 ]; then
            printf "\n✅ Success! Kernel source cloned into the '%s' directory.\n" "$DIR_NAME"
        else
            printf "\n❌ Git clone failed. Please verify that the tag '%s' exists.\n" "$TAG"
            exit 1
        fi
        ;;

    *)
        # --- Invalid Method ---
        printf "❌ Error: Invalid method specified: '%s'.\n\n" "$METHOD"
        usage
        ;;
esac

exit 0
