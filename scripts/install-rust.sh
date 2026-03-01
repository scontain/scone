#!/usr/bin/env bash
set -euo pipefail

# Installs rustup/cargo if missing, and ensures common components are installed.
# Safe to run multiple times (idempotent-ish).

# ---- Config ----
TOOLCHAIN="${TOOLCHAIN:-stable}"
COMPONENTS=(${COMPONENTS:-rustfmt clippy})
PROFILE="${PROFILE:-default}"   # rustup profiles: minimal|default|complete
RUSTUP_INIT_URL="${RUSTUP_INIT_URL:-https://sh.rustup.rs}"

# ---- Helpers ----
log() { printf '%s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

ensure_path() {
  # Ensure current shell sees cargo/rustup after install
  if [ -f "${HOME}/.cargo/env" ]; then
    # shellcheck disable=SC1090
    source "${HOME}/.cargo/env"
  fi
}

require_cmd() {
  if ! have "$1"; then
    log "ERROR: required command not found: $1"
    exit 1
  fi
}

# ---- Main ----
main() {
  # Basic prerequisites
  require_cmd curl
  # If we need to install rustup, we also need a shell and some basics
  if ! have rustup || ! have cargo || ! have rustc; then
    log "Rust toolchain missing (rustup/cargo/rustc). Installing via rustup..."
    # Install rustup non-interactively; adds toolchain + cargo/rustc.
    # -y: no prompt, --profile: controls installed components set, --default-toolchain: stable/nightly/etc
    curl -sSf "$RUSTUP_INIT_URL" | sh -s -- -y --profile "$PROFILE" --default-toolchain "$TOOLCHAIN"
    ensure_path
  else
    log "rustup/cargo/rustc already present."
    ensure_path
  fi

  # Sanity check
  if ! have rustup || ! have cargo || ! have rustc; then
    log "ERROR: rustup/cargo/rustc still not available after install."
    log "Try opening a new shell or run: source \$HOME/.cargo/env"
    exit 1
  fi

  log "Rust versions:"
  rustup --version
  rustc --version
  cargo --version

  # Ensure the desired toolchain is installed + set as default
  if ! rustup toolchain list | awk '{print $1}' | grep -qx "${TOOLCHAIN}"; then
    log "Installing toolchain: ${TOOLCHAIN}"
    rustup toolchain install "${TOOLCHAIN}"
  fi
  rustup default "${TOOLCHAIN}" >/dev/null

  # Ensure components are installed (idempotent)
  for c in "${COMPONENTS[@]}"; do
    log "Ensuring rustup component installed: $c"
    # rustup component add is idempotent; if already installed it exits 0 with a message
    rustup component add "$c" --toolchain "${TOOLCHAIN}"
  done

  log "Done. You may need to reload your shell for PATH changes."
  log "Current session can be fixed with: source \$HOME/.cargo/env"
}

main "$@"