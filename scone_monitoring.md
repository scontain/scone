# Prometheus and Grafana Stack

Prometheus and Grafana are two widely used open-source tools for monitoring and visualizing system metrics and application performance.

- Prometheus collects and stores metrics.

- Grafana queries Prometheus and displays those metrics.


## Installing Prometheus


```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
```

## Grafana Dashboard

The login credentials for the Grafana dashboard are:

```bash
echo    "Login: admin"
echo -n "Password: "
kubectl --namespace monitoring get secrets kube-prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

On the computer where your browser run, you can execute:

```
kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80
```

You can then open the Grafana dashboard in your browser at <http://localhost:3000>

## Enabling CAS Metrics

We switch on the enclave metrics on CAS 'cas' in namespace 'default':

```bash
export CAS="cas"
export CAS_NAMESPACE="default"
kubectl patch cas $CAS -n $CAS_NAMESPACE \
  --type=json \
  -p='[{"op": "replace", "path": "/spec/enclaveMetrics/enabled", "value": true}]'
```

## Visualizing CAS Metrics