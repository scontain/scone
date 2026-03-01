#!/usr/bin/env bash

set -Eeuo pipefail

TYPE_SPEED="${TYPE_SPEED:-25}"
PAUSE_AFTER_CMD="${PAUSE_AFTER_CMD:-0.6}"
SHELLRC="${SHELLRC:-/dev/null}"
PROMPT="${PROMPT:-$'\[\e[1;32m\]demo\[\e[0m\]:\[\e[1;34m\]~\[\e[0m\]\$ '}"
COLUMNS="${COLUMNS:-100}"
LINES="${LINES:-26}"
ORANGE="${ORANGE:-\033[38;5;208m}"
LILAC="${LILAC:-\033[38;5;141m}"
RESET="${RESET:-\033[0m}"

slow_type() {
  local text="$*"
  local delay
  delay=$(awk "BEGIN { print 1 / $TYPE_SPEED }")
  for ((i=0; i<${#text}; i++)); do
    printf "%s" "${text:i:1}"
    sleep "$delay"
  done
}

pe() {
  local cmd="$*"
  local display_cmd
  display_cmd=$(printf "%s" "$cmd" | sed 's/\$/\\$/g')
  printf "%b" "$ORANGE"
  slow_type "$display_cmd"
  printf "%b" "$RESET"
  printf "\n"

  if [[ -n "${PE_BUFFER:-}" ]]; then
    PE_BUFFER+=$'\n'
  fi
  PE_BUFFER+="$cmd"

  # Execute only when buffered lines form a complete shell command.
  if bash -n <(printf '%s\n' "$PE_BUFFER") 2>/dev/null; then
    eval "$PE_BUFFER"
    PE_BUFFER=""
  fi

  sleep "$PAUSE_AFTER_CMD"
}

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export COLUMNS LINES
export PS1="$PROMPT"
stty cols "$COLUMNS" rows "$LINES"

printf "%b" "$LILAC"
printf '%s\n' '# SCONE CLI'
printf '%s\n' ''
printf '%s\n' 'You can run the [`scone` CLI](https://sconedocs.github.io/CAS_cli/) on your **host machine**, within a **virtual machine (VM)**, or inside a **container**. While running it in a container offers good portability, it may suffer from slower startup times. Therefore, we recommend installing the `scone` CLI **directly on your development machine** for better performance.'
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
printf '%s\n' 'In case you want to use the values defined in the environment variables and file `Values.yaml`, please set:'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'In case the values of the environment variables need to confirmed by the user, set it to `--force`: '
printf '%s\n' ''
printf '%s\n' 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--force"'
printf '%s\n' ''
printf '%s\n' 'Let'\''s ask the user and set the environment variables depending on the input of the user:'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'The SCONE CLI is available as Debian packages as part of a container image. '
printf '%s\n' 'We first verify that the container image is properly signed by cosign.'
printf '%s\n' ''
printf '%s\n' 'To do so, we define the cosign public verification key using a function `create_cosign_verification_key`.'
printf '%s\n' 'We verify the signature of a given container image with function `verify_image`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe '#'
pe '# create a file with the public key of the signer key for all scone.cloud images'
pe '#'
pe ''
pe 'function create_cosign_verification_key() {'
pe '    export cosign_public_key_file="$(mktemp).pub"'
pe '    cat > $cosign_public_key_file <<EOF'
pe '-----BEGIN PUBLIC KEY-----'
pe 'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAErLf0HT8xZlLaoX5jNN8aVL1Yrs+P'
pe 'wS7K6tXeRlWLlUX1GeEtTdcuhZMKb5VUNaWEJW2ZU0YIF91D93dCZbUYpw=='
pe '-----END PUBLIC KEY-----'
pe 'EOF'
pe '}'
pe ''
pe 'function verify_image() {'
pe '    local image_name'
pe '    image_name="$1"'
pe '    if [[ "$image_name" == "" ]]; then'
pe '        echo "The name of the image for which we should verify the signature, was empty. Exiting."'
pe '        exit 1'
pe '    fi'
pe ''
pe '    echo "Verifying the signature of image '\''$image_name'\''"'
pe ''
pe '    docker pull "$image_name" >/dev/null'
pe '    export cosign_public_key_file=${cosign_public_key_file:-""}'
pe '    if [[ "$cosign_public_key_file" == "" ]]; then'
pe '        create_cosign_verification_key'
pe '    fi'
pe '    cosign verify --key "$cosign_public_key_file" "$image_name" >/dev/null 2> /dev/null || { echo "Failed to verify signature of image '\''$image_name'\''! Exiting! Please check that '\''cosign version'\'' shows a git version >= 2.0.0. Also ensure that there is no field '\''credsStore'\'' in '\''$HOME/.docker/config.json'\''"; exit 1; }'
pe ''
pe '    echo " - verification was successful"'
pe '}'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Next, we define the image that contains the `scone` CLI Debian package and'
printf '%s\n' 'verify the image:'
printf '%s\n' ''
printf "%b" "$RESET"

pe '# default repo and image name'
pe 'export REPO="$REGISTRY/scone.cloud"'
pe 'export IMAGE="scone-deb-pkgs"'
pe ''
pe 'verify_image "$REPO/$IMAGE:$SCONE_VERSION"'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'After successful verification, we create a temporary container'
printf '%s\n' 'to be able to copy the Debian packages to the local filesystem.'
printf '%s\n' ''
printf "%b" "$RESET"

pe '# ensure that container scone-packages does not exit'
pe 'docker rm scone-packages 2> /dev/null || true'
pe ''
pe '# run container such that we can copy the packages to a local repo'
pe 'docker create --name scone-packages "$REPO/$IMAGE:$SCONE_VERSION" sleep 1 > /dev/null'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Next, we copy the package to the `/tmp` directory and'
printf '%s\n' 'install the `scone` packages. '
printf '%s\n' ''
printf '%s\n' 'You will need to type your `sudo` password:'
printf '%s\n' ''
printf "%b" "$RESET"

pe '# copy the packages'
pe 'mkdir -p /tmp/packages'
pe 'docker cp scone-packages:/ /tmp/packages'
pe 'docker rm scone-packages'
pe ''
pe '# install the packages'
pe 'sudo dpkg -i /tmp/packages/scone-common_amd64.deb '
pe 'sudo dpkg -i /tmp/packages/scone-libc_amd64.deb '
pe 'sudo dpkg -i /tmp/packages/scone-cli_amd64.deb '
pe 'sudo dpkg -i /tmp/packages/k8s-scone.deb'
pe 'sudo dpkg -i /tmp/packages/kubectl-scone.deb '
pe ''
pe '# clean up'
pe 'rm -rf /tmp/packages'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'We ensure that `kubectl-scone` plugin only exists once - otherwise, `kubectl` issues a warning:'
printf '%s\n' ''
printf "%b" "$RESET"

pe ''
pe 'if [[ -e /usr/bin/kubectl-scone && -e /bin/kubectl-scone ]] ; then'
pe '    P1=$(realpath /usr/bin/kubectl-scone )'
pe '    P2=$(realpath /bin/kubectl-scone )'
pe '    if [[ -n "$P1" && -n "$P2" && "$P1" != "$P2" ]]; then'
pe '        rm -f "$P2"'
pe '    fi'
pe 'fi'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Check that the `scone` cli is properly installed by executing:'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'echo "Expecting SCONE version: $SCONE_VERSION"'
pe 'scone --version'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'This should execute the same SCONE version as the previously printed latest stable version.'
printf '%s\n' '(The minimal version is 6.0.0)'
printf '%s\n' ''
printf "%b" "$RESET"

pe '  echo "✅ All scone-related executable installed"'

