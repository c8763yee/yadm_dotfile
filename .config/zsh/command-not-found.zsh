# Load the native command-not-found integration without taking over HyDE or Fedora.
# This file is sourced once from zinit.zsh, after Zinit is available.
_yadm_command_not_found_init() {
    emulate -L zsh
    local distro="" class="" brew_repo="" handler=""

    case "$OSTYPE" in
        darwin*)
            (( $+commands[brew] )) || return 0
            # Use the active Homebrew installation (also works with 1401).
            brew_repo=$(command brew --repository 2>/dev/null) || return 0
            handler="$brew_repo/Library/Homebrew/command-not-found/handler.sh"
            [[ -r "$handler" ]] && source "$handler"
            ;;
        msys*|cygwin*)
            (( $+commands[pacman] )) || return 0
            command_not_found_handler() {
                local cmd="$1" matches=""
                if [[ $cmd != */* ]]; then
                    matches=$(command pacman -F -- "$cmd" 2>/dev/null) || matches=""
                    # MSYS2 packages often expose Windows executables as .exe.
                    if [[ -z $matches && $cmd != *.exe ]]; then
                        matches=$(command pacman -F -- "$cmd.exe" 2>/dev/null) || matches=""
                    fi
                fi
                if [[ -n $matches ]]; then
                    print -r -- "$matches"
                else
                    print -u2 -r -- "zsh: command not found: $cmd"
                fi
                return 127
            }
            ;;
        linux*)
            if [[ -r /etc/os-release ]]; then
                distro=$(. /etc/os-release; print -r -- "${ID:-}")
            fi
            [[ $distro == fedora ]] && return 0
            if [[ $distro == arch ]] && (( $+commands[yadm] )); then
                class=$(command yadm config local.class 2>/dev/null)
                [[ $class == Hyprland ]] && return 0
            fi
            # Uses pkgfile on Arch, command-not-found on Debian/Ubuntu, and
            # other distro-native handlers supported by Oh My Zsh.
            zinit snippet OMZP::command-not-found
            ;;
    esac
}

_yadm_command_not_found_init
unfunction _yadm_command_not_found_init
