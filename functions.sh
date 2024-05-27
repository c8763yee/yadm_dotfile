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
            sudo apt update -y && sudo apt upgrade -y && sudo apt autoremove -y && sudo snap refresh
            ;;
        *)
            echo "Unknown distro"
            ;;
    esac
}
