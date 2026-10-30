#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
bash -n "$root/.config/yadm/bootstrap.d/34-antigravity" \
    "$root/.config/yadm/bootstrap.d/35-mcp" \
    "$root/.config/yadm/lib/install-pensieve.sh" \
    "$root/.config/yadm/lib/sync-antigravity-mcp.sh"
jq -e '.toolPermission == "request-review"' \
    "$root/.config/yadm/templates/antigravity-cli-settings.json" >/dev/null
grep -q 'pensieve-init --project' "$root/.config/agents/AGENTS.md"

tmp=$(mktemp -d /var/tmp/agy-scope.XXXXXX)
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home"
export XDG_CONFIG_HOME="$HOME/.config"
mkdir -p "$HOME/.local/bin" "$XDG_CONFIG_HOME/agents" "$XDG_CONFIG_HOME/yadm/templates"
cp "$root/.config/agents/mcp.json" "$XDG_CONFIG_HOME/agents/mcp.json"
cp "$root/.config/yadm/templates/antigravity-cli-settings.json" \
    "$XDG_CONFIG_HOME/yadm/templates/antigravity-cli-settings.json"
printf '#!/bin/sh\nexit 0\n' >"$HOME/.local/bin/agy"
chmod +x "$HOME/.local/bin/agy"
bash "$root/.config/yadm/bootstrap.d/34-antigravity"
jq -e '.toolPermission == "request-review"' "$HOME/.gemini/antigravity-cli/settings.json" >/dev/null

# Re-running bootstrap preserves native application settings.
printf '{"toolPermission":"strict","keep":true}\n' >"$HOME/.gemini/antigravity-cli/settings.json"
bash "$root/.config/yadm/bootstrap.d/34-antigravity"
jq -e '.keep == true and .toolPermission == "strict"' "$HOME/.gemini/antigravity-cli/settings.json" >/dev/null

printf '#!/bin/sh\nexit 0\n' >"$HOME/.local/bin/zhtw-mcp"
chmod +x "$HOME/.local/bin/zhtw-mcp"
mkdir -p "$HOME/.gemini/config"
printf '{"mcpServers":{"zhtw-mcp":{"command":"/custom/tool"},"other":{"command":"/bin/true"}}}\n' >"$HOME/.gemini/config/mcp_config.json"
bash "$root/.config/yadm/lib/sync-antigravity-mcp.sh"
jq -e '.mcpServers["zhtw-mcp"].command == "/custom/tool" and .mcpServers.other.command == "/bin/true"' \
    "$HOME/.gemini/config/mcp_config.json" >/dev/null
test ! -e "$HOME/.pensieve"
echo 'Antigravity scope checks passed'
