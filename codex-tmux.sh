#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "${BASH_SOURCE[0]}")"
readonly WORKDIR="$(pwd -P)"

SESSION_LABEL="${WORKDIR##*/}"
SESSION_LABEL="${SESSION_LABEL//[^[:alnum:]_-]/-}"
SESSION_LABEL="${SESSION_LABEL:0:32}"
[[ -n "$SESSION_LABEL" ]] || SESSION_LABEL=root
read -r SESSION_HASH _ < <(printf '%s' "$WORKDIR" | cksum)

readonly SESSION_LABEL
readonly SESSION_HASH
readonly SESSION="${CODEX_TMUX_SESSION:-codex-${SESSION_LABEL}-${SESSION_HASH}}"
readonly WINDOW="${CODEX_TMUX_WINDOW:-codex}"
readonly WATCH_SESSION="${SESSION}-capacity-watch"
readonly CODEX_START_COMMAND="${CODEX_START_COMMAND:-cr}"
readonly CHECK_SECONDS="${CODEX_CAPACITY_CHECK_SECONDS:-5}"
readonly RETRY_SECONDS="${CODEX_CAPACITY_RETRY_SECONDS:-60}"

readonly CAPACITY_MESSAGE='Selected model is at capacity. Please try a different model.'
readonly CONTENT_BLOCKED_TITLE="This content can't be shown"
readonly CONTENT_BLOCKED_MESSAGE='We take extra caution with cybersecurity requests. If you’re a security professional, you may be able to apply for Trusted Access.'
readonly RESUME_COMMAND='/goal resume'
readonly RESUME_SUCCESS_MESSAGE='Goal active'
readonly RESUME_FAILURE_MESSAGE='Failed to update thread goal: thread/goal/set failed in TUI'
readonly SAFETY_CHECK_MESSAGE='Additional safety checks'
readonly SAFETY_WAIT_OPTION='Keep waiting'
readonly SAFETY_CONFIRM_MESSAGE='Press enter to confirm or esc to go back'

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage:
  $(basename "$0") start [codex arguments...]
  $(basename "$0") away
  $(basename "$0") back
  $(basename "$0") status
  $(basename "$0") monitor-off

Commands:
  start        Start this directory's Codex, disable monitoring, and attach.
  away         Enable capacity monitoring without detaching.
  back         Disable monitoring and attach only when currently detached.
  status       Show the Codex and monitor state.
  monitor-off  Disable monitoring without attaching.

Each working directory uses a separate Codex thread and tmux session.

Environment:
  CODEX_TMUX_SESSION                 Override the directory-based session name
  CODEX_TMUX_WINDOW                  Window name (default: codex)
  CODEX_START_COMMAND                Interactive Bash command (default: cr)
  CODEX_CAPACITY_CHECK_SECONDS       Detection interval (default: 5)
  CODEX_CAPACITY_RETRY_SECONDS       Resume retry interval (default: 60)
EOF
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "command not found: $1"
}

validate_seconds() {
    local name="$1"
    local value="$2"

    [[ "$value" =~ ^[1-9][0-9]*$ ]] || die "$name must be a positive integer"
}

session_exists() {
    tmux has-session -t "$SESSION" 2>/dev/null
}

watcher_exists() {
    tmux has-session -t "$WATCH_SESSION" 2>/dev/null
}

require_session() {
    session_exists || die "Codex tmux session is not running; run '$0 start' first"
}

managed_pane() {
    local pane

    pane="$(tmux show-environment -t "$SESSION" CODEX_TMUX_PANE 2>/dev/null)" ||
        die "tmux session '$SESSION' was not created by this script"
    pane="${pane#CODEX_TMUX_PANE=}"

    tmux display-message -p -t "$pane" '#{pane_id}' >/dev/null 2>&1 ||
        die "the managed Codex pane no longer exists"

    printf '%s\n' "$pane"
}

create_session() {
    local command
    local pane
    local argument
    local quoted_argument
    local start_command="$CODEX_START_COMMAND"

    for argument in "$@"; do
        printf -v quoted_argument '%q' "$argument"
        start_command+=" $quoted_argument"
    done

    printf -v command 'exec bash -ic %q' "$start_command"
    tmux new-session -d -s "$SESSION" -n "$WINDOW" -c "$WORKDIR" "$command"

    pane="$(tmux display-message -p -t "$SESSION:$WINDOW" '#{pane_id}')"
    tmux set-environment -t "$SESSION" CODEX_TMUX_PANE "$pane"
    tmux set-option -w -t "$SESSION:$WINDOW" automatic-rename off >/dev/null
}

ensure_session() {
    if session_exists; then
        (($# == 0)) || die "Codex is already running; start arguments only apply to a new session"
        managed_pane >/dev/null
        return
    fi

    create_session "$@"
}

stop_watcher() {
    if watcher_exists; then
        tmux kill-session -t "$WATCH_SESSION"
    fi
}

start_watcher() {
    local pane
    local command

    if watcher_exists; then
        return
    fi

    pane="$(managed_pane)"
    printf -v command '%q ' bash "$SCRIPT_PATH" __monitor \
        "$SESSION" "$pane" "$CHECK_SECONDS" "$RETRY_SECONDS"

    tmux new-session -d -s "$WATCH_SESSION" -n monitor "$command"
}

attach_session() {
    tmux set-option -t "$SESSION" mouse on >/dev/null

    if [[ ! -t 0 || ! -t 1 ]]; then
        return
    fi

    tmux select-window -t "$SESSION:$WINDOW"

    if [[ -n "${TMUX:-}" ]]; then
        tmux switch-client -t "$SESSION"
        return
    fi

    exec tmux attach-session -t "$SESSION"
}

away_mode() {
    require_session
    validate_seconds CODEX_CAPACITY_CHECK_SECONDS "$CHECK_SECONDS"
    validate_seconds CODEX_CAPACITY_RETRY_SECONDS "$RETRY_SECONDS"

    start_watcher

    printf 'away monitoring enabled for tmux session %s\n' "$SESSION"
}

back_mode() {
    local attached

    require_session
    stop_watcher
    attached="$(tmux display-message -p -t "$SESSION" '#{session_attached}')"

    if ((attached > 0)); then
        printf 'away monitoring disabled; tmux session remains attached\n'
        return
    fi

    attach_session
}

show_status() {
    local pane
    local attached
    local command

    printf 'Directory: %s\nSession: %s\n' "$WORKDIR" "$SESSION"

    if ! session_exists; then
        printf 'Codex: stopped\nMonitor: stopped\n'
        return
    fi

    pane="$(managed_pane)"
    attached="$(tmux display-message -p -t "$SESSION" '#{session_attached}')"
    command="$(tmux display-message -p -t "$pane" '#{pane_current_command}')"

    printf 'Codex: running (%s, attached clients: %s)\n' "$command" "$attached"

    if watcher_exists; then
        printf 'Monitor: enabled (check: %ss, retry: %ss)\n' "$CHECK_SECONDS" "$RETRY_SECONDS"
    else
        printf 'Monitor: stopped\n'
    fi
}

capture_screen() {
    tmux capture-pane -p -J -t "$1" 2>/dev/null || true
}

send_resume() {
    local pane="$1"

    tmux send-keys -t "$pane" C-u
    sleep 0.1
    tmux send-keys -t "$pane" -l "$RESUME_COMMAND"
    sleep 0.2
    tmux send-keys -t "$pane" Enter
    printf '%s sent %s\n' "$(date '+%F %T')" "$RESUME_COMMAND"
}

confirm_safety_wait() {
    local pane="$1"

    tmux send-keys -t "$pane" Enter
    printf '%s confirmed safety wait\n' "$(date '+%F %T')"
}

latest_screen_state() {
    local screen="$1"
    local line
    local state=idle
    local content_blocked=false
    local safety_dialog=false

    if [[ "$screen" == *"$CONTENT_BLOCKED_TITLE"* ]] &&
        [[ "$screen" == *"$CONTENT_BLOCKED_MESSAGE"* ]]; then
        content_blocked=true
    fi

    if [[ "$screen" == *"$SAFETY_CHECK_MESSAGE"* ]] &&
        [[ "$screen" == *"$SAFETY_WAIT_OPTION"* ]] &&
        [[ "$screen" == *"$SAFETY_CONFIRM_MESSAGE"* ]]; then
        safety_dialog=true
    fi

    while IFS= read -r line; do
        if [[ "$line" == *"$CAPACITY_MESSAGE"* ]]; then
            state=needs_resume
        fi

        if [[ "$content_blocked" == true ]] &&
            [[ "$line" == *"$CONTENT_BLOCKED_MESSAGE"* ]]; then
            state=needs_resume
        fi

        if [[ "$line" == *"$RESUME_SUCCESS_MESSAGE"* ]]; then
            state=resume_succeeded
        fi

        if [[ "$line" == *"$RESUME_FAILURE_MESSAGE"* ]]; then
            state=goal_missing
        fi

        if [[ "$safety_dialog" == true ]] &&
            [[ "$line" == *"$SAFETY_CONFIRM_MESSAGE"* ]]; then
            state=safety_wait
        fi
    done <<<"$screen"

    printf '%s\n' "$state"
}

monitor_loop() {
    local session="$1"
    local pane="$2"
    local check_seconds="$3"
    local retry_seconds="$4"
    local screen
    local state
    local previous_state=idle
    local last_send=0

    validate_seconds check_seconds "$check_seconds"
    validate_seconds retry_seconds "$retry_seconds"

    while tmux has-session -t "$session" 2>/dev/null; do
        if ! tmux display-message -p -t "$pane" '#{pane_id}' >/dev/null 2>&1; then
            return
        fi

        screen="$(capture_screen "$pane")"
        state="$(latest_screen_state "$screen")"

        case "$state" in
            safety_wait)
                if [[ "$previous_state" != safety_wait ]]; then
                    confirm_safety_wait "$pane"
                fi
                ;;

            needs_resume)
                if [[ "$previous_state" != needs_resume ]] ||
                    ((SECONDS - last_send >= retry_seconds)); then
                    send_resume "$pane"
                    last_send=$SECONDS
                fi
                ;;
        esac

        previous_state="$state"
        sleep "$check_seconds"
    done
}

main() {
    local action="${1:-start}"

    if (($# > 0)); then
        shift
    fi

    require_command tmux

    case "$action" in
        start)
            stop_watcher
            ensure_session "$@"
            attach_session
            ;;

        away)
            (($# == 0)) || die "away does not accept arguments"
            away_mode
            ;;

        back)
            (($# == 0)) || die "back does not accept arguments"
            back_mode
            ;;

        status)
            (($# == 0)) || die "status does not accept arguments"
            show_status
            ;;

        monitor-off)
            (($# == 0)) || die "monitor-off does not accept arguments"
            stop_watcher
            printf 'away monitoring disabled\n'
            ;;

        __monitor)
            (($# == 4)) || die "invalid internal monitor arguments"
            monitor_loop "$@"
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
