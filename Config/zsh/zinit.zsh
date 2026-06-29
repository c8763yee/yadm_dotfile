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
zinit ice depth=1
zinit light romkatv/powerlevel10k

# Turbo mode: defer sourcing until after prompt draw so plugins load
# asynchronously in parallel. fast-syntax-highlighting must come last to
# wrap widgets defined by the earlier plugins.
zinit wait lucid light-mode for \
    atload"!_zsh_autosuggest_start" \
        zsh-users/zsh-autosuggestions \
    blockf \
        zsh-users/zsh-completions \
    atload'bindkey "^[[A" history-substring-search-up; bindkey "^[[B" history-substring-search-down' \
        zsh-users/zsh-history-substring-search \
    Aloxaf/fzf-tab \
    zdharma-continuum/fast-syntax-highlighting

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

# Turbo mode: queue all OMZ plugins in one batch so they source
# asynchronously in parallel after the prompt is drawn.
zinit wait"1" lucid reset for \
    OMZP::git OMZP::vim-interaction OMZP::pipenv OMZP::pip OMZP::aliases \
    OMZP::docker OMZP::docker-compose OMZP::poetry OMZP::git-commit \
    OMZP::git-auto-fetch OMZP::ssh OMZP::sudo OMZP::github OMZP::git-hubflow \
    OMZP::git-lfs OMZP::alias-finder OMZP::uv OMZP::colored-man-pages OMZP::gh \
    OMZP::history OMZP::postgres OMZP::ssh-agent OMZP::supervisor OMZP::tmux \
    OMZP::themes OMZP::vscode OMZP::wakeonlan

zinit wait lucid light-mode for djui/alias-tips
