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

SSH public keys belong in the ignored `Values.credentials.yaml`, alongside local
registry credentials. Shared `Values.yaml` must not contain a user's SSH key.
An explicit `SSH_PUB_KEY` takes precedence for this deployment; otherwise we use
its saved local value, falling back to the first public key in `~/.ssh`.
The following snippet resolves the SSH key and registry credentials together
and saves them using an atomic update:

```bash
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
```

## Container Image

In our pod, we use a versioned image such as `registry.scontain.com/workshop/scone:6.0.8`.

```bash
toolbox_image_override="${CLI_IMAGE:-}"
toolbox_namespace_override="${CLI_NAMESPACE:-}"
toolbox_version_override="${SCONE_VERSION:-}"
export CLI_IMAGE="${CLI_IMAGE:-registry.scontain.com/workshop/scone}"
```

## Creating Namespace and Secrets

By default we install the CLI image in namespace `scone-tools`. You can overwrite the namespace with the help of environment variable `CLI_NAMESPACE`:

```bash
export CLI_NAMESPACE="${CLI_NAMESPACE:-scone-tools}"
```

Let's ask the user and set the environment variables depending on the input of the user:

```bash
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
```

The credentials selected by `tplenv` are used for all three registry secrets:
`scone-registry` and `sconeapps` provide image pull credentials, while
`scone-registry-env` provides the toolbox's Docker login credentials and registry
address. Every run creates or updates these secrets before recreating the toolbox,
so a previous deployment cannot retain an old login. Updating a secret must succeed
before deployment continues.

Credentials go directly to Kubernetes through standard input; no plaintext
`scone-registry.env` file is written by toolbox setup. To use a different registry,
select it through `tplenv` together with its username and token, and set `CLI_IMAGE`
to the corresponding toolbox image.

```bash
kubectl create ns "$CLI_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
python3 ./scripts/reconcile-toolbox-registry.py --namespace "$CLI_NAMESPACE"
```

## Add RBAC to the namespace

The RBAC template gives the toolbox service account workload permissions in its
own namespace and adds a `scone-demo-runner-$CLI_NAMESPACE` Role and RoleBinding
in `default`. The latter permits demo secrets, ConfigMaps, services, pods, Jobs,
Deployments, SCONE policies, and NetworkPolicies. Demo `NAMESPACE` can therefore
remain `default`, independently of `CAS_NAMESPACE`.

Setup also provisions `java-demo`, `ci-scone-td-build`, and `nfs-demo`, with demo
Roles and RoleBindings scoped to each namespace. These roles include PVC access
for the shared-volume demo. Set `TOOLBOX_DEMO_NAMESPACES` to a space-separated
list to use other namespaces, or set it to an empty string to skip this step.
The setup account creates namespaces; the toolbox does not receive permission to
create namespaces or change RBAC.

Infrastructure access remains read-only: these additional permissions do not
allow modifying CAS instances, RBAC, cluster resources, or `kube-system` workloads.
Run this setup using a Kubernetes account allowed to create these roles and
bindings. We render the template and apply it before deploying the toolbox:

```bash
render_toolbox_manifest ./k8s/rbac.template.yaml ./k8s/rbac.yaml
kubectl apply -f ./k8s/rbac.yaml

# The suite also ships demos that use dedicated namespaces. Provision them with
# the setup account; the toolbox service account keeps namespace creation denied.
read -r -a toolbox_demo_namespaces <<< "${TOOLBOX_DEMO_NAMESPACES-java-demo ci-scone-td-build nfs-demo}"
for toolbox_demo_namespace in "${toolbox_demo_namespaces[@]}"; do
  kubectl create ns "$toolbox_demo_namespace" --dry-run=client -o yaml | kubectl apply -f -
  export TOOLBOX_DEMO_NAMESPACE="$toolbox_demo_namespace"
  render_toolbox_manifest ./k8s/demo-rbac.template.yaml ./k8s/demo-rbac.yaml
  kubectl apply -f ./k8s/demo-rbac.yaml
done
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
alias connects to `root` on loopback port `2222` by default and uses
`HostKeyAlias scone-toolbox-k8s` to keep its host key separate from other local
tunnels. Set `TOOLBOX_SSH_PORT=2200` to use another port. It asks before adding a missing
alias or correcting an existing alias. Declining leaves your SSH configuration
unchanged, and you can still use the direct SSH command printed below.

Approved updates preserve other SSH configuration and use an atomic replacement.
Set `TOOLBOX_SSH_CONFIG` to use a configuration file other than `~/.ssh/config`.
The helper stores the forwarding PID and process identity under
`~/.cache/scone-toolbox` (`--state-dir` can change this location). On the next
interactive setup, it checks and stops its previously recorded forward before
offering to start a new one. It leaves unrelated processes alone, including
processes that reuse an old PID. It verifies the SSH banner before reporting
readiness and prints the process ID and log path. The forward survives this
script exiting; rerun setup after replacing the toolbox pod.
`K8S_CLI_DEPLOY_ONLY=true` skips SSH configuration and forwarding prompts for automation.

```bash
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
```

If you declined automatic forwarding, keep the printed port-forward command
running in one terminal. Once forwarding is ready, run `ssh scone-toolbox-k8s`
if the alias is configured, or
`ssh -o HostKeyAlias=scone-toolbox-k8s -p 2222 root@127.0.0.1` to connect directly
(use the configured port if different). Authentication uses the private key
corresponding to `SSH_PUB_KEY` configured for the toolbox.

Host keys are generated when the image is built. After a trusted image upgrade,
remove the old toolbox key with `ssh-keygen -R scone-toolbox-k8s`, then reconnect.
The helper never removes known host keys automatically. To refresh forwarding
without redeploying, run
`python3 ./scripts/configure-toolbox-ssh.py --ensure-forward --namespace scone-tools`
(with `--local-port 2200` if configured).

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

wait_for_pod_logs "$CLI_NAMESPACE" app=scone-toolbox || true
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
