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
printf '%s\n' '# Checking Prerequisites'
printf '%s\n' ''
printf '%s\n' '## Ensure that `cargo` is installed'
printf '%s\n' ''
printf '%s\n' 'We install some utilities with the help of `cargo`. Hence, we first ensure that `rust` and `cargo` are installed'
printf '%s\n' 'with the help of `scripts/install-rust.sh` that checks if `rust` and important components are installed and installs'
printf '%s\n' '`rust`. '
printf '%s\n' ''
printf '%s\n' '![Screencast](docs/prerequisite_check.gif)'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# ensuring that rust is installed
EOF
)"
pe "$(cat <<'EOF'
./scripts/install-rust.sh
EOF
)"
pe "$(cat <<'EOF'
# ensure PATH is properly set:
EOF
)"
pe "$(cat <<'EOF'
export PATH=$HOME/.cargo/bin:$PATH
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'We use helper programs `tplenv` and `retry-spinner`. Hence, we ensure that they are installed:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# ensuring that tplenv is installed
EOF
)"
pe "$(cat <<'EOF'
cargo install tplenv
EOF
)"
pe "$(cat <<'EOF'
# ensuring that retry-spinner is installed
EOF
)"
pe "$(cat <<'EOF'
cargo install retry-spinner
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Environment Variables'
printf '%s\n' ''
printf '%s\n' 'By default, we install the latest stable version of SCONE. You can overwrite the version by setting environment variable `SCONE_VERSION` to the SCONE version that you want to install:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
export SCONE_VERSION=$(cat stable.txt)
EOF
)"
pe "$(cat <<'EOF'
export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""
EOF
)"

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

pe "$(cat <<'EOF'
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )
EOF
)"

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

pe "$(cat <<'EOF'
GREEN='\033[0;32m'
EOF
)"
pe "$(cat <<'EOF'
YELLOW='\033[1;33m'
EOF
)"
pe "$(cat <<'EOF'
RED='\033[0;31m'
EOF
)"
pe "$(cat <<'EOF'
NC='\033[0m' # No Color
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
check_command() {
EOF
)"
pe "$(cat <<'EOF'
  command -v "$1" &>/dev/null
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
scone_registry_login() {
EOF
)"
pe "$(cat <<'EOF'
    if [[ -n "${REGISTRY_TOKEN}" && -n "${REGISTRY_USER}" ]]; then
EOF
)"
pe "$(cat <<'EOF'
        echo "Attempting docker login..."
EOF
)"
pe "$(cat <<'EOF'
        echo "${REGISTRY_TOKEN}" | docker login ${REGISTRY} --username "${REGISTRY_USER}" --password-stdin
EOF
)"
pe "$(cat <<'EOF'
    else
EOF
)"
pe "$(cat <<'EOF'
        echo "Skipping docker login - REGISTRY_TOKEN or REGISTRY_USER not set or empty"
EOF
)"
pe "$(cat <<'EOF'
        echo "WARNING: Cannot access private SCONE images without login"
EOF
)"
pe "$(cat <<'EOF'
    fi
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
# Auto-install Cosign if not present
EOF
)"
pe "$(cat <<'EOF'
if ! check_command cosign; then
EOF
)"
pe "$(cat <<'EOF'
  echo "📥 Installing Cosign..."
EOF
)"
pe "$(cat <<'EOF'
  curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
EOF
)"
pe "$(cat <<'EOF'
  sudo mv cosign-linux-amd64 /usr/local/bin/cosign
EOF
)"
pe "$(cat <<'EOF'
  sudo chmod +x /usr/local/bin/cosign
EOF
)"
pe "$(cat <<'EOF'
  echo "✔️ Cosign installed successfully."
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  echo "✔️ Cosign is already installed."
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
# Auto-install Docker if not present
EOF
)"
pe "$(cat <<'EOF'
if ! check_command docker; then
EOF
)"
pe "$(cat <<'EOF'
  echo "📥 Installing Docker..."
EOF
)"
pe "$(cat <<'EOF'
  curl -fsSL https://get.docker.com | sh
EOF
)"
pe "$(cat <<'EOF'
  echo "✔️ Docker installed successfully. Please log out and back in for group changes to take effect."
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  echo "✔️ Docker is already installed."
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
# Auto-install GitHub CLI if not present
EOF
)"
pe "$(cat <<'EOF'
if ! check_command gh; then
EOF
)"
pe "$(cat <<'EOF'
  echo "📥 Installing GitHub CLI..."
EOF
)"
pe "$(cat <<'EOF'
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
EOF
)"
pe "$(cat <<'EOF'
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
EOF
)"
pe "$(cat <<'EOF'
  sudo apt update
EOF
)"
pe "$(cat <<'EOF'
  sudo apt install -y gh
EOF
)"
pe "$(cat <<'EOF'
  echo "✔️ GitHub CLI installed successfully."
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  echo "✔️ GitHub CLI is already installed."
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
# Auto-install kubectl if not present
EOF
)"
pe "$(cat <<'EOF'
if ! check_command kubectl; then
EOF
)"
pe "$(cat <<'EOF'
  echo "📥 Installing kubectl..."
EOF
)"
pe "$(cat <<'EOF'
  export KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
EOF
)"
pe "$(cat <<'EOF'
  curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl
EOF
)"
pe "$(cat <<'EOF'
  curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256
EOF
)"
pe "$(cat <<'EOF'
  echo "$(cat kubectl.sha256) kubectl" | sha256sum --check
EOF
)"
pe "$(cat <<'EOF'
  sudo chmod +x kubectl
EOF
)"
pe "$(cat <<'EOF'
  sudo mv ./kubectl /usr/local/bin/
EOF
)"
pe "$(cat <<'EOF'
  rm kubectl.sha256
EOF
)"
pe "$(cat <<'EOF'
  echo "✔️ kubectl installed successfully."
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  echo "✔️ kubectl is already installed."
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
install_yq_v4() {
EOF
)"
pe "$(cat <<'EOF'
  YQ_VERSION="v4.46.1"
EOF
)"
pe "$(cat <<'EOF'
  sudo apt update
EOF
)"
pe "$(cat <<'EOF'
  sudo apt install -y --no-install-recommends xz-utils
EOF
)"
pe "$(cat <<'EOF'
  curl -L "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64.tar.gz" | sudo tar xz -C /usr/local/bin
EOF
)"
pe "$(cat <<'EOF'
  sudo chmod +x /usr/local/bin/yq_linux_amd64
EOF
)"
pe "$(cat <<'EOF'
  sudo ln -sf /usr/local/bin/yq_linux_amd64 /usr/local/bin/yq
EOF
)"
pe "$(cat <<'EOF'
  echo "✔️ yq installed successfully."
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
# Check and Auto install Yq Version 4
EOF
)"
pe "$(cat <<'EOF'
if check_command yq; then
EOF
)"
pe "$(cat <<'EOF'
    yq_version=$(yq --version 2>&1 | grep  -oE 'v[0-9]+' | cut -d'v' -f2) || yq_version=""
EOF
)"
pe "$(cat <<'EOF'
    if [[ -z "$yq_version" || "$yq_version" == "0" ]]; then
EOF
)"
pe "$(cat <<'EOF'
        echo -e "${RED}❌ Found yq version $yq_version which is not supported. Installing Yq v4"
EOF
)"
pe "$(cat <<'EOF'
        install_yq_v4
EOF
)"
pe "$(cat <<'EOF'
    fi
EOF
)"
pe "$(cat <<'EOF'
    if [[ "$yq_version" -ge 4 ]]; then
EOF
)"
pe "$(cat <<'EOF'
        echo "✔️ yq v$yq_version is installed (meets requirement v4+)."
EOF
)"
pe "$(cat <<'EOF'
    else
EOF
)"
pe "$(cat <<'EOF'
        echo -e "${RED}❌ yq version $yq_version is too old. Installing Yq v4"
EOF
)"
pe "$(cat <<'EOF'
        install_yq_v4
EOF
)"
pe "$(cat <<'EOF'
    fi
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
    echo -e "${RED}❌ yq is not installed. Installing Yq v4"
EOF
)"
pe "$(cat <<'EOF'
    install_yq_v4
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
# Auto-install other required packages
EOF
)"
pe "$(cat <<'EOF'
missing_packages=()
EOF
)"
pe "$(cat <<'EOF'
for pkg in pkg-config jq libssl-dev; do
EOF
)"
pe "$(cat <<'EOF'
  if ! dpkg -s "$pkg" &>/dev/null; then
EOF
)"
pe "$(cat <<'EOF'
    missing_packages+=("$pkg")
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
if [ ${#missing_packages[@]} -ne 0 ]; then
EOF
)"
pe "$(cat <<'EOF'
  echo "📥 Installing missing packages: ${missing_packages[*]}"
EOF
)"
pe "$(cat <<'EOF'
  sudo apt update
EOF
)"
pe "$(cat <<'EOF'
  sudo apt install -y "${missing_packages[@]}"
EOF
)"
pe "$(cat <<'EOF'
  echo "✔️ All missing packages installed successfully."
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
# sed is typically pre-installed on Ubuntu, but check anyway
EOF
)"
pe "$(cat <<'EOF'
if ! check_command sed; then
EOF
)"
pe "$(cat <<'EOF'
  echo "📥 Installing sed..."
EOF
)"
pe "$(cat <<'EOF'
  sudo apt update
EOF
)"
pe "$(cat <<'EOF'
  sudo apt install -y sed
EOF
)"
pe "$(cat <<'EOF'
  echo "✔️ sed installed successfully."
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  echo "✔️ sed is already installed."
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
# Check Kubernetes cluster connectivity
EOF
)"
pe "$(cat <<'EOF'
if ! kubectl cluster-info &>/dev/null; then
EOF
)"
pe "$(cat <<'EOF'
  echo -e "${RED}❌ No Kubernetes cluster detected via kubectl. Is your cluster running?${NC}"
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
echo "✅ All external executables are installed and ready"
EOF
)"

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

pe "$(cat <<'EOF'
echo "Environment variable SCONE_VERSION is set to $SCONE_VERSION"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
echo -e "${YELLOW}📦 Checking access to required container images...${NC}"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
if ! docker pull --quiet "registry.scontain.com/scone.cloud/sconecli:$SCONE_VERSION" &>/dev/null; then
EOF
)"
pe "$(cat <<'EOF'
      echo -e "${RED}❌ Cannot pull Docker image - trying to log in${NC}"
EOF
)"
pe "$(cat <<'EOF'
    # ask user for the credentials for accessing the registry
EOF
)"
pe "$(cat <<'EOF'
  eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --create-values-file --eval --force )
EOF
)"
pe "$(cat <<'EOF'
  kubectl create secret docker-registry scontain --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
EOF
)"
pe "$(cat <<'EOF'
      scone_registry_login
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
  images=(
EOF
)"
pe "$(cat <<'EOF'
    "registry.scontain.com/scone.cloud/sconecli:$SCONE_VERSION"
EOF
)"
pe "$(cat <<'EOF'
    "registry.scontain.com/scone.cloud/scone-deb-pkgs:$SCONE_VERSION"
EOF
)"
pe "$(cat <<'EOF'
    "registry.scontain.com/scone.cloud/sconecli:$SCONE_VERSION"
EOF
)"
pe "$(cat <<'EOF'
    "registry.scontain.com/public-images/glibc:2.35-v4"
EOF
)"
pe "$(cat <<'EOF'
    "registry.scontain.com/public-images/glibc:2.39-v3"
EOF
)"
pe "$(cat <<'EOF'
  )
EOF
)"
pe "$(cat <<'EOF'
  for image in "${images[@]}"; do
EOF
)"
pe "$(cat <<'EOF'
    if ! docker pull --quiet "$image" &>/dev/null; then
EOF
)"
pe "$(cat <<'EOF'
      echo -e "${RED}❌ Cannot pull Docker image: $image${NC}"
EOF
)"
pe "$(cat <<'EOF'
      exit 1
EOF
)"
pe "$(cat <<'EOF'
    else
EOF
)"
pe "$(cat <<'EOF'
      echo "✅ image '$image' is accessible"
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
  echo -e "${GREEN}✔️ All images are OK.${NC}"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Install SCONE CLI tools'
printf '%s\n' ''
printf '%s\n' 'We succeeded to pull the required, images. Next, we can install the `scone`-replated executable. To do so, you can run script `./scripts/install_sconecli.sh`.'
printf "%b" "$RESET"

