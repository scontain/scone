# Deploying SCONE CLI Image on Kubernetes

This document describes how to set up a pod in a Kubernetes cluster that contains all the tools to transform cloud-native applications into confidential applications. To do so, we need a Docker daemon that we use to transform existing native container images of the application into confidential container images used by the confidential cloud-native application.

![Screencast](docs/k8s_cli.gif)

## Prerequisites


We first ensure that command `kubectl` is installed:

```bash
check_command() {
  command -v "$1" &>/dev/null
}

# Auto-install kubectl if not present
if ! check_command kubectl; then
  echo "Please run ./scripts/prerequisite_check.sh first"
else
  echo "✔️ kubectl is already installed."
fi
```

Next, we check that we have access to a Kubernetes cluster. This Kubernetes cluster is used to install a pod to run the transformation of applications.

```bash
# checking that we have access to a cluster
kubectl get nodes || { echo "Failed to list Kubernetes nodes: Exiting" ; exit 1; }
```

## Enabling TCP on Docker Daemon

The image requires TCP on the Docker Daemon. If you are using a Kubernetes cluster with confidential nodes, we need to enable TCP on the Docker Daemon by running the [enable docker script](scripts/enable_docker_tcp.sh)

> Note: Enabling TCP on Docker is a serious security risk. Use this option only if you run a private Kubernetes cluster. We provide a [script](scripts/disable_docker_tcp.sh) to disable TCP when you are done using the Docker daemon.

## Deployment

You need to log in to the Docker registry `registry.scontain.com` with an account that has access to the namespace `scone.cloud`. If you have not yet registered with `gitlab.scontain.com`, please check <https://sconedocs.github.io/registry/> on how to register an account.

Please determine your username and create an access token with read permission for registries - as described in <https://sconedocs.github.io/registry/>. 

## SSH Key for Toolbox Access

The toolbox container starts `sshd` automatically with password authentication disabled. To allow SSH login, we pass your public key in environment variable `SSH_PUB_KEY`.

The following snippet tries to initialize `SSH_PUB_KEY` from your local `~/.ssh` directory and writes it into `Values.credentials.yaml`:

```bash
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

```

Next, we set all environment variables related to the registry credentials.

```bash
# Map SCONE_REGISTRY_* env vars to the names expected by tplenv
export REGISTRY_USER="${REGISTRY_USER:-${SCONE_REGISTRY_USERNAME:-}}"
export REGISTRY_TOKEN="${REGISTRY_TOKEN:-${SCONE_REGISTRY_ACCESS_TOKEN:-}}"

eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --context --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} )
```

## Container Image

In our pod, we use a pre-built image `registry.scontain.com/workshop/scone`

```bash
export CLI_IMAGE="${CLI_IMAGE:-registry.scontain.com/workshop/scone}"
```

## Creating Namespace and Secrets

By default we install the CLI image in namespace `scone-tools`. You can overwrite the namespace with the help of environment variable `CLI_NAMESPACE`:

```bash
export CLI_NAMESPACE="scone-tools"
```

Let's ask the user and set the environment variables depending on the input of the user:

```bash
eval $(tplenv --file environment-variables-k8s.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )
```

Next we create a Kubernetes namespace and pull secrets. We assume here that we can use the same PAT for different pull secrets. Actually, we create two pull secrets:

- `scone-registry`: we use this in the context of some examples. This permits use to store these examples on a different repo.

 - `sconeapps`: we use this secret to pull the container images from `registry.scontain.com`.

Please adjust in case you use a unique PAT for each pull secret.

Also, in case you built and pushed the image to a different registry, you need to adjust the value for `docker-server` in the  `docker-registry` secret accordingly.

```bash
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
```

   
## Add RBAC to the namespace

We provide a template to define the RBAC for the CLI image. We instantiate this template first and then apply the RBAC:

```bash
tplenv --file ./k8s/rbac.template.yaml --output ./k8s/rbac.yaml
kubectl apply -f ./k8s/rbac.yaml
```
   
## Deploy DIND

```bash
tplenv --file ./k8s/dind.template.yaml --output ./k8s/dind.yaml
kubectl apply -f ./k8s/dind.yaml
```

## Deploy the SCONE CLI

We change the image name in `deployment.yaml` file for the one you pushed in step 1

```bash
tplenv --file ./k8s/deployment.template.yaml --output ./k8s/deployment.yaml
# delete old deployment...
{ kubectl -n "${CLI_NAMESPACE}" delete deployment/scone-toolbox ; kubectl wait --for=delete pod -n "${CLI_NAMESPACE}" -l app=scone-toolbox  --timeout=120s; }  || echo "Ok - it seems no deployment was running"
# ensure we load the latest container image
kubectl apply -f ./k8s/deployment.yaml
```

## SSH Access via Port-Forward

After deployment, wait until the toolbox pod is `Ready`, then forward local port `2222` to container port `22`:

```
kubectl -n "${CLI_NAMESPACE}" wait pod -l app=scone-toolbox \
  --for=condition=Ready --timeout=300s
kill $(cat /tmp/pf-2222.pid) || true
rm /tmp/pf-2222.pid || true
kubectl -n "${CLI_NAMESPACE}" port-forward deploy/scone-toolbox 2222:22 &  echo $! > /tmp/pf-2222.pid
```

In another terminal, connect via SSH (password login is disabled, key-based login only):

```
ssh -p 2222 root@127.0.0.1
```

If you want a convenient host alias, add an idempotent block to `~/.ssh/config`:

```
SSH_CONFIG="${HOME}/.ssh/config"
HOST_ALIAS="scone-toolbox-k8s"
BEGIN_MARKER="# >>> ${HOST_ALIAS} >>>"
END_MARKER="# <<< ${HOST_ALIAS} <<<"

mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"
touch "${SSH_CONFIG}"
chmod 600 "${SSH_CONFIG}"

tmp_config="$(mktemp)"
awk -v begin="${BEGIN_MARKER}" -v end="${END_MARKER}" '
  $0 == begin {skip=1; next}
  $0 == end   {skip=0; next}
  !skip       {print}
' "${SSH_CONFIG}" > "${tmp_config}"

printf '%s\n' \
  "${BEGIN_MARKER}" \
  "Host ${HOST_ALIAS}" \
  "  HostName 127.0.0.1" \
  "  Port 2222" \
  "  User root" \
  "  ServerAliveInterval 30" \
  "  StrictHostKeyChecking accept-new" \
  "${END_MARKER}" \
  >> "${tmp_config}"

mv "${tmp_config}" "${SSH_CONFIG}"
```

Then connect using the alias:

```
ssh scone-toolbox-k8s
```

##  Watch the logs of the pod

```bash
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
```
  
##  Run the SCONE CLI using help

```bash
kubectl exec -n $CLI_NAMESPACE -it deploy/scone-toolbox  -c scone-toolbox -- scone --help
```

##  Drop into the shell to execute your commands

```bash
kubectl exec -n $CLI_NAMESPACE -it deploy/scone-toolbox  -c scone-toolbox -- bash
```
