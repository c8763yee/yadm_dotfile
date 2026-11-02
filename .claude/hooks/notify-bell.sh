#!/usr/bin/env bash
# Ring the terminal bell of whoever is attached to this tmux server.
# Writes straight to each client tty, so it works from hooks (no controlling
# tty) and for both local (Konsole/Kitty) and SSH (Windows Terminal) clients.
# Never fails: a missed notification must not break the calling hook.
if [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
  tmux list-clients -F '#{client_tty}' 2>/dev/null | while read -r tty; do
    [ -w "$tty" ] && printf '\a' >"$tty"
  done
elif [ -w /dev/tty ]; then
  printf '\a' >/dev/tty
fi
exit 0
