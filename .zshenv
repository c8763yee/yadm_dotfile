setopt interactive_comments
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export PATH="$PATH:$HOME/.cargo/bin:$HOME/.local/bin:/bin:/sbin/:/usr/bin"
if ! source "$ZDOTDIR/.zshenv"; then
    echo "FATAL Error: Could not source $ZDOTDIR/.zshenv"
    return 1
fi
