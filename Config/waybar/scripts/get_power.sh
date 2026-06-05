#!/bin/bash
# Pure reader. The watts are computed by power_daemon.sh; this just emits the
# latest snapshot. waybar runs it once per monitor, so it must stay stateless —
# no shared file to race on.
OUT="${XDG_RUNTIME_DIR:-/tmp}/power_draw.json"
cat "$OUT" 2>/dev/null \
    || echo '{"text":"CPU: N/A | GPU: N/A","tooltip":"CPU: N/A\nGPU: N/A"}'
