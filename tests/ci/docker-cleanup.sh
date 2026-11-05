#!/usr/bin/env bash
# Removes the Docker objects that the CI tests create, so a self-hosted runner keeps
# only what it had before.
#
# Usage:
#   tests/ci/docker-cleanup.sh <id>
#       remove containers, volumes, networks and images labeled scone-ci=<id>, and the
#       images pulled with --pull for <id>
#   tests/ci/docker-cleanup.sh --pull <id> <image> [<platform>]
#       pull <image> unless it is present (for <platform>, e.g. linux/amd64); if it
#       was not, remember to remove it
set -euo pipefail

pulled_list() { echo "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/scone-ci-${1}.pulled"; }

if [[ "${1:-}" == --pull ]]; then
  id="${2:?usage: $0 --pull <id> <image> [<platform>]}"
  image="${3:?usage: $0 --pull <id> <image> [<platform>]}"
  platform="${4:-}"
  present="$(docker image inspect --format '{{.Os}}/{{.Architecture}}' "${image}" 2>/dev/null || true)"
  if [[ -z "${present}" || ( -n "${platform}" && "${present}" != "${platform}" ) ]]; then
    echo "${image}" >> "$(pulled_list "${id}")"
    docker pull --quiet ${platform:+--platform "${platform}"} "${image}" >/dev/null
  fi
  exit 0
fi

id="${1:?usage: $0 <id>}"
filter="label=scone-ci=${id}"
rc=0
# IDs contain no whitespace, so word splitting is safe here.
# shellcheck disable=SC2086
{
  containers="$(docker ps -aq --filter "${filter}")"
  [[ -z "${containers}" ]] || docker rm -f -v ${containers} >/dev/null || rc=1
  volumes="$(docker volume ls -q --filter "${filter}")"
  [[ -z "${volumes}" ]] || docker volume rm ${volumes} >/dev/null || rc=1
  networks="$(docker network ls -q --filter "${filter}")"
  [[ -z "${networks}" ]] || docker network rm ${networks} >/dev/null || rc=1
  images="$(docker images -q --filter "${filter}" | sort -u)"
  [[ -z "${images}" ]] || docker rmi -f ${images} >/dev/null || rc=1
}
list="$(pulled_list "${id}")"
if [[ -f "${list}" ]]; then
  while IFS= read -r image; do
    # Another job on this host may still use it; then it stays.
    docker rmi "${image}" >/dev/null 2>&1 || echo "Kept ${image} (in use)."
  done < "${list}"
  rm -f "${list}"
fi
exit "${rc}"
