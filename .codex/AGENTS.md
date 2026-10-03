# Global Instructions

Before doing any work, read and follow these shared instruction files:

- `$HOME/.claude/custom-prompt/linus.md`
- `$HOME/.claude/custom-prompt/chinese.md`

## zh-TW Output Requirements

Whenever a response contains Traditional Chinese, call the
`mcp__zhtw_mcp.zhtw` tool before the final response with:

```yaml
text: <Chinese content>
content_type: markdown
fix_mode: lexical_safe
detect_ai: true
detect_translationese: true
```

Use the corrected text when the tool returns corrections.

Treat Claude-specific syntax or tool names in the shared files as intent, and
use the equivalent Codex capability when available.
