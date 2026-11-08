#!/usr/bin/env bash

set -euo pipefail
export CONFIRM_ALL_ENVIRONMENT_VARIABLES=${CONFIRM_ALL_ENVIRONMENT_VARIABLES-"--force"}

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
printf '%s\n' 'export SCONE_VERSION="${SCONE_VERSION:-$(cat stable.txt)}"'
printf "${RESET}"

export SCONE_VERSION="${SCONE_VERSION:-$(cat stable.txt)}"

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
printf '%s\n' '# On macOS, we install missing tools with Homebrew instead of apt.'
printf '%s\n' 'is_macos() {'
printf '%s\n' '  [[ "$(uname -s)" == Darwin ]]'
printf '%s\n' '}'
printf '%s\n' ''
printf '%s\n' '# Succeeds if you sourced this script (". ./scripts/prerequisite_check.sh"), as the README says:'
printf '%s\n' '# then BASH_SOURCE[0] is this script and $0 is your shell. zsh, which has no BASH_SOURCE, can'
printf '%s\n' '# only source this script.'
printf '%s\n' 'is_sourced() {'
printf '%s\n' '  [[ "${BASH_SOURCE[0]:-}" != "$0" ]]'
printf '%s\n' '}'
printf '%s\n' ''
printf '%s\n' '# If something is missing, we stop with "stop_check || return 1 2>/dev/null || exit 1": it'
printf '%s\n' '# returns to your shell if you sourced this script, and exits with 1 if you ran it. "exit 1"'
printf '%s\n' '# would close your shell, and so would "return 1" while the "set -e" of this script is on:'
printf '%s\n' '# stop_check turns "set -e" off if you sourced this script.'
printf '%s\n' 'stop_check() {'
printf '%s\n' '  if is_sourced; then set +e; fi'
printf '%s\n' '  return 1'
printf '%s\n' '}'
printf '%s\n' ''
printf '%s\n' '# Installs the Homebrew formulae $@. Fails if Homebrew is missing: then the caller stops.'
printf '%s\n' 'brew_install() {'
printf '%s\n' '  if ! check_command brew; then'
printf '%s\n' '    echo -e "${RED}❌ Missing on this Mac: $*. Install Homebrew (https://brew.sh) and run this script again, or install $* yourself.${NC}"'
printf '%s\n' '    return 1'
printf '%s\n' '  fi'
printf '%s\n' '  brew install "$@" || return'
printf '%s\n' '  hash -r'
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
printf '%s\n' '# cosign >= 2.0.0 verifies the SCONE package images. Images signed with cosign 3.x in its'
printf '%s\n' '# bundle format, such as the workshop image built by ./scripts/build.sh, need cosign >= 3.0.0.'
printf '%s\n' 'COSIGN_MIN_VERSION="${COSIGN_MIN_VERSION:-2.0.0}"'
printf '%s\n' 'COSIGN_BUNDLE_MIN_VERSION="${COSIGN_BUNDLE_MIN_VERSION:-3.0.0}"'
printf '%s\n' '# The cosign release to install, e.g., v3.1.4. Default: the latest release.'
printf '%s\n' 'COSIGN_RELEASE="${COSIGN_RELEASE:-latest}"'
printf '%s\n' 'COSIGN_INSTALL_PATH="${COSIGN_INSTALL_PATH:-/usr/local/bin/cosign}"'
printf '%s\n' ''
printf '%s\n' '# Prints the version (e.g., 2.4.1) of cosign, or of the cosign binary $1, or nothing if unknown.'
printf '%s\n' 'cosign_version() {'
printf '%s\n' '  "${1:-cosign}" version 2>/dev/null | grep -Eo '\''GitVersion: *v?[0-9]+\.[0-9]+\.[0-9]+'\'' | grep -Eo '\''[0-9]+\.[0-9]+\.[0-9]+'\'' | head -n 1 || true'
printf '%s\n' '}'
printf '%s\n' ''
printf '%s\n' '# Succeeds if cosign is installed and its version is at least $1 (default: COSIGN_MIN_VERSION).'
printf '%s\n' 'cosign_version_ok() {'
printf '%s\n' '  local version min_version="${1:-$COSIGN_MIN_VERSION}"'
printf '%s\n' '  check_command cosign || return 1'
printf '%s\n' '  version="$(cosign_version)"'
printf '%s\n' '  [[ -n "$version" ]] || return 1'
printf '%s\n' '  [[ "$(printf '\''%s\n%s\n'\'' "$min_version" "$version" | sort -V | head -n 1)" == "$min_version" ]]'
printf '%s\n' '}'
printf '%s\n' ''
printf '%s\n' '# Installs the cosign binary of COSIGN_RELEASE for this OS and CPU as COSIGN_INSTALL_PATH.'
printf '%s\n' '# The binary must match the release checksums and run before it replaces an installed cosign.'
printf '%s\n' 'install_cosign() ('
printf '%s\n' '  case "$(uname -s)" in'
printf '%s\n' '    Linux) os=linux ;;'
printf '%s\n' '    Darwin) os=darwin ;;'
printf '%s\n' '    *) echo "No cosign release for OS $(uname -s)"; exit 1 ;;'
printf '%s\n' '  esac'
printf '%s\n' '  case "$(uname -m)" in'
printf '%s\n' '    x86_64|amd64) arch=amd64 ;;'
printf '%s\n' '    aarch64|arm64) arch=arm64 ;;'
printf '%s\n' '    *) echo "No cosign release for CPU $(uname -m)"; exit 1 ;;'
printf '%s\n' '  esac'
printf '%s\n' '  asset="cosign-$os-$arch"'
printf '%s\n' '  tag="$COSIGN_RELEASE"'
printf '%s\n' '  if [[ "$tag" == latest ]]; then'
printf '%s\n' '    # Resolve the tag once, so the binary and the checksums come from the same release.'
printf '%s\n' '    tag="$(curl -fsSIL --retry 3 -o /dev/null -w '\''%{url_effective}'\'' https://github.com/sigstore/cosign/releases/latest)" || { echo "Cannot determine the latest cosign release"; exit 1; }'
printf '%s\n' '    tag="${tag##*/}"'
printf '%s\n' '  fi'
printf '%s\n' '  if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then'
printf '%s\n' '    echo "Unexpected cosign release '\''$tag'\''"'
printf '%s\n' '    exit 1'
printf '%s\n' '  fi'
printf '%s\n' '  url="https://github.com/sigstore/cosign/releases/download/$tag"'
printf '%s\n' '  tmp="$(mktemp -d)"'
printf '%s\n' '  trap '\''rm -rf "$tmp"'\'' EXIT'
printf '%s\n' '  echo "Downloading $url/$asset"'
printf '%s\n' '  if ! curl -fsSL --retry 3 -o "$tmp/$asset" "$url/$asset" \'
printf '%s\n' '    || ! curl -fsSL --retry 3 -o "$tmp/cosign_checksums.txt" "$url/cosign_checksums.txt"; then'
printf '%s\n' '    echo "Download of cosign $tag failed"'
printf '%s\n' '    exit 1'
printf '%s\n' '  fi'
printf '%s\n' '  expected="$(awk -v f="$asset" '\''$2 == f { print $1 }'\'' "$tmp/cosign_checksums.txt")"'
printf '%s\n' '  if check_command sha256sum; then'
printf '%s\n' '    actual="$(sha256sum "$tmp/$asset" | awk '\''{ print $1 }'\'')"'
printf '%s\n' '  else'
printf '%s\n' '    actual="$(shasum -a 256 "$tmp/$asset" | awk '\''{ print $1 }'\'')"'
printf '%s\n' '  fi'
printf '%s\n' '  if [[ -z "$expected" || "$actual" != "$expected" ]]; then'
printf '%s\n' '    echo "Checksum of $asset does not match cosign_checksums.txt of cosign $tag"'
printf '%s\n' '    exit 1'
printf '%s\n' '  fi'
printf '%s\n' '  chmod +x "$tmp/$asset"'
printf '%s\n' '  if [[ -z "$(cosign_version "$tmp/$asset")" ]]; then'
printf '%s\n' '    echo "The downloaded $asset does not run on this machine"'
printf '%s\n' '    exit 1'
printf '%s\n' '  fi'
printf '%s\n' '  sudo mkdir -p "$(dirname "$COSIGN_INSTALL_PATH")" && sudo install -m 0755 "$tmp/$asset" "$COSIGN_INSTALL_PATH"'
printf '%s\n' ')'
printf '%s\n' ''
printf '%s\n' '# Install Cosign if it is missing, or update it if it cannot verify the workshop image'
printf '%s\n' 'if cosign_version_ok "$COSIGN_BUNDLE_MIN_VERSION"; then'
printf '%s\n' '  echo "✔️ Cosign $(cosign_version) is already installed."'
printf '%s\n' 'else'
printf '%s\n' '  if check_command cosign; then'
printf '%s\n' '    echo "📥 Cosign '\''$(cosign_version)'\'' of $(command -v cosign) is older than $COSIGN_BUNDLE_MIN_VERSION: installing Cosign $COSIGN_RELEASE..."'
printf '%s\n' '  else'
printf '%s\n' '    echo "📥 Installing Cosign $COSIGN_RELEASE..."'
printf '%s\n' '  fi'
printf '%s\n' '  if install_cosign; then'
printf '%s\n' '    hash -r'
printf '%s\n' '    if [[ "$(command -v cosign)" != "$COSIGN_INSTALL_PATH" ]]; then'
printf '%s\n' '      echo -e "${YELLOW}⚠️ Installed cosign $(cosign_version "$COSIGN_INSTALL_PATH") as $COSIGN_INSTALL_PATH, but $(command -v cosign) comes first in your PATH: remove it or put $(dirname "$COSIGN_INSTALL_PATH") first.${NC}"'
printf '%s\n' '    fi'
printf '%s\n' '  else'
printf '%s\n' '    echo -e "${YELLOW}⚠️ Could not install cosign: see the message above.${NC}"'
printf '%s\n' '  fi'
printf '%s\n' '  if cosign_version_ok "$COSIGN_BUNDLE_MIN_VERSION"; then'
printf '%s\n' '    echo "✔️ Cosign $(cosign_version) installed successfully."'
printf '%s\n' '  elif cosign_version_ok; then'
printf '%s\n' '    echo -e "${YELLOW}⚠️ Using cosign $(cosign_version) of $(command -v cosign): it verifies the SCONE package images, but not the workshop image, which needs cosign >= $COSIGN_BUNDLE_MIN_VERSION.${NC}"'
printf '%s\n' '  else'
printf '%s\n' '    if check_command cosign; then'
printf '%s\n' '      echo -e "${RED}❌ We need cosign >= $COSIGN_MIN_VERSION to verify the SCONE images, but $(command -v cosign) is cosign '\''$(cosign_version)'\''.${NC}"'
printf '%s\n' '    else'
printf '%s\n' '      echo -e "${RED}❌ We need cosign >= $COSIGN_MIN_VERSION to verify the SCONE images, but no cosign is installed.${NC}"'
printf '%s\n' '    fi'
printf '%s\n' '    stop_check || return 1 2>/dev/null || exit 1'
printf '%s\n' '  fi'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' '# Auto-install Docker if not present'
printf '%s\n' 'if ! check_command docker; then'
printf '%s\n' '  if is_macos; then'
printf '%s\n' '    # get.docker.com supports Linux only.'
printf '%s\n' '    echo -e "${RED}❌ Docker is not installed. On macOS, install Docker Desktop (https://docs.docker.com/desktop/setup/install/mac-install/) or another Docker engine, start it, and run this script again.${NC}"'
printf '%s\n' '    stop_check || return 1 2>/dev/null || exit 1'
printf '%s\n' '  fi'
printf '%s\n' '  echo "📥 Installing Docker..."'
printf '%s\n' '  curl -fsSL https://get.docker.com | sh'
printf '%s\n' '  echo "✔️ Docker installed successfully. Please log out and back in for group changes to take effect."'
printf '%s\n' 'else'
printf '%s\n' '  echo "✔️ Docker is already installed."'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' '# Ensure that we can run docker without being root (on macOS: that Docker runs)'
printf '%s\n' './scripts/check_docker_setup.sh || stop_check || return 1 2>/dev/null || exit 1'
printf '%s\n' ''
printf '%s\n' '# Auto-install GitHub CLI if not present'
printf '%s\n' 'if ! check_command gh; then'
printf '%s\n' '  echo "📥 Installing GitHub CLI..."'
printf '%s\n' '  if is_macos; then'
printf '%s\n' '    brew_install gh || stop_check || return 1 2>/dev/null || exit 1'
printf '%s\n' '  else'
printf '%s\n' '    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg'
printf '%s\n' '    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null'
printf '%s\n' '    sudo apt update'
printf '%s\n' '    sudo apt install -y gh'
printf '%s\n' '  fi'
printf '%s\n' '  echo "✔️ GitHub CLI installed successfully."'
printf '%s\n' 'else'
printf '%s\n' '  echo "✔️ GitHub CLI is already installed."'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' '# Auto-install kubectl if not present'
printf '%s\n' 'if ! check_command kubectl; then'
printf '%s\n' '  echo "📥 Installing kubectl..."'
printf '%s\n' '  if is_macos; then'
printf '%s\n' '    brew_install kubectl || stop_check || return 1 2>/dev/null || exit 1'
printf '%s\n' '  else'
printf '%s\n' '    export KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)'
printf '%s\n' '    curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl'
printf '%s\n' '    curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256'
printf '%s\n' '    echo "$(cat kubectl.sha256) kubectl" | sha256sum --check'
printf '%s\n' '    sudo chmod +x kubectl'
printf '%s\n' '    sudo mv ./kubectl /usr/local/bin/'
printf '%s\n' '    rm kubectl.sha256'
printf '%s\n' '  fi'
printf '%s\n' '  echo "✔️ kubectl installed successfully."'
printf '%s\n' 'else'
printf '%s\n' '  echo "✔️ kubectl is already installed."'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' '# Auto-install Helm if not present'
printf '%s\n' 'if ! check_command helm; then'
printf '%s\n' '  echo "📥 Installing Helm..."'
printf '%s\n' '  if is_macos; then'
printf '%s\n' '    brew_install helm || stop_check || return 1 2>/dev/null || exit 1'
printf '%s\n' '  else'
printf '%s\n' '    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash'
printf '%s\n' '  fi'
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
printf '%s\n' 'install_yq=false'
printf '%s\n' 'if check_command yq; then'
printf '%s\n' '    yq_version=$(yq --version 2>&1 | grep  -oE '\''v[0-9]+'\'' | cut -d'\''v'\'' -f2) || yq_version=""'
printf '%s\n' '    if [[ -z "$yq_version" || "$yq_version" == "0" ]]; then'
printf '%s\n' '        echo -e "${RED}❌ Found yq version $yq_version which is not supported. Installing Yq v4"'
printf '%s\n' '        install_yq=true'
printf '%s\n' '    fi'
printf '%s\n' '    if [[ "$yq_version" -ge 4 ]]; then'
printf '%s\n' '        echo "✔️ yq v$yq_version is installed (meets requirement v4+)."'
printf '%s\n' '    else'
printf '%s\n' '        echo -e "${RED}❌ yq version $yq_version is too old. Installing Yq v4"'
printf '%s\n' '        install_yq=true'
printf '%s\n' '    fi'
printf '%s\n' 'else'
printf '%s\n' '    echo -e "${RED}❌ yq is not installed. Installing Yq v4"'
printf '%s\n' '    install_yq=true'
printf '%s\n' 'fi'
printf '%s\n' '# On macOS, we stop here if Homebrew is missing: a function like install_yq_v4 can only'
printf '%s\n' '# return from itself, not from this script.'
printf '%s\n' 'if [[ "$install_yq" == true ]]; then'
printf '%s\n' '  if is_macos; then'
printf '%s\n' '    # Homebrew'\''s yq is mikefarah/yq v4.'
printf '%s\n' '    brew_install yq || stop_check || return 1 2>/dev/null || exit 1'
printf '%s\n' '    echo "✔️ yq installed successfully."'
printf '%s\n' '  else'
printf '%s\n' '    install_yq_v4'
printf '%s\n' '  fi'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' '# Auto-install other required packages'
printf '%s\n' 'missing_packages=()'
printf '%s\n' 'if is_macos; then'
printf '%s\n' '  # Homebrew'\''s openssl@3 provides what libssl-dev provides on Debian. It is keg-only,'
printf '%s\n' '  # so pkg-config does not see it unless PKG_CONFIG_PATH points to it: ask brew as well.'
printf '%s\n' '  for pkg in pkg-config jq; do'
printf '%s\n' '    if ! check_command "$pkg"; then'
printf '%s\n' '      missing_packages+=("$pkg")'
printf '%s\n' '    fi'
printf '%s\n' '  done'
printf '%s\n' '  if ! { check_command brew && brew list --formula openssl@3 &>/dev/null; } \'
printf '%s\n' '    && ! pkg-config --exists openssl &>/dev/null; then'
printf '%s\n' '    missing_packages+=("openssl@3")'
printf '%s\n' '  fi'
printf '%s\n' 'else'
printf '%s\n' '  for pkg in pkg-config jq libssl-dev; do'
printf '%s\n' '    if ! dpkg -s "$pkg" &>/dev/null; then'
printf '%s\n' '      missing_packages+=("$pkg")'
printf '%s\n' '    fi'
printf '%s\n' '  done'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' 'if [ ${#missing_packages[@]} -ne 0 ]; then'
printf '%s\n' '  echo "📥 Installing missing packages: ${missing_packages[*]}"'
printf '%s\n' '  if is_macos; then'
printf '%s\n' '    brew_install "${missing_packages[@]}" || stop_check || return 1 2>/dev/null || exit 1'
printf '%s\n' '  else'
printf '%s\n' '    sudo apt update'
printf '%s\n' '    sudo apt install -y "${missing_packages[@]}"'
printf '%s\n' '  fi'
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

# If something is missing, we stop with "stop_check || return 1 2>/dev/null || exit 1": it
# returns to your shell if you sourced this script, and exits with 1 if you ran it. "exit 1"
# would close your shell, and so would "return 1" while the "set -e" of this script is on:
# stop_check turns "set -e" off if you sourced this script.
stop_check() {
  if is_sourced; then set +e; fi
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
printf '%s\n' ''
printf '%s\n' 'The SCONE CLI packages run on x86_64 Linux only, so `./scripts/install_sconecli.sh` stops on'
printf '%s\n' 'other hosts, e.g., on macOS. There, run the SCONE CLI in the workshop image instead: on an x86_64'
printf '%s\n' 'machine with Docker (see "Run the Workshop Image" in the [README](README.md)), or in a Kubernetes'
printf '%s\n' 'cluster with x86_64 nodes with `./scripts/k8s_cli.sh` (see [k8s.md](k8s.md)).'
printf "${RESET}"

