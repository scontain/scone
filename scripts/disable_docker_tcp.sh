#!/usr/bin/env bash
set -euo pipefail

# Undoes enable_docker_tcp.sh: removes the systemd socket that exposes the Docker
# API on 172.17.0.1:2375, and the configuration written by earlier versions of
# enable_docker_tcp.sh, which made dockerd listen on 0.0.0.0:2375.

SERVICE_NAME="docker"
SOCKET_UNIT="scone-docker-tcp.socket"
SOCKET_FILE="/etc/systemd/system/${SOCKET_UNIT}"
DAEMON_JSON="/etc/docker/daemon.json"
# Written by enable_docker_tcp.sh into the socket unit when it added "fd://" to daemon.json.
FD_HOST_NOTE="# Added \"fd://\" to ${DAEMON_JSON} hosts; disable_docker_tcp.sh removes it."
LEGACY_OVERRIDE_DIR="/etc/systemd/system/${SERVICE_NAME}.service.d"
LEGACY_OVERRIDE="${LEGACY_OVERRIDE_DIR}/override.conf"
LEGACY_MARKERS='enable_docker_tcp\.sh|Clear the default ExecStart and set our own with TCP'

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

remove_fd_host() {
  echo "Removing \"fd://\" from the hosts in ${DAEMON_JSON} ..."
  need_cmd python3
  python3 - "${DAEMON_JSON}" <<'EOF'
import json, os, sys
path = sys.argv[1]
with open(path) as f:
    cfg = json.load(f)
hosts = cfg.get("hosts") or []
if "fd://" in hosts:
    hosts.remove("fd://")
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
    os.chmod(tmp, os.stat(path).st_mode & 0o7777)
    os.replace(tmp, path)
EOF
}

remove_socket() {
  [[ -f "${SOCKET_FILE}" ]] || return 1
  if grep -Fqx "${FD_HOST_NOTE}" "${SOCKET_FILE}" && [[ -f "${DAEMON_JSON}" ]]; then
    remove_fd_host
  fi
  echo "Removing ${SOCKET_FILE} ..."
  systemctl disable --now "${SOCKET_UNIT}" || true
  rm -f "${SOCKET_FILE}"
}

remove_legacy_config() {
  # Earlier versions of enable_docker_tcp.sh replaced ExecStart in override.conf with
  # "-H fd:// -H tcp://0.0.0.0:2375"; one also edited daemon.json and kept backups
  # with the suffix .scone-tcp.bak.
  local changed=1
  if [[ -f "${DAEMON_JSON}.scone-tcp.bak" ]]; then
    echo "Restoring ${DAEMON_JSON} from ${DAEMON_JSON}.scone-tcp.bak ..."
    mv -f "${DAEMON_JSON}.scone-tcp.bak" "${DAEMON_JSON}"
    changed=0
  fi
  if [[ -f "${LEGACY_OVERRIDE}.scone-tcp.bak" ]]; then
    echo "Restoring ${LEGACY_OVERRIDE} from ${LEGACY_OVERRIDE}.scone-tcp.bak ..."
    mv -f "${LEGACY_OVERRIDE}.scone-tcp.bak" "${LEGACY_OVERRIDE}"
    changed=0
  elif [[ -f "${LEGACY_OVERRIDE}" ]] && grep -Eq "${LEGACY_MARKERS}" "${LEGACY_OVERRIDE}"; then
    if [[ -f "${DAEMON_JSON}" ]] && grep -q '"hosts"[[:space:]]*:' "${DAEMON_JSON}"; then
      # The stock unit passes -H fd://, which dockerd rejects when daemon.json sets hosts.
      local dockerd_path
      dockerd_path="$(command -v dockerd || echo /usr/bin/dockerd)"
      echo "${DAEMON_JSON} defines hosts; rewriting ${LEGACY_OVERRIDE} to start dockerd without -H flags ..."
      printf '[Service]\n# dockerd takes its hosts from %s.\nExecStart=\nExecStart=%s --containerd=/run/containerd/containerd.sock\n' \
        "${DAEMON_JSON}" "${dockerd_path}" > "${LEGACY_OVERRIDE}"
    else
      echo "Removing ${LEGACY_OVERRIDE} ..."
      rm -f "${LEGACY_OVERRIDE}"
      rmdir "${LEGACY_OVERRIDE_DIR}" 2>/dev/null || true
    fi
    changed=0
  fi
  return "${changed}"
}

main() {
  require_root
  need_cmd systemctl
  check_docker_service

  local changed=false
  if remove_socket; then
    changed=true
  fi
  if remove_legacy_config; then
    changed=true
  fi

  if [[ "${changed}" == true ]]; then
    echo "Reloading systemd and restarting Docker ..."
    systemctl daemon-reload
    # docker.service allows only a few starts per minute (StartLimitBurst). Running this
    # script and enable_docker_tcp.sh back to back can exceed that and leave Docker
    # stopped with "start-limit-hit", so reset the counter first.
    systemctl reset-failed "${SERVICE_NAME}.service" 2>/dev/null || true
    systemctl restart "${SERVICE_NAME}"
  else
    echo "No configuration from enable_docker_tcp.sh found. Nothing to remove."
  fi

  echo "Verifying ..."
  if listening_on_tcp; then
    echo "Docker still listens on TCP. That is configured outside these scripts:" >&2
    echo "check \"hosts\" in ${DAEMON_JSON} and the -H flags in 'systemctl cat ${SERVICE_NAME}'." >&2
    exit 1
  fi
  echo "Docker TCP API is disabled."
}

main "$@"
