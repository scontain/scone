#!/usr/bin/env bash

set -euo pipefail
export CONFIRM_ALL_ENVIRONMENT_VARIABLES=${CONFIRM_ALL_ENVIRONMENT_VARIABLES:-"--force"}

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

printf "${VIOLET}"
printf '%s\n' '# SCONE Tooling Installation'
printf '%s\n' ''
printf '%s\n' 'You can run the SCONE command set on your **host machine**, within a **virtual machine (VM)**, or inside a **container**. While running it in a container offers good portability, it may suffer from slower startup times. Therefore, we recommend installing all required commands **directly on your development machine** for better performance.'
printf '%s\n' ''
printf '%s\n' '![Screencast](docs/install_sconecli.gif)'
printf '%s\n' ''
printf '%s\n' 'This document explains how to install all required SCONE workflow commands on **Linux distributions that support Debian packages**. Packages are also available for **Alpine Linux**.'
printf '%s\n' ''
printf '%s\n' 'NOTE: We assume that you already run `./scripts/prerequisite_check.sh`.'
printf '%s\n' ''
printf '%s\n' '## Commands Installed By This Guide'
printf '%s\n' ''
printf '%s\n' '- `scone`'
printf '%s\n' '- `kubectl-scone`'
printf '%s\n' '- `kubectl-scone-azure`'
printf '%s\n' '- `scone-td-build`'
printf '%s\n' ''
printf '%s\n' '## Caveat For `scone` When Running Inside a Container'
printf '%s\n' ''
printf '%s\n' 'There are two versions of the `scone` CLI:'
printf '%s\n' ''
printf '%s\n' '- A **native version** that cannot run inside an enclave'
printf '%s\n' '- The **default version**, which is designed to run **inside an enclave**'
printf '%s\n' '  '
printf '%s\n' 'By default, the `scone` CLI of a container runs confidential in production mode. To run in simulation mode on systems that do not support production TEEs, set the environment variable `SCONE_PRODUCTION=0`, e.g., you can run`SCONE_PRODUCTION=0 scone --help` .'
printf '%s\n' ''
printf '%s\n' 'Below, we describe how to install these commands and run `scone` using `auto` mode, i.e., it will most likely run in simulation mode.'
printf '%s\n' ''
printf '%s\n' '## Installing All Required Commands'
printf '%s\n' ''
printf '%s\n' 'We assume in this description that you run a Debian-based distribution like Ubuntu. Note that we also have packages for Alpine Linux.'
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
printf '%s\n' 'The core SCONE packages are available as Debian packages as part of a container image. We first verify that the container image is properly signed by cosign.'
printf '%s\n' ''
printf '%s\n' 'To do so, we define the cosign public verification key using a function `create_cosign_verification_key`. We verify the signature of a given container image with function `verify_image`:'
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
printf '%s\n' 'Next, we define the image that contains the core SCONE Debian packages and'
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
printf '%s\n' 'Next, we copy both Debian packages and required binaries from the same'
printf '%s\n' '`scone-packages` container.'
printf '%s\n' ''
printf '%s\n' 'You will need to type your `sudo` password:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# copy Debian packages and required binaries'
printf '%s\n' 'mkdir -p /tmp/packages'
printf '%s\n' 'mkdir -p /tmp/scone-bin'
printf '%s\n' 'docker cp scone-packages:/packages /tmp || {'
printf '%s\n' '    docker cp scone-packages:/scone-common_amd64.deb /tmp/packages;'
printf '%s\n' '    docker cp scone-packages:/scone-libc_amd64.deb /tmp/packages;'
printf '%s\n' '    docker cp scone-packages:/scone-cli_amd64.deb /tmp/packages;'
printf '%s\n' '    docker cp scone-packages:/scone-td-build.deb /tmp/scone-bin/;'
printf '%s\n' '    docker cp scone-packages:/kubectl-scone.deb /tmp/scone-bin/;'
printf '%s\n' '    docker cp scone-packages:/kubectl-scone-azure.deb /tmp/scone-bin/;'
printf '%s\n' '}'
printf '%s\n' ''
printf '%s\n' 'export SCONE_GLIBC_DEB=$(docker export scone-packages | tar -t | grep -i "glibc.*installer" | sort -V | tail -1 | xargs basename)'
printf '%s\n' '[[ -n "$SCONE_GLIBC_DEB" ]] || { echo "Failed to locate scone-glibc installer in $REPO/$IMAGE:$SCONE_VERSION"; exit 1; }'
printf '%s\n' 'docker cp "scone-packages:/$SCONE_GLIBC_DEB" /tmp/'
printf '%s\n' ''
printf '%s\n' '# scone-td-build and the kubectl plugins are not in every release'\''s package image (e.g. 6.0.8).'
printf '%s\n' '[[ -e /tmp/scone-bin/scone-td-build ]] || docker cp scone-packages:/usr/local/bin/scone-td-build /tmp/scone-bin/ 2>/dev/null || {'
printf '%s\n' '    # Fall back to a separate scone-td-build image if one is configured.'
printf '%s\n' '    if [[ -n "${SCONE_TD_BUILD_IMAGE:-}" ]]; then'
printf '%s\n' '        docker rm scone-td-build-packages 2> /dev/null || true'
printf '%s\n' '        docker create --name scone-td-build-packages "$SCONE_TD_BUILD_IMAGE" sleep 1 > /dev/null \'
printf '%s\n' '          && docker cp scone-td-build-packages:/usr/local/bin/scone-td-build /tmp/scone-bin/ \'
printf '%s\n' '          || echo "ERROR: '\''scone-td-build'\'' not available in $SCONE_TD_BUILD_IMAGE"'
printf '%s\n' '        docker rm scone-td-build-packages > /dev/null 2>&1 || true'
printf '%s\n' '    else'
printf '%s\n' '        echo "ERROR: '\''scone-td-build'\'' not available in $REPO/$IMAGE:$SCONE_VERSION (set SCONE_TD_BUILD_IMAGE to an image that contains /usr/local/bin/scone-td-build)"'
printf '%s\n' '    fi'
printf '%s\n' '}'
printf '%s\n' '[[ -e /tmp/scone-bin/kubectl-scone ]] || docker cp scone-packages:/usr/local/bin/kubectl-scone /tmp/scone-bin/ 2>/dev/null || echo "ERROR: '\''kubectl scone'\'' not available"'
printf '%s\n' '[[ -e /tmp/scone-bin/kubectl-scone-azure ]] || docker cp scone-packages:/usr/local/bin/kubectl-scone-azure /tmp/scone-bin/ 2>/dev/null || echo "ERROR: '\''kubectl-scone-azure'\'' not available"'
printf '%s\n' ''
printf '%s\n' 'docker rm scone-packages'
printf '%s\n' ''
printf '%s\n' '# install the packages'
printf '%s\n' 'sudo dpkg -i /tmp/packages/scone-common_amd64.deb '
printf '%s\n' 'sudo dpkg -i /tmp/packages/scone-libc_amd64.deb '
printf '%s\n' 'sudo dpkg -i /tmp/packages/scone-cli_amd64.deb '
printf '%s\n' 'sudo dpkg -i "/tmp/$SCONE_GLIBC_DEB"'
printf '%s\n' ''
printf '%s\n' '# install binaries on host'
printf '%s\n' 'sudo install -m 0755 /tmp/scone-bin/scone-td-build /usr/local/bin/scone-td-build  || echo "ERROR: '\''scone-td-build'\'' not available"'
printf '%s\n' 'sudo install -m 0755 /tmp/scone-bin/kubectl-scone /usr/local/bin/kubectl-scone || echo "ERROR: '\''kubectl scone'\'' not available"'
printf '%s\n' 'sudo install -m 0755 /tmp/scone-bin/kubectl-scone-azure /usr/local/bin/kubectl-scone-azure  || echo "ERROR: '\''kubectl-scone-azure'\'' not available"'
printf '%s\n' ''
printf '%s\n' '# clean up'
printf '%s\n' 'rm -rf /tmp/packages'
printf '%s\n' 'rm -rf /tmp/scone-bin'
printf '%s\n' 'rm -f "/tmp/$SCONE_GLIBC_DEB"'
printf "${RESET}"

# copy Debian packages and required binaries
mkdir -p /tmp/packages
mkdir -p /tmp/scone-bin
docker cp scone-packages:/packages /tmp || {
    docker cp scone-packages:/scone-common_amd64.deb /tmp/packages;
    docker cp scone-packages:/scone-libc_amd64.deb /tmp/packages;
    docker cp scone-packages:/scone-cli_amd64.deb /tmp/packages;
    docker cp scone-packages:/scone-td-build.deb /tmp/scone-bin/;
    docker cp scone-packages:/kubectl-scone.deb /tmp/scone-bin/;
    docker cp scone-packages:/kubectl-scone-azure.deb /tmp/scone-bin/;
}

export SCONE_GLIBC_DEB=$(docker export scone-packages | tar -t | grep -i "glibc.*installer" | sort -V | tail -1 | xargs basename)
[[ -n "$SCONE_GLIBC_DEB" ]] || { echo "Failed to locate scone-glibc installer in $REPO/$IMAGE:$SCONE_VERSION"; exit 1; }
docker cp "scone-packages:/$SCONE_GLIBC_DEB" /tmp/

# scone-td-build and the kubectl plugins are not in every release's package image (e.g. 6.0.8).
[[ -e /tmp/scone-bin/scone-td-build ]] || docker cp scone-packages:/usr/local/bin/scone-td-build /tmp/scone-bin/ 2>/dev/null || {
    # Fall back to a separate scone-td-build image if one is configured.
    if [[ -n "${SCONE_TD_BUILD_IMAGE:-}" ]]; then
        docker rm scone-td-build-packages 2> /dev/null || true
        docker create --name scone-td-build-packages "$SCONE_TD_BUILD_IMAGE" sleep 1 > /dev/null \
          && docker cp scone-td-build-packages:/usr/local/bin/scone-td-build /tmp/scone-bin/ \
          || echo "ERROR: 'scone-td-build' not available in $SCONE_TD_BUILD_IMAGE"
        docker rm scone-td-build-packages > /dev/null 2>&1 || true
    else
        echo "ERROR: 'scone-td-build' not available in $REPO/$IMAGE:$SCONE_VERSION (set SCONE_TD_BUILD_IMAGE to an image that contains /usr/local/bin/scone-td-build)"
    fi
}
[[ -e /tmp/scone-bin/kubectl-scone ]] || docker cp scone-packages:/usr/local/bin/kubectl-scone /tmp/scone-bin/ 2>/dev/null || echo "ERROR: 'kubectl scone' not available"
[[ -e /tmp/scone-bin/kubectl-scone-azure ]] || docker cp scone-packages:/usr/local/bin/kubectl-scone-azure /tmp/scone-bin/ 2>/dev/null || echo "ERROR: 'kubectl-scone-azure' not available"

docker rm scone-packages

# install the packages
sudo dpkg -i /tmp/packages/scone-common_amd64.deb 
sudo dpkg -i /tmp/packages/scone-libc_amd64.deb 
sudo dpkg -i /tmp/packages/scone-cli_amd64.deb 
sudo dpkg -i "/tmp/$SCONE_GLIBC_DEB"

# install binaries on host
sudo install -m 0755 /tmp/scone-bin/scone-td-build /usr/local/bin/scone-td-build  || echo "ERROR: 'scone-td-build' not available"
sudo install -m 0755 /tmp/scone-bin/kubectl-scone /usr/local/bin/kubectl-scone || echo "ERROR: 'kubectl scone' not available"
sudo install -m 0755 /tmp/scone-bin/kubectl-scone-azure /usr/local/bin/kubectl-scone-azure  || echo "ERROR: 'kubectl-scone-azure' not available"

# clean up
rm -rf /tmp/packages
rm -rf /tmp/scone-bin
rm -f "/tmp/$SCONE_GLIBC_DEB"

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
printf '%s\n' 'Check that all required commands are properly installed by executing:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'echo "Expecting SCONE version: $SCONE_VERSION"'
printf '%s\n' 'MISSING_COMMANDS=""'
printf '%s\n' 'scone --version || MISSING_COMMANDS="$MISSING_COMMANDS scone"'
printf '%s\n' 'kubectl scone --help >/dev/null  || MISSING_COMMANDS="$MISSING_COMMANDS kubectl-scone"'
printf '%s\n' 'kubectl scone-azure --help >/dev/null || MISSING_COMMANDS="$MISSING_COMMANDS kubectl-scone-azure"'
printf '%s\n' 'scone-td-build --help >/dev/null  || MISSING_COMMANDS="$MISSING_COMMANDS scone-td-build"'
printf '%s\n' 'scone-td-build --version 2>/dev/null || true'
printf "${RESET}"

echo "Expecting SCONE version: $SCONE_VERSION"
MISSING_COMMANDS=""
scone --version || MISSING_COMMANDS="$MISSING_COMMANDS scone"
kubectl scone --help >/dev/null  || MISSING_COMMANDS="$MISSING_COMMANDS kubectl-scone"
kubectl scone-azure --help >/dev/null || MISSING_COMMANDS="$MISSING_COMMANDS kubectl-scone-azure"
scone-td-build --help >/dev/null  || MISSING_COMMANDS="$MISSING_COMMANDS scone-td-build"
scone-td-build --version 2>/dev/null || true

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'This should execute the same SCONE version as the previously printed latest stable version.'
printf '%s\n' 'The `--help` checks should also complete successfully. The `scone-td-build-demos` need'
printf '%s\n' '`scone-td-build` 0.4.0 or newer.'
printf '%s\n' ''
printf '%s\n' 'We stop with an error if any command is missing:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'if [[ -n "$MISSING_COMMANDS" ]]; then'
printf '%s\n' '  echo "❌ Missing SCONE commands:$MISSING_COMMANDS"'
printf '%s\n' '  exit 1'
printf '%s\n' 'fi'
printf '%s\n' 'echo "✅ All required SCONE commands installed"'
printf "${RESET}"

if [[ -n "$MISSING_COMMANDS" ]]; then
  echo "❌ Missing SCONE commands:$MISSING_COMMANDS"
  exit 1
fi
echo "✅ All required SCONE commands installed"

