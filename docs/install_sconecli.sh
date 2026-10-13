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
printf "%b" "$RESET"

pe "$(cat <<'EOF'
eval $(tplenv --file environment-variables.md --create-values-file --eval --context ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'The core SCONE packages are available as Debian packages as part of a container image. We first verify that the container image is properly signed by cosign.'
printf '%s\n' ''
printf '%s\n' 'To do so, we define the cosign public verification key using a function `create_cosign_verification_key`. We verify the signature of a given container image with function `verify_image`:'
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
printf '%s\n' 'Next, we define the image that contains the core SCONE Debian packages and'
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
printf '%s\n' 'Next, inspect the package image archive and copy only the packages it contains.'
printf '%s\n' 'SCONE 6.x places Debian packages at the image root; SCONE 7.x may add more packages'
printf '%s\n' 'there. Some releases use a packages directory. This handles both layouts without'
printf '%s\n' 'assuming that a fixed set of files exists.'
printf '%s\n' ''
printf '%s\n' 'The extracted files go in a unique temporary directory, so existing files in /tmp'
printf '%s\n' 'are left alone. The temporary container and directory are removed when the script'
printf '%s\n' 'exits.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
INSTALL_WORK="$(mktemp -d /tmp/scone-install.XXXXXXXX)"
EOF
)"
pe "$(cat <<'EOF'
SCONE_PACKAGE_CONTAINER="scone-packages-$$-$RANDOM"
EOF
)"
pe "$(cat <<'EOF'
SCONE_PACKAGE_CONTAINER_CREATED=false
EOF
)"
pe "$(cat <<'EOF'
SCONE_TD_BUILD_IMAGE="$(printenv SCONE_TD_BUILD_IMAGE || true)"
EOF
)"
pe "$(cat <<'EOF'
SCONE_TD_BUILD_CONTAINER=""
EOF
)"
pe "$(cat <<'EOF'
cleanup_scone_package_install() {
EOF
)"
pe "$(cat <<'EOF'
    if [[ -n "$SCONE_TD_BUILD_CONTAINER" ]]; then
EOF
)"
pe "$(cat <<'EOF'
        docker rm "$SCONE_TD_BUILD_CONTAINER" >/dev/null 2>&1 || true
EOF
)"
pe "$(cat <<'EOF'
    fi
EOF
)"
pe "$(cat <<'EOF'
    if [[ "$SCONE_PACKAGE_CONTAINER_CREATED" == true ]]; then
EOF
)"
pe "$(cat <<'EOF'
        docker rm "$SCONE_PACKAGE_CONTAINER" >/dev/null 2>&1 || true
EOF
)"
pe "$(cat <<'EOF'
    fi
EOF
)"
pe "$(cat <<'EOF'
    rm -rf "$INSTALL_WORK"
EOF
)"
pe "$(cat <<'EOF'
}
EOF
)"
pe "$(cat <<'EOF'
trap cleanup_scone_package_install EXIT
EOF
)"
pe "$(cat <<'EOF'
mkdir -p "$INSTALL_WORK/packages" "$INSTALL_WORK/bin"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
docker create --name "$SCONE_PACKAGE_CONTAINER" "$REPO/$IMAGE:$SCONE_VERSION" sleep 1 >/dev/null
EOF
)"
pe "$(cat <<'EOF'
SCONE_PACKAGE_CONTAINER_CREATED=true
EOF
)"
pe "$(cat <<'EOF'
docker export "$SCONE_PACKAGE_CONTAINER" | tar -tf - > "$INSTALL_WORK/image-files.txt"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
while IFS= read -r archive_path; do
EOF
)"
pe "$(cat <<'EOF'
    package_path="$archive_path"
EOF
)"
pe "$(cat <<'EOF'
    if [[ "$package_path" == ./* ]]; then
EOF
)"
pe "$(cat <<'EOF'
        package_path="${package_path#./}"
EOF
)"
pe "$(cat <<'EOF'
    fi
EOF
)"
pe "$(cat <<'EOF'
    package_name="${package_path##*/}"
EOF
)"
pe "$(cat <<'EOF'
    case "$package_name" in
EOF
)"
pe "$(cat <<'EOF'
        scone-common_*.deb|scone-libc_*.deb|scone-cli_*.deb|scone-glibc-*-installer_*.deb|scone-td-build*.deb|kubectl-scone*.deb|k8s-scone*.deb)
EOF
)"
pe "$(cat <<'EOF'
            case "$package_path" in
EOF
)"
pe "$(cat <<'EOF'
                packages/*|scone*.deb|kubectl*.deb|k8s-scone*.deb) ;;
EOF
)"
pe "$(cat <<'EOF'
                *) continue ;;
EOF
)"
pe "$(cat <<'EOF'
            esac
EOF
)"
pe "$(cat <<'EOF'
            if [[ ! -e "$INSTALL_WORK/packages/$package_name" ]]; then
EOF
)"
pe "$(cat <<'EOF'
                docker cp "$SCONE_PACKAGE_CONTAINER:/$package_path" "$INSTALL_WORK/packages/$package_name"
EOF
)"
pe "$(cat <<'EOF'
            fi
EOF
)"
pe "$(cat <<'EOF'
            ;;
EOF
)"
pe "$(cat <<'EOF'
    esac
EOF
)"
pe "$(cat <<'EOF'
done < "$INSTALL_WORK/image-files.txt"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
for package_prefix in scone-common scone-libc scone-cli; do
EOF
)"
pe "$(cat <<'EOF'
    if ! compgen -G "$INSTALL_WORK/packages/$package_prefix"_*.deb >/dev/null; then
EOF
)"
pe "$(cat <<'EOF'
        echo "Missing $package_prefix Debian package in $REPO/$IMAGE:$SCONE_VERSION" >&2
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
done
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
SCONE_GLIBC_DEB="$(find "$INSTALL_WORK/packages" -maxdepth 1 -type f -name '*glibc*installer*.deb' -printf '%f\n' | sort -V | tail -n 1)"
EOF
)"
pe "$(cat <<'EOF'
if [[ -z "$SCONE_GLIBC_DEB" ]]; then
EOF
)"
pe "$(cat <<'EOF'
    echo "Failed to locate a scone-glibc installer in $REPO/$IMAGE:$SCONE_VERSION" >&2
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
for tool in scone-td-build kubectl-scone kubectl-scone-azure; do
EOF
)"
pe "$(cat <<'EOF'
    if grep -Fqx "usr/local/bin/$tool" "$INSTALL_WORK/image-files.txt"; then
EOF
)"
pe "$(cat <<'EOF'
        docker cp "$SCONE_PACKAGE_CONTAINER:/usr/local/bin/$tool" "$INSTALL_WORK/bin/$tool"
EOF
)"
pe "$(cat <<'EOF'
    fi
EOF
)"
pe "$(cat <<'EOF'
done
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Install the core packages. This requires sudo access.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
sudo dpkg -i "$INSTALL_WORK/packages"/scone-common_*.deb
EOF
)"
pe "$(cat <<'EOF'
sudo dpkg -i "$INSTALL_WORK/packages"/scone-libc_*.deb
EOF
)"
pe "$(cat <<'EOF'
sudo dpkg -i "$INSTALL_WORK/packages"/scone-cli_*.deb
EOF
)"
pe "$(cat <<'EOF'
sudo dpkg -i "$INSTALL_WORK/packages/$SCONE_GLIBC_DEB"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Some releases do not include scone-td-build or the kubectl plugins. Keep the'
printf '%s\n' 'optional binary and SCONE_TD_BUILD_IMAGE fallback for those releases.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
if [[ ! -e "$INSTALL_WORK/bin/scone-td-build" ]]; then
EOF
)"
pe "$(cat <<'EOF'
    if docker cp "$SCONE_PACKAGE_CONTAINER:/usr/local/bin/scone-td-build" "$INSTALL_WORK/bin/" 2>/dev/null; then
EOF
)"
pe "$(cat <<'EOF'
        :
EOF
)"
pe "$(cat <<'EOF'
    elif [[ -n "$SCONE_TD_BUILD_IMAGE" ]]; then
EOF
)"
pe "$(cat <<'EOF'
        verify_image "$SCONE_TD_BUILD_IMAGE"
EOF
)"
pe "$(cat <<'EOF'
        SCONE_TD_BUILD_CONTAINER="scone-td-build-packages-$$-$RANDOM"
EOF
)"
pe "$(cat <<'EOF'
        docker create --name "$SCONE_TD_BUILD_CONTAINER" "$SCONE_TD_BUILD_IMAGE" sleep 1 >/dev/null
EOF
)"
pe "$(cat <<'EOF'
        if ! docker cp "$SCONE_TD_BUILD_CONTAINER:/usr/local/bin/scone-td-build" "$INSTALL_WORK/bin/"; then
EOF
)"
pe "$(cat <<'EOF'
            docker rm "$SCONE_TD_BUILD_CONTAINER" >/dev/null 2>&1 || true
EOF
)"
pe "$(cat <<'EOF'
            echo "ERROR: scone-td-build not available in $SCONE_TD_BUILD_IMAGE" >&2
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
        docker rm "$SCONE_TD_BUILD_CONTAINER" >/dev/null
EOF
)"
pe "$(cat <<'EOF'
        SCONE_TD_BUILD_CONTAINER=""
EOF
)"
pe "$(cat <<'EOF'
    else
EOF
)"
pe "$(cat <<'EOF'
        echo "ERROR: scone-td-build not available in $REPO/$IMAGE:$SCONE_VERSION (set SCONE_TD_BUILD_IMAGE to an image containing /usr/local/bin/scone-td-build)" >&2
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
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
for tool in kubectl-scone kubectl-scone-azure; do
EOF
)"
pe "$(cat <<'EOF'
    if [[ ! -e "$INSTALL_WORK/bin/$tool" ]]; then
EOF
)"
pe "$(cat <<'EOF'
        docker cp "$SCONE_PACKAGE_CONTAINER:/usr/local/bin/$tool" "$INSTALL_WORK/bin/$tool" 2>/dev/null || echo "ERROR: $tool not available"
EOF
)"
pe "$(cat <<'EOF'
    fi
EOF
)"
pe "$(cat <<'EOF'
done
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
sudo install -m 0755 "$INSTALL_WORK/bin/scone-td-build" /usr/local/bin/scone-td-build || echo "ERROR: scone-td-build not available"
EOF
)"
pe "$(cat <<'EOF'
sudo install -m 0755 "$INSTALL_WORK/bin/kubectl-scone" /usr/local/bin/kubectl-scone || echo "ERROR: kubectl scone not available"
EOF
)"
pe "$(cat <<'EOF'
sudo install -m 0755 "$INSTALL_WORK/bin/kubectl-scone-azure" /usr/local/bin/kubectl-scone-azure || echo "ERROR: kubectl-scone-azure not available"
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
printf '%s\n' 'Validate the tools that the shell actually selects through `PATH`. This catches'
printf '%s\n' 'older Cargo binaries shadowing newly installed system packages, as well as newer'
printf '%s\n' 'plugins that expect a different CAS schema.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Validate the tools selected by PATH.
EOF
)"
pe "$(cat <<'EOF'
SCONE_VERSION="$SCONE_VERSION" ./scripts/check-scone-tooling.sh
EOF
)"
pe "$(cat <<'EOF'
echo "✅ All required SCONE commands installed and compatible with the workshop version requirements"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'The checker requires `scone` and `kubectl-scone` to match the major/minor release'
printf '%s\n' 'line of `SCONE_VERSION`; patch versions may differ. A stable target rejects'
printf '%s\n' 'prerelease tools. The demos require a stable `scone-td-build` version of at least'
printf '%s\n' '0.4.0 and the `apply -f scone.yaml` interface. Workshop revision `b607bdc` supports'
printf '%s\n' 'the current `cas-endpoint` templates. The checker also exercises the kubectl'
printf '%s\n' 'plugins'\'' help commands. Any failure stops installation before the success message'
printf '%s\n' 'and lists executable paths to help identify shadowed installations.'
printf '%s\n' ''
printf '%s\n' 'To repeat these checks without installing packages, run this from the repository:'
printf '%s\n' ''
printf '%s\n' 'SCONE_VERSION=6.0.8 ./scripts/check-scone-tooling.sh'
printf '%s\n' ''
printf '%s\n' 'Without `SCONE_VERSION`, the standalone checker uses `stable.txt`. Set the target'
printf '%s\n' 'to the release used by your operator. These are local version and command checks;'
printf '%s\n' 'they do not contact Kubernetes or verify CAS connectivity or attestation.'
printf "%b" "$RESET"

