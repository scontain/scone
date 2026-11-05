#!/usr/bin/env bash
# Runs inside the ubuntu:<version> container that tests/ci/glibc-install.sh starts.
#
# Usage: glibc-install-container.sh patched|unpatched
#   patched    select and patch the scone-glibc installer with the block from
#              scripts/install_sconecli.sh, install it, check that it is installed
#   unpatched  install the scone-glibc installer as shipped; it must fail when the
#              postinst's loader lookup finds the fake snap first
#
# Expects /debs (the packages from scone-deb-pkgs), /opt/scone-ci/glibc-block.sh
# (the glibc block extracted from scripts/install_sconecli.sh) and a read-only fake
# core24 snap at /snap/core24/1643.
set -euo pipefail

mode="${1:?usage: $0 patched|unpatched}"
LOADER_FIND=(find / -name ld-linux-x86-64.so.2 -type l -print -quit)
SNAP_LOADER=/snap/core24/1643/usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2

ok() { printf 'ok - %s\n' "$*"; }
fail() { printf 'FAIL - %s\n' "$*" >&2; exit 1; }

export INSTALL_WORK=/work REPO=registry.scontain.com/scone.cloud IMAGE=scone-deb-pkgs
export SCONE_VERSION="${SCONE_VERSION:-unknown}"
mkdir -p "${INSTALL_WORK}/packages"
cp /debs/*.deb "${INSTALL_WORK}/packages/"

host_glibc="$(getconf GNU_LIBC_VERSION | awk '{print $2}')"
# shellcheck disable=SC1091
echo "$(. /etc/os-release && echo "${PRETTY_NAME}"), glibc ${host_glibc}"
[[ -e "${SNAP_LOADER}" ]] || fail "the fake snap is not mounted"
first_loader="$("${LOADER_FIND[@]}" 2>/dev/null || true)"
echo "The postinst's lookup '${LOADER_FIND[*]}' finds ${first_loader:-nothing}"
echo "  which resolves to $(readlink -f "${first_loader}")"
if [[ "${first_loader}" == /snap/* ]]; then
  snap_first=true
else
  snap_first=false
fi

install_dependencies() {
  # The installer runs plain dpkg -i, which does not resolve dependencies. Desktop and
  # server installs have them (e.g., gettext-base for scone-cli); a container image
  # does not, so install the non-SCONE dependencies the packages declare first.
  local deps
  deps="$(for deb in "${INSTALL_WORK}"/packages/*.deb; do dpkg-deb -f "${deb}" Depends; done \
    | tr ',' '\n' | sed -E 's/\|.*//; s/\(.*\)//; s/[[:space:]]//g' | grep -v -e '^scone-' -e '^$' | sort -u)"
  [[ -n "${deps}" ]] || return 0
  echo "Installing the dependencies of the SCONE packages: ${deps//$'\n'/ }"
  apt-get update -qq
  # shellcheck disable=SC2086 # one package per word
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends ${deps} >/dev/null
}

install_core() {
  install_dependencies
  dpkg -i "${INSTALL_WORK}"/packages/scone-common_*.deb
  dpkg -i "${INSTALL_WORK}"/packages/scone-libc_*.deb
  dpkg -i "${INSTALL_WORK}"/packages/scone-cli_*.deb
}

glibc_installed() {
  dpkg -s scone-glibc 2>/dev/null | grep -qx 'Status: install ok installed'
}

case "${mode}" in
  patched)
    # shellcheck source=/dev/null
    source /opt/scone-ci/glibc-block.sh
    [[ "${SCONE_GLIBC_DEB}" == "scone-glibc-${host_glibc}-installer_amd64.deb" ]] \
      || fail "selected ${SCONE_GLIBC_DEB} for glibc ${host_glibc}"
    ok "selected ${SCONE_GLIBC_DEB}"
    dpkg-deb -e "${INSTALL_WORK}/packages/${SCONE_GLIBC_DEB}" /tmp/glibc-control
    if grep -aqF "${LOADER_FIND[*]}" /tmp/glibc-control/postinst; then
      fail "the postinst of ${SCONE_GLIBC_DEB} still looks up the loader with find"
    fi
    if grep -aqF "${LOADER_FIND[*]}" <(dpkg-deb --ctrl-tarfile "/debs/${SCONE_GLIBC_DEB}" | tar -xOf - ./postinst); then
      ok "the postinst no longer looks up the loader with find"
    else
      echo "Note: the shipped postinst has no 'find' lookup; the block left it unchanged."
    fi
    install_core
    dpkg -i "${INSTALL_WORK}/packages/${SCONE_GLIBC_DEB}" || fail "dpkg -i ${SCONE_GLIBC_DEB} failed"
    glibc_installed || fail "dpkg -s scone-glibc: $(dpkg -s scone-glibc 2>&1 | grep '^Status')"
    ok "dpkg -s scone-glibc: install ok installed"
    # The postinst replaced the loader and libc; native programs must still start.
    if ! bash -c true || ! ls / >/dev/null; then
      fail "programs do not start after the install"
    fi
    ok "programs still start with the installed loader and libc"
    if [[ "${snap_first}" == true ]]; then
      ok "the patch mattered: the unpatched lookup would have found ${first_loader}"
    else
      echo "::notice title=glibc-install ${host_glibc}::find visits ${first_loader} before /snap in this container, so this run does not show that the patch is needed"
    fi
    ;;
  unpatched)
    deb="scone-glibc-${host_glibc}-installer_amd64.deb"
    [[ -e "${INSTALL_WORK}/packages/${deb}" ]] || fail "no ${deb} in the package image"
    if [[ "${snap_first}" != true ]]; then
      # overlayfs lists the image's own directories before /snap, which only exists
      # as a mount point. On a host, the order depends on the file system (on an
      # Ubuntu 22.04 host with snaps, find hit /snap/core22/... first).
      echo "::notice title=glibc-install ${host_glibc}::find visits ${first_loader:-nothing} before /snap in this container; skipping the check that the unpatched installer fails"
      echo "SKIP - the unpatched lookup does not reach the fake snap in this container"
      exit 0
    fi
    install_core
    rc=0
    out="$(dpkg -i "${INSTALL_WORK}/packages/${deb}" 2>&1)" || rc=$?
    printf '%s\n' "${out}" | sed 's/^/    | /'
    [[ "${rc}" -ne 0 ]] || fail "the unpatched ${deb} installed although find returned ${first_loader}"
    grep -qF "${SNAP_LOADER}" <<<"${out}" || fail "the unpatched install failed, but not at ${SNAP_LOADER}"
    ! glibc_installed || fail "scone-glibc is marked as installed"
    ok "the unpatched ${deb} fails at the read-only ${SNAP_LOADER}"
    ;;
  *)
    fail "unknown mode ${mode}"
    ;;
esac
