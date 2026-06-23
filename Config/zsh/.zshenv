#!/usr/bin/env zsh

custom_dir="$HOME/Config/zsh/conf.d"
for file in "$custom_dir"/**/*.zsh(N); do
  [[ $file == */autocompletion/* ]] && (( ! $+functions[compdef] )) && continue
  [ -r "$file" ] && source "$file"
done
unset custom_dir file
