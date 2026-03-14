# SCONE Tooling Installation

You can run the SCONE command set on your **host machine**, within a **virtual machine (VM)**, or inside a **container**. While running it in a container offers good portability, it may suffer from slower startup times. Therefore, we recommend installing all required commands **directly on your development machine** for better performance.

![Screencast](docs/install_sconecli.gif)

This document explains how to install all required SCONE workflow commands on **Linux distributions that support Debian packages**. Packages are also available for **Alpine Linux**.

NOTE: We assume that you already run `./scripts/prerequisite_check.sh`.

## Commands Installed By This Guide

- `scone`
- `kubectl-scone`
- `kubectl-scone-azure`
- `scone-td-build`

## Caveat For `scone` When Running Inside a Container

There are two versions of the `scone` CLI:

- A **native version** that cannot run inside an enclave
- The **default version**, which is designed to run **inside an enclave**
  
By default, the `scone` CLI of a container runs confidential in production mode. To run in simulation mode on systems that do not support production TEEs, set the environment variable `SCONE_PRODUCTION=0`, e.g., you can run`SCONE_PRODUCTION=0 scone --help` .

Below, we describe how to install these commands and run `scone` using `auto` mode, i.e., it will most likely run in simulation mode.

## Installing All Required Commands

We assume in this description that you run a Debian-based distribution like Ubuntu. Note that we also have packages for Alpine Linux.

`tplenv` will now ask the user for all environment variables that are described in file `environment-variables.md`
but that are not set yet. 

Let's ask the user and set the environment variables depending on the input of the user:

```bash
eval $(tplenv --file environment-variables.md --create-values-file --eval --context ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )
```

The core SCONE packages are available as Debian packages as part of a container image. We first verify that the container image is properly signed by cosign.

To do so, we define the cosign public verification key using a function `create_cosign_verification_key`. We verify the signature of a given container image with function `verify_image`:

```bash
#
# create a file with the public key of the signer key for all scone.cloud images
#

function create_cosign_verification_key() {
    export cosign_public_key_file="$(mktemp).pub"
    cat > $cosign_public_key_file <<SEOF
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAErLf0HT8xZlLaoX5jNN8aVL1Yrs+P
wS7K6tXeRlWLlUX1GeEtTdcuhZMKb5VUNaWEJW2ZU0YIF91D93dCZbUYpw==
-----END PUBLIC KEY-----
SEOF
}

function verify_image() {
    local image_name
    image_name="$1"
    if [[ "$image_name" == "" ]]; then
        echo "The name of the image for which we should verify the signature, was empty. Exiting."
        exit 1
    fi

    echo "Verifying the signature of image '$image_name'"

    docker pull "$image_name" >/dev/null
    export cosign_public_key_file=${cosign_public_key_file:-""}
    if [[ "$cosign_public_key_file" == "" ]]; then
        create_cosign_verification_key
    fi
    cosign verify --key "$cosign_public_key_file" "$image_name" >/dev/null 2> /dev/null || { echo "Failed to verify signature of image '$image_name'! Exiting! Please check that 'cosign version' shows a git version >= 2.0.0. Also ensure that there is no field 'credsStore' in '$HOME/.docker/config.json'"; exit 1; }

    echo " - verification was successful"
}
```

Next, we define the image that contains the core SCONE Debian packages and
verify the image:

```bash
# default repo and image name
export REPO="$REGISTRY/scone.cloud"
export IMAGE="scone-deb-pkgs"

verify_image "$REPO/$IMAGE:$SCONE_VERSION"
```

After successful verification, we create a temporary container
to be able to copy the Debian packages to the local filesystem.

```bash
# ensure that container scone-packages does not exit
docker rm scone-packages 2> /dev/null || true

# run container such that we can copy the packages to a local repo
docker create --name scone-packages "$REPO/$IMAGE:$SCONE_VERSION" sleep 1 > /dev/null
```

Next, we copy both Debian packages and required binaries from the same
`scone-packages` container.

You will need to type your `sudo` password:

```bash
# copy Debian packages and required binaries
mkdir -p /tmp/packages
mkdir -p /tmp/scone-bin
docker cp scone-packages:/packages /tmp || {
    docker cp scone-packages:/scone-common_amd64.deb /tmp/packages;
    docker cp scone-packages:/scone-libc_amd64.deb /tmp/packages;
    docker cp scone-packages:/scone-cli_amd64.deb /tmp/packages;
}

docker cp scone-packages:/usr/local/bin/scone-td-build /tmp/scone-bin/
docker cp scone-packages:/usr/local/bin/kubectl-scone /tmp/scone-bin/
docker cp scone-packages:/usr/local/bin/kubectl-scone-azure /tmp/scone-bin/

docker rm scone-packages

# install the packages
sudo dpkg -i /tmp/packages/scone-common_amd64.deb 
sudo dpkg -i /tmp/packages/scone-libc_amd64.deb 
sudo dpkg -i /tmp/packages/scone-cli_amd64.deb 

# install binaries on host
sudo install -m 0755 /tmp/scone-bin/scone-td-build /usr/local/bin/scone-td-build
sudo install -m 0755 /tmp/scone-bin/kubectl-scone /usr/local/bin/kubectl-scone
sudo install -m 0755 /tmp/scone-bin/kubectl-scone-azure /usr/local/bin/kubectl-scone-azure

# clean up
rm -rf /tmp/packages
rm -rf /tmp/scone-bin
```

We ensure that `kubectl-scone` plugin only exists once - otherwise, `kubectl` issues a warning:

```bash

if [[ -e /usr/bin/kubectl-scone && -e /bin/kubectl-scone ]] ; then
    P1=$(realpath /usr/bin/kubectl-scone )
    P2=$(realpath /bin/kubectl-scone )
    if [[ -n "$P1" && -n "$P2" && "$P1" != "$P2" ]]; then
        rm -f "$P2"
    fi
fi
```

Check that all required commands are properly installed by executing:

```bash
echo "Expecting SCONE version: $SCONE_VERSION"
scone --version
kubectl scone --help >/dev/null
kubectl scone-azure --help >/dev/null
scone-td-build --help >/dev/null
```

This should execute the same SCONE version as the previously printed latest stable version.
(The minimal version is 7.0.0). The `--help` checks should also complete successfully.

```bash
  echo "✅ All required SCONE commands installed"
```
