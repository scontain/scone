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
printf '%s\n' 'In our pod, we use a pre-built image `registry.scontain.com/workshop/scone`'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
export CLI_IMAGE="registry.scontain.com/workshop/scone"
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
export CLI_NAMESPACE="scone-tools"
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
tplenv --file ./k8s/rbac.template.yaml --output ./k8s/rbac.yaml
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
tplenv --file ./k8s/dind.template.yaml --output ./k8s/dind.yaml
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
tplenv --file ./k8s/deployment.template.yaml --output ./k8s/deployment.yaml
EOF
)"
pe "$(cat <<'EOF'
# delete old deployment...
EOF
)"
pe "$(cat <<'EOF'
{ kubectl -n "${CLI_NAMESPACE}" delete deployment/scone-toolbox ; kubectl wait --for=delete -n "${CLI_NAMESPACE}" deployment/scone-toolbox  --timeout=120s; }  || echo "Ok - it seems no deployment was running"
EOF
)"
pe "$(cat <<'EOF'
# ensure we load the latest container image
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f ./k8s/deployment.yaml
EOF
)"
pe "$(cat <<'EOF'
kubectl -n "${CLI_NAMESPACE}" rollout restart deployment/scone-toolbox
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## SSH Access via Port-Forward'
printf '%s\n' ''
printf '%s\n' 'After deployment, wait until the toolbox pod is `Ready`, then forward local port `2222` to container port `22`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl -n "${CLI_NAMESPACE}" wait pod -l app=scone-toolbox \
  --for=condition=Ready --timeout=300s
EOF
)"
pe "$(cat <<'EOF'
kill $(cat /tmp/pf-2222.pid) || true
EOF
)"
pe "$(cat <<'EOF'
rm /tmp/pf-2222.pid || true
EOF
)"
pe "$(cat <<'EOF'
echo "kubectl -n "${CLI_NAMESPACE}" port-forward deploy/scone-toolbox 2222:22 &" 
EOF
)"
pe "$(cat <<'EOF'
kubectl -n "${CLI_NAMESPACE}" port-forward deploy/scone-toolbox 2222:22 &  echo $! > /tmp/pf-2222.pid
EOF
)"

printf "%b" "$LILAC"
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
kubectl exec -n $CLI_NAMESPACE -it deploy/scone-toolbox  -c scone-toolbox -- scone --help
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '##  Drop into the shell to execute your commands'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl exec -n $CLI_NAMESPACE -it deploy/scone-toolbox  -c scone-toolbox -- bash
EOF
)"

