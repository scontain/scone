#!/usr/bin/env bash

set -Eeuo pipefail

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
  local display_cmd
  display_cmd=$(printf "%s" "$cmd" | sed 's/\$/\\$/g')
  printf "%b" "$ORANGE"
  slow_type "$display_cmd"
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
printf '%s\n' '# Checking Prerequisites'
printf '%s\n' ''
printf '%s\n' '## Ensure that `cargo` is installed'
printf '%s\n' ''
printf '%s\n' 'We install some utilities with the help of `cargo`. Hence, we first ensure that `rust` and `cargo` are installed'
printf '%s\n' 'with the help of `scripts/install-rust.sh` that checks if `rust` and important components are installed and installs'
printf '%s\n' '`rust`. '
printf '%s\n' ''
printf "%b" "$RESET"

pe '# ensuring that rust is installed'
pe './scripts/install-rust.sh'
pe '# ensure PATH is properly set:'
pe 'export PATH=$HOME/.cargo/bin:$PATH'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'We use helper programs `tplenv` and `retry-spinner`. Hence, we ensure that they are installed:'
printf '%s\n' ''
printf "%b" "$RESET"

pe '# ensuring that tplenv is installed'
pe 'cargo install tplenv'
pe '# ensuring that retry-spinner is installed'
pe 'cargo install retry-spinner'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Environment Variables'
printf '%s\n' ''
printf '%s\n' 'By default, we install the latest stable version of SCONE. You can overwrite the version by setting environment variable `SCONE_VERSION` to the SCONE version that you want to install:'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'export SCONE_VERSION=$(cat stable.txt)'
pe 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""'

printf "%b" "$LILAC"
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
printf "%b" "$RESET"

pe 'eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'

printf "%b" "$LILAC"
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
printf "%b" "$RESET"

pe 'GREEN='\''\033[0;32m'\'''
pe 'YELLOW='\''\033[1;33m'\'''
pe 'RED='\''\033[0;31m'\'''
pe 'NC='\''\033[0m'\'' # No Color'
pe ''
pe 'check_command() {'
pe '  command -v "$1" &>/dev/null'
pe '}'
pe ''
pe 'scone_registry_login() {'
pe '    if [[ -n "${REGISTRY_TOKEN}" && -n "${REGISTRY_USER}" ]]; then'
pe '        echo "Attempting docker login..."'
pe '        echo "${REGISTRY_TOKEN}" | docker login ${REGISTRY} --username "${REGISTRY_USER}" --password-stdin'
pe '    else'
pe '        echo "Skipping docker login - REGISTRY_TOKEN or REGISTRY_USER not set or empty"'
pe '        echo "WARNING: Cannot access private SCONE images without login"'
pe '    fi'
pe '}'
pe ''
pe '# Auto-install Cosign if not present'
pe 'if ! check_command cosign; then'
pe '  echo "📥 Installing Cosign..."'
pe '  curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"'
pe '  sudo mv cosign-linux-amd64 /usr/local/bin/cosign'
pe '  sudo chmod +x /usr/local/bin/cosign'
pe '  echo "✔️ Cosign installed successfully."'
pe 'else'
pe '  echo "✔️ Cosign is already installed."'
pe 'fi'
pe ''
pe '# Auto-install Docker if not present'
pe 'if ! check_command docker; then'
pe '  echo "📥 Installing Docker..."'
pe '  curl -fsSL https://get.docker.com | sh'
pe '  echo "✔️ Docker installed successfully. Please log out and back in for group changes to take effect."'
pe 'else'
pe '  echo "✔️ Docker is already installed."'
pe 'fi'
pe ''
pe '# Auto-install GitHub CLI if not present'
pe 'if ! check_command gh; then'
pe '  echo "📥 Installing GitHub CLI..."'
pe '  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg'
pe '  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null'
pe '  sudo apt update'
pe '  sudo apt install -y gh'
pe '  echo "✔️ GitHub CLI installed successfully."'
pe 'else'
pe '  echo "✔️ GitHub CLI is already installed."'
pe 'fi'
pe ''
pe '# Auto-install kubectl if not present'
pe 'if ! check_command kubectl; then'
pe '  echo "📥 Installing kubectl..."'
pe '  export KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)'
pe '  curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl'
pe '  curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256'
pe '  echo "$(cat kubectl.sha256) kubectl" | sha256sum --check'
pe '  sudo chmod +x kubectl'
pe '  sudo mv ./kubectl /usr/local/bin/'
pe '  rm kubectl.sha256'
pe '  echo "✔️ kubectl installed successfully."'
pe 'else'
pe '  echo "✔️ kubectl is already installed."'
pe 'fi'
pe ''
pe 'install_yq_v4() {'
pe '  YQ_VERSION="v4.46.1"'
pe '  sudo apt update'
pe '  sudo apt install -y --no-install-recommends xz-utils'
pe '  curl -L "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64.tar.gz" | sudo tar xz -C /usr/local/bin'
pe '  sudo chmod +x /usr/local/bin/yq_linux_amd64'
pe '  sudo ln -sf /usr/local/bin/yq_linux_amd64 /usr/local/bin/yq'
pe '  echo "✔️ yq installed successfully."'
pe '}'
pe ''
pe '# Check and Auto install Yq Version 4'
pe 'if check_command yq; then'
pe '    yq_version=$(yq --version 2>&1 | grep  -oE '\''v[0-9]+'\'' | cut -d'\''v'\'' -f2) || yq_version=""'
pe '    if [[ -z "$yq_version" || "$yq_version" == "0" ]]; then'
pe '        echo -e "${RED}❌ Found yq version $yq_version which is not supported. Installing Yq v4"'
pe '        install_yq_v4'
pe '    fi'
pe '    if [[ "$yq_version" -ge 4 ]]; then'
pe '        echo "✔️ yq v$yq_version is installed (meets requirement v4+)."'
pe '    else'
pe '        echo -e "${RED}❌ yq version $yq_version is too old. Installing Yq v4"'
pe '        install_yq_v4'
pe '    fi'
pe 'else'
pe '    echo -e "${RED}❌ yq is not installed. Installing Yq v4"'
pe '    install_yq_v4'
pe 'fi'
pe ''
pe '# Auto-install other required packages'
pe 'missing_packages=()'
pe 'for pkg in pkg-config jq libssl-dev; do'
pe '  if ! dpkg -s "$pkg" &>/dev/null; then'
pe '    missing_packages+=("$pkg")'
pe '  fi'
pe 'done'
pe ''
pe 'if [ ${#missing_packages[@]} -ne 0 ]; then'
pe '  echo "📥 Installing missing packages: ${missing_packages[*]}"'
pe '  sudo apt update'
pe '  sudo apt install -y "${missing_packages[@]}"'
pe '  echo "✔️ All missing packages installed successfully."'
pe 'fi'
pe ''
pe '# sed is typically pre-installed on Ubuntu, but check anyway'
pe 'if ! check_command sed; then'
pe '  echo "📥 Installing sed..."'
pe '  sudo apt update'
pe '  sudo apt install -y sed'
pe '  echo "✔️ sed installed successfully."'
pe 'else'
pe '  echo "✔️ sed is already installed."'
pe 'fi'
pe ''
pe '# Check Kubernetes cluster connectivity'
pe 'if ! kubectl cluster-info &>/dev/null; then'
pe '  echo -e "${RED}❌ No Kubernetes cluster detected via kubectl. Is your cluster running?${NC}"'
pe 'fi'
pe ''
pe 'echo "✅ All external executables are installed and ready"'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Check access to `scone.cloud` images'
printf '%s\n' ''
printf '%s\n' 'We check that we can pull some SCONE container images that we need to execute'
printf '%s\n' 'the transformations. If this fail, please do the following:'
printf '%s\n' ''
printf '%s\n' '- generate an access token following these instructions: <https://sconedocs.github.io/registry/#create-an-access-token>'
printf '%s\n' ''
printf "%b" "$RESET"

pe 'echo "Environment variable SCONE_VERSION is set to $SCONE_VERSION"'
pe ''
pe 'echo -e "${YELLOW}📦 Checking access to required container images...${NC}"'
pe ''
pe 'if ! docker pull --quiet "registry.scontain.com/scone.cloud/sconecli:$SCONE_VERSION" &>/dev/null; then'
pe '      echo -e "${RED}❌ Cannot pull Docker image - trying to log in${NC}"'
pe '    # ask user for the credentials for accessing the registry'
pe '  eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --create-values-file --eval --force )'
pe '  kubectl create secret docker-registry scontain --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN'
pe '      scone_registry_login'
pe 'fi'
pe ''
pe '  images=('
pe '    "registry.scontain.com/scone.cloud/sconecli:$SCONE_VERSION"'
pe '    "registry.scontain.com/scone.cloud/scone-deb-pkgs:$SCONE_VERSION"'
pe '    "registry.scontain.com/scone.cloud/sconecli:$SCONE_VERSION"'
pe '    "registry.scontain.com/public-images/glibc:2.35-v4"'
pe '    "registry.scontain.com/public-images/glibc:2.39-v3"'
pe '  )'
pe '  for image in "${images[@]}"; do'
pe '    if ! docker pull --quiet "$image" &>/dev/null; then'
pe '      echo -e "${RED}❌ Cannot pull Docker image: $image${NC}"'
pe '      exit 1'
pe '    else'
pe '      echo "✅ image '\''$image'\'' is accessible"'
pe '    fi'
pe '  done'
pe '  echo -e "${GREEN}✔️ All images are OK.${NC}"'

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Install SCONE CLI tools'
printf '%s\n' ''
printf '%s\n' 'We succeeded to pull the required, images. Next, we can install the `scone`-replated executable. To do so, you can run script `./scripts/install_sconecli.sh`.'
printf "%b" "$RESET"

