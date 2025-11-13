### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load plugins and themes
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-history-substring-search
zinit light zdharma-continuum/fast-syntax-highlighting

zinit ice depth=1; zinit light romkatv/powerlevel10k

# oh-my-zsh snippets
# Must Load OMZ Git library
zi snippet OMZL::git.zsh

# Must Load OMZ Async prompt library
zi snippet OMZL::async_prompt.zsh 

zinit snippet OMZL::completion.zsh
zinit snippet OMZL::history.zsh
zinit snippet OMZL::key-bindings.zsh
zinit snippet OMZL::theme-and-appearance.zsh
zinit snippet OMZL::directories.zsh
plugins=(git vim-interaction pipenv pip aliases docker docker-compose poetry git-commit git-auto-fetch ssh sudo github git-hubflow git-lfs alias-finder uv colored-man-pages gh history postgres ssh-agent supervisor tmux themes vscode wakeonlan)
for plugin in "${plugins[@]}"; do
    # Turbo mode: defer sourcing until after prompt draw for faster startup.
    zinit ice wait"1" lucid reset
    zinit snippet "OMZP::${plugin}"
done

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
