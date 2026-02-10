#!/bin/bash
STATE="${XDG_RUNTIME_DIR:-/tmp}/power_state"

# Read previous and current CPU energy
prev=$(cat "$STATE" 2>/dev/null || echo 0)
curr=$(cat /sys/class/powercap/intel-rapl:0/energy_uj 2>/dev/null || echo 0)
echo "$curr" > "$STATE"

# Calculate CPU watts (needs floating point)
cpu=$(awk -v c="$curr" -v p="$prev" 'BEGIN {
    if (c > 0 && p > 0) printf "%.2f", (c - p) / 1000000
}')

# Get GPU watts
gpu=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null)
[[ -n "$gpu" ]] && gpu=$(printf "%.2f" "$gpu")

# Format output
cpu_text="${cpu:+${cpu}W}"
gpu_text="${gpu:+${gpu}W}"

printf '{"text":"CPU: %s | GPU: %s","tooltip":"CPU: %s\\nGPU: %s"}\n' \
    "${cpu_text:-N/A}" "${gpu_text:-N/A}" "${cpu_text:-N/A}" "${gpu_text:-N/A}"
