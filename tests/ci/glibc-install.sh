#!/usr/bin/env bash
# Installs the SCONE packages of stable.txt in a plain Ubuntu container, with the
# scone-glibc installer selected and patched exactly as scripts/install_sconecli.sh
# does it, and with a fake read-only core24 snap whose loader the unpatched postinst
# would pick. Also checks that the unpatched installer fails there.
#
# Usage: tests/ci/glibc-install.sh <ubuntu-version>      e.g. 22.04
#
# Needs a Docker host that can pull registry.scontain.com/scone.cloud/scone-deb-pkgs
# (docker login registry.scontain.com). Runs the containers as linux/amd64.
#
# Environment:
#   SCONE_CI_ID     suffix for container and volume names, and the value of their
#                   scone-ci label (default: local-<pid>)
#   SCONE_VERSION   package version (default: stable.txt)
set -euo pipefail

ubuntu_version="${1:?usage: $0 <ubuntu-version>}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
installer="${repo_root}/scripts/install_sconecli.sh"
id="${SCONE_CI_ID:-local-$$}"
name="scone-ci-glibc-${id}"
ubuntu="ubuntu:${ubuntu_version}"
platform=linux/amd64
work="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/scone-ci-glibc.XXXXXX")"

cleanup() {
  local rc=$?
  "${repo_root}/tests/ci/docker-cleanup.sh" "${id}" || true
  rm -rf "${work}"
  exit "${rc}"
}
trap cleanup EXIT

# Prints the lines of the generated installer from the first line matching START
# through the first line matching END that follows a line matching MID. Only the
# executed lines match: the echoed copies start with "printf".
extract_block() {
  START="$1" MID="$2" END="$3" awk '
    !on && $0 ~ ENVIRON["START"] { on = 1 }
    on { print }
    on && $0 ~ ENVIRON["MID"] { seen = 1 }
    on && seen && $0 ~ ENVIRON["END"] { found = 1; exit }
    END { exit !found }
  ' "${installer}"
}

export SCONE_VERSION="${SCONE_VERSION:-$(tr -d '[:space:]' < "${repo_root}/stable.txt")}"
[[ "${SCONE_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]] || { echo "Bad SCONE_VERSION '${SCONE_VERSION}'" >&2; exit 1; }
export REPO=registry.scontain.com/scone.cloud IMAGE=scone-deb-pkgs
export INSTALL_WORK="${work}/install" SCONE_PACKAGE_CONTAINER="${name}-packages"
mkdir -p "${INSTALL_WORK}/packages"

# The package copy loop and the glibc block, as the installer runs them.
# shellcheck disable=SC2016 # the patterns match a literal "$"
{
  echo 'set -euo pipefail'
  extract_block '^docker export "\$SCONE_PACKAGE_CONTAINER"' '^for package_prefix in ' '^done$'
} > "${work}/copy-packages.sh"
extract_block '^SCONE_GLIBC_VERSION=' 'dpkg-deb --root-owner-group -b' '^fi$' > "${work}/glibc-block.sh"
echo "Extracted from scripts/install_sconecli.sh: $(wc -l < "${work}/copy-packages.sh") lines of the package copy loop, $(wc -l < "${work}/glibc-block.sh") lines of the glibc block."

echo "Copying the packages out of ${REPO}/${IMAGE}:${SCONE_VERSION} ..."
"${repo_root}/tests/ci/docker-cleanup.sh" --pull "${id}" "${REPO}/${IMAGE}:${SCONE_VERSION}" "${platform}"
docker create --platform "${platform}" --label "scone-ci=${id}" --name "${SCONE_PACKAGE_CONTAINER}" \
  "${REPO}/${IMAGE}:${SCONE_VERSION}" sleep 1 >/dev/null
bash "${work}/copy-packages.sh"
ls -1 "${INSTALL_WORK}/packages"

echo "Creating the fake core24 snap ..."
"${repo_root}/tests/ci/docker-cleanup.sh" --pull "${id}" "${ubuntu}" "${platform}"
docker volume create --label "scone-ci=${id}" "${name}-snap" >/dev/null
# The layout of core24: /lib64 -> usr/lib64, and usr/lib64/ld-linux-x86-64.so.2 is a
# symlink to the loader in usr/lib/x86_64-linux-gnu. The unpatched postinst resolves
# the symlink with readlink -f and copies its loader over the read-only file at the end.
docker run --rm --platform "${platform}" --label "scone-ci=${id}" -v "${name}-snap:/core24" "${ubuntu}" sh -euc '
  mkdir -p /core24/usr/lib/x86_64-linux-gnu /core24/usr/lib64
  cp -L /lib64/ld-linux-x86-64.so.2 /core24/usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2
  ln -s ../lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /core24/usr/lib64/ld-linux-x86-64.so.2
  ln -s usr/lib /core24/lib
  ln -s usr/lib64 /core24/lib64
'

run_in_ubuntu() {
  docker run --rm --platform "${platform}" --label "scone-ci=${id}" \
    -e "SCONE_VERSION=${SCONE_VERSION}" \
    -v "${INSTALL_WORK}/packages:/debs:ro" \
    -v "${work}/glibc-block.sh:/opt/scone-ci/glibc-block.sh:ro" \
    -v "${repo_root}/tests/ci/glibc-install-container.sh:/opt/scone-ci/test.sh:ro" \
    -v "${name}-snap:/snap/core24/1643:ro" \
    "${ubuntu}" bash /opt/scone-ci/test.sh "$1"
}

echo
echo "===== ${ubuntu}: patched installer"
run_in_ubuntu patched
echo
echo "===== ${ubuntu}: unpatched installer"
run_in_ubuntu unpatched
