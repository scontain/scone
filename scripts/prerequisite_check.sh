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

- 'gcc-multilib' - (this dependency will be removed)
- 'cosign': needed to sign and verify the signature of container images
- 'docker': needed to build and run docker images
- 'kubectl': command line interface for Kubernetes
- 'yq' (v4+): command to access yaml documents
- 'sed': simple editor to manipulate text files
- 'gh': GitHub command line interface
- 'pkg-config': A tool for discovering compiler and linker flags
- 'jq': command to access json documents
- 'libssl-dev': ssl development tools
- 'helm': Kubernetes package manager
- 'git': version control system to check repository access

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

check_yq_version() {
    if check_command yq; then
        local version
        version=$(yq --version 2>&1 | grep -oP 'v\d+' | cut -d'v' -f2)
        if [[ -z "$version" || "$version" == "0" ]]; then
            echo -e "${RED}❌ Found yq version $version which is not supported. Please install yq v4+ from https://github.com/mikefarah/yq/${NC}"
            return 1
        fi
        if [[ "$version" -ge 4 ]]; then
            echo "✔️ yq v$version is installed (meets requirement v4+)."
            return 0
        else
            echo -e "${RED}❌ yq version $version is too old. Please install yq v4+ from https://github.com/mikefarah/yq/${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ yq is not installed. Please install yq v4+ from https://github.com/mikefarah/yq/${NC}"
        return 1
    fi
}

if ! dpkg-query -W -f='${Status}' gcc-multilib 2>/dev/null | grep "ok installed" &>/dev/null; then
    echo "📥 Installing gcc-multilib..."
    sudo apt update
    sudo apt -y install gcc-multilib
else
    echo "✔️ gcc-multilib is already installed."
fi

missing=()
for cmd in cosign docker kubectl sed gh pkg-config jq helm git; do
    if ! check_command "$cmd"; then
        missing+=("$cmd")
    fi
done

if ! check_yq_version; then
    missing+=("yq(v4+)")
fi

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

echo -e "${YELLOW}🔍 Checking Docker registry login...${NC}"

# Check if logged in to the specific registry
if docker login registry.scontain.com >/dev/null 2>&1 <<<' '; then
    echo "✅ Already authenticated with registry.scontain.com"
else
    echo -e "${RED}❌ Not authenticated with registry.scontain.com${NC}"
    echo -e "${YELLOW}To login, use one of these methods:"
    echo ""
    echo "1. Using environment variables:"
    echo "   echo \$SCONE_REGISTRY_TOKEN | docker login registry.scontain.com -u \$SCONE_REGISTRY_USER --password-stdin"
    echo ""
    echo "2. Interactive login:"
    echo "   docker login registry.scontain.com"
    echo ""
    echo "Documentation: https://sconedocs.github.io/registry/#create-an-access-token"
    echo -e "${NC}"
    exit 1
fi

# determine the latest stable version of SCONE:
VERSION=$(curl -L -s https://raw.githubusercontent.com/scontain/scone/refs/heads/main/stable.txt)
echo "The latest stable version of SCONE is $VERSION"

echo -e "${YELLOW}📦 Checking access to required container images...${NC}"
images=(
    "registry.scontain.com/scone.cloud/sconecli:$VERSION"
    "registry.scontain.com/scone.cloud/scone-deb-pkgs:$VERSION"
    "registry.scontain.com/scone.cloud/sconecli:$VERSION"
    "registry.scontain.com/public-images/glibc:2.35-v4"
    "registry.scontain.com/public-images/glibc:2.39-v3"
    "registry.scontain.com/scone.cloud/runtime-ubuntu20.04:$VERSION"
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
