#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016  # the check expressions are eval-ed later
# Tests the SCONE_TD_BUILD_IMAGE fallback in sconecli.md with mocked docker
# and verify_image: the fallback image must be verified before anything is
# copied out of it.
#   tests/sconecli-td-build-fallback.test.sh
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

failures=0
check() {
  if eval "$2"; then echo "ok   - $1"; else echo "FAIL - $1"; failures=$((failures + 1)); fi
}

# The fallback block, exactly as documented: from the check for a missing
# scone-td-build binary to its closing fi.
awk '/^if \[\[ ! -e "\$INSTALL_WORK\/bin\/scone-td-build" \]\]; then$/{p=1} p{print} p&&/^fi$/{exit}' \
  "$repo_root/sconecli.md" > "$work/fallback.sh"
# Without a block, the checks below would pass vacuously.
check "sconecli.md contains the scone-td-build fallback" '[[ -s "$work/fallback.sh" ]]'
check "sconecli.md fallback calls verify_image" \
  'grep -q "verify_image \"\$SCONE_TD_BUILD_IMAGE\"" "$work/fallback.sh"'

run_fallback() {
  # $1: exit status of the mocked verify_image
  bash -c '
    set -euo pipefail  # as in the generated scripts/install_sconecli.sh
    calls="$1"; verify_rc="$2"; fallback="$3"
    verify_image() { echo "verify $1" >> "$calls"; [[ "$verify_rc" == 0 ]] || exit 1; }
    # The package image does not contain scone-td-build.
    docker() { echo "docker $*" >> "$calls"; [[ "$1" != cp || "$2" != "$SCONE_PACKAGE_CONTAINER":* ]]; }
    REPO=r IMAGE=i SCONE_VERSION=v SCONE_TD_BUILD_IMAGE=example/td-build:1
    INSTALL_WORK="$(dirname "$calls")/install" SCONE_PACKAGE_CONTAINER=scone-packages-test
    SCONE_TD_BUILD_CONTAINER=""
    source "$fallback"
  ' _ "$work/calls" "$1" "$work/fallback.sh"
}

: > "$work/calls"
rc=0; run_fallback 1 >/dev/null 2>&1 || rc=$?
check "failed verification aborts the install" '[[ $rc != 0 ]]'
check "nothing is created or copied from an unverified image" \
  '! grep -q "docker create --name scone-td-build-packages" "$work/calls"'

: > "$work/calls"
rc=0; run_fallback 0 >/dev/null 2>&1 || rc=$?
check "verified fallback succeeds" '[[ $rc == 0 ]]'
check "verified image is used" 'grep -Eq "^docker create --name scone-td-build-packages-[^ ]+ example/td-build:1 " "$work/calls"'
verify_line="$(grep -n "^verify example/td-build:1$" "$work/calls" | cut -d: -f1 || true)"
create_line="$(grep -n "^docker create --name scone-td-build-packages" "$work/calls" | cut -d: -f1 || true)"
check "verification happens before the copy" \
  '[[ -n "$verify_line" && -n "$create_line" ]] && (( verify_line < create_line ))'

exit "$failures"
