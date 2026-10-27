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
