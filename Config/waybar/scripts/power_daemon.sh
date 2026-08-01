#!/bin/bash
# Compatibility entry point for existing Waybar/systemd installations.
exec "$HOME/.local/bin/power-monitor-daemon" "$@"
