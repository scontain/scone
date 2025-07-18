# Prometheus and Grafana Stack

Prometheus and Grafana are two widely used open-source tools for monitoring and visualizing system metrics and application performance.

- Prometheus collects and stores metrics.

- Grafana queries Prometheus and displays those metrics.


## Installing Prometheus

Install from https://github.com/prometheus-operator/kube-prometheus.

```bash
# Create the namespace and CRDs, and then wait for them to be available before creating the remaining resources
# Note that due to some CRD size we are using kubectl server-side apply feature which is generally available since kubernetes 1.22.
# If you are using previous kubernetes versions this feature may not be available and you would need to use kubectl create instead.
pushd /tmp
# ensure we do not get wrong content
rm -rf kube-prometheus || true
git clone https://github.com/prometheus-operator/kube-prometheus.git -b v0.15.0 --depth 1
pushd kube-prometheus
kubectl apply --server-side -f manifests/setup || true
kubectl wait \
    --for condition=Established \
    --all CustomResourceDefinition \
    --namespace=monitoring || true
kubectl apply -f manifests/ || true
popd; popd
```

Create service monitor.

```bash
kubectl apply -f prometheus-grafana-manifests/service-monitor.yaml
```

Wait for grafana pod to be ready, and then patch its service to expose a LoadBalancer.

```bash
kubectl wait pod -l "app.kubernetes.io/component=grafana,app.kubernetes.io/name=grafana,app.kubernetes.io/part-of=kube-prometheus" \
  -n monitoring --for=condition=Ready --timeout 5m
kubectl patch svc grafana -n monitoring --type=json -p '
[
    {
        "op": "replace",
        "path": "/spec/type",
        "value": "LoadBalancer"
    }
]'

MAX_WAIT=30     # Total seconds to wait
INTERVAL=5      # Seconds between checks
TRIES=$((MAX_WAIT / INTERVAL))
COUNT=0
IP=""

while [[ -z "$IP" ]]; do
  if [[ $COUNT -ge $TRIES ]]; then
    echo "⚠️  LoadBalancer IP was not assigned after $MAX_WAIT seconds. Continuing without it."
    break
  fi
  echo "⏳ Waiting for LoadBalancer IP..."
  sleep $INTERVAL
  IP=$(kubectl get svc grafana -n monitoring -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null)
  ((COUNT=COUNT+1))
done

if [[ -n "$IP" ]]; then
  echo "✅ LoadBalancer IP assigned: $IP"
else
  echo "ℹ️  Proceeding without LoadBalancer IP."
fi
```

Build configmap with SCONE Operator dashboard from template.

```bash
cp prometheus-grafana-manifests/configmap-dashboard-operator-template.yaml prometheus-grafana-manifests/configmap-dashboard-operator.yaml
sed 's/^/    /' prometheus-grafana-manifests/scone-dashboard-scone-operator.json >> prometheus-grafana-manifests/configmap-dashboard-operator.yaml

#export SCONE_DASHBOARD_RUNTIME_APP=$(cat prometheus-grafana-manifests/scone-dashboard-runtime-app.json)
cp prometheus-grafana-manifests/configmap-dashboard-runtime-template.yaml prometheus-grafana-manifests/configmap-dashboard-runtime.yaml
sed 's/^/    /' prometheus-grafana-manifests/scone-dashboard-runtime-app.json >> prometheus-grafana-manifests/configmap-dashboard-runtime.yaml
```

Apply configmap with the dashboards.

```bash
kubectl apply --server-side -n monitoring -f prometheus-grafana-manifests/configmap-dashboard-operator.yaml
kubectl apply --server-side -n monitoring -f prometheus-grafana-manifests/configmap-dashboard-runtime.yaml


current_volumes=$(kubectl get deployment -n monitoring grafana -o json | jq -e -r '.spec.template.spec.volumes')

updates_volumes=$(echo $current_volumes | jq '. += [
  {
    "configMap": {
      "defaultMode": 420,
      "name": "grafana-scone-dashboard-operator"
    },
    "name": "grafana-scone-dashboard-operator"
  },
  {
    "configMap": {
      "defaultMode": 420,
      "name": "grafana-scone-dashboard-runtime"
    },
    "name": "grafana-scone-dashboard-runtime"
  }
]')

current_volume_mounts=$(kubectl get deployment -n monitoring grafana -o json | jq -e -r '.spec.template.spec.containers[0].volumeMounts')
updates_volume_mounts=$(echo $current_volume_mounts | jq '. += [
  {
    "mountPath": "/grafana-dashboard-definitions/0/grafana-scone-dashboard-operator",
    "name": "grafana-scone-dashboard-operator"
  },
  {
    "mountPath": "/grafana-dashboard-definitions/0/grafana-scone-dashboard-runtime",
    "name": "grafana-scone-dashboard-runtime"
  }
]')

kubectl patch deployment -n monitoring grafana --type=json --patch """
  [
      {
          "op": "replace",
          "path": "/spec/template/spec/volumes",
          "value": $updates_volumes
      },
      {
          "op": "replace",
          "path": "/spec/template/spec/containers/0/volumeMounts",
          "value": $updates_volume_mounts
      },
  ]
""" || echo "We ignore errors because of duplicates"
```

## Grafana Dashboard

The login credentials for the Grafana dashboard are:

```bash
echo    "Login:    admin"
echo    "Password: admin"
```

On the computer where your browser run, you can execute:

```
kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80
```

You can then open the Grafana dashboard in your browser at <http://localhost:3000>


## Visualizing SCONE Operator Metrics

Access the dashboard for the SCONE Operator Metrics in `Grafana Home -> Dashboards -> Default -> SCONE Operator Dashboard`.
