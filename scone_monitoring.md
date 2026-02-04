# Prometheus and Grafana Stack

Prometheus and Grafana are two widely used open-source tools for monitoring and visualizing system metrics and application performance.

- Prometheus collects and stores metrics.

- Grafana queries Prometheus and displays those metrics.


## Installing Prometheus (Optional)

If you already have Prometheus running in your cluster, you can skip this section.

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

## Enabling Metrics Collection (ServiceMonitor)

SCONE metrics are exposed via Prometheus and require a ServiceMonitor to be applied before dashboards can display data.

```bash
kubectl apply -f prometheus-grafana-manifests/service-monitor.yaml
```

## Grafana Dashboard

Before importing the SCONE dashboards, you must be able to access the Grafana UI.

The login credentials for the Grafana dashboard are:

```bash
echo    "Login:    admin"
echo    "Password: admin"
```

On the computer where your browser run, you can execute:

```
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

You can then open the Grafana dashboard in your browser at <http://localhost:3000>

## Importing SCONE Dashboards into Grafana

SCONE provides preconfigured Grafana dashboards for visualizing Prometheus metrics.

### Available Dashboards

* ```Scone Operator Dashboard```: contains LAS and SGX-Plugin metrics. It also contains a CAS instance status overview. 
  * ```Scone Operator CAS Details Dashboard```: this dashboard contains metrics for a specified CAS instance, selected from the overview in the Scone Operator Dashboard.
* ```Scone Operator Controller Dashboard```: contains Scone Operator Controller metrics, including certificate read metrics, controller runtime metrics, Go metrics, leader election metrics, etc.
* ```Scone Runtime Dashboard```: contains an overview for SCONEfied applications running in the cluster. To display detailed metrics for a given application, click the application's identifier in the overview. This identifier is based on the application's config ID, its CAS address, its namespace and its corresponding service.
* ```Scone Runtime Application Details Dashboard```: contains metrics for a given application, selected from the application overview inside the Scone Runtime Dashboard detailed above.

All dashboard JSON files are located in:
```bash
scone/prometheus-grafana-manifests
```

### Import Steps

1. Open the Grafana UI.
2. Navigate to ```Dashboards``` from the Grafana home page.
3. Click `New -> Import`.
4. Upload the desired SCONE dashboard JSON file.
5. Click Import to complete the process.

## Visualizing SCONE Operator Metrics

Access the dashboard for the SCONE Operator Metrics in `Grafana Home -> Dashboards -> SCONE Dashboard`.

## SCONE Runtime Metrics

The SCONE Runtime can collect metrics and provide this information via a Prometheus metric.

### Activate metrics collection in the application

- Metrics are exposed when environment variable `SCONE_METRICS` is defined, the value indicates at which port the metrics are expose. For example, `SCONE_METRICS=prometheus_port:9090` exposes metrics on port 9090. Other ports can be used if desired, this guide continues assuming port 9090 is supposed to be used.

- If the application runs in a CAS session, add `SCONE_METRICS: "prometheus_port:9090"`. 
- If the application runs standalone, specify `SCONE_METRICS=prometheus_port:9090` in its execution environment.

Point your Prometheus Scraper at the services address and the used port to collect the produced metrics.
In SCONE 6.0.4, the following metrics are exposed:

```bash
# HELP scone_enclave_heap_allocated_bytes The amount of memory requested by the application (roughly equal to VSZ)
# TYPE scone_enclave_heap_allocated_bytes gauge
scone_enclave_heap_allocated_bytes{run_id="9fe39eadbef32e20",scone_version="6.0.4"} 8536064
# HELP scone_enclave_heap_allocated_bytes_max The peak amount of memory requested by the application (roughly equal to VSZ)
# TYPE scone_enclave_heap_allocated_bytes_max gauge
scone_enclave_heap_allocated_bytes_max{run_id="9fe39eadbef32e20",scone_version="6.0.4"} 8552448
# HELP scone_enclave_heap_consecutive_allocated_heap_bytes The size of the consecutive allocated heap memory - the closer this is to allocated_bytes the lower fragmentation is in the heap
# TYPE scone_enclave_heap_consecutive_allocated_heap_bytes gauge
scone_enclave_heap_consecutive_allocated_heap_bytes{run_id="9fe39eadbef32e20",scone_version="6.0.4"} 4317184
# HELP scone_enclave_heap_max_bytes The maximal application available heap space
# TYPE scone_enclave_heap_max_bytes gauge
scone_enclave_heap_max_bytes{run_id="9fe39eadbef32e20",scone_version="6.0.4"} 67108864
# HELP scone_page_allocator_brk The size of the program break memory
# TYPE scone_page_allocator_brk gauge
scone_page_allocator_brk{run_id="9fe39eadbef32e20",scone_version="6.0.4"} 0
# HELP scone_page_allocator_committed_memory_bytes EDMM: The amount of committed heap memory (same as dynamically_allocated_memory_bytes + min_heap)
# TYPE scone_page_allocator_committed_memory_bytes gauge
scone_page_allocator_committed_memory_bytes{run_id="9fe39eadbef32e20",scone_version="6.0.4"} 67108864
# HELP scone_page_allocator_dynamically_allocated_memory_bytes EDMM: The amount of heap memory dynamically allocated by the application
# TYPE scone_page_allocator_dynamically_allocated_memory_bytes gauge
scone_page_allocator_dynamically_allocated_memory_bytes{run_id="9fe39eadbef32e20",scone_version="6.0.4"} 0
# HELP scone_page_allocator_mmap_calls Number of mmap() calls that have been handled by the in-enclave page allocator
# TYPE scone_page_allocator_mmap_calls gauge
scone_page_allocator_mmap_calls{run_id="9fe39eadbef32e20",scone_version="6.0.4"} 52
# HELP scone_page_allocator_mremap_calls Number of mremap() calls that have been handled by the in-enclave page allocator
# TYPE scone_page_allocator_mremap_calls gauge
scone_page_allocator_mremap_calls{run_id="9fe39eadbef32e20",scone_version="6.0.4"} 0
# HELP scone_page_allocator_munmap_calls Number of munmap() calls that have been handled by the in-enclave page allocator
# TYPE scone_page_allocator_munmap_calls gauge
scone_page_allocator_munmap_calls{run_id="9fe39eadbef32e20",scone_version="6.0.4"} 27
```