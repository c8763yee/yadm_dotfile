#!/bin/bash
# Single writer for CPU/GPU power draw.
# waybar spawns one exec per monitor, so letting each instance compute the RAPL
# delta means several processes racing on one energy-counter state file — the
# deltas get split and the watts read low. This daemon is the only owner of that
# state; every waybar instance just reads the result via get_power.sh.
set -u

RAPL=/sys/class/powercap/intel-rapl/intel-rapl:0
OUT="${XDG_RUNTIME_DIR:-/tmp}/power_draw.json"
TMP="$OUT.tmp"

max=$(sudo -n cat "$RAPL/max_energy_range_uj" 2>/dev/null || echo 0)

prev_e=0
prev_t=0

while :; do
    curr_e=$(sudo -n cat "$RAPL/energy_uj" 2>/dev/null || echo 0)
    curr_t=$(date +%s.%N)

    # watts = ΔE / Δt. Measure Δt instead of trusting the sleep, and fold the
    # counter wraparound into ΔE — both kill a special case the consumer would
    # otherwise have to guess at.
    cpu=$(awk -v ce="$curr_e" -v pe="$prev_e" -v ct="$curr_t" -v pt="$prev_t" -v m="$max" 'BEGIN {
        if (pe > 0 && ce > 0 && pt > 0) {
            de = ce - pe
            if (de < 0) de += m
            dt = ct - pt
            if (dt > 0) printf "%.2f", de / 1000000 / dt
        }
    }')

    prev_e=$curr_e
    prev_t=$curr_t

    gpu=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null)
    [[ -n "$gpu" ]] && gpu=$(printf "%.2f" "$gpu")

    cpu_text="${cpu:+${cpu}W}"
    gpu_text="${gpu:+${gpu}W}"

    printf '{"text":"CPU: %s | GPU: %s","tooltip":"CPU: %s\\nGPU: %s"}\n' \
        "${cpu_text:-N/A}" "${gpu_text:-N/A}" "${cpu_text:-N/A}" "${gpu_text:-N/A}" > "$TMP"
    mv -f "$TMP" "$OUT"

    sleep 1
done
