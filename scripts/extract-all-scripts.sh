#!/usr/bin/env bash

set -euo pipefail

./scripts/extract-bash.sh sconecli.md scripts/install_sconecli.sh
./scripts/extract-bash.sh scone_operator.md scripts/reconcile_scone_operator.sh

./scripts/extract-bash.sh deploying-osv-scanner.md scripts/install_osv_scanner.sh
