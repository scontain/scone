#!/usr/bin/env bash
set -euo pipefail

# Config — change if you want a different bind address/port.
TARGET_HOST="tcp://0.0.0.0:2375"
SERVICE_NAME="docker"
OVERRIDE_DIR="/etc/systemd/system/${SERVICE_NAME}.service.d"
OVERRIDE_FILE="${OVERRIDE_DIR}/override.conf"
DAEMON_JSON="/etc/docker/daemon.json"
# Backups restored by disable_docker_tcp.sh.
OVERRIDE_BACKUP="${OVERRIDE_FILE}.scone-tcp.bak"
DAEMON_JSON_BACKUP="${DAEMON_JSON}.scone-tcp.bak"

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

daemon_json_has_hosts() {
  [[ -f "${DAEMON_JSON}" ]] && python3 - "${DAEMON_JSON}" <<'EOF'
import json, sys
sys.exit(0 if "hosts" in json.load(open(sys.argv[1])) else 1)
EOF
}

add_tcp_to_daemon_json() {
  # dockerd refuses to start if hosts are given both as -H flags and in daemon.json,
  # so when daemon.json owns "hosts" the TCP endpoint must be added there.
  if [[ ! -f "${DAEMON_JSON_BACKUP}" ]]; then
    cp -p "${DAEMON_JSON}" "${DAEMON_JSON_BACKUP}"
    echo "Backed up ${DAEMON_JSON} to ${DAEMON_JSON_BACKUP}"
  fi
  python3 - "${DAEMON_JSON}" "${TARGET_HOST}" <<'EOF'
import json, os, sys
path, host = sys.argv[1], sys.argv[2]
cfg = json.load(open(path))
if host in cfg["hosts"]:
    sys.exit(0)
cfg["hosts"].append(host)
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
os.chmod(tmp, os.stat(path).st_mode & 0o7777)
os.replace(tmp, path)
print(f"Added {host} to {path} hosts")
EOF
}

ensure_override() {
  local dockerd_path exec_start
  dockerd_path="$(command -v dockerd || true)"
  [[ -z "${dockerd_path}" ]] && dockerd_path="/usr/bin/dockerd"

  if daemon_json_has_hosts; then
    echo "Note: ${DAEMON_JSON} defines 'hosts'; adding TCP there and starting dockerd without -H flags."
    need_cmd python3
    add_tcp_to_daemon_json
    exec_start="${dockerd_path} --containerd=/run/containerd/containerd.sock"
  else
    exec_start="${dockerd_path} -H fd:// -H ${TARGET_HOST} --containerd=/run/containerd/containerd.sock"
  fi

  local desired
  desired="$(cat <<EOF
[Service]
# Written by enable_docker_tcp.sh; disable_docker_tcp.sh restores the previous state.
ExecStart=
ExecStart=${exec_start}
EOF
)"

  if [[ -f "${OVERRIDE_FILE}" ]] && [[ "$(cat "${OVERRIDE_FILE}")" == "${desired}" ]]; then
    echo "Override already present: ${OVERRIDE_FILE}"
    return
  fi

  mkdir -p "${OVERRIDE_DIR}"
  if [[ -f "${OVERRIDE_FILE}" && ! -f "${OVERRIDE_BACKUP}" ]] \
      && ! grep -q "enable_docker_tcp.sh" "${OVERRIDE_FILE}" \
      && ! grep -q -- "-H ${TARGET_HOST}" "${OVERRIDE_FILE}"; then
    cp -p "${OVERRIDE_FILE}" "${OVERRIDE_BACKUP}"
    echo "Backed up existing ${OVERRIDE_FILE} to ${OVERRIDE_BACKUP}"
  fi
  echo "Writing ${OVERRIDE_FILE} ..."
  printf '%s\n' "${desired}" > "${OVERRIDE_FILE}"
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

  # Always reconcile: an earlier run may have left a conflicting override.
  ensure_override
  if ! reload_and_restart_docker; then
    echo "Docker failed to restart. Check 'journalctl -u ${SERVICE_NAME}'; undo with ./scripts/disable_docker_tcp.sh" >&2
    exit 1
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
