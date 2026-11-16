#!/usr/bin/env bash
# Mocked, non-network regression checks for native Ponytail provisioning.
set -euo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
script="$root/.config/yadm/lib/install-ponytail.sh"
bash -n "$script"
jq -e '.enabledPlugins["ponytail@ponytail"] == true and
       .extraKnownMarketplaces.ponytail.source.repo == "DietrichGebert/ponytail" and
       .statusLine.command == "bunx -y ccstatusline@latest"' "$root/.claude/settings.json" >/dev/null
jq -e '.defaultMode == "lite"' "$root/.config/ponytail/config.json" >/dev/null
test -f "$root/.config/agents/prompts/.gitkeep"
if grep -q 'prompts/.*\.md' "$root/.config/agents/AGENTS.md" \
    "$root/.claude/agents/logic-adversary.md" \
    "$root/.codex/agents/logic-adversary.toml" \
    "$root/.gemini/config/agents/logic-adversary/agent.md"; then
    echo 'A removed custom prompt is still referenced' >&2
    exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/state" "$tmp/home"
export HOME="$tmp/home" TEST_LOG="$tmp/log" TEST_STATE="$tmp/state"
export PATH="$tmp/bin:$PATH"

cat >"$tmp/bin/node" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
cat >"$tmp/bin/claude" <<'STUB'
#!/usr/bin/env bash
[[ "$*" == "plugin install ponytail --marketplace DietrichGebert/ponytail --scope user" ]] || exit 2
printf 'claude %s\n' "$*" >>"$TEST_LOG"
STUB
cat >"$tmp/bin/codex" <<'STUB'
#!/usr/bin/env bash
case "$*" in
    "plugin marketplace list --json")
        if [[ -f "$TEST_STATE/marketplace" ]]; then
            printf '%s\n' '{"marketplaces":[{"name":"ponytail"}]}'
        else
            printf '%s\n' '{"marketplaces":[]}'
        fi
        ;;
    "plugin marketplace add DietrichGebert/ponytail")
        touch "$TEST_STATE/marketplace"
        printf 'codex %s\n' "$*" >>"$TEST_LOG"
        ;;
    "plugin list --json")
        if [[ -f "$TEST_STATE/plugin" ]]; then
            printf '%s\n' '{"installed":[{"name":"ponytail","marketplaceName":"ponytail","enabled":true}]}'
        else
            printf '%s\n' '{"installed":[]}'
        fi
        ;;
    "plugin add ponytail@ponytail")
        touch "$TEST_STATE/plugin"
        printf 'codex %s\n' "$*" >>"$TEST_LOG"
        ;;
    *) printf 'Unexpected Codex command: %s\n' "$*" >&2; exit 3 ;;
esac
STUB
chmod +x "$tmp/bin/"*

bash "$script"
bash "$script"
[[ $(grep -c '^claude plugin install' "$TEST_LOG") -eq 2 ]]
[[ $(grep -c '^codex plugin marketplace add' "$TEST_LOG") -eq 1 ]]
[[ $(grep -c '^codex plugin add' "$TEST_LOG") -eq 1 ]]
[[ ! -e "$HOME/.claude/settings.json" ]]
echo 'PASS ponytail scope'
