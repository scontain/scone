#!/usr/bin/env bash
set -euo pipefail

# Makes the Docker API reachable at tcp://172.17.0.1:2375, the docker0 bridge
# address, for tools that need the host daemon over TCP. scripts/build.sh does
# not need it; it mounts the local Docker socket instead.
#
# The endpoint has no TLS or authentication: whoever can connect gets root on this
# host. Binding the bridge address instead of 0.0.0.0 keeps it off the external
# interfaces, but local users and containers can still reach it.
#
# A systemd socket unit holds the listener instead of a "dockerd -H tcp://..." flag:
# - FreeBind lets systemd bind 172.17.0.1 at boot, before dockerd creates docker0.
#   dockerd opens its API listeners before it sets up networking, so with
#   "-H tcp://172.17.0.1:2375" Docker would fail to start after every reboot.
# - dockerd takes the socket over through socket activation ("-H fd://", which
#   the stock docker.service already uses), so docker.service stays unchanged.
#
# Undo with: sudo ./scripts/disable_docker_tcp.sh

TCP_ADDRESS="172.17.0.1"
TCP_PORT="2375"
SERVICE_NAME="docker"
SOCKET_UNIT="scone-docker-tcp.socket"
SOCKET_FILE="/etc/systemd/system/${SOCKET_UNIT}"
DAEMON_JSON="/etc/docker/daemon.json"
# Recorded in the socket unit when this script added "fd://" to the daemon.json hosts.
FD_HOST_NOTE="# Added \"fd://\" to ${DAEMON_JSON} hosts; disable_docker_tcp.sh removes it."
# Earlier versions of this script made dockerd listen on 0.0.0.0:2375 via override.conf.
LEGACY_OVERRIDE="/etc/systemd/system/${SERVICE_NAME}.service.d/override.conf"
LEGACY_MARKERS='enable_docker_tcp\.sh|Clear the default ExecStart and set our own with TCP'

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

api_reachable() {
  # Returns 0 if the Docker API answers on the TCP endpoint.
  if command -v curl >/dev/null 2>&1; then
    [[ "$(curl -fsS --max-time 5 "http://${TCP_ADDRESS}:${TCP_PORT}/_ping" 2>/dev/null)" == "OK" ]]
  else
    timeout 10 docker -H "tcp://${TCP_ADDRESS}:${TCP_PORT}" version >/dev/null 2>&1
  fi
}

daemon_json() {
  # Usage: daemon_json has-hosts|has-fd|add-fd
  # Returns 1 when daemon.json does not exist or the answer is no.
  [[ -f "${DAEMON_JSON}" ]] || return 1
  need_cmd python3
  local rc=0
  python3 - "$1" "${DAEMON_JSON}" <<'EOF' || rc=$?
import json, os, sys
action, path = sys.argv[1:3]
try:
    with open(path) as f:
        text = f.read()
    cfg = json.loads(text) if text.strip() else {}
except (OSError, ValueError) as e:
    print(f"Cannot read {path}: {e}", file=sys.stderr)
    sys.exit(2)
hosts = cfg.get("hosts")
if action == "has-hosts":
    sys.exit(0 if hosts is not None else 1)
if action == "has-fd":
    sys.exit(0 if hosts and "fd://" in hosts else 1)
hosts.append("fd://")  # add-fd
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
os.chmod(tmp, os.stat(path).st_mode & 0o7777)
os.replace(tmp, path)
EOF
  (( rc <= 1 )) || exit "${rc}"
  return "${rc}"
}

legacy_config_present() {
  [[ -f "${LEGACY_OVERRIDE}.scone-tcp.bak" || -f "${DAEMON_JSON}.scone-tcp.bak" ]] && return 0
  [[ -f "${LEGACY_OVERRIDE}" ]] && grep -Eq "${LEGACY_MARKERS}" "${LEGACY_OVERRIDE}"
}

ensure_dockerd_accepts_socket() {
  # Sets added_fd=true when this run or an earlier one added "fd://" to daemon.json.
  local exec_start
  exec_start="$(systemctl show -p ExecStart --value "${SERVICE_NAME}")"
  if [[ -f "${SOCKET_FILE}" ]] && grep -Fqx "${FD_HOST_NOTE}" "${SOCKET_FILE}"; then
    added_fd=true
  fi

  if grep -Eq '(-H|--host)[= ]*fd://' <<<"${exec_start}"; then
    return 0  # stock docker.service
  fi
  if daemon_json has-hosts; then
    # dockerd rejects -H flags when daemon.json defines hosts, so add fd:// there.
    if ! daemon_json has-fd; then
      echo "Adding \"fd://\" to the hosts in ${DAEMON_JSON} so that dockerd accepts the socket ..."
      daemon_json add-fd
      added_fd=true
    fi
    return 0
  fi
  echo "dockerd is started without -H fd://, so it would ignore the systemd socket:" >&2
  echo "  ${exec_start}" >&2
  echo "Add \"-H fd://\" to ExecStart of ${SERVICE_NAME}.service, or \"fd://\" to \"hosts\" in ${DAEMON_JSON}, and rerun." >&2
  exit 1
}

write_socket_unit() {
  local note=""
  [[ "${added_fd}" == true ]] && note="${FD_HOST_NOTE}"$'\n'
  echo "Writing ${SOCKET_FILE} ..."
  cat > "${SOCKET_FILE}" <<EOF
# Written by enable_docker_tcp.sh; disable_docker_tcp.sh removes it.
${note}[Unit]
Description=Docker API on ${TCP_ADDRESS}:${TCP_PORT} for SCONE image builds (no TLS)

[Socket]
ListenStream=${TCP_ADDRESS}:${TCP_PORT}
# Bind before dockerd has created the docker0 bridge that owns this address.
FreeBind=true
Service=${SERVICE_NAME}.service

[Install]
WantedBy=sockets.target
EOF
}

main() {
  require_root
  need_cmd systemctl
  check_docker_service

  if legacy_config_present; then
    echo "Removing the configuration of an earlier version of this script (it listened on 0.0.0.0:${TCP_PORT}) ..."
    "${script_dir}/disable_docker_tcp.sh"
  fi

  if api_reachable; then
    echo "Docker API already reachable at tcp://${TCP_ADDRESS}:${TCP_PORT}. Nothing to do."
    exit 0
  fi

  added_fd=false
  ensure_dockerd_accepts_socket
  write_socket_unit

  systemctl daemon-reload
  systemctl enable "${SOCKET_UNIT}"
  # dockerd gets the socket only when it starts, and it keeps an old copy open
  # until it stops, so stop it before (re)binding the socket.
  echo "Restarting Docker with the socket ..."
  systemctl stop "${SERVICE_NAME}"
  if ! systemctl restart "${SOCKET_UNIT}"; then
    echo "Cannot listen on ${TCP_ADDRESS}:${TCP_PORT}. Is another process using the port? Check 'ss -lntp | grep :${TCP_PORT}'." >&2
    systemctl start "${SERVICE_NAME}" || true
    exit 1
  fi
  if ! systemctl start "${SERVICE_NAME}"; then
    echo "Docker failed to start. Check 'journalctl -u ${SERVICE_NAME}'; undo with sudo ./scripts/disable_docker_tcp.sh" >&2
    exit 1
  fi

  echo "Verifying ..."
  for _ in 1 2 3 4 5; do
    if api_reachable; then
      echo "Docker API enabled at tcp://${TCP_ADDRESS}:${TCP_PORT}"
      exit 0
    fi
    sleep 1
  done
  echo "Docker API is not reachable at tcp://${TCP_ADDRESS}:${TCP_PORT}. Check 'journalctl -u ${SERVICE_NAME} -u ${SOCKET_UNIT}'." >&2
  exit 1
}

main "$@"
