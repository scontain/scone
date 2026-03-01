#!/usr/bin/env bash

set -Eeuo pipefail

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

escape_unescaped_dollars() {
  local input="$1"
  local output=""
  local prev=""
  local ch
  local i

  for ((i=0; i<${#input}; i++)); do
    ch="${input:i:1}"
    if [[ "$ch" == '$' && "$prev" != '\' ]]; then
      output+='\\$'
    else
      output+="$ch"
    fi
    prev="$ch"
  done

  printf "%s" "$output"
}

pe() {
  local cmd="$*"
  local display_cmd
  display_cmd=$(escape_unescaped_dollars "$cmd")
  printf "%b" "$ORANGE"
  slow_type "$display_cmd"
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

pe ''
pe 'DEPLOYMENT="scone-controller-manager"'
pe 'NAMESPACE="scone-system"'
pe ''
pe 'if ! kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" >/dev/null 2>&1; then'
pe '  echo "❌ Error: Deployment '\''$DEPLOYMENT'\'' not found in namespace '\''$NAMESPACE'\''."'
pe '  echo "   Please run '\''./scripts/reconcile_scone_operator.sh'\'' to the SCONE operator"'
pe '  exit 1'
pe 'fi'
pe ''
pe 'echo "✅ Deployment '\''$DEPLOYMENT'\'' exists in namespace '\''$NAMESPACE'\'' (i.e., the SCONE Operator is running)."'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '2. ensure that the SCONE `kubectl` plugins are installed:'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'if ! kubectl-provision --help >/dev/null ; then'
pe '  echo "❌ Error: The '\''kubectl-provision'\'' plugin is not installed or not available in your \$PATH."'
pe '  echo "ℹ️  Please install it before continuing by running '\''./scripts/reconcile_scone_operator.sh'\''"'
pe '  exit 1'
pe 'fi'
pe 'echo "✅ '\''kubectl-provision'\'' plugin is available."'
pe ''
pe 'if ! kubectl-scone --help >/dev/null ; then'
pe '  echo "❌ Error: The '\''kubectl-scone'\'' plugin is not installed or not available in your \$PATH."'
pe '  echo "ℹ️  Please install it before continuing by running '\''./scripts/install_sconecli.sh'\''"'
pe '  exit 1'
pe 'fi'
pe ''
pe 'echo "✅ '\''kubectl-scone'\'' plugin is available."'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' '3. Ensure that SGX Plugin and Local Attestation Service (LAS) are `HEALTHY`'
printf '%s\n' ''
printf '%s\n' 'First, we check the state of the SGX Plugin. For the LAS to be healthy, the SGX Plugin must be healthy:'
printf '%s\n' ''
printf "%b" "$RESET"

pe '# Try to extract the STATE field (assuming kubectl output includes a column "STATE")'
pe 'if kubectl get sgx -o json | jq -e '\''[.items[].status.state] | all(. == "HEALTHY")'\'' >/dev/null; then'
pe '  echo "✅ All sgx resources are HEALTHY."'
pe 'else'
pe '  echo "❌ Error: SGX Plugin state is not HEALTHY."'
pe '  echo "ℹ️  Please verify that the SGX is running correctly."'
pe '  exit 1'
pe 'fi'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Next, we check that the LAS is healthy:'
printf '%s\n' ''
printf '%s\n' ''
printf "%b" "$RESET"

pe '# Try to extract the STATE field (assuming kubectl output includes a column "STATE")'
pe 'STATE=$(kubectl get las las -o jsonpath='\''{.status.state}'\'' 2>/dev/null || true)'
pe ''
pe 'if [[ "$STATE" != "HEALTHY" ]]; then'
pe '  echo "❌ Error: LAS state is '\''$STATE'\'' (expected: HEALTHY)."'
pe '  echo "ℹ️  Please verify that the LAS is running correctly."'
pe '  # exit 1'
pe 'fi'
pe ''
pe 'echo "✅ LAS state is HEALTHY."'

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

pe '    export DEFAULT_DCAP_KEY="00000000000000000000000000000000"'
pe '    export DCAP_KEY=${DCAP_KEY:-$DEFAULT_DCAP_KEY}'
pe '    if [[ "$DCAP_KEY" == "$DEFAULT_DCAP_KEY" ]] ; then'
pe '        echo "WARNING: No DCAP API Key in environment variable DCAP_KEY specified"'
pe '        EXISTING_DCAP_KEY=$(kubectl get las las -o json | jq -r '\''.spec.dcapKey'\'' )'
pe ''
pe '        if [[ "$EXISTING_DCAP_KEY" == "null" ]] ; then'
pe '            echo "WARNING: Extraction of DCAP_KEY from LAS failed - using default DCAP_KEY=$DEFAULT_DCAP_KEY - not recommended."'
pe '        else'
pe '            DCAP_KEY="$EXISTING_DCAP_KEY"'
pe '            echo "WARNING: Using DCAP_KEY extracted from LAS - not recommended."'
pe '        fi'
pe '    fi'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'In case we use the default DCAP API key, we ask the user for some input:'
printf '%s\n' ''
printf "%b" "$RESET"

pe '# Check if DCAP_KEY is empty or unset'
pe 'if [[ "$DCAP_KEY" == "$DEFAULT_DCAP_KEY" ]]; then'
pe '  while true; do'
pe '    read -rp "Please enter a 32-character hexadecimal DCAP_KEY: " input'
pe ''
pe '    # Check if input is 32 hex chars (case-insensitive)'
pe '    if [[ "$input" =~ ^[0-9a-fA-F]{32}$ ]]; then'
pe '      DCAP_KEY="$input"'
pe '      export DCAP_KEY'
pe '      echo "✅ DCAP_KEY set."'
pe '      break'
pe '    else'
pe '      echo "❌ Invalid input. Must be exactly 32 hex characters (0-9, a-f)."'
pe '    fi'
pe '  done'
pe '  # kubectl provision requires DCAP argument '
pe '  export DCAP_ARG="--dcap-api $DCAP_KEY"'
pe ''
pe 'else'
pe '  # kubectl provision will extract DCAP_KEY from LAS'
pe '  export DCAP_ARG=""'
pe 'fi'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '5. Determine the current stable version of the SCONE platform:'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'VERSION=$(curl -L -s https://raw.githubusercontent.com/scontain/scone/refs/heads/main/stable.txt)'
pe 'echo "The lastest stable version of SCONE is $VERSION"'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '6. Ensure that Persistent Volumes exist'
printf '%s\n' ''
printf '%s\n' 'In some clusters, we have experienced problems with persistent volumes and persisten volume claims. Hence, we check if they exist:'
printf '%s\n' ''
printf "%b" "$RESET"

pe '# Checking if PersistentVolume (PV) and PersistentVolumeClaim (PVC) APIs are available...'
pe ''
pe 'required_resources=("persistentvolumes" "persistentvolumeclaims")'
pe 'kubectl_output=""'
pe 'max_attempts=30'
pe 'attempt=0'
pe ''
pe '# Function: Check if required API resources exist in kubectl output'
pe 'check_required_resources() {'
pe '  # Run kubectl and store output (even if it fails)'
pe '  if ! kubectl_output=$(kubectl api-resources 2>&1); then'
pe '    echo "❌ kubectl api-resources failed: continuing anyhow"'
pe '  fi'
pe ''
pe '  missing=0'
pe '  for res in "${required_resources[@]}"; do'
pe '    if echo "$kubectl_output" | grep -qw "$res"; then'
pe '      echo "✅ Found API resource: $res"'
pe '    else'
pe '      echo "❌ Missing API resource: $res"'
pe '      missing=1'
pe '    fi'
pe '  done'
pe ''
pe '  if [[ $missing -eq 0 ]]; then'
pe '    return 0'
pe '  else'
pe '    return 1'
pe '  fi'
pe '}'
pe ''
pe ''
pe '# Retry loop: check resources until all are found or max attempts reached'
pe 'echo "🔄 Checking for required API resources: ${required_resources[*]}"'
pe 'until check_required_resources; do'
pe '  ((attempt++))'
pe '  echo "⏳ Attempt #$attempt failed. Retrying in 2s..."'
pe '  if [[ $attempt -ge $max_attempts ]]; then'
pe '    echo "❌ Error: Required resources not found after $max_attempts attempts. Aborting."'
pe '    exit 1'
pe '  fi'
pe '  sleep 2'
pe 'done'
pe ''
pe 'echo "✅ PV and PVC API resources are available."'
pe ''
pe '# Check for StorageClass'
pe 'echo "🔍 Checking for available StorageClasses..."'
pe 'storage_classes=$(kubectl get storageclass -o name 2>/dev/null || true)'
pe ''
pe 'if [[ -z "$storage_classes" ]]; then'
pe '  echo "❌ Error: No StorageClasses found. PersistentVolume provisioning may not work."'
pe '  exit 1'
pe 'fi'
pe ''
pe 'echo "✅ Found StorageClasses:"'
pe 'kubectl get storageclass'
pe ''
pe '# Look for default StorageClass'
pe 'default_class=$(kubectl get storageclass -o jsonpath='\''{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}'\'' || true)'
pe ''
pe 'if [[ -z "$default_class" ]]; then'
pe '  echo "⚠️  Warning: No default StorageClass is set. You must explicitly define a storageClassName in PVCs."'
pe 'else'
pe '  echo "✅ Default StorageClass: $default_class"'
pe 'fi'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '7. Determine the name and the namespace of the CAS instance'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'echo "✅ Using environment variable CAS (if it exists): ${CAS:-}"'
pe '# Prompt for CAS (CAS instance name)'
pe 'while [[ -z "${CAS:-}" ]]; do'
pe '  read -rp "Enter the name of the CAS instance (CAS): " CAS'
pe 'done'
pe ''
pe 'echo "✅ Using environment variable CAS_NAMESPACE (if it exists): ${CAS_NAMESPACE:-}"'
pe '# Prompt for CAS_NAMESPACE (Kubernetes namespace)'
pe 'while [[ -z "${CAS_NAMESPACE:-}" ]]; do'
pe '  read -rp "Enter the Kubernetes namespace for CAS (default: default): " CAS_NAMESPACE'
pe '  CAS_NAMESPACE="${CAS_NAMESPACE:-default}"'
pe 'done'
pe ''
pe '# Export the variables'
pe 'export CAS'
pe 'export CAS_NAMESPACE'
pe ''
pe '# Confirm to the user'
pe 'echo "✅ Using CAS: $CAS"'
pe 'echo "✅ Using namespace: $CAS_NAMESPACE"'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Check that this CAS instance does not yet exist:'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'if kubectl get cas "$CAS" -n "$CAS_NAMESPACE" &>/dev/null; then'
pe '  echo "❌ Error: A CAS resource named '\''$CAS'\'' already exists in namespace '\''$CAS_NAMESPACE'\''."'
pe '  exit 1'
pe 'fi'
pe ''
pe 'echo "✅ No existing CAS resource named '\''$CAS'\'' found in namespace '\''$CAS_NAMESPACE'\''."'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '8. Confirm that we want to install this CAS'
printf '%s\n' ''
printf '%s\n' 'Make sure that we actually want to install CAS $CAS in the namespace $CAS_NAMESPACE of the current cluster'
printf '%s\n' ''
printf "%b" "$RESET"

pe '# Get the current Kubernetes context'
pe 'K8S_CONTEXT=$(kubectl config current-context 2>/dev/null)'
pe ''
pe 'if [[ -z "$K8S_CONTEXT" ]]; then'
pe '  echo "❌ Could not determine the current Kubernetes context."'
pe '  exit 1'
pe 'fi'
pe ''
pe 'echo "📦 Current Kubernetes context: $K8S_CONTEXT"'
pe ''
pe '# Ask for confirmation'
pe 'read -rp "Do you want to proceed install version $VERSION of SCONE CAS $CAS in namespace $CAS_NAMESPACE  within this context? [y/N] " confirm'
pe 'confirm=${confirm,,}  # Convert to lowercase'
pe ''
pe 'if [[ "$confirm" != "y" && "$confirm" != "yes" ]]; then'
pe '  echo "❌ Aborted by user."'
pe '  exit 1'
pe 'fi'
pe ''
pe 'echo "✅ Proceeding with context: $K8S_CONTEXT"'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '9. Check the number of nodes'
printf '%s\n' ''
printf '%s\n' 'We expect at least 3 nodes in the Kubernetes cluster that have a healthy LAS, i.e., on these nodes, we can run the CAS and the CAS safety services.'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'node_count=$(kubectl get nodes -l las.scontain.com/ok=true --no-headers 2>/dev/null | wc -l)'
pe 'required=3'
pe ''
pe 'if (( $node_count < required )); then'
pe '  echo "❌ Error: Only $node_count node(s) found with label '\''las.scontain.com/ok=true'\''. At least $required are required."'
pe '  echo "   NOTE: Continuing anyhow - you might need to edit the desired number of safety services for the CAS to become HEALTHY"'
pe 'fi'
pe ''
pe 'echo "✅ $node_count node(s) with label '\''las.scontain.com/ok=true'\'' found — OK."'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '10. Installing the CAS '
printf '%s\n' ''
printf '%s\n' 'The following statement installs the CAS and waits until the CAS becomes healthy:'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'if ! kubectl provision cas --verbose --wait --set-version $VERSION --namespace "$CAS_NAMESPACE" $DCAP_ARG "$CAS" ; then'
pe '  echo "❌ Failed to create CAS $CAS in namespace $CAS_NAMESPACE."'
pe '  exit 1'
pe 'fi'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Finally, we show the status of the CAS'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'kubectl get cas $CAS -n $CAS_NAMESPACE'
pe 'echo "✅ CAS $CAS installed in $CAS_NAMESPACE"'

