# Checking Prerequisites

## Checking Commands

To run our commands and to transform manifests and container images,
we need a set of executable. We install the following external `executable` on
the current machine:

- `gcc-multilib` - (this dependency will be removed)
- `rustc`: the Rust compiler - only needed when building the tool chain or building rust compilers
- `cosign`: needed to sign and verify the signature of container images
- `docker`: needed to build and run docker images
- `kubectl`: command line interface for Kubernetes
- `yq`: command to access yaml documents
- `sed`: simple editor to manipulate text files
- `gh`: GitHub command line interface
- `pkg-config`: A tool for discovering compiler and linker flags
- `jq`: command to access json documents
- `libssl-dev`: ssl development tools

> NOTE: If the script fails on the first run with error:
> `Errors were encountered while processing: scone-glibc`
> please run a second time.

```bash
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

  check_command() {
    command -v "$1" &>/dev/null
  }

  if ! dpkg-query -W -f='${Status}' gcc-multilib 2>/dev/null | grep "ok installed" &>/dev/null; then
    echo "📥 Installing gcc-multilib..."
    sudo apt update
    sudo apt -y install gcc-multilib
  else
    echo "✔️ gcc-multilib is already installed."
  fi

  if ! check_command rustc; then
    echo -e "${RED}❌ Rust is not installed. Please install it from https://rustup.rs/${NC}"
    exit 1
  else
    echo "✔️ Rust is already installed."
  fi

  if ! check_command cosign; then
    echo "📥 Installing Cosign..."
    curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
    sudo mv cosign-linux-amd64 /usr/local/bin/cosign
    sudo chmod +x /usr/local/bin/cosign
  else
    echo "✔️ Cosign is already installed."
  fi

  if ! check_command docker; then
    echo -e "${RED}❌ Docker is not installed. Please install it from https://docs.docker.com/engine/install/ubuntu/${NC}"
    exit 1
  else
    echo "✔️ Docker is already installed."
  fi

  missing=()
  for cmd in kubectl yq sed gh pkg-config jq; do
    if ! check_command "$cmd"; then
      missing+=("$cmd")
    fi
  done

  if ! dpkg -s libssl-dev &>/dev/null; then
    missing+=("libssl-dev")
  fi

  if [ ${#missing[@]} -ne 0 ]; then
    echo -e "${RED}❌ Missing required tools/packages:${NC} ${missing[*]}"
    exit 1
  fi

  if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}❌ No Kubernetes cluster detected via kubectl. Is your cluster running?${NC}"
    exit 1
  fi
  echo "✅ Installed all external executable"
```


## Check access to `scone.cloud` images

We check that we can pull some SCONE container images that we need to execute
the transformations. If this fail, please do the following:

- generate an access token following these instructions: <https://sconedocs.github.io/registry/#create-an-access-token>

- 

```bash
# determine the latest stable version of SCONE:
VERSION=$(curl -L -s https://raw.githubusercontent.com/scontain/scone/refs/heads/main/stable.txt)
echo "The lastest stable version of SCONE is $VERSION"

echo -e "${YELLOW}📦 Checking access to required container images...${NC}"
  images=(
    "registry.scontain.com/scone.cloud/sconecli:$VERSION"
    "registry.scontain.com/scone.cloud/scone-deb-pkgs:$VERSION"
    "registry.scontain.com/scone.cloud/sconecli:$VERSION"
    "registry.scontain.com/public-images/glibc:2.35-v4"
    "registry.scontain.com/public-images/glibc:2.39-v3"
  )
  for image in "${images[@]}"; do
    if ! docker pull --quiet "$image" &>/dev/null; then
      echo -e "${RED}❌ Cannot pull Docker image: $image${NC}"
      exit 1
    else
      echo "✅ image '$image' is accessible"
    fi
  done
  echo -e "${GREEN}✔️ All images are OK.${NC}"
```


## Install SCONE CLI tools

We succeeded to pull the required, images. Next, we can install the `scone`-replated executable. To do so, we run script `./scripts/install_sconecli.sh`:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
"$SCRIPT_DIR/install_sconecli.sh"
```
