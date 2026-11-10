#!/usr/bin/env bash
# Exercise Rust setup without downloads or changes to the user's toolchains.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
installer="${1:-$repo_root/scripts/install-rust.sh}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

run_installer() {
  bash -c '
    set -euo pipefail
    installer="$1"
    calls="$2"
    installed="$3"
    selected="$4"
    install_status="$5"
    export TOOLCHAIN="$6"
    export COMPONENTS="$7"
    # fake_cc stands in for cc: it exists unless $8 is "missing", and
    # "apt-get install build-essential" creates it unless $8 is "broken".
    linker="${8:-present}"
    export RUST_LINKER=fake_cc
    [[ "$linker" != present ]] || fake_cc() { :; }
    sudo() { printf "sudo %s\n" "$*" >> "$calls"; "$@"; }
    apt-get() {
      printf "apt-get %s\n" "$*" >> "$calls"
      if [[ "$*" == "install -y build-essential" && "$linker" == missing ]]; then
        fake_cc() { :; }
      fi
    }

    # Functions take precedence over real tools, even if .cargo/env edits PATH.
    curl() { echo "unexpected download" >&2; return 99; }
    rustup() {
      printf "rustup %s\n" "$*" >> "$calls"
      case "$1 ${2:-}" in
        "toolchain list")
          if [[ "$installed" == 1 ]]; then
            printf "%s (default)\n" "${TOOLCHAIN}-x86_64-unknown-linux-gnu"
          fi
          ;;
        "run $TOOLCHAIN")
          [[ "$*" == "run $TOOLCHAIN rustc --version" && "$installed" == 1 ]]
          ;;
        "toolchain install")
          [[ "$3" == "$TOOLCHAIN" ]] || return 98
          [[ "$install_status" == 0 ]] || return "$install_status"
          installed=1
          ;;
        "default $TOOLCHAIN")
          [[ "$installed" == 1 ]] || return 97
          selected=1
          ;;
        "component add") [[ "$selected" == 1 ]] ;;
        "--version ") ;;
        *) return 96 ;;
      esac
    }
    rustc() {
      printf "rustc %s\n" "$*" >> "$calls"
      [[ "$selected" == 1 ]]
    }
    cargo() {
      printf "cargo %s\n" "$*" >> "$calls"
      [[ "$selected" == 1 ]]
    }
    source "$installer"
  ' _ "$installer" "$work/calls" "$@" > "$work/output" 2>&1
}

fail() {
  printf 'FAIL - %s\n' "$1" >&2
  cat "$work/output" >&2
  exit 1
}

for toolchain in stable nightly 1.96.0 stable-x86_64-unknown-linux-gnu; do
  : > "$work/calls"
  run_installer 1 1 0 "$toolchain" 'rustfmt clippy' || fail "installed $toolchain"
  if grep -q '^rustup toolchain install' "$work/calls"; then
    fail "installed $toolchain must not be updated"
  fi
  grep -qx "rustup component add clippy --toolchain $toolchain" "$work/calls" \
    || fail "clippy component for $toolchain"
  printf 'ok - installed %s is reused\n' "$toolchain"
done

: > "$work/calls"
run_installer 0 0 0 stable 'rustfmt clippy' || fail 'missing toolchain without a default'
grep -qx 'rustup toolchain install stable' "$work/calls" || fail 'install missing stable'
printf 'ok - missing toolchain is installed before version checks\n'

: > "$work/calls"
run_installer 1 0 0 stable 'rustfmt clippy' || fail 'installed toolchain without a default'
if grep -q '^rustup toolchain install' "$work/calls"; then
  fail 'installed toolchain without a default must not be updated'
fi
printf 'ok - installed toolchain can be selected without an existing default\n'

: > "$work/calls"
status=0
run_installer 0 0 73 stable 'rustfmt clippy' || status=$?
[[ "$status" == 73 ]] || fail 'propagate installation failure'
if grep -q '^rustup default' "$work/calls"; then
  fail 'do not continue after installation failure'
fi
printf 'ok - installation failure stops setup and preserves its exit status\n'

: > "$work/calls"
run_installer 1 1 0 stable 'rustfmt clippy rust-src' || fail 'custom components'
grep -qx 'rustup component add rust-src --toolchain stable' "$work/calls" \
  || fail 'custom component list'
printf 'ok - custom component list is preserved\n'

: > "$work/calls"
run_installer 1 1 0 stable 'rustfmt clippy' missing || fail 'missing C compiler'
grep -q 'apt-get install -y build-essential' "$work/calls" || fail 'install build-essential'
grep -q '^rustup component add' "$work/calls" || fail 'continue after installing build-essential'
printf 'ok - missing C compiler is installed with build-essential\n'

: > "$work/calls"
run_installer 1 1 0 stable 'rustfmt clippy' present || fail 'present C compiler'
if grep -q 'apt-get' "$work/calls"; then
  fail 'do not install build-essential if a C compiler exists'
fi
printf 'ok - present C compiler is kept\n'

: > "$work/calls"
status=0
run_installer 1 1 0 stable 'rustfmt clippy' broken || status=$?
[[ "$status" != 0 ]] || fail 'stop if no C compiler can be installed'
grep -q 'still not available' "$work/output" || fail 'explain the missing C compiler'
if grep -q '^rustup' "$work/calls"; then
  fail 'do not set up rust without a C compiler'
fi
printf 'ok - setup stops if no C compiler can be installed\n'
