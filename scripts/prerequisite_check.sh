#!/usr/bin/env bash

set -euo pipefail
export CONFIRM_ALL_ENVIRONMENT_VARIABLES=${CONFIRM_ALL_ENVIRONMENT_VARIABLES:-"--force"}

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

printf "${VIOLET}"
printf '%s\n' '# Checking Prerequisites'
printf '%s\n' ''
printf '%s\n' '## Ensure `cargo` Is Installed'
printf '%s\n' ''
printf '%s\n' 'We install some utilities with `cargo`, so we first ensure that `rust` and `cargo` are installed. Use `scripts/install-rust.sh`, which checks for `rust` and required components and installs them if needed.'
printf '%s\n' ''
printf '%s\n' '![Screencast](docs/prerequisite_check.gif)'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Ensure rust is installed'
printf '%s\n' './scripts/install-rust.sh'
printf '%s\n' '# Ensure PATH is set correctly'
printf '%s\n' 'export PATH=$HOME/.cargo/bin:$PATH'
printf '%s\n' '# Add to PATH for all future shells'
printf '%s\n' 'grep -q '\''.cargo/bin'\'' ~/.bashrc || echo '\''export PATH="$HOME/.cargo/bin:$PATH"'\'' >> ~/.bashrc'
printf "${RESET}"

# Ensure rust is installed
./scripts/install-rust.sh
# Ensure PATH is set correctly
export PATH=$HOME/.cargo/bin:$PATH
# Add to PATH for all future shells
grep -q '.cargo/bin' ~/.bashrc || echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'We use the helper programs `tplenv` and `retry-spinner`, so ensure they are installed:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Ensure tplenv is installed'
printf '%s\n' 'cargo install tplenv'
printf '%s\n' '# Ensure retry-spinner is installed'
printf '%s\n' 'cargo install retry-spinner'
printf "${RESET}"

# Ensure tplenv is installed
cargo install tplenv
# Ensure retry-spinner is installed
cargo install retry-spinner

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Environment Variables'
printf '%s\n' ''
printf '%s\n' 'By default, we install the latest stable SCONE version. You can override this by setting `SCONE_VERSION` to the version you want to install:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'export SCONE_VERSION=$(cat stable.txt)'
printf "${RESET}"

export SCONE_VERSION=$(cat stable.txt)

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '`tplenv` asks for all environment variables described in `environment-variables.md` that are not yet set.'
printf '%s\n' ''
printf '%s\n' 'Run the following to prompt for and set missing variables:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)'
printf "${RESET}"

eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Check Commands'
printf '%s\n' ''
printf '%s\n' 'To run our commands and transform manifests and container images, we need a set of executables. We install the following tools on the current machine:'
printf '%s\n' ''
printf '%s\n' '- `cosign`: signs and verifies container image signatures'
printf '%s\n' '- `docker`: builds and runs Docker images'
printf '%s\n' '- `kubectl`: command-line interface for Kubernetes'
printf '%s\n' '- `helm`: package manager for Kubernetes'
printf '%s\n' '- `yq`: processes YAML documents'
printf '%s\n' '- `sed`: manipulates text files'
printf '%s\n' '- `gh`: GitHub command-line interface'
printf '%s\n' '- `pkg-config`: discovers compiler and linker flags'
printf '%s\n' '- `jq`: processes JSON documents'
printf '%s\n' '- `libssl-dev`: SSL development tools'
printf '%s\n' ''
printf '%s\n' '> **Note:** If the script fails on the first run with `Errors were encountered while processing: scone-glibc`, run it a second time.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'GREEN='\''\033[0;32m'\'''
printf '%s\n' 'YELLOW='\''\033[1;33m'\'''
printf '%s\n' 'RED='\''\033[0;31m'\'''
printf '%s\n' 'NC='\''\033[0m'\'' # No Color'
printf '%s\n' ''
printf '%s\n' 'check_command() {'
printf '%s\n' '  command -v "$1" &>/dev/null'
printf '%s\n' '}'
printf '%s\n' ''
printf '%s\n' 'scone_registry_login() {'
printf '%s\n' '    if [[ -n "${REGISTRY_TOKEN}" && -n "${REGISTRY_USER}" ]]; then'
printf '%s\n' '        echo "Attempting docker login..."'
printf '%s\n' '        echo "${REGISTRY_TOKEN}" | docker login ${REGISTRY} --username "${REGISTRY_USER}" --password-stdin'
printf '%s\n' '    else'
printf '%s\n' '        echo "Skipping docker login - REGISTRY_TOKEN or REGISTRY_USER not set or empty"'
printf '%s\n' '        echo "WARNING: Cannot access private SCONE images without login"'
printf '%s\n' '    fi'
printf '%s\n' '}'
printf '%s\n' ''
printf '%s\n' '# Auto-install Cosign if not present'
printf '%s\n' 'if ! check_command cosign; then'
printf '%s\n' '  echo "📥 Installing Cosign..."'
printf '%s\n' '  curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"'
printf '%s\n' '  sudo mv cosign-linux-amd64 /usr/local/bin/cosign'
printf '%s\n' '  sudo chmod +x /usr/local/bin/cosign'
printf '%s\n' '  echo "✔️ Cosign installed successfully."'
printf '%s\n' 'else'
printf '%s\n' '  echo "✔️ Cosign is already installed."'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' '# Auto-install Docker if not present'
printf '%s\n' 'if ! check_command docker; then'
printf '%s\n' '  echo "📥 Installing Docker..."'
printf '%s\n' '  curl -fsSL https://get.docker.com | sh'
printf '%s\n' '  echo "✔️ Docker installed successfully. Please log out and back in for group changes to take effect."'
printf '%s\n' 'else'
printf '%s\n' '  echo "✔️ Docker is already installed."'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' '# Ensure that we can run docker without being root'
printf '%s\n' './scripts/check_docker_setup.sh'
printf '%s\n' ''
printf '%s\n' '# Auto-install GitHub CLI if not present'
printf '%s\n' 'if ! check_command gh; then'
printf '%s\n' '  echo "📥 Installing GitHub CLI..."'
printf '%s\n' '  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg'
printf '%s\n' '  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null'
printf '%s\n' '  sudo apt update'
printf '%s\n' '  sudo apt install -y gh'
printf '%s\n' '  echo "✔️ GitHub CLI installed successfully."'
printf '%s\n' 'else'
printf '%s\n' '  echo "✔️ GitHub CLI is already installed."'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' '# Auto-install kubectl if not present'
printf '%s\n' 'if ! check_command kubectl; then'
printf '%s\n' '  echo "📥 Installing kubectl..."'
printf '%s\n' '  export KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)'
printf '%s\n' '  curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl'
printf '%s\n' '  curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256'
printf '%s\n' '  echo "$(cat kubectl.sha256) kubectl" | sha256sum --check'
printf '%s\n' '  sudo chmod +x kubectl'
printf '%s\n' '  sudo mv ./kubectl /usr/local/bin/'
printf '%s\n' '  rm kubectl.sha256'
printf '%s\n' '  echo "✔️ kubectl installed successfully."'
printf '%s\n' 'else'
printf '%s\n' '  echo "✔️ kubectl is already installed."'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' '# Auto-install Helm if not present'
printf '%s\n' 'if ! check_command helm; then'
printf '%s\n' '  echo "📥 Installing Helm..."'
printf '%s\n' '  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash'
printf '%s\n' '  echo "✔️ Helm installed successfully."'
printf '%s\n' 'else'
printf '%s\n' '  echo "✔️ Helm is already installed."'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' 'install_yq_v4() {'
printf '%s\n' '  YQ_VERSION="v4.46.1"'
printf '%s\n' '  sudo apt update'
printf '%s\n' '  sudo apt install -y --no-install-recommends xz-utils'
printf '%s\n' '  curl -L "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64.tar.gz" | sudo tar xz -C /usr/local/bin'
printf '%s\n' '  sudo chmod +x /usr/local/bin/yq_linux_amd64'
printf '%s\n' '  sudo ln -sf /usr/local/bin/yq_linux_amd64 /usr/local/bin/yq'
printf '%s\n' '  echo "✔️ yq installed successfully."'
printf '%s\n' '}'
printf '%s\n' ''
printf '%s\n' '# Check and auto-install yq v4'
printf '%s\n' 'if check_command yq; then'
printf '%s\n' '    yq_version=$(yq --version 2>&1 | grep  -oE '\''v[0-9]+'\'' | cut -d'\''v'\'' -f2) || yq_version=""'
printf '%s\n' '    if [[ -z "$yq_version" || "$yq_version" == "0" ]]; then'
printf '%s\n' '        echo -e "${RED}❌ Found yq version $yq_version which is not supported. Installing Yq v4"'
printf '%s\n' '        install_yq_v4'
printf '%s\n' '    fi'
printf '%s\n' '    if [[ "$yq_version" -ge 4 ]]; then'
printf '%s\n' '        echo "✔️ yq v$yq_version is installed (meets requirement v4+)."'
printf '%s\n' '    else'
printf '%s\n' '        echo -e "${RED}❌ yq version $yq_version is too old. Installing Yq v4"'
printf '%s\n' '        install_yq_v4'
printf '%s\n' '    fi'
printf '%s\n' 'else'
printf '%s\n' '    echo -e "${RED}❌ yq is not installed. Installing Yq v4"'
printf '%s\n' '    install_yq_v4'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' '# Auto-install other required packages'
printf '%s\n' 'missing_packages=()'
printf '%s\n' 'for pkg in pkg-config jq libssl-dev; do'
printf '%s\n' '  if ! dpkg -s "$pkg" &>/dev/null; then'
printf '%s\n' '    missing_packages+=("$pkg")'
printf '%s\n' '  fi'
printf '%s\n' 'done'
printf '%s\n' ''
printf '%s\n' 'if [ ${#missing_packages[@]} -ne 0 ]; then'
printf '%s\n' '  echo "📥 Installing missing packages: ${missing_packages[*]}"'
printf '%s\n' '  sudo apt update'
printf '%s\n' '  sudo apt install -y "${missing_packages[@]}"'
printf '%s\n' '  echo "✔️ All missing packages installed successfully."'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' '# sed is typically pre-installed on Ubuntu, but check anyway'
printf '%s\n' 'if ! check_command sed; then'
printf '%s\n' '  echo "📥 Installing sed..."'
printf '%s\n' '  sudo apt update'
printf '%s\n' '  sudo apt install -y sed'
printf '%s\n' '  echo "✔️ sed installed successfully."'
printf '%s\n' 'else'
printf '%s\n' '  echo "✔️ sed is already installed."'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' '# Check Kubernetes cluster connectivity'
printf '%s\n' 'if ! kubectl cluster-info &>/dev/null; then'
printf '%s\n' '  echo -e "${RED}❌ No Kubernetes cluster detected via kubectl. Is your cluster running?${NC}"'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' 'echo "✅ All external executables are installed and ready"'
printf "${RESET}"

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

# Auto-install Helm if not present
if ! check_command helm; then
  echo "📥 Installing Helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
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

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Check Access to `scone.cloud` Images'
printf '%s\n' ''
printf '%s\n' 'Check that you can pull the SCONE container images required for transformations. If this fails, do the following:'
printf '%s\n' ''
printf '%s\n' '- Generate an access token by following these instructions: <https://sconedocs.github.io/registry/#create-an-access-token>'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'echo "Environment variable SCONE_VERSION is set to $SCONE_VERSION"'
printf '%s\n' ''
printf '%s\n' 'echo -e "${YELLOW}📦 Checking access to required container images...${NC}"'
printf '%s\n' ''
printf '%s\n' 'if ! docker pull --quiet "registry.scontain.com/scone.cloud/sconecli:$SCONE_VERSION" &>/dev/null; then'
printf '%s\n' '      echo -e "${RED}❌ Cannot pull Docker image - trying to log in${NC}"'
printf '%s\n' '    # ask user for the credentials for accessing the registry'
printf '%s\n' '  eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --create-values-file --context --eval --force )'
printf '%s\n' '    kubectl create secret docker-registry sconeapps --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN || true'
printf '%s\n' '      scone_registry_login'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' '  images=('
printf '%s\n' '    "registry.scontain.com/scone.cloud/sconecli:$SCONE_VERSION"'
printf '%s\n' '    "registry.scontain.com/scone.cloud/scone-deb-pkgs:$SCONE_VERSION"'
printf '%s\n' '    "registry.scontain.com/scone.cloud/sconecli:$SCONE_VERSION"'
printf '%s\n' '    "registry.scontain.com/public-images/glibc:2.35-v4"'
printf '%s\n' '    "registry.scontain.com/public-images/glibc:2.39-v3"'
printf '%s\n' '  )'
printf '%s\n' '  for image in "${images[@]}"; do'
printf '%s\n' '    if ! docker pull --quiet "$image" &>/dev/null; then'
printf '%s\n' '      echo -e "${RED}❌ Cannot pull Docker image: $image${NC}"'
printf '%s\n' '      exit 1'
printf '%s\n' '    else'
printf '%s\n' '      echo "✅ image '\''$image'\'' is accessible"'
printf '%s\n' '    fi'
printf '%s\n' '  done'
printf '%s\n' '  echo -e "${GREEN}✔️ All images are OK.${NC}"'
printf "${RESET}"

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

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Install SCONE CLI Tools'
printf '%s\n' ''
printf '%s\n' 'The required images are now available. Next, install the `scone`-related executables by running `./scripts/install_sconecli.sh`.'
printf "${RESET}"

