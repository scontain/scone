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
printf "%b" "$RESET"

pe "$(cat <<'EOF'
check_command() {
EOF
)"
pe "$(cat <<'EOF'
  command -v "$1" &>/dev/null
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
# Auto-install kubectl if not present
EOF
)"
pe "$(cat <<'EOF'
if ! check_command kubectl; then
EOF
)"
pe "$(cat <<'EOF'
  echo "Please run ./scripts/prerequisite_check.sh first"
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  echo "✔️ kubectl is already installed."
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Next, we check that we have access to a Kubernetes cluster. This Kubernetes cluster is used to install a pod to run the transformation of applications.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# checking that we have access to a cluster
EOF
)"
pe "$(cat <<'EOF'
kubectl get nodes || { echo "Failed to list Kubernetes nodes: Exiting" ; exit 1; }
EOF
)"

printf "%b" "$LILAC"
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
printf "%b" "$RESET"

pe "$(cat <<'EOF'
if [[ -z "${SSH_PUB_KEY:-}" ]]; then
EOF
)"
pe "$(cat <<'EOF'
  for key_file in "$HOME/.ssh/id_ed25519.pub" "$HOME/.ssh/id_rsa.pub" "$HOME/.ssh/id_ecdsa.pub"; do
EOF
)"
pe "$(cat <<'EOF'
    if [[ -f "$key_file" ]]; then
EOF
)"
pe "$(cat <<'EOF'
      export SSH_PUB_KEY
EOF
)"
pe "$(cat <<'EOF'
      SSH_PUB_KEY="$(head -n 1 "$key_file")"
EOF
)"
pe "$(cat <<'EOF'
      echo "Using SSH public key from $key_file"
EOF
)"
pe "$(cat <<'EOF'
      break
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
fi
EOF
)"
pe "$(cat <<'EOF'

EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Next, we set all environment variables related to the registry credentials.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --context --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} )
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Container Image'
printf '%s\n' ''
printf '%s\n' 'In our pod, we use a versioned image such as `registry.scontain.com/workshop/scone:6.0.8`.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
toolbox_image_override="${CLI_IMAGE:-}"
EOF
)"
pe "$(cat <<'EOF'
toolbox_namespace_override="${CLI_NAMESPACE:-}"
EOF
)"
pe "$(cat <<'EOF'
toolbox_version_override="${SCONE_VERSION:-}"
EOF
)"
pe "$(cat <<'EOF'
export CLI_IMAGE="${CLI_IMAGE:-registry.scontain.com/workshop/scone:${SCONE_VERSION:-$(cat stable.txt)}}"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Creating Namespace and Secrets'
printf '%s\n' ''
printf '%s\n' 'By default we install the CLI image in namespace `scone-tools`. You can overwrite the namespace with the help of environment variable `CLI_NAMESPACE`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
export CLI_NAMESPACE="${CLI_NAMESPACE:-scone-tools}"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Let'\''s ask the user and set the environment variables depending on the input of the user:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
eval $(tplenv --file environment-variables-k8s.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Explicit caller settings take precedence over saved Values.yaml defaults.
EOF
)"
pe "$(cat <<'EOF'
export SCONE_VERSION="${toolbox_version_override:-${SCONE_VERSION:-$(cat stable.txt)}}"
EOF
)"
pe "$(cat <<'EOF'
export CLI_NAMESPACE="${toolbox_namespace_override:-${CLI_NAMESPACE:-scone-tools}}"
EOF
)"
pe "$(cat <<'EOF'
export CLI_IMAGE="${toolbox_image_override:-${CLI_IMAGE:-registry.scontain.com/workshop/scone}}"
EOF
)"
pe "$(cat <<'EOF'
if [[ "$CLI_IMAGE" == "registry.scontain.com/workshop/scone" ]]; then
EOF
)"
pe "$(cat <<'EOF'
  export CLI_IMAGE="${CLI_IMAGE}:${SCONE_VERSION}"
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
# Render from the resolved environment. Saved values would otherwise override it.
EOF
)"
pe "$(cat <<'EOF'
# Stage output beside its destination so a failed render preserves the old file.
EOF
)"
pe "$(cat <<'EOF'
render_toolbox_manifest() {
EOF
)"
pe "$(cat <<'EOF'
  local template="$1" output="$2" temporary
EOF
)"
pe "$(cat <<'EOF'
  temporary="$(mktemp "${output}.XXXXXX")"
EOF
)"
pe "$(cat <<'EOF'
  if tplenv --values-file /dev/null --file "$template" --output "$temporary"; then
EOF
)"
pe "$(cat <<'EOF'
    if mv -f "$temporary" "$output"; then
EOF
)"
pe "$(cat <<'EOF'
      return 0
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
pe "$(cat <<'EOF'
  rm -f "$temporary"
EOF
)"
pe "$(cat <<'EOF'
  return 1
EOF
)"
pe "$(cat <<'EOF'
}
EOF
)"

printf "%b" "$LILAC"
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
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl create ns $CLI_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
SECRET_NAME="scone-registry"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
if kubectl get secret "$SECRET_NAME" -n "$CLI_NAMESPACE" >/dev/null 2>&1; then
EOF
)"
pe "$(cat <<'EOF'
  echo "Secret '$SECRET_NAME' exists in namespace '$CLI_NAMESPACE' - do not replace."
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  echo "Secret '$SECRET_NAME' not found in namespace '$CLI_NAMESPACE' - Creating it."
EOF
)"
pe "$(cat <<'EOF'
  kubectl -n $CLI_NAMESPACE create secret docker-registry "$SECRET_NAME" \
    --docker-server=registry.scontain.com \
    --docker-username="$REGISTRY_USER" \
    --docker-password="$REGISTRY_TOKEN"
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
SECRET_NAME="sconeapps"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
if kubectl get secret "$SECRET_NAME" -n "$CLI_NAMESPACE" >/dev/null 2>&1; then
EOF
)"
pe "$(cat <<'EOF'
  echo "Secret '$SECRET_NAME' exists in namespace '$CLI_NAMESPACE' - do not replace."
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  echo "Secret '$SECRET_NAME' not found in namespace '$CLI_NAMESPACE' - Creating it."
EOF
)"
pe "$(cat <<'EOF'
  kubectl -n $CLI_NAMESPACE create secret docker-registry "$SECRET_NAME" \
    --docker-server=registry.scontain.com \
    --docker-username="$REGISTRY_USER" \
    --docker-password="$REGISTRY_TOKEN"
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
SECRET_NAME="scone-registry-env"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
if kubectl get secret "$SECRET_NAME" -n "$CLI_NAMESPACE" >/dev/null 2>&1; then
EOF
)"
pe "$(cat <<'EOF'
  echo "Secret '$SECRET_NAME' exists in namespace '$CLI_NAMESPACE' - do not replace."
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
cat > ./scone-registry.env <<SEOF
EOF
)"
pe "$(cat <<'EOF'
export REGISTRY_TOKEN="$REGISTRY_TOKEN"
EOF
)"
pe "$(cat <<'EOF'
export REGISTRY_USER="$REGISTRY_USER"
EOF
)"
pe "$(cat <<'EOF'
SEOF
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
kubectl -n $CLI_NAMESPACE create secret generic $SECRET_NAME \
--from-file=$SECRET_NAME=./scone-registry.env
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '   '
printf '%s\n' '## Add RBAC to the namespace'
printf '%s\n' ''
printf '%s\n' 'We provide a template to define the RBAC for the CLI image. We instantiate this template first and then apply the RBAC:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
render_toolbox_manifest ./k8s/rbac.template.yaml ./k8s/rbac.yaml
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f ./k8s/rbac.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' '   '
printf '%s\n' '## Deploy DIND'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
render_toolbox_manifest ./k8s/dind.template.yaml ./k8s/dind.yaml
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f ./k8s/dind.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Deploy the SCONE CLI'
printf '%s\n' ''
printf '%s\n' 'We change the image name in `deployment.yaml` file for the one you pushed in step 1'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
render_toolbox_manifest ./k8s/deployment.template.yaml ./k8s/deployment.yaml
EOF
)"
pe "$(cat <<'EOF'
echo "Deploying toolbox image: $CLI_IMAGE"
EOF
)"
pe "$(cat <<'EOF'
# delete old deployment...
EOF
)"
pe "$(cat <<'EOF'
{ kubectl -n "${CLI_NAMESPACE}" delete deployment/scone-toolbox ; kubectl wait --for=delete pod -n "${CLI_NAMESPACE}" -l app=scone-toolbox  --timeout=120s; }  || echo "Ok - it seems no deployment was running"
EOF
)"
pe "$(cat <<'EOF'
# ensure we load the selected container image
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f ./k8s/deployment.yaml
EOF
)"
pe "$(cat <<'EOF'
kubectl -n "$CLI_NAMESPACE" rollout status deployment/scone-toolbox --timeout=300s
EOF
)"
pe "$(cat <<'EOF'
kubectl -n "$CLI_NAMESPACE" exec deploy/scone-toolbox -c scone-toolbox -- scone-td-build --version
EOF
)"

printf "%b" "$LILAC"
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
printf "%b" "$RESET"

pe "$(cat <<'EOF'
toolbox_ssh_args=(--ensure-forward --namespace "$CLI_NAMESPACE" --config "${TOOLBOX_SSH_CONFIG:-$HOME/.ssh/config}")
EOF
)"
pe "$(cat <<'EOF'
if [[ "${K8S_CLI_DEPLOY_ONLY:-false}" == true ]]; then
EOF
)"
pe "$(cat <<'EOF'
  toolbox_ssh_args+=(--non-interactive)
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"
pe "$(cat <<'EOF'
if ! python3 ./scripts/configure-toolbox-ssh.py "${toolbox_ssh_args[@]}"; then
EOF
)"
pe "$(cat <<'EOF'
  echo "SSH setup could not complete. To connect directly:"
EOF
)"
pe "$(cat <<'EOF'
  printf '  kubectl -n %q port-forward deploy/scone-toolbox 2222:22\n' "$CLI_NAMESPACE"
EOF
)"
pe "$(cat <<'EOF'
  echo "  ssh -p 2222 root@127.0.0.1"
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'If you declined automatic forwarding, keep the printed port-forward command'
printf '%s\n' 'running in one terminal. Once forwarding is ready, run `ssh scone-toolbox-k8s`'
printf '%s\n' 'if the alias is configured, or'
printf '%s\n' '`ssh -p 2222 root@127.0.0.1` to connect directly. Authentication uses the private'
printf '%s\n' 'key corresponding to `SSH_PUB_KEY` configured for the toolbox.'
printf '%s\n' ''
printf '%s\n' '##  Watch the logs of the pod'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
wait_for_pod_logs() {
EOF
)"
pe "$(cat <<'EOF'
  local ns="${1:-default}"
EOF
)"
pe "$(cat <<'EOF'
  local label="${2:?Usage: wait_for_pod_logs <namespace> <label>}"
EOF
)"
pe "$(cat <<'EOF'
  local timeout="${3:-200s}"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
  echo "⏳ Waiting for pod with label $label in namespace $ns..."
EOF
)"
pe "$(cat <<'EOF'
  kubectl wait pod -n "$ns" -l "$label" --for=condition=Ready --timeout="$timeout" || {
EOF
)"
pe "$(cat <<'EOF'
    echo "❌ Timeout waiting for pod to become Ready."
EOF
)"
pe "$(cat <<'EOF'
    return 1
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
  local pod
EOF
)"
pe "$(cat <<'EOF'
  pod=$(kubectl get pod -n "$ns" -l "$label" -o jsonpath='{.items[0].metadata.name}')
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
  echo "📜 Showing first 10 lines of logs from pod: $pod"
EOF
)"
pe "$(cat <<'EOF'
  kubectl logs -n "$ns" "$pod" | head -n 10
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
wait_for_pod_logs $CLI_NAMESPACE app=scone-toolbox || true
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' '  '
printf '%s\n' '##  Run the SCONE CLI using help'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl exec -n "$CLI_NAMESPACE" deploy/scone-toolbox -c scone-toolbox -- scone --help
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '##  Drop into the shell to execute your commands'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
if [[ "${K8S_CLI_DEPLOY_ONLY:-false}" != true ]]; then
EOF
)"
pe "$(cat <<'EOF'
  kubectl exec -n "$CLI_NAMESPACE" -it deploy/scone-toolbox -c scone-toolbox -- bash
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

