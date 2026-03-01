# Deploying SCONE CLI Image on Kubernetes

This document describes on how to set up a pod in Kubernetes cluster that contains all the tools to transform cloud-native applications into confidential applications. To do so, we need a Docker deamon that we use to transform existing native container images of the application into confidential container images used by the confidential cloud-native application.

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

Next, we check that we havve access to a Kubernetes cluster. This Kubernetes cluster is used to install a pod to run the transformation of applications.

```bash
# checking that we have access to a cluster
kubectl get nodes || { echo "Failed to list Kubernetes nodes: Exiting" ; exit 1; }
```

## Enabling TCP on Docker Daemon

The image requires TCP on the Docker Daemon. If you are using a Kubernetes cluster with confidential nodes, we need to enable TCP on the Docker Daemon by running the [enable docker script](scripts/enable_docker_tcp.sh)

> Note: Enabling TCP on the Docker is a serious security risk. Use this option only if you run a private Kubernetes cluster. We provide a [script](scripts/disable_docker_tcp.sh) to disable the TCP when you are done using the docker deamon.

## Deployment

You need to login to the docker registry `registry.scontain.com` with an account that has access to the namespace `scone.cloud`. If you have not yet registered with `gitlab.scontain.com`, please check <https://sconedocs.github.io/registry/> on how to register an account. 

Please determine your username and create an access token with read permission for registries - as described in <https://sconedocs.github.io/registry/>. 

We can ask the user for the credentials of the repository:

```
export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--force"
```

If we want to use the values from file `Values.yaml`, we set this environment variables as follows:

```bash
export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""
```

Next, we set all environment variables related to the registry credentials.

```bash
eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} )
```

To be sure, we check that both variables are defined:

```bash
if [ -z "${REGISTRY_USER+x}" ]; then
  echo "Environment variable REGISTRY_USER is not set - please define and retry." 
  exit 1
fi
if [ -z "${REGISTRY_TOKEN+x}" ]; then
  echo "Environment variable REGISTRY_TOKEN is not set  - please define and retry." 
  exit 1
fi
```

## Container Image

In our pod, we use a pre-built image `registry.scontain.com/workshop/scone`

```bash
export CLI_IMAGE="registry.scontain.com/workshop/scone"
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

cat > ./scone-registry.env <<EOF
export REGISTRY_TOKEN="$REGISTRY_TOKEN"
export REGISTRY_USER="$REGISTRY_USER"
EOF

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
# ensure we load the latest container image
kubectl apply -f ./k8s/deployment.yaml
kubectl -n "${CLI_NAMESPACE}" rollout restart deployment/scone-toolbox
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

wait_for_pod_logs $CLI_NAMESPACE app=scone-toolbox
```
   
##  Run the SCONE CLI using help

```bash
kubectl exec -n $CLI_NAMESPACE -it deploy/scone-toolbox  -c scone-toolbox -- scone --help
```

##  Drop into the shell to execute your commands

```bash
kubectl exec -n $CLI_NAMESPACE -it deploy/scone-toolbox  -c scone-toolbox -- bash
```
