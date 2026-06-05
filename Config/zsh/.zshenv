#!/usr/bin/env zsh

for file in "${0:A:h}/conf.d/"**/*.zsh(N); do
  [ -r "$file" ] && source "$file"
done
autoload -Uz compinit
compinit
