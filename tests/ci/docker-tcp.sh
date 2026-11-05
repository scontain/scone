#!/usr/bin/env bash
# Boots Ubuntu with systemd and Docker in a privileged container and runs
# tests/ci/docker-tcp-container.sh in it. Needs a Docker host that allows
# privileged containers; changes nothing on the host outside of Docker.
#
# Usage: tests/ci/docker-tcp.sh <ubuntu-version>      e.g. 22.04
#
# Environment:
#   SCONE_CI_ID       suffix for container, image, volume and network names, and the
#                     value of their scone-ci label (default: local-<pid>)
#   SCONE_CI_KEEP=1   keep the container for debugging
#   LEGACY_REF        commit with the old enable/disable_docker_tcp.sh, which made
#                     dockerd listen on 0.0.0.0:2375 (default: last version on main
#                     before the socket unit)
set -euo pipefail

ubuntu_version="${1:?usage: $0 <ubuntu-version>}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
id="${SCONE_CI_ID:-local-$$}"
name="scone-ci-docker-tcp-${id}"
image="scone-ci-docker-tcp:${id}"
legacy_ref="${LEGACY_REF:-a75d8730872a1a903a964389f3d1f84d4b25af78}"
work="$(mktemp -d)"

cleanup() {
  local rc=$?
  if [[ "${SCONE_CI_KEEP:-0}" == 1 ]]; then
    echo "Keeping container ${name} (SCONE_CI_KEEP=1)."
  else
    "${repo_root}/tests/ci/docker-cleanup.sh" "${id}" || true
  fi
  rm -rf "${work}"
  exit "${rc}"
}
trap cleanup EXIT

echo "Old enable/disable_docker_tcp.sh from ${legacy_ref} ..."
mkdir -p "${work}/legacy"
if ! git -C "${repo_root}" cat-file -e "${legacy_ref}^{commit}" 2>/dev/null; then
  git -C "${repo_root}" fetch --quiet --depth=1 origin "${legacy_ref}"
fi
for script in enable_docker_tcp.sh disable_docker_tcp.sh; do
  git -C "${repo_root}" show "${legacy_ref}:scripts/${script}" > "${work}/legacy/${script}"
done
grep -q 'tcp://0.0.0.0:2375' "${work}/legacy/enable_docker_tcp.sh" \
  || { echo "${legacy_ref} does not contain the old enable script" >&2; exit 1; }
chmod 0755 "${work}"/legacy/*.sh

base="ubuntu:${ubuntu_version}"
"${repo_root}/tests/ci/docker-cleanup.sh" --pull "${id}" "${base}"
echo "Building ${image} from ${base} ..."
docker build --quiet --label "scone-ci=${id}" --build-arg "UBUNTU_VERSION=${ubuntu_version}" \
  -t "${image}" "${repo_root}/tests/ci/docker-tcp" >/dev/null

# The container's own dockerd must get 172.17.0.0/16 for docker0, so the container
# must not sit on a network that overlaps it (e.g., the runner's default bridge).
docker network create --label "scone-ci=${id}" "${name}" >/dev/null
subnet="$(docker network inspect -f '{{range .IPAM.Config}}{{.Subnet}} {{end}}' "${name}")"
if [[ "${subnet}" == 172.17.* ]]; then
  echo "Docker gave network ${name} the subnet ${subnet}, which overlaps the docker0 under test." >&2
  exit 1
fi
docker volume create --label "scone-ci=${id}" "${name}" >/dev/null

echo "Booting ${name} ..."
docker run -d --name "${name}" --hostname "${name}" --label "scone-ci=${id}" \
  --network "${name}" \
  --privileged --cgroupns=host -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  --tmpfs /run --tmpfs /run/lock \
  -v "${name}:/var/lib/docker" \
  -v "${repo_root}/scripts:/opt/scone-ci/scripts:ro" \
  -v "${work}/legacy:/opt/scone-ci/legacy:ro" \
  -v "${repo_root}/tests/ci/docker-tcp-container.sh:/opt/scone-ci/test.sh:ro" \
  "${image}" >/dev/null

state=""
for _ in $(seq 1 120); do
  state="$(docker exec "${name}" systemctl is-system-running 2>/dev/null || true)"
  [[ "${state}" == running || "${state}" == degraded ]] && break
  sleep 1
done
echo "systemd: ${state:-no answer}"
if [[ "${state}" == degraded ]]; then
  docker exec "${name}" systemctl --no-pager --failed || true
fi
if ! docker exec "${name}" systemctl is-active --quiet docker.service; then
  docker exec "${name}" journalctl --no-pager -n 80 -u docker.service -u containerd.service || true
  echo "docker.service did not start in ${name}" >&2
  exit 1
fi

docker exec "${name}" bash /opt/scone-ci/test.sh
