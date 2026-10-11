#!/usr/bin/env bash
# shellcheck disable=SC2034  # rc is read inside the eval-ed check expressions
# Tests the SCONE_TD_BUILD_IMAGE fallback in sconecli.md with mocked docker
# and verify_image: the fallback image must be verified before anything is
# copied out of it.
#   tests/sconecli-td-build-fallback.test.sh
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The fallback block, exactly as documented.
awk '/^\[\[ -e \/tmp\/scone-bin\/scone-td-build \]\]/{p=1} p{print} p&&/^}$/{exit}' \
  "$repo_root/sconecli.md" > "$work/fallback.sh"
grep -q 'verify_image "\$SCONE_TD_BUILD_IMAGE"' "$work/fallback.sh" \
  || echo "FAIL - sconecli.md fallback does not call verify_image (checks below show the effect)"

run_fallback() {
  # $1: exit status of the mocked verify_image
  bash -c '
    calls="$1"; verify_rc="$2"; fallback="$3"
    verify_image() { echo "verify $1" >> "$calls"; [[ "$verify_rc" == 0 ]] || exit 1; }
    docker() { echo "docker $*" >> "$calls"; [[ "$1" != cp || "$2" != scone-packages:* ]]; }
    REPO=r IMAGE=i SCONE_VERSION=v SCONE_TD_BUILD_IMAGE=example/td-build:1
    source "$fallback"
  ' _ "$work/calls" "$1" "$work/fallback.sh"
}

failures=0
check() {
  if eval "$2"; then echo "ok   - $1"; else echo "FAIL - $1"; failures=$((failures + 1)); fi
}

: > "$work/calls"
rc=0; run_fallback 1 >/dev/null 2>&1 || rc=$?
check "failed verification aborts the install" '[[ $rc != 0 ]]'
check "nothing is created or copied from an unverified image" \
  '! grep -q "docker create --name scone-td-build-packages" "$work/calls"'

: > "$work/calls"
rc=0; run_fallback 0 >/dev/null 2>&1 || rc=$?
check "verified fallback succeeds" '[[ $rc == 0 ]]'
check "verified image is used" 'grep -q "docker create --name scone-td-build-packages example/td-build:1" "$work/calls"'
check "verification happens before the copy" \
  '[[ $(grep -n "^verify " "$work/calls" | cut -d: -f1) -lt $(grep -n "docker create --name scone-td-build-packages" "$work/calls" | cut -d: -f1) ]]'

exit "$failures"
