#!/usr/bin/env bash
# wait-crd-state.sh — wait for CRD + instances to reach status.state=$COND
# Usage:
#   COND=HEALTHY TIMEOUT=300 INTERVAL=2 NAMESPACE= scripts/wait-crd-state.sh las
# Env:
#   COND      — target state string for .status.state (default: HEALTHY)
#   TIMEOUT   — overall timeout in seconds (default: 300)
#   INTERVAL  — poll interval in seconds (default: 2)
#   NAMESPACE — limit to one namespace for namespaced CRDs (default: all)

set -Eeuo pipefail

COND=${COND:-HEALTHY}
TIMEOUT=${TIMEOUT:-300}
INTERVAL=${INTERVAL:-2}
NAMESPACE=${NAMESPACE:-}

need() { command -v "$1" >/dev/null || { echo "Missing dependency: $1" >&2; exit 127; }; }
need kubectl; need jq

CRD_QUERY=${1:-}
if [[ -z "$CRD_QUERY" ]]; then
  echo "Usage: $0 <crd-name|kind|plural|shortname>" >&2
  exit 2
fi

# Resolve CRD name from kind/plural/shortname if needed
if [[ "$CRD_QUERY" == *.* ]]; then
  CRD_NAME="$CRD_QUERY"
else
  CRD_NAME=$(
    kubectl get crd -o json | jq -r --arg q "$CRD_QUERY" '
      .items[]
      | select(
          .metadata.name == $q
          or (.spec.names.kind|ascii_downcase == ($q|ascii_downcase))
          or (.spec.names.plural|ascii_downcase == ($q|ascii_downcase))
          or ((.spec.names.shortNames // [])[]? | ascii_downcase == ($q|ascii_downcase))
        )
      | .metadata.name
    ' | head -n1
  )
fi
[[ -n "${CRD_NAME:-}" ]] || { echo "CRD '$CRD_QUERY' not found." >&2; exit 2; }
echo "[INFO] CRD resolved to: $CRD_NAME"

echo "[INFO] Waiting for CRD to be Established (timeout ${TIMEOUT}s)…"
kubectl wait --for=condition=Established "crd/${CRD_NAME}" --timeout="${TIMEOUT}s"

# Pull details for listing instances
read -r GROUP PLURAL SCOPE <<<"$(kubectl get crd "$CRD_NAME" -o json | jq -r '
  [ .spec.group, .spec.names.plural, .spec.scope ] | @tsv
')"

# Determine namespace selector
if [[ "$SCOPE" == "Namespaced" ]]; then
  if [[ -n "$NAMESPACE" ]]; then nsflag=(-n "$NAMESPACE"); else nsflag=(--all-namespaces); fi
else
  nsflag=()
fi

echo "[INFO] Discovering instances of ${PLURAL}.${GROUP}…"
mapfile -t RES < <(kubectl get "${PLURAL}.${GROUP}" "${nsflag[@]}" -o json \
  | jq -r '.items[] | [ ( .metadata.namespace // "" ), .metadata.name ] | @tsv')

if (( ${#RES[@]} == 0 )); then
  echo "[INFO] No instances found. CRD is Established. Done."
  exit 0
fi

target_uc=${COND^^}
total=${#RES[@]}
deadline=$(( $(date +%s) + TIMEOUT ))
echo "[INFO] Waiting for .status.state == '${COND}' on ${total} instance(s)…"

while (( $(date +%s) < deadline )); do
  ok=0
  not_ready=()
  for row in "${RES[@]}"; do
    ns="${row%%$'\t'*}"; name="${row##*$'\t'}"
    if [[ "$SCOPE" == "Namespaced" ]]; then
      obj=$(kubectl get "${PLURAL}.${GROUP}" "$name" -n "$ns" -o json 2>/dev/null || true)
      ref="${ns}/${name}"
    else
      obj=$(kubectl get "${PLURAL}.${GROUP}" "$name" -o json 2>/dev/null || true)
      ref="${name}"
    fi
    [[ -n "$obj" ]] || { not_ready+=("$ref: <missing>"); continue; }

    state=$(jq -r '.status.state // empty' <<<"$obj")
    state_uc=${state^^}
    if [[ -n "$state" && "$state_uc" == "$target_uc" ]]; then
      ((ok++))
    else
      not_ready+=("$ref: ${state:-<unset>}")
    fi
  done

  if (( ok == total )); then
    echo "[INFO] All ${ok}/${total} instances reached state '${COND}'."
    exit 0
  fi

  echo "[INFO] ${ok}/${total} ready; waiting ${INTERVAL}s…"
  # Show up to 5 not-ready states for visibility
  printf '  - %s\n' "${not_ready[@]:0:5}"
  sleep "$INTERVAL"
done

echo "[ERROR] Timeout: not all ${PLURAL}.${GROUP} instances reached state '${COND}' within ${TIMEOUT}s." >&2
exit 1
