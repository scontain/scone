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

pe() {
  local cmd="$*"
  local display_cmd
  display_cmd=$(printf "%s" "$cmd" | sed 's/\$/\\$/g')
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
printf '%s\n' '# Deploying SCONE CLI Image on Kubernetes'
printf '%s\n' ''
printf '%s\n' 'This document describes on how to set up a pod in Kubernetes cluster that contains all the tools to transform cloud-native applications into confidential applications. To do so, we need a Docker deamon that we use to transform existing native container images of the application into confidential container images used by the confidential cloud-native application.'
printf '%s\n' ''
printf '%s\n' '## Prerequisites'
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' 'We first ensure that command `kubectl` is installed:'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'check_command() {'
pe '  command -v "$1" &>/dev/null'
pe '}'
pe ''
pe '# Auto-install kubectl if not present'
pe 'if ! check_command kubectl; then'
pe '  echo "Please run ./scripts/prerequisite_check.sh first"'
pe 'else'
pe '  echo "✔️ kubectl is already installed."'
pe 'fi'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Next, we check that we havve access to a Kubernetes cluster. This Kubernetes cluster is used to install a pod to run the transformation of applications.'
printf '%s\n' ''
printf "%b" "$RESET"

pe '# checking that we have access to a cluster'
pe 'kubectl get nodes || { echo "Failed to list Kubernetes nodes: Exiting" ; exit 1; }'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Enabling TCP on Docker Daemon'
printf '%s\n' ''
printf '%s\n' 'The image requires TCP on the Docker Daemon. If you are using a Kubernetes cluster with confidential nodes, we need to enable TCP on the Docker Daemon by running the [enable docker script](scripts/enable_docker_tcp.sh)'
printf '%s\n' ''
printf '%s\n' '> Note: Enabling TCP on the Docker is a serious security risk. Use this option only if you run a private Kubernetes cluster. We provide a [script](scripts/disable_docker_tcp.sh) to disable the TCP when you are done using the docker deamon.'
printf '%s\n' ''
printf '%s\n' '## Deployment'
printf '%s\n' ''
printf '%s\n' 'You need to login to the docker registry `registry.scontain.com` with an account that has access to the namespace `scone.cloud`. If you have not yet registered with `gitlab.scontain.com`, please check <https://sconedocs.github.io/registry/> on how to register an account. '
printf '%s\n' ''
printf '%s\n' 'Please determine your username and create an access token with read permission for registries - as described in <https://sconedocs.github.io/registry/>. '
printf '%s\n' ''
printf '%s\n' 'We can ask the user for the credentials of the repository:'
printf '%s\n' ''
printf '%s\n' 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--force"'
printf '%s\n' ''
printf '%s\n' 'If we want to use the values from file `Values.yaml`, we set this environment variables as follows:'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Next, we set all environment variables related to the registry credentials.'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} )'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'To be sure, we check that both variables are defined:'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'if [ -z "${REGISTRY_USER+x}" ]; then'
pe '  echo "Environment variable REGISTRY_USER is not set - please define and retry." '
pe '  exit 1'
pe 'fi'
pe 'if [ -z "${REGISTRY_TOKEN+x}" ]; then'
pe '  echo "Environment variable REGISTRY_TOKEN is not set  - please define and retry." '
pe '  exit 1'
pe 'fi'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Container Image'
printf '%s\n' ''
printf '%s\n' 'In our pod, we use a pre-built image `registry.scontain.com/workshop/scone`'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'export CLI_IMAGE="registry.scontain.com/workshop/scone"'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Creating Namespace and Secrets'
printf '%s\n' ''
printf '%s\n' 'By default we install the CLI image in namespace `scone-tools`. You can overwrite the namespace with the help of environment variable `CLI_NAMESPACE`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'export CLI_NAMESPACE="scone-tools"'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Let'\''s ask the user and set the environment variables depending on the input of the user:'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'eval $(tplenv --file environment-variables-k8s.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'

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

pe 'kubectl create ns $CLI_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -'
pe ''
pe 'SECRET_NAME="scone-registry"'
pe ''
pe 'if kubectl get secret "$SECRET_NAME" -n "$CLI_NAMESPACE" >/dev/null 2>&1; then'
pe '  echo "Secret '\''$SECRET_NAME'\'' exists in namespace '\''$CLI_NAMESPACE'\'' - do not replace."'
pe 'else'
pe '  echo "Secret '\''$SECRET_NAME'\'' not found in namespace '\''$CLI_NAMESPACE'\'' - Creating it."'
pe '  kubectl -n $CLI_NAMESPACE create secret docker-registry "$SECRET_NAME" \'
pe '    --docker-server=registry.scontain.com \'
pe '    --docker-username="$REGISTRY_USER" \'
pe '    --docker-password="$REGISTRY_TOKEN"'
pe 'fi'
pe ''
pe 'SECRET_NAME="sconeapps"'
pe ''
pe 'if kubectl get secret "$SECRET_NAME" -n "$CLI_NAMESPACE" >/dev/null 2>&1; then'
pe '  echo "Secret '\''$SECRET_NAME'\'' exists in namespace '\''$CLI_NAMESPACE'\'' - do not replace."'
pe 'else'
pe '  echo "Secret '\''$SECRET_NAME'\'' not found in namespace '\''$CLI_NAMESPACE'\'' - Creating it."'
pe '  kubectl -n $CLI_NAMESPACE create secret docker-registry "$SECRET_NAME" \'
pe '    --docker-server=registry.scontain.com \'
pe '    --docker-username="$REGISTRY_USER" \'
pe '    --docker-password="$REGISTRY_TOKEN"'
pe 'fi'
pe ''
pe 'SECRET_NAME="scone-registry-env"'
pe ''
pe 'if kubectl get secret "$SECRET_NAME" -n "$CLI_NAMESPACE" >/dev/null 2>&1; then'
pe '  echo "Secret '\''$SECRET_NAME'\'' exists in namespace '\''$CLI_NAMESPACE'\'' - do not replace."'
pe 'else'
pe ''
pe 'cat > ./scone-registry.env <<EOF'
pe 'export REGISTRY_TOKEN="$REGISTRY_TOKEN"'
pe 'export REGISTRY_USER="$REGISTRY_USER"'
pe 'EOF'
pe ''
pe 'kubectl -n $CLI_NAMESPACE create secret generic $SECRET_NAME \'
pe '--from-file=$SECRET_NAME=./scone-registry.env'
pe 'fi'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '   '
printf '%s\n' '## Add RBAC to the namespace'
printf '%s\n' ''
printf '%s\n' 'We provide a template to define the RBAC for the CLI image. We instantiate this template first and then apply the RBAC:'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'tplenv --file ./k8s/rbac.template.yaml --output ./k8s/rbac.yaml'
pe 'kubectl apply -f ./k8s/rbac.yaml'

printf "%b" "$LILAC"
printf '%s\n' '   '
printf '%s\n' '## Deploy DIND'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'tplenv --file ./k8s/dind.template.yaml --output ./k8s/dind.yaml'
pe 'kubectl apply -f ./k8s/dind.yaml'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Deploy the SCONE CLI'
printf '%s\n' ''
printf '%s\n' 'We change the image name in `deployment.yaml` file for the one you pushed in step 1'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'tplenv --file ./k8s/deployment.template.yaml --output ./k8s/deployment.yaml'
pe '# ensure we load the latest container image'
pe 'kubectl apply -f ./k8s/deployment.yaml'
pe 'kubectl -n "${CLI_NAMESPACE}" rollout restart deployment/scone-toolbox'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '##  Watch the logs of the pod'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'wait_for_pod_logs() {'
pe '  local ns="${1:-default}"'
pe '  local label="${2:?Usage: wait_for_pod_logs <namespace> <label>}"'
pe '  local timeout="${3:-200s}"'
pe ''
pe '  echo "⏳ Waiting for pod with label $label in namespace $ns..."'
pe '  kubectl wait pod -n "$ns" -l "$label" --for=condition=Ready --timeout="$timeout" || {'
pe '    echo "❌ Timeout waiting for pod to become Ready."'
pe '    return 1'
pe '  }'
pe ''
pe '  local pod'
pe '  pod=$(kubectl get pod -n "$ns" -l "$label" -o jsonpath='\''{.items[0].metadata.name}'\'')'
pe ''
pe '  echo "📜 Showing first 10 lines of logs from pod: $pod"'
pe '  kubectl logs -n "$ns" "$pod" | head -n 10'
pe '}'
pe ''
pe 'wait_for_pod_logs $CLI_NAMESPACE app=scone-toolbox'

printf "%b" "$LILAC"
printf '%s\n' '   '
printf '%s\n' '##  Run the SCONE CLI using help'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'kubectl exec -n $CLI_NAMESPACE -it deploy/scone-toolbox  -c scone-toolbox -- scone --help'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '##  Drop into the shell to execute your commands'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'kubectl exec -n $CLI_NAMESPACE -it deploy/scone-toolbox  -c scone-toolbox -- bash'

