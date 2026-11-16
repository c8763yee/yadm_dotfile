#!/usr/bin/env bash
# Install Ponytail through native user-scope plugins, not shared skill symlinks.
set -euo pipefail

for executable in node jq claude; do
    command -v "$executable" >/dev/null 2>&1 || {
        echo "Ponytail installation requires $executable on PATH" >&2
        exit 1
    }
done

# Claude Code >= 2.1.292 supports single-step marketplace installation.
# This command is safe to repeat when the plugin is already installed.
claude plugin install ponytail --marketplace DietrichGebert/ponytail --scope user

# Codex may be installed after the initial bootstrap on some hosts.
if ! command -v codex >/dev/null 2>&1; then
    echo "Codex not installed; rerun install-ponytail.sh after installing it" >&2
    exit 0
fi

if ! codex plugin marketplace list --json |
    jq -e 'any(.marketplaces[]?; .name == "ponytail")' >/dev/null; then
    codex plugin marketplace add DietrichGebert/ponytail
fi

if ! codex plugin list --json |
    jq -e 'any(.installed[]?; .name == "ponytail" and .marketplaceName == "ponytail")' >/dev/null; then
    codex plugin add ponytail@ponytail
fi

echo "Ponytail installed for Claude Code and Codex"
