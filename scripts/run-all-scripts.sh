#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${script_dir}/install_sconecli.sh"
"${script_dir}/reconcile_scone_operator.sh"
"${script_dir}/install_cas.sh"
"${script_dir}/prerequisite_check.sh"
"${script_dir}/install_prometheus_grafana.sh"
"${script_dir}/run_golang.sh"
"${script_dir}/k8s_cli.sh"
