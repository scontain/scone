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

Next, inspect the package image archive and copy only the packages it contains.
SCONE 6.x places Debian packages at the image root; SCONE 7.x may add more packages
there. Some releases use a packages directory. This handles both layouts without
assuming that a fixed set of files exists.

The extracted files go in a unique temporary directory, so existing files in /tmp
are left alone. The temporary container and directory are removed when the script
exits.

The `scone-glibc` installer must match the glibc of the host. The package image
ships installers for glibc 2.31, 2.35 and 2.39, i.e., Ubuntu 20.04, 22.04 and 24.04.
Ubuntu 26.04 (glibc 2.43) will be supported in an upcoming SCONE version.
The installer's post-installation script searches the whole filesystem for the
dynamic loader. On hosts with snaps it can pick a read-only copy inside a snap and
fail with `cp: can't create '/snap/core24/...': File exists`, so we patch it to use
the canonical loader path `/lib64/ld-linux-x86-64.so.2`.

```bash
INSTALL_WORK="$(mktemp -d /tmp/scone-install.XXXXXXXX)"
SCONE_PACKAGE_CONTAINER="scone-packages-$$-$RANDOM"
SCONE_PACKAGE_CONTAINER_CREATED=false
SCONE_TD_BUILD_IMAGE="$(printenv SCONE_TD_BUILD_IMAGE || true)"
# Locally built tools (see ./overwrite.sh) for releases whose package image lacks them.
SCONE_TOOL_OVERRIDE_DIR="$(printenv SCONE_TOOL_OVERRIDE_DIR || echo "$PWD/overwrite/bin")"
SCONE_TD_BUILD_CONTAINER=""
SCONE_WORKSHOP_CONTAINER=""
cleanup_scone_package_install() {
    if [[ -n "$SCONE_TD_BUILD_CONTAINER" ]]; then
        docker rm "$SCONE_TD_BUILD_CONTAINER" >/dev/null 2>&1 || true
    fi
    if [[ -n "$SCONE_WORKSHOP_CONTAINER" ]]; then
        docker rm "$SCONE_WORKSHOP_CONTAINER" >/dev/null 2>&1 || true
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

# Select the glibc installer that matches the host glibc (e.g., 2.35 on Ubuntu 22.04).
# Set SCONE_GLIBC_VERSION to override the detected version.
SCONE_GLIBC_VERSION="$(printenv SCONE_GLIBC_VERSION || getconf GNU_LIBC_VERSION | awk '{print $2}')"
SCONE_GLIBC_DEB="scone-glibc-${SCONE_GLIBC_VERSION}-installer_amd64.deb"
if [[ ! -e "$INSTALL_WORK/packages/$SCONE_GLIBC_DEB" ]]; then
    echo "No scone-glibc installer for host glibc $SCONE_GLIBC_VERSION in $REPO/$IMAGE:$SCONE_VERSION. Available:" >&2
    find "$INSTALL_WORK/packages" -maxdepth 1 -type f -name '*glibc*installer*.deb' -printf '  %f\n' | sort -V >&2
    if [[ -r /etc/os-release ]] && (. /etc/os-release && [[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "26.04" ]]); then
        echo "Ubuntu 26.04 will be supported in an upcoming SCONE version. Please use Ubuntu 20.04, 22.04 or 24.04 in the meantime." >&2
    else
        echo "Set SCONE_GLIBC_VERSION to select one of these explicitly." >&2
    fi
    exit 1
fi

# The postinst finds the host loader with 'find /', which can return a read-only copy
# inside a snap (e.g., /snap/core24/.../ld-linux-x86-64.so.2). Use the canonical path.
SCONE_GLIBC_LOADER_FIND='find / -name ld-linux-x86-64.so.2 -type l -print -quit'
SCONE_GLIBC_LOADER_SED='s|find / -name ld-linux-x86-64\.so\.2 -type l -print -quit|echo /lib64/ld-linux-x86-64.so.2|g'
SCONE_GLIBC_PKG_DIR="$INSTALL_WORK/glibc-pkg"
# dpkg-deb -b rejects control directories below mode 0755: do not inherit a strict umask.
(umask 022 && dpkg-deb -R "$INSTALL_WORK/packages/$SCONE_GLIBC_DEB" "$SCONE_GLIBC_PKG_DIR")
SCONE_GLIBC_POSTINST="$SCONE_GLIBC_PKG_DIR/DEBIAN/postinst"
if [[ -f "$SCONE_GLIBC_POSTINST" ]] && grep -aFq "$SCONE_GLIBC_LOADER_FIND" "$SCONE_GLIBC_POSTINST"; then
    if SCONE_GLIBC_ARCHIVE_LINE="$(grep -a -n -m1 '^__ARCHIVE_START__' "$SCONE_GLIBC_POSTINST")"; then
        # Self-extracting postinst: only edit the script in front of the embedded archive.
        SCONE_GLIBC_ARCHIVE_LINE="${SCONE_GLIBC_ARCHIVE_LINE%%:*}"
        {
            head -n "$SCONE_GLIBC_ARCHIVE_LINE" "$SCONE_GLIBC_POSTINST" | sed "$SCONE_GLIBC_LOADER_SED"
            tail -n +"$((SCONE_GLIBC_ARCHIVE_LINE + 1))" "$SCONE_GLIBC_POSTINST"
        } > "$SCONE_GLIBC_POSTINST.patched"
    else
        sed "$SCONE_GLIBC_LOADER_SED" "$SCONE_GLIBC_POSTINST" > "$SCONE_GLIBC_POSTINST.patched"
    fi
    if grep -aFq "$SCONE_GLIBC_LOADER_FIND" "$SCONE_GLIBC_POSTINST.patched"; then
        echo "Failed to patch the loader lookup in the postinst script of $SCONE_GLIBC_DEB" >&2
        exit 1
    fi
    chmod 0755 "$SCONE_GLIBC_POSTINST.patched"
    mv "$SCONE_GLIBC_POSTINST.patched" "$SCONE_GLIBC_POSTINST"
    (umask 022 && dpkg-deb --root-owner-group -b "$SCONE_GLIBC_PKG_DIR" "$INSTALL_WORK/packages/$SCONE_GLIBC_DEB" >/dev/null)
fi

for tool in scone-td-build kubectl-scone kubectl-scone-azure; do
    if grep -Fqx "usr/local/bin/$tool" "$INSTALL_WORK/image-files.txt"; then
        docker cp "$SCONE_PACKAGE_CONTAINER:/usr/local/bin/$tool" "$INSTALL_WORK/bin/$tool"
    fi
done
```

Install the core packages. This requires sudo access.

```bash
sudo dpkg -i "$INSTALL_WORK/packages"/scone-common_*.deb
sudo dpkg -i "$INSTALL_WORK/packages"/scone-libc_*.deb
sudo dpkg -i "$INSTALL_WORK/packages"/scone-cli_*.deb
sudo dpkg -i "$INSTALL_WORK/packages/$SCONE_GLIBC_DEB"
```

The workshop image `registry.scontain.com/workshop/scone:$SCONE_VERSION`, built by
`./scripts/build.sh`, is always newer than the package image of the same release.
If it exists and has a valid cosign signature, its `scone-td-build`, `kubectl-scone`
and `kubectl-scone-azure` replace the ones from the package image. Unsigned or
missing workshop images are skipped. Set `SCONE_WORKSHOP_IMAGE` to use a different
image, or to an empty value to skip this step.

```bash
SCONE_WORKSHOP_IMAGE="${SCONE_WORKSHOP_IMAGE-registry.scontain.com/workshop/scone:$SCONE_VERSION}"
if [[ -n "$SCONE_WORKSHOP_IMAGE" ]]; then
    if [[ -z "${cosign_public_key_file:-}" ]]; then
        create_cosign_verification_key
    fi
    # Check the signature before pulling: the workshop image is large.
    if ! docker manifest inspect "$SCONE_WORKSHOP_IMAGE" >/dev/null 2>&1; then
        echo "Workshop image $SCONE_WORKSHOP_IMAGE is not available: keeping the tools of $REPO/$IMAGE:$SCONE_VERSION"
    elif ! cosign verify --key "$cosign_public_key_file" "$SCONE_WORKSHOP_IMAGE" >/dev/null 2>&1; then
        echo "Workshop image $SCONE_WORKSHOP_IMAGE has no valid signature: keeping the tools of $REPO/$IMAGE:$SCONE_VERSION"
    else
        echo "Taking the tools from the verified workshop image $SCONE_WORKSHOP_IMAGE"
        docker pull "$SCONE_WORKSHOP_IMAGE" >/dev/null
        SCONE_WORKSHOP_CONTAINER="scone-workshop-$$-$RANDOM"
        docker create --name "$SCONE_WORKSHOP_CONTAINER" "$SCONE_WORKSHOP_IMAGE" true >/dev/null
        for tool in scone-td-build kubectl-scone kubectl-scone-azure; do
            # /root/.cargo/bin holds the tools built by ./overwrite.sh and comes first in its PATH.
            for dir in /root/.cargo/bin /usr/local/bin; do
                if docker cp -L "$SCONE_WORKSHOP_CONTAINER:$dir/$tool" "$INSTALL_WORK/bin/$tool.workshop" 2>/dev/null; then
                    mv -f "$INSTALL_WORK/bin/$tool.workshop" "$INSTALL_WORK/bin/$tool"
                    echo " - $tool from $dir"
                    break
                fi
            done
        done
        docker rm "$SCONE_WORKSHOP_CONTAINER" >/dev/null
        SCONE_WORKSHOP_CONTAINER=""
    fi
fi
```

Some releases (e.g., 6.0.8) do not include scone-td-build or the kubectl plugins.
For those releases, `scone-td-build` is taken from `SCONE_TD_BUILD_IMAGE` if set.
Otherwise, missing tools are taken from `SCONE_TOOL_OVERRIDE_DIR` (default:
`overwrite/bin`), which `./overwrite.sh` builds.

```bash
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
    elif [[ -x "${SCONE_TOOL_OVERRIDE_DIR:-}/scone-td-build" ]]; then
        echo "Using scone-td-build from $SCONE_TOOL_OVERRIDE_DIR"
        cp "$SCONE_TOOL_OVERRIDE_DIR/scone-td-build" "$INSTALL_WORK/bin/"
    else
        echo "ERROR: scone-td-build not available in $REPO/$IMAGE:$SCONE_VERSION (run ./overwrite.sh to build it into overwrite/bin, or set SCONE_TD_BUILD_IMAGE to an image containing /usr/local/bin/scone-td-build)" >&2
    fi
fi

for tool in kubectl-scone kubectl-scone-azure; do
    if [[ ! -e "$INSTALL_WORK/bin/$tool" ]]; then
        if docker cp "$SCONE_PACKAGE_CONTAINER:/usr/local/bin/$tool" "$INSTALL_WORK/bin/$tool" 2>/dev/null; then
            :
        elif [[ -x "$SCONE_TOOL_OVERRIDE_DIR/$tool" ]]; then
            echo "Using $tool from $SCONE_TOOL_OVERRIDE_DIR"
            cp "$SCONE_TOOL_OVERRIDE_DIR/$tool" "$INSTALL_WORK/bin/$tool"
        else
            echo "ERROR: $tool not available in $REPO/$IMAGE:$SCONE_VERSION (run ./overwrite.sh to build it into overwrite/bin, or set SCONE_TOOL_OVERRIDE_DIR)" >&2
        fi
    fi
done

sudo install -m 0755 "$INSTALL_WORK/bin/scone-td-build" /usr/local/bin/scone-td-build || echo "ERROR: scone-td-build not available"
sudo install -m 0755 "$INSTALL_WORK/bin/kubectl-scone" /usr/local/bin/kubectl-scone || echo "ERROR: kubectl scone not available"
sudo install -m 0755 "$INSTALL_WORK/bin/kubectl-scone-azure" /usr/local/bin/kubectl-scone-azure || echo "ERROR: kubectl-scone-azure not available"
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

Validate the tools that the shell actually selects through `PATH`. This catches
older Cargo binaries shadowing newly installed system packages, as well as newer
plugins that expect a different CAS schema.

```bash
# Validate the tools selected by PATH.
SCONE_VERSION="$SCONE_VERSION" ./scripts/check-scone-tooling.sh
echo "✅ All required SCONE commands installed and compatible with the workshop version requirements"
```

The checker requires `scone` and `kubectl-scone` to match the major/minor release
line of `SCONE_VERSION`; patch versions may differ. A stable target rejects
prerelease tools. The demos require a stable `scone-td-build` version of at least
0.4.0 and the `apply -f scone.yaml` interface. Workshop revision `b607bdc` supports
the current `cas-endpoint` templates. The checker also exercises the kubectl
plugins' help commands. Any failure stops installation before the success message
and lists executable paths to help identify shadowed installations.

To repeat these checks without installing packages, run this from the repository:

```console
SCONE_VERSION=6.0.8 ./scripts/check-scone-tooling.sh
```

Without `SCONE_VERSION`, the standalone checker uses `stable.txt`. Set the target
to the release used by your operator. These are local version and command checks;
they do not contact Kubernetes or verify CAS connectivity or attestation.
