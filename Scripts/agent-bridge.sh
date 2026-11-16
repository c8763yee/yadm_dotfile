#!/usr/bin/env bash

export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
unset SSH_AGENT_PID

mkdir -p "$HOME/.ssh" 2>/dev/null || true
if [[ ! -w "$HOME/.ssh" ]]; then
    return 0 2>/dev/null || exit 0
fi

if ! ss -a 2>/dev/null | grep -Fq "$SSH_AUTH_SOCK"; then
    (
        flock -n 9 || exit 0
        if ! ss -a 2>/dev/null | grep -Fq "$SSH_AUTH_SOCK"; then
            rm -f "$SSH_AUTH_SOCK"
            setsid socat \
                UNIX-LISTEN:"$SSH_AUTH_SOCK",fork \
                EXEC:"/mnt/c/Users/c8763yee/AppData/Local/Microsoft/WinGet/Packages/albertony.npiperelay_Microsoft.Winget.Source_8wekyb3d8bbwe/npiperelay.exe -ei -s //./pipe/openssh-ssh-agent",nofork >/dev/null 2>&1 &
        fi
    ) 9>"$HOME/.ssh/agent.sock.lock"
fi
