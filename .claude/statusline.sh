#!/bin/bash
input=$(cat)

DIR=$(echo "$input" | jq -r '.workspace.current_dir')
DIR_NAME="${DIR##*/}"
BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
MODEL=$(echo "$input" | jq -r '.model.display_name')
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')

LINE1="📁 ${DIR_NAME}"
[ -n "$BRANCH" ] && LINE1="${LINE1} | 🌿 ${BRANCH}"
if [ -n "$EFFORT" ]; then
  LINE1="${LINE1} | 🤖 ${MODEL} (${EFFORT})"
else
  LINE1="${LINE1} | 🤖 ${MODEL}"
fi

IN_TOK=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
OUT_TOK=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
CTX_REMAIN=$(echo "$input" | jq -r '.context_window.remaining_percentage // 0' | cut -d. -f1)
FIVE_HR=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // 0' | cut -d. -f1)
WEEKLY=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // 0' | cut -d. -f1)

LINE2="🔢 $((IN_TOK + OUT_TOK)) tokens | 🧠 ${CTX_REMAIN}% context left | ⏱ 5h: ${FIVE_HR}% | 📅 week: ${WEEKLY}%"

COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
COST_FMT=$(printf "%.4f" "$COST")

LINE3="💰 \$${COST_FMT} | ⬆ in: ${IN_TOK} | ⬇ out: ${OUT_TOK}"

printf '%s\n%s\n%s\n' "$LINE1" "$LINE2" "$LINE3"
