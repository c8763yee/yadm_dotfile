plugin_manifest="$HOME/Config/zsh/zinit.zsh"
if [[ -r $plugin_manifest ]]; then
  source "$plugin_manifest"
else
  print -u2 "Missing Zinit manifest: $plugin_manifest"
  return 1
fi
unset plugin_manifest
