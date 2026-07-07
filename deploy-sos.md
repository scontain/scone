# SCONE OSV Scan Deployment

This document explains how to deploy the Confidential SCONE OSV Scan to a Kubernetes cluster.

## Configuration Variables

```bash
# Variables to configure
SCONE_CLI_IMAGE="registry.scontain.com/sconecuratedimages/sconecli:alpine-scone5.9.0"
```

## Required Environment Variables

```bash
# List of env vars to check
env_vars=(
  GH_TOKEN
  REGISTRY_USERNAME
  REGISTRY_EMAIL
  REGISTRY_ACCESS_TOKEN    # needed by operator_controller
  SOS_IMAGE_REGISTRY_URL
  SOS_IMAGE_REGISTRY_REPOSITORY
  SOS_IMAGE_VERSION
  SOS_IMAGE_REGISTRY_USERNAME
  SOS_IMAGE_REGISTRY_PASSWORD
)
```

## Required Dependencies

```bash
# List of commands to check
deps=(docker kubectl jq cosign helm nc)
```

## Required Resources

This script assumes that the scone-operator is already installed in the Kubernetes cluster, and that there is a running CAS instance.

## Environment Validation

Check that all required environment variables are set:

```bash
function check_env() {
  echo "🔍 Checking environment variables..."
  for var in "${env_vars[@]}"; do
    if [[ -z "${!var-}" ]]; then
      echo "❌ Required environment variable \$$var is not set." >&2
      exit 1
    fi
  done
  echo "✅ All required environment variables are set."
}
```

## Dependency Validation

Verify that all required command-line tools are installed:

```bash
function check_deps() {
  echo "🔍 Verifying dependencies..."
  for cmd in "${deps[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
      echo "❌ '$cmd' not found in PATH. Please install it." >&2
      exit 1
    fi
  done
  echo "✅ All dependencies are installed."
}
```

## Kubernetes Cluster Validation

Verify connectivity to the Kubernetes cluster:

```bash
function check_k8s() {
  echo "🔍 Checking kubectl client..."
  if ! kubectl version --client &> /dev/null; then
    echo "❌ kubectl client is not installed or not on PATH." >&2
    exit 1
  fi

  echo "🔍 Checking API‑server connectivity by listing namespaces..."
  if ! kubectl get namespaces &> /dev/null; then
    echo "❌ Cannot reach Kubernetes API server. Please check your KUBECONFIG and current context." >&2
    exit 1
  fi

  echo "✅ Kubernetes cluster is accessible."
}
```

## Helm Repository Setup

Add and update SCONE Helm repositories:

```bash
function add_helm_repos() {
  echo "📝 Checking and adding Helm repositories…"

  if ! helm repo list 2>/dev/null | grep -q "^sconeapps"; then
    echo "  • Adding sconeapps repository..."
    helm repo add sconeapps "https://${GH_TOKEN}@raw.githubusercontent.com/scontain/sconeapps/scone.cloud/"
  else
    echo "  • sconeapps repository already exists. Skipping."
  fi

  if ! helm repo list 2>/dev/null | grep -q "^sconeappsee"; then
    echo "  • Adding sconeappsee repository..."
    helm repo add sconeappsee "https://${GH_TOKEN}@raw.githubusercontent.com/scontain/sconeappsee/main/"
  else
    echo "  • sconeappsee repository already exists. Skipping."
  fi

  echo "  • Updating Helm repositories..."
  helm repo update
  echo "✅ Helm repos configured."
}
```

## CAS Attestation and Default

Attest CAS and set it as default:

```bash
function cas_attest_and_default() {
  echo "🔐 Attesting CAS and setting default…"
  pushd ../scone >/dev/null
  # function wrapper for scone CLI
  function scone() {
    docker run --rm -v "$PWD/security-policies":/root/security-policies \
      -v "$HOME/.cas":/root/.cas --workdir /root --network host \
      "${SCONE_CLI_IMAGE}" scone "$@"
  }

  # Kill any existing port-forward to port 8081
  pkill -f "port-forward.*8081" 2>/dev/null || true

  kubectl port-forward cas-0 8081 >/dev/null 2>&1 &
  PORT_FORWARD_PID=$!
  sleep 5

  scone cas attest localhost \
    --mrsigner 195e5a6df987d6a515dd083750c1ea352283f8364d3ec9142b0d593988c6ed2d \
    --isvsvn 5 \
    --isvprodid 41316 \
    --accept-sw-hardening-needed \
    --accept-configuration-needed

  scone cas set-default localhost

  # Clean up port-forward
  kill "$PORT_FORWARD_PID" 2>/dev/null || true

  popd >/dev/null
  echo "✅ CAS attested and default set."
}
```

## MaxScale CAS Sessions

Create CAS sessions for MaxScale database:

```bash
function create_cas_sessions_maxscale() {
  echo "🔐 Creating CAS sessions for MaxScale…"
  pushd ../scone >/dev/null
  # Kill any existing port-forward to port 8081
  pkill -f "port-forward.*8081" 2>/dev/null || true

  kubectl port-forward cas-0 8081 >/dev/null 2>&1 &
  PORT_FORWARD_PID=$!
  sleep 5
  function scone() {
    docker run --rm -v "$(pwd)":/root \
      -v "$HOME/.cas":/root/.cas --workdir /root --network host \
      "${SCONE_CLI_IMAGE}" scone "$@"
  }

  for policy in certificates maxscale primary replica backup dba-policy; do
    scone session create "security-policies/${policy}.yaml"
  done
  # Clean up port-forward
  kill "$PORT_FORWARD_PID" 2>/dev/null || true
  popd >/dev/null
  echo "✅ CAS sessions created."
}
```

## MaxScale Installation

Install MaxScale via Helm with confidential computing configuration:

```bash
function install_maxscale() {
  echo "🚀 Installing MaxScale via Helm…"
  helm install maxscale sconeappsee/mariadb-spr \
    --set scone.attestation.cas=cas.default \
    --set scone.attestation.maxscaleConfigID=mariadb-maxscale/maxscale \
    --set scone.attestation.maxmeConfigID=mariadb-maxscale/maxme \
    --set scone.attestation.primaryBaseConfigID=mariadb-primary \
    --set scone.attestation.replicaBaseConfigID=mariadb-replica \
    --set scone.attestation.backupBaseConfigID=mariadb-backup \
    --set maxscale.enabled=true \
    --set maxscale.metrics.enabled=true \
    --set replica.replicas=1 \
    --set primary.metrics.enabled=true \
    --set replica.metrics.enabled=true \
    --set backup.enabled=true \
    --set backup.storageClass=default \
    --set primary.persistence.enabled=true \
    --set primary.persistence.storageClass=default \
    --set replica.persistence.enabled=true \
    --set replica.persistence.storageClass=default \
    --set replica.persistence.size=40Gi \
    --set primary.persistence.size=40Gi \
    --set backup.size=40Gi
  echo "✅ MaxScale installed."
}
```

## SOS Image Build and Push

Build and push SOS container images to registry:

```bash
function build_and_push_sos() {
  pushd .. >/dev/null
  echo "🔑 Logging in to SOS image registry..."
  echo "${SOS_IMAGE_REGISTRY_PASSWORD}" | docker login "${SOS_IMAGE_REGISTRY_URL}" \
    --username "${SOS_IMAGE_REGISTRY_USERNAME}" --password-stdin
  echo "📦 Building and pushing SOS images…"
  docker build -f cmd/sconeosvdbmanager/Dockerfile.sconified \
    -t "${SOS_IMAGE_REGISTRY_URL}/${SOS_IMAGE_REGISTRY_REPOSITORY}:${SOS_IMAGE_VERSION}-dbmanager" .
  docker build -f cmd/sconeosvscan/Dockerfile.sconified \
    -t "${SOS_IMAGE_REGISTRY_URL}/${SOS_IMAGE_REGISTRY_REPOSITORY}:${SOS_IMAGE_VERSION}-osvscan" .
  docker push "${SOS_IMAGE_REGISTRY_URL}/${SOS_IMAGE_REGISTRY_REPOSITORY}:${SOS_IMAGE_VERSION}-dbmanager"
  docker push "${SOS_IMAGE_REGISTRY_URL}/${SOS_IMAGE_REGISTRY_REPOSITORY}:${SOS_IMAGE_VERSION}-osvscan"
  popd >/dev/null
  echo "✅ SOS images built and pushed."
}
```

## Namespace and Secret Creation

Create the sos namespace and image pull secret:

```bash
function create_namespace_and_secret() {
  echo "🌐 Ensuring 'sos' namespace exists…"
  kubectl create namespace sos --dry-run=client -o yaml | kubectl apply -f -
  echo "🔑 Creating pull secret in 'sos'…"
  kubectl create secret docker-registry git-lsd \
    --docker-server="${SOS_IMAGE_REGISTRY_URL}" \
    --docker-username="${SOS_IMAGE_REGISTRY_USERNAME}" \
    --docker-password="${SOS_IMAGE_REGISTRY_PASSWORD}" \
    --namespace sos --dry-run=client -o yaml \
    | kubectl apply -f -
  echo "✅ Namespace and pull secret ready."
}
```

## SOS Deployment

Deploy the SOS application to Kubernetes:

```bash
function deploy_sos() {
  echo "🚀 Deploying SOS manifests…"
  pushd ../scone >/dev/null
  ./k8s-manifest-fill.sh sos-manifest-template.yaml sos-manifest.yaml
  kubectl apply -f sos-manifest.yaml
  popd >/dev/null
  echo "✅ SOS deployed."
}
```

## SOS CAS Policy Preparation

Prepare the CAS policy for SOS with MaxScale:

```bash
function prepare_sos_cas_policy() {
  echo "🔄 Preparing SOS CAS policy…"
  pushd ../scone >/dev/null
  ./maxscale.sh sos-cas-policy-maxscale-template.yaml sos.yaml
  popd >/dev/null
  echo "✅ SOS CAS policy prepared."
}
```

## SOS CAS Session Creation

Create the CAS session for SOS:

```bash
function create_sos_cas_session() {
  echo "🔐 Creating SOS CAS session…"
  pushd ../scone >/dev/null
  # Kill any existing port-forward to port 8081
  pkill -f "port-forward.*8081" 2>/dev/null || true

  kubectl port-forward cas-0 8081 >/dev/null 2>&1 &
  PORT_FORWARD_PID=$!
  sleep 5
  function scone() {
    docker run --rm -v "$(pwd)":/root \
      -v "$HOME/.cas":/root/.cas --workdir /root --network host \
      "${SCONE_CLI_IMAGE}" scone "$@"
  }
  scone session create sos.yaml
  # Clean up port-forward
  kill "$PORT_FORWARD_PID" 2>/dev/null || true
  popd >/dev/null
  echo "✅ SOS CAS session created."
}
```

## Main Execution Flow

Execute all deployment steps in order:

```bash
check_env
check_deps
check_k8s
add_helm_repos
cas_attest_and_default
create_cas_sessions_maxscale
install_maxscale
build_and_push_sos
create_namespace_and_secret
deploy_sos
prepare_sos_cas_policy
create_sos_cas_session


echo "🎉 All steps completed successfully!"
```