# SCONE Confidential Computing Platform

This repo contains several markdown files and a version file:

- [`stable.txt`](stable.txt): the latest stable version of the SCONE platform


When installing software, please follow these steps. First, install software on your local machine:

- [`prerequisite_check.md`](prerequisite_check.md): explains how to install all required prerequisites for running `scone`-related commands. To speed up the process, you can execute the script `./scripts/prerequisite_check.sh`. This script also calls `./scripts/install_sconecli.sh`.

- [`sconecli.md`](sconecli.md): a description on how to install the `scone` CLI on your host/development VM. To speed up the process, you can execute the script `./scripts/install_sconecli.sh` to install the latest stable version of the SCONE CLI. Note that this script is called by `./scripts/prerequisite_check.sh`, i.e., only needed in case you only want to install/upgrade SCONE-related commands.

Second, install the SCONE platform and a first CAS instance on your Kubernetes cluster:

- [`scone_operator.md`](scone_operator.md): a description on how to install or upgrade the SCONE platform in a Kubernetes cluster. To speed up the process, you can execute the script `./scripts/reconcile_scone_operator.sh`.

- [`CAS.md`](CAS.md): a description on how to create a CAS instance. You can execute as a script: `./scripts/install_cas.sh`. The script asks for the name and the namespace of the CAS - unless you defined environment variables `CAS` and/or `CAS_NAMESPACE`.

- [golang support](https://github.com/scontain/golang): we support the latest golang versions for building confidential applications.

## Automatic Script Extraction

All markdown files are associated with a script that executes the individual steps of the script.

- `scripts/extract-all-scripts.sh`: almost all scripts in the directory `scripts` are automatically derived from the markdown files. If one updates the Markdown files, the generated scripts can be updated by executing `scripts/extract-all-scripts.sh`.

- `scripts/extract-bash.sh`: a simple script that extracts all `bash` and `sh` blocks from a given markdown file and stores them in a script file.

## Running with Docker

### Copy and create the registry env

```bash
cp scone-registry.env.template scone-registry.env
```

Provide the correct credentials. To generate an access token, follow these instructions: <https://sconedocs.github.io/registry/#create-an-access-token>

### Build the image

```bash
docker build -t scone:latest .
```

### Run the image

Create a container using the image

```bash
export KUBECONFIG_PATH=<path-to-your-kubeconfig>
docker run -it --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $KUBECONFIG_PATH:/kubeconfig \
    -v ./scone-registry.env:/scone-registry.env \
    scone:latest
```

### Pre-built Container Image

We also maintain a pre-built image at <registry.scontain.com/workshop/scone>.

```bash
cat > scone-registry.env <<EOF
export SCONE_REGISTRY_ACCESS_TOKEN="<...>see https://sconedocs.github.io/registry/#create-an-access-token>"
export SCONE_REGISTRY_USERNAME="<...>"
EOF
```

