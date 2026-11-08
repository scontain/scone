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
printf '%s\n' 'To do so, we define the cosign public verification key using a function `create_cosign_verification_key`. We verify the signature of a given container image with function `verify_image`, which needs cosign 2.0.0 or newer (`COSIGN_MIN_VERSION`):'
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
# cosign >= 2.0.0 verifies the SCONE package images. Images signed with cosign 3.x in its
EOF
)"
pe "$(cat <<'EOF'
# bundle format, such as the workshop image built by ./scripts/build.sh, need cosign >= 3.0.0.
EOF
)"
pe "$(cat <<'EOF'
COSIGN_MIN_VERSION="${COSIGN_MIN_VERSION:-2.0.0}"
EOF
)"
pe "$(cat <<'EOF'
COSIGN_BUNDLE_MIN_VERSION="${COSIGN_BUNDLE_MIN_VERSION:-3.0.0}"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Prints the version of the installed cosign (e.g., 2.4.1), or nothing if unknown.
EOF
)"
pe "$(cat <<'EOF'
function cosign_version() {
EOF
)"
pe "$(cat <<'EOF'
    cosign version 2>/dev/null | grep -Eo 'GitVersion: *v?[0-9]+\.[0-9]+\.[0-9]+' | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true
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
# Succeeds if cosign is installed and its version is at least $1 (default: COSIGN_MIN_VERSION).
EOF
)"
pe "$(cat <<'EOF'
function cosign_version_ok() {
EOF
)"
pe "$(cat <<'EOF'
    local version min_version="${1:-$COSIGN_MIN_VERSION}"
EOF
)"
pe "$(cat <<'EOF'
    command -v cosign >/dev/null 2>&1 || return 1
EOF
)"
pe "$(cat <<'EOF'
    version="$(cosign_version)"
EOF
)"
pe "$(cat <<'EOF'
    [[ -n "$version" ]] || return 1
EOF
)"
pe "$(cat <<'EOF'
    [[ "$(printf '%s\n%s\n' "$min_version" "$version" | sort -V | head -n 1)" == "$min_version" ]]
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
    if ! command -v cosign >/dev/null 2>&1; then
EOF
)"
pe "$(cat <<'EOF'
        echo "cosign is not installed, so we cannot verify the signature of image '$image_name'! Exiting! Please run ./scripts/prerequisite_check.sh to install cosign."
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
    if ! cosign_version_ok; then
EOF
)"
pe "$(cat <<'EOF'
        echo "cosign version '$(cosign_version)' of $(command -v cosign) is too old or unknown: we need cosign >= $COSIGN_MIN_VERSION to verify the signature of image '$image_name'! Exiting! Please run ./scripts/prerequisite_check.sh to update cosign."
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
    cosign verify --key "$cosign_public_key_file" "$image_name" >/dev/null 2> /dev/null || { echo "Failed to verify signature of image '$image_name'! Exiting! Please check that 'cosign version' shows a git version >= $COSIGN_MIN_VERSION. Also ensure that there is no field 'credsStore' in '$HOME/.docker/config.json'"; exit 1; }
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
printf '%s\n' 'The `scone-glibc` installer must match the glibc of the host. The package image'
printf '%s\n' 'ships installers for glibc 2.31, 2.35 and 2.39, i.e., Ubuntu 20.04, 22.04 and 24.04.'
printf '%s\n' 'Ubuntu 26.04 (glibc 2.43) will be supported in an upcoming SCONE version.'
printf '%s\n' 'The installer'\''s post-installation script searches the whole filesystem for the'
printf '%s\n' 'dynamic loader. On hosts with snaps it can pick a read-only copy inside a snap and'
printf '%s\n' 'fail with `cp: can'\''t create '\''/snap/core24/...'\'': File exists`, so we patch it to use'
printf '%s\n' 'the canonical loader path `/lib64/ld-linux-x86-64.so.2`.'
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
# Locally built tools (see ./overwrite.sh) for releases whose package image lacks them.
EOF
)"
pe "$(cat <<'EOF'
SCONE_TOOL_OVERRIDE_DIR="$(printenv SCONE_TOOL_OVERRIDE_DIR || echo "$PWD/overwrite/bin")"
EOF
)"
pe "$(cat <<'EOF'
SCONE_TD_BUILD_CONTAINER=""
EOF
)"
pe "$(cat <<'EOF'
SCONE_WORKSHOP_CONTAINER=""
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
    if [[ -n "$SCONE_WORKSHOP_CONTAINER" ]]; then
EOF
)"
pe "$(cat <<'EOF'
        docker rm "$SCONE_WORKSHOP_CONTAINER" >/dev/null 2>&1 || true
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
# Select the glibc installer that matches the host glibc (e.g., 2.35 on Ubuntu 22.04).
EOF
)"
pe "$(cat <<'EOF'
# Set SCONE_GLIBC_VERSION to override the detected version.
EOF
)"
pe "$(cat <<'EOF'
SCONE_GLIBC_VERSION="$(printenv SCONE_GLIBC_VERSION || getconf GNU_LIBC_VERSION | awk '{print $2}')"
EOF
)"
pe "$(cat <<'EOF'
SCONE_GLIBC_DEB="scone-glibc-${SCONE_GLIBC_VERSION}-installer_amd64.deb"
EOF
)"
pe "$(cat <<'EOF'
if [[ ! -e "$INSTALL_WORK/packages/$SCONE_GLIBC_DEB" ]]; then
EOF
)"
pe "$(cat <<'EOF'
    echo "No scone-glibc installer for host glibc $SCONE_GLIBC_VERSION in $REPO/$IMAGE:$SCONE_VERSION. Available:" >&2
EOF
)"
pe "$(cat <<'EOF'
    find "$INSTALL_WORK/packages" -maxdepth 1 -type f -name '*glibc*installer*.deb' -printf '  %f\n' | sort -V >&2
EOF
)"
pe "$(cat <<'EOF'
    if [[ -r /etc/os-release ]] && (. /etc/os-release && [[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "26.04" ]]); then
EOF
)"
pe "$(cat <<'EOF'
        echo "Ubuntu 26.04 will be supported in an upcoming SCONE version. Please use Ubuntu 20.04, 22.04 or 24.04 in the meantime." >&2
EOF
)"
pe "$(cat <<'EOF'
    else
EOF
)"
pe "$(cat <<'EOF'
        echo "Set SCONE_GLIBC_VERSION to select one of these explicitly." >&2
EOF
)"
pe "$(cat <<'EOF'
    fi
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
# The postinst finds the host loader with 'find /', which can return a read-only copy
EOF
)"
pe "$(cat <<'EOF'
# inside a snap (e.g., /snap/core24/.../ld-linux-x86-64.so.2). Use the canonical path.
EOF
)"
pe "$(cat <<'EOF'
SCONE_GLIBC_LOADER_FIND='find / -name ld-linux-x86-64.so.2 -type l -print -quit'
EOF
)"
pe "$(cat <<'EOF'
SCONE_GLIBC_LOADER_SED='s|find / -name ld-linux-x86-64\.so\.2 -type l -print -quit|echo /lib64/ld-linux-x86-64.so.2|g'
EOF
)"
pe "$(cat <<'EOF'
SCONE_GLIBC_PKG_DIR="$INSTALL_WORK/glibc-pkg"
EOF
)"
pe "$(cat <<'EOF'
# dpkg-deb -b rejects control directories below mode 0755: do not inherit a strict umask.
EOF
)"
pe "$(cat <<'EOF'
(umask 022 && dpkg-deb -R "$INSTALL_WORK/packages/$SCONE_GLIBC_DEB" "$SCONE_GLIBC_PKG_DIR")
EOF
)"
pe "$(cat <<'EOF'
SCONE_GLIBC_POSTINST="$SCONE_GLIBC_PKG_DIR/DEBIAN/postinst"
EOF
)"
pe "$(cat <<'EOF'
if [[ -f "$SCONE_GLIBC_POSTINST" ]] && grep -aFq "$SCONE_GLIBC_LOADER_FIND" "$SCONE_GLIBC_POSTINST"; then
EOF
)"
pe "$(cat <<'EOF'
    if SCONE_GLIBC_ARCHIVE_LINE="$(grep -a -n -m1 '^__ARCHIVE_START__' "$SCONE_GLIBC_POSTINST")"; then
EOF
)"
pe "$(cat <<'EOF'
        # Self-extracting postinst: only edit the script in front of the embedded archive.
EOF
)"
pe "$(cat <<'EOF'
        SCONE_GLIBC_ARCHIVE_LINE="${SCONE_GLIBC_ARCHIVE_LINE%%:*}"
EOF
)"
pe "$(cat <<'EOF'
        {
EOF
)"
pe "$(cat <<'EOF'
            head -n "$SCONE_GLIBC_ARCHIVE_LINE" "$SCONE_GLIBC_POSTINST" | sed "$SCONE_GLIBC_LOADER_SED"
EOF
)"
pe "$(cat <<'EOF'
            tail -n +"$((SCONE_GLIBC_ARCHIVE_LINE + 1))" "$SCONE_GLIBC_POSTINST"
EOF
)"
pe "$(cat <<'EOF'
        } > "$SCONE_GLIBC_POSTINST.patched"
EOF
)"
pe "$(cat <<'EOF'
    else
EOF
)"
pe "$(cat <<'EOF'
        sed "$SCONE_GLIBC_LOADER_SED" "$SCONE_GLIBC_POSTINST" > "$SCONE_GLIBC_POSTINST.patched"
EOF
)"
pe "$(cat <<'EOF'
    fi
EOF
)"
pe "$(cat <<'EOF'
    if grep -aFq "$SCONE_GLIBC_LOADER_FIND" "$SCONE_GLIBC_POSTINST.patched"; then
EOF
)"
pe "$(cat <<'EOF'
        echo "Failed to patch the loader lookup in the postinst script of $SCONE_GLIBC_DEB" >&2
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
    chmod 0755 "$SCONE_GLIBC_POSTINST.patched"
EOF
)"
pe "$(cat <<'EOF'
    mv "$SCONE_GLIBC_POSTINST.patched" "$SCONE_GLIBC_POSTINST"
EOF
)"
pe "$(cat <<'EOF'
    (umask 022 && dpkg-deb --root-owner-group -b "$SCONE_GLIBC_PKG_DIR" "$INSTALL_WORK/packages/$SCONE_GLIBC_DEB" >/dev/null)
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
printf '%s\n' 'The workshop image `registry.scontain.com/workshop/scone:$SCONE_VERSION`, built by'
printf '%s\n' '`./scripts/build.sh`, is always newer than the package image of the same release.'
printf '%s\n' 'If it exists and has a valid cosign signature, its `scone-td-build`, `kubectl-scone`'
printf '%s\n' 'and `kubectl-scone-azure` replace the ones from the package image. Unsigned or'
printf '%s\n' 'missing workshop images are skipped, and so is the whole step if `cosign` is not'
printf '%s\n' 'installed or older than `COSIGN_BUNDLE_MIN_VERSION` (default 3.0.0): the workshop image'
printf '%s\n' 'is signed with cosign 3, which cosign 2.x cannot verify. The image is pulled'
printf '%s\n' 'by the digest that `cosign verify` checked, so a tag'
printf '%s\n' 'that moves after the check cannot slip in an unverified image. A tool that needs a'
printf '%s\n' 'newer glibc than the host has (e.g., the 6.0.8 workshop tools need glibc 2.34, so'
printf '%s\n' 'they do not run on Ubuntu 20.04) is skipped, and the package image'\''s version is kept.'
printf '%s\n' 'Set `SCONE_WORKSHOP_IMAGE` to use a different image, or to an empty value to skip'
printf '%s\n' 'this step.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
SCONE_WORKSHOP_IMAGE="${SCONE_WORKSHOP_IMAGE-registry.scontain.com/workshop/scone:$SCONE_VERSION}"
EOF
)"
pe "$(cat <<'EOF'
if [[ -n "$SCONE_WORKSHOP_IMAGE" ]]; then
EOF
)"
pe "$(cat <<'EOF'
    if [[ -z "${cosign_public_key_file:-}" ]]; then
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
    # Check the signature before pulling: the workshop image is large.
EOF
)"
pe "$(cat <<'EOF'
    SCONE_WORKSHOP_DIGEST=""
EOF
)"
pe "$(cat <<'EOF'
    if ! command -v cosign >/dev/null 2>&1; then
EOF
)"
pe "$(cat <<'EOF'
        echo "cosign is not installed, so workshop image $SCONE_WORKSHOP_IMAGE cannot be verified: keeping the tools of $REPO/$IMAGE:$SCONE_VERSION"
EOF
)"
pe "$(cat <<'EOF'
    elif ! cosign_version_ok "$COSIGN_BUNDLE_MIN_VERSION"; then
EOF
)"
pe "$(cat <<'EOF'
        echo "cosign version '$(cosign_version)' is older than $COSIGN_BUNDLE_MIN_VERSION, so workshop image $SCONE_WORKSHOP_IMAGE cannot be verified: keeping the tools of $REPO/$IMAGE:$SCONE_VERSION. Run ./scripts/prerequisite_check.sh to update cosign."
EOF
)"
pe "$(cat <<'EOF'
    elif ! docker manifest inspect "$SCONE_WORKSHOP_IMAGE" >/dev/null 2>&1; then
EOF
)"
pe "$(cat <<'EOF'
        echo "Workshop image $SCONE_WORKSHOP_IMAGE is not available: keeping the tools of $REPO/$IMAGE:$SCONE_VERSION"
EOF
)"
pe "$(cat <<'EOF'
    elif ! SCONE_WORKSHOP_VERIFIED="$(cosign verify --key "$cosign_public_key_file" "$SCONE_WORKSHOP_IMAGE" 2>/dev/null)"; then
EOF
)"
pe "$(cat <<'EOF'
        echo "Workshop image $SCONE_WORKSHOP_IMAGE has no valid signature: keeping the tools of $REPO/$IMAGE:$SCONE_VERSION"
EOF
)"
pe "$(cat <<'EOF'
    else
EOF
)"
pe "$(cat <<'EOF'
        SCONE_WORKSHOP_DIGEST="$(printf '%s' "$SCONE_WORKSHOP_VERIFIED" | grep -o '"docker-manifest-digest": *"sha256:[0-9a-f]\{64\}"' | grep -o 'sha256:[0-9a-f]*' | head -n 1 || true)"
EOF
)"
pe "$(cat <<'EOF'
        if [[ -z "$SCONE_WORKSHOP_DIGEST" ]]; then
EOF
)"
pe "$(cat <<'EOF'
            echo "cosign did not report the verified digest of $SCONE_WORKSHOP_IMAGE: keeping the tools of $REPO/$IMAGE:$SCONE_VERSION"
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
    if [[ -n "$SCONE_WORKSHOP_DIGEST" ]]; then
EOF
)"
pe "$(cat <<'EOF'
        # Drop the tag (a ':' after the last '/') or digest and pin the verified digest.
EOF
)"
pe "$(cat <<'EOF'
        SCONE_WORKSHOP_REPO="${SCONE_WORKSHOP_IMAGE%@*}"
EOF
)"
pe "$(cat <<'EOF'
        if [[ "${SCONE_WORKSHOP_REPO##*/}" == *:* ]]; then
EOF
)"
pe "$(cat <<'EOF'
            SCONE_WORKSHOP_REPO="${SCONE_WORKSHOP_REPO%:*}"
EOF
)"
pe "$(cat <<'EOF'
        fi
EOF
)"
pe "$(cat <<'EOF'
        SCONE_WORKSHOP_REF="$SCONE_WORKSHOP_REPO@$SCONE_WORKSHOP_DIGEST"
EOF
)"
pe "$(cat <<'EOF'
        echo "Taking the tools from the verified workshop image $SCONE_WORKSHOP_REF"
EOF
)"
pe "$(cat <<'EOF'
        docker pull "$SCONE_WORKSHOP_REF" >/dev/null
EOF
)"
pe "$(cat <<'EOF'
        SCONE_WORKSHOP_CONTAINER="scone-workshop-$$-$RANDOM"
EOF
)"
pe "$(cat <<'EOF'
        docker create --name "$SCONE_WORKSHOP_CONTAINER" "$SCONE_WORKSHOP_REF" true >/dev/null
EOF
)"
pe "$(cat <<'EOF'
        for tool in scone-td-build kubectl-scone kubectl-scone-azure; do
EOF
)"
pe "$(cat <<'EOF'
            # /root/.cargo/bin holds the tools built by ./overwrite.sh and comes first in its PATH.
EOF
)"
pe "$(cat <<'EOF'
            for dir in /root/.cargo/bin /usr/local/bin; do
EOF
)"
pe "$(cat <<'EOF'
                if docker cp -L "$SCONE_WORKSHOP_CONTAINER:$dir/$tool" "$INSTALL_WORK/bin/$tool.workshop" 2>/dev/null; then
EOF
)"
pe "$(cat <<'EOF'
                    # ldd reports "version `GLIBC_x' not found" if the host glibc is too old.
EOF
)"
pe "$(cat <<'EOF'
                    SCONE_WORKSHOP_LDD="$(ldd "$INSTALL_WORK/bin/$tool.workshop" 2>&1 || true)"
EOF
)"
pe "$(cat <<'EOF'
                    if [[ "$SCONE_WORKSHOP_LDD" == *"not found"* ]]; then
EOF
)"
pe "$(cat <<'EOF'
                        rm -f "$INSTALL_WORK/bin/$tool.workshop"
EOF
)"
pe "$(cat <<'EOF'
                        echo " - $tool from $dir does not run on this host, keeping the package version:"
EOF
)"
pe "$(cat <<'EOF'
                        printf '%s\n' "$SCONE_WORKSHOP_LDD" | grep 'not found' | sed 's/^/     /'
EOF
)"
pe "$(cat <<'EOF'
                    else
EOF
)"
pe "$(cat <<'EOF'
                        mv -f "$INSTALL_WORK/bin/$tool.workshop" "$INSTALL_WORK/bin/$tool"
EOF
)"
pe "$(cat <<'EOF'
                        echo " - $tool from $dir"
EOF
)"
pe "$(cat <<'EOF'
                    fi
EOF
)"
pe "$(cat <<'EOF'
                    break
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
        done
EOF
)"
pe "$(cat <<'EOF'
        docker rm "$SCONE_WORKSHOP_CONTAINER" >/dev/null
EOF
)"
pe "$(cat <<'EOF'
        SCONE_WORKSHOP_CONTAINER=""
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
printf '%s\n' 'Some releases (e.g., 6.0.8) do not include scone-td-build or the kubectl plugins.'
printf '%s\n' 'For those releases, `scone-td-build` is taken from `SCONE_TD_BUILD_IMAGE` if set.'
printf '%s\n' 'Otherwise, missing tools are taken from `SCONE_TOOL_OVERRIDE_DIR` (default:'
printf '%s\n' '`overwrite/bin`), which `./overwrite.sh` builds.'
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
    elif [[ -x "${SCONE_TOOL_OVERRIDE_DIR:-}/scone-td-build" ]]; then
EOF
)"
pe "$(cat <<'EOF'
        echo "Using scone-td-build from $SCONE_TOOL_OVERRIDE_DIR"
EOF
)"
pe "$(cat <<'EOF'
        cp "$SCONE_TOOL_OVERRIDE_DIR/scone-td-build" "$INSTALL_WORK/bin/"
EOF
)"
pe "$(cat <<'EOF'
    else
EOF
)"
pe "$(cat <<'EOF'
        echo "ERROR: scone-td-build not available in $REPO/$IMAGE:$SCONE_VERSION (run ./overwrite.sh to build it into overwrite/bin, or set SCONE_TD_BUILD_IMAGE to an image containing /usr/local/bin/scone-td-build)" >&2
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
        if docker cp "$SCONE_PACKAGE_CONTAINER:/usr/local/bin/$tool" "$INSTALL_WORK/bin/$tool" 2>/dev/null; then
EOF
)"
pe "$(cat <<'EOF'
            :
EOF
)"
pe "$(cat <<'EOF'
        elif [[ -x "$SCONE_TOOL_OVERRIDE_DIR/$tool" ]]; then
EOF
)"
pe "$(cat <<'EOF'
            echo "Using $tool from $SCONE_TOOL_OVERRIDE_DIR"
EOF
)"
pe "$(cat <<'EOF'
            cp "$SCONE_TOOL_OVERRIDE_DIR/$tool" "$INSTALL_WORK/bin/$tool"
EOF
)"
pe "$(cat <<'EOF'
        else
EOF
)"
pe "$(cat <<'EOF'
            echo "ERROR: $tool not available in $REPO/$IMAGE:$SCONE_VERSION (run ./overwrite.sh to build it into overwrite/bin, or set SCONE_TOOL_OVERRIDE_DIR)" >&2
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

