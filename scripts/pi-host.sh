#!/usr/bin/env bash

set -Eeuo pipefail

readonly SSH_TARGET="${PI_HOST_SSH_TARGET:-Arianrhod@10.238.0.117}"
readonly WSL_DISTRO="${PI_HOST_WSL_DISTRO:-Ubuntu-22.04}"

[[ "$SSH_TARGET" != *[[:space:]]* ]] || {
    printf 'error: PI_HOST_SSH_TARGET must not contain whitespace\n' >&2
    exit 1
}
[[ "$WSL_DISTRO" =~ ^[[:alnum:]_.-]+$ ]] || {
    printf 'error: invalid PI_HOST_WSL_DISTRO: %s\n' "$WSL_DISTRO" >&2
    exit 1
}
exec env ssh \
    -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -t "$SSH_TARGET" \
    "wsl.exe -d $WSL_DISTRO"
