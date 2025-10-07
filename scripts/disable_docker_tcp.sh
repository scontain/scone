#!/usr/bin/env bash
set -euo pipefail

# Config
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

listening_on_tcp() {
  # Returns 0 if dockerd is currently listening on any TCP port.
  if command -v ss >/dev/null 2>&1; then
    ss -lntp 2>/dev/null | grep -Eiq 'LISTEN.*:(237[0-9]|2380).*(dockerd|docker)' && return 0
  elif command -v netstat >/dev/null 2>&1; then
    netstat -lntp 2>/dev/null | grep -Eiq ':(237[0-9]|2380).*(LISTEN).*((dockerd|docker)/|/dockerd|/docker)' && return 0
  fi
  return 1
}

config_has_tcp() {
  # Returns 0 if the systemd unit (including drop-ins) has a tcp:// host configured
  systemctl cat "${SERVICE_NAME}" 2>/dev/null | grep -Eiq -- '-H\s+tcp://'
}

remove_override() {
  if [[ -f "${OVERRIDE_FILE}" ]]; then
    echo "Removing ${OVERRIDE_FILE} ..."
    rm -f "${OVERRIDE_FILE}"

    # Remove directory if empty
    if [[ -d "${OVERRIDE_DIR}" ]] && [[ -z "$(ls -A "${OVERRIDE_DIR}" 2>/dev/null)" ]]; then
      echo "Removing empty directory ${OVERRIDE_DIR} ..."
      rmdir "${OVERRIDE_DIR}"
    fi
    return 0
  else
    echo "No override file found at ${OVERRIDE_FILE}"
    return 1
  fi
}

warn_daemon_json_hosts() {
  # If daemon.json has TCP configured, warn that it won't be modified
  local dj="/etc/docker/daemon.json"
  if [[ -f "${dj}" ]] && grep -q '"hosts"\s*:' "${dj}"; then
    if grep -q 'tcp://' "${dj}"; then
      echo "Warning: /etc/docker/daemon.json defines TCP hosts. This script only removes systemd overrides." >&2
      echo "You may need to manually edit ${dj} to fully disable TCP." >&2
      return 0
    fi
  fi
  return 1
}

reload_and_restart_docker() {
  echo "Reloading systemd and restarting Docker..."
  systemctl daemon-reload
  systemctl restart "${SERVICE_NAME}"
}

main() {
  require_root
  need_cmd systemctl
  check_docker_service

  echo "Checking if Docker TCP is currently enabled..."

  local tcp_listening=false
  local tcp_configured=false

  if listening_on_tcp; then
    tcp_listening=true
    echo "Docker is currently listening on TCP."
  else
    echo "Docker is not currently listening on TCP."
  fi

  if config_has_tcp; then
    tcp_configured=true
    echo "TCP is configured in systemd."
  else
    echo "TCP is not configured in systemd."
  fi

  # If neither listening nor configured, nothing to do
  if [[ "${tcp_listening}" == "false" ]] && [[ "${tcp_configured}" == "false" ]]; then
    echo "Docker TCP is already disabled. Nothing to do."
    exit 0
  fi

  # Check for daemon.json conflicts
  local has_daemon_json_tcp=false
  if warn_daemon_json_hosts; then
    has_daemon_json_tcp=true
  fi

  # Remove systemd override if present
  local override_removed=false
  if remove_override; then
    override_removed=true
  fi

  # Only restart if we actually made changes
  if [[ "${override_removed}" == "true" ]]; then
    reload_and_restart_docker
  else
    echo "No systemd changes made. Docker restart not required."
  fi

  # Verify final state
  echo "Verifying..."
  if listening_on_tcp; then
    if [[ "${has_daemon_json_tcp}" == "true" ]]; then
      echo "Docker is still listening on TCP (likely due to /etc/docker/daemon.json configuration)."
      echo "Systemd override has been removed, but manual daemon.json edit is required."
      exit 0
    else
      echo "Docker is still listening on TCP after restart. Check 'journalctl -u ${SERVICE_NAME}' for details." >&2
      exit 1
    fi
  else
    echo "Docker TCP API successfully disabled."
    exit 0
  fi
}

main "$@"