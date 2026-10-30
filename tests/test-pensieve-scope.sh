#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
installer="$repo_root/.config/yadm/lib/install-pensieve.sh"
initializer="$repo_root/.local/bin/pensieve-init"
bootstrap="$repo_root/.config/yadm/bootstrap.d/30-user"

[[ -f "$bootstrap" ]]
bash -n "$installer" "$initializer" "$bootstrap"
! grep -q 'init-project-data.sh' "$bootstrap"
! grep -q 'claude plugin install pensieve' "$bootstrap"

tmp=$(mktemp -d "${PENSIEVE_TEST_TMPDIR:-/var/tmp}/pensieve-scope.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home"
mkdir -p "$HOME" "$tmp/unrelated" "$tmp/upstream/.src/scripts" "$tmp/project/subdir"

git init -q -b main "$tmp/upstream"
printf '%s\n' '---' 'name: pensieve' 'description: test' '---' >"$tmp/upstream/SKILL.md"
cat >"$tmp/upstream/.src/scripts/init-project-data.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
[[ "$(pwd -P)" == "$PENSIEVE_PROJECT_ROOT" ]]
mkdir -p "$PENSIEVE_PROJECT_ROOT/.pensieve"
printf '%s\n' "$PENSIEVE_PROJECT_ROOT" >"$PENSIEVE_PROJECT_ROOT/.pensieve/initialized-root"
SCRIPT
git -C "$tmp/upstream" add .
git -C "$tmp/upstream" -c user.name=Test -c user.email=test@example.invalid commit -qm 'fixture'

# Installing the skill cannot initialize the current project (or HOME).
(
    cd "$tmp/unrelated"
    PENSIEVE_REPO_URL="$tmp/upstream" bash "$installer"
)
[[ -f "$HOME/.claude/skills/pensieve/SKILL.md" ]]
[[ -L "$HOME/.agents/skills/pensieve" ]]
[[ "$(realpath -e -- "$HOME/.agents/skills/pensieve")" == "$(realpath -e -- "$HOME/.claude/skills/pensieve")" ]]
[[ ! -e "$tmp/unrelated/.pensieve" && ! -e "$HOME/.pensieve" ]]

# Reinstall is idempotent, and an invalid invocation does not create data.
PENSIEVE_REPO_URL="$tmp/upstream" bash "$installer"
if bash "$initializer" >/dev/null 2>&1; then
    echo 'initializer unexpectedly accepted missing explicit --project' >&2
    exit 1
fi
[[ ! -e "$tmp/unrelated/.pensieve" ]]

# The caller selects exactly one real repository root.
git init -q -b main "$tmp/project"
bash "$initializer" --project "$tmp/project"
[[ "$(cat "$tmp/project/.pensieve/initialized-root")" == "$(cd "$tmp/project" && pwd -P)" ]]
if bash "$initializer" --project "$tmp/project/subdir" >/dev/null 2>&1; then
    echo 'initializer unexpectedly accepted a nested project directory' >&2
    exit 1
fi
if bash "$initializer" --project "$HOME" >/dev/null 2>&1; then
    echo 'initializer unexpectedly accepted HOME' >&2
    exit 1
fi

# A preexisting unrelated Codex Skill must never be overwritten.
rm "$HOME/.agents/skills/pensieve"
mkdir "$HOME/.agents/skills/pensieve"
printf 'sentinel\n' >"$HOME/.agents/skills/pensieve/do-not-overwrite"
if PENSIEVE_REPO_URL="$tmp/upstream" bash "$installer" >/dev/null 2>&1; then
    echo 'installer unexpectedly overwrote an existing Codex skill' >&2
    exit 1
fi
[[ -f "$HOME/.agents/skills/pensieve/do-not-overwrite" ]]

printf 'Pensieve scope tests passed\n'
