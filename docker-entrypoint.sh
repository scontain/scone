#!/bin/bash
set -euo pipefail

source /scone-registry/scone-registry-env

mkdir -p ~/.kube
if [[ -f /kubeconfig ]]; then
  cp /kubeconfig ~/.kube/config
else
  APISERVER="${APISERVER:-}"
  if [[ -z "$APISERVER" ]]; then
    if [[ -n "${KUBERNETES_SERVICE_HOST:-}" && -n "${KUBERNETES_SERVICE_PORT:-}" ]]; then
      APISERVER="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}"
    else
      APISERVER="https://kubernetes.default.svc"
    fi
  fi
  TOKEN="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
  CA="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
  NS="$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)"
  kubectl config set-cluster in-cluster --server="$APISERVER" --certificate-authority="$CA" --embed-certs=true
  kubectl config set-credentials sa --token="$TOKEN"
  kubectl config set-context in-cluster --cluster=in-cluster --user=sa --namespace="$NS"
  kubectl config use-context in-cluster
fi

cd "$HOME"

# Check Kubernetes cluster connectivity
RED='\033[0;31m'
NC='\033[0m' # No Color
if ! kubectl cluster-info &>/dev/null; then
  echo -e "${RED}❌ No Kubernetes cluster detected via kubectl. Is your cluster running?${NC}"
fi

if [[ -n "${SCONE_REGISTRY_ACCESS_TOKEN}" && -n "${SCONE_REGISTRY_USERNAME}" ]]; then
    echo "Attempting docker login..."
    echo "${SCONE_REGISTRY_ACCESS_TOKEN}" | docker login registry.scontain.com --username "${SCONE_REGISTRY_USERNAME}" --password-stdin
    echo "Docker login successful."
fi

echo '[[ -f /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion' >>~/.bashrc
echo 'source <(kubectl completion bash)' >>~/.bashrc
echo 'alias k=kubectl; complete -F __start_kubectl k' >>~/.bashrc
echo 'export PATH=$HOME/.cargo/bin:$PATH' >>~/.bashrc
git config --global credential.helper cache

cd
exec "$@"
