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

## Docker TCP connections

The Kubernetes toolbox connects to a separate Docker-in-Docker (`dind`) Deployment through `tcp://dind.${CLI_NAMESPACE}.svc.cluster.local:2375`. The [DIND manifest](k8s/dind.template.yaml) already enables that TCP listener, and this script deploys it below. You do not need to enable Docker TCP on your laptop or Kubernetes nodes for the toolbox to use this service.

The [enable docker script](scripts/enable_docker_tcp.sh) changes the local Linux systemd Docker service on the machine where you execute it. It writes `/etc/systemd/system/docker.service.d/override.conf` and restarts Docker to listen on `0.0.0.0:2375`. Running it on a laptop affects that laptop; running it over SSH on a node affects that node. It does not change remote Kubernetes resources or the node's containerd configuration.

> Note: This Docker TCP listener has no TLS or authentication. Restrict access to trusted clients. The [disable docker script](scripts/disable_docker_tcp.sh) removes the local systemd override. `build.sh` separately requires its configured Docker endpoint at `tcp://172.17.0.1:2375` to be reachable from where the build runs.

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
eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --context --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} )
```

## Container Image

In our pod, we use a versioned image such as `registry.scontain.com/workshop/scone:6.0.8`.

```bash
toolbox_image_override="${CLI_IMAGE:-}"
toolbox_namespace_override="${CLI_NAMESPACE:-}"
toolbox_version_override="${SCONE_VERSION:-}"
export CLI_IMAGE="${CLI_IMAGE:-registry.scontain.com/workshop/scone:${SCONE_VERSION:-$(cat stable.txt)}}"
```

## Creating Namespace and Secrets

By default we install the CLI image in namespace `scone-tools`. You can overwrite the namespace with the help of environment variable `CLI_NAMESPACE`:

```bash
export CLI_NAMESPACE="${CLI_NAMESPACE:-scone-tools}"
```

Let's ask the user and set the environment variables depending on the input of the user:

```bash
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
render_toolbox_manifest ./k8s/rbac.template.yaml ./k8s/rbac.yaml
kubectl apply -f ./k8s/rbac.yaml
```
   
## Deploy DIND

```bash
render_toolbox_manifest ./k8s/dind.template.yaml ./k8s/dind.yaml
kubectl apply -f ./k8s/dind.yaml
```

## Deploy the SCONE CLI

We change the image name in `deployment.yaml` file for the one you pushed in step 1

```bash
render_toolbox_manifest ./k8s/deployment.template.yaml ./k8s/deployment.yaml
echo "Deploying toolbox image: $CLI_IMAGE"
# delete old deployment...
{ kubectl -n "${CLI_NAMESPACE}" delete deployment/scone-toolbox ; kubectl wait --for=delete pod -n "${CLI_NAMESPACE}" -l app=scone-toolbox  --timeout=120s; }  || echo "Ok - it seems no deployment was running"
# ensure we load the selected container image
kubectl apply -f ./k8s/deployment.yaml
kubectl -n "$CLI_NAMESPACE" rollout status deployment/scone-toolbox --timeout=300s
kubectl -n "$CLI_NAMESPACE" exec deploy/scone-toolbox -c scone-toolbox -- scone-td-build --version
```

## SSH Access via Port-Forward

The script checks the effective configuration of the local `scone-toolbox-k8s`
alias, including wildcard rules and included SSH configuration files. A working
alias connects to `root` on loopback port `2222`. It asks before adding a missing
alias or correcting an existing alias. Declining leaves your SSH configuration
unchanged, and you can still use the direct SSH command printed below.

Approved updates preserve other SSH configuration and use an atomic replacement.
Set `TOOLBOX_SSH_CONFIG` to use a configuration file other than `~/.ssh/config`.
If local port `2222` has no listener, the script asks whether to start
`kubectl port-forward` in the background. It verifies the SSH banner before
reporting the connection as ready, and prints the process ID and log path.
The forwarding process survives this script exiting; replacing the toolbox pod
ends that forwarding session, so rerun setup or the printed port-forward command.
`K8S_CLI_DEPLOY_ONLY=true` skips SSH configuration and forwarding prompts for automation.

```bash
toolbox_ssh_args=(--ensure-forward --namespace "$CLI_NAMESPACE" --config "${TOOLBOX_SSH_CONFIG:-$HOME/.ssh/config}")
if [[ "${K8S_CLI_DEPLOY_ONLY:-false}" == true ]]; then
  toolbox_ssh_args+=(--non-interactive)
fi
if ! python3 ./scripts/configure-toolbox-ssh.py "${toolbox_ssh_args[@]}"; then
  echo "SSH setup could not complete. To connect directly:"
  printf '  kubectl -n %q port-forward deploy/scone-toolbox 2222:22\n' "$CLI_NAMESPACE"
  echo "  ssh -p 2222 root@127.0.0.1"
fi
```

If you declined automatic forwarding, keep the printed port-forward command
running in one terminal. Once forwarding is ready, run `ssh scone-toolbox-k8s`
if the alias is configured, or
`ssh -p 2222 root@127.0.0.1` to connect directly. Authentication uses the private
key corresponding to `SSH_PUB_KEY` configured for the toolbox.

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
kubectl exec -n "$CLI_NAMESPACE" deploy/scone-toolbox -c scone-toolbox -- scone --help
```

##  Drop into the shell to execute your commands

```bash
if [[ "${K8S_CLI_DEPLOY_ONLY:-false}" != true ]]; then
  kubectl exec -n "$CLI_NAMESPACE" -it deploy/scone-toolbox -c scone-toolbox -- bash
fi
```
