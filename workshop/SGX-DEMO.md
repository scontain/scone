# SGX Demo

This guide covers creating a 3-node SGX cluster on Azure, deploying the SCONE platform, and running the demo applications. All steps assume you are running inside the SCONE workshop container.

## Prerequisites

- The SCONE workshop container running (via `./scripts/k8s_cli.sh` or locally)
- An Azure subscription with quota for DC-series VMs (DCsv2, DCsv3, or DCdsv3)

## Azure Credentials

Create a service principal with Contributor role:

```bash
az ad sp create-for-rbac --name "scone-azure-sp" --role Contributor \
  --scopes /subscriptions/<subscription-id> --sdk-auth > az-credentials.json
```

This produces a JSON file with the following structure:

```json
{
  "tenantId": "your-tenant-id",
  "clientId": "your-client-id",
  "clientSecret": "your-client-secret",
  "subscriptionId": "your-subscription-id"
}
```

## 1. Set Azure Subscription Variables

Use `tplenv` to configure the Azure subscription variables:

```bash
eval $(tplenv --file workshop/azure-subscription.md --create-values-file --eval --output /dev/null)
```

This will prompt you for:
- `AZURE_CREDENTIALS_PATH` — path to the credentials JSON file created above
- `AZURE_RESOURCE_GROUP` — resource group name (leave empty to auto-generate)

## 2. Create the SGX Cluster

Create a 3-node SGX cluster:

```bash
kubectl-scone_azure create --sgx \
  --node-count 3 \
  --kube-config ./kubeconfig-sgx.yaml \
  --credentials "$AZURE_CREDENTIALS_PATH" \
  --rg "$AZURE_RESOURCE_GROUP" \
  -v
```

This provisions an AKS cluster with DC-series VMs (SGX-capable nodes) and the confidential computing addon. The tool automatically selects the cheapest available VM size and region that has quota.

Once complete, verify the cluster:

```bash
export KUBECONFIG=./kubeconfig-sgx.yaml
kubectl get nodes
```

All 3 nodes should show `Ready` status.

## 3. Deploy the SCONE Platform

Install the SCONE operator, LAS, SGX plugin, and all required tools:

```bash
./scripts/prerequisite_check.sh
```

Deploy the SCONE operator to the cluster:

```bash
./scripts/reconcile_scone_operator.sh
```

### Install CAS

Set the CAS name and namespace, then deploy the Certificate Authority Service:

```bash
export CAS="cas"
export CAS_NAMESPACE="default"
./scripts/install_cas.sh
```

## 4. Run the Demos

Clone the demos repository:

```bash
git clone https://github.com/scontain/scone-td-build-demos.git
cd scone-td-build-demos
```

### Run All Demos

Each demo uses `tplenv` to prompt for the required environment variables (image registry, credentials, etc.). Run all demos sequentially:

```bash
./scripts/run-all-scripts.sh
```

This runs the hello-world, configmap, and web-server demos. Each demo builds a native application, sconifies it with `scone-td-build`, and deploys it to the cluster.

## Cleanup

Delete the cluster when done:

```bash
kubectl-scone_azure delete \
  --cluster-name <cluster-name> \
  --rg "$AZURE_RESOURCE_GROUP" \
  --credentials "$AZURE_CREDENTIALS_PATH" \
  -v
```

Replace `<cluster-name>` with the name shown during creation (e.g., `scone-9cc7dd39`).