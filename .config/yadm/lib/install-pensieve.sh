#!/usr/bin/env bash
# Install one user-level Pensieve checkout for Claude Code and Codex.
# Project initialization is deliberately not part of this script.
set -euo pipefail

source_repo="${PENSIEVE_REPO_URL:-https://github.com/kingkongshot/Pensieve.git}"
skill_dir="$HOME/.claude/skills/pensieve"
codex_skill="$HOME/.agents/skills/pensieve"

mkdir -p "$(dirname "$skill_dir")" "$(dirname "$codex_skill")"

if [[ -e "$skill_dir" || -L "$skill_dir" ]]; then
    # Without a nested Git checkout, git -C could resolve the enclosing yadm
    # repository and accidentally pull the wrong remote.
    checkout_root=$(git -C "$skill_dir" rev-parse --show-toplevel 2>/dev/null) || {
        echo "Pensieve path is not a Git checkout: $skill_dir" >&2
        exit 1
    }
    if [[ "$(realpath -e -- "$checkout_root")" != "$(realpath -e -- "$skill_dir")" ]]; then
        echo "Refusing to update a non-Pensieve checkout: $skill_dir" >&2
        exit 1
    fi
    git -C "$skill_dir" pull --ff-only
else
    git clone -b main "$source_repo" "$skill_dir"
fi

if [[ ! -f "$skill_dir/SKILL.md" || ! -f "$skill_dir/.src/scripts/init-project-data.sh" ]]; then
    echo "Pensieve checkout is missing required files: $skill_dir" >&2
    exit 1
fi

if [[ -L "$codex_skill" ]]; then
    if [[ "$(realpath -e -- "$codex_skill")" != "$(realpath -e -- "$skill_dir")" ]]; then
        echo "Refusing to replace an existing Codex skill link: $codex_skill" >&2
        exit 1
    fi
elif [[ -e "$codex_skill" ]]; then
    echo "Refusing to overwrite an existing Codex skill: $codex_skill" >&2
    exit 1
else
    ln -s -- "$skill_dir" "$codex_skill"
fi

printf 'Pensieve installed for Claude Code and Codex (user scope).\n'
printf 'Project initialization is opt-in: pensieve-init --project /path/to/repo\n'
