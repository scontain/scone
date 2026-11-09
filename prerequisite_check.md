# Checking Prerequisites

## Ensure `cargo` Is Installed

We install some utilities with `cargo`, so we first ensure that `rust` and `cargo` are installed. Use `scripts/install-rust.sh`, which checks for `rust` and required components and installs them if needed.

![Screencast](docs/prerequisite_check.gif)

```bash
# Ensure rust is installed
./scripts/install-rust.sh
# Ensure PATH is set correctly
export PATH=$HOME/.cargo/bin:$PATH
# Add to PATH for all future shells
grep -q '.cargo/bin' ~/.bashrc || echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
```

We use the helper programs `tplenv` and `retry-spinner`, so ensure they are installed:

```bash
# Ensure tplenv is installed
cargo install tplenv
# Ensure retry-spinner is installed
cargo install retry-spinner
```

## Environment Variables

By default, we install the latest stable SCONE version. You can override this by setting `SCONE_VERSION` to the version you want to install:

```bash
export SCONE_VERSION="${SCONE_VERSION:-$(cat stable.txt)}"
```

`tplenv` asks for all environment variables described in `environment-variables.md` that are not yet set.

Run the following to prompt for and set missing variables:

```bash
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
```

## Check Commands

To run our commands and transform manifests and container images, we need a set of executables. We install the following tools on the current machine:

- `cosign`: signs and verifies container image signatures
- `docker`: builds and runs Docker images
- `kubectl`: command-line interface for Kubernetes
- `helm`: package manager for Kubernetes
- `yq`: processes YAML documents
- `sed`: manipulates text files
- `gh`: GitHub command-line interface
- `pkg-config`: discovers compiler and linker flags
- `jq`: processes JSON documents
- `libssl-dev`: SSL development tools

> **Note:** If the script fails on the first run with `Errors were encountered while processing: scone-glibc`, run it a second time.

On **Linux**, we install missing tools with `apt` and the Docker install script, so this works on
Debian and Ubuntu. On **macOS** (Apple Silicon and Intel), we install missing tools with
[Homebrew](https://brew.sh) (`brew install gh kubectl helm yq pkg-config jq openssl@3`, where
`openssl@3` replaces `libssl-dev`). Without Homebrew, the script names the missing tool and stops.
Docker cannot be installed by script on macOS: install and start
[Docker Desktop](https://docs.docker.com/desktop/setup/install/mac-install/) (or another Docker
engine, e.g., Colima) first. On macOS, the script prepares the Kubernetes path of the README;
the SCONE CLI itself needs x86_64 Linux (see [Install SCONE CLI Tools](#install-scone-cli-tools)).

`cosign` 2.0.0 or newer verifies the SCONE package images. The workshop image is signed with
cosign 3, so verifying it needs cosign 3.0.0 or newer. If `cosign` is missing or older than
3.0.0, we install the binary for this OS and CPU from the latest cosign release as
`/usr/local/bin/cosign`. Set `COSIGN_RELEASE` (e.g., `v3.1.4`) to install a specific release.
The binary must match the checksums of its release and run on this machine before it replaces
the installed `cosign`. If the update fails, an installed cosign 2.x is kept: it still verifies
the package images, but the installation then keeps the tools of the package image instead
of the workshop image's.

```bash
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

check_command() {
  command -v "$1" &>/dev/null
}

# On macOS, we install missing tools with Homebrew instead of apt.
is_macos() {
  [[ "$(uname -s)" == Darwin ]]
}

# Succeeds if you sourced this script (". ./scripts/prerequisite_check.sh"), as the README says:
# then BASH_SOURCE[0] is this script and $0 is your shell. zsh, which has no BASH_SOURCE, can
# only source this script.
is_sourced() {
  [[ "${BASH_SOURCE[0]:-}" != "$0" ]]
}

# This script starts with "set -euo pipefail". If you sourced it, these options are on in your
# shell: then any command that fails closes it. reset_shell_options turns them off again if you
# sourced this script. We call it when we stop and at the end.
reset_shell_options() {
  if is_sourced; then set +e +u +o pipefail; fi
}

# If something is missing, we stop with "stop_check || return 1 2>/dev/null || exit 1": it
# returns to your shell if you sourced this script, and exits with 1 if you ran it. "exit 1"
# would close your shell, and so would "return 1" while "set -e" is on.
stop_check() {
  reset_shell_options
  return 1
}

# Installs the Homebrew formulae $@. Fails if Homebrew is missing: then the caller stops.
brew_install() {
  if ! check_command brew; then
    echo -e "${RED}❌ Missing on this Mac: $*. Install Homebrew (https://brew.sh) and run this script again, or install $* yourself.${NC}"
    return 1
  fi
  brew install "$@" || return
  hash -r
}

scone_registry_login() {
    if [[ -n "${REGISTRY_TOKEN}" && -n "${REGISTRY_USER}" ]]; then
        echo "Attempting docker login..."
        echo "${REGISTRY_TOKEN}" | docker login ${REGISTRY} --username "${REGISTRY_USER}" --password-stdin
    else
        echo "Skipping docker login - REGISTRY_TOKEN or REGISTRY_USER not set or empty"
        echo "WARNING: Cannot access private SCONE images without login"
    fi
}

# cosign >= 2.0.0 verifies the SCONE package images. Images signed with cosign 3.x in its
# bundle format, such as the workshop image built by ./scripts/build.sh, need cosign >= 3.0.0.
COSIGN_MIN_VERSION="${COSIGN_MIN_VERSION:-2.0.0}"
COSIGN_BUNDLE_MIN_VERSION="${COSIGN_BUNDLE_MIN_VERSION:-3.0.0}"
# The cosign release to install, e.g., v3.1.4. Default: the latest release.
COSIGN_RELEASE="${COSIGN_RELEASE:-latest}"
COSIGN_INSTALL_PATH="${COSIGN_INSTALL_PATH:-/usr/local/bin/cosign}"

# Prints the version (e.g., 2.4.1) of cosign, or of the cosign binary $1, or nothing if unknown.
cosign_version() {
  "${1:-cosign}" version 2>/dev/null | grep -Eo 'GitVersion: *v?[0-9]+\.[0-9]+\.[0-9]+' | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true
}

# Succeeds if cosign is installed and its version is at least $1 (default: COSIGN_MIN_VERSION).
cosign_version_ok() {
  local version min_version="${1:-$COSIGN_MIN_VERSION}"
  check_command cosign || return 1
  version="$(cosign_version)"
  [[ -n "$version" ]] || return 1
  [[ "$(printf '%s\n%s\n' "$min_version" "$version" | sort -V | head -n 1)" == "$min_version" ]]
}

# Installs the cosign binary of COSIGN_RELEASE for this OS and CPU as COSIGN_INSTALL_PATH.
# The binary must match the release checksums and run before it replaces an installed cosign.
install_cosign() (
  case "$(uname -s)" in
    Linux) os=linux ;;
    Darwin) os=darwin ;;
    *) echo "No cosign release for OS $(uname -s)"; exit 1 ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "No cosign release for CPU $(uname -m)"; exit 1 ;;
  esac
  asset="cosign-$os-$arch"
  tag="$COSIGN_RELEASE"
  if [[ "$tag" == latest ]]; then
    # Resolve the tag once, so the binary and the checksums come from the same release.
    tag="$(curl -fsSIL --retry 3 -o /dev/null -w '%{url_effective}' https://github.com/sigstore/cosign/releases/latest)" || { echo "Cannot determine the latest cosign release"; exit 1; }
    tag="${tag##*/}"
  fi
  if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    echo "Unexpected cosign release '$tag'"
    exit 1
  fi
  url="https://github.com/sigstore/cosign/releases/download/$tag"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  echo "Downloading $url/$asset"
  if ! curl -fsSL --retry 3 -o "$tmp/$asset" "$url/$asset" \
    || ! curl -fsSL --retry 3 -o "$tmp/cosign_checksums.txt" "$url/cosign_checksums.txt"; then
    echo "Download of cosign $tag failed"
    exit 1
  fi
  expected="$(awk -v f="$asset" '$2 == f { print $1 }' "$tmp/cosign_checksums.txt")"
  if check_command sha256sum; then
    actual="$(sha256sum "$tmp/$asset" | awk '{ print $1 }')"
  else
    actual="$(shasum -a 256 "$tmp/$asset" | awk '{ print $1 }')"
  fi
  if [[ -z "$expected" || "$actual" != "$expected" ]]; then
    echo "Checksum of $asset does not match cosign_checksums.txt of cosign $tag"
    exit 1
  fi
  chmod +x "$tmp/$asset"
  if [[ -z "$(cosign_version "$tmp/$asset")" ]]; then
    echo "The downloaded $asset does not run on this machine"
    exit 1
  fi
  sudo mkdir -p "$(dirname "$COSIGN_INSTALL_PATH")" && sudo install -m 0755 "$tmp/$asset" "$COSIGN_INSTALL_PATH"
)

# Install Cosign if it is missing, or update it if it cannot verify the workshop image
if cosign_version_ok "$COSIGN_BUNDLE_MIN_VERSION"; then
  echo "✔️ Cosign $(cosign_version) is already installed."
else
  if check_command cosign; then
    echo "📥 Cosign '$(cosign_version)' of $(command -v cosign) is older than $COSIGN_BUNDLE_MIN_VERSION: installing Cosign $COSIGN_RELEASE..."
  else
    echo "📥 Installing Cosign $COSIGN_RELEASE..."
  fi
  if install_cosign; then
    hash -r
    if [[ "$(command -v cosign)" != "$COSIGN_INSTALL_PATH" ]]; then
      echo -e "${YELLOW}⚠️ Installed cosign $(cosign_version "$COSIGN_INSTALL_PATH") as $COSIGN_INSTALL_PATH, but $(command -v cosign) comes first in your PATH: remove it or put $(dirname "$COSIGN_INSTALL_PATH") first.${NC}"
    fi
  else
    echo -e "${YELLOW}⚠️ Could not install cosign: see the message above.${NC}"
  fi
  if cosign_version_ok "$COSIGN_BUNDLE_MIN_VERSION"; then
    echo "✔️ Cosign $(cosign_version) installed successfully."
  elif cosign_version_ok; then
    echo -e "${YELLOW}⚠️ Using cosign $(cosign_version) of $(command -v cosign): it verifies the SCONE package images, but not the workshop image, which needs cosign >= $COSIGN_BUNDLE_MIN_VERSION.${NC}"
  else
    if check_command cosign; then
      echo -e "${RED}❌ We need cosign >= $COSIGN_MIN_VERSION to verify the SCONE images, but $(command -v cosign) is cosign '$(cosign_version)'.${NC}"
    else
      echo -e "${RED}❌ We need cosign >= $COSIGN_MIN_VERSION to verify the SCONE images, but no cosign is installed.${NC}"
    fi
    stop_check || return 1 2>/dev/null || exit 1
  fi
fi

# Auto-install Docker if not present
if ! check_command docker; then
  if is_macos; then
    # get.docker.com supports Linux only.
    echo -e "${RED}❌ Docker is not installed. On macOS, install Docker Desktop (https://docs.docker.com/desktop/setup/install/mac-install/) or another Docker engine, start it, and run this script again.${NC}"
    stop_check || return 1 2>/dev/null || exit 1
  fi
  echo "📥 Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  echo "✔️ Docker installed successfully. Please log out and back in for group changes to take effect."
else
  echo "✔️ Docker is already installed."
fi

# Ensure that we can run docker without being root (on macOS: that Docker runs)
./scripts/check_docker_setup.sh || stop_check || return 1 2>/dev/null || exit 1

# Auto-install GitHub CLI if not present
if ! check_command gh; then
  echo "📥 Installing GitHub CLI..."
  if is_macos; then
    brew_install gh || stop_check || return 1 2>/dev/null || exit 1
  else
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
    sudo apt install -y gh
  fi
  echo "✔️ GitHub CLI installed successfully."
else
  echo "✔️ GitHub CLI is already installed."
fi

# Auto-install kubectl if not present
if ! check_command kubectl; then
  echo "📥 Installing kubectl..."
  if is_macos; then
    brew_install kubectl || stop_check || return 1 2>/dev/null || exit 1
  else
    export KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl
    curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256
    echo "$(cat kubectl.sha256) kubectl" | sha256sum --check
    sudo chmod +x kubectl
    sudo mv ./kubectl /usr/local/bin/
    rm kubectl.sha256
  fi
  echo "✔️ kubectl installed successfully."
else
  echo "✔️ kubectl is already installed."
fi

# Auto-install Helm if not present
if ! check_command helm; then
  echo "📥 Installing Helm..."
  if is_macos; then
    brew_install helm || stop_check || return 1 2>/dev/null || exit 1
  else
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  fi
  echo "✔️ Helm installed successfully."
else
  echo "✔️ Helm is already installed."
fi

install_yq_v4() {
  YQ_VERSION="v4.46.1"
  sudo apt update
  sudo apt install -y --no-install-recommends xz-utils
  curl -L "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64.tar.gz" | sudo tar xz -C /usr/local/bin
  sudo chmod +x /usr/local/bin/yq_linux_amd64
  sudo ln -sf /usr/local/bin/yq_linux_amd64 /usr/local/bin/yq
  echo "✔️ yq installed successfully."
}

# Check and auto-install yq v4
install_yq=false
if check_command yq; then
    yq_version=$(yq --version 2>&1 | grep  -oE 'v[0-9]+' | cut -d'v' -f2) || yq_version=""
    if [[ -z "$yq_version" || "$yq_version" == "0" ]]; then
        echo -e "${RED}❌ Found yq version $yq_version which is not supported. Installing Yq v4"
        install_yq=true
    fi
    if [[ "$yq_version" -ge 4 ]]; then
        echo "✔️ yq v$yq_version is installed (meets requirement v4+)."
    else
        echo -e "${RED}❌ yq version $yq_version is too old. Installing Yq v4"
        install_yq=true
    fi
else
    echo -e "${RED}❌ yq is not installed. Installing Yq v4"
    install_yq=true
fi
# On macOS, we stop here if Homebrew is missing: a function like install_yq_v4 can only
# return from itself, not from this script.
if [[ "$install_yq" == true ]]; then
  if is_macos; then
    # Homebrew's yq is mikefarah/yq v4.
    brew_install yq || stop_check || return 1 2>/dev/null || exit 1
    echo "✔️ yq installed successfully."
  else
    install_yq_v4
  fi
fi

# Auto-install other required packages
missing_packages=()
if is_macos; then
  # Homebrew's openssl@3 provides what libssl-dev provides on Debian. It is keg-only,
  # so pkg-config does not see it unless PKG_CONFIG_PATH points to it: ask brew as well.
  for pkg in pkg-config jq; do
    if ! check_command "$pkg"; then
      missing_packages+=("$pkg")
    fi
  done
  if ! { check_command brew && brew list --formula openssl@3 &>/dev/null; } \
    && ! pkg-config --exists openssl &>/dev/null; then
    missing_packages+=("openssl@3")
  fi
else
  for pkg in pkg-config jq libssl-dev; do
    if ! dpkg -s "$pkg" &>/dev/null; then
      missing_packages+=("$pkg")
    fi
  done
fi

if [ ${#missing_packages[@]} -ne 0 ]; then
  echo "📥 Installing missing packages: ${missing_packages[*]}"
  if is_macos; then
    brew_install "${missing_packages[@]}" || stop_check || return 1 2>/dev/null || exit 1
  else
    sudo apt update
    sudo apt install -y "${missing_packages[@]}"
  fi
  echo "✔️ All missing packages installed successfully."
fi

# sed is typically pre-installed on Ubuntu, but check anyway
if ! check_command sed; then
  echo "📥 Installing sed..."
  sudo apt update
  sudo apt install -y sed
  echo "✔️ sed installed successfully."
else
  echo "✔️ sed is already installed."
fi

# Check Kubernetes cluster connectivity
if ! kubectl cluster-info &>/dev/null; then
  echo -e "${RED}❌ No Kubernetes cluster detected via kubectl. Is your cluster running?${NC}"
fi

echo "✅ All external executables are installed and ready"
```

## Check Access to `scone.cloud` Images

Check that you can pull the SCONE container images required for transformations. If this fails, do the following:

- Generate an access token by following these instructions: <https://sconedocs.github.io/registry/#create-an-access-token>

```bash
echo "Environment variable SCONE_VERSION is set to $SCONE_VERSION"

echo -e "${YELLOW}📦 Checking access to required container images...${NC}"

if ! docker pull --quiet "registry.scontain.com/scone.cloud/sconecli:$SCONE_VERSION" &>/dev/null; then
      echo -e "${RED}❌ Cannot pull Docker image - trying to log in${NC}"
    # ask user for the credentials for accessing the registry. tplenv creates or
    # replaces the file with the umask's mode: keep the saved token private.
  if [[ -f Values.credentials.yaml ]]; then chmod 600 Values.credentials.yaml; fi
  eval $(umask 077; tplenv --values Values.credentials.yaml --file registry.credentials.md --create-values-file --context --eval --force )
    kubectl create secret docker-registry sconeapps --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN || true
      scone_registry_login
fi

  images=(
    "registry.scontain.com/scone.cloud/sconecli:$SCONE_VERSION"
    "registry.scontain.com/scone.cloud/scone-deb-pkgs:$SCONE_VERSION"
    "registry.scontain.com/scone.cloud/sconecli:$SCONE_VERSION"
    "registry.scontain.com/public-images/glibc:2.35-v4"
    "registry.scontain.com/public-images/glibc:2.39-v3"
  )
  for image in "${images[@]}"; do
    if ! docker pull --quiet "$image" &>/dev/null; then
      echo -e "${RED}❌ Cannot pull Docker image: $image${NC}"
      stop_check || return 1 2>/dev/null || exit 1
    else
      echo "✅ image '$image' is accessible"
    fi
  done
  echo -e "${GREEN}✔️ All images are OK.${NC}"
  reset_shell_options
```

## Install SCONE CLI Tools

The required images are now available. Next, install the `scone`-related executables by running `./scripts/install_sconecli.sh`.

The SCONE CLI packages run on x86_64 Linux only, so `./scripts/install_sconecli.sh` stops on
other hosts, e.g., on macOS. There, run the SCONE CLI in the workshop image instead: on an x86_64
machine with Docker (see "Run the Workshop Image" in the [README](README.md)), or in a Kubernetes
cluster with x86_64 nodes with `./scripts/k8s_cli.sh` (see [k8s.md](k8s.md)).
