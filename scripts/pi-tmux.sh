#!/usr/bin/env bash

set -Eeuo pipefail

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  start   Start this directory's tmux session with pi -r, without attaching.
  attach  Attach to this directory's existing tmux session.
  open    Start when needed, then attach. This is the default command.
  status  Show this directory's tmux session state.
  stop    Stop this directory's tmux session.

Environment:
  PI_TMUX_CWD      Override the project directory.
  PI_TMUX_SESSION  Override the generated tmux session name.
  PI_TMUX_WINDOW   Override the tmux window name (default: pi).
EOF
}

command -v tmux >/dev/null 2>&1 || die 'tmux is not installed'
command -v cksum >/dev/null 2>&1 || die 'cksum is not installed'

readonly WORKDIR="${PI_TMUX_CWD:-$(pwd -P)}"
readonly WINDOW="${PI_TMUX_WINDOW:-pi}"
[[ -d "$WORKDIR" ]] || die "working directory does not exist: $WORKDIR"

SESSION_LABEL="${WORKDIR##*/}"
SESSION_LABEL="${SESSION_LABEL//[^[:alnum:]_-]/-}"
SESSION_LABEL="${SESSION_LABEL:0:32}"
[[ -n "$SESSION_LABEL" ]] || SESSION_LABEL=root
read -r SESSION_HASH _ < <(printf '%s' "$WORKDIR" | cksum)

readonly SESSION_LABEL
readonly SESSION_HASH
readonly SESSION="${PI_TMUX_SESSION:-pi-${SESSION_LABEL}-${SESSION_HASH}}"

session_exists() {
    tmux has-session -t "$SESSION" 2>/dev/null
}

require_session() {
    session_exists || die "tmux session is not running for $WORKDIR; run '$(basename "$0") start' first"
}

require_interactive_terminal() {
    [[ -t 0 && -t 1 ]] || die 'attach requires an interactive terminal'
}

start_session() {
    local pi_bin
    local start_command

    if session_exists; then
        printf 'tmux session already running: %s\n' "$SESSION"
        return
    fi

    pi_bin="$(command -v pi)" || die 'pi is not available on PATH'
    printf -v start_command 'exec %q -r' "$pi_bin"

    tmux new-session -d \
        -s "$SESSION" \
        -n "$WINDOW" \
        -c "$WORKDIR" \
        "$start_command"
    tmux set-option -t "$SESSION" mouse on >/dev/null

    printf 'tmux session started: %s\n' "$SESSION"
}

attach_session() {
    require_session
    require_interactive_terminal

    if [[ -n "${TMUX:-}" ]]; then
        exec tmux switch-client -t "$SESSION"
    fi

    exec tmux attach-session -t "$SESSION"
}

show_status() {
    local attached
    local command

    printf 'Directory: %s\nSession: %s\n' "$WORKDIR" "$SESSION"
    if ! session_exists; then
        printf 'State: stopped\n'
        return
    fi

    attached="$(tmux display-message -p -t "$SESSION" '#{session_attached}')"
    command="$(tmux display-message -p -t "$SESSION" '#{pane_current_command}')"
    printf 'State: running\nCommand: %s\nAttached clients: %s\n' "$command" "$attached"
}

stop_session() {
    if ! session_exists; then
        printf 'tmux session already stopped: %s\n' "$SESSION"
        return
    fi

    tmux kill-session -t "$SESSION"
    printf 'tmux session stopped: %s\n' "$SESSION"
}

main() {
    local action="${1:-open}"

    if (($# > 0)); then
        shift
    fi
    (($# == 0)) || die "unexpected arguments: $*"

    case "$action" in
        start)
            start_session
            ;;
        attach)
            attach_session
            ;;
        open)
            require_interactive_terminal
            start_session
            attach_session
            ;;
        status)
            show_status
            ;;
        stop)
            stop_session
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            usage >&2
            die "unknown command: $action"
            ;;
    esac
}

main "$@"
