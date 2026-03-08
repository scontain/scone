#!/usr/bin/env bash

set -Eeuo pipefail
export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""

TYPE_SPEED="${TYPE_SPEED:-25}"
PAUSE_AFTER_CMD="${PAUSE_AFTER_CMD:-0.6}"
SHELLRC="${SHELLRC:-/dev/null}"
PROMPT="${PROMPT:-$'\[\e[1;32m\]demo\[\e[0m\]:\[\e[1;34m\]~\[\e[0m\]\$ '}"
COLUMNS="${COLUMNS:-100}"
LINES="${LINES:-26}"
ORANGE="${ORANGE:-\033[38;5;208m}"
LILAC="${LILAC:-\033[38;5;141m}"
RESET="${RESET:-\033[0m}"

slow_type() {
  local text="$*"
  local delay
  delay=$(awk "BEGIN { print 1 / $TYPE_SPEED }")
  for ((i=0; i<${#text}; i++)); do
    printf "%s" "${text:i:1}"
    sleep "$delay"
  done
}

pe() {
  local cmd="$*"
  printf "%b" "$ORANGE"
  slow_type "$cmd"
  printf "%b" "$RESET"
  printf "\n"

  if [[ -n "${PE_BUFFER:-}" ]]; then
    PE_BUFFER+=$'\n'
  fi
  PE_BUFFER+="$cmd"

  # Execute only when buffered lines form a complete shell command.
  if bash -n <(printf '%s\n' "$PE_BUFFER") 2>/dev/null; then
    eval "$PE_BUFFER"
    PE_BUFFER=""
  fi

  sleep "$PAUSE_AFTER_CMD"
}

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export COLUMNS LINES
export PS1="$PROMPT"
stty cols "$COLUMNS" rows "$LINES"

printf "%b" "$LILAC"
printf '%s\n' '# Deploying a CAS instance'
printf '%s\n' ''
printf '%s\n' 'We deploy a SCONE CAS (i.e., a Configuration and Attestation Service) in the default cluster. '
printf '%s\n' ''
printf '%s\n' '![Screencast](docs/install_cas.gif)'
printf '%s\n' ''
printf '%s\n' '- First, we check that we have access to the cluster and the SCONE platform is already installed. '
printf '%s\n' '- Second, we ask the user for the name and the namespace of the CAS. '
printf '%s\n' '- Third, we call `kubectl provision` to install the CAS.'
printf '%s\n' ''
printf '%s\n' '## Steps'
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' '1. Ensure that the SCONE operator is installed and up-to-date (see [scone_operator](scone_operator.md))'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
DEPLOYMENT="scone-controller-manager"
EOF
)"
pe "$(cat <<'EOF'
NAMESPACE="scone-system"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
if ! kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" >/dev/null 2>&1; then
EOF
)"
pe "$(cat <<'EOF'
  echo "❌ Error: Deployment '$DEPLOYMENT' not found in namespace '$NAMESPACE'."
EOF
)"
pe "$(cat <<'EOF'
  echo "   Please run './scripts/reconcile_scone_operator.sh' to the SCONE operator"
EOF
)"
pe "$(cat <<'EOF'
  exit 1
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
echo "✅ Deployment '$DEPLOYMENT' exists in namespace '$NAMESPACE' (i.e., the SCONE Operator is running)."
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '2. ensure that the SCONE `kubectl` plugins are installed:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
if ! kubectl-provision --help >/dev/null ; then
EOF
)"
pe "$(cat <<'EOF'
  echo "❌ Error: The 'kubectl-provision' plugin is not installed or not available in your \$PATH."
EOF
)"
pe "$(cat <<'EOF'
  echo "ℹ️  Please install it before continuing by running './scripts/reconcile_scone_operator.sh'"
EOF
)"
pe "$(cat <<'EOF'
  exit 1
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"
pe "$(cat <<'EOF'
echo "✅ 'kubectl-provision' plugin is available."
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
if ! kubectl-scone --help >/dev/null ; then
EOF
)"
pe "$(cat <<'EOF'
  echo "❌ Error: The 'kubectl-scone' plugin is not installed or not available in your \$PATH."
EOF
)"
pe "$(cat <<'EOF'
  echo "ℹ️  Please install it before continuing by running './scripts/install_sconecli.sh'"
EOF
)"
pe "$(cat <<'EOF'
  exit 1
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
echo "✅ 'kubectl-scone' plugin is available."
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' '3. Ensure that SGX Plugin and Local Attestation Service (LAS) are `HEALTHY`'
printf '%s\n' ''
printf '%s\n' 'First, we check the state of the SGX Plugin. For the LAS to be healthy, the SGX Plugin must be healthy:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Try to extract the STATE field (assuming kubectl output includes a column "STATE")
EOF
)"
pe "$(cat <<'EOF'
if kubectl get sgx -o json | jq -e '[.items[].status.state] | all(. == "HEALTHY")' >/dev/null; then
EOF
)"
pe "$(cat <<'EOF'
  echo "✅ All sgx resources are HEALTHY."
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  echo "❌ Error: SGX Plugin state is not HEALTHY."
EOF
)"
pe "$(cat <<'EOF'
  echo "ℹ️  Please verify that the SGX is running correctly."
EOF
)"
pe "$(cat <<'EOF'
  exit 1
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Next, we check that the LAS is healthy:'
printf '%s\n' ''
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Try to extract the STATE field (assuming kubectl output includes a column "STATE")
EOF
)"
pe "$(cat <<'EOF'
STATE=$(kubectl get las las -o jsonpath='{.status.state}' 2>/dev/null || true)
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
if [[ "$STATE" != "HEALTHY" ]]; then
EOF
)"
pe "$(cat <<'EOF'
  echo "❌ Error: LAS state is '$STATE' (expected: HEALTHY)."
EOF
)"
pe "$(cat <<'EOF'
  echo "ℹ️  Please verify that the LAS is running correctly."
EOF
)"
pe "$(cat <<'EOF'
  exit 1
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
echo "✅ LAS state is HEALTHY."
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '4. We determine your Intel API Key'
printf '%s\n' ''
printf '%s\n' 'Please visit <https://api.portal.trustedservices.intel.com/manage-subscriptions> to generate or copy your DCAP API Key. Store this API key in a local environment variable: '
printf '%s\n' ''
printf '%s\n' 'export DCAP_KEY="..."'
printf '%s\n' ''
printf '%s\n' 'In case your cluster has already been installed, you can extract the DCAP_API_KEY as follows:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
    export DEFAULT_DCAP_KEY="00000000000000000000000000000000"
EOF
)"
pe "$(cat <<'EOF'
    export DCAP_KEY=${DCAP_KEY:-$DEFAULT_DCAP_KEY}
EOF
)"
pe "$(cat <<'EOF'
    if [[ "$DCAP_KEY" == "$DEFAULT_DCAP_KEY" ]] ; then
EOF
)"
pe "$(cat <<'EOF'
        echo "WARNING: No DCAP API Key in environment variable DCAP_KEY specified"
EOF
)"
pe "$(cat <<'EOF'
        EXISTING_DCAP_KEY=$(kubectl get las las -o json | jq -r '.spec.dcapKey' )
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
        if [[ "$EXISTING_DCAP_KEY" == "null" ]] ; then
EOF
)"
pe "$(cat <<'EOF'
            echo "WARNING: Extraction of DCAP_KEY from LAS failed - using default DCAP_KEY=$DEFAULT_DCAP_KEY - not recommended."
EOF
)"
pe "$(cat <<'EOF'
        else
EOF
)"
pe "$(cat <<'EOF'
            DCAP_KEY="$EXISTING_DCAP_KEY"
EOF
)"
pe "$(cat <<'EOF'
            echo "WARNING: Using DCAP_KEY extracted from LAS - not recommended."
EOF
)"
pe "$(cat <<'EOF'
        fi
EOF
)"
pe "$(cat <<'EOF'
    fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'In case we use the default DCAP API key, we ask the user for some input:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Check if DCAP_KEY is empty or unset
EOF
)"
pe "$(cat <<'EOF'
if [[ "$DCAP_KEY" == "$DEFAULT_DCAP_KEY" ]]; then
EOF
)"
pe "$(cat <<'EOF'
  while true; do
EOF
)"
pe "$(cat <<'EOF'
    read -rp "Please enter a 32-character hexadecimal DCAP_KEY: " input
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
    # Check if input is 32 hex chars (case-insensitive)
EOF
)"
pe "$(cat <<'EOF'
    if [[ "$input" =~ ^[0-9a-fA-F]{32}$ ]]; then
EOF
)"
pe "$(cat <<'EOF'
      DCAP_KEY="$input"
EOF
)"
pe "$(cat <<'EOF'
      export DCAP_KEY
EOF
)"
pe "$(cat <<'EOF'
      echo "✅ DCAP_KEY set."
EOF
)"
pe "$(cat <<'EOF'
      break
EOF
)"
pe "$(cat <<'EOF'
    else
EOF
)"
pe "$(cat <<'EOF'
      echo "❌ Invalid input. Must be exactly 32 hex characters (0-9, a-f)."
EOF
)"
pe "$(cat <<'EOF'
    fi
EOF
)"
pe "$(cat <<'EOF'
  done
EOF
)"
pe "$(cat <<'EOF'
  # kubectl provision requires DCAP argument 
EOF
)"
pe "$(cat <<'EOF'
  export DCAP_ARG="--dcap-api $DCAP_KEY"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  # kubectl provision will extract DCAP_KEY from LAS
EOF
)"
pe "$(cat <<'EOF'
  export DCAP_ARG=""
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '5. Determine the current stable version of the SCONE platform:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
export VERSION=$(curl -L -s https://raw.githubusercontent.com/scontain/scone/refs/heads/main/stable.txt)
EOF
)"
pe "$(cat <<'EOF'
echo "The lastest stable version of SCONE is $VERSION"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '6. Ensure that Persistent Volumes exist'
printf '%s\n' ''
printf '%s\n' 'In some clusters, we have experienced problems with persistent volumes and persisten volume claims. Hence, we check if they exist:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Checking if PersistentVolume (PV) and PersistentVolumeClaim (PVC) APIs are available...
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
required_resources=("persistentvolumes" "persistentvolumeclaims")
EOF
)"
pe "$(cat <<'EOF'
kubectl_output=""
EOF
)"
pe "$(cat <<'EOF'
max_attempts=30
EOF
)"
pe "$(cat <<'EOF'
attempt=0
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Function: Check if required API resources exist in kubectl output
EOF
)"
pe "$(cat <<'EOF'
check_required_resources() {
EOF
)"
pe "$(cat <<'EOF'
  # Run kubectl and store output (even if it fails)
EOF
)"
pe "$(cat <<'EOF'
  if ! kubectl_output=$(kubectl api-resources 2>&1); then
EOF
)"
pe "$(cat <<'EOF'
    echo "❌ kubectl api-resources failed: continuing anyhow"
EOF
)"
pe "$(cat <<'EOF'
  fi
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
  missing=0
EOF
)"
pe "$(cat <<'EOF'
  for res in "${required_resources[@]}"; do
EOF
)"
pe "$(cat <<'EOF'
    if echo "$kubectl_output" | grep -qw "$res"; then
EOF
)"
pe "$(cat <<'EOF'
      echo "✅ Found API resource: $res"
EOF
)"
pe "$(cat <<'EOF'
    else
EOF
)"
pe "$(cat <<'EOF'
      echo "❌ Missing API resource: $res"
EOF
)"
pe "$(cat <<'EOF'
      missing=1
EOF
)"
pe "$(cat <<'EOF'
    fi
EOF
)"
pe "$(cat <<'EOF'
  done
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
  if [[ $missing -eq 0 ]]; then
EOF
)"
pe "$(cat <<'EOF'
    return 0
EOF
)"
pe "$(cat <<'EOF'
  else
EOF
)"
pe "$(cat <<'EOF'
    return 1
EOF
)"
pe "$(cat <<'EOF'
  fi
EOF
)"
pe "$(cat <<'EOF'
}
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Retry loop: check resources until all are found or max attempts reached
EOF
)"
pe "$(cat <<'EOF'
echo "🔄 Checking for required API resources: ${required_resources[*]}"
EOF
)"
pe "$(cat <<'EOF'
until check_required_resources; do
EOF
)"
pe "$(cat <<'EOF'
  ((attempt++))
EOF
)"
pe "$(cat <<'EOF'
  echo "⏳ Attempt #$attempt failed. Retrying in 2s..."
EOF
)"
pe "$(cat <<'EOF'
  if [[ $attempt -ge $max_attempts ]]; then
EOF
)"
pe "$(cat <<'EOF'
    echo "❌ Error: Required resources not found after $max_attempts attempts. Aborting."
EOF
)"
pe "$(cat <<'EOF'
    exit 1
EOF
)"
pe "$(cat <<'EOF'
  fi
EOF
)"
pe "$(cat <<'EOF'
  sleep 2
EOF
)"
pe "$(cat <<'EOF'
done
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
echo "✅ PV and PVC API resources are available."
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Check for StorageClass
EOF
)"
pe "$(cat <<'EOF'
echo "🔍 Checking for available StorageClasses..."
EOF
)"
pe "$(cat <<'EOF'
storage_classes=$(kubectl get storageclass -o name 2>/dev/null || true)
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
if [[ -z "$storage_classes" ]]; then
EOF
)"
pe "$(cat <<'EOF'
  echo "❌ Error: No StorageClasses found. PersistentVolume provisioning may not work."
EOF
)"
pe "$(cat <<'EOF'
  exit 1
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
echo "✅ Found StorageClasses:"
EOF
)"
pe "$(cat <<'EOF'
kubectl get storageclass
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Look for default StorageClass
EOF
)"
pe "$(cat <<'EOF'
default_class=$(kubectl get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}' || true)
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
if [[ -z "$default_class" ]]; then
EOF
)"
pe "$(cat <<'EOF'
  echo "⚠️  Warning: No default StorageClass is set. You must explicitly define a storageClassName in PVCs."
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  echo "✅ Default StorageClass: $default_class"
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '7. Determine the name and the namespace of the CAS instance'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
eval $(tplenv --file Values-CAS.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )
EOF
)"
pe "$(cat <<'EOF'
# Confirm to the user
EOF
)"
pe "$(cat <<'EOF'
echo "✅ Using CAS: $CAS"
EOF
)"
pe "$(cat <<'EOF'
echo "✅ Using namespace: $CAS_NAMESPACE"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Check that this CAS instance does not yet exist:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
if kubectl get cas "$CAS" -n "$CAS_NAMESPACE" &>/dev/null; then
EOF
)"
pe "$(cat <<'EOF'
  echo "❌ Error: A CAS resource named '$CAS' already exists in namespace '$CAS_NAMESPACE'."
EOF
)"
pe "$(cat <<'EOF'
  exit 1
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
echo "✅ No existing CAS resource named '$CAS' found in namespace '$CAS_NAMESPACE'."
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '8. Confirm that we want to install this CAS'
printf '%s\n' ''
printf '%s\n' 'Make sure that we actually want to install CAS $CAS in the namespace $CAS_NAMESPACE of the current cluster'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Get the current Kubernetes context
EOF
)"
pe "$(cat <<'EOF'
K8S_CONTEXT=$(kubectl config current-context 2>/dev/null)
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
if [[ -z "$K8S_CONTEXT" ]]; then
EOF
)"
pe "$(cat <<'EOF'
  echo "❌ Could not determine the current Kubernetes context."
EOF
)"
pe "$(cat <<'EOF'
  exit 1
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
echo "📦 Current Kubernetes context: $K8S_CONTEXT"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Ask for confirmation
EOF
)"
pe "$(cat <<'EOF'
read -rp "Do you want to proceed install version $VERSION of SCONE CAS $CAS in namespace $CAS_NAMESPACE  within this context? [y/N] " confirm
EOF
)"
pe "$(cat <<'EOF'
confirm=${confirm,,}  # Convert to lowercase
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
if [[ "$confirm" != "y" && "$confirm" != "yes" ]]; then
EOF
)"
pe "$(cat <<'EOF'
  echo "❌ Aborted by user."
EOF
)"
pe "$(cat <<'EOF'
  exit 1
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
echo "✅ Proceeding with context: $K8S_CONTEXT"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '9. Check the number of nodes'
printf '%s\n' ''
printf '%s\n' 'We expect at least 3 nodes in the Kubernetes cluster that have a healthy LAS, i.e., on these nodes, we can run the CAS and the CAS safety services.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
node_count=$(kubectl get nodes -l las.scontain.com/ok=true --no-headers 2>/dev/null | wc -l)
EOF
)"
pe "$(cat <<'EOF'
required=3
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
if (( $node_count < required )); then
EOF
)"
pe "$(cat <<'EOF'
  echo "❌ Error: Only $node_count node(s) found with label 'las.scontain.com/ok=true'. At least $required are required."
EOF
)"
pe "$(cat <<'EOF'
  echo "   NOTE: Continuing anyhow - you might need to edit the desired number of safety services for the CAS to become HEALTHY"
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
echo "✅ $node_count node(s) with label 'las.scontain.com/ok=true' found — OK."
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '10. Installing the CAS '
printf '%s\n' ''
printf '%s\n' 'The following statement installs the CAS and waits until the CAS becomes healthy:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
if ! kubectl provision cas --verbose --wait --set-version $VERSION --namespace "$CAS_NAMESPACE" $DCAP_ARG "$CAS" ; then
EOF
)"
pe "$(cat <<'EOF'
  echo "❌ Failed to create CAS $CAS in namespace $CAS_NAMESPACE."
EOF
)"
pe "$(cat <<'EOF'
  exit 1
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Finally, we show the status of the CAS'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl get cas $CAS -n $CAS_NAMESPACE
EOF
)"
pe "$(cat <<'EOF'
echo "✅ CAS $CAS installed in $CAS_NAMESPACE"
EOF
)"

