# Global Instructions

Before doing any work, read and follow these shared instruction files:

- @~/.config/agents/prompts/linus.md
- @~/.config/agents/prompts/chinese.md

## zh-TW Output Requirements

Whenever a response contains Traditional Chinese, call the `zhtw` tool of the
`zhtw-mcp` MCP server before the final response
(Claude Code: `mcp__zhtw-mcp__zhtw`, Codex: `mcp__zhtw_mcp.zhtw`) with:

```yaml
text: <Chinese content>
content_type: markdown
fix_mode: lexical_safe
detect_ai: true
detect_translationese: true
```

Use the corrected text when the tool returns corrections.

## Pre-implementation Adversarial Review

For nontrivial engineering tasks, read and follow
`~/.config/agents/prompts/adversarial.md` when its review triggers apply.

Use the platform's native `logic-adversary` subagent when available.
Complete the bounded design review before changing implementation files.
The main agent owns adjudication, implementation, and compatibility.

If no independent subagent can run, explicitly label the process
*Self-review*. Never claim independent verification that did not occur.

## Pensieve initialization for each project

For the first substantive task in a writable standalone Git repository, the
main agent MUST locate the actual repository root and check
`<repo>/.pensieve/state.md`. This user-scope rule authorizes one-time
initialization: if `.pensieve/` is absent, run
`pensieve-init --project "<absolute-repository-root>"` before project work.
If `.pensieve/` exists without `state.md`, report the incomplete state
instead of overwriting it. Never reinitialize an already initialized project.

Do not run initialization from bootstrap, startup hooks, or subagents. Skip
chat-only requests, non-Git and read-only directories, `$HOME` (the live yadm
working tree), `/`, and `/tmp`. Do not invent alternative roots to bypass
those restrictions. When tools or permission are missing, explicitly report
NOT RUN and continue with the original task when safe.
