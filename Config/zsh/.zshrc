# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.config/zsh/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi


# PATH settings
export PATH=/home/c8763yee/.local/bin${PATH:+:${PATH}}
if [[ -n $(command -v snap 2> /dev/null) ]]; then
	export PATH=/snap/bin:$PATH
fi

if [[ -n $(command -v nvidia-smi 2> /dev/null) ]]; then
	export PATH=/opt/cuda/bin:$PATH
	export LD_LIBRARY_PATH=/opt/cuda/lib64:${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
fi

# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:/usr/local/bin:$PATH

# Format for `time` command in terminal
TIMEFMT=$(cat <<EOF
-----------------------
Time Info: %3J
real	%E
user	%U
sys	%S
%P cpu %(%Xtext+%Ddata %Mmax)k
%I inputs+%O outputs (%F major+%R minor) pagefaults %
Wswaps %*E total
-----------------------
EOF
)

export EDITOR=vim
if [[ -n $(command -v nvim) ]]; then
	export EDITOR=nvim
elif [[ -n $(command -v nano) ]]; then
	export EDITOR=nano
fi

# To customize prompt, run `p10k configure` or edit ~/.config/zsh/.p10k.zsh.
[[ ! -f ~/.config/zsh/.p10k.zsh ]] || source ~/.config/zsh/.p10k.zsh

if [[ $- =~ i ]] && [[ -z "$TMUX" ]] && [[ -n "$SSH_TTY" ]]; then
  tmux attach-session -t ssh_tmux || tmux new-session -s ssh_tmux
fi

