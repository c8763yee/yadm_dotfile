#!/usr/bin/env bash
# Merge shared MCP definitions into Antigravity CLI without overwriting custom entries.
set -euo pipefail
manifest="${XDG_CONFIG_HOME:-$HOME/.config}/agents/mcp.json"
config="$HOME/.gemini/config/mcp_config.json"
mkdir -p "$(dirname "$config")"
if [[ ! -e "$config" ]]; then
    printf '{"mcpServers":{}}\n' >"$config"
fi
jq -e 'type == "object" and (.mcpServers | type == "object")' "$config" >/dev/null || {
    echo "Invalid Antigravity MCP configuration: $config" >&2
    exit 1
}
while IFS= read -r entry; do
    name=$(jq -r '.key' <<<"$entry")
    cmd=$(jq -r '.value.command' <<<"$entry")
    cmd="${cmd//\$HOME/$HOME}"
    [[ -x "$cmd" ]] || continue
    args=$(jq -c '.value.args // []' <<<"$entry")
    tmp=$(mktemp "${config}.tmp.XXXXXX")
    if jq --arg name "$name" --arg cmd "$cmd" --argjson args "$args" \
        '.mcpServers[$name] //= {"command": $cmd, "args": $args}' "$config" >"$tmp"; then
        chmod 600 "$tmp"
        mv -f -- "$tmp" "$config"
    else
        rm -f -- "$tmp"
        exit 1
    fi
done < <(jq -c 'to_entries[]' "$manifest")
