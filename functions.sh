function killAll() {
    ps aux | grep $1 | awk '{print $2}' | xargs kill -9
}

function UPDATE() {
    # Update the system using alias based on distro in /etc/os-release
    case $(grep -oP '(?<=^ID=).+' /etc/os-release) in
        arch)
            pSyu $@ && ySyu $@
        ;;
        debian)
            sudo apt update -y && sudo apt upgrade -y && sudo apt autoremove -y
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
