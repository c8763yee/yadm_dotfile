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

# A normal Git checkout and yadm's bare Git repo have different layouts.
# Select the exact repository backing this script, never an ancestor checkout.
git_top=$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || :)
home_root=$(cd -- "$HOME" && pwd -P)
if [[ -n "$git_top" ]] && [[ "$(cd -- "$git_top" && pwd -P)" == "$root" ]]; then
    git -C "$root" diff --check
    git -C "$root" diff --cached --check
    echo 'PASS diff hygiene (Git checkout)'
elif [[ "$root" == "$home_root" ]]; then
    # Prefer yadm if available (its worktree/data paths may be customized).
    # Otherwise Git can still inspect the standard XDG yadm bare repository.
    yadm_repo="${XDG_DATA_HOME:-$HOME/.local/share}/yadm/repo.git"
    if command -v yadm >/dev/null 2>&1 && yadm rev-parse --verify HEAD >/dev/null 2>&1; then
        yadm diff --check
        yadm diff --cached --check
        echo 'PASS diff hygiene (yadm)'
    elif [[ -d "$yadm_repo" ]] && git --git-dir="$yadm_repo" rev-parse --verify HEAD >/dev/null 2>&1; then
        git --git-dir="$yadm_repo" --work-tree="$root" diff --check
        git --git-dir="$yadm_repo" --work-tree="$root" diff --cached --check
        echo 'PASS diff hygiene (yadm bare repository)'
    else
        echo "NOT RUN diff hygiene: no initialized yadm repository found for $root"
        echo "Checked yadm on PATH and $yadm_repo"
        incomplete=1
    fi
else
    echo "NOT RUN diff hygiene: $root is neither a Git checkout root nor HOME=$home_root"
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
