#!/usr/bin/env bash

set -euo pipefail 
LILAC='\033[1;35m'
RESET='\033[0m'
printf "${LILAC}"
cat <<EOF
# Checking Prerequisites

## Checking Commands

To run our commands and to transform manifests and container images,
we need a set of executable. We install the following external 'executable' on
the current machine:

- 'cosign': needed to sign and verify the signature of container images
- 'docker': needed to build and run docker images
- 'kubectl': command line interface for Kubernetes
- 'yq': command to access yaml documents
- 'sed': simple editor to manipulate text files
- 'gh': GitHub command line interface
- 'pkg-config': A tool for discovering compiler and linker flags
- 'jq': command to access json documents
- 'libssl-dev': ssl development tools

> NOTE: If the script fails on the first run with error:
> 'Errors were encountered while processing: scone-glibc'
> please run a second time.

EOF
printf "${RESET}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

check_command() {
  command -v "$1" &>/dev/null
}

scone_registry_login() {
    if [[ -n "${SCONE_REGISTRY_ACCESS_TOKEN}" && -n "${SCONE_REGISTRY_USERNAME}" ]]; then
        echo "Attempting docker login..."
        echo "${SCONE_REGISTRY_ACCESS_TOKEN}" | docker login registry.scontain.com --username "${SCONE_REGISTRY_USERNAME}" --password-stdin
    else
        echo "Skipping docker login - SCONE_REGISTRY_TOKEN or SCONE_REGISTRY_USERNAME not set or empty"
        return 1
    fi
}

# Auto-install Cosign if not present
if ! check_command cosign; then
  echo "📥 Installing Cosign..."
  curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
  sudo mv cosign-linux-amd64 /usr/local/bin/cosign
  sudo chmod +x /usr/local/bin/cosign
  echo "✔️ Cosign installed successfully."
else
  echo "✔️ Cosign is already installed."
fi

# Auto-install Docker if not present
if ! check_command docker; then
  echo "📥 Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  echo "✔️ Docker installed successfully. Please log out and back in for group changes to take effect."
else
  echo "✔️ Docker is already installed."
fi

# Auto-install GitHub CLI if not present
if ! check_command gh; then
  echo "📥 Installing GitHub CLI..."
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  sudo apt update
  sudo apt install -y gh
  echo "✔️ GitHub CLI installed successfully."
else
  echo "✔️ GitHub CLI is already installed."
fi

# Auto-install kubectl if not present
if ! check_command kubectl; then
  echo "📥 Installing kubectl..."
  KUBECTL_VERSION="v1.28.10"
  curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl
  curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256
  echo "$(cat kubectl.sha256) kubectl" | sha256sum --check
  sudo chmod +x kubectl
  sudo mv ./kubectl /usr/local/bin/
  rm kubectl.sha256
  echo "✔️ kubectl installed successfully."
else
  echo "✔️ kubectl is already installed."
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

# Check and Auto install Yq Version 4
if check_command yq; then
    yq_version=$(yq --version 2>&1 | grep -oP 'v\d+' | cut -d'v' -f2)
    if [[ -z "$yq_version" || "$yq_version" == "0" ]]; then
        echo -e "${RED}❌ Found yq version $yq_version which is not supported. Installing Yq v4"
        install_yq_v4
    fi
    if [[ "$yq_version" -ge 4 ]]; then
        echo "✔️ yq v$yq_version is installed (meets requirement v4+)."
    else
        echo -e "${RED}❌ yq version $yq_version is too old. Installing Yq v4"
        install_yq_v4
    fi
else
    echo -e "${RED}❌ yq is not installed. Installing Yq v4"
    install_yq_v4
fi

# Auto-install other required packages
missing_packages=()
for pkg in pkg-config jq libssl-dev; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    missing_packages+=("$pkg")
  fi
done

if [ ${#missing_packages[@]} -ne 0 ]; then
  echo "📥 Installing missing packages: ${missing_packages[*]}"
  sudo apt update
  sudo apt install -y "${missing_packages[@]}"
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
  exit 1
fi

echo "✅ All external executables are installed and ready"
LILAC='\033[1;35m'
RESET='\033[0m'
printf "${LILAC}"
cat <<EOF

## Check access to 'scone.cloud' images

We check that we can pull some SCONE container images that we need to execute
the transformations. If this fail, please do the following:

- generate an access token following these instructions: <https://sconedocs.github.io/registry/#create-an-access-token>

EOF
printf "${RESET}"

# determine the latest stable version of SCONE:
VERSION=$(curl -L -s https://raw.githubusercontent.com/scontain/scone/refs/heads/main/stable.txt)
echo "The lastest stable version of SCONE is $VERSION"

echo -e "${YELLOW}📦 Checking access to required container images...${NC}"
scone_registry_login
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
LILAC='\033[1;35m'
RESET='\033[0m'
printf "${LILAC}"
cat <<EOF

## Install SCONE CLI tools

We succeeded to pull the required, images. Next, we can install the 'scone'-replated executable. To do so, we run script './scripts/install_sconecli.sh':

EOF
printf "${RESET}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
"$SCRIPT_DIR/install_sconecli.sh"
