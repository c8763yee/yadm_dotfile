#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fcitx5_interpolation="\#{fcitx5}"

set_tmux_option() {
  local option=$1
  local value=$2
  tmux set-option -gq "$option" "$value"
}

get_tmux_option() {
  local option
  local default_value
  local option_value
  option="$1"
  default_value="$2"
  option_value="$(tmux show-option -qv "$option")"
  if [ -z "$option_value" ]; then
    option_value="$(tmux show-option -gqv "$option")"
  fi
  if [ -z "$option_value" ]; then
    echo "$default_value"
  else
    echo "$option_value"
  fi
}

do_interpolation() {
  local all_interpolated="$1"
  value=$(get_tmux_option "@fcitx5")
  all_interpolated=${all_interpolated//${fcitx5_interpolation}/${value}}
  echo "$all_interpolated"
}

update_tmux_option() {
  local option
  local option_value
  local new_option_value
  option=$1
  option_value=$(get_tmux_option "$option")
  new_option_value=$(do_interpolation "$option_value")
  set_tmux_option "$option" "$new_option_value"
}

to_ascii() {
    LC_CTYPE=C printf "%d" "'$1'"
}

main() {
    dbus-send --session --print-reply --dest=org.freedesktop.DBus \
        /org/freedesktop/DBus org.freedesktop.DBus.StartServiceByName \
        string:org.fcitx.Fcitx5 uint32:0 >/dev/null || return 1
    pid=$(tmux display-message -pF '#{pid}')
    tmux run -b "/usr/libexec/fcitx5-tmux $pid"
    declare -A KEYS=(
        [F1]=0xffbe
        [F2]=0xffbf
        [F3]=0xffc0
        [F4]=0xffc1
        [F5]=0xffc2
        [F6]=0xffc3
        [F7]=0xffc4
        [F8]=0xffc5
        [F9]=0xffc6
        [F10]=0xffc7
        [F11]=0xffc8
        [F12]=0xffc9
        [Insert]=0xff63
        [Delete]=0xffff
        [Home]=0xff50
        [End]=0xff57
        [PageDown]=0xff56
        [PageUp]=0xff55
        [Tab]=0xff09
        [Space]=0x0020
        [BSpace]=0xff08
        [Enter]=0xff0d
        [Escape]=0xff1b
        [Up]=0xff52
        [Down]=0xff54
        [Left]=0xff51
        [Right]=0xff53
        [KP/]=0xffaf
        [KP*]=0xffaa
        [KP-]=0xffad
        [KP7]=0xffb7
        [KP8]=0xffb8
        [KP9]=0xffb9
        [KP+]=0xffab
        [KP4]=0xffb4
        [KP5]=0xffb5
        [KP6]=0xffb6
        [KP1]=0xffb1
        [KP2]=0xffb2
        [KP3]=0xffb3
        [KPEnter]=0xff8d
        [KP0]=0xffb0
        [KP.]=0xffae
    )
    local KEY BIND_KEY VALUE STATE MODIFIERS BASE_STATE i
    local -a PRINTABLE_KEYS=(
        "abcdefghijklmnopqrstuvwxyz0123456789,./;'[]-=\\\`"
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*()_+{}|:"<>?~'
    )
    for BASE_STATE in 0 1; do
        for ((i = 0; i < ${#PRINTABLE_KEYS[BASE_STATE]}; i++)); do
            KEY=${PRINTABLE_KEYS[BASE_STATE]:i:1}
            VALUE=$(to_ascii "$KEY")
            for MODIFIERS in '' C- M- M-C-; do
                STATE=$BASE_STATE
                case "$MODIFIERS" in
                    C-) STATE=$((STATE | 4)) ;;
                    M-) STATE=$((STATE | 8)) ;;
                    M-C-) STATE=$((STATE | 12)) ;;
                esac
                BIND_KEY="$MODIFIERS$KEY"
                if [[ $KEY == ';' ]]; then
                    BIND_KEY="${MODIFIERS}\\;"
                fi
                tmux bind-key -n "$BIND_KEY" run "dbus-send --print-reply=literal --dest=org.fcitx.Fcitx5.Tmux-$pid /tmux org.fcitx.Fcitx.TmuxProxy.ProcessKeyEvent uint32:$VALUE uint32:$STATE"
            done
        done
    done

    for KEY in "${!KEYS[@]}"; do
        VALUE=${KEYS[$KEY]}
        tmux bind-key -n ${KEY} run "dbus-send --print-reply=literal --dest=org.fcitx.Fcitx5.Tmux-$pid /tmux org.fcitx.Fcitx.TmuxProxy.ProcessKeyEvent uint32:$VALUE uint32:0"
        tmux bind-key -n C-${KEY} run "dbus-send --print-reply=literal --dest=org.fcitx.Fcitx5.Tmux-$pid /tmux org.fcitx.Fcitx.TmuxProxy.ProcessKeyEvent uint32:$VALUE uint32:4"
        tmux bind-key -n M-${KEY} run "dbus-send --print-reply=literal --dest=org.fcitx.Fcitx5.Tmux-$pid /tmux org.fcitx.Fcitx.TmuxProxy.ProcessKeyEvent uint32:$VALUE uint32:8"
        tmux bind-key -n M-C-${KEY} run "dbus-send --print-reply=literal --dest=org.fcitx.Fcitx5.Tmux-$pid /tmux org.fcitx.Fcitx.TmuxProxy.ProcessKeyEvent uint32:$VALUE uint32:12"
    done
}
main
