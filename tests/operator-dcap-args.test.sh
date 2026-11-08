#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016  # the check expressions are eval-ed later
# Tests the operator_controller calls in scone_operator.md with a mocked
# operator_controller: OPERATOR_DCAP_ARGS is empty on Azure or with a preset
# DCAP_KEY, and its expansion must not abort under set -u with the bash 3.2
# that macOS ships as /bin/bash. The calls run with the bash that runs this
# test, so run it with /bin/bash on a Mac, too:
#   tests/operator-dcap-args.test.sh
#   /bin/bash tests/operator-dcap-args.test.sh
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

failures=0
check() {
  if eval "$2"; then echo "ok   - $1"; else echo "FAIL - $1"; failures=$((failures + 1)); fi
}

# Mocked operator_controller: prints one argument per line.
cat > "$work/operator_controller" <<'MOCK'
#!/bin/sh
printf '%s\n' "$@"
MOCK
chmod +x "$work/operator_controller"

# The calls exactly as documented: the install and the update call.
grep -E '^[[:space:]]*\./operator_controller .*OPERATOR_DCAP_ARGS' "$repo_root/scone_operator.md" \
  > "$work/calls"
# Without the calls, the checks below would pass vacuously.
check "scone_operator.md contains both operator_controller calls with OPERATOR_DCAP_ARGS" \
  '[[ $(wc -l < "$work/calls") -eq 2 ]]'

run_call() {
  # $1: call, $2: "empty" or a DCAP key for OPERATOR_DCAP_ARGS
  (cd "$work" && "$BASH" -c '
    set -euo pipefail  # as in the generated scripts
    SCONE_VERSION=1.2.3 REGISTRY_USER=user REGISTRY_TOKEN=token
    if [[ "$2" == empty ]]; then OPERATOR_DCAP_ARGS=(); else OPERATOR_DCAP_ARGS=(--dcap-api "$2"); fi
    eval "$1"
  ' _ "$1" "$2")
}

n=0
while IFS= read -r call; do
  n=$((n + 1))
  rc=0; out="$(run_call "$call" empty 2>&1)" || rc=$?
  check "call $n: empty OPERATOR_DCAP_ARGS runs and passes no --dcap-api" \
    '[[ $rc == 0 && "$out" == *"--verbose"* && "$out" != *"--dcap-api"* ]]'
  check "call $n: empty OPERATOR_DCAP_ARGS adds no empty argument" \
    '! grep -qx "" <<<"$out"'
  rc=0; out="$(run_call "$call" "0123456789abcdef0123456789abcdef" 2>&1)" || rc=$?
  check "call $n: a DCAP key is passed as --dcap-api <key>" \
    '[[ $rc == 0 ]] && grep -A1 -x -- "--dcap-api" <<<"$out" | tail -n1 | grep -qx 0123456789abcdef0123456789abcdef'
done < "$work/calls"

exit "$failures"
