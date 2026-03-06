#!/usr/bin/env bash

set -euo pipefail
export CONFIRM_ALL_ENVIRONMENT_VARIABLES=${CONFIRM_ALL_ENVIRONMENT_VARIABLES:-"--force"}

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

printf "${VIOLET}"
printf '%s\n' '# SCONE CLI'
printf '%s\n' ''
printf '%s\n' 'You can run the [`scone` CLI](https://sconedocs.github.io/CAS_cli/) on your **host machine**, within a **virtual machine (VM)**, or inside a **container**. While running it in a container offers good portability, it may suffer from slower startup times. Therefore, we recommend installing the `scone` CLI **directly on your development machine** for better performance.'
printf '%s\n' ''
printf '%s\n' '![Screencast](docs/install_sconecli.gif)'
printf '%s\n' ''
printf '%s\n' 'This document explains how to install the `scone` CLI on **Linux distributions that support Debian packages**. Packages are also available for **Alpine Linux**.'
printf '%s\n' ''
printf '%s\n' 'NOTE: We assume that you already run `./scripts/prerequisite_check.sh`.'
printf '%s\n' ''
printf '%s\n' '## Caveat When Running Inside a Container'
printf '%s\n' ''
printf '%s\n' 'There are two versions of the `scone` CLI:'
printf '%s\n' ''
printf '%s\n' '- A **native version** that cannot run inside an enclave'
printf '%s\n' '- The **default version**, which is designed to run **inside an enclave**'
printf '%s\n' '  '
printf '%s\n' 'By default, the `scone` CLI of a container runs confidential in production mode. To run in simulation mode on systems that do not support production TEEs, set the environment variable `SCONE_PRODUCTION=0`, e.g., you can run`SCONE_PRODUCTION=0 scone --help` .'
printf '%s\n' ''
printf '%s\n' 'Below, we describe how to install the `scone` CLI using `auto` mode, i.e., the CLI will most likely run in simulation mode.'
printf '%s\n' ''
printf '%s\n' '## Installing the `scone` CLI '
printf '%s\n' ''
printf '%s\n' 'We assume in this description that you run a Debian-based distribution like Ubuntu. Note that we also have packages for Alpine Linux.'
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' '`tplenv` will now ask the user for all environment variables that are described in file `environment-variables.md`'
printf '%s\n' 'but that are not set yet. '
printf '%s\n' ''
printf '%s\n' 'Let'\''s ask the user and set the environment variables depending on the input of the user:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'eval $(tplenv --file environment-variables.md --create-values-file --eval --context ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'
printf "${RESET}"

eval $(tplenv --file environment-variables.md --create-values-file --eval --context ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'The SCONE CLI is available as Debian packages as part of a container image. '
printf '%s\n' 'We first verify that the container image is properly signed by cosign.'
printf '%s\n' ''
printf '%s\n' 'To do so, we define the cosign public verification key using a function `create_cosign_verification_key`.'
printf '%s\n' 'We verify the signature of a given container image with function `verify_image`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '#'
printf '%s\n' '# create a file with the public key of the signer key for all scone.cloud images'
printf '%s\n' '#'
printf '%s\n' ''
printf '%s\n' 'function create_cosign_verification_key() {'
printf '%s\n' '    export cosign_public_key_file="$(mktemp).pub"'
printf '%s\n' '    cat > $cosign_public_key_file <<SEOF'
printf '%s\n' '-----BEGIN PUBLIC KEY-----'
printf '%s\n' 'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAErLf0HT8xZlLaoX5jNN8aVL1Yrs+P'
printf '%s\n' 'wS7K6tXeRlWLlUX1GeEtTdcuhZMKb5VUNaWEJW2ZU0YIF91D93dCZbUYpw=='
printf '%s\n' '-----END PUBLIC KEY-----'
printf '%s\n' 'SEOF'
printf '%s\n' '}'
printf '%s\n' ''
printf '%s\n' 'function verify_image() {'
printf '%s\n' '    local image_name'
printf '%s\n' '    image_name="$1"'
printf '%s\n' '    if [[ "$image_name" == "" ]]; then'
printf '%s\n' '        echo "The name of the image for which we should verify the signature, was empty. Exiting."'
printf '%s\n' '        exit 1'
printf '%s\n' '    fi'
printf '%s\n' ''
printf '%s\n' '    echo "Verifying the signature of image '\''$image_name'\''"'
printf '%s\n' ''
printf '%s\n' '    docker pull "$image_name" >/dev/null'
printf '%s\n' '    export cosign_public_key_file=${cosign_public_key_file:-""}'
printf '%s\n' '    if [[ "$cosign_public_key_file" == "" ]]; then'
printf '%s\n' '        create_cosign_verification_key'
printf '%s\n' '    fi'
printf '%s\n' '    cosign verify --key "$cosign_public_key_file" "$image_name" >/dev/null 2> /dev/null || { echo "Failed to verify signature of image '\''$image_name'\''! Exiting! Please check that '\''cosign version'\'' shows a git version >= 2.0.0. Also ensure that there is no field '\''credsStore'\'' in '\''$HOME/.docker/config.json'\''"; exit 1; }'
printf '%s\n' ''
printf '%s\n' '    echo " - verification was successful"'
printf '%s\n' '}'
printf "${RESET}"

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

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Next, we define the image that contains the `scone` CLI Debian package and'
printf '%s\n' 'verify the image:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# default repo and image name'
printf '%s\n' 'export REPO="$REGISTRY/scone.cloud"'
printf '%s\n' 'export IMAGE="scone-deb-pkgs"'
printf '%s\n' ''
printf '%s\n' 'verify_image "$REPO/$IMAGE:$SCONE_VERSION"'
printf "${RESET}"

# default repo and image name
export REPO="$REGISTRY/scone.cloud"
export IMAGE="scone-deb-pkgs"

verify_image "$REPO/$IMAGE:$SCONE_VERSION"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'After successful verification, we create a temporary container'
printf '%s\n' 'to be able to copy the Debian packages to the local filesystem.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# ensure that container scone-packages does not exit'
printf '%s\n' 'docker rm scone-packages 2> /dev/null || true'
printf '%s\n' ''
printf '%s\n' '# run container such that we can copy the packages to a local repo'
printf '%s\n' 'docker create --name scone-packages "$REPO/$IMAGE:$SCONE_VERSION" sleep 1 > /dev/null'
printf "${RESET}"

# ensure that container scone-packages does not exit
docker rm scone-packages 2> /dev/null || true

# run container such that we can copy the packages to a local repo
docker create --name scone-packages "$REPO/$IMAGE:$SCONE_VERSION" sleep 1 > /dev/null

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Next, we copy the package to the `/tmp` directory and'
printf '%s\n' 'install the `scone` packages. '
printf '%s\n' ''
printf '%s\n' 'You will need to type your `sudo` password:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# copy the packages'
printf '%s\n' 'mkdir -p /tmp/packages'
printf '%s\n' 'docker cp scone-packages:/ /tmp/packages'
printf '%s\n' 'docker rm scone-packages'
printf '%s\n' ''
printf '%s\n' '# install the packages'
printf '%s\n' 'sudo dpkg -i /tmp/packages/scone-common_amd64.deb '
printf '%s\n' 'sudo dpkg -i /tmp/packages/scone-libc_amd64.deb '
printf '%s\n' 'sudo dpkg -i /tmp/packages/scone-cli_amd64.deb '
printf '%s\n' 'sudo dpkg -i /tmp/packages/k8s-scone.deb'
printf '%s\n' 'sudo dpkg -i /tmp/packages/kubectl-scone.deb '
printf '%s\n' ''
printf '%s\n' '# clean up'
printf '%s\n' 'rm -rf /tmp/packages'
printf "${RESET}"

# copy the packages
mkdir -p /tmp/packages
docker cp scone-packages:/ /tmp/packages
docker rm scone-packages

# install the packages
sudo dpkg -i /tmp/packages/scone-common_amd64.deb 
sudo dpkg -i /tmp/packages/scone-libc_amd64.deb 
sudo dpkg -i /tmp/packages/scone-cli_amd64.deb 
sudo dpkg -i /tmp/packages/k8s-scone.deb
sudo dpkg -i /tmp/packages/kubectl-scone.deb 

# clean up
rm -rf /tmp/packages

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'We ensure that `kubectl-scone` plugin only exists once - otherwise, `kubectl` issues a warning:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' ''
printf '%s\n' 'if [[ -e /usr/bin/kubectl-scone && -e /bin/kubectl-scone ]] ; then'
printf '%s\n' '    P1=$(realpath /usr/bin/kubectl-scone )'
printf '%s\n' '    P2=$(realpath /bin/kubectl-scone )'
printf '%s\n' '    if [[ -n "$P1" && -n "$P2" && "$P1" != "$P2" ]]; then'
printf '%s\n' '        rm -f "$P2"'
printf '%s\n' '    fi'
printf '%s\n' 'fi'
printf "${RESET}"


if [[ -e /usr/bin/kubectl-scone && -e /bin/kubectl-scone ]] ; then
    P1=$(realpath /usr/bin/kubectl-scone )
    P2=$(realpath /bin/kubectl-scone )
    if [[ -n "$P1" && -n "$P2" && "$P1" != "$P2" ]]; then
        rm -f "$P2"
    fi
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Check that the `scone` cli is properly installed by executing:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'echo "Expecting SCONE version: $SCONE_VERSION"'
printf '%s\n' 'scone --version'
printf "${RESET}"

echo "Expecting SCONE version: $SCONE_VERSION"
scone --version

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'This should execute the same SCONE version as the previously printed latest stable version.'
printf '%s\n' '(The minimal version is 6.0.0)'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '  echo "✅ All scone-related executable installed"'
printf "${RESET}"

  echo "✅ All scone-related executable installed"

