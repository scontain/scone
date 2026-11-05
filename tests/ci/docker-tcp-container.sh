#!/usr/bin/env bash
# Runs inside the systemd container that tests/ci/docker-tcp.sh boots. Exercises
# scripts/enable_docker_tcp.sh and scripts/disable_docker_tcp.sh against a real
# docker.service. The scenarios build on each other and run in order; the first
# failed check stops the run.
#
# Expects:
#   /opt/scone-ci/scripts  the repository's scripts/ directory (read-only)
#   /opt/scone-ci/legacy   enable/disable_docker_tcp.sh from before the socket unit
#                          (they made dockerd listen on 0.0.0.0:2375)
set -euo pipefail

SCRIPTS=/opt/scone-ci/scripts
LEGACY=/opt/scone-ci/legacy
ADDR=172.17.0.1
PORT=2375
SOCKET_UNIT=scone-docker-tcp.socket
SOCKET_FILE=/etc/systemd/system/${SOCKET_UNIT}
OVERRIDE=/etc/systemd/system/docker.service.d/override.conf
DAEMON_JSON=/etc/docker/daemon.json

scenario() { printf '\n===== %s\n' "$*"; }
ok() { printf 'ok - %s\n' "$*"; }
fail() {
  printf 'FAIL - %s\n' "$*" >&2
  echo "--- journal (docker, ${SOCKET_UNIT}) ---" >&2
  journalctl --no-pager -n 60 -u docker.service -u "${SOCKET_UNIT}" >&2 || true
  exit 1
}

run_script() {
  # Usage: run_script <path> ; prints the output and stores it in $out.
  local rc=0
  out="$(bash "$1" 2>&1)" || rc=$?
  printf '%s\n' "${out}" | sed 's/^/    | /'
  return "${rc}"
}

# "path=... ; argv[]=..." of docker.service's ExecStart, without the runtime fields
# (start_time, pid) that change on every restart.
exec_start() {
  systemctl show -p ExecStart --value docker.service | grep -oE 'path=[^;]*; argv\[\]=[^;]*'
}

# Local addresses that listen on port 2375, one per line.
listeners() {
  ss -Hlnt "sport = :${PORT}" | awk '{print $4}' | sort -u
}

assert_bound_only_to_bridge() {
  local l
  l="$(listeners)"
  [[ "${l}" == "${ADDR}:${PORT}" ]] || fail "expected only ${ADDR}:${PORT} to listen, got: ${l:-nothing}"
  ok "port ${PORT} listens only on ${ADDR}"
}

assert_port_closed() {
  local l
  l="$(listeners)"
  [[ -z "${l}" ]] || fail "port ${PORT} still listens on: ${l}"
  # docker0 owns ${ADDR}, so this connection stays inside the container.
  if curl -fsS --max-time 5 "http://${ADDR}:${PORT}/_ping" >/dev/null 2>&1; then
    fail "the Docker API still answers on ${ADDR}:${PORT}"
  fi
  ok "port ${PORT} is closed"
}

# The API on the TCP endpoint answers and is this container's dockerd: when docker0
# is missing, ${ADDR} routes to the runner host, whose docker0 has the same address.
api_answers() {
  [[ "$(curl -fsS --max-time 5 "http://${ADDR}:${PORT}/_ping" 2>/dev/null)" == OK ]] || return 1
  local remote local_id
  remote="$(curl -fsS --max-time 5 "http://${ADDR}:${PORT}/info" \
    | python3 -c 'import json, sys; i = json.load(sys.stdin); print(i["ID"], i["Name"])')" || return 1
  local_id="$(docker -H unix:///var/run/docker.sock info --format '{{.ID}} {{.Name}}')" || return 1
  [[ "${remote}" == "${local_id}" ]]
}

assert_api_answers() {
  local _
  for _ in $(seq 1 30); do
    if api_answers; then
      ok "curl http://${ADDR}:${PORT}/_ping says OK (this container's dockerd)"
      return 0
    fi
    sleep 1
  done
  fail "the Docker API does not answer on ${ADDR}:${PORT}"
}

assert_docker_runs() {
  systemctl is-active --quiet docker.service || fail "docker.service is not active"
  docker -H unix:///var/run/docker.sock info >/dev/null || fail "docker info over the unix socket failed"
  ok "docker.service runs and docker info works over the unix socket"
}

hosts_in_daemon_json() {
  python3 -c 'import json, sys; print(json.dumps(json.load(open(sys.argv[1])).get("hosts")))' "${DAEMON_JSON}"
}

[[ -x "${SCRIPTS}/enable_docker_tcp.sh" && -f "${LEGACY}/enable_docker_tcp.sh" ]] \
  || fail "missing scripts under ${SCRIPTS} or ${LEGACY}"
ip -4 addr show docker0 | grep -q "inet ${ADDR}/" || fail "docker0 does not have ${ADDR}"
assert_docker_runs
# The scenarios restart Docker more often than this limit allows; the scripts must
# reset it themselves.
echo "docker.service: $(systemctl show -p StartLimitBurst -p StartLimitIntervalUSec docker.service | paste -sd ' ')"

scenario "A: enable on a stock docker.service"
[[ ! -e "${OVERRIDE}" && ! -e "${DAEMON_JSON}" ]] || fail "the image is not in its stock state"
stock_exec_start="$(exec_start)"
echo "    ExecStart: ${stock_exec_start}"
run_script "${SCRIPTS}/enable_docker_tcp.sh" || fail "enable_docker_tcp.sh exited $?"
ok "enable_docker_tcp.sh exited 0"
assert_api_answers
assert_bound_only_to_bridge
[[ "$(exec_start)" == "${stock_exec_start}" ]] || fail "ExecStart changed: $(exec_start)"
ok "ExecStart of docker.service is unchanged"
[[ ! -e "${OVERRIDE}" ]] || fail "${OVERRIDE} was written"
ok "no ${OVERRIDE}"
assert_docker_runs

scenario "B: boot order: the socket binds ${ADDR} before docker0 exists"
systemctl stop docker.service docker.socket "${SOCKET_UNIT}"
ip link del docker0
! ip link show docker0 >/dev/null 2>&1 || fail "docker0 still exists"
if python3 -c 'import socket, sys; socket.socket().bind((sys.argv[1], 0))' "${ADDR}" 2>/dev/null; then
  fail "${ADDR} is still a local address after deleting docker0"
fi
ok "docker0 is gone and ${ADDR} cannot be bound without FreeBind"
systemctl start "${SOCKET_UNIT}" || fail "systemctl start ${SOCKET_UNIT} failed without docker0"
ok "${SOCKET_UNIT} starts without docker0 (FreeBind)"
assert_bound_only_to_bridge
systemctl start docker.service || fail "docker.service does not start"
assert_api_answers
assert_docker_runs

scenario "C: a second enable has nothing to do"
run_script "${SCRIPTS}/enable_docker_tcp.sh" || fail "enable_docker_tcp.sh exited $?"
grep -q "Nothing to do" <<<"${out}" || fail "the second enable did not say 'Nothing to do'"
ok "the second enable says 'Nothing to do'"

scenario "D: disable"
run_script "${SCRIPTS}/disable_docker_tcp.sh" || fail "disable_docker_tcp.sh exited $?"
[[ ! -e "${SOCKET_FILE}" ]] || fail "${SOCKET_FILE} still exists"
ok "${SOCKET_FILE} is removed"
assert_port_closed
assert_docker_runs

scenario "E: upgrade from the old enable script (dockerd -H tcp://0.0.0.0:${PORT})"
run_script "${LEGACY}/enable_docker_tcp.sh" || fail "the old enable_docker_tcp.sh exited $?"
[[ -f "${OVERRIDE}" ]] || fail "the old enable script did not write ${OVERRIDE}"
grep -qE "^(0\.0\.0\.0|\*|\[::\]):${PORT}$" <<<"$(listeners)" \
  || fail "the old enable script does not listen on all addresses: $(listeners)"
ok "the old script listens on all addresses through ${OVERRIDE}"
run_script "${SCRIPTS}/enable_docker_tcp.sh" || fail "enable_docker_tcp.sh exited $?"
[[ ! -e "${OVERRIDE}" ]] || fail "the old ${OVERRIDE} is still there"
ok "the old ${OVERRIDE} is removed"
[[ "$(exec_start)" == "${stock_exec_start}" ]] || fail "ExecStart is not the stock one: $(exec_start)"
assert_bound_only_to_bridge
assert_api_answers
assert_docker_runs
run_script "${SCRIPTS}/disable_docker_tcp.sh" || fail "disable_docker_tcp.sh exited $?"
assert_port_closed

scenario "F: daemon.json sets hosts and a user override.conf starts dockerd without -H"
mkdir -p /etc/docker "$(dirname "${OVERRIDE}")"
printf '{"hosts": ["unix:///var/run/docker.sock"]}\n' > "${DAEMON_JSON}"
cat > "${OVERRIDE}" <<'EOF'
[Service]
Environment="HTTP_PROXY=http://proxy.example.invalid:3128" "NO_PROXY=localhost,127.0.0.1"
ExecStart=
ExecStart=/usr/bin/dockerd --containerd=/run/containerd/containerd.sock
EOF
systemctl daemon-reload
systemctl restart docker.service || fail "docker does not start with the user configuration"
assert_docker_runs
assert_port_closed
override_sum="$(sha256sum < "${OVERRIDE}")"
hosts_before="$(hosts_in_daemon_json)"
run_script "${SCRIPTS}/enable_docker_tcp.sh" || fail "enable_docker_tcp.sh exited $?"
[[ "$(hosts_in_daemon_json)" == '["unix:///var/run/docker.sock", "fd://"]' ]] \
  || fail "unexpected hosts in ${DAEMON_JSON}: $(hosts_in_daemon_json)"
ok "enable added fd:// to the hosts in ${DAEMON_JSON}"
[[ "$(sha256sum < "${OVERRIDE}")" == "${override_sum}" ]] || fail "enable changed ${OVERRIDE}"
ok "${OVERRIDE} is byte-identical"
assert_api_answers
assert_bound_only_to_bridge
assert_docker_runs
run_script "${SCRIPTS}/disable_docker_tcp.sh" || fail "disable_docker_tcp.sh exited $?"
[[ "$(hosts_in_daemon_json)" == "${hosts_before}" ]] \
  || fail "disable did not restore the hosts: $(hosts_in_daemon_json), expected ${hosts_before}"
ok "disable restored the hosts in ${DAEMON_JSON}: ${hosts_before}"
[[ "$(sha256sum < "${OVERRIDE}")" == "${override_sum}" ]] || fail "disable changed ${OVERRIDE}"
ok "${OVERRIDE} is byte-identical"
[[ ! -e "${SOCKET_FILE}" ]] || fail "${SOCKET_FILE} still exists"
assert_port_closed
assert_docker_runs

printf '\nAll docker-tcp scenarios passed.\n'
