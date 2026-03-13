# TDX Workshop

This runbook provisions a TDX CVM cluster on Azure, installs the SCONE platform with SGX plugin 7.0.0-alpha.1, and runs the full demo suite. Each demo attests the public CAS (`scone-cas.cf`) individually.

## 1. Load Environment Variables

Load configuration from `workshop/Values.yaml`. We `pushd` into the workshop directory so that tplenv finds `Values.yaml` with the defaults:

```bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pushd workshop
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
popd
```

## 2. Verify Prerequisites

Check that all required tools are available:

```bash
for tool in kubectl-scone_azure az kubectl scone-td-build tplenv jq; do
  if ! command -v "$tool" &>/dev/null; then
    echo "ERROR: $tool is not installed or not on PATH"
    exit 1
  fi
  echo "OK: $tool"
done
```

## 3. Create TDX CVM Cluster

Provision a single-node TDX cluster on Azure. The `--no-attestation` flag skips KBS platform attestation to simplify the flow.

```bash
kubectl scone-azure create --tdx \
  --node-count ${NODE_COUNT} \
  --memory ${MEMORY} \
  --vcores ${VCORES} \
  --scone-config ${CVM_CONFIG} \
  --kube-config ${KUBECONFIG_PATH} \
  --credentials ${AZURE_CREDENTIALS} \
  --rg ${RESOURCE_GROUP} \
  --no-attestation
```

Set the kubeconfig and verify the cluster:

```bash
export KUBECONFIG=$(realpath ${KUBECONFIG_PATH})
kubectl get nodes
retry-spinner --timeout 300 --wait 10 -- kubectl wait --for=condition=Ready nodes --all --timeout=10s
```

## 4. Install SCONE Platform (SGX Plugin ${SGX_PLUGIN_VERSION})

Download the operator controller script:

```bash
mkdir -p /tmp/SCONE_OPERATOR_CONTROLLER
cd /tmp/SCONE_OPERATOR_CONTROLLER
curl -fsSL "https://raw.githubusercontent.com/scontain/SH/master/${SGX_PLUGIN_VERSION}/operator_controller" > operator_controller
curl -fsSL "https://raw.githubusercontent.com/scontain/SH/master/${SGX_PLUGIN_VERSION}/operator_controller.asc" > operator_controller.asc
chmod a+x operator_controller
echo "Downloaded operator_controller for version ${SGX_PLUGIN_VERSION}"
```

Run the operator controller to install the SGX plugin, SCONE operator, and LAS. We pin `CERT_MANAGER` to avoid pulling a version incompatible with the cluster's Kubernetes release:

```bash
export CERT_MANAGER="https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
bash operator_controller \
  --set-version ${SGX_PLUGIN_VERSION} \
  --reconcile --update --plugin --verbose \
  --dcap-api "${DCAP_KEY}" \
  --secret-operator \
  --username ${REGISTRY_USER} \
  --access-token ${REGISTRY_TOKEN} \
  --email ${REGISTRY_EMAIL}
```

Wait for the SGX plugin and LAS to become healthy:

```bash
retry-spinner --timeout 600 --wait 15 -- sh -c 'kubectl get sgx -o jsonpath="{.items[0].status.state}" | grep -q HEALTHY'
echo "SGX plugin is HEALTHY"
retry-spinner --timeout 600 --wait 15 -- sh -c 'kubectl get las -o jsonpath="{.items[0].status.state}" | grep -q HEALTHY'
echo "LAS is HEALTHY"
```

Return to the repo root directory (we changed to `/tmp` for the download):

```bash
cd "${REPO_ROOT}"
```

## 5. Run Demos

Export the CAS variables so they override per-demo defaults (most demos default to a local CAS):

```bash
export CAS_NAME=${CAS_NAME}
export CAS_NAMESPACE=${CAS_NAMESPACE}
```

Run all 6 demos:

```bash
./scripts/run-all-scripts.sh
```

## 6. Cleanup (Optional)

To delete the cluster, note the cluster name and resource group from the creation output above, then run:

```bash
echo "To delete the cluster, run:"
echo "kubectl scone-azure delete --cluster-name <CLUSTER_NAME> --rg <RESOURCE_GROUP> --credentials ${AZURE_CREDENTIALS}"
```
