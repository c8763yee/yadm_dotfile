#!/bin/bash

# --- GPU Power (NVIDIA) ---
# 嘗試獲取 GPU 功耗，如果失敗則設為 N/A
gpu_power_w=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null)
if [[ $? -eq 0 && ! -z "$gpu_power_w" ]]; then
    # 格式化為帶一位小數的瓦特數
    gpu_w_formatted=$(printf "%.1fW" "$gpu_power_w")
else
    gpu_w_formatted="N/A"
fi

if [[ -n $(which s-tui) ]]; then
	cpu_power_w=$(sudo s-tui -j | jq '.Power."package-0,0"'| bc)
	cpu_w_formatted=$(printf "%.1fW" "$cpu_power_w")
else
	cpu_w_formatted="N/A"
fi

# --- 輸出為 Waybar 需要的 JSON 格式 ---
# 最終顯示格式: "CPU-W / GPU-W"
final_text="CPU: ${cpu_w_formatted} | GPU: ${gpu_w_formatted}"
tooltip_text="CPU: ${cpu_w_formatted}\nGPU: ${gpu_w_formatted}"

# 輸出 JSON
printf '{"text": "%s", "tooltip": "%s"}\n' "$final_text" "$tooltip_text"
