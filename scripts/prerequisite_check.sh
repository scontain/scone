#!/usr/bin/env bash

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

printf "${VIOLET}"
printf '%s\n' '# Checking Prerequisites'
printf '%s\n' ''
printf '%s\n' '## Ensure that `cargo` is installed'
printf '%s\n' ''
printf '%s\n' 'We install some utilities with the help of `cargo`. Hence, we first ensure that `rust` and `cargo` are installed'
printf '%s\n' 'with the help of `scripts/install-rust.sh` that checks if `rust` and important components are installed and installs'
printf '%s\n' '`rust`. '
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# ensuring that rust is installed'
printf '%s\n' './scripts/install-rust.sh'
printf '%s\n' '# ensure PATH is properly set:'
printf '%s\n' 'export PATH=\$HOME/.cargo/bin:\$PATH'
printf "${RESET}"

# ensuring that rust is installed
./scripts/install-rust.sh
# ensure PATH is properly set:
export PATH=$HOME/.cargo/bin:$PATH

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'We use helper programs `tplenv` and `retry-spinner`. Hence, we ensure that they are installed:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# ensuring that tplenv is installed'
printf '%s\n' 'cargo install tplenv'
printf '%s\n' '# ensuring that retry-spinner is installed'
printf '%s\n' 'cargo install retry-spinner'
printf "${RESET}"

# ensuring that tplenv is installed
cargo install tplenv
# ensuring that retry-spinner is installed
cargo install retry-spinner

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Environment Variables'
printf '%s\n' ''
printf '%s\n' 'By default, we install the latest stable version of SCONE. You can overwrite the version by setting environment variable `SCONE_VERSION` to the SCONE version that you want to install:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'export SCONE_VERSION=\$(cat stable.txt)'
printf '%s\n' 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""'
printf "${RESET}"

export SCONE_VERSION=$(cat stable.txt)
export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Set the following environment variable to `--force` if you want to be asked interactively for the SCONE_VERSION:'
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' '`tplenv` will now ask the user for all environment variables that are described in file `environment-variables.md`'
printf '%s\n' 'but that are not set yet. In case `--force` is set, the values of all environment variables need to confirmed by the user:'
printf '%s\n' ''
printf '%s\n' 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--force"'
printf '%s\n' ''
printf '%s\n' 'Let'\''s ask the user and set the environment variables depending on the input of the user:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'eval \$(tplenv --file environment-variables.md --create-values-file --context --eval \${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'
printf "${RESET}"

eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Checking Commands'
printf '%s\n' ''
printf '%s\n' 'To run our commands and to transform manifests and container images,'
printf '%s\n' 'we need a set of executable. We install the following external `executable` on'
printf '%s\n' 'the current machine:'
printf '%s\n' ''
printf '%s\n' '- `cosign`: needed to sign and verify the signature of container images'
printf '%s\n' '- `docker`: needed to build and run docker images'
printf '%s\n' '- `kubectl`: command line interface for Kubernetes'
printf '%s\n' '- `yq`: command to access yaml documents'
printf '%s\n' '- `sed`: simple editor to manipulate text files'
printf '%s\n' '- `gh`: GitHub command line interface'
printf '%s\n' '- `pkg-config`: A tool for discovering compiler and linker flags'
printf '%s\n' '- `jq`: command to access json documents'
printf '%s\n' '- `libssl-dev`: ssl development tools'
printf '%s\n' ''
printf '%s\n' '> NOTE: If the script fails on the first run with error:'
printf '%s\n' '> `Errors were encountered while processing: scone-glibc`'
printf '%s\n' '> please run a second time.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'GREEN='\''\033[0;32m'\'''
printf '%s\n' 'YELLOW='\''\033[1;33m'\'''
printf '%s\n' 'RED='\''\033[0;31m'\'''
printf '%s\n' 'NC='\''\033[0m'\'' # No Color'
printf '%s\n' ''
printf '%s\n' 'check_command() {'
printf '%s\n' '  command -v "\$1" &>/dev/null'
printf '%s\n' '}'
printf '%s\n' ''
printf '%s\n' 'scone_registry_login() {'
printf '%s\n' '    if [[ -n "\${REGISTRY_TOKEN}" && -n "\${REGISTRY_USER}" ]]; then'
printf '%s\n' '        echo "Attempting docker login..."'
printf '%s\n' '        echo "\${REGISTRY_TOKEN}" | docker login \${REGISTRY} --username "\${REGISTRY_USER}" --password-stdin'
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
printf '%s\n' '# Auto-install GitHub CLI if not present'
printf '%s\n' 'if ! check_command gh; then'
printf '%s\n' '  echo "📥 Installing GitHub CLI..."'
printf '%s\n' '  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg'
printf '%s\n' '  echo "deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null'
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
printf '%s\n' '  export KUBECTL_VERSION=\$(curl -L -s https://dl.k8s.io/release/stable.txt)'
printf '%s\n' '  curl -LO https://dl.k8s.io/release/\${KUBECTL_VERSION}/bin/linux/amd64/kubectl'
printf '%s\n' '  curl -LO https://dl.k8s.io/release/\${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256'
printf '%s\n' '  echo "\$(cat kubectl.sha256) kubectl" | sha256sum --check'
printf '%s\n' '  sudo chmod +x kubectl'
printf '%s\n' '  sudo mv ./kubectl /usr/local/bin/'
printf '%s\n' '  rm kubectl.sha256'
printf '%s\n' '  echo "✔️ kubectl installed successfully."'
printf '%s\n' 'else'
printf '%s\n' '  echo "✔️ kubectl is already installed."'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' 'install_yq_v4() {'
printf '%s\n' '  YQ_VERSION="v4.46.1"'
printf '%s\n' '  sudo apt update'
printf '%s\n' '  sudo apt install -y --no-install-recommends xz-utils'
printf '%s\n' '  curl -L "https://github.com/mikefarah/yq/releases/download/\${YQ_VERSION}/yq_linux_amd64.tar.gz" | sudo tar xz -C /usr/local/bin'
printf '%s\n' '  sudo chmod +x /usr/local/bin/yq_linux_amd64'
printf '%s\n' '  sudo ln -sf /usr/local/bin/yq_linux_amd64 /usr/local/bin/yq'
printf '%s\n' '  echo "✔️ yq installed successfully."'
printf '%s\n' '}'
printf '%s\n' ''
printf '%s\n' '# Check and Auto install Yq Version 4'
printf '%s\n' 'if check_command yq; then'
printf '%s\n' '    yq_version=\$(yq --version 2>&1 | grep  -oE '\''v[0-9]+'\'' | cut -d'\''v'\'' -f2) || yq_version=""'
printf '%s\n' '    if [[ -z "\$yq_version" || "\$yq_version" == "0" ]]; then'
printf '%s\n' '        echo -e "\${RED}❌ Found yq version \$yq_version which is not supported. Installing Yq v4"'
printf '%s\n' '        install_yq_v4'
printf '%s\n' '    fi'
printf '%s\n' '    if [[ "\$yq_version" -ge 4 ]]; then'
printf '%s\n' '        echo "✔️ yq v\$yq_version is installed (meets requirement v4+)."'
printf '%s\n' '    else'
printf '%s\n' '        echo -e "\${RED}❌ yq version \$yq_version is too old. Installing Yq v4"'
printf '%s\n' '        install_yq_v4'
printf '%s\n' '    fi'
printf '%s\n' 'else'
printf '%s\n' '    echo -e "\${RED}❌ yq is not installed. Installing Yq v4"'
printf '%s\n' '    install_yq_v4'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' '# Auto-install other required packages'
printf '%s\n' 'missing_packages=()'
printf '%s\n' 'for pkg in pkg-config jq libssl-dev; do'
printf '%s\n' '  if ! dpkg -s "\$pkg" &>/dev/null; then'
printf '%s\n' '    missing_packages+=("\$pkg")'
printf '%s\n' '  fi'
printf '%s\n' 'done'
printf '%s\n' ''
printf '%s\n' 'if [ \${#missing_packages[@]} -ne 0 ]; then'
printf '%s\n' '  echo "📥 Installing missing packages: \${missing_packages[*]}"'
printf '%s\n' '  sudo apt update'
printf '%s\n' '  sudo apt install -y "\${missing_packages[@]}"'
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
printf '%s\n' '  echo -e "\${RED}❌ No Kubernetes cluster detected via kubectl. Is your cluster running?\${NC}"'
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

# Check and Auto install Yq Version 4
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
printf '%s\n' '## Check access to `scone.cloud` images'
printf '%s\n' ''
printf '%s\n' 'We check that we can pull some SCONE container images that we need to execute'
printf '%s\n' 'the transformations. If this fail, please do the following:'
printf '%s\n' ''
printf '%s\n' '- generate an access token following these instructions: <https://sconedocs.github.io/registry/#create-an-access-token>'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'echo "Environment variable SCONE_VERSION is set to \$SCONE_VERSION"'
printf '%s\n' ''
printf '%s\n' 'echo -e "\${YELLOW}📦 Checking access to required container images...\${NC}"'
printf '%s\n' ''
printf '%s\n' 'if ! docker pull --quiet "registry.scontain.com/scone.cloud/sconecli:\$SCONE_VERSION" &>/dev/null; then'
printf '%s\n' '      echo -e "\${RED}❌ Cannot pull Docker image - trying to log in\${NC}"'
printf '%s\n' '    # ask user for the credentials for accessing the registry'
printf '%s\n' '  eval \$(tplenv --values Values.credentials.yaml --file registry.credentials.md --create-values-file --eval --force )'
printf '%s\n' '  kubectl create secret docker-registry scontain --docker-server=\$REGISTRY --docker-username=\$REGISTRY_USER --docker-password=\$REGISTRY_TOKEN'
printf '%s\n' '      scone_registry_login'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' '  images=('
printf '%s\n' '    "registry.scontain.com/scone.cloud/sconecli:\$SCONE_VERSION"'
printf '%s\n' '    "registry.scontain.com/scone.cloud/scone-deb-pkgs:\$SCONE_VERSION"'
printf '%s\n' '    "registry.scontain.com/scone.cloud/sconecli:\$SCONE_VERSION"'
printf '%s\n' '    "registry.scontain.com/public-images/glibc:2.35-v4"'
printf '%s\n' '    "registry.scontain.com/public-images/glibc:2.39-v3"'
printf '%s\n' '  )'
printf '%s\n' '  for image in "\${images[@]}"; do'
printf '%s\n' '    if ! docker pull --quiet "\$image" &>/dev/null; then'
printf '%s\n' '      echo -e "\${RED}❌ Cannot pull Docker image: \$image\${NC}"'
printf '%s\n' '      exit 1'
printf '%s\n' '    else'
printf '%s\n' '      echo "✅ image '\''\$image'\'' is accessible"'
printf '%s\n' '    fi'
printf '%s\n' '  done'
printf '%s\n' '  echo -e "\${GREEN}✔️ All images are OK.\${NC}"'
printf "${RESET}"

echo "Environment variable SCONE_VERSION is set to $SCONE_VERSION"

echo -e "${YELLOW}📦 Checking access to required container images...${NC}"

if ! docker pull --quiet "registry.scontain.com/scone.cloud/sconecli:$SCONE_VERSION" &>/dev/null; then
      echo -e "${RED}❌ Cannot pull Docker image - trying to log in${NC}"
    # ask user for the credentials for accessing the registry
  eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --create-values-file --eval --force )
  kubectl create secret docker-registry scontain --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
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
printf '%s\n' '## Install SCONE CLI tools'
printf '%s\n' ''
printf '%s\n' 'We succeeded to pull the required, images. Next, we can install the `scone`-replated executable. To do so, you can run script `./scripts/install_sconecli.sh`.'
printf "${RESET}"

