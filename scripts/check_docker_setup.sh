#!/usr/bin/env bash
set -euo pipefail

log() {
    printf '[INFO] %s\n' "$*"
}

warn() {
    printf '[WARN] %s\n' "$*" >&2
}

err() {
    printf '[ERROR] %s\n' "$*" >&2
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        err "Required command not found: $1"
        exit 1
    }
}

main() {
    need_cmd id
    need_cmd getent
    need_cmd stat

    local user group_exists sock="/var/run/docker.sock"
    user="${SUDO_USER:-$USER}"

    if ! command -v docker >/dev/null 2>&1; then
        err "docker command not found. Please install Docker first."
        exit 1
    fi

    if getent group docker >/dev/null 2>&1; then
        log "Group 'docker' already exists."
        group_exists=1
    else
        log "Group 'docker' does not exist. Creating it..."
        sudo groupadd docker
        group_exists=0
    fi

    if [ -S "$sock" ]; then
        sock_group="$(stat -c '%G' "$sock")"
        sock_mode="$(stat -c '%a' "$sock")"
        log "Docker socket: $sock"
        log "Socket group: $sock_group"
        log "Socket mode : $sock_mode"

        if [ "$sock_group" != "docker" ]; then
            warn "Socket is not owned by group 'docker'."
            warn "Trying to change group ownership of $sock to 'docker'..."
            sudo chgrp docker "$sock" || warn "Could not change socket group; Docker service may recreate it anyway."
            sudo chmod 660 "$sock" || warn "Could not change socket permissions."
        fi
    else
        warn "Docker socket $sock does not exist."
        warn "Docker daemon may not be running yet."
    fi

    if id -nG "$user" | tr ' ' '\n' | grep -qx docker; then
        log "User '$user' is already in group 'docker'."
    else
        log "Adding user '$user' to group 'docker'..."
        sudo usermod -aG docker "$user"
        warn "Group membership changed."
        warn "You need to log out and back in, or run:"
        warn "  newgrp docker"
    fi

    if docker ps >/dev/null 2>&1; then
        log "Docker already works without sudo for the current shell."
    else
        warn "Docker may still require a new login shell before non-root access works."
        warn "After re-login, test with:"
        warn "  docker ps"
    fi
}

main "$@"
