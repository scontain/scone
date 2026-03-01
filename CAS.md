# Deploying a CAS instance

We deploy a SCONE CAS (i.e., a Configuration and Attestation Service) in the default cluster. 

![Screencast](docs/install_cas.gif)

- First, we check that we have access to the cluster and the SCONE platform is already installed. 
- Second, we ask the user for the name and the namespace of the CAS. 
- Third, we call `kubectl provision` to install the CAS.

## Steps


1. Ensure that the SCONE operator is installed and up-to-date (see [scone_operator](scone_operator.md))

```bash

DEPLOYMENT="scone-controller-manager"
NAMESPACE="scone-system"

if ! kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "❌ Error: Deployment '$DEPLOYMENT' not found in namespace '$NAMESPACE'."
  echo "   Please run './scripts/reconcile_scone_operator.sh' to the SCONE operator"
  exit 1
fi

echo "✅ Deployment '$DEPLOYMENT' exists in namespace '$NAMESPACE' (i.e., the SCONE Operator is running)."
```

2. ensure that the SCONE `kubectl` plugins are installed:

```bash
if ! kubectl-provision --help >/dev/null ; then
  echo "❌ Error: The 'kubectl-provision' plugin is not installed or not available in your \$PATH."
  echo "ℹ️  Please install it before continuing by running './scripts/reconcile_scone_operator.sh'"
  exit 1
fi
echo "✅ 'kubectl-provision' plugin is available."

if ! kubectl-scone --help >/dev/null ; then
  echo "❌ Error: The 'kubectl-scone' plugin is not installed or not available in your \$PATH."
  echo "ℹ️  Please install it before continuing by running './scripts/install_sconecli.sh'"
  exit 1
fi

echo "✅ 'kubectl-scone' plugin is available."
```


3. Ensure that SGX Plugin and Local Attestation Service (LAS) are `HEALTHY`

First, we check the state of the SGX Plugin. For the LAS to be healthy, the SGX Plugin must be healthy:

```bash
# Try to extract the STATE field (assuming kubectl output includes a column "STATE")
if kubectl get sgx -o json | jq -e '[.items[].status.state] | all(. == "HEALTHY")' >/dev/null; then
  echo "✅ All sgx resources are HEALTHY."
else
  echo "❌ Error: SGX Plugin state is not HEALTHY."
  echo "ℹ️  Please verify that the SGX is running correctly."
  exit 1
fi
```

Next, we check that the LAS is healthy:


```bash
# Try to extract the STATE field (assuming kubectl output includes a column "STATE")
STATE=$(kubectl get las las -o jsonpath='{.status.state}' 2>/dev/null || true)

if [[ "$STATE" != "HEALTHY" ]]; then
  echo "❌ Error: LAS state is '$STATE' (expected: HEALTHY)."
  echo "ℹ️  Please verify that the LAS is running correctly."
  # exit 1
fi

echo "✅ LAS state is HEALTHY."
```

4. We determine your Intel API Key

Please visit <https://api.portal.trustedservices.intel.com/manage-subscriptions> to generate or copy your DCAP API Key. Store this API key in a local environment variable: 

```
export DCAP_KEY="..."
```

In case your cluster has already been installed, you can extract the DCAP_API_KEY as follows:

```bash
    export DEFAULT_DCAP_KEY="00000000000000000000000000000000"
    export DCAP_KEY=${DCAP_KEY:-$DEFAULT_DCAP_KEY}
    if [[ "$DCAP_KEY" == "$DEFAULT_DCAP_KEY" ]] ; then
        echo "WARNING: No DCAP API Key in environment variable DCAP_KEY specified"
        EXISTING_DCAP_KEY=$(kubectl get las las -o json | jq -r '.spec.dcapKey' )

        if [[ "$EXISTING_DCAP_KEY" == "null" ]] ; then
            echo "WARNING: Extraction of DCAP_KEY from LAS failed - using default DCAP_KEY=$DEFAULT_DCAP_KEY - not recommended."
        else
            DCAP_KEY="$EXISTING_DCAP_KEY"
            echo "WARNING: Using DCAP_KEY extracted from LAS - not recommended."
        fi
    fi
```

In case we use the default DCAP API key, we ask the user for some input:

```bash
# Check if DCAP_KEY is empty or unset
if [[ "$DCAP_KEY" == "$DEFAULT_DCAP_KEY" ]]; then
  while true; do
    read -rp "Please enter a 32-character hexadecimal DCAP_KEY: " input

    # Check if input is 32 hex chars (case-insensitive)
    if [[ "$input" =~ ^[0-9a-fA-F]{32}$ ]]; then
      DCAP_KEY="$input"
      export DCAP_KEY
      echo "✅ DCAP_KEY set."
      break
    else
      echo "❌ Invalid input. Must be exactly 32 hex characters (0-9, a-f)."
    fi
  done
  # kubectl provision requires DCAP argument 
  export DCAP_ARG="--dcap-api $DCAP_KEY"

else
  # kubectl provision will extract DCAP_KEY from LAS
  export DCAP_ARG=""
fi
```

5. Determine the current stable version of the SCONE platform:

```bash
VERSION=$(curl -L -s https://raw.githubusercontent.com/scontain/scone/refs/heads/main/stable.txt)
echo "The lastest stable version of SCONE is $VERSION"
```

6. Ensure that Persistent Volumes exist

In some clusters, we have experienced problems with persistent volumes and persisten volume claims. Hence, we check if they exist:

```bash
# Checking if PersistentVolume (PV) and PersistentVolumeClaim (PVC) APIs are available...

required_resources=("persistentvolumes" "persistentvolumeclaims")
kubectl_output=""
max_attempts=30
attempt=0

# Function: Check if required API resources exist in kubectl output
check_required_resources() {
  # Run kubectl and store output (even if it fails)
  if ! kubectl_output=$(kubectl api-resources 2>&1); then
    echo "❌ kubectl api-resources failed: continuing anyhow"
  fi

  missing=0
  for res in "${required_resources[@]}"; do
    if echo "$kubectl_output" | grep -qw "$res"; then
      echo "✅ Found API resource: $res"
    else
      echo "❌ Missing API resource: $res"
      missing=1
    fi
  done

  if [[ $missing -eq 0 ]]; then
    return 0
  else
    return 1
  fi
}


# Retry loop: check resources until all are found or max attempts reached
echo "🔄 Checking for required API resources: ${required_resources[*]}"
until check_required_resources; do
  ((attempt++))
  echo "⏳ Attempt #$attempt failed. Retrying in 2s..."
  if [[ $attempt -ge $max_attempts ]]; then
    echo "❌ Error: Required resources not found after $max_attempts attempts. Aborting."
    exit 1
  fi
  sleep 2
done

echo "✅ PV and PVC API resources are available."

# Check for StorageClass
echo "🔍 Checking for available StorageClasses..."
storage_classes=$(kubectl get storageclass -o name 2>/dev/null || true)

if [[ -z "$storage_classes" ]]; then
  echo "❌ Error: No StorageClasses found. PersistentVolume provisioning may not work."
  exit 1
fi

echo "✅ Found StorageClasses:"
kubectl get storageclass

# Look for default StorageClass
default_class=$(kubectl get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}' || true)

if [[ -z "$default_class" ]]; then
  echo "⚠️  Warning: No default StorageClass is set. You must explicitly define a storageClassName in PVCs."
else
  echo "✅ Default StorageClass: $default_class"
fi
```

7. Determine the name and the namespace of the CAS instance

```bash
echo "✅ Using environment variable CAS (if it exists): ${CAS:-}"
# Prompt for CAS (CAS instance name)
while [[ -z "${CAS:-}" ]]; do
  read -rp "Enter the name of the CAS instance (CAS): " CAS
done

echo "✅ Using environment variable CAS_NAMESPACE (if it exists): ${CAS_NAMESPACE:-}"
# Prompt for CAS_NAMESPACE (Kubernetes namespace)
while [[ -z "${CAS_NAMESPACE:-}" ]]; do
  read -rp "Enter the Kubernetes namespace for CAS (default: default): " CAS_NAMESPACE
  CAS_NAMESPACE="${CAS_NAMESPACE:-default}"
done

# Export the variables
export CAS
export CAS_NAMESPACE

# Confirm to the user
echo "✅ Using CAS: $CAS"
echo "✅ Using namespace: $CAS_NAMESPACE"
```

Check that this CAS instance does not yet exist:

```bash
if kubectl get cas "$CAS" -n "$CAS_NAMESPACE" &>/dev/null; then
  echo "❌ Error: A CAS resource named '$CAS' already exists in namespace '$CAS_NAMESPACE'."
  exit 1
fi

echo "✅ No existing CAS resource named '$CAS' found in namespace '$CAS_NAMESPACE'."
```

8. Confirm that we want to install this CAS

Make sure that we actually want to install CAS $CAS in the namespace $CAS_NAMESPACE of the current cluster

```bash
# Get the current Kubernetes context
K8S_CONTEXT=$(kubectl config current-context 2>/dev/null)

if [[ -z "$K8S_CONTEXT" ]]; then
  echo "❌ Could not determine the current Kubernetes context."
  exit 1
fi

echo "📦 Current Kubernetes context: $K8S_CONTEXT"

# Ask for confirmation
read -rp "Do you want to proceed install version $VERSION of SCONE CAS $CAS in namespace $CAS_NAMESPACE  within this context? [y/N] " confirm
confirm=${confirm,,}  # Convert to lowercase

if [[ "$confirm" != "y" && "$confirm" != "yes" ]]; then
  echo "❌ Aborted by user."
  exit 1
fi

echo "✅ Proceeding with context: $K8S_CONTEXT"
```

9. Check the number of nodes

We expect at least 3 nodes in the Kubernetes cluster that have a healthy LAS, i.e., on these nodes, we can run the CAS and the CAS safety services.

```bash
node_count=$(kubectl get nodes -l las.scontain.com/ok=true --no-headers 2>/dev/null | wc -l)
required=3

if (( $node_count < required )); then
  echo "❌ Error: Only $node_count node(s) found with label 'las.scontain.com/ok=true'. At least $required are required."
  echo "   NOTE: Continuing anyhow - you might need to edit the desired number of safety services for the CAS to become HEALTHY"
fi

echo "✅ $node_count node(s) with label 'las.scontain.com/ok=true' found — OK."
```

10. Installing the CAS 

The following statement installs the CAS and waits until the CAS becomes healthy:

```bash
if ! kubectl provision cas --verbose --wait --set-version $VERSION --namespace "$CAS_NAMESPACE" $DCAP_ARG "$CAS" ; then
  echo "❌ Failed to create CAS $CAS in namespace $CAS_NAMESPACE."
  exit 1
fi
```

Finally, we show the status of the CAS

```bash
kubectl get cas $CAS -n $CAS_NAMESPACE
echo "✅ CAS $CAS installed in $CAS_NAMESPACE"
```
