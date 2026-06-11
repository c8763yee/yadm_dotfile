#!/usr/bin/env bash

set -euo pipefail

workspace_json=$(hyprctl -j activeworkspace)
workspace_id=$(jq -r '.id' <<<"$workspace_json")
workspace_name=$(jq -r '.name' <<<"$workspace_json")

if [[ $workspace_name == special:* ]]; then
    exit 0
fi

special_name="show-desktop-${workspace_id}"

if ((workspace_id > 0)); then
    restore_target=$workspace_id
else
    restore_target="name:${workspace_name}"
fi

mapfile -t hidden_addresses < <(
    hyprctl -j clients |
        jq -r --arg workspace "special:${special_name}" \
            '.[] | select(.workspace.name == $workspace) | .address'
)

commands=()
if ((${#hidden_addresses[@]} > 0)); then
    for address in "${hidden_addresses[@]}"; do
        commands+=("dispatch movetoworkspacesilent ${restore_target},address:${address}")
    done
else
    mapfile -t visible_addresses < <(
        hyprctl -j clients |
            jq -r --argjson workspace_id "$workspace_id" \
                '.[] | select(.workspace.id == $workspace_id) | .address'
    )

    for address in "${visible_addresses[@]}"; do
        commands+=("dispatch movetoworkspacesilent special:${special_name},address:${address}")
    done
fi

((${#commands[@]} > 0)) || exit 0

batch=$(IFS=';'; echo "${commands[*]}")
hyprctl --batch "$batch" >/dev/null
