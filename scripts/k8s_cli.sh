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
printf '%s\n' '## Docker TCP connections'
printf '%s\n' ''
printf '%s\n' 'The Kubernetes toolbox connects to a separate Docker-in-Docker (`dind`) Deployment through `tcp://dind.${CLI_NAMESPACE}.svc.cluster.local:2375`. The [DIND manifest](k8s/dind.template.yaml) already enables that TCP listener, and this script deploys it below. You do not need to enable Docker TCP on your laptop or Kubernetes nodes for the toolbox to use this service.'
printf '%s\n' ''
printf '%s\n' 'The [enable docker script](scripts/enable_docker_tcp.sh) changes the local Linux systemd Docker service on the machine where you execute it. It writes `/etc/systemd/system/docker.service.d/override.conf` and restarts Docker to listen on `0.0.0.0:2375`. Running it on a laptop affects that laptop; running it over SSH on a node affects that node. It does not change remote Kubernetes resources or the node'\''s containerd configuration.'
printf '%s\n' ''
printf '%s\n' '> Note: This Docker TCP listener has no TLS or authentication. Restrict access to trusted clients. The [disable docker script](scripts/disable_docker_tcp.sh) removes the local systemd override. `build.sh` separately requires its configured Docker endpoint at `tcp://172.17.0.1:2375` to be reachable from where the build runs.'
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
printf '%s\n' 'eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --context --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} )'
printf "${RESET}"

eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --context --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} )

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Container Image'
printf '%s\n' ''
printf '%s\n' 'In our pod, we use a versioned image such as `registry.scontain.com/workshop/scone:6.0.8`.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'toolbox_image_override="${CLI_IMAGE:-}"'
printf '%s\n' 'toolbox_namespace_override="${CLI_NAMESPACE:-}"'
printf '%s\n' 'toolbox_version_override="${SCONE_VERSION:-}"'
printf '%s\n' 'export CLI_IMAGE="${CLI_IMAGE:-registry.scontain.com/workshop/scone:${SCONE_VERSION:-$(cat stable.txt)}}"'
printf "${RESET}"

toolbox_image_override="${CLI_IMAGE:-}"
toolbox_namespace_override="${CLI_NAMESPACE:-}"
toolbox_version_override="${SCONE_VERSION:-}"
export CLI_IMAGE="${CLI_IMAGE:-registry.scontain.com/workshop/scone:${SCONE_VERSION:-$(cat stable.txt)}}"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Creating Namespace and Secrets'
printf '%s\n' ''
printf '%s\n' 'By default we install the CLI image in namespace `scone-tools`. You can overwrite the namespace with the help of environment variable `CLI_NAMESPACE`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'export CLI_NAMESPACE="${CLI_NAMESPACE:-scone-tools}"'
printf "${RESET}"

export CLI_NAMESPACE="${CLI_NAMESPACE:-scone-tools}"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Let'\''s ask the user and set the environment variables depending on the input of the user:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'eval $(tplenv --file environment-variables-k8s.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'
printf '%s\n' ''
printf '%s\n' '# Explicit caller settings take precedence over saved Values.yaml defaults.'
printf '%s\n' 'export SCONE_VERSION="${toolbox_version_override:-${SCONE_VERSION:-$(cat stable.txt)}}"'
printf '%s\n' 'export CLI_NAMESPACE="${toolbox_namespace_override:-${CLI_NAMESPACE:-scone-tools}}"'
printf '%s\n' 'export CLI_IMAGE="${toolbox_image_override:-${CLI_IMAGE:-registry.scontain.com/workshop/scone}}"'
printf '%s\n' 'if [[ "$CLI_IMAGE" == "registry.scontain.com/workshop/scone" ]]; then'
printf '%s\n' '  export CLI_IMAGE="${CLI_IMAGE}:${SCONE_VERSION}"'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' '# Render from the resolved environment. Saved values would otherwise override it.'
printf '%s\n' '# Stage output beside its destination so a failed render preserves the old file.'
printf '%s\n' 'render_toolbox_manifest() {'
printf '%s\n' '  local template="$1" output="$2" temporary'
printf '%s\n' '  temporary="$(mktemp "${output}.XXXXXX")"'
printf '%s\n' '  if tplenv --values-file /dev/null --file "$template" --output "$temporary"; then'
printf '%s\n' '    if mv -f "$temporary" "$output"; then'
printf '%s\n' '      return 0'
printf '%s\n' '    fi'
printf '%s\n' '  fi'
printf '%s\n' '  rm -f "$temporary"'
printf '%s\n' '  return 1'
printf '%s\n' '}'
printf "${RESET}"

eval $(tplenv --file environment-variables-k8s.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )

# Explicit caller settings take precedence over saved Values.yaml defaults.
export SCONE_VERSION="${toolbox_version_override:-${SCONE_VERSION:-$(cat stable.txt)}}"
export CLI_NAMESPACE="${toolbox_namespace_override:-${CLI_NAMESPACE:-scone-tools}}"
export CLI_IMAGE="${toolbox_image_override:-${CLI_IMAGE:-registry.scontain.com/workshop/scone}}"
if [[ "$CLI_IMAGE" == "registry.scontain.com/workshop/scone" ]]; then
  export CLI_IMAGE="${CLI_IMAGE}:${SCONE_VERSION}"
fi

# Render from the resolved environment. Saved values would otherwise override it.
# Stage output beside its destination so a failed render preserves the old file.
render_toolbox_manifest() {
  local template="$1" output="$2" temporary
  temporary="$(mktemp "${output}.XXXXXX")"
  if tplenv --values-file /dev/null --file "$template" --output "$temporary"; then
    if mv -f "$temporary" "$output"; then
      return 0
    fi
  fi
  rm -f "$temporary"
  return 1
}

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
printf '%s\n' 'render_toolbox_manifest ./k8s/rbac.template.yaml ./k8s/rbac.yaml'
printf '%s\n' 'kubectl apply -f ./k8s/rbac.yaml'
printf "${RESET}"

render_toolbox_manifest ./k8s/rbac.template.yaml ./k8s/rbac.yaml
kubectl apply -f ./k8s/rbac.yaml

printf "${VIOLET}"
printf '%s\n' '   '
printf '%s\n' '## Deploy DIND'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'render_toolbox_manifest ./k8s/dind.template.yaml ./k8s/dind.yaml'
printf '%s\n' 'kubectl apply -f ./k8s/dind.yaml'
printf "${RESET}"

render_toolbox_manifest ./k8s/dind.template.yaml ./k8s/dind.yaml
kubectl apply -f ./k8s/dind.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Deploy the SCONE CLI'
printf '%s\n' ''
printf '%s\n' 'We change the image name in `deployment.yaml` file for the one you pushed in step 1'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'render_toolbox_manifest ./k8s/deployment.template.yaml ./k8s/deployment.yaml'
printf '%s\n' 'echo "Deploying toolbox image: $CLI_IMAGE"'
printf '%s\n' '# delete old deployment...'
printf '%s\n' '{ kubectl -n "${CLI_NAMESPACE}" delete deployment/scone-toolbox ; kubectl wait --for=delete pod -n "${CLI_NAMESPACE}" -l app=scone-toolbox  --timeout=120s; }  || echo "Ok - it seems no deployment was running"'
printf '%s\n' '# ensure we load the selected container image'
printf '%s\n' 'kubectl apply -f ./k8s/deployment.yaml'
printf '%s\n' 'kubectl -n "$CLI_NAMESPACE" rollout status deployment/scone-toolbox --timeout=300s'
printf '%s\n' 'kubectl -n "$CLI_NAMESPACE" exec deploy/scone-toolbox -c scone-toolbox -- scone-td-build --version'
printf "${RESET}"

render_toolbox_manifest ./k8s/deployment.template.yaml ./k8s/deployment.yaml
echo "Deploying toolbox image: $CLI_IMAGE"
# delete old deployment...
{ kubectl -n "${CLI_NAMESPACE}" delete deployment/scone-toolbox ; kubectl wait --for=delete pod -n "${CLI_NAMESPACE}" -l app=scone-toolbox  --timeout=120s; }  || echo "Ok - it seems no deployment was running"
# ensure we load the selected container image
kubectl apply -f ./k8s/deployment.yaml
kubectl -n "$CLI_NAMESPACE" rollout status deployment/scone-toolbox --timeout=300s
kubectl -n "$CLI_NAMESPACE" exec deploy/scone-toolbox -c scone-toolbox -- scone-td-build --version

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## SSH Access via Port-Forward'
printf '%s\n' ''
printf '%s\n' 'The script checks the effective configuration of the local `scone-toolbox-k8s`'
printf '%s\n' 'alias, including wildcard rules and included SSH configuration files. A working'
printf '%s\n' 'alias connects to `root` on loopback port `2222`. It asks before adding a missing'
printf '%s\n' 'alias or correcting an existing alias. Declining leaves your SSH configuration'
printf '%s\n' 'unchanged, and you can still use the direct SSH command printed below.'
printf '%s\n' ''
printf '%s\n' 'Approved updates preserve other SSH configuration and use an atomic replacement.'
printf '%s\n' 'Set `TOOLBOX_SSH_CONFIG` to use a configuration file other than `~/.ssh/config`.'
printf '%s\n' 'If local port `2222` has no listener, the script asks whether to start'
printf '%s\n' '`kubectl port-forward` in the background. It verifies the SSH banner before'
printf '%s\n' 'reporting the connection as ready, and prints the process ID and log path.'
printf '%s\n' 'The forwarding process survives this script exiting; replacing the toolbox pod'
printf '%s\n' 'ends that forwarding session, so rerun setup or the printed port-forward command.'
printf '%s\n' '`K8S_CLI_DEPLOY_ONLY=true` skips SSH configuration and forwarding prompts for automation.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'toolbox_ssh_args=(--ensure-forward --namespace "$CLI_NAMESPACE" --config "${TOOLBOX_SSH_CONFIG:-$HOME/.ssh/config}")'
printf '%s\n' 'if [[ "${K8S_CLI_DEPLOY_ONLY:-false}" == true ]]; then'
printf '%s\n' '  toolbox_ssh_args+=(--non-interactive)'
printf '%s\n' 'fi'
printf '%s\n' 'if ! python3 ./scripts/configure-toolbox-ssh.py "${toolbox_ssh_args[@]}"; then'
printf '%s\n' '  echo "SSH setup could not complete. To connect directly:"'
printf '%s\n' '  printf '\''  kubectl -n %q port-forward deploy/scone-toolbox 2222:22\n'\'' "$CLI_NAMESPACE"'
printf '%s\n' '  echo "  ssh -p 2222 root@127.0.0.1"'
printf '%s\n' 'fi'
printf "${RESET}"

toolbox_ssh_args=(--ensure-forward --namespace "$CLI_NAMESPACE" --config "${TOOLBOX_SSH_CONFIG:-$HOME/.ssh/config}")
if [[ "${K8S_CLI_DEPLOY_ONLY:-false}" == true ]]; then
  toolbox_ssh_args+=(--non-interactive)
fi
if ! python3 ./scripts/configure-toolbox-ssh.py "${toolbox_ssh_args[@]}"; then
  echo "SSH setup could not complete. To connect directly:"
  printf '  kubectl -n %q port-forward deploy/scone-toolbox 2222:22\n' "$CLI_NAMESPACE"
  echo "  ssh -p 2222 root@127.0.0.1"
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'If you declined automatic forwarding, keep the printed port-forward command'
printf '%s\n' 'running in one terminal. Once forwarding is ready, run `ssh scone-toolbox-k8s`'
printf '%s\n' 'if the alias is configured, or'
printf '%s\n' '`ssh -p 2222 root@127.0.0.1` to connect directly. Authentication uses the private'
printf '%s\n' 'key corresponding to `SSH_PUB_KEY` configured for the toolbox.'
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
printf '%s\n' 'kubectl exec -n "$CLI_NAMESPACE" deploy/scone-toolbox -c scone-toolbox -- scone --help'
printf "${RESET}"

kubectl exec -n "$CLI_NAMESPACE" deploy/scone-toolbox -c scone-toolbox -- scone --help

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '##  Drop into the shell to execute your commands'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'if [[ "${K8S_CLI_DEPLOY_ONLY:-false}" != true ]]; then'
printf '%s\n' '  kubectl exec -n "$CLI_NAMESPACE" -it deploy/scone-toolbox -c scone-toolbox -- bash'
printf '%s\n' 'fi'
printf "${RESET}"

if [[ "${K8S_CLI_DEPLOY_ONLY:-false}" != true ]]; then
  kubectl exec -n "$CLI_NAMESPACE" -it deploy/scone-toolbox -c scone-toolbox -- bash
fi

