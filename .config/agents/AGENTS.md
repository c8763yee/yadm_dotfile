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
