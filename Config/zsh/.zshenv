#!/usr/bin/env zsh
echo $0
# for file in "${0:A:h}/conf.d/"**/*.zsh(N); do
for file in "${${(%):-%N}:A:h}/conf.d/"**/*.zsh(N); do
  [ -r "$file" ] && source "$file"
done
autoload -Uz compinit
compinit
