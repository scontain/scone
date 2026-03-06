#!/bin/bash
set -euo pipefail

source /scone-registry/scone-registry-env

mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

if [[ -n "${SSH_PUB_KEY:-}" ]]; then
  if ! grep -qxF "$SSH_PUB_KEY" ~/.ssh/authorized_keys; then
    echo "$SSH_PUB_KEY" >>~/.ssh/authorized_keys
  fi
fi

ssh-keygen -A
/usr/sbin/sshd

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

if [[ -n "${REGISTRY_TOKEN+x}" && -n "${REGISTRY_USER+x}" ]]; then
    echo "Attempting docker login..."
    echo "${REGISTRY_TOKEN}" | docker login registry.scontain.com --username "${REGISTRY_USER}" --password-stdin
    echo "Docker login successful."
fi

echo '[[ -f /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion' >>~/.bashrc
echo 'source <(kubectl completion bash)' >>~/.bashrc
echo 'alias k=kubectl; complete -F __start_kubectl k' >>~/.bashrc
echo 'export PATH=$HOME/.cargo/bin:$PATH' >>~/.bashrc
git config --global credential.helper cache


if [[ -n "${DOCKER_HOST:-}" ]]; then
  echo "export DOCKER_HOST=${DOCKER_HOST}" >>~/.bashrc
fi
if [[ -n "${DIND_SERVICE_PORT_DOCKER:-}" ]]; then
  echo "export DIND_SERVICE_PORT_DOCKER=${DIND_SERVICE_PORT_DOCKER}" >>~/.bashrc
fi
if [[ -n "${DOCKER_CONFIG:-}" ]]; then
  echo "export DOCKER_CONFIG=${DOCKER_CONFIG}" >>~/.bashrc
fi



cd
exec "$@"
