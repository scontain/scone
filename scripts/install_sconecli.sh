#!/usr/bin/env bash

set -euo pipefail 
LILAC='\033[1;35m'
RESET='\033[0m'
printf "${LILAC}"
cat <<EOF
# SCONE CLI

You can run the ['scone' CLI](https://sconedocs.github.io/CAS_cli/) within a container, a VM, or your host.

## Caveat

We have two versions of the 'scone' CLI:
    - a native version that cannot run inside of an enclave, and
    - the default version that expects to run inside of an enclave
  
By default, the 'scone' CLI inside of an container runs confidential in production mode. To run in simulation mode, set the environment variable 'SCONE_PRODUCTION=0', e.g., you can run'SCONE_PRODUCTION=0 scone --help' on systems that do not support production TEEs.

## Installing the 'scone' CLI 

We assume in this description that you run a Debian-based distribution like Ubuntu. Note that we also have packages for Alpine Linux.

EOF
printf "${RESET}"

# determine the latest stable version of SCONE:
VERSION=$(curl -L -s https://raw.githubusercontent.com/scontain/scone/refs/heads/main/stable.txt)
echo "The lastest stable version of SCONE is $VERSION"
LILAC='\033[1;35m'
RESET='\033[0m'
printf "${LILAC}"
cat <<EOF

The SCONE CLI is available as Debian packages as part of a container image. 
We first verify that the container image is properly signed by cosign.

To do so, we define the cosign public verification key using a function 'create_cosign_verification_key'.
We verify the signature of a given container image with function 'verify_image':

EOF
printf "${RESET}"

#
# create a file with the public key of the signer key for all scone.cloud images
#

function create_cosign_verification_key() {
    export cosign_public_key_file="$(mktemp).pub"
    cat > $cosign_public_key_file <<EOF
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAErLf0HT8xZlLaoX5jNN8aVL1Yrs+P
wS7K6tXeRlWLlUX1GeEtTdcuhZMKb5VUNaWEJW2ZU0YIF91D93dCZbUYpw==
-----END PUBLIC KEY-----
EOF
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
LILAC='\033[1;35m'
RESET='\033[0m'
printf "${LILAC}"
cat <<EOF

Next, we define the image that contains the 'scone' CLI Debian package and
verify the image:

EOF
printf "${RESET}"

# default repo and image name
export REPO="registry.scontain.com/scone.cloud"
export IMAGE="scone-deb-pkgs"

verify_image "$REPO/$IMAGE:$VERSION"
LILAC='\033[1;35m'
RESET='\033[0m'
printf "${LILAC}"
cat <<EOF

After successful verification, we create a temporary container
to be able to copy the Debian packages to the local filesystem.

EOF
printf "${RESET}"

# run container such that we can copy the packages to a local repo
docker create --name scone-packages "$REPO/$IMAGE:$VERSION" sleep 1 > /dev/null
LILAC='\033[1;35m'
RESET='\033[0m'
printf "${LILAC}"
cat <<EOF

Next, we copy the package to the '/tmp' directory and
install the 'scone' packages. 

You need to type your 'sudo' password:

EOF
printf "${RESET}"

# copy the packages
mkdir -p /tmp/packages
docker cp scone-packages:/packages /tmp/
docker rm scone-packages

# install the packages
sudo dpkg -i \
     /tmp/packages/scone-common_amd64.deb \
     /tmp/packages/scone-libc_amd64.deb \
     /tmp/packages/scone-cli_amd64.deb

# clean up
rm -rf /tmp/packages
LILAC='\033[1;35m'
RESET='\033[0m'
printf "${LILAC}"
cat <<EOF

Check that the 'scone' cli is properly installed by executing:

EOF
printf "${RESET}"

echo "Expecting SCONE version: $VERSION"
scone --version
LILAC='\033[1;35m'
RESET='\033[0m'
printf "${LILAC}"
cat <<EOF

This should execute the same SCONE version as the previously printed latest stable version.
(The minimal version is 5.10.0-rc.5)
EOF
printf "${RESET}"

