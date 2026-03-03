#!/usr/bin/env bash

set -euo pipefail
export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--force"

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

printf "${VIOLET}"
printf '%s\n' '# Prometheus and Grafana Stack'
printf '%s\n' ''
printf '%s\n' 'Prometheus and Grafana are two widely used open-source tools for monitoring and visualizing system metrics and application performance.'
printf '%s\n' ''
printf '%s\n' '![Screencast](docs/install_prometheus_grafana.gif)'
printf '%s\n' ''
printf '%s\n' '- Prometheus collects and stores metrics.'
printf '%s\n' ''
printf '%s\n' '- Grafana queries Prometheus and displays those metrics.'
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' '## Installing Prometheus (Optional)'
printf '%s\n' ''
printf '%s\n' 'If you already have Prometheus running in your cluster, you can skip this section.'
printf '%s\n' ''
printf '%s\n' 'Install from https://github.com/prometheus-operator/kube-prometheus.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Create the namespace and CRDs, and then wait for them to be available before creating the remaining resources'
printf '%s\n' '# Note that due to some CRD size we are using kubectl server-side apply feature which is generally available since kubernetes 1.22.'
printf '%s\n' '# If you are using previous kubernetes versions this feature may not be available and you would need to use kubectl create instead.'
printf '%s\n' 'pushd /tmp'
printf '%s\n' '# ensure we do not get wrong content'
printf '%s\n' 'rm -rf kube-prometheus || true'
printf '%s\n' 'git clone https://github.com/prometheus-operator/kube-prometheus.git -b v0.15.0 --depth 1'
printf '%s\n' 'pushd kube-prometheus'
printf '%s\n' 'kubectl apply --server-side -f manifests/setup || true'
printf '%s\n' 'kubectl wait \'
printf '%s\n' '    --for condition=Established \'
printf '%s\n' '    --all CustomResourceDefinition \'
printf '%s\n' '    --namespace=monitoring || true'
printf '%s\n' 'kubectl apply -f manifests/ || true'
printf '%s\n' 'popd; popd'
printf "${RESET}"

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

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Enabling Metrics Collection (ServiceMonitor)'
printf '%s\n' ''
printf '%s\n' 'SCONE metrics are exposed via Prometheus and require a ServiceMonitor to be applied before dashboards can display data.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl apply -f prometheus-grafana-manifests/service-monitor.yaml'
printf "${RESET}"

kubectl apply -f prometheus-grafana-manifests/service-monitor.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Grafana Dashboard'
printf '%s\n' ''
printf '%s\n' 'Before importing the SCONE dashboards, you must be able to access the Grafana UI.'
printf '%s\n' ''
printf '%s\n' 'The login credentials for the Grafana dashboard are:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'echo    "Login:    admin"'
printf '%s\n' 'echo    "Password: admin"'
printf "${RESET}"

echo    "Login:    admin"
echo    "Password: admin"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'On the computer where your browser runs, you can execute:'
printf '%s\n' ''
printf '%s\n' 'kubectl port-forward -n monitoring svc/grafana 3000:3000'
printf '%s\n' ''
printf '%s\n' 'You can then open the Grafana dashboard in your browser at <http://localhost:3000>'
printf '%s\n' ''
printf '%s\n' '## Importing SCONE Dashboards into Grafana'
printf '%s\n' ''
printf '%s\n' 'SCONE provides preconfigured Grafana dashboards for visualizing Prometheus metrics.'
printf '%s\n' ''
printf '%s\n' '### Available Dashboards'
printf '%s\n' ''
printf '%s\n' '* ```Scone Operator Dashboard```: contains LAS and SGX-Plugin metrics. It also contains a CAS instance status overview. '
printf '%s\n' '  * ```Scone Operator CAS Details Dashboard```: this dashboard contains metrics for a specified CAS instance, selected from the overview in the Scone Operator Dashboard.'
printf '%s\n' '* ```Scone Operator Controller Dashboard```: contains Scone Operator Controller metrics, including certificate read metrics, controller runtime metrics, Go metrics, leader election metrics, etc.'
printf '%s\n' '* ```Scone Runtime Dashboard```: contains an overview for SCONEfied applications running in the cluster. To display detailed metrics for a given application, click the application'\''s identifier in the overview. This identifier is based on the application'\''s config ID, its CAS address, its namespace and its corresponding service.'
printf '%s\n' '* ```Scone Runtime Application Details Dashboard```: contains metrics for a given application, selected from the application overview inside the Scone Runtime Dashboard detailed above.'
printf '%s\n' ''
printf '%s\n' 'All dashboard JSON files are located in:'
printf '%s\n' 'scone/prometheus-grafana-manifests'
printf '%s\n' ''
printf '%s\n' '### Import Steps'
printf '%s\n' ''
printf '%s\n' '1. Open the Grafana UI.'
printf '%s\n' '2. Navigate to ```Dashboards``` from the Grafana home page.'
printf '%s\n' '3. Click `New -> Import`.'
printf '%s\n' '4. Upload the desired SCONE dashboard JSON file.'
printf '%s\n' '5. Click Import to complete the process.'
printf '%s\n' ''
printf '%s\n' '## Visualizing SCONE Operator Metrics'
printf '%s\n' ''
printf '%s\n' 'Access the dashboard for the SCONE Operator Metrics in `Grafana Home -> Dashboards -> SCONE Dashboard`.'
printf '%s\n' ''
printf '%s\n' '## SCONE Runtime Metrics'
printf '%s\n' ''
printf '%s\n' 'The SCONE Runtime can collect metrics and provide this information via a Prometheus metric.'
printf '%s\n' ''
printf '%s\n' '### Activate metrics collection in the application'
printf '%s\n' ''
printf '%s\n' '- Metrics are exposed when environment variable `SCONE_METRICS` is defined, the value indicates at which port the metrics are expose. For example, `SCONE_METRICS=prometheus_port:9090` exposes metrics on port 9090. Other ports can be used if desired, this guide continues assuming port 9090 is supposed to be used.'
printf '%s\n' ''
printf '%s\n' '- If the application runs in a CAS session, add `SCONE_METRICS: "prometheus_port:9090"`. '
printf '%s\n' '- If the application runs standalone, specify `SCONE_METRICS=prometheus_port:9090` in its execution environment.'
printf '%s\n' ''
printf '%s\n' 'Point your Prometheus Scraper at the services address and the used port to collect the produced metrics.'
printf '%s\n' 'In SCONE 6.0.4, the following metrics are exposed:'
printf '%s\n' ''
printf '%s\n' '# HELP scone_enclave_heap_allocated_bytes The amount of memory requested by the application (roughly equal to VSZ)'
printf '%s\n' '# TYPE scone_enclave_heap_allocated_bytes gauge'
printf '%s\n' 'scone_enclave_heap_allocated_bytes{run_id="9fe39eadbef32e20",scone_version="6.0.4"} 8536064'
printf '%s\n' '# HELP scone_enclave_heap_allocated_bytes_max The peak amount of memory requested by the application (roughly equal to VSZ)'
printf '%s\n' '# TYPE scone_enclave_heap_allocated_bytes_max gauge'
printf '%s\n' 'scone_enclave_heap_allocated_bytes_max{run_id="9fe39eadbef32e20",scone_version="6.0.4"} 8552448'
printf '%s\n' '# HELP scone_enclave_heap_consecutive_allocated_heap_bytes The size of the consecutive allocated heap memory - the closer this is to allocated_bytes the lower fragmentation is in the heap'
printf '%s\n' '# TYPE scone_enclave_heap_consecutive_allocated_heap_bytes gauge'
printf '%s\n' 'scone_enclave_heap_consecutive_allocated_heap_bytes{run_id="9fe39eadbef32e20",scone_version="6.0.4"} 4317184'
printf '%s\n' '# HELP scone_enclave_heap_max_bytes The maximal application available heap space'
printf '%s\n' '# TYPE scone_enclave_heap_max_bytes gauge'
printf '%s\n' 'scone_enclave_heap_max_bytes{run_id="9fe39eadbef32e20",scone_version="6.0.4"} 67108864'
printf '%s\n' '# HELP scone_page_allocator_brk The size of the program break memory'
printf '%s\n' '# TYPE scone_page_allocator_brk gauge'
printf '%s\n' 'scone_page_allocator_brk{run_id="9fe39eadbef32e20",scone_version="6.0.4"} 0'
printf '%s\n' '# HELP scone_page_allocator_committed_memory_bytes EDMM: The amount of committed heap memory (same as dynamically_allocated_memory_bytes + min_heap)'
printf '%s\n' '# TYPE scone_page_allocator_committed_memory_bytes gauge'
printf '%s\n' 'scone_page_allocator_committed_memory_bytes{run_id="9fe39eadbef32e20",scone_version="6.0.4"} 67108864'
printf '%s\n' '# HELP scone_page_allocator_dynamically_allocated_memory_bytes EDMM: The amount of heap memory dynamically allocated by the application'
printf '%s\n' '# TYPE scone_page_allocator_dynamically_allocated_memory_bytes gauge'
printf '%s\n' 'scone_page_allocator_dynamically_allocated_memory_bytes{run_id="9fe39eadbef32e20",scone_version="6.0.4"} 0'
printf '%s\n' '# HELP scone_page_allocator_mmap_calls Number of mmap() calls that have been handled by the in-enclave page allocator'
printf '%s\n' '# TYPE scone_page_allocator_mmap_calls gauge'
printf '%s\n' 'scone_page_allocator_mmap_calls{run_id="9fe39eadbef32e20",scone_version="6.0.4"} 52'
printf '%s\n' '# HELP scone_page_allocator_mremap_calls Number of mremap() calls that have been handled by the in-enclave page allocator'
printf '%s\n' '# TYPE scone_page_allocator_mremap_calls gauge'
printf '%s\n' 'scone_page_allocator_mremap_calls{run_id="9fe39eadbef32e20",scone_version="6.0.4"} 0'
printf '%s\n' '# HELP scone_page_allocator_munmap_calls Number of munmap() calls that have been handled by the in-enclave page allocator'
printf '%s\n' '# TYPE scone_page_allocator_munmap_calls gauge'
printf '%s\n' 'scone_page_allocator_munmap_calls{run_id="9fe39eadbef32e20",scone_version="6.0.4"} 27'
printf "${RESET}"

