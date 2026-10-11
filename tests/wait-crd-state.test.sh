#!/usr/bin/env bash
# Tests scripts/wait-crd-state.sh against a mocked kubectl.
#   tests/wait-crd-state.test.sh
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mock_dir="$(mktemp -d)"
trap 'rm -rf "$mock_dir"' EXIT

# Mocked kubectl: one namespaced CRD "cas" with two instances in namespace "ws".
# MOCK_STATES maps instance name to state, e.g. "target=HEALTHY other=UNHEALTHY".
cat > "$mock_dir/kubectl" <<'MOCK'
#!/usr/bin/env bash
state_of() { for kv in $MOCK_STATES; do [[ "${kv%%=*}" == "$1" ]] && echo "${kv#*=}"; done; }
item() { printf '{"metadata":{"namespace":"ws","name":"%s"},"status":{"state":"%s"}}' "$1" "$(state_of "$1")"; }
case "$*" in
  "get crd -o json")
    echo '{"items":[{"metadata":{"name":"cas.services.scone.cloud"},"spec":{"group":"services.scone.cloud","scope":"Namespaced","names":{"kind":"CAS","plural":"cas"}}}]}' ;;
  wait*) exit 0 ;;
  "get crd cas.services.scone.cloud -o json")
    echo '{"spec":{"group":"services.scone.cloud","scope":"Namespaced","names":{"plural":"cas"}}}' ;;
  "get cas.services.scone.cloud -n ws -o json")
    printf '{"items":[%s,%s]}' "$(item target)" "$(item other)" ;;
  "get cas.services.scone.cloud "*" -n ws -o json")
    item "$3" ;;
  *) echo "unexpected kubectl $*" >&2; exit 1 ;;
esac
MOCK
chmod +x "$mock_dir/kubectl"

failures=0
expect() {
  local want="$1" desc="$2"; shift 2
  local got=0
  env PATH="$mock_dir:$PATH" COND=HEALTHY TIMEOUT=3 INTERVAL=1 NAMESPACE=ws "$@" \
    "$repo_root/scripts/wait-crd-state.sh" cas >/dev/null 2>&1 || got=$?
  if [[ "$got" == "$want" ]]; then
    echo "ok   - $desc"
  else
    echo "FAIL - $desc (exit $got, expected $want)"
    failures=$((failures + 1))
  fi
}

expect 0 "all instances HEALTHY exits 0 (no set -e abort on the first increment)" \
  MOCK_STATES="target=HEALTHY other=HEALTHY"
expect 0 "NAME scopes the wait: unhealthy sibling is ignored" \
  MOCK_STATES="target=HEALTHY other=UNHEALTHY" NAME=target
expect 1 "without NAME an unhealthy sibling times out" \
  MOCK_STATES="target=HEALTHY other=UNHEALTHY"
expect 1 "NAME of a missing instance fails" \
  MOCK_STATES="target=HEALTHY other=HEALTHY" NAME=missing

exit "$failures"
