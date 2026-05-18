#!/usr/bin/env bash
# Usage: $0 [-f <func>...] [-n <notrace_func>...] [-d <depth>] -- <command> [args...]

TRACEFS=/sys/kernel/tracing

die()   { echo "$0: error: $1" >&2; exit 1; }
usage() { echo "Usage: $0 [-f <func>...] [-n <notrace_func>...] [-d <depth>] -- <command> [args...]" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "must run as root"

funcs=()
notrace_funcs=()
depth=''
exec_cmd=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f)         shift; [[ -n "$1" ]] || die "-f requires an argument"; funcs+=("$1") ;;
        -n)         shift; [[ -n "$1" ]] || die "-n requires an argument"; notrace_funcs+=("$1") ;;
        -d)         shift; [[ "$1" =~ ^[0-9]+$ ]] || die "-d requires a positive integer"; depth="$1" ;;
        --)         shift; exec_cmd=("$@"); break ;;
        -h|--help)  usage ;;
        *)          die "unknown flag: $1" ;;
    esac
    shift
done

[[ ${#exec_cmd[@]} -gt 0 ]] || die "missing -- <command>"

sync_fifo=$(mktemp -u /tmp/ftrace_sync.XXXXXX)
mkfifo "$sync_fifo"

cleanup() {
    echo 0     > "$TRACEFS/tracing_on"
    echo ''    > "$TRACEFS/set_graph_function"
    echo ''    > "$TRACEFS/set_graph_notrace"
    echo ''    > "$TRACEFS/set_ftrace_pid"
    echo ''    > "$TRACEFS/set_event_pid"
    echo 'nop' > "$TRACEFS/current_tracer"
    rm -f "$sync_fifo"
}
trap cleanup EXIT

# reset state
echo 'nop' > "$TRACEFS/current_tracer"
echo ''    > "$TRACEFS/set_graph_function"
echo ''    > "$TRACEFS/set_graph_notrace"
echo ''    > "$TRACEFS/set_ftrace_pid"
echo ''    > "$TRACEFS/set_event_pid"
echo ''    > "$TRACEFS/trace"

if [[ ${#funcs[@]} -gt 0 ]]; then
    for func in "${funcs[@]}"; do
        echo "$func" >> "$TRACEFS/set_graph_function" || die "unknown function: $func"
    done
fi

for func in "${notrace_funcs[@]}"; do
    echo "$func" >> "$TRACEFS/set_graph_notrace"
done

[[ -n "$depth" ]] && echo "$depth" > "$TRACEFS/max_graph_depth"

echo 'function_graph' > "$TRACEFS/current_tracer"
echo 1 > "$TRACEFS/tracing_on"

{ read -r _ < "$sync_fifo"; exec "${exec_cmd[@]}"; } &
exec_pid=$!

echo "$exec_pid" > "$TRACEFS/set_ftrace_pid"
echo "$exec_pid" > "$TRACEFS/set_event_pid"
echo go > "$sync_fifo"

cat "$TRACEFS/trace_pipe" &
pipe_pid=$!

wait "$exec_pid"
ret=$?

kill "$pipe_pid" 2>/dev/null
wait "$pipe_pid" 2>/dev/null

exit $ret
