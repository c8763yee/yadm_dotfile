#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
install="$root/.config/yadm/lib/install-agent-harness.sh"
verify="$root/.config/yadm/verify/run.sh"

bash -n "$install" "$verify"
for name in harness-verify failure-to-eval; do
    grep -q "^name: $name$" "$root/.config/agents/skills/$name/SKILL.md"
done
grep -q 'harness-verify' "$root/.config/agents/AGENTS.md"
grep -q 'logic-adversary' "$root/.config/agents/AGENTS.md"

# Bootstrap-created User-scope links must not appear as untracked dotfiles.
# The live yadm worktree uses a bare Git directory instead of a .git folder.
check_ignored() {
    if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git -C "$root" check-ignore -q "$1"
    elif [[ "$root" == "$(cd "$HOME" && pwd -P)" ]] && command -v yadm >/dev/null 2>&1; then
        yadm check-ignore -q "$1"
    else
        echo 'NOT RUN ignore checks: no Git checkout or yadm available' >&2
        return 2
    fi
}
for path in .claude/skills/harness-verify .claude/skills/failure-to-eval \
            .agents/skills/harness-verify .agents/skills/failure-to-eval; do
    check_ignored "$path" || {
        echo "Missing ignore rule or failed check for generated Skill: $path" >&2
        exit 1
    }
done

tmp=$(mktemp -d "${HARNESS_TEST_TMPDIR:-/var/tmp}/harness-scope.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home"
export XDG_CONFIG_HOME="$HOME/.config"
mkdir -p "$XDG_CONFIG_HOME/agents"
cp -a "$root/.config/agents/skills" "$XDG_CONFIG_HOME/agents/"

# No user Skill is replaced, and no project is initialized by installation.
bash "$install"
bash "$install"
for name in harness-verify failure-to-eval; do
    for skills in "$HOME/.claude/skills" "$HOME/.agents/skills" \
                  "$HOME/.gemini/antigravity-cli/skills"; do
        [[ -L "$skills/$name" ]]
        [[ "$(realpath -e -- "$skills/$name")" == "$(realpath -e -- "$XDG_CONFIG_HOME/agents/skills/$name")" ]]
    done
done
[[ ! -e "$HOME/.pensieve" ]]

# Preflight must fail safely when a target exists, without replacing it.
rm "$HOME/.agents/skills/failure-to-eval"
mkdir "$HOME/.agents/skills/failure-to-eval"
printf '%s\n' keep >"$HOME/.agents/skills/failure-to-eval/sentinel"
if bash "$install" >/dev/null 2>&1; then
    echo 'installer overwrote a conflicting skill' >&2
    exit 1
fi
[[ "$(cat "$HOME/.agents/skills/failure-to-eval/sentinel")" == keep ]]

# Verification is independent of installation and rejects unknown levels.
bash "$verify" --level quick
if bash "$verify" --level invalid >/dev/null 2>&1; then
    echo 'verification accepted an unknown level' >&2
    exit 1
fi
echo 'PASS harness scope'
