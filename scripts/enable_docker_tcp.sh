#!/usr/bin/env bash
set -euo pipefail

# Config — change if you want a different bind address/port.
TARGET_HOST="tcp://0.0.0.0:2375"
UNIX_SOCK="unix:///var/run/docker.sock"
SERVICE_NAME="docker"
OVERRIDE_DIR="/etc/systemd/system/${SERVICE_NAME}.service.d"
OVERRIDE_FILE="${OVERRIDE_DIR}/override.conf"

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }; }

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "Please run as root (use sudo)." >&2
    exit 1
  fi
}

check_docker_service() {
  if ! systemctl list-unit-files "${SERVICE_NAME}.service" &>/dev/null; then
    echo "Docker service not found. Is Docker installed?" >&2
    exit 1
  fi
}

extract_port() {
  # Extract port number from TARGET_HOST (e.g., tcp://0.0.0.0:2375 -> 2375)
  echo "${TARGET_HOST}" | sed -n 's/.*:\([0-9]\+\)$/\1/p'
}

listening_on_tcp() {
  # Returns 0 if dockerd is currently listening on the configured TCP port.
  local port
  port="$(extract_port)"
  [[ -z "${port}" ]] && return 1

  if command -v ss >/dev/null 2>&1; then
    ss -lntp 2>/dev/null | grep -E "LISTEN.*:${port}\s" | grep -Eiq "dockerd|docker" && return 0
  elif command -v netstat >/dev/null 2>&1; then
    netstat -lntp 2>/dev/null | grep -E ":${port}.*LISTEN" | grep -Eiq "dockerd|docker" && return 0
  fi
  return 1
}

config_has_tcp() {
  # Returns 0 if the systemd unit (including drop-ins) already has a tcp:// host
  systemctl cat "${SERVICE_NAME}" 2>/dev/null | grep -Eiq -- '-H\s+tcp://'
}

ensure_override() {
  local dockerd_path
  dockerd_path="$(command -v dockerd || true)"
  [[ -z "${dockerd_path}" ]] && dockerd_path="/usr/bin/dockerd"

  mkdir -p "${OVERRIDE_DIR}"

  # Only rewrite if the file is missing or doesn't match desired TARGET_HOST.
  local need_write=1
  if [[ -f "${OVERRIDE_FILE}" ]]; then
    grep -q "${TARGET_HOST//\//\\/}" "${OVERRIDE_FILE}" && need_write=0
  fi

  if [[ "${need_write}" -eq 1 ]]; then
    echo "Writing ${OVERRIDE_FILE} with TCP host ${TARGET_HOST} ..."
    cat > "${OVERRIDE_FILE}" <<EOF
[Service]
# Clear the default ExecStart and set our own with TCP + Unix socket
ExecStart=
ExecStart=${dockerd_path} -H ${UNIX_SOCK} -H ${TARGET_HOST}
EOF
  else
    echo "Override already present and points to ${TARGET_HOST}."
  fi
}

warn_daemon_json_hosts() {
  # If daemon.json has "hosts" configured, warn (flags will override, but it's good to know).
  local dj="/etc/docker/daemon.json"
  if [[ -f "${dj}" ]] && grep -q '"hosts"\s*:' "${dj}"; then
    if grep -q 'tcp://' "${dj}"; then
      echo "Note: /etc/docker/daemon.json already defines TCP hosts. systemd ExecStart will override them." >&2
    else
      echo "Note: /etc/docker/daemon.json defines 'hosts' without TCP. systemd ExecStart will override them." >&2
    fi
  fi
}

reload_and_restart_docker() {
  echo "Reloading systemd and restarting Docker..."
  systemctl daemon-reload
  systemctl restart "${SERVICE_NAME}"
}

main() {
  local port
  port="$(extract_port)"

  require_root
  need_cmd systemctl
  check_docker_service

  echo "Checking if Docker is already listening on TCP :${port} ..."
  if listening_on_tcp; then
    echo "TCP already enabled (dockerd is listening on :${port}). Nothing to do."
    exit 0
  fi

  echo "Checking if systemd config already enables TCP ..."
  if config_has_tcp; then
    echo "TCP appears configured in systemd, but dockerd isn't listening yet."
    reload_and_restart_docker
  else
    warn_daemon_json_hosts
    ensure_override
    reload_and_restart_docker
  fi

  echo "Verifying..."
  if listening_on_tcp; then
    echo "Docker TCP API enabled at ${TARGET_HOST}"
    exit 0
  else
    echo "Docker is not listening on TCP :${port} after restart. Check 'journalctl -u ${SERVICE_NAME}' for errors." >&2
    exit 1
  fi
}

main "$@"
