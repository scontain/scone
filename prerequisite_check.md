# Checking Prerequisites

## Ensure `cargo` Is Installed

We install some utilities with `cargo`, so we first ensure that `rust` and `cargo` are installed. Use `scripts/install-rust.sh`, which checks for `rust` and required components and installs them if needed.

![Screencast](docs/prerequisite_check.gif)

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
export SCONE_VERSION=$(cat stable.txt)
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
- `yq`: processes YAML documents
- `sed`: manipulates text files
- `gh`: GitHub command-line interface
- `pkg-config`: discovers compiler and linker flags
- `jq`: processes JSON documents
- `libssl-dev`: SSL development tools

> **Note:** If the script fails on the first run with `Errors were encountered while processing: scone-glibc`, run it a second time.

```bash
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

check_command() {
  command -v "$1" &>/dev/null
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

# Ensure that we can run docker without being root
./scripts/check_docker_setup.sh

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
  export KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
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

# Check and auto-install yq v4
if check_command yq; then
    yq_version=$(yq --version 2>&1 | grep  -oE 'v[0-9]+' | cut -d'v' -f2) || yq_version=""
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
    # ask user for the credentials for accessing the registry
  eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --create-values-file --context --eval --force )
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
      exit 1
    else
      echo "✅ image '$image' is accessible"
    fi
  done
  echo -e "${GREEN}✔️ All images are OK.${NC}"
```

## Install SCONE CLI Tools

The required images are now available. Next, install the `scone`-related executables by running `./scripts/install_sconecli.sh`.
