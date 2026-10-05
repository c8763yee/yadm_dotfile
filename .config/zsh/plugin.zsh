# HyDE probes this file once and sources it again when it succeeds.
# Keep it idempotent so Zinit is initialized exactly once.
if [[ -n ${YADM_ZINIT_LOADED:-} ]]; then
  return 0
fi
typeset -g YADM_ZINIT_LOADED=1

plugin_manifest="${ZDOTDIR:-$HOME/.config/zsh}/zinit.zsh"
if [[ -r $plugin_manifest ]]; then
  source "$plugin_manifest"
else
  print -u2 "Missing Zinit manifest: $plugin_manifest"
  return 1
fi
unset plugin_manifest
