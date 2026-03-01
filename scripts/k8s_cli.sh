#!/usr/bin/env bash

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

printf "${VIOLET}"
printf '%s\n' '# Deploying SCONE CLI Image on Kubernetes'
printf '%s\n' ''
printf '%s\n' 'This document describes on how to set up a pod in Kubernetes cluster that contains all the tools to transform cloud-native applications into confidential applications. To do so, we need a Docker deamon that we use to transform existing native container images of the application into confidential container images used by the confidential cloud-native application.'
printf '%s\n' ''
printf '%s\n' '## Prerequisites'
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' 'We first ensure that command `kubectl` is installed:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'check_command() {'
printf '%s\n' '  command -v "\\$1" &>/dev/null'
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
printf '%s\n' 'Next, we check that we havve access to a Kubernetes cluster. This Kubernetes cluster is used to install a pod to run the transformation of applications.'
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
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""'
printf "${RESET}"

export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Next, we set all environment variables related to the registry credentials.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'eval \\$(tplenv --values Values.credentials.yaml --file registry.credentials.md --create-values-file --eval \\${CONFIRM_ALL_ENVIRONMENT_VARIABLES} )'
printf "${RESET}"

eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} )

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'To be sure, we check that both variables are defined:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'if [ -z "\\${REGISTRY_USER+x}" ]; then'
printf '%s\n' '  echo "Environment variable REGISTRY_USER is not set - please define and retry." '
printf '%s\n' '  exit 1'
printf '%s\n' 'fi'
printf '%s\n' 'if [ -z "\\${REGISTRY_TOKEN+x}" ]; then'
printf '%s\n' '  echo "Environment variable REGISTRY_TOKEN is not set  - please define and retry." '
printf '%s\n' '  exit 1'
printf '%s\n' 'fi'
printf "${RESET}"

if [ -z "${REGISTRY_USER+x}" ]; then
  echo "Environment variable REGISTRY_USER is not set - please define and retry." 
  exit 1
fi
if [ -z "${REGISTRY_TOKEN+x}" ]; then
  echo "Environment variable REGISTRY_TOKEN is not set  - please define and retry." 
  exit 1
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Container Image'
printf '%s\n' ''
printf '%s\n' 'In our pod, we use a pre-built image `registry.scontain.com/workshop/scone`'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'export CLI_IMAGE="registry.scontain.com/workshop/scone"'
printf "${RESET}"

export CLI_IMAGE="registry.scontain.com/workshop/scone"

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
printf '%s\n' 'eval \\$(tplenv --file environment-variables-k8s.md --create-values-file --context --eval \\${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'
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
printf '%s\n' 'kubectl create ns \\$CLI_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -'
printf '%s\n' ''
printf '%s\n' 'SECRET_NAME="scone-registry"'
printf '%s\n' ''
printf '%s\n' 'if kubectl get secret "\\$SECRET_NAME" -n "\\$CLI_NAMESPACE" >/dev/null 2>&1; then'
printf '%s\n' '  echo "Secret '\''\\$SECRET_NAME'\'' exists in namespace '\''\\$CLI_NAMESPACE'\'' - do not replace."'
printf '%s\n' 'else'
printf '%s\n' '  echo "Secret '\''\\$SECRET_NAME'\'' not found in namespace '\''\\$CLI_NAMESPACE'\'' - Creating it."'
printf '%s\n' '  kubectl -n \\$CLI_NAMESPACE create secret docker-registry "\\$SECRET_NAME" \'
printf '%s\n' '    --docker-server=registry.scontain.com \'
printf '%s\n' '    --docker-username="\\$REGISTRY_USER" \'
printf '%s\n' '    --docker-password="\\$REGISTRY_TOKEN"'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' 'SECRET_NAME="sconeapps"'
printf '%s\n' ''
printf '%s\n' 'if kubectl get secret "\\$SECRET_NAME" -n "\\$CLI_NAMESPACE" >/dev/null 2>&1; then'
printf '%s\n' '  echo "Secret '\''\\$SECRET_NAME'\'' exists in namespace '\''\\$CLI_NAMESPACE'\'' - do not replace."'
printf '%s\n' 'else'
printf '%s\n' '  echo "Secret '\''\\$SECRET_NAME'\'' not found in namespace '\''\\$CLI_NAMESPACE'\'' - Creating it."'
printf '%s\n' '  kubectl -n \\$CLI_NAMESPACE create secret docker-registry "\\$SECRET_NAME" \'
printf '%s\n' '    --docker-server=registry.scontain.com \'
printf '%s\n' '    --docker-username="\\$REGISTRY_USER" \'
printf '%s\n' '    --docker-password="\\$REGISTRY_TOKEN"'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' 'SECRET_NAME="scone-registry-env"'
printf '%s\n' ''
printf '%s\n' 'if kubectl get secret "\\$SECRET_NAME" -n "\\$CLI_NAMESPACE" >/dev/null 2>&1; then'
printf '%s\n' '  echo "Secret '\''\\$SECRET_NAME'\'' exists in namespace '\''\\$CLI_NAMESPACE'\'' - do not replace."'
printf '%s\n' 'else'
printf '%s\n' ''
printf '%s\n' 'cat > ./scone-registry.env <<EOF'
printf '%s\n' 'export REGISTRY_TOKEN="\\$REGISTRY_TOKEN"'
printf '%s\n' 'export REGISTRY_USER="\\$REGISTRY_USER"'
printf '%s\n' 'EOF'
printf '%s\n' ''
printf '%s\n' 'kubectl -n \\$CLI_NAMESPACE create secret generic \\$SECRET_NAME \'
printf '%s\n' '--from-file=\\$SECRET_NAME=./scone-registry.env'
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

cat > ./scone-registry.env <<EOF
export REGISTRY_TOKEN="$REGISTRY_TOKEN"
export REGISTRY_USER="$REGISTRY_USER"
EOF

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
printf '%s\n' '# ensure we load the latest container image'
printf '%s\n' 'kubectl apply -f ./k8s/deployment.yaml'
printf '%s\n' 'kubectl -n "\\${CLI_NAMESPACE}" rollout restart deployment/scone-toolbox'
printf "${RESET}"

tplenv --file ./k8s/deployment.template.yaml --output ./k8s/deployment.yaml
# ensure we load the latest container image
kubectl apply -f ./k8s/deployment.yaml
kubectl -n "${CLI_NAMESPACE}" rollout restart deployment/scone-toolbox

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '##  Watch the logs of the pod'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'wait_for_pod_logs() {'
printf '%s\n' '  local ns="\\${1:-default}"'
printf '%s\n' '  local label="\\${2:?Usage: wait_for_pod_logs <namespace> <label>}"'
printf '%s\n' '  local timeout="\\${3:-200s}"'
printf '%s\n' ''
printf '%s\n' '  echo "⏳ Waiting for pod with label \\$label in namespace \\$ns..."'
printf '%s\n' '  kubectl wait pod -n "\\$ns" -l "\\$label" --for=condition=Ready --timeout="\\$timeout" || {'
printf '%s\n' '    echo "❌ Timeout waiting for pod to become Ready."'
printf '%s\n' '    return 1'
printf '%s\n' '  }'
printf '%s\n' ''
printf '%s\n' '  local pod'
printf '%s\n' '  pod=\\$(kubectl get pod -n "\\$ns" -l "\\$label" -o jsonpath='\''{.items[0].metadata.name}'\'')'
printf '%s\n' ''
printf '%s\n' '  echo "📜 Showing first 10 lines of logs from pod: \\$pod"'
printf '%s\n' '  kubectl logs -n "\\$ns" "\\$pod" | head -n 10'
printf '%s\n' '}'
printf '%s\n' ''
printf '%s\n' 'wait_for_pod_logs \\$CLI_NAMESPACE app=scone-toolbox'
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

wait_for_pod_logs $CLI_NAMESPACE app=scone-toolbox

printf "${VIOLET}"
printf '%s\n' '   '
printf '%s\n' '##  Run the SCONE CLI using help'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl exec -n \\$CLI_NAMESPACE -it deploy/scone-toolbox  -c scone-toolbox -- scone --help'
printf "${RESET}"

kubectl exec -n $CLI_NAMESPACE -it deploy/scone-toolbox  -c scone-toolbox -- scone --help

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '##  Drop into the shell to execute your commands'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl exec -n \\$CLI_NAMESPACE -it deploy/scone-toolbox  -c scone-toolbox -- bash'
printf "${RESET}"

kubectl exec -n $CLI_NAMESPACE -it deploy/scone-toolbox  -c scone-toolbox -- bash

