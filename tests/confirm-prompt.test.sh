#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016  # the check expressions are eval-ed later
# Tests the y/N confirmation in scone_operator.md and CAS.md with a mocked
# kubectl. The answer is lowercased without bash 4 syntax, so the generated
# scripts also run with the bash 3.2 that macOS ships as /bin/bash. The block
# runs with the bash that runs this test, so run it with /bin/bash on a Mac, too:
#   tests/confirm-prompt.test.sh
#   /bin/bash tests/confirm-prompt.test.sh
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

failures=0
check() {
  if eval "$2"; then echo "ok   - $1"; else echo "FAIL - $1"; failures=$((failures + 1)); fi
}

run_block() {
  # $1: extracted block, $2: answer typed at the prompt
  printf '%s\n' "$2" | "$BASH" -c '
    set -euo pipefail  # as in the generated scripts
    kubectl() { echo test-context; }
    SCONE_VERSION=1.2.3 VERSION=1.2.3 CAS=cas CAS_NAMESPACE=default
    source "$1"
  ' _ "$1"
}

for md in scone_operator.md CAS.md; do
  block="$work/${md%.md}.sh"
  # The block exactly as documented: from the context lookup to the "Proceeding" message.
  awk '/^# Get the current Kubernetes context$/{p=1} p{print} p&&/^echo ".*Proceeding with context/{exit}' \
    "$repo_root/$md" > "$block"
  # Without a block, the checks below would pass vacuously.
  check "$md contains the confirmation block" \
    '[[ -s "$block" ]] && grep -q "^read -rp .* confirm$" "$block"'

  for answer in y Y yes YES Yes; do
    rc=0; out="$(run_block "$block" "$answer" 2>&1)" || rc=$?
    check "$md: answer '$answer' proceeds" '[[ $rc == 0 && "$out" == *"Proceeding with context: test-context"* ]]'
  done
  for answer in "" n N no NO yess; do
    rc=0; out="$(run_block "$block" "$answer" 2>&1)" || rc=$?
    check "$md: answer '$answer' aborts" '[[ $rc == 1 && "$out" == *"Aborted by user."* ]]'
  done
done

exit "$failures"
