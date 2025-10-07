# Deploying SCONE CLI Image on Kubernetes

## Prerequisites

Ensure that you have the following installed:

- `kubectl`
- access to a Kubernetes cluster with confidential nodes

```bash

check_command() {
  command -v "$1" &>/dev/null
}

# Auto-install kubectl if not present
if ! check_command kubectl; then
  KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
  echo "📥 Installing kubectl $KUBECTL_VERSION ..."
  curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl
  curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256
  echo "$(cat kubectl.sha256) kubectl" | sha256sum --check
  sudo chmod +x kubectl
  sudo mv ./kubectl /usr/local/bin/
  rm kubectl.sha256
  echo "✔️ kubectl $KUBECTL_VERSION installed successfully."
else
  echo "✔️ kubectl is already installed."
fi

kubectl get nodes || { echo "Failed to list Kubernetes nodes: Exiting" ; exit 1; }
```

## Deployment

You need to login to the docker registry `registry.scontain.com` with an account that has access to the namespace `scone.cloud`. If you are already logged in to `registry.scontain.com`, you are all set. If you have not logged in yet, please set the following variables:

```
export SCONE_REGISTRY_USERNAME="..." # set to your user name 
export SCONE_REGISTRY_ACCESS_TOKEN="..." # set to personal access token with read access to scone.cloud
```

We check that both variables are defined:

```bash
if [ -z "${SCONE_REGISTRY_USERNAME+x}" ]; then
  echo "Environment variable SCONE_REGISTRY_USERNAME is not set - please define and retry." 
  exit 1
fi
if [ -z "${SCONE_REGISTRY_ACCESS_TOKEN+x}" ]; then
  echo "Environment variable SCONE_REGISTRY_ACCESS_TOKEN is not set  - please define and retry." 
  exit 1
fi
```

1. You can build and push your own image

```
export CLI_IMAGE="<registry>/<username>/repository>:<tag>"

docker build -t $CLI_IMAGE .
docker push $CLI_IMAGE$
```

We use instead the pre-built image `registry.scontain.com/workshop/scone`

```bash
export CLI_IMAGE="registry.scontain.com/workshop/scone"
```

2. Create Namespace and Secrets

By default we install the CLI image in namespace `scone-tools`. You can overwrite the namespace with the help of environment variable `CLI_NAMESPACE`:

```
export CLI_NAMESPACE="..."
```

Next we create a Kubernetes namespace and pull secrets. We assume here that we can use the same PAT for different pull secrets. Please adjust in case you use a unique PAT for each pull secret.

Also, in case you built and pushed the image to a different registry, you need to adjust the value for `docker-server` in the  `docker-registry` secret accordingly.

```bash
export CLI_NAMESPACE=${CLI_NAMESPACE:-scone-tools}
kubectl create ns $CLI_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

SECRET_NAME="scone-registry"

if kubectl get secret "$SECRET_NAME" -n "$CLI_NAMESPACE" >/dev/null 2>&1; then
  echo "Secret '$SECRET_NAME' exists in namespace '$CLI_NAMESPACE' - do not replace."
else
  echo "Secret '$SECRET_NAME' not found in namespace '$CLI_NAMESPACE' - Creating it."
  kubectl -n $CLI_NAMESPACE create secret docker-registry "$SECRET_NAME" \
    --docker-server=registry.scontain.com \
    --docker-username="$SCONE_REGISTRY_USERNAME" \
    --docker-password="$SCONE_REGISTRY_ACCESS_TOKEN"
fi

SECRET_NAME="sconeapps"

if kubectl get secret "$SECRET_NAME" -n "$CLI_NAMESPACE" >/dev/null 2>&1; then
  echo "Secret '$SECRET_NAME' exists in namespace '$CLI_NAMESPACE' - do not replace."
else
  echo "Secret '$SECRET_NAME' not found in namespace '$CLI_NAMESPACE' - Creating it."
  kubectl -n $CLI_NAMESPACE create secret docker-registry "$SECRET_NAME" \
    --docker-server=registry.scontain.com \
    --docker-username="$SCONE_REGISTRY_USERNAME" \
    --docker-password="$SCONE_REGISTRY_ACCESS_TOKEN"
fi

SECRET_NAME="scone-registry-env"

if kubectl get secret "$SECRET_NAME" -n "$CLI_NAMESPACE" >/dev/null 2>&1; then
  echo "Secret '$SECRET_NAME' exists in namespace '$CLI_NAMESPACE' - do not replace."
else

cat > ./scone-registry.env <<EOF
export SCONE_REGISTRY_ACCESS_TOKEN="$SCONE_REGISTRY_ACCESS_TOKEN"
export SCONE_REGISTRY_USERNAME="$SCONE_REGISTRY_USERNAME"
EOF

kubectl -n $CLI_NAMESPACE create secret generic $SECRET_NAME \
--from-file=$SECRET_NAME=./scone-registry.env
fi
```

   
3. Add RBAC to the namespace

We provide a template to define the RBAC for the CLI image. We instantiate this template first and then apply the RBAC:

```bash
envsubst < ./k8s/rbac.template.yaml > ./k8s/rbac.yaml
kubectl apply -f ./k8s/rbac.yaml
```
   
4. Deploy DIND

```bash
envsubst < ./k8s/dind.template.yaml > ./k8s/dind.yaml
kubectl apply -f ./k8s/dind.yaml
```

5. Deploy the SCONE CLI

We change the image name in `pod.yaml` file for the one you pushed in step 1

```bash
envsubst < ./k8s/pod.template.yaml > ./k8s/pod.yaml
kubectl apply -f ./k8s/pod.yaml
```

5. Watch the logs of the pod

```bash
wait_for_pod_logs() {
  local ns="${1:-default}"
  local label="${2:?Usage: wait_for_pod_logs <namespace> <label>}"
  local timeout="${3:-120s}"

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
   
6. Run the SCONE CLI using help

```bash
kubectl -n $CLI_NAMESPACE exec -it scone-toolbox -- scone --help
```

7. Drop into the shell to execute your commands

```bash
kubectl -n $CLI_NAMESPACE exec -it scone-toolbox -- bash
```
