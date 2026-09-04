#!/usr/bin/env bash

set -Eeuo pipefail

readonly SSH_TARGET="${PI_HOST_SSH_TARGET:-Arianrhod@10.238.0.117}"
readonly WSL_DISTRO="${PI_HOST_WSL_DISTRO:-Ubuntu-22.04}"
readonly WSL_CWD="${PI_HOST_WSL_CWD:-$(pwd -P)}"
readonly SERVER_ALIVE_INTERVAL="${PI_HOST_SERVER_ALIVE_INTERVAL:-5}"
readonly SERVER_ALIVE_COUNT_MAX="${PI_HOST_SERVER_ALIVE_COUNT_MAX:-2}"

TTY_STATE=''

[[ "$SSH_TARGET" != *[[:space:]]* ]] || {
    printf 'error: PI_HOST_SSH_TARGET must not contain whitespace\n' >&2
    exit 1
}
[[ "$WSL_DISTRO" =~ ^[[:alnum:]_.-]+$ ]] || {
    printf 'error: invalid PI_HOST_WSL_DISTRO: %s\n' "$WSL_DISTRO" >&2
    exit 1
}
[[ "$WSL_CWD" == /* ]] || {
    printf 'error: WSL cwd must be an absolute path: %s\n' "$WSL_CWD" >&2
    exit 1
}
[[ "$SERVER_ALIVE_INTERVAL" =~ ^[1-9][0-9]*$ ]] || {
    printf 'error: PI_HOST_SERVER_ALIVE_INTERVAL must be a positive integer\n' >&2
    exit 1
}
[[ "$SERVER_ALIVE_COUNT_MAX" =~ ^[1-9][0-9]*$ ]] || {
    printf 'error: PI_HOST_SERVER_ALIVE_COUNT_MAX must be a positive integer\n' >&2
    exit 1
}
case "$WSL_CWD" in
    *['"&|<>^%!']*)
        printf 'error: WSL cwd contains unsupported Windows shell characters: %s\n' "$WSL_CWD" >&2
        exit 1
        ;;
esac

restore_terminal() {
    if [[ -w /dev/tty ]]; then
        printf '\033[?2026l\033[?9l\033[?1000l\033[?1001l\033[?1002l\033[?1003l\033[?1004l\033[?1005l\033[?1006l\033[?1015l\033[?1016l\033[?2004l\033[?9001l\033[>4;0m\033[<u\033[?1049l\033[?1047l\033[?47l\033[0m\033[?25h' > /dev/tty 2>/dev/null || true
        if [[ -n "$TTY_STATE" ]]; then
            stty "$TTY_STATE" < /dev/tty > /dev/tty 2>&1 || stty sane < /dev/tty > /dev/tty 2>&1 || true
        else
            stty sane < /dev/tty > /dev/tty 2>&1 || true
        fi
    fi
}

if command -v stty >/dev/null 2>&1 && [[ -t 0 || -t 1 ]]; then
    TTY_STATE="$(stty -g < /dev/tty 2>/dev/null || true)"
fi
trap restore_terminal EXIT

set +e
env ssh \
    -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=10 \
    -o ConnectionAttempts=1 \
    -o ServerAliveInterval="$SERVER_ALIVE_INTERVAL" \
    -o ServerAliveCountMax="$SERVER_ALIVE_COUNT_MAX" \
    -o TCPKeepAlive=yes \
    -o 'EscapeChar=~' \
    -tt "$SSH_TARGET" \
    "wsl.exe -d $WSL_DISTRO --cd \"$WSL_CWD\""
ssh_status=$?
set -e

restore_terminal
trap - EXIT
exit "$ssh_status"
