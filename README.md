# SCONE Confidential Computing Platform

This repo contains several markdown files and a version file:

- [`stable.txt`](stable.txt): the latest stable version of the SCONE platform


When you install software, please follow the following steps. First, install software on your local machine:

- [`prerequisite_check.md`](prerequisite_check.md): explains how to install all required prerequisites for runninf `scone`-related commands. To speed up the process, you can execute the script `./scripts/prerequisite_check.sh`. This script also calls `./scripts/install_sconecli.sh`.

- [`sconecli.md`](sconecli.md): a description on how to install the `scone` CLI on your host / development VM. To speed up the process, you can execute the script `./scripts/install_sconecli.sh` to install the latest stable version of the SCONE CLI. Note that this script is called by `./scripts/prerequisite_check.sh`, i.e., only needed in case you only want to install / upgrade SCONE-related commands.

Second, install the SCONE platform and a first CAS instance on your Kubernetes cluster:

- [`scone_operator.md`](scone_operator.md): a description on how to install or upgrade the SCONE platform in a Kubernetes cluster. To speed up the process, you can execute the script `./scripts/reconcile_scone_operator.sh`.

- [`CAS.md`](CAS.md): a description on how to create a CAS `cas` in the default namespace.

## Automatic Script Extraction

All markdown files are associated with a script that executes the individual steps of the script.

- `scripts/extract-all-scripts.sh`: almost all scripts in directory `scripts` are automatically derived from the markdown files. In case one updates the markdown files, one can update the generated scripts by executing `scripts/extract-all-scripts.sh`.

- `scripts/extract-bash.sh`: a simple script that extracts all `bash` and `sh` blocks from a given markdown file and stores it in a script file.

