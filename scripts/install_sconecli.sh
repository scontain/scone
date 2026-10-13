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
printf '%s\n' 'Next, inspect the package image archive and copy only the packages it contains.'
printf '%s\n' 'SCONE 6.x places Debian packages at the image root; SCONE 7.x may add more packages'
printf '%s\n' 'there. Some releases use a packages directory. This handles both layouts without'
printf '%s\n' 'assuming that a fixed set of files exists.'
printf '%s\n' ''
printf '%s\n' 'The extracted files go in a unique temporary directory, so existing files in /tmp'
printf '%s\n' 'are left alone. The temporary container and directory are removed when the script'
printf '%s\n' 'exits.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'INSTALL_WORK="$(mktemp -d /tmp/scone-install.XXXXXXXX)"'
printf '%s\n' 'SCONE_PACKAGE_CONTAINER="scone-packages-$$-$RANDOM"'
printf '%s\n' 'SCONE_PACKAGE_CONTAINER_CREATED=false'
printf '%s\n' 'SCONE_TD_BUILD_IMAGE="$(printenv SCONE_TD_BUILD_IMAGE || true)"'
printf '%s\n' 'SCONE_TD_BUILD_CONTAINER=""'
printf '%s\n' 'cleanup_scone_package_install() {'
printf '%s\n' '    if [[ -n "$SCONE_TD_BUILD_CONTAINER" ]]; then'
printf '%s\n' '        docker rm "$SCONE_TD_BUILD_CONTAINER" >/dev/null 2>&1 || true'
printf '%s\n' '    fi'
printf '%s\n' '    if [[ "$SCONE_PACKAGE_CONTAINER_CREATED" == true ]]; then'
printf '%s\n' '        docker rm "$SCONE_PACKAGE_CONTAINER" >/dev/null 2>&1 || true'
printf '%s\n' '    fi'
printf '%s\n' '    rm -rf "$INSTALL_WORK"'
printf '%s\n' '}'
printf '%s\n' 'trap cleanup_scone_package_install EXIT'
printf '%s\n' 'mkdir -p "$INSTALL_WORK/packages" "$INSTALL_WORK/bin"'
printf '%s\n' ''
printf '%s\n' 'docker create --name "$SCONE_PACKAGE_CONTAINER" "$REPO/$IMAGE:$SCONE_VERSION" sleep 1 >/dev/null'
printf '%s\n' 'SCONE_PACKAGE_CONTAINER_CREATED=true'
printf '%s\n' 'docker export "$SCONE_PACKAGE_CONTAINER" | tar -tf - > "$INSTALL_WORK/image-files.txt"'
printf '%s\n' ''
printf '%s\n' 'while IFS= read -r archive_path; do'
printf '%s\n' '    package_path="$archive_path"'
printf '%s\n' '    if [[ "$package_path" == ./* ]]; then'
printf '%s\n' '        package_path="${package_path#./}"'
printf '%s\n' '    fi'
printf '%s\n' '    package_name="${package_path##*/}"'
printf '%s\n' '    case "$package_name" in'
printf '%s\n' '        scone-common_*.deb|scone-libc_*.deb|scone-cli_*.deb|scone-glibc-*-installer_*.deb|scone-td-build*.deb|kubectl-scone*.deb|k8s-scone*.deb)'
printf '%s\n' '            case "$package_path" in'
printf '%s\n' '                packages/*|scone*.deb|kubectl*.deb|k8s-scone*.deb) ;;'
printf '%s\n' '                *) continue ;;'
printf '%s\n' '            esac'
printf '%s\n' '            if [[ ! -e "$INSTALL_WORK/packages/$package_name" ]]; then'
printf '%s\n' '                docker cp "$SCONE_PACKAGE_CONTAINER:/$package_path" "$INSTALL_WORK/packages/$package_name"'
printf '%s\n' '            fi'
printf '%s\n' '            ;;'
printf '%s\n' '    esac'
printf '%s\n' 'done < "$INSTALL_WORK/image-files.txt"'
printf '%s\n' ''
printf '%s\n' 'for package_prefix in scone-common scone-libc scone-cli; do'
printf '%s\n' '    if ! compgen -G "$INSTALL_WORK/packages/$package_prefix"_*.deb >/dev/null; then'
printf '%s\n' '        echo "Missing $package_prefix Debian package in $REPO/$IMAGE:$SCONE_VERSION" >&2'
printf '%s\n' '        exit 1'
printf '%s\n' '    fi'
printf '%s\n' 'done'
printf '%s\n' ''
printf '%s\n' 'SCONE_GLIBC_DEB="$(find "$INSTALL_WORK/packages" -maxdepth 1 -type f -name '\''*glibc*installer*.deb'\'' -printf '\''%f\n'\'' | sort -V | tail -n 1)"'
printf '%s\n' 'if [[ -z "$SCONE_GLIBC_DEB" ]]; then'
printf '%s\n' '    echo "Failed to locate a scone-glibc installer in $REPO/$IMAGE:$SCONE_VERSION" >&2'
printf '%s\n' '    exit 1'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' 'for tool in scone-td-build kubectl-scone kubectl-scone-azure; do'
printf '%s\n' '    if grep -Fqx "usr/local/bin/$tool" "$INSTALL_WORK/image-files.txt"; then'
printf '%s\n' '        docker cp "$SCONE_PACKAGE_CONTAINER:/usr/local/bin/$tool" "$INSTALL_WORK/bin/$tool"'
printf '%s\n' '    fi'
printf '%s\n' 'done'
printf "${RESET}"

INSTALL_WORK="$(mktemp -d /tmp/scone-install.XXXXXXXX)"
SCONE_PACKAGE_CONTAINER="scone-packages-$$-$RANDOM"
SCONE_PACKAGE_CONTAINER_CREATED=false
SCONE_TD_BUILD_IMAGE="$(printenv SCONE_TD_BUILD_IMAGE || true)"
SCONE_TD_BUILD_CONTAINER=""
cleanup_scone_package_install() {
    if [[ -n "$SCONE_TD_BUILD_CONTAINER" ]]; then
        docker rm "$SCONE_TD_BUILD_CONTAINER" >/dev/null 2>&1 || true
    fi
    if [[ "$SCONE_PACKAGE_CONTAINER_CREATED" == true ]]; then
        docker rm "$SCONE_PACKAGE_CONTAINER" >/dev/null 2>&1 || true
    fi
    rm -rf "$INSTALL_WORK"
}
trap cleanup_scone_package_install EXIT
mkdir -p "$INSTALL_WORK/packages" "$INSTALL_WORK/bin"

docker create --name "$SCONE_PACKAGE_CONTAINER" "$REPO/$IMAGE:$SCONE_VERSION" sleep 1 >/dev/null
SCONE_PACKAGE_CONTAINER_CREATED=true
docker export "$SCONE_PACKAGE_CONTAINER" | tar -tf - > "$INSTALL_WORK/image-files.txt"

while IFS= read -r archive_path; do
    package_path="$archive_path"
    if [[ "$package_path" == ./* ]]; then
        package_path="${package_path#./}"
    fi
    package_name="${package_path##*/}"
    case "$package_name" in
        scone-common_*.deb|scone-libc_*.deb|scone-cli_*.deb|scone-glibc-*-installer_*.deb|scone-td-build*.deb|kubectl-scone*.deb|k8s-scone*.deb)
            case "$package_path" in
                packages/*|scone*.deb|kubectl*.deb|k8s-scone*.deb) ;;
                *) continue ;;
            esac
            if [[ ! -e "$INSTALL_WORK/packages/$package_name" ]]; then
                docker cp "$SCONE_PACKAGE_CONTAINER:/$package_path" "$INSTALL_WORK/packages/$package_name"
            fi
            ;;
    esac
done < "$INSTALL_WORK/image-files.txt"

for package_prefix in scone-common scone-libc scone-cli; do
    if ! compgen -G "$INSTALL_WORK/packages/$package_prefix"_*.deb >/dev/null; then
        echo "Missing $package_prefix Debian package in $REPO/$IMAGE:$SCONE_VERSION" >&2
        exit 1
    fi
done

SCONE_GLIBC_DEB="$(find "$INSTALL_WORK/packages" -maxdepth 1 -type f -name '*glibc*installer*.deb' -printf '%f\n' | sort -V | tail -n 1)"
if [[ -z "$SCONE_GLIBC_DEB" ]]; then
    echo "Failed to locate a scone-glibc installer in $REPO/$IMAGE:$SCONE_VERSION" >&2
    exit 1
fi

for tool in scone-td-build kubectl-scone kubectl-scone-azure; do
    if grep -Fqx "usr/local/bin/$tool" "$INSTALL_WORK/image-files.txt"; then
        docker cp "$SCONE_PACKAGE_CONTAINER:/usr/local/bin/$tool" "$INSTALL_WORK/bin/$tool"
    fi
done

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Install the core packages. This requires sudo access.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'sudo dpkg -i "$INSTALL_WORK/packages"/scone-common_*.deb'
printf '%s\n' 'sudo dpkg -i "$INSTALL_WORK/packages"/scone-libc_*.deb'
printf '%s\n' 'sudo dpkg -i "$INSTALL_WORK/packages"/scone-cli_*.deb'
printf '%s\n' 'sudo dpkg -i "$INSTALL_WORK/packages/$SCONE_GLIBC_DEB"'
printf "${RESET}"

sudo dpkg -i "$INSTALL_WORK/packages"/scone-common_*.deb
sudo dpkg -i "$INSTALL_WORK/packages"/scone-libc_*.deb
sudo dpkg -i "$INSTALL_WORK/packages"/scone-cli_*.deb
sudo dpkg -i "$INSTALL_WORK/packages/$SCONE_GLIBC_DEB"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Some releases do not include scone-td-build or the kubectl plugins. Keep the'
printf '%s\n' 'optional binary and SCONE_TD_BUILD_IMAGE fallback for those releases.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'if [[ ! -e "$INSTALL_WORK/bin/scone-td-build" ]]; then'
printf '%s\n' '    if docker cp "$SCONE_PACKAGE_CONTAINER:/usr/local/bin/scone-td-build" "$INSTALL_WORK/bin/" 2>/dev/null; then'
printf '%s\n' '        :'
printf '%s\n' '    elif [[ -n "$SCONE_TD_BUILD_IMAGE" ]]; then'
printf '%s\n' '        verify_image "$SCONE_TD_BUILD_IMAGE"'
printf '%s\n' '        SCONE_TD_BUILD_CONTAINER="scone-td-build-packages-$$-$RANDOM"'
printf '%s\n' '        docker create --name "$SCONE_TD_BUILD_CONTAINER" "$SCONE_TD_BUILD_IMAGE" sleep 1 >/dev/null'
printf '%s\n' '        if ! docker cp "$SCONE_TD_BUILD_CONTAINER:/usr/local/bin/scone-td-build" "$INSTALL_WORK/bin/"; then'
printf '%s\n' '            docker rm "$SCONE_TD_BUILD_CONTAINER" >/dev/null 2>&1 || true'
printf '%s\n' '            echo "ERROR: scone-td-build not available in $SCONE_TD_BUILD_IMAGE" >&2'
printf '%s\n' '            exit 1'
printf '%s\n' '        fi'
printf '%s\n' '        docker rm "$SCONE_TD_BUILD_CONTAINER" >/dev/null'
printf '%s\n' '        SCONE_TD_BUILD_CONTAINER=""'
printf '%s\n' '    else'
printf '%s\n' '        echo "ERROR: scone-td-build not available in $REPO/$IMAGE:$SCONE_VERSION (set SCONE_TD_BUILD_IMAGE to an image containing /usr/local/bin/scone-td-build)" >&2'
printf '%s\n' '    fi'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' 'for tool in kubectl-scone kubectl-scone-azure; do'
printf '%s\n' '    if [[ ! -e "$INSTALL_WORK/bin/$tool" ]]; then'
printf '%s\n' '        docker cp "$SCONE_PACKAGE_CONTAINER:/usr/local/bin/$tool" "$INSTALL_WORK/bin/$tool" 2>/dev/null || echo "ERROR: $tool not available"'
printf '%s\n' '    fi'
printf '%s\n' 'done'
printf '%s\n' ''
printf '%s\n' 'sudo install -m 0755 "$INSTALL_WORK/bin/scone-td-build" /usr/local/bin/scone-td-build || echo "ERROR: scone-td-build not available"'
printf '%s\n' 'sudo install -m 0755 "$INSTALL_WORK/bin/kubectl-scone" /usr/local/bin/kubectl-scone || echo "ERROR: kubectl scone not available"'
printf '%s\n' 'sudo install -m 0755 "$INSTALL_WORK/bin/kubectl-scone-azure" /usr/local/bin/kubectl-scone-azure || echo "ERROR: kubectl-scone-azure not available"'
printf "${RESET}"

if [[ ! -e "$INSTALL_WORK/bin/scone-td-build" ]]; then
    if docker cp "$SCONE_PACKAGE_CONTAINER:/usr/local/bin/scone-td-build" "$INSTALL_WORK/bin/" 2>/dev/null; then
        :
    elif [[ -n "$SCONE_TD_BUILD_IMAGE" ]]; then
        verify_image "$SCONE_TD_BUILD_IMAGE"
        SCONE_TD_BUILD_CONTAINER="scone-td-build-packages-$$-$RANDOM"
        docker create --name "$SCONE_TD_BUILD_CONTAINER" "$SCONE_TD_BUILD_IMAGE" sleep 1 >/dev/null
        if ! docker cp "$SCONE_TD_BUILD_CONTAINER:/usr/local/bin/scone-td-build" "$INSTALL_WORK/bin/"; then
            docker rm "$SCONE_TD_BUILD_CONTAINER" >/dev/null 2>&1 || true
            echo "ERROR: scone-td-build not available in $SCONE_TD_BUILD_IMAGE" >&2
            exit 1
        fi
        docker rm "$SCONE_TD_BUILD_CONTAINER" >/dev/null
        SCONE_TD_BUILD_CONTAINER=""
    else
        echo "ERROR: scone-td-build not available in $REPO/$IMAGE:$SCONE_VERSION (set SCONE_TD_BUILD_IMAGE to an image containing /usr/local/bin/scone-td-build)" >&2
    fi
fi

for tool in kubectl-scone kubectl-scone-azure; do
    if [[ ! -e "$INSTALL_WORK/bin/$tool" ]]; then
        docker cp "$SCONE_PACKAGE_CONTAINER:/usr/local/bin/$tool" "$INSTALL_WORK/bin/$tool" 2>/dev/null || echo "ERROR: $tool not available"
    fi
done

sudo install -m 0755 "$INSTALL_WORK/bin/scone-td-build" /usr/local/bin/scone-td-build || echo "ERROR: scone-td-build not available"
sudo install -m 0755 "$INSTALL_WORK/bin/kubectl-scone" /usr/local/bin/kubectl-scone || echo "ERROR: kubectl scone not available"
sudo install -m 0755 "$INSTALL_WORK/bin/kubectl-scone-azure" /usr/local/bin/kubectl-scone-azure || echo "ERROR: kubectl-scone-azure not available"

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
printf '%s\n' 'Validate the tools that the shell actually selects through `PATH`. This catches'
printf '%s\n' 'older Cargo binaries shadowing newly installed system packages, as well as newer'
printf '%s\n' 'plugins that expect a different CAS schema.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Validate the tools selected by PATH.'
printf '%s\n' 'SCONE_VERSION="$SCONE_VERSION" ./scripts/check-scone-tooling.sh'
printf '%s\n' 'echo "✅ All required SCONE commands installed and compatible with the workshop version requirements"'
printf "${RESET}"

# Validate the tools selected by PATH.
SCONE_VERSION="$SCONE_VERSION" ./scripts/check-scone-tooling.sh
echo "✅ All required SCONE commands installed and compatible with the workshop version requirements"

printf "${VIOLET}"
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
printf "${RESET}"

