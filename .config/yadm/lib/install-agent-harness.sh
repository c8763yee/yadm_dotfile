#!/usr/bin/env bash
# Publish one yadm-owned User-scope Harness source for multiple agents.
set -euo pipefail
source_root="${XDG_CONFIG_HOME:-$HOME/.config}/agents/skills"

names=(harness-verify failure-to-eval)
roots=("$HOME/.claude/skills" "$HOME/.agents/skills" "$HOME/.gemini/antigravity-cli/skills")

for name in "${names[@]}"; do
    [[ -f "$source_root/$name/SKILL.md" ]] || {
        echo "Missing Harness source skill: $name" >&2
        exit 1
    }
done

# Preflight every target before creating any link. Never overwrite user Skills.
for root in "${roots[@]}"; do
    for name in "${names[@]}"; do
        target="$root/$name"
        source="$source_root/$name"
        if [[ -L "$target" ]]; then
            [[ "$(realpath -e -- "$target" 2>/dev/null)" == "$(realpath -e -- "$source")" ]] || {
                echo "Conflicting Harness skill link: $target" >&2
                exit 1
            }
        elif [[ -e "$target" ]]; then
            echo "Refusing to overwrite existing Harness skill: $target" >&2
            exit 1
        fi
    done
done

for root in "${roots[@]}"; do
    mkdir -p "$root"
    for name in "${names[@]}"; do
        target="$root/$name"
        [[ -L "$target" ]] || ln -s -- "$source_root/$name" "$target"
    done
done

echo "Harness User skills ready (Claude Code, Codex, Antigravity CLI)"
