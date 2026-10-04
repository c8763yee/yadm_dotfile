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

# Zinit installs missing objects synchronously before the first prompt by
# default. Prefetch plain GitHub plugins concurrently so first-run download
# time is bounded by the slowest clone instead of the sum of all clones.
zinit_prefetch_git_plugins() {
    emulate -L zsh
    setopt local_options no_monitor

    local -a plugins pids
    local plugin dest tmp
    local rc=0

    plugins=(
        romkatv/powerlevel10k
        zsh-users/zsh-autosuggestions
        zsh-users/zsh-completions
        zsh-users/zsh-history-substring-search
        Aloxaf/fzf-tab
        zdharma-continuum/fast-syntax-highlighting
        djui/alias-tips
    )

    command mkdir -p "$ZINIT[PLUGINS_DIR]"

    for plugin in "${plugins[@]}"; do
        dest="$ZINIT[PLUGINS_DIR]/${plugin//\//---}"
        [[ -d "$dest/.git" ]] && continue

        tmp="$dest.prefetch.$.$RANDOM"
        (
            command rm -rf -- "$tmp"
            if command git clone --quiet --depth 1 --single-branch \
                "https://github.com/$plugin.git" "$tmp"; then
                if [[ ! -e "$dest" ]]; then
                    command mv -- "$tmp" "$dest"
                else
                    command rm -rf -- "$tmp"
                fi
            else
                command rm -rf -- "$tmp"
                return 1
            fi
        ) &
        pids+=($!)
    done

    for pid in "${pids[@]}"; do
        wait "$pid" || rc=1
    done

    return "$rc"
}

# Missing-plugin prefetch is best-effort. If one clone fails, Zinit falls back
# to its normal installer for that plugin.
zinit_prefetch_git_plugins || :
unfunction zinit_prefetch_git_plugins

# Subsequent bulk updates can use Zinit's native concurrent updater.
zinit-update-parallel() {
    zinit update --parallel "${1:-8}"
}

# Initialize Zsh's completion system. Fedora's _dnf5 completion uses
# `dnf5 --complete` to search package names from enabled repositories.
autoload -Uz compinit
compinit -d "${ZDOTDIR:-$HOME}/.zcompdump"

# Local generated completions live outside HyDE-owned completion paths.
# Load them only after compinit has defined compdef.
for completion in "${ZDOTDIR:-$HOME/.config/zsh}"/conf.d/autocompletion/*.zsh(N); do
    source "$completion"
done
unset completion

# Load plugins and themes
zinit ice depth=1
zinit light romkatv/powerlevel10k

# Turbo mode: defer sourcing until after the prompt. Sourcing still runs in
# the main shell and is therefore serialized; this is deferred/asynchronous
# scheduling, not true parallel execution. fast-syntax-highlighting stays last
# so it can wrap widgets defined by the earlier plugins.
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

# Turbo mode: queue OMZ plugins after the prompt. These loads are deferred,
# not truly parallel, because they mutate the same shell state.
zinit wait"1" lucid reset for \
    OMZP::git OMZP::vim-interaction OMZP::pipenv OMZP::pip OMZP::aliases \
    OMZP::docker OMZP::docker-compose OMZP::poetry OMZP::git-commit \
    OMZP::git-auto-fetch OMZP::ssh OMZP::sudo OMZP::github OMZP::git-hubflow \
    OMZP::git-lfs OMZP::alias-finder OMZP::uv OMZP::colored-man-pages OMZP::gh \
    OMZP::history OMZP::postgres OMZP::ssh-agent OMZP::supervisor OMZP::tmux \
    OMZP::themes OMZP::vscode OMZP::wakeonlan

zinit wait lucid light-mode for djui/alias-tips
