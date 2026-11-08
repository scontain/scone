#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016  # the check expressions are eval-ed later
# Tests the macOS support of prerequisite_check.md and scripts/check_docker_setup.sh
# offline: a mocked uname reports Darwin (or Linux), and docker, brew, sudo, apt, dpkg,
# curl and the installed tools are mocks that only log their calls. Only a few basic
# host tools are on PATH, so nothing on this host is used or changed.
#   tests/prerequisite-macos.test.sh
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

failures=0
check() {
  if eval "$2"; then echo "ok   - $1"; else echo "FAIL - $1"; failures=$((failures + 1)); fi
}

# The helpers and the tool checks of prerequisite_check.md, exactly as documented:
# from check_command() to scone_registry_login(), and from the Docker step to the
# final message.
awk '/^check_command\(\)/{p=1} /^scone_registry_login\(\)/{exit} p' \
  "$repo_root/prerequisite_check.md" > "$work/helpers.sh"
awk '/^# Auto-install Docker/{p=1} p{print} /^echo ".* All external executables are installed/{exit}' \
  "$repo_root/prerequisite_check.md" > "$work/tools.sh"
# Without the blocks, the checks below would pass vacuously.
check "prerequisite_check.md contains the macOS helpers" \
  'grep -q "^is_macos()" "$work/helpers.sh" && grep -q "^brew_install()" "$work/helpers.sh"'
check "prerequisite_check.md contains the tool checks" \
  'grep -q "check_docker_setup.sh" "$work/tools.sh" && grep -q "All external executables" "$work/tools.sh"'

# Only these host tools are visible: no apt, dpkg, getent, stat, brew or docker of this host.
sysbin="$work/sysbin"
mkdir -p "$sysbin"
for tool in awk cat chmod cp cut dirname grep head id mkdir mktemp mv rm sed sh sort tail touch tr; do
  ln -s "$(command -v "$tool")" "$sysbin/$tool"
done
# Scripts started with '#!/usr/bin/env bash' run with the bash under test.
ln -s "$BASH" "$sysbin/bash"

mock="$work/mock"
mkdir -p "$mock" "$work/docker-bin" "$work/brew-bin"
cat > "$mock/uname" <<'MOCK'
#!/bin/sh
case "$1" in -m) echo "$MOCK_CPU" ;; *) echo "$MOCK_OS" ;; esac
MOCK
# Logged only: they must not run anything, and must not be called at all on macOS.
for tool in sudo apt apt-get curl; do
  printf '#!/bin/sh\necho "%s $*" >> "$CALLS"\n' "$tool" > "$mock/$tool"
done
# Read stdin like 'sudo tee' would: with pipefail, an unread pipe fails the echo before it.
echo 'cat > /dev/null' >> "$mock/sudo"
cat > "$mock/dpkg" <<'MOCK'
#!/bin/sh
echo "dpkg $*" >> "$CALLS"
case "$1" in
  --print-architecture) echo amd64 ;;
  -s) case " $DPKG_INSTALLED " in *" $2 "*) exit 0 ;; *) exit 1 ;; esac ;;
esac
MOCK
cat > "$work/docker-bin/docker" <<'MOCK'
#!/bin/sh
echo "docker $*" >> "$CALLS"
if [ "$1" = ps ]; then exit "${DOCKER_PS_RC:-0}"; fi
MOCK
# make-tool DIR NAME [YQ_MAJOR]: an installed tool.
cat > "$work/make-tool" <<'MOCK'
#!/bin/sh
mkdir -p "$1"
case "$2" in
  yq) printf '#!/bin/sh\necho "yq (https://github.com/mikefarah/yq/) version v%s.47.1"\n' "${3:-4}" > "$1/yq" ;;
  pkg-config) printf '#!/bin/sh\n[ "$1" = --exists ] && exit "${PKG_CONFIG_OPENSSL_RC:-1}"\nexit 0\n' > "$1/pkg-config" ;;
  *) printf '#!/bin/sh\nexit 0\n' > "$1/$2" ;;
esac
chmod +x "$1/$2"
MOCK
# brew installs formulas into $BREW_PREFIX/bin; openssl@3 provides no command.
cat > "$work/brew-bin/brew" <<'MOCK'
#!/bin/sh
echo "brew $*" >> "$CALLS"
case "$1" in
  install)
    shift
    for formula in "$@"; do
      case "$formula" in
        openssl@3) touch "$BREW_PREFIX/openssl@3.installed" ;;
        *) "$MAKE_TOOL" "$BREW_PREFIX/bin" "$formula" ;;
      esac
    done
    ;;
  list)
    [ "$2" = --formula ] && shift
    [ -e "$BREW_PREFIX/$2.installed" ]
    ;;
  *) exit 1 ;;
esac
MOCK
chmod +x "$mock"/* "$work/docker-bin/docker" "$work/make-tool" "$work/brew-bin/brew"

all_tools="gh kubectl helm yq jq pkg-config"
case_no=0
# run_tools INSTALLED_TOOLS: runs the tool checks of prerequisite_check.md on a mocked
# host; sets $case_dir and $rc. NAME:N installs yq vN. Settings: MOCK_OS (Darwin),
# MOCK_CPU (arm64), NO_BREW, NO_DOCKER, DOCKER_PS_RC, BREW_FORMULAS (already installed),
# DPKG_INSTALLED, PKG_CONFIG_OPENSSL_RC.
run_tools() {
  local tool path
  case_no=$((case_no + 1))
  case_dir="$work/case$case_no"
  mkdir -p "$case_dir/home" "$case_dir/tools" "$case_dir/brew/bin" "$case_dir/scripts"
  : > "$case_dir/calls"
  for tool in $1; do
    case "$tool" in
      *:*) "$work/make-tool" "$case_dir/tools" "${tool%%:*}" "${tool#*:}" ;;
      *) "$work/make-tool" "$case_dir/tools" "$tool" ;;
    esac
  done
  for tool in ${BREW_FORMULAS:-}; do touch "$case_dir/brew/$tool.installed"; done
  if [[ "${MOCK_OS:-Darwin}" == Darwin ]]; then
    cp "$repo_root/scripts/check_docker_setup.sh" "$case_dir/scripts/"
  else
    # The Linux docker group setup needs getent and GNU stat: not part of this test.
    printf '#!/bin/sh\necho "check_docker_setup" >> "$CALLS"\n' > "$case_dir/scripts/check_docker_setup.sh"
    chmod +x "$case_dir/scripts/check_docker_setup.sh"
  fi
  path="$mock"
  [[ -n "${NO_DOCKER:-}" ]] || path="$path:$work/docker-bin"
  [[ -n "${NO_BREW:-}" ]] || path="$path:$work/brew-bin"
  path="$path:$case_dir/tools:$case_dir/brew/bin:$sysbin"
  rc=0
  (
    cd "$case_dir"
    env -i HOME="$case_dir/home" PATH="$path" CALLS="$case_dir/calls" \
      MOCK_OS="${MOCK_OS:-Darwin}" MOCK_CPU="${MOCK_CPU:-arm64}" \
      BREW_PREFIX="$case_dir/brew" MAKE_TOOL="$work/make-tool" \
      DOCKER_PS_RC="${DOCKER_PS_RC:-0}" DPKG_INSTALLED="${DPKG_INSTALLED:-}" \
      PKG_CONFIG_OPENSSL_RC="${PKG_CONFIG_OPENSSL_RC:-1}" \
      "$BASH" -euo pipefail -c '
        GREEN="" YELLOW="" RED="" NC=""
        source "$1"
        source "$2"
      ' _ "$work/helpers.sh" "$work/tools.sh"
  ) < /dev/null > "$case_dir/out" 2>&1 || rc=$?
}

reached_end='[[ $rc == 0 ]] && grep -q "All external executables are installed and ready" "$case_dir/out"'
no_linux_installers='! grep -Eq "^(sudo|apt|apt-get|dpkg|curl) " "$case_dir/calls"'

# A fresh Mac with Homebrew and Docker Desktop: brew installs everything.
run_tools ""
check "fresh Mac: reaches the end" "$reached_end"
check "fresh Mac: only Docker is checked, no docker group" \
  'grep -q "Docker works for the current user" "$case_dir/out" && ! grep -q "Group .docker." "$case_dir/out"'
for formula in gh kubectl helm yq "pkg-config jq openssl@3"; do
  check "fresh Mac: brew install $formula" 'grep -qx "brew install $formula" "$case_dir/calls"'
done
check "fresh Mac: no sudo, apt, dpkg or curl" "$no_linux_installers"

# A Mac with all tools: nothing is installed.
BREW_FORMULAS="openssl@3" run_tools "$all_tools"
check "Mac with all tools: reaches the end" "$reached_end"
check "Mac with all tools: nothing installed" '! grep -q "^brew install" "$case_dir/calls"'
check "Mac with all tools: no sudo, apt, dpkg or curl" "$no_linux_installers"

# Without Homebrew, a Mac with all tools still works, if pkg-config finds OpenSSL.
NO_BREW=1 PKG_CONFIG_OPENSSL_RC=0 run_tools "$all_tools"
check "Mac without Homebrew, all tools: reaches the end" "$reached_end"

# Without Homebrew, a missing tool stops the script with a message that names it.
NO_BREW=1 PKG_CONFIG_OPENSSL_RC=0 run_tools "kubectl helm yq jq pkg-config"
check "Mac without Homebrew, gh missing: stops" \
  '[[ $rc == 1 ]] && grep -q "Missing on this Mac: gh" "$case_dir/out" && grep -q "https://brew.sh" "$case_dir/out"'
check "Mac without Homebrew, gh missing: no sudo, apt, dpkg or curl" "$no_linux_installers"
NO_BREW=1 run_tools "$all_tools"
check "Mac without Homebrew, no OpenSSL: stops" \
  '[[ $rc == 1 ]] && grep -q "Missing on this Mac: openssl@3" "$case_dir/out"'

# yq v3 is replaced by Homebrew's yq v4.
BREW_FORMULAS="openssl@3" run_tools "gh kubectl helm yq:3 jq pkg-config"
check "Mac with yq v3: brew install yq" '[[ $rc == 0 ]] && grep -qx "brew install yq" "$case_dir/calls"'

# Docker cannot be installed by script on macOS.
NO_DOCKER=1 run_tools "$all_tools"
check "Mac without Docker: stops and points to Docker Desktop" \
  '[[ $rc == 1 ]] && grep -q "install Docker Desktop" "$case_dir/out"'
check "Mac without Docker: get.docker.com is not used" "$no_linux_installers"
check "Mac without Docker: nothing installed" '! grep -q "^brew install" "$case_dir/calls"'

# Docker Desktop is installed, but not running.
DOCKER_PS_RC=1 BREW_FORMULAS="openssl@3" run_tools "$all_tools"
check "Docker Desktop not running: stops" \
  '[[ $rc == 1 ]] && grep -q "Start Docker Desktop" "$case_dir/out"'

# Linux keeps using get.docker.com, apt and dpkg, even if brew is installed.
MOCK_OS=Linux MOCK_CPU=x86_64 NO_DOCKER=1 DPKG_INSTALLED="pkg-config libssl-dev" run_tools "kubectl helm yq"
check "Linux: reaches the end" "$reached_end"
check "Linux: installs Docker with get.docker.com" 'grep -qx "curl -fsSL https://get.docker.com" "$case_dir/calls"'
check "Linux: runs the docker group setup" 'grep -qx "check_docker_setup" "$case_dir/calls"'
check "Linux: installs gh with apt" 'grep -qx "sudo apt install -y gh" "$case_dir/calls"'
check "Linux: checks packages with dpkg and installs jq with apt" \
  'grep -qx "dpkg -s libssl-dev" "$case_dir/calls" && grep -qx "sudo apt install -y jq" "$case_dir/calls"'
check "Linux: brew is not used" '! grep -q "^brew " "$case_dir/calls"'

# check_docker_setup.sh on macOS without docker.
rc=0
env -i HOME="$work" PATH="$mock:$sysbin" CALLS="$work/calls" MOCK_OS=Darwin MOCK_CPU=arm64 \
  "$BASH" "$repo_root/scripts/check_docker_setup.sh" < /dev/null > "$work/check-docker.out" 2>&1 || rc=$?
check "check_docker_setup.sh on macOS without docker: points to Docker Desktop" \
  '[[ $rc == 1 ]] && grep -q "install Docker Desktop" "$work/check-docker.out"'

# The generated scripts/prerequisite_check.sh, sourced as the README says, on a fresh
# Mac with Homebrew, Docker Desktop, cargo and cosign 3.
case_no=$((case_no + 1))
case_dir="$work/case$case_no"
mkdir -p "$case_dir/home" "$case_dir/tools" "$case_dir/brew/bin" "$case_dir/scripts"
: > "$case_dir/calls"
cp "$repo_root/scripts/prerequisite_check.sh" "$repo_root/scripts/check_docker_setup.sh" "$case_dir/scripts/"
cp "$repo_root/stable.txt" "$case_dir/"
for tool in install-rust.sh; do
  printf '#!/bin/sh\necho "%s $*" >> "$CALLS"\n' "$tool" > "$case_dir/scripts/$tool"
done
for tool in cargo tplenv; do
  printf '#!/bin/sh\necho "%s $*" >> "$CALLS"\n' "$tool" > "$case_dir/tools/$tool"
done
printf '#!/bin/sh\necho "GitVersion:    v3.1.0"\n' > "$case_dir/tools/cosign"
chmod +x "$case_dir/scripts/install-rust.sh" "$case_dir/tools"/*
rc=0
(
  cd "$case_dir"
  env -i HOME="$case_dir/home" \
    PATH="$mock:$work/docker-bin:$work/brew-bin:$case_dir/tools:$case_dir/brew/bin:$sysbin" \
    CALLS="$case_dir/calls" MOCK_OS=Darwin MOCK_CPU=arm64 \
    BREW_PREFIX="$case_dir/brew" MAKE_TOOL="$work/make-tool" \
    "$BASH" -c '. ./scripts/prerequisite_check.sh'
) < /dev/null > "$case_dir/out" 2>&1 || rc=$?
check "prerequisite_check.sh on a fresh Mac: reaches the end" \
  '[[ $rc == 0 ]] && grep -q "All external executables are installed and ready" "$case_dir/out" && grep -q "All images are OK" "$case_dir/out"'
check "prerequisite_check.sh on a fresh Mac: no sudo, apt, dpkg or curl" "$no_linux_installers"
check "prerequisite_check.sh on a fresh Mac: keeps cosign 3.1.0" 'grep -q "Cosign 3.1.0 is already installed" "$case_dir/out"'

if [[ $failures != 0 ]]; then
  for out in "$work"/case*/out "$work/check-docker.out"; do
    echo "--- $out"
    tail -n 15 "$out"
  done
fi
exit "$failures"
