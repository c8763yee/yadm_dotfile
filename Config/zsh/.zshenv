#!/usr/bin/env zsh

custom_dir="$HOME/Config/zsh/conf.d"
if [[ $(readlink $HOME/.config/zsh) 
	== $(dirname $custom_dir) ]]; then
	custom_dir=$HOME/.config/zsh
fi
for file in "$custom_dir"/**/*.zsh(N); do
  [[ $file == */autocompletion/* ]] && (( ! $+functions[compdef] )) && continue
  [ -r "$file" ] && source "$file"
done
unset custom_dir file
