#!/usr/bin/env bash
# Read-only, risk-scaled verification; never installs or modifies user settings.
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd -P)
level=quick
case "${1:-}" in
    "") ;;
    --level)
        [[ $# -eq 2 ]] || { echo 'Usage: run.sh [--level quick|standard|critical]' >&2; exit 2; }
        level=$2
        ;;
    *) echo 'Usage: run.sh [--level quick|standard|critical]' >&2; exit 2 ;;
esac
case "$level" in
    quick|standard|critical) ;;
    *) echo "Unknown verification level: $level" >&2; exit 2 ;;
esac

echo "[VERIFY] level=$level"
incomplete=0
sh -n "$root/.config/yadm/bootstrap"
for script in "$root"/.config/yadm/bootstrap.d/* "$root"/.config/yadm/lib/*.sh \
              "$root"/.local/bin/pensieve-init "$root"/tests/test-*-scope.sh; do
    [[ -f "$script" ]] || continue
    bash -n "$script"
done
echo 'PASS syntax'

if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$root" diff --check
    git -C "$root" diff --cached --check
elif [[ "$root" == "$(cd -- "$HOME" && pwd -P)" ]] && command -v yadm >/dev/null 2>&1; then
    yadm diff --check
    yadm diff --cached --check
else
    echo 'NOT RUN diff hygiene: no Git checkout or yadm available'
    incomplete=1
fi

if command -v jq >/dev/null 2>&1; then
    jq -e . "$root/.claude/settings.json" \
            "$root/.config/agents/mcp.json" \
            "$root/.config/yadm/templates/antigravity-cli-settings.json" >/dev/null
    echo 'PASS JSON'
else
    echo 'NOT RUN JSON: jq unavailable'
    incomplete=1
fi

if (( incomplete != 0 )); then
    echo 'NOT RUN verification incomplete; resolve missing tools before claiming PASS'
    exit 2
fi

if [[ "$level" == quick ]]; then
    echo 'PASS quick checks (does not establish integration behavior)'
    exit 0
fi

for test in test-harness-scope.sh test-pensieve-scope.sh test-antigravity-scope.sh; do
    bash "$root/tests/$test"
done
echo 'PASS standard isolated scope checks'

if [[ "$level" == critical ]]; then
    echo 'NOT RUN QEMU integration: requires explicit case selection and guest assertions'
    echo "See $root/docs/QEMU_TESTING.md"
    exit 2
fi
