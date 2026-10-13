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
printf '%s\n' 'SSH public keys belong in the ignored `Values.credentials.yaml`, alongside local'
printf '%s\n' 'registry credentials. Shared `Values.yaml` must not contain a user'\''s SSH key.'
printf '%s\n' 'An explicit `SSH_PUB_KEY` takes precedence for this deployment; otherwise we use'
printf '%s\n' 'its saved local value, falling back to the first public key in `~/.ssh`.'
printf '%s\n' 'The following snippet resolves the SSH key and registry credentials together'
printf '%s\n' 'and saves them using an atomic update:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'toolbox_ssh_key_override="${SSH_PUB_KEY:-}"'
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
printf '%s\n' '# tplenv prioritizes saved values. Stage its update to protect local credentials'
printf '%s\n' '# if rendering fails, then restore an explicit caller key for this deployment.'
printf '%s\n' 'read -r -a toolbox_confirmation_options <<< "${CONFIRM_ALL_ENVIRONMENT_VARIABLES}"'
printf '%s\n' 'toolbox_credentials_temporary="$(mktemp Values.credentials.yaml.XXXXXX)"'
printf '%s\n' 'if [[ -f Values.credentials.yaml ]]; then'
printf '%s\n' '  cp -p Values.credentials.yaml "$toolbox_credentials_temporary"'
printf '%s\n' 'fi'
printf '%s\n' 'if toolbox_ssh_exports="$(tplenv --values "$toolbox_credentials_temporary" --file toolbox.credentials.md --context --create-values-file --eval "${toolbox_confirmation_options[@]}")"; then'
printf '%s\n' '  chmod 600 "$toolbox_credentials_temporary"'
printf '%s\n' '  mv -f "$toolbox_credentials_temporary" Values.credentials.yaml'
printf '%s\n' '  eval "$toolbox_ssh_exports"'
printf '%s\n' 'else'
printf '%s\n' '  rm -f "$toolbox_credentials_temporary"'
printf '%s\n' '  exit 1'
printf '%s\n' 'fi'
printf '%s\n' 'export SSH_PUB_KEY="${toolbox_ssh_key_override:-$SSH_PUB_KEY}"'
printf "${RESET}"

toolbox_ssh_key_override="${SSH_PUB_KEY:-}"
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

# tplenv prioritizes saved values. Stage its update to protect local credentials
# if rendering fails, then restore an explicit caller key for this deployment.
read -r -a toolbox_confirmation_options <<< "${CONFIRM_ALL_ENVIRONMENT_VARIABLES}"
toolbox_credentials_temporary="$(mktemp Values.credentials.yaml.XXXXXX)"
if [[ -f Values.credentials.yaml ]]; then
  cp -p Values.credentials.yaml "$toolbox_credentials_temporary"
fi
if toolbox_ssh_exports="$(tplenv --values "$toolbox_credentials_temporary" --file toolbox.credentials.md --context --create-values-file --eval "${toolbox_confirmation_options[@]}")"; then
  chmod 600 "$toolbox_credentials_temporary"
  mv -f "$toolbox_credentials_temporary" Values.credentials.yaml
  eval "$toolbox_ssh_exports"
else
  rm -f "$toolbox_credentials_temporary"
  exit 1
fi
export SSH_PUB_KEY="${toolbox_ssh_key_override:-$SSH_PUB_KEY}"

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
printf '%s\n' 'export CLI_IMAGE="${CLI_IMAGE:-registry.scontain.com/workshop/scone}"'
printf "${RESET}"

toolbox_image_override="${CLI_IMAGE:-}"
toolbox_namespace_override="${CLI_NAMESPACE:-}"
toolbox_version_override="${SCONE_VERSION:-}"
export CLI_IMAGE="${CLI_IMAGE:-registry.scontain.com/workshop/scone}"

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
printf '%s\n' 'toolbox_values_temporary="$(mktemp Values.yaml.XXXXXX)"'
printf '%s\n' 'if [[ -f Values.yaml ]]; then'
printf '%s\n' '  cp -p Values.yaml "$toolbox_values_temporary"'
printf '%s\n' 'fi'
printf '%s\n' 'if toolbox_environment_exports="$(tplenv --values "$toolbox_values_temporary" --file environment-variables-k8s.md --create-values-file --context --eval "${toolbox_confirmation_options[@]}" --output /dev/null)"; then'
printf '%s\n' '  mv -f "$toolbox_values_temporary" Values.yaml'
printf '%s\n' '  eval "$toolbox_environment_exports"'
printf '%s\n' 'else'
printf '%s\n' '  rm -f "$toolbox_values_temporary"'
printf '%s\n' '  exit 1'
printf '%s\n' 'fi'
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

toolbox_values_temporary="$(mktemp Values.yaml.XXXXXX)"
if [[ -f Values.yaml ]]; then
  cp -p Values.yaml "$toolbox_values_temporary"
fi
if toolbox_environment_exports="$(tplenv --values "$toolbox_values_temporary" --file environment-variables-k8s.md --create-values-file --context --eval "${toolbox_confirmation_options[@]}" --output /dev/null)"; then
  mv -f "$toolbox_values_temporary" Values.yaml
  eval "$toolbox_environment_exports"
else
  rm -f "$toolbox_values_temporary"
  exit 1
fi

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
printf '%s\n' 'The credentials selected by `tplenv` are used for all three registry secrets:'
printf '%s\n' '`scone-registry` and `sconeapps` provide image pull credentials, while'
printf '%s\n' '`scone-registry-env` provides the toolbox'\''s Docker login credentials and registry'
printf '%s\n' 'address. Every run creates or updates these secrets before recreating the toolbox,'
printf '%s\n' 'so a previous deployment cannot retain an old login. Updating a secret must succeed'
printf '%s\n' 'before deployment continues.'
printf '%s\n' ''
printf '%s\n' 'Credentials go directly to Kubernetes through standard input; no plaintext'
printf '%s\n' '`scone-registry.env` file is written by toolbox setup. To use a different registry,'
printf '%s\n' 'select it through `tplenv` together with its username and token, and set `CLI_IMAGE`'
printf '%s\n' 'to the corresponding toolbox image.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl create ns "$CLI_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -'
printf '%s\n' 'python3 ./scripts/reconcile-toolbox-registry.py --namespace "$CLI_NAMESPACE"'
printf "${RESET}"

kubectl create ns "$CLI_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
python3 ./scripts/reconcile-toolbox-registry.py --namespace "$CLI_NAMESPACE"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Add RBAC to the namespace'
printf '%s\n' ''
printf '%s\n' 'The RBAC template gives the toolbox service account workload permissions in its'
printf '%s\n' 'own namespace and adds a `scone-demo-runner-$CLI_NAMESPACE` Role and RoleBinding'
printf '%s\n' 'in `default`. The latter permits demo secrets, ConfigMaps, services, pods, Jobs,'
printf '%s\n' 'Deployments, SCONE policies, and NetworkPolicies. Demo `NAMESPACE` can therefore'
printf '%s\n' 'remain `default`, independently of `CAS_NAMESPACE`.'
printf '%s\n' ''
printf '%s\n' 'Infrastructure access remains read-only: these additional permissions do not'
printf '%s\n' 'allow modifying CAS instances, RBAC, cluster resources, or `kube-system` workloads.'
printf '%s\n' 'Run this setup using a Kubernetes account allowed to create these roles and'
printf '%s\n' 'bindings. We render the template and apply it before deploying the toolbox:'
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
printf '%s\n' 'alias connects to `root` on loopback port `2222` by default and uses'
printf '%s\n' '`HostKeyAlias scone-toolbox-k8s` to keep its host key separate from other local'
printf '%s\n' 'tunnels. Set `TOOLBOX_SSH_PORT=2200` to use another port. It asks before adding a missing'
printf '%s\n' 'alias or correcting an existing alias. Declining leaves your SSH configuration'
printf '%s\n' 'unchanged, and you can still use the direct SSH command printed below.'
printf '%s\n' ''
printf '%s\n' 'Approved updates preserve other SSH configuration and use an atomic replacement.'
printf '%s\n' 'Set `TOOLBOX_SSH_CONFIG` to use a configuration file other than `~/.ssh/config`.'
printf '%s\n' 'The helper stores the forwarding PID and process identity under'
printf '%s\n' '`~/.cache/scone-toolbox` (`--state-dir` can change this location). On the next'
printf '%s\n' 'interactive setup, it checks and stops its previously recorded forward before'
printf '%s\n' 'offering to start a new one. It leaves unrelated processes alone, including'
printf '%s\n' 'processes that reuse an old PID. It verifies the SSH banner before reporting'
printf '%s\n' 'readiness and prints the process ID and log path. The forward survives this'
printf '%s\n' 'script exiting; rerun setup after replacing the toolbox pod.'
printf '%s\n' '`K8S_CLI_DEPLOY_ONLY=true` skips SSH configuration and forwarding prompts for automation.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'toolbox_ssh_args=(--ensure-forward --namespace "$CLI_NAMESPACE" --config "${TOOLBOX_SSH_CONFIG:-$HOME/.ssh/config}")'
printf '%s\n' 'if [[ -n "${TOOLBOX_SSH_PORT:-}" ]]; then'
printf '%s\n' '  toolbox_ssh_args+=(--local-port "$TOOLBOX_SSH_PORT")'
printf '%s\n' 'fi'
printf '%s\n' 'if [[ "${K8S_CLI_DEPLOY_ONLY:-false}" == true ]]; then'
printf '%s\n' '  toolbox_ssh_args+=(--non-interactive)'
printf '%s\n' 'fi'
printf '%s\n' 'if ! python3 ./scripts/configure-toolbox-ssh.py "${toolbox_ssh_args[@]}"; then'
printf '%s\n' '  echo "SSH setup could not complete. Follow the connection instructions printed above."'
printf '%s\n' 'fi'
printf "${RESET}"

toolbox_ssh_args=(--ensure-forward --namespace "$CLI_NAMESPACE" --config "${TOOLBOX_SSH_CONFIG:-$HOME/.ssh/config}")
if [[ -n "${TOOLBOX_SSH_PORT:-}" ]]; then
  toolbox_ssh_args+=(--local-port "$TOOLBOX_SSH_PORT")
fi
if [[ "${K8S_CLI_DEPLOY_ONLY:-false}" == true ]]; then
  toolbox_ssh_args+=(--non-interactive)
fi
if ! python3 ./scripts/configure-toolbox-ssh.py "${toolbox_ssh_args[@]}"; then
  echo "SSH setup could not complete. Follow the connection instructions printed above."
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'If you declined automatic forwarding, keep the printed port-forward command'
printf '%s\n' 'running in one terminal. Once forwarding is ready, run `ssh scone-toolbox-k8s`'
printf '%s\n' 'if the alias is configured, or'
printf '%s\n' '`ssh -o HostKeyAlias=scone-toolbox-k8s -p 2222 root@127.0.0.1` to connect directly'
printf '%s\n' '(use the configured port if different). Authentication uses the private key'
printf '%s\n' 'corresponding to `SSH_PUB_KEY` configured for the toolbox.'
printf '%s\n' ''
printf '%s\n' 'Host keys are generated when the image is built. After a trusted image upgrade,'
printf '%s\n' 'remove the old toolbox key with `ssh-keygen -R scone-toolbox-k8s`, then reconnect.'
printf '%s\n' 'The helper never removes known host keys automatically. To refresh forwarding'
printf '%s\n' 'without redeploying, run'
printf '%s\n' '`python3 ./scripts/configure-toolbox-ssh.py --ensure-forward --namespace scone-tools`'
printf '%s\n' '(with `--local-port 2200` if configured).'
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
printf '%s\n' 'wait_for_pod_logs "$CLI_NAMESPACE" app=scone-toolbox || true'
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

wait_for_pod_logs "$CLI_NAMESPACE" app=scone-toolbox || true

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

