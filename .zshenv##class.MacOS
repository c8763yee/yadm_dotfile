#!/usr/bin/env zsh

setopt interactive_comments
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"

if ! source $ZDOTDIR/.zshenv; then
	echo "FATAL Error: Could not source $ZDOTDIR/.zshenv"
	return 1
fi

if [[ -n "${SSH_CLIENT-}${SSH_TTY-}" && -z "${TMUX-}" && -o interactive ]]; then
	if [[ ! -f /tmp/no-tmux ]]; then
		export LANG="${LANG:-en_US.UTF-8}"
		export LC_ALL="${LC_ALL:-en_US.UTF-8}"
		exec tmux new-session -A -s ssh_tmux
	else
		echo "will not use tmux in this session"
		rm -f /tmp/no-tmux
	fi
fi
