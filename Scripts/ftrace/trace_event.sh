#!/usr/bin/env bash
# Usage: $0 -e <event> [-e <event>...] -- <command> [args...]

TRACEFS=/sys/kernel/tracing

die()   { echo "$0: error: $1" >&2; exit 1; }
usage() { echo "Usage: $0 -e <event> [-e <event>...] -- <command> [args...]" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "must run as root"

events=()
exec_cmd=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e)         shift; [[ -n "$1" ]] || die "-e requires an argument"; events+=("$1") ;;
        --)         shift; exec_cmd=("$@"); break ;;
        -h|--help)  usage ;;
        *)          die "unknown flag: $1" ;;
    esac
    shift
done

[[ ${#exec_cmd[@]} -gt 0 ]] || die "missing -- <command>"
[[ ${#events[@]}   -gt 0 ]] || die "at least one -e <event> required"

sync_fifo=$(mktemp -u /tmp/ftrace_sync.XXXXXX)
mkfifo "$sync_fifo"

cleanup() {
    echo 0    > "$TRACEFS/tracing_on"
    echo ''   > "$TRACEFS/set_event"
    echo ''   > "$TRACEFS/set_event_pid"
    rm -f "$sync_fifo"
}
trap cleanup EXIT

# reset state
echo 'nop' > "$TRACEFS/current_tracer"
echo ''    > "$TRACEFS/set_event"
echo ''    > "$TRACEFS/set_event_pid"
echo ''    > "$TRACEFS/trace"

for event in "${events[@]}"; do
    echo "$event" >> "$TRACEFS/set_event" || die "unknown event: $event"
done

echo 1 > "$TRACEFS/tracing_on"

# start exec suspended on fifo, then set its pid before releasing it
{ read -r _ < "$sync_fifo"; exec "${exec_cmd[@]}"; } &
exec_pid=$!

echo "$exec_pid" > "$TRACEFS/set_event_pid"
echo go > "$sync_fifo"

cat "$TRACEFS/trace_pipe" &
pipe_pid=$!

wait "$exec_pid"
ret=$?

kill "$pipe_pid" 2>/dev/null
wait "$pipe_pid" 2>/dev/null

exit $ret
