#!/usr/bin/env bash
set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

[[ -f "$state_home/hyde/staterc" ]] && source "$state_home/hyde/staterc"
[[ -f "$state_home/hyde/config" ]] && source "$state_home/hyde/config"

wallpaper_dirs=()
if [[ -n ${HYDE_THEME:-} && -d "$config_home/hyde/themes/$HYDE_THEME/wallpapers" ]]; then
	wallpaper_dirs+=("$config_home/hyde/themes/$HYDE_THEME/wallpapers")
fi
if declare -p WALLPAPER_CUSTOM_PATHS &>/dev/null; then
	wallpaper_dirs+=("${WALLPAPER_CUSTOM_PATHS[@]}")
else
	wallpaper_dirs+=("$HOME/wallpapers")
fi

mkdir -p "$runtime_dir/hyde"
exec 9>"$runtime_dir/hyde/wallpaper.lock"
flock -w 15 9

query="$(awww query --json)"
mapfile -t outputs < <(jq -r '.[][] | .name' <<<"$query")
if ((${#outputs[@]} == 0)); then
	printf 'No awww outputs found\n' >&2
	exit 1
fi

mapfile -d '' -t wallpapers < <(
	find -H "${wallpaper_dirs[@]}" -type f \
		\( -iname '*.gif' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) \
		! -path '*/logo/*' -print0 | shuf -z
)
if ((${#wallpapers[@]} < ${#outputs[@]})); then
	printf 'Need at least %d wallpapers, found %d\n' "${#outputs[@]}" "${#wallpapers[@]}" >&2
	exit 1
fi

for i in "${!outputs[@]}"; do
	awww img --outputs "${outputs[i]}" "${wallpapers[i]}" \
		--transition-bezier .43,1.19,1,.4 \
		--transition-type grow --transition-duration 0.4 --transition-fps 60 --resize fit
	printf '%s: %s\n' "${outputs[i]}" "${wallpapers[i]}"
done
