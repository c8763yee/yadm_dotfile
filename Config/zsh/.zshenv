#!/usr/bin/env zsh

custom_dir="$HOME/Config/zsh/conf.d"
if [[ $(readlink "$HOME/.config/zsh") == "$HOME/Config/zsh" ]]; then
	custom_dir="${ZDOTDIR:-$HOME/.config/zsh}/conf.d"
fi
for file in "$custom_dir"/**/*.zsh(N); do
  [[ $file == */autocompletion/* ]] && (( ! $+functions[compdef] )) && continue
  [ -r "$file" ] && source "$file"
done
unset custom_dir file
