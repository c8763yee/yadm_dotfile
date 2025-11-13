#!/bin/bash

# --- GPU Power (NVIDIA) ---
# Trying to get GPU power consumption using nvidia-smi
gpu_w_formatted="N/A"
gpu_power_w=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null)
if [[ $? -eq 0 && ! -z "$gpu_power_w" ]]; then
    gpu_w_formatted=$(printf "%.2fW" "$gpu_power_w")
fi

cpu_w_formatted="N/A"
PREVIOUS_POWER_FILE="/tmp/previous_cpu_power_uj"

# TODO: Write a kernel module to get previous power reading instead of using a temp file.
current_uj=$(sudo cat /sys/class/powercap/intel-rapl:0/energy_uj)
if [[ -f "$PREVIOUS_POWER_FILE" ]]; then
    previous_uj=$(cat "$PREVIOUS_POWER_FILE")
    cpu_power_w=$(echo "scale=2; ($current_uj - $previous_uj) / 1000000" | bc)
    cpu_w_formatted=$(printf "%.2fW" "$cpu_power_w")
fi
echo "$current_uj" > "$PREVIOUS_POWER_FILE"

# "CPU-W / GPU-W"
final_text="CPU: ${cpu_w_formatted} | GPU: ${gpu_w_formatted}"
tooltip_text="CPU: ${cpu_w_formatted}\nGPU: ${gpu_w_formatted}"

# Convert data to Waybar JSON format
printf '{"text": "%s", "tooltip": "%s"}\n' "$final_text" "$tooltip_text"
