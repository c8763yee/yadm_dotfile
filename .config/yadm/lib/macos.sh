# macOS-only package provisioner. Homebrew and yadm are preinstalled.
check_macos_toolchain() {
    if xcrun --find clang >/dev/null 2>&1; then return 0; fi
    if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
        echo "Xcode 已安裝，但開發工具無法使用；請檢查 xcode-select" >&2
    else
        xcode-select --install || :
    fi
    echo "完成 Xcode/CLT 設定後，請重新執行 yadm bootstrap" >&2
    return 1
}
install_macos_packages() {
    local arch prefix arm_capable
    check_macos_toolchain || return 1
    arch=$(uname -m) || return 1
    arm_capable=$(sysctl -n hw.optional.arm64 2>/dev/null || :)
    if [[ "$arm_capable" == 1 && "$arch" != arm64 ]]; then
        echo "請改用原生 ARM64 終端機，勿以 Rosetta 執行" >&2; return 1
    fi
    case "$arch" in
        arm64|x86_64) ;;
        *) echo "不支援的架構: $arch" >&2; return 1 ;;
    esac
    command -v brew >/dev/null 2>&1 || { echo "找不到 brew" >&2; return 1; }
    prefix=$(brew --prefix) || return 1

    # 1401 can translate ARM64 Homebrew on Intel Hackintosh. The active
    # Homebrew prefix selects the package target, not uname -m alone.
    case "$arch:$prefix" in
        arm64:/opt/homebrew|x86_64:/usr/local|x86_64:/opt/homebrew) ;;
        *)
            echo "不支援的 Homebrew 組態: $arch / $prefix" >&2
            return 1
            ;;
    esac
    brew bundle --file="$PACKAGES_DIR/Brewfile.MacOS"
}
