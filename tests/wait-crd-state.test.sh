#!/usr/bin/env bash
# Tests scripts/wait-crd-state.sh against a mocked kubectl.
# The script runs with the bash that runs this test, so run it with the
# bash 3.2 that macOS ships as /bin/bash, too:
#   tests/wait-crd-state.test.sh
#   /bin/bash tests/wait-crd-state.test.sh
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mock_dir="$(mktemp -d)"
trap 'rm -rf "$mock_dir"' EXIT

# Mocked kubectl with two CRDs: the namespaced "cas" (instances in namespace "ws")
# and the cluster-scoped "las". MOCK_STATES lists the instances with their state,
# e.g. "target=HEALTHY other=UNHEALTHY"; both CRDs have the same instances.
cat > "$mock_dir/kubectl" <<'MOCK'
#!/usr/bin/env bash
state_of() { for kv in $MOCK_STATES; do [[ "${kv%%=*}" == "$1" ]] && echo "${kv#*=}"; done; }
# $1: namespace ("" for a cluster-scoped instance), $2: name
item() {
  local ns=""
  [[ -n "$1" ]] && ns="\"namespace\":\"$1\","
  printf '{"metadata":{%s"name":"%s"},"status":{"state":"%s"}}' "$ns" "$2" "$(state_of "$2")"
}
items() {
  local sep="" kv
  printf '{"items":['
  for kv in $MOCK_STATES; do printf '%s' "$sep"; item "$1" "${kv%%=*}"; sep=","; done
  printf ']}'
}
crd() { printf '{"metadata":{"name":"%s.services.scone.cloud"},"spec":{"group":"services.scone.cloud","scope":"%s","names":{"kind":"%s","plural":"%s"}}}' "$1" "$2" "$3" "$1"; }
case "$*" in
  "get crd -o json")
    printf '{"items":[%s,%s]}' "$(crd cas Namespaced CAS)" "$(crd las Cluster LAS)" ;;
  wait*) exit 0 ;;
  "get crd cas.services.scone.cloud -o json") crd cas Namespaced CAS ;;
  "get crd las.services.scone.cloud -o json") crd las Cluster LAS ;;
  "get cas.services.scone.cloud -n ws -o json") items ws ;;
  "get cas.services.scone.cloud "*" -n ws -o json") item ws "$3" ;;
  # Cluster-scoped: no namespace flag at all, not even an empty argument.
  "get las.services.scone.cloud -o json") items "" ;;
  "get las.services.scone.cloud "*" -o json") item "" "$3" ;;
  *) echo "unexpected kubectl $*" >&2; exit 1 ;;
esac
MOCK
chmod +x "$mock_dir/kubectl"

failures=0
# expect <exit status> <description> <crd> [VAR=value...]
expect() {
  local want="$1" desc="$2" crd="$3"; shift 3
  local got=0
  env PATH="$mock_dir:$PATH" COND=HEALTHY TIMEOUT=3 INTERVAL=1 NAMESPACE=ws "$@" \
    "$BASH" "$repo_root/scripts/wait-crd-state.sh" "$crd" >/dev/null 2>&1 || got=$?
  if [[ "$got" == "$want" ]]; then
    echo "ok   - $desc"
  else
    echo "FAIL - $desc (exit $got, expected $want)"
    failures=$((failures + 1))
  fi
}

expect 0 "all instances HEALTHY exits 0 (no set -e abort on the first increment)" cas \
  MOCK_STATES="target=HEALTHY other=HEALTHY"
expect 0 "NAME scopes the wait: unhealthy sibling is ignored" cas \
  MOCK_STATES="target=HEALTHY other=UNHEALTHY" NAME=target
expect 1 "without NAME an unhealthy sibling times out" cas \
  MOCK_STATES="target=HEALTHY other=UNHEALTHY"
expect 1 "NAME of a missing instance fails" cas \
  MOCK_STATES="target=HEALTHY other=HEALTHY" NAME=missing
expect 0 "no instances: the Established CRD is enough" cas \
  MOCK_STATES=""
expect 0 "state matches COND regardless of case (state Healthy)" cas \
  MOCK_STATES="target=Healthy other=healthy"
expect 0 "COND matches regardless of case (COND=healthy)" cas \
  MOCK_STATES="target=HEALTHY other=HEALTHY" COND=healthy
expect 1 "an unset state never matches" cas \
  MOCK_STATES="target=HEALTHY other="
expect 0 "cluster-scoped CRD: all instances HEALTHY exits 0" las \
  MOCK_STATES="las=HEALTHY" NAMESPACE=
expect 1 "cluster-scoped CRD: an unhealthy instance times out" las \
  MOCK_STATES="las=UNHEALTHY" NAMESPACE=

exit "$failures"
