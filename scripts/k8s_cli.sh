#!/usr/bin/env bash

set -euo pipefail
export CONFIRM_ALL_ENVIRONMENT_VARIABLES=${CONFIRM_ALL_ENVIRONMENT_VARIABLES:-"--force"}

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

printf "${VIOLET}"
printf '%s\n' '# Deploying SCONE CLI Image on Kubernetes'
printf '%s\n' ''
printf '%s\n' 'This document describes how to set up a pod in a Kubernetes cluster that contains all the tools to transform cloud-native applications into confidential applications. To do so, we need a Docker daemon that we use to transform existing native container images of the application into confidential container images used by the confidential cloud-native application.'
printf '%s\n' ''
printf '%s\n' '![Screencast](docs/k8s_cli.gif)'
printf '%s\n' ''
printf '%s\n' '## Prerequisites'
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' 'We first ensure that command `kubectl` is installed:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'check_command() {'
printf '%s\n' '  command -v "$1" &>/dev/null'
printf '%s\n' '}'
printf '%s\n' ''
printf '%s\n' '# Auto-install kubectl if not present'
printf '%s\n' 'if ! check_command kubectl; then'
printf '%s\n' '  echo "Please run ./scripts/prerequisite_check.sh first"'
printf '%s\n' 'else'
printf '%s\n' '  echo "✔️ kubectl is already installed."'
printf '%s\n' 'fi'
printf "${RESET}"

check_command() {
  command -v "$1" &>/dev/null
}

# Auto-install kubectl if not present
if ! check_command kubectl; then
  echo "Please run ./scripts/prerequisite_check.sh first"
else
  echo "✔️ kubectl is already installed."
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Next, we check that we have access to a Kubernetes cluster. This Kubernetes cluster is used to install a pod to run the transformation of applications.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# checking that we have access to a cluster'
printf '%s\n' 'kubectl get nodes || { echo "Failed to list Kubernetes nodes: Exiting" ; exit 1; }'
printf "${RESET}"

# checking that we have access to a cluster
kubectl get nodes || { echo "Failed to list Kubernetes nodes: Exiting" ; exit 1; }

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Enabling TCP on Docker Daemon'
printf '%s\n' ''
printf '%s\n' 'The image requires TCP on the Docker Daemon. If you are using a Kubernetes cluster with confidential nodes, we need to enable TCP on the Docker Daemon by running the [enable docker script](scripts/enable_docker_tcp.sh)'
printf '%s\n' ''
printf '%s\n' '> Note: Enabling TCP on Docker is a serious security risk. Use this option only if you run a private Kubernetes cluster. We provide a [script](scripts/disable_docker_tcp.sh) to disable TCP when you are done using the Docker daemon.'
printf '%s\n' ''
printf '%s\n' '## Deployment'
printf '%s\n' ''
printf '%s\n' 'You need to log in to the Docker registry `registry.scontain.com` with an account that has access to the namespace `scone.cloud`. If you have not yet registered with `gitlab.scontain.com`, please check <https://sconedocs.github.io/registry/> on how to register an account.'
printf '%s\n' ''
printf '%s\n' 'Please determine your username and create an access token with read permission for registries - as described in <https://sconedocs.github.io/registry/>. '
printf '%s\n' ''
printf '%s\n' '## SSH Key for Toolbox Access'
printf '%s\n' ''
printf '%s\n' 'The toolbox container starts `sshd` automatically with password authentication disabled. To allow SSH login, we pass your public key in environment variable `SSH_PUB_KEY`.'
printf '%s\n' ''
printf '%s\n' 'The following snippet tries to initialize `SSH_PUB_KEY` from your local `~/.ssh` directory and writes it into `Values.credentials.yaml`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'if [[ -z "${SSH_PUB_KEY:-}" ]]; then'
printf '%s\n' '  for key_file in "$HOME/.ssh/id_ed25519.pub" "$HOME/.ssh/id_rsa.pub" "$HOME/.ssh/id_ecdsa.pub"; do'
printf '%s\n' '    if [[ -f "$key_file" ]]; then'
printf '%s\n' '      export SSH_PUB_KEY'
printf '%s\n' '      SSH_PUB_KEY="$(head -n 1 "$key_file")"'
printf '%s\n' '      echo "Using SSH public key from $key_file"'
printf '%s\n' '      break'
printf '%s\n' '    fi'
printf '%s\n' '  done'
printf '%s\n' 'fi'
printf '%s\n' ''
printf "${RESET}"

if [[ -z "${SSH_PUB_KEY:-}" ]]; then
  for key_file in "$HOME/.ssh/id_ed25519.pub" "$HOME/.ssh/id_rsa.pub" "$HOME/.ssh/id_ecdsa.pub"; do
    if [[ -f "$key_file" ]]; then
      export SSH_PUB_KEY
      SSH_PUB_KEY="$(head -n 1 "$key_file")"
      echo "Using SSH public key from $key_file"
      break
    fi
  done
fi


printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Next, we set all environment variables related to the registry credentials.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Map SCONE_REGISTRY_* env vars to the names expected by tplenv'
printf '%s\n' 'export REGISTRY_USER="${REGISTRY_USER:-${SCONE_REGISTRY_USERNAME:-}}"'
printf '%s\n' 'export REGISTRY_TOKEN="${REGISTRY_TOKEN:-${SCONE_REGISTRY_ACCESS_TOKEN:-}}"'
printf '%s\n' ''
printf '%s\n' 'eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --context --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} )'
printf "${RESET}"

# Map SCONE_REGISTRY_* env vars to the names expected by tplenv
export REGISTRY_USER="${REGISTRY_USER:-${SCONE_REGISTRY_USERNAME:-}}"
export REGISTRY_TOKEN="${REGISTRY_TOKEN:-${SCONE_REGISTRY_ACCESS_TOKEN:-}}"

eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --context --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} )

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Container Image'
printf '%s\n' ''
printf '%s\n' 'In our pod, we use a pre-built image `registry.scontain.com/workshop/scone`'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'export CLI_IMAGE="${CLI_IMAGE:-registry.scontain.com/workshop/scone}"'
printf "${RESET}"

export CLI_IMAGE="${CLI_IMAGE:-registry.scontain.com/workshop/scone}"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Creating Namespace and Secrets'
printf '%s\n' ''
printf '%s\n' 'By default we install the CLI image in namespace `scone-tools`. You can overwrite the namespace with the help of environment variable `CLI_NAMESPACE`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'export CLI_NAMESPACE="scone-tools"'
printf "${RESET}"

export CLI_NAMESPACE="scone-tools"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Let'\''s ask the user and set the environment variables depending on the input of the user:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'eval $(tplenv --file environment-variables-k8s.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'
printf "${RESET}"

eval $(tplenv --file environment-variables-k8s.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Next we create a Kubernetes namespace and pull secrets. We assume here that we can use the same PAT for different pull secrets. Actually, we create two pull secrets:'
printf '%s\n' ''
printf '%s\n' '- `scone-registry`: we use this in the context of some examples. This permits use to store these examples on a different repo.'
printf '%s\n' ''
printf '%s\n' ' - `sconeapps`: we use this secret to pull the container images from `registry.scontain.com`.'
printf '%s\n' ''
printf '%s\n' 'Please adjust in case you use a unique PAT for each pull secret.'
printf '%s\n' ''
printf '%s\n' 'Also, in case you built and pushed the image to a different registry, you need to adjust the value for `docker-server` in the  `docker-registry` secret accordingly.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl create ns $CLI_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -'
printf '%s\n' ''
printf '%s\n' 'SECRET_NAME="scone-registry"'
printf '%s\n' ''
printf '%s\n' 'if kubectl get secret "$SECRET_NAME" -n "$CLI_NAMESPACE" >/dev/null 2>&1; then'
printf '%s\n' '  echo "Secret '\''$SECRET_NAME'\'' exists in namespace '\''$CLI_NAMESPACE'\'' - do not replace."'
printf '%s\n' 'else'
printf '%s\n' '  echo "Secret '\''$SECRET_NAME'\'' not found in namespace '\''$CLI_NAMESPACE'\'' - Creating it."'
printf '%s\n' '  kubectl -n $CLI_NAMESPACE create secret docker-registry "$SECRET_NAME" \'
printf '%s\n' '    --docker-server=registry.scontain.com \'
printf '%s\n' '    --docker-username="$REGISTRY_USER" \'
printf '%s\n' '    --docker-password="$REGISTRY_TOKEN"'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' 'SECRET_NAME="sconeapps"'
printf '%s\n' ''
printf '%s\n' 'if kubectl get secret "$SECRET_NAME" -n "$CLI_NAMESPACE" >/dev/null 2>&1; then'
printf '%s\n' '  echo "Secret '\''$SECRET_NAME'\'' exists in namespace '\''$CLI_NAMESPACE'\'' - do not replace."'
printf '%s\n' 'else'
printf '%s\n' '  echo "Secret '\''$SECRET_NAME'\'' not found in namespace '\''$CLI_NAMESPACE'\'' - Creating it."'
printf '%s\n' '  kubectl -n $CLI_NAMESPACE create secret docker-registry "$SECRET_NAME" \'
printf '%s\n' '    --docker-server=registry.scontain.com \'
printf '%s\n' '    --docker-username="$REGISTRY_USER" \'
printf '%s\n' '    --docker-password="$REGISTRY_TOKEN"'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' 'SECRET_NAME="scone-registry-env"'
printf '%s\n' ''
printf '%s\n' 'if kubectl get secret "$SECRET_NAME" -n "$CLI_NAMESPACE" >/dev/null 2>&1; then'
printf '%s\n' '  echo "Secret '\''$SECRET_NAME'\'' exists in namespace '\''$CLI_NAMESPACE'\'' - do not replace."'
printf '%s\n' 'else'
printf '%s\n' ''
printf '%s\n' 'cat > ./scone-registry.env <<SEOF'
printf '%s\n' 'export REGISTRY_TOKEN="$REGISTRY_TOKEN"'
printf '%s\n' 'export REGISTRY_USER="$REGISTRY_USER"'
printf '%s\n' 'SEOF'
printf '%s\n' ''
printf '%s\n' 'kubectl -n $CLI_NAMESPACE create secret generic $SECRET_NAME \'
printf '%s\n' '--from-file=$SECRET_NAME=./scone-registry.env'
printf '%s\n' 'fi'
printf "${RESET}"

kubectl create ns $CLI_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

SECRET_NAME="scone-registry"

if kubectl get secret "$SECRET_NAME" -n "$CLI_NAMESPACE" >/dev/null 2>&1; then
  echo "Secret '$SECRET_NAME' exists in namespace '$CLI_NAMESPACE' - do not replace."
else
  echo "Secret '$SECRET_NAME' not found in namespace '$CLI_NAMESPACE' - Creating it."
  kubectl -n $CLI_NAMESPACE create secret docker-registry "$SECRET_NAME" \
    --docker-server=registry.scontain.com \
    --docker-username="$REGISTRY_USER" \
    --docker-password="$REGISTRY_TOKEN"
fi

SECRET_NAME="sconeapps"

if kubectl get secret "$SECRET_NAME" -n "$CLI_NAMESPACE" >/dev/null 2>&1; then
  echo "Secret '$SECRET_NAME' exists in namespace '$CLI_NAMESPACE' - do not replace."
else
  echo "Secret '$SECRET_NAME' not found in namespace '$CLI_NAMESPACE' - Creating it."
  kubectl -n $CLI_NAMESPACE create secret docker-registry "$SECRET_NAME" \
    --docker-server=registry.scontain.com \
    --docker-username="$REGISTRY_USER" \
    --docker-password="$REGISTRY_TOKEN"
fi

SECRET_NAME="scone-registry-env"

if kubectl get secret "$SECRET_NAME" -n "$CLI_NAMESPACE" >/dev/null 2>&1; then
  echo "Secret '$SECRET_NAME' exists in namespace '$CLI_NAMESPACE' - do not replace."
else

cat > ./scone-registry.env <<SEOF
export REGISTRY_TOKEN="$REGISTRY_TOKEN"
export REGISTRY_USER="$REGISTRY_USER"
SEOF

kubectl -n $CLI_NAMESPACE create secret generic $SECRET_NAME \
--from-file=$SECRET_NAME=./scone-registry.env
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '   '
printf '%s\n' '## Add RBAC to the namespace'
printf '%s\n' ''
printf '%s\n' 'We provide a template to define the RBAC for the CLI image. We instantiate this template first and then apply the RBAC:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'tplenv --file ./k8s/rbac.template.yaml --output ./k8s/rbac.yaml'
printf '%s\n' 'kubectl apply -f ./k8s/rbac.yaml'
printf "${RESET}"

tplenv --file ./k8s/rbac.template.yaml --output ./k8s/rbac.yaml
kubectl apply -f ./k8s/rbac.yaml

printf "${VIOLET}"
printf '%s\n' '   '
printf '%s\n' '## Deploy DIND'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'tplenv --file ./k8s/dind.template.yaml --output ./k8s/dind.yaml'
printf '%s\n' 'kubectl apply -f ./k8s/dind.yaml'
printf "${RESET}"

tplenv --file ./k8s/dind.template.yaml --output ./k8s/dind.yaml
kubectl apply -f ./k8s/dind.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Deploy the SCONE CLI'
printf '%s\n' ''
printf '%s\n' 'We change the image name in `deployment.yaml` file for the one you pushed in step 1'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'tplenv --file ./k8s/deployment.template.yaml --output ./k8s/deployment.yaml'
printf '%s\n' '# delete old deployment...'
printf '%s\n' '{ kubectl -n "${CLI_NAMESPACE}" delete deployment/scone-toolbox ; kubectl wait --for=delete pod -n "${CLI_NAMESPACE}" -l app=scone-toolbox  --timeout=120s; }  || echo "Ok - it seems no deployment was running"'
printf '%s\n' '# ensure we load the latest container image'
printf '%s\n' 'kubectl apply -f ./k8s/deployment.yaml'
printf "${RESET}"

tplenv --file ./k8s/deployment.template.yaml --output ./k8s/deployment.yaml
# delete old deployment...
{ kubectl -n "${CLI_NAMESPACE}" delete deployment/scone-toolbox ; kubectl wait --for=delete pod -n "${CLI_NAMESPACE}" -l app=scone-toolbox  --timeout=120s; }  || echo "Ok - it seems no deployment was running"
# ensure we load the latest container image
kubectl apply -f ./k8s/deployment.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## SSH Access via Port-Forward'
printf '%s\n' ''
printf '%s\n' 'After deployment, wait until the toolbox pod is `Ready`, then forward local port `2222` to container port `22`:'
printf '%s\n' ''
printf '%s\n' 'kubectl -n "${CLI_NAMESPACE}" wait pod -l app=scone-toolbox \'
printf '%s\n' '  --for=condition=Ready --timeout=300s'
printf '%s\n' 'kill $(cat /tmp/pf-2222.pid) || true'
printf '%s\n' 'rm /tmp/pf-2222.pid || true'
printf '%s\n' 'kubectl -n "${CLI_NAMESPACE}" port-forward deploy/scone-toolbox 2222:22 &  echo $! > /tmp/pf-2222.pid'
printf '%s\n' ''
printf '%s\n' 'In another terminal, connect via SSH (password login is disabled, key-based login only):'
printf '%s\n' ''
printf '%s\n' 'ssh -p 2222 root@127.0.0.1'
printf '%s\n' ''
printf '%s\n' 'If you want a convenient host alias, add an idempotent block to `~/.ssh/config`:'
printf '%s\n' ''
printf '%s\n' 'SSH_CONFIG="${HOME}/.ssh/config"'
printf '%s\n' 'HOST_ALIAS="scone-toolbox-k8s"'
printf '%s\n' 'BEGIN_MARKER="# >>> ${HOST_ALIAS} >>>"'
printf '%s\n' 'END_MARKER="# <<< ${HOST_ALIAS} <<<"'
printf '%s\n' ''
printf '%s\n' 'mkdir -p "${HOME}/.ssh"'
printf '%s\n' 'chmod 700 "${HOME}/.ssh"'
printf '%s\n' 'touch "${SSH_CONFIG}"'
printf '%s\n' 'chmod 600 "${SSH_CONFIG}"'
printf '%s\n' ''
printf '%s\n' 'tmp_config="$(mktemp)"'
printf '%s\n' 'awk -v begin="${BEGIN_MARKER}" -v end="${END_MARKER}" '\'''
printf '%s\n' '  $0 == begin {skip=1; next}'
printf '%s\n' '  $0 == end   {skip=0; next}'
printf '%s\n' '  !skip       {print}'
printf '%s\n' ''\'' "${SSH_CONFIG}" > "${tmp_config}"'
printf '%s\n' ''
printf '%s\n' 'printf '\''%s\n'\'' \'
printf '%s\n' '  "${BEGIN_MARKER}" \'
printf '%s\n' '  "Host ${HOST_ALIAS}" \'
printf '%s\n' '  "  HostName 127.0.0.1" \'
printf '%s\n' '  "  Port 2222" \'
printf '%s\n' '  "  User root" \'
printf '%s\n' '  "  ServerAliveInterval 30" \'
printf '%s\n' '  "  StrictHostKeyChecking accept-new" \'
printf '%s\n' '  "${END_MARKER}" \'
printf '%s\n' '  >> "${tmp_config}"'
printf '%s\n' ''
printf '%s\n' 'mv "${tmp_config}" "${SSH_CONFIG}"'
printf '%s\n' ''
printf '%s\n' 'Then connect using the alias:'
printf '%s\n' ''
printf '%s\n' 'ssh scone-toolbox-k8s'
printf '%s\n' ''
printf '%s\n' '##  Watch the logs of the pod'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'wait_for_pod_logs() {'
printf '%s\n' '  local ns="${1:-default}"'
printf '%s\n' '  local label="${2:?Usage: wait_for_pod_logs <namespace> <label>}"'
printf '%s\n' '  local timeout="${3:-200s}"'
printf '%s\n' ''
printf '%s\n' '  echo "⏳ Waiting for pod with label $label in namespace $ns..."'
printf '%s\n' '  kubectl wait pod -n "$ns" -l "$label" --for=condition=Ready --timeout="$timeout" || {'
printf '%s\n' '    echo "❌ Timeout waiting for pod to become Ready."'
printf '%s\n' '    return 1'
printf '%s\n' '  }'
printf '%s\n' ''
printf '%s\n' '  local pod'
printf '%s\n' '  pod=$(kubectl get pod -n "$ns" -l "$label" -o jsonpath='\''{.items[0].metadata.name}'\'')'
printf '%s\n' ''
printf '%s\n' '  echo "📜 Showing first 10 lines of logs from pod: $pod"'
printf '%s\n' '  kubectl logs -n "$ns" "$pod" | head -n 10'
printf '%s\n' '}'
printf '%s\n' ''
printf '%s\n' 'wait_for_pod_logs $CLI_NAMESPACE app=scone-toolbox || true'
printf "${RESET}"

wait_for_pod_logs() {
  local ns="${1:-default}"
  local label="${2:?Usage: wait_for_pod_logs <namespace> <label>}"
  local timeout="${3:-200s}"

  echo "⏳ Waiting for pod with label $label in namespace $ns..."
  kubectl wait pod -n "$ns" -l "$label" --for=condition=Ready --timeout="$timeout" || {
    echo "❌ Timeout waiting for pod to become Ready."
    return 1
  }

  local pod
  pod=$(kubectl get pod -n "$ns" -l "$label" -o jsonpath='{.items[0].metadata.name}')

  echo "📜 Showing first 10 lines of logs from pod: $pod"
  kubectl logs -n "$ns" "$pod" | head -n 10
}

wait_for_pod_logs $CLI_NAMESPACE app=scone-toolbox || true

printf "${VIOLET}"
printf '%s\n' '  '
printf '%s\n' '##  Run the SCONE CLI using help'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl exec -n $CLI_NAMESPACE -it deploy/scone-toolbox  -c scone-toolbox -- scone --help'
printf "${RESET}"

kubectl exec -n $CLI_NAMESPACE -it deploy/scone-toolbox  -c scone-toolbox -- scone --help

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '##  Drop into the shell to execute your commands'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl exec -n $CLI_NAMESPACE -it deploy/scone-toolbox  -c scone-toolbox -- bash'
printf "${RESET}"

kubectl exec -n $CLI_NAMESPACE -it deploy/scone-toolbox  -c scone-toolbox -- bash

