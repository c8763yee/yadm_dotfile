#!/usr/bin/env bash
# Exercise platform routing without installing real packages.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config"
export TEST_LOG="$tmp/log" TEST_OS=Darwin TEST_ARCH=arm64
export TEST_ARM_CAPABLE=1 TEST_PREFIX=/opt/homebrew TEST_CLT=1
mkdir -p "$tmp/bin" "$XDG_CONFIG_HOME/yadm/lib" \
    "$XDG_CONFIG_HOME/yadm/packages" "$XDG_CONFIG_HOME/yadm/bootstrap.d"
cp "$repo/.config/yadm/lib/"{env,macos}.sh "$XDG_CONFIG_HOME/yadm/lib/"
cp "$repo/.config/yadm/packages/Brewfile.MacOS" "$XDG_CONFIG_HOME/yadm/packages/"
export PATH="$tmp/bin:$PATH"
cat >"$tmp/bin/uname" <<'STUB'
#!/usr/bin/env bash
case "$1" in
    -s) echo "$TEST_OS" ;;
    -m) echo "$TEST_ARCH" ;;
    *) exit 1 ;;
esac
STUB
cat >"$tmp/bin/sysctl" <<'STUB'
#!/usr/bin/env bash
[[ "$1" == -n && "$2" == hw.optional.arm64 ]] || exit 1
echo "$TEST_ARM_CAPABLE"
STUB
cat >"$tmp/bin/xcrun" <<'STUB'
#!/usr/bin/env bash
[[ "$TEST_CLT" == 1 && "$1" == --find && "$2" == clang ]]
STUB
cat >"$tmp/bin/xcode-select" <<'STUB'
#!/usr/bin/env bash
echo "xcode-select $*" >>"$TEST_LOG"
STUB
cat >"$tmp/bin/brew" <<'STUB'
#!/usr/bin/env bash
case "$1" in
    --prefix) echo "$TEST_PREFIX" ;;
    shellenv) echo "export HOMEBREW_PREFIX='$TEST_PREFIX'" ;;
    bundle) echo "brew $*" >>"$TEST_LOG" ;;
    *) exit 1 ;;
esac
STUB
cat >"$tmp/bin/yadm" <<'STUB'
#!/usr/bin/env bash
echo "yadm $*" >>"$TEST_LOG"
STUB
chmod +x "$tmp/bin/"*
stage="$repo/.config/yadm/bootstrap.d/10-packages"

: >"$TEST_LOG"
bash "$stage"
grep -q 'brew bundle --file=' "$TEST_LOG"
TEST_ARCH=x86_64 TEST_ARM_CAPABLE=0 TEST_PREFIX=/usr/local bash "$stage"

if TEST_ARCH=x86_64 TEST_ARM_CAPABLE=1 TEST_PREFIX=/usr/local bash "$stage" >/dev/null 2>&1; then
    echo "Rosetta incorrectly accepted" >&2; exit 1
fi
if TEST_PREFIX=/usr/local bash "$stage" >/dev/null 2>&1; then
    echo "Wrong Homebrew prefix accepted" >&2; exit 1
fi
: >"$TEST_LOG"
if TEST_CLT=0 bash "$stage" >/dev/null 2>&1; then
    echo "Missing CLT accepted" >&2; exit 1
fi
grep -q 'xcode-select --install' "$TEST_LOG"
! grep -q 'brew bundle' "$TEST_LOG"

for name in 10-packages 20-desktop 30-user 34-antigravity 35-mcp 40-system; do
    cat >"$XDG_CONFIG_HOME/yadm/bootstrap.d/$name" <<'STUB'
#!/bin/sh
basename "$0" >>"$TEST_LOG"
STUB
    chmod +x "$XDG_CONFIG_HOME/yadm/bootstrap.d/$name"
done
: >"$TEST_LOG"
env -u YADM_CLASS sh "$repo/.config/yadm/bootstrap"
grep -q '^yadm config local.class MacOS$' "$TEST_LOG"
grep -q '^10-packages$' "$TEST_LOG"
grep -q '^30-user$' "$TEST_LOG"
grep -q '^35-mcp$' "$TEST_LOG"
! grep -q '^20-desktop$' "$TEST_LOG"
! grep -q '^40-system$' "$TEST_LOG"
if YADM_CLASS=Kde sh "$repo/.config/yadm/bootstrap" >/dev/null 2>&1; then
    echo "Linux class accepted on macOS" >&2; exit 1
fi
if [[ -e /etc/os-release ]]; then
    : >"$TEST_LOG"
    TEST_OS=Linux YADM_CLASS=Base sh "$repo/.config/yadm/bootstrap"
    grep -q '^20-desktop$' "$TEST_LOG"
    grep -q '^40-system$' "$TEST_LOG"
fi
echo 'PASS mocked macOS bootstrap'
