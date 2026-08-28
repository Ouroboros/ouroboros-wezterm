#!/usr/bin/env bash

set -Eeuo pipefail

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [--tmux38] <command>

Options:
  --tmux38  Use the pinned tmux next-3.8 build on the pi-3.8 socket.

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
  PI_TMUX_BIN       Override the tmux 3.7c binary.
  PI_TMUX_SOCKET    Override the tmux 3.7c socket name (default: pi-3.7c).
  PI_TMUX38_BIN     Override the tmux next-3.8 binary.
  PI_TMUX38_SOCKET  Override the tmux next-3.8 socket name (default: pi-3.8).
EOF
}

readonly DEFAULT_TMUX_BIN='/usr/local/bin/tmux'
readonly DEFAULT_TMUX_SOCKET='pi-3.7c'
readonly DEFAULT_TMUX38_BIN='/root/.local/src/tmux-3.8-dev-40381bdc/tmux'
readonly DEFAULT_TMUX38_SOCKET='pi-3.8'

USE_TMUX38=false
TMUX_BIN=''
TMUX_SOCKET=''
TMUX_LABEL=''
TMUX_ARGS=()

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

configure_tmux() {
    local expected_version
    local version

    if "$USE_TMUX38"; then
        TMUX_BIN="${PI_TMUX38_BIN:-$DEFAULT_TMUX38_BIN}"
        TMUX_SOCKET="${PI_TMUX38_SOCKET:-$DEFAULT_TMUX38_SOCKET}"
        TMUX_LABEL='tmux next-3.8'
        expected_version='tmux next-3.8'
    else
        TMUX_BIN="${PI_TMUX_BIN:-$DEFAULT_TMUX_BIN}"
        TMUX_SOCKET="${PI_TMUX_SOCKET:-$DEFAULT_TMUX_SOCKET}"
        TMUX_LABEL='tmux 3.7c'
        expected_version='tmux 3.7c'
    fi

    [[ -x "$TMUX_BIN" ]] || die "$TMUX_LABEL is not executable: $TMUX_BIN"
    [[ "$TMUX_SOCKET" =~ ^[[:alnum:]_.-]+$ ]] || die "invalid tmux socket name: $TMUX_SOCKET"
    version="$("$TMUX_BIN" -V)" || die "failed to execute tmux: $TMUX_BIN"
    [[ "$version" == "$expected_version" ]] || die "$expected_version is required, found: $version"
    TMUX_ARGS=(-L "$TMUX_SOCKET")
}

tmux_command() {
    "$TMUX_BIN" "${TMUX_ARGS[@]}" "$@"
}

session_exists() {
    tmux_command has-session -t "$SESSION" 2>/dev/null
}

stable_session_exists() {
    local stable_bin
    local stable_socket

    "$USE_TMUX38" || return 1
    stable_bin="${PI_TMUX_BIN:-$DEFAULT_TMUX_BIN}"
    stable_socket="${PI_TMUX_SOCKET:-$DEFAULT_TMUX_SOCKET}"
    [[ -x "$stable_bin" ]] || return 1
    "$stable_bin" -L "$stable_socket" has-session -t "$SESSION" 2>/dev/null
}

require_session() {
    session_exists || die "tmux session is not running for $WORKDIR; run '$(basename "$0") start' first"
}

require_interactive_terminal() {
    [[ -t 0 && -t 1 ]] || die 'attach requires an interactive terminal'
}

require_compatible_attach_context() {
    local current_socket
    local current_socket_name

    [[ -n "${TMUX:-}" ]] || return 0
    current_socket="${TMUX%%,*}"
    current_socket_name="${current_socket##*/}"
    [[ "$current_socket_name" == "$TMUX_SOCKET" ]] || die "detach the current tmux client before attaching to the $TMUX_LABEL server"
}

start_session() {
    local pi_bin
    local start_command

    if session_exists; then
        printf 'tmux session already running: %s\n' "$SESSION"
        return
    fi
    if stable_session_exists; then
        die "tmux 3.7c session is still running: $SESSION; stop it explicitly before starting --tmux38"
    fi

    pi_bin="$(command -v pi)" || die 'pi is not available on PATH'
    printf -v start_command 'exec %q -r' "$pi_bin"

    tmux_command new-session -d \
        -s "$SESSION" \
        -n "$WINDOW" \
        -c "$WORKDIR" \
        "$start_command"
    tmux_command set-option -t "$SESSION" mouse on >/dev/null

    printf 'tmux session started: %s\n' "$SESSION"
}

attach_session() {
    require_session
    require_interactive_terminal
    require_compatible_attach_context

    if [[ -n "${TMUX:-}" ]]; then
        exec "$TMUX_BIN" "${TMUX_ARGS[@]}" switch-client -t "$SESSION"
    fi

    exec "$TMUX_BIN" "${TMUX_ARGS[@]}" -T sync attach-session -t "$SESSION"
}

show_status() {
    local attached
    local command

    printf 'Directory: %s\nSession: %s\n' "$WORKDIR" "$SESSION"
    if ! session_exists; then
        printf 'State: stopped\n'
        return
    fi

    attached="$(tmux_command display-message -p -t "$SESSION" '#{session_attached}')"
    command="$(tmux_command display-message -p -t "$SESSION" '#{pane_current_command}')"
    printf 'State: running\nCommand: %s\nAttached clients: %s\n' "$command" "$attached"
}

stop_session() {
    if ! session_exists; then
        printf 'tmux session already stopped: %s\n' "$SESSION"
        return
    fi

    tmux_command kill-session -t "$SESSION"
    printf 'tmux session stopped: %s\n' "$SESSION"
}

main() {
    local action='open'
    local action_set=false

    while (($# > 0)); do
        case "$1" in
            --tmux38)
                USE_TMUX38=true
                ;;
            start|attach|open|status|stop|help|-h|--help)
                "$action_set" && die "unexpected argument: $1"
                action="$1"
                action_set=true
                ;;
            *)
                usage >&2
                die "unknown argument: $1"
                ;;
        esac
        shift
    done

    case "$action" in
        help|-h|--help)
            usage
            return
            ;;
    esac

    configure_tmux

    case "$action" in
        start)
            start_session
            ;;
        attach)
            attach_session
            ;;
        open)
            require_interactive_terminal
            require_compatible_attach_context
            start_session
            attach_session
            ;;
        status)
            show_status
            ;;
        stop)
            stop_session
            ;;
        *)
            die "unsupported command: $action"
            ;;
    esac
}

main "$@"
