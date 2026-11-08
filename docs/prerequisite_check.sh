#!/usr/bin/env bash

set -Eeuo pipefail
export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""

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
printf '%s\n' '## Ensure `cargo` Is Installed'
printf '%s\n' ''
printf '%s\n' 'We install some utilities with `cargo`, so we first ensure that `rust` and `cargo` are installed. Use `scripts/install-rust.sh`, which checks for `rust` and required components and installs them if needed.'
printf '%s\n' ''
printf '%s\n' '![Screencast](docs/prerequisite_check.gif)'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Ensure rust is installed
EOF
)"
pe "$(cat <<'EOF'
./scripts/install-rust.sh
EOF
)"
pe "$(cat <<'EOF'
# Ensure PATH is set correctly
EOF
)"
pe "$(cat <<'EOF'
export PATH=$HOME/.cargo/bin:$PATH
EOF
)"
pe "$(cat <<'EOF'
# Add to PATH for all future shells
EOF
)"
pe "$(cat <<'EOF'
grep -q '.cargo/bin' ~/.bashrc || echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'We use the helper programs `tplenv` and `retry-spinner`, so ensure they are installed:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Ensure tplenv is installed
EOF
)"
pe "$(cat <<'EOF'
cargo install tplenv
EOF
)"
pe "$(cat <<'EOF'
# Ensure retry-spinner is installed
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
printf '%s\n' 'By default, we install the latest stable SCONE version. You can override this by setting `SCONE_VERSION` to the version you want to install:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
export SCONE_VERSION="${SCONE_VERSION:-$(cat stable.txt)}"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '`tplenv` asks for all environment variables described in `environment-variables.md` that are not yet set.'
printf '%s\n' ''
printf '%s\n' 'Run the following to prompt for and set missing variables:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
EOF
)"

printf "%b" "$LILAC"
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
printf '%s\n' 'On **Linux**, we install missing tools with `apt` and the Docker install script, so this works on'
printf '%s\n' 'Debian and Ubuntu. On **macOS** (Apple Silicon and Intel), we install missing tools with'
printf '%s\n' '[Homebrew](https://brew.sh) (`brew install gh kubectl helm yq pkg-config jq openssl@3`, where'
printf '%s\n' '`openssl@3` replaces `libssl-dev`). Without Homebrew, the script names the missing tool and stops.'
printf '%s\n' 'Docker cannot be installed by script on macOS: install and start'
printf '%s\n' '[Docker Desktop](https://docs.docker.com/desktop/setup/install/mac-install/) (or another Docker'
printf '%s\n' 'engine, e.g., Colima) first. On macOS, the script prepares the Kubernetes path of the README;'
printf '%s\n' 'the SCONE CLI itself needs x86_64 Linux (see [Install SCONE CLI Tools](#install-scone-cli-tools)).'
printf '%s\n' ''
printf '%s\n' '`cosign` 2.0.0 or newer verifies the SCONE package images. The workshop image is signed with'
printf '%s\n' 'cosign 3, so verifying it needs cosign 3.0.0 or newer. If `cosign` is missing or older than'
printf '%s\n' '3.0.0, we install the binary for this OS and CPU from the latest cosign release as'
printf '%s\n' '`/usr/local/bin/cosign`. Set `COSIGN_RELEASE` (e.g., `v3.1.4`) to install a specific release.'
printf '%s\n' 'The binary must match the checksums of its release and run on this machine before it replaces'
printf '%s\n' 'the installed `cosign`. If the update fails, an installed cosign 2.x is kept: it still verifies'
printf '%s\n' 'the package images, but the installation then keeps the tools of the package image instead'
printf '%s\n' 'of the workshop image'\''s.'
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
# On macOS, we install missing tools with Homebrew instead of apt.
EOF
)"
pe "$(cat <<'EOF'
is_macos() {
EOF
)"
pe "$(cat <<'EOF'
  [[ "$(uname -s)" == Darwin ]]
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
brew_install() {
EOF
)"
pe "$(cat <<'EOF'
  if ! check_command brew; then
EOF
)"
pe "$(cat <<'EOF'
    echo -e "${RED}❌ Missing on this Mac: $*. Install Homebrew (https://brew.sh) and run this script again, or install $* yourself.${NC}"
EOF
)"
pe "$(cat <<'EOF'
    exit 1
EOF
)"
pe "$(cat <<'EOF'
  fi
EOF
)"
pe "$(cat <<'EOF'
  brew install "$@"
EOF
)"
pe "$(cat <<'EOF'
  hash -r
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
# cosign >= 2.0.0 verifies the SCONE package images. Images signed with cosign 3.x in its
EOF
)"
pe "$(cat <<'EOF'
# bundle format, such as the workshop image built by ./scripts/build.sh, need cosign >= 3.0.0.
EOF
)"
pe "$(cat <<'EOF'
COSIGN_MIN_VERSION="${COSIGN_MIN_VERSION:-2.0.0}"
EOF
)"
pe "$(cat <<'EOF'
COSIGN_BUNDLE_MIN_VERSION="${COSIGN_BUNDLE_MIN_VERSION:-3.0.0}"
EOF
)"
pe "$(cat <<'EOF'
# The cosign release to install, e.g., v3.1.4. Default: the latest release.
EOF
)"
pe "$(cat <<'EOF'
COSIGN_RELEASE="${COSIGN_RELEASE:-latest}"
EOF
)"
pe "$(cat <<'EOF'
COSIGN_INSTALL_PATH="${COSIGN_INSTALL_PATH:-/usr/local/bin/cosign}"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Prints the version (e.g., 2.4.1) of cosign, or of the cosign binary $1, or nothing if unknown.
EOF
)"
pe "$(cat <<'EOF'
cosign_version() {
EOF
)"
pe "$(cat <<'EOF'
  "${1:-cosign}" version 2>/dev/null | grep -Eo 'GitVersion: *v?[0-9]+\.[0-9]+\.[0-9]+' | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true
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
# Succeeds if cosign is installed and its version is at least $1 (default: COSIGN_MIN_VERSION).
EOF
)"
pe "$(cat <<'EOF'
cosign_version_ok() {
EOF
)"
pe "$(cat <<'EOF'
  local version min_version="${1:-$COSIGN_MIN_VERSION}"
EOF
)"
pe "$(cat <<'EOF'
  check_command cosign || return 1
EOF
)"
pe "$(cat <<'EOF'
  version="$(cosign_version)"
EOF
)"
pe "$(cat <<'EOF'
  [[ -n "$version" ]] || return 1
EOF
)"
pe "$(cat <<'EOF'
  [[ "$(printf '%s\n%s\n' "$min_version" "$version" | sort -V | head -n 1)" == "$min_version" ]]
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
# Installs the cosign binary of COSIGN_RELEASE for this OS and CPU as COSIGN_INSTALL_PATH.
EOF
)"
pe "$(cat <<'EOF'
# The binary must match the release checksums and run before it replaces an installed cosign.
EOF
)"
pe "$(cat <<'EOF'
install_cosign() (
EOF
)"
pe "$(cat <<'EOF'
  case "$(uname -s)" in
EOF
)"
pe "$(cat <<'EOF'
    Linux) os=linux ;;
EOF
)"
pe "$(cat <<'EOF'
    Darwin) os=darwin ;;
EOF
)"
pe "$(cat <<'EOF'
    *) echo "No cosign release for OS $(uname -s)"; exit 1 ;;
EOF
)"
pe "$(cat <<'EOF'
  esac
EOF
)"
pe "$(cat <<'EOF'
  case "$(uname -m)" in
EOF
)"
pe "$(cat <<'EOF'
    x86_64|amd64) arch=amd64 ;;
EOF
)"
pe "$(cat <<'EOF'
    aarch64|arm64) arch=arm64 ;;
EOF
)"
pe "$(cat <<'EOF'
    *) echo "No cosign release for CPU $(uname -m)"; exit 1 ;;
EOF
)"
pe "$(cat <<'EOF'
  esac
EOF
)"
pe "$(cat <<'EOF'
  asset="cosign-$os-$arch"
EOF
)"
pe "$(cat <<'EOF'
  tag="$COSIGN_RELEASE"
EOF
)"
pe "$(cat <<'EOF'
  if [[ "$tag" == latest ]]; then
EOF
)"
pe "$(cat <<'EOF'
    # Resolve the tag once, so the binary and the checksums come from the same release.
EOF
)"
pe "$(cat <<'EOF'
    tag="$(curl -fsSIL --retry 3 -o /dev/null -w '%{url_effective}' https://github.com/sigstore/cosign/releases/latest)" || { echo "Cannot determine the latest cosign release"; exit 1; }
EOF
)"
pe "$(cat <<'EOF'
    tag="${tag##*/}"
EOF
)"
pe "$(cat <<'EOF'
  fi
EOF
)"
pe "$(cat <<'EOF'
  if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
EOF
)"
pe "$(cat <<'EOF'
    echo "Unexpected cosign release '$tag'"
EOF
)"
pe "$(cat <<'EOF'
    exit 1
EOF
)"
pe "$(cat <<'EOF'
  fi
EOF
)"
pe "$(cat <<'EOF'
  url="https://github.com/sigstore/cosign/releases/download/$tag"
EOF
)"
pe "$(cat <<'EOF'
  tmp="$(mktemp -d)"
EOF
)"
pe "$(cat <<'EOF'
  trap 'rm -rf "$tmp"' EXIT
EOF
)"
pe "$(cat <<'EOF'
  echo "Downloading $url/$asset"
EOF
)"
pe "$(cat <<'EOF'
  if ! curl -fsSL --retry 3 -o "$tmp/$asset" "$url/$asset" \
    || ! curl -fsSL --retry 3 -o "$tmp/cosign_checksums.txt" "$url/cosign_checksums.txt"; then
EOF
)"
pe "$(cat <<'EOF'
    echo "Download of cosign $tag failed"
EOF
)"
pe "$(cat <<'EOF'
    exit 1
EOF
)"
pe "$(cat <<'EOF'
  fi
EOF
)"
pe "$(cat <<'EOF'
  expected="$(awk -v f="$asset" '$2 == f { print $1 }' "$tmp/cosign_checksums.txt")"
EOF
)"
pe "$(cat <<'EOF'
  if check_command sha256sum; then
EOF
)"
pe "$(cat <<'EOF'
    actual="$(sha256sum "$tmp/$asset" | awk '{ print $1 }')"
EOF
)"
pe "$(cat <<'EOF'
  else
EOF
)"
pe "$(cat <<'EOF'
    actual="$(shasum -a 256 "$tmp/$asset" | awk '{ print $1 }')"
EOF
)"
pe "$(cat <<'EOF'
  fi
EOF
)"
pe "$(cat <<'EOF'
  if [[ -z "$expected" || "$actual" != "$expected" ]]; then
EOF
)"
pe "$(cat <<'EOF'
    echo "Checksum of $asset does not match cosign_checksums.txt of cosign $tag"
EOF
)"
pe "$(cat <<'EOF'
    exit 1
EOF
)"
pe "$(cat <<'EOF'
  fi
EOF
)"
pe "$(cat <<'EOF'
  chmod +x "$tmp/$asset"
EOF
)"
pe "$(cat <<'EOF'
  if [[ -z "$(cosign_version "$tmp/$asset")" ]]; then
EOF
)"
pe "$(cat <<'EOF'
    echo "The downloaded $asset does not run on this machine"
EOF
)"
pe "$(cat <<'EOF'
    exit 1
EOF
)"
pe "$(cat <<'EOF'
  fi
EOF
)"
pe "$(cat <<'EOF'
  sudo mkdir -p "$(dirname "$COSIGN_INSTALL_PATH")" && sudo install -m 0755 "$tmp/$asset" "$COSIGN_INSTALL_PATH"
EOF
)"
pe "$(cat <<'EOF'
)
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Install Cosign if it is missing, or update it if it cannot verify the workshop image
EOF
)"
pe "$(cat <<'EOF'
if cosign_version_ok "$COSIGN_BUNDLE_MIN_VERSION"; then
EOF
)"
pe "$(cat <<'EOF'
  echo "✔️ Cosign $(cosign_version) is already installed."
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  if check_command cosign; then
EOF
)"
pe "$(cat <<'EOF'
    echo "📥 Cosign '$(cosign_version)' of $(command -v cosign) is older than $COSIGN_BUNDLE_MIN_VERSION: installing Cosign $COSIGN_RELEASE..."
EOF
)"
pe "$(cat <<'EOF'
  else
EOF
)"
pe "$(cat <<'EOF'
    echo "📥 Installing Cosign $COSIGN_RELEASE..."
EOF
)"
pe "$(cat <<'EOF'
  fi
EOF
)"
pe "$(cat <<'EOF'
  if install_cosign; then
EOF
)"
pe "$(cat <<'EOF'
    hash -r
EOF
)"
pe "$(cat <<'EOF'
    if [[ "$(command -v cosign)" != "$COSIGN_INSTALL_PATH" ]]; then
EOF
)"
pe "$(cat <<'EOF'
      echo -e "${YELLOW}⚠️ Installed cosign $(cosign_version "$COSIGN_INSTALL_PATH") as $COSIGN_INSTALL_PATH, but $(command -v cosign) comes first in your PATH: remove it or put $(dirname "$COSIGN_INSTALL_PATH") first.${NC}"
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
    echo -e "${YELLOW}⚠️ Could not install cosign: see the message above.${NC}"
EOF
)"
pe "$(cat <<'EOF'
  fi
EOF
)"
pe "$(cat <<'EOF'
  if cosign_version_ok "$COSIGN_BUNDLE_MIN_VERSION"; then
EOF
)"
pe "$(cat <<'EOF'
    echo "✔️ Cosign $(cosign_version) installed successfully."
EOF
)"
pe "$(cat <<'EOF'
  elif cosign_version_ok; then
EOF
)"
pe "$(cat <<'EOF'
    echo -e "${YELLOW}⚠️ Using cosign $(cosign_version) of $(command -v cosign): it verifies the SCONE package images, but not the workshop image, which needs cosign >= $COSIGN_BUNDLE_MIN_VERSION.${NC}"
EOF
)"
pe "$(cat <<'EOF'
  else
EOF
)"
pe "$(cat <<'EOF'
    if check_command cosign; then
EOF
)"
pe "$(cat <<'EOF'
      echo -e "${RED}❌ We need cosign >= $COSIGN_MIN_VERSION to verify the SCONE images, but $(command -v cosign) is cosign '$(cosign_version)'.${NC}"
EOF
)"
pe "$(cat <<'EOF'
    else
EOF
)"
pe "$(cat <<'EOF'
      echo -e "${RED}❌ We need cosign >= $COSIGN_MIN_VERSION to verify the SCONE images, but no cosign is installed.${NC}"
EOF
)"
pe "$(cat <<'EOF'
    fi
EOF
)"
pe "$(cat <<'EOF'
    exit 1
EOF
)"
pe "$(cat <<'EOF'
  fi
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
  if is_macos; then
EOF
)"
pe "$(cat <<'EOF'
    # get.docker.com supports Linux only.
EOF
)"
pe "$(cat <<'EOF'
    echo -e "${RED}❌ Docker is not installed. On macOS, install Docker Desktop (https://docs.docker.com/desktop/setup/install/mac-install/) or another Docker engine, start it, and run this script again.${NC}"
EOF
)"
pe "$(cat <<'EOF'
    exit 1
EOF
)"
pe "$(cat <<'EOF'
  fi
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
# Ensure that we can run docker without being root
EOF
)"
pe "$(cat <<'EOF'
./scripts/check_docker_setup.sh
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
  if is_macos; then
EOF
)"
pe "$(cat <<'EOF'
    brew_install gh
EOF
)"
pe "$(cat <<'EOF'
  else
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
  fi
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
  if is_macos; then
EOF
)"
pe "$(cat <<'EOF'
    brew_install kubectl
EOF
)"
pe "$(cat <<'EOF'
  else
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
  fi
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
# Auto-install Helm if not present
EOF
)"
pe "$(cat <<'EOF'
if ! check_command helm; then
EOF
)"
pe "$(cat <<'EOF'
  echo "📥 Installing Helm..."
EOF
)"
pe "$(cat <<'EOF'
  if is_macos; then
EOF
)"
pe "$(cat <<'EOF'
    brew_install helm
EOF
)"
pe "$(cat <<'EOF'
  else
EOF
)"
pe "$(cat <<'EOF'
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
EOF
)"
pe "$(cat <<'EOF'
  fi
EOF
)"
pe "$(cat <<'EOF'
  echo "✔️ Helm installed successfully."
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  echo "✔️ Helm is already installed."
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
  if is_macos; then
EOF
)"
pe "$(cat <<'EOF'
    # Homebrew's yq is mikefarah/yq v4.
EOF
)"
pe "$(cat <<'EOF'
    brew_install yq
EOF
)"
pe "$(cat <<'EOF'
    echo "✔️ yq installed successfully."
EOF
)"
pe "$(cat <<'EOF'
    return
EOF
)"
pe "$(cat <<'EOF'
  fi
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
# Check and auto-install yq v4
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
if is_macos; then
EOF
)"
pe "$(cat <<'EOF'
  # Homebrew's openssl@3 provides what libssl-dev provides on Debian. It is keg-only,
EOF
)"
pe "$(cat <<'EOF'
  # so pkg-config does not see it unless PKG_CONFIG_PATH points to it: ask brew as well.
EOF
)"
pe "$(cat <<'EOF'
  for pkg in pkg-config jq; do
EOF
)"
pe "$(cat <<'EOF'
    if ! check_command "$pkg"; then
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
  if ! { check_command brew && brew list --formula openssl@3 &>/dev/null; } \
    && ! pkg-config --exists openssl &>/dev/null; then
EOF
)"
pe "$(cat <<'EOF'
    missing_packages+=("openssl@3")
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
fi
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
  if is_macos; then
EOF
)"
pe "$(cat <<'EOF'
    brew_install "${missing_packages[@]}"
EOF
)"
pe "$(cat <<'EOF'
  else
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
  fi
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
printf '%s\n' '## Check Access to `scone.cloud` Images'
printf '%s\n' ''
printf '%s\n' 'Check that you can pull the SCONE container images required for transformations. If this fails, do the following:'
printf '%s\n' ''
printf '%s\n' '- Generate an access token by following these instructions: <https://sconedocs.github.io/registry/#create-an-access-token>'
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
  eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --create-values-file --context --eval --force )
EOF
)"
pe "$(cat <<'EOF'
    kubectl create secret docker-registry sconeapps --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN || true
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
printf '%s\n' '## Install SCONE CLI Tools'
printf '%s\n' ''
printf '%s\n' 'The required images are now available. Next, install the `scone`-related executables by running `./scripts/install_sconecli.sh`.'
printf '%s\n' ''
printf '%s\n' 'The SCONE CLI packages run on x86_64 Linux only, so `./scripts/install_sconecli.sh` stops on'
printf '%s\n' 'other hosts, e.g., on macOS. There, run the SCONE CLI in the workshop image instead: on an x86_64'
printf '%s\n' 'machine with Docker (see "Run the Workshop Image" in the [README](README.md)), or in a Kubernetes'
printf '%s\n' 'cluster with x86_64 nodes with `./scripts/k8s_cli.sh` (see [k8s.md](k8s.md)).'
printf "%b" "$RESET"

