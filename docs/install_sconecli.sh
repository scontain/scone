#!/usr/bin/env bash

set -Eeuo pipefail
export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""

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
  printf "%b" "$ORANGE"
  slow_type "$cmd"
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
printf "%b" "$RESET"

pe "$(cat <<'EOF'
eval $(tplenv --file environment-variables.md --create-values-file --eval --context ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'The SCONE CLI is available as Debian packages as part of a container image. '
printf '%s\n' 'We first verify that the container image is properly signed by cosign.'
printf '%s\n' ''
printf '%s\n' 'To do so, we define the cosign public verification key using a function `create_cosign_verification_key`.'
printf '%s\n' 'We verify the signature of a given container image with function `verify_image`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
#
EOF
)"
pe "$(cat <<'EOF'
# create a file with the public key of the signer key for all scone.cloud images
EOF
)"
pe "$(cat <<'EOF'
#
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
function create_cosign_verification_key() {
EOF
)"
pe "$(cat <<'EOF'
    export cosign_public_key_file="$(mktemp).pub"
EOF
)"
pe "$(cat <<'EOF'
    cat > $cosign_public_key_file <<SEOF
EOF
)"
pe "$(cat <<'EOF'
-----BEGIN PUBLIC KEY-----
EOF
)"
pe "$(cat <<'EOF'
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAErLf0HT8xZlLaoX5jNN8aVL1Yrs+P
EOF
)"
pe "$(cat <<'EOF'
wS7K6tXeRlWLlUX1GeEtTdcuhZMKb5VUNaWEJW2ZU0YIF91D93dCZbUYpw==
EOF
)"
pe "$(cat <<'EOF'
-----END PUBLIC KEY-----
EOF
)"
pe "$(cat <<'EOF'
SEOF
EOF
)"
pe "$(cat <<'EOF'
}
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
function verify_image() {
EOF
)"
pe "$(cat <<'EOF'
    local image_name
EOF
)"
pe "$(cat <<'EOF'
    image_name="$1"
EOF
)"
pe "$(cat <<'EOF'
    if [[ "$image_name" == "" ]]; then
EOF
)"
pe "$(cat <<'EOF'
        echo "The name of the image for which we should verify the signature, was empty. Exiting."
EOF
)"
pe "$(cat <<'EOF'
        exit 1
EOF
)"
pe "$(cat <<'EOF'
    fi
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
    echo "Verifying the signature of image '$image_name'"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
    docker pull "$image_name" >/dev/null
EOF
)"
pe "$(cat <<'EOF'
    export cosign_public_key_file=${cosign_public_key_file:-""}
EOF
)"
pe "$(cat <<'EOF'
    if [[ "$cosign_public_key_file" == "" ]]; then
EOF
)"
pe "$(cat <<'EOF'
        create_cosign_verification_key
EOF
)"
pe "$(cat <<'EOF'
    fi
EOF
)"
pe "$(cat <<'EOF'
    cosign verify --key "$cosign_public_key_file" "$image_name" >/dev/null 2> /dev/null || { echo "Failed to verify signature of image '$image_name'! Exiting! Please check that 'cosign version' shows a git version >= 2.0.0. Also ensure that there is no field 'credsStore' in '$HOME/.docker/config.json'"; exit 1; }
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
    echo " - verification was successful"
EOF
)"
pe "$(cat <<'EOF'
}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Next, we define the image that contains the `scone` CLI Debian package and'
printf '%s\n' 'verify the image:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# default repo and image name
EOF
)"
pe "$(cat <<'EOF'
export REPO="$REGISTRY/scone.cloud"
EOF
)"
pe "$(cat <<'EOF'
export IMAGE="scone-deb-pkgs"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
verify_image "$REPO/$IMAGE:$SCONE_VERSION"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'After successful verification, we create a temporary container'
printf '%s\n' 'to be able to copy the Debian packages to the local filesystem.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# ensure that container scone-packages does not exit
EOF
)"
pe "$(cat <<'EOF'
docker rm scone-packages 2> /dev/null || true
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# run container such that we can copy the packages to a local repo
EOF
)"
pe "$(cat <<'EOF'
docker create --name scone-packages "$REPO/$IMAGE:$SCONE_VERSION" sleep 1 > /dev/null
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Next, we copy the package to the `/tmp` directory and'
printf '%s\n' 'install the `scone` packages. '
printf '%s\n' ''
printf '%s\n' 'You will need to type your `sudo` password:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# copy the packages
EOF
)"
pe "$(cat <<'EOF'
mkdir -p /tmp/packages
EOF
)"
pe "$(cat <<'EOF'
docker cp scone-packages:/packages /tmp || {
EOF
)"
pe "$(cat <<'EOF'
    docker cp scone-packages:/scone-common_amd64.deb /tmp/packages;
EOF
)"
pe "$(cat <<'EOF'
    docker cp scone-packages:/scone-libc_amd64.deb /tmp/packages;
EOF
)"
pe "$(cat <<'EOF'
    docker cp scone-packages:/scone-cli_amd64.deb /tmp/packages;
EOF
)"
pe "$(cat <<'EOF'
    docker cp scone-packages:/k8s-scone.deb /tmp/packages;
EOF
)"
pe "$(cat <<'EOF'
    docker cp scone-packages:/kubectl-scone.deb /tmp/packages;
EOF
)"
pe "$(cat <<'EOF'
}
EOF
)"
pe "$(cat <<'EOF'
docker rm scone-packages
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# install the packages
EOF
)"
pe "$(cat <<'EOF'
sudo dpkg -i /tmp/packages/scone-common_amd64.deb 
EOF
)"
pe "$(cat <<'EOF'
sudo dpkg -i /tmp/packages/scone-libc_amd64.deb 
EOF
)"
pe "$(cat <<'EOF'
sudo dpkg -i /tmp/packages/scone-cli_amd64.deb 
EOF
)"
pe "$(cat <<'EOF'
sudo dpkg -i /tmp/packages/k8s-scone.deb
EOF
)"
pe "$(cat <<'EOF'
sudo dpkg -i /tmp/packages/kubectl-scone.deb 
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# clean up
EOF
)"
pe "$(cat <<'EOF'
rm -rf /tmp/packages
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'We ensure that `kubectl-scone` plugin only exists once - otherwise, `kubectl` issues a warning:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
if [[ -e /usr/bin/kubectl-scone && -e /bin/kubectl-scone ]] ; then
EOF
)"
pe "$(cat <<'EOF'
    P1=$(realpath /usr/bin/kubectl-scone )
EOF
)"
pe "$(cat <<'EOF'
    P2=$(realpath /bin/kubectl-scone )
EOF
)"
pe "$(cat <<'EOF'
    if [[ -n "$P1" && -n "$P2" && "$P1" != "$P2" ]]; then
EOF
)"
pe "$(cat <<'EOF'
        rm -f "$P2"
EOF
)"
pe "$(cat <<'EOF'
    fi
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Check that the `scone` cli is properly installed by executing:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
echo "Expecting SCONE version: $SCONE_VERSION"
EOF
)"
pe "$(cat <<'EOF'
scone --version
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'This should execute the same SCONE version as the previously printed latest stable version.'
printf '%s\n' '(The minimal version is 6.0.0)'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
  echo "✅ All scone-related executable installed"
EOF
)"

