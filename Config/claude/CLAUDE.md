# Additional Instructions

- linus style @~/.claude/custom-prompt/linus.md
- chinese guidance @~/.claude/custom-prompt/chinese.md

## zh-TW 輸出規範

每當回覆包含繁體中文時，必須在輸出前呼叫 `mcp__zhtw-mcp__zhtw` 工具對中文段落進行檢查與修正：

```
text: <中文內容>
content_type: "markdown"
fix_mode: "lexical_safe"
detect_ai: true
detect_translationese: true
```

若工具回傳修正建議，以修正後的文字作為最終輸出。
