#!/usr/bin/env bash

set -euo pipefail

# Array of input/output file pairs
files=(
  "sconecli.md scripts/install_sconecli.sh"
  "scone_operator.md scripts/reconcile_scone_operator.sh"
  "CAS.md scripts/install_cas.sh"
  "prerequisite_check.md scripts/prerequisite_check.sh"
<<<<<<< HEAD
  "scone_monitoring.md scripts/install_prometheus_grafana.sh"
  # TODO: uncomment it: "deploying-osv-scanner.md scripts/install_osv_scanner.sh"
=======
>>>>>>> 08a5ff1 (change docker file)
)

# Loop over the file pairs
for pair in "${files[@]}"; do
  ./scripts/extract-bash.sh $pair
done
