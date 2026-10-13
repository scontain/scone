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

- [`sconecli.md`](sconecli.md): describes how to install the required SCONE workflow commands (`scone`, `kubectl-scone`, `kubectl-scone-azure`, `scone-td-build`) on your machine or development VM. To speed up the process, run `./scripts/install_sconecli.sh` to install either the latest stable version (default) or another SCONE version.

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

- [scone-td-build](https://github.com/scontain-gmbh/scone-td-build-demos): shows how to transform cloud-native applications into confidential cloud-native applications running on Intel SGX, Intel TDX or AMD SEV-SNP.

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

Prepare the override binaries, then build the image with the same SCONE release:

```bash
SCONE_VERSION=6.0.8 ./overwrite.sh
./scripts/build.sh --version 6.0.8
```

`overwrite.sh` builds `scone-td-build` **0.4.0** from pinned revision
`b607bdc7009fc8990c2f083fdf02180f436c5369` and `kubectl-scone` **6.0.5** from
`00044d0bbe70f005398833eb9a5efac394fd93d4`. The plugin uses the boolean
`autoUpdate` schema expected by the 6.0 operator. Its patch version differs from
the **6.0.8** SCONE image/package release. It no longer follows `main`.
The public helpers and Azure plugin are also built. Cargo names the Azure executable
`kubectl-scone_azure`; `overwrite.sh` renames it to `kubectl-scone-azure`, which is
the name kubectl plugin discovery requires. `kubectl-provision` is copied from
`$HOME/.cargo/bin/kubectl-provision` (override that path with
`KUBECTL_PROVISION_BINARY`). Private repository access is required.

Builds use a temporary directory. All binaries must pass validation before they
replace existing overrides; files are copied completely and flushed before atomic
replacement. To select different source revisions, set `SCONE_TD_BUILD_REV` and
`SCONE_KUBECTL_PLUGIN_REV`. Their output must still pass the target version and
interface checks. `SCONE_VERSION` defaults to `stable.txt` for `overwrite.sh`.

`build.sh` requires prepared overrides; it does not compile them. Before calling
Docker it validates the actual files in `overwrite/bin`, independently of host
`PATH`. The Dockerfile repeats the checks inside the image, fails on missing or
uncopyable binaries, and uses the requested `SCONE_VERSION` for package installation.
After building, `build.sh` runs the installed tooling check in the completed image
before tagging or pushing it. Validation does not contact Kubernetes.

To check overrides without building:

```bash
SCONE_VERSION=6.0.8 ./scripts/check-scone-tooling.sh --overrides-dir overwrite/bin
```

The build uses the `dind` Docker context at `tcp://172.17.0.1:2375` for building,
checking, tagging and pushing. It requires `$HOME/.kube/config` and
`$HOME/.docker/config.json` as BuildKit secrets. Local credential YAML files are
excluded from the build context by `.dockerignore` and remain on the host.

To build and push the versioned image:

```bash
./scripts/build.sh --version 6.0.8 --push-to registry.scontain.com/workshop/scone
```

The existing `--test` option additionally runs the Kubernetes toolbox demos.
