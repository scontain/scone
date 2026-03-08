# SCONE Confidential Computing Platform

This repository contains markdown guides that explain how to install the SCONE platform. It also includes a version file:

- [`stable.txt`](stable.txt): the latest stable version of the SCONE platform

## Installation

The SCONE Confidential Computing Platform includes components that run on your local machine (for development) and components that run in a Kubernetes cluster (for development and production). This guide shows how to run the development components in a Kubernetes cluster.

### Local Installation

If you want to install the development components on your local machine or on a development VM, follow these steps.

> **Note**: We currently assume your machine is x86-based. CPU emulation is not sufficient because we require instructions such as `rdrnd` that are not emulated. For this reason, we also show below how to run the development components in a Kubernetes cluster made up of x86 machines.

- [`prerequisite_check.md`](prerequisite_check.md): explains how to install all prerequisites required for `scone` commands. To speed up the process, run `. ./scripts/prerequisite_check.sh`. The leading `.` is required so the current shell's `PATH` is updated.

![Screencast](docs/prerequisite_check.gif)

- [`sconecli.md`](sconecli.md): describes how to install the `scone` CLI on your machine or development VM. To speed up the process, run `./scripts/install_sconecli.sh` to install either the latest stable version (default) or another SCONE CLI version.

![Screencast](docs/install_sconecli.gif)

## Kubernetes Cluster Installation (Development and Production Components)

If you do not have a dedicated x86 development VM, you can run the development components as part of a Kubernetes cluster with x86 nodes:

- [`prerequisite_check.md`](prerequisite_check.md): run `. ./scripts/prerequisite_check.sh` to ensure `kubectl` and `cargo` are installed.

![Screencast](docs/prerequisite_check.gif)

Next, install the SCONE platform and an initial CAS instance in your Kubernetes cluster. These components are required to run confidential applications, so the cluster is expected to run Kubernetes nodes that support confidential computing.

> **Note:** We can provide a `kubectl` plugin to create a confidential Kubernetes cluster on-premises or on common cloud providers. Contact us at info@scontain.com.

- [`scone_operator.md`](scone_operator.md): describes how to install or upgrade the SCONE platform in a Kubernetes cluster. To speed up the process, run `./scripts/reconcile_scone_operator.sh`.

![Screencast](docs/reconcile_scone_operator.gif)

- [`CAS.md`](CAS.md): describes how to create a CAS instance. You can also run `./scripts/install_cas.sh`, which prompts for the CAS name and namespace.

![Screencast](docs/install_cas.gif)

- [`scone_monitoring.md`](scone_monitoring.md): optional installation of Prometheus, Grafana, and SCONE dashboards.

![Screencast](docs/install_prometheus_grafana.gif)

- Inside the container, you can build confidential applications such as our [confidential Java app](https://github.com/scontain/java-args-env-file).

- [`k8s.md`](k8s.md): describes the steps to deploy SCONE commands in a Kubernetes cluster. These steps are also included in `./scripts/k8s_cli.sh`.

![Screencast](docs/k8s_cli.gif)

## Tutorials

- [scone-td-build](https://github.com/scontainug/scone-td-build-demos): shows how to transform cloud-native applications into confidential cloud-native applications running on Intel TDX or AMD SEV-SNP.

- [confidential Java app](https://github.com/scontain/java-args-env-file): shows how to run a cloud-native Java service as a confidential cloud-native Java service on Intel SGX, Intel TDX, or AMD SEV-SNP.

- [golang.md](golang.md): SCONE Go support documentation and workflow.

![Screencast](docs/run_golang.gif)

- [Go support](https://github.com/scontain/golang): provides container images with the latest `Go` versions for building native applications.
- Shows how to build a native `Go` application (`caddy`) into a [`confidential caddy`](https://github.com/scontainug/caddy) application using [`scone-signer`](https://sconedocs.github.io/CAS_cli/#scone-signer).

## SCONE Workshop Container Image

We maintain a prebuilt container image at <registry.scontain.com/workshop/scone> that contains all SCONE development tools.

### Pull Credentials

This container image needs access to `registry.scontain.com`; credentials are stored in `scone-registry.env`.

- If you are already logged in to `registry.scontain.com` with your local Docker instance, run:

```bash
./scripts/extract_scone-registry-env.sh
```

This creates `scone-registry.env`.

- If you are not logged in yet, you can create the file manually:

```bash
tplenv --file scone-registry.env.template --output scone-registry.env --values registy.credentials.yaml --create-values-file --context --force
```

### Run the Workshop Image

Create a container from the image:

```bash
export KUBECONFIG_PATH=${KUBECONFIG:-$HOME/.kube/config}
docker run -it --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $KUBECONFIG_PATH:/kubeconfig \
    -v ./scone-registry.env:/scone-registry/scone-registry-env \
    registry.scontain.com/workshop/scone
```

> **Note:** `./scripts/k8s_cli.sh` deploys the workshop image in a Kubernetes cluster. Because Docker is required to build container images, a Docker engine also runs in the Kubernetes cluster.

## Background

### Automatic Script Extraction

Each markdown file is associated with a script that executes the documented steps.

- `scripts/extract-all-scripts.sh`: most scripts in the `scripts` directory are automatically derived from markdown files. If you update markdown content, regenerate scripts by running `scripts/extract-all-scripts.sh`.
- `scripts/extract-bash.sh`: extracts all `bash` and `sh` blocks from a markdown file and stores them in a script file.

Generate updated screencasts by running `make`.

### Building the workshop image

Build with:

````
./scripts/build.sh --version <SCONE_VERSION>
./scripts/build.sh --version <SCONE_VERSION> --test
```

These commands build the `scone-td-build` image as follows:

```bash
# HOSTIP as seen from within the docker container
export HOSTIP="172.17.0.1" 
docker context create dind \
  --docker "host=tcp://${HOSTIP}:2375" || true

rm registy.credentials.yaml || true
rm Values.credentials.yaml || true

export SCONE_VERSION=$(cat stable.txt)

docker --context dind  buildx build \
    --secret id=kubeconfig,src=$HOME/.kube/config  \
    --secret id=dockerconfig,src=$HOME/.docker/config.json \
    --build-arg DOCKER_HOST="tcp://${HOSTIP}:2375" \
    -t scone:latest \
    --build-arg SCONE_VERSION \
    --file Dockerfile .
```

Next, you can tag and push your image. For example:

```bash
docker tag scone:latest registry.scontain.com/workshop/scone
docker tag scone:latest registry.scontain.com/workshop/scone:$SCONE_VERSION
docker push registry.scontain.com/workshop/scone
docker push registry.scontain.com/workshop/scone:$SCONE_VERSION
```
