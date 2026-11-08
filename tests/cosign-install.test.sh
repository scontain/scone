#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016  # the check expressions are eval-ed later
# Tests the cosign checks of prerequisite_check.md and sconecli.md offline, with
# fake cosign binaries and a mocked curl that serves the release files.
#   tests/cosign-install.test.sh
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

failures=0
check() {
  if eval "$2"; then echo "ok   - $1"; else echo "FAIL - $1"; failures=$((failures + 1)); fi
}

# The cosign block of prerequisite_check.md, exactly as documented: from the version
# settings to the Docker step.
awk '/^COSIGN_MIN_VERSION=/{p=1} /^# Auto-install Docker/{exit} p' \
  "$repo_root/prerequisite_check.md" > "$work/cosign.sh"
# Without a block, the checks below would pass vacuously.
check "prerequisite_check.md contains the cosign block" \
  '[[ -s "$work/cosign.sh" ]] && grep -q "^install_cosign()" "$work/cosign.sh"'

# The asset that install_cosign should pick on this host.
case "$(uname -s)" in Linux) os=linux ;; Darwin) os=darwin ;; *) os=unknown ;; esac
case "$(uname -m)" in x86_64|amd64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; *) arch=unknown ;; esac
asset="cosign-$os-$arch"

fake_cosign() { # path version
  mkdir -p "$(dirname "$1")"
  printf '#!/bin/sh\necho "GitVersion:    %s"\n' "$2" > "$1"
  chmod +x "$1"
}

# Mocked curl: resolves "latest" to v9.9.9 and serves $work/release/<file> for tag $SERVE_TAG.
mkdir -p "$work/mock" "$work/release"
cat > "$work/mock/curl" <<'MOCK'
#!/bin/sh
out=""; url=""; wformat=""
while [ $# -gt 0 ]; do
  case "$1" in -o) out="$2"; shift ;; -w) wformat="$2"; shift ;; http*) url="$1" ;; esac
  shift
done
echo "$url" >> "$CURL_LOG"
[ "$CURL_MODE" = fail ] && exit 22
if [ -n "$wformat" ]; then echo "https://github.com/sigstore/cosign/releases/tag/v9.9.9"; exit 0; fi
case "$url" in */download/"$SERVE_TAG"/*) ;; *) exit 22 ;; esac
cp "$RELEASE_DIR/${url##*/}" "$out" || exit 22
MOCK
printf '#!/bin/sh\nexec "$@"\n' > "$work/mock/sudo"
chmod +x "$work/mock/curl" "$work/mock/sudo"

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{ print $1 }'; else shasum -a 256 "$1" | awk '{ print $1 }'; fi
}

serve_release() { # file to serve as $asset, checksum (default: its real checksum)
  cp "$1" "$work/release/$asset"
  printf '%s  %s\n%s  %s\n' "${2:-$(sha256 "$1")}" "$asset" "1111111111111111111111111111111111111111111111111111111111111111" "cosign-other-os" \
    > "$work/release/cosign_checksums.txt"
}

fake_cosign "$work/v9.9.9" v9.9.9
case_no=0
run_cosign_block() { # PATH entries before the system directories (@INSTALL@: the install directory); sets $case_dir, $rc
  case_no=$((case_no + 1))
  case_dir="$work/case$case_no"
  mkdir -p "$case_dir/install"
  : > "$case_dir/curl.log"
  rc=0
  env -i HOME="$case_dir" PATH="$work/mock:${1//@INSTALL@/$case_dir/install}:/usr/bin:/bin" \
    CURL_LOG="$case_dir/curl.log" CURL_MODE="${CURL_MODE:-ok}" SERVE_TAG="${SERVE_TAG:-v9.9.9}" \
    RELEASE_DIR="$work/release" COSIGN_INSTALL_PATH="$case_dir/install/cosign" \
    ${COSIGN_RELEASE:+COSIGN_RELEASE="$COSIGN_RELEASE"} \
    "$BASH" -euo pipefail -c '
      YELLOW="" RED="" NC=""
      check_command() { command -v "$1" &>/dev/null; }
      source "$1"
    ' _ "$work/cosign.sh" > "$case_dir/out" 2>&1 || rc=$?
}

# cosign 3.x is kept as it is.
fake_cosign "$work/c1/cosign" v3.1.0
run_cosign_block "@INSTALL@:$work/c1"
check "cosign 3.1.0: succeeds without downloading" '[[ $rc == 0 && ! -s "$case_dir/curl.log" ]]'

# cosign 2.x is updated to the latest release for this OS and CPU.
serve_release "$work/v9.9.9"
fake_cosign "$work/c2/cosign" 2.2.4
run_cosign_block "@INSTALL@:$work/c2"
check "cosign 2.2.4: updated to the latest release" \
  '[[ $rc == 0 ]] && grep -q "Cosign 9.9.9 installed successfully" "$case_dir/out"'
check "cosign 2.2.4: downloads $asset" 'grep -q "/download/v9.9.9/$asset$" "$case_dir/curl.log"'
check "cosign 2.2.4: checks cosign_checksums.txt of the same release" \
  'grep -q "/download/v9.9.9/cosign_checksums.txt$" "$case_dir/curl.log"'
check "cosign 2.2.4: installs the new cosign" '"$case_dir/install/cosign" version | grep -q v9.9.9'

# 'devel' builds report no version: update them as well.
fake_cosign "$work/c3/cosign" devel
run_cosign_block "@INSTALL@:$work/c3"
check "cosign devel: updated" '[[ $rc == 0 ]] && grep -q "Cosign 9.9.9 installed successfully" "$case_dir/out"'

# An older cosign earlier in PATH shadows the new one: warn and keep going with 2.x.
fake_cosign "$work/c4/cosign" 2.2.4
run_cosign_block "$work/c4:@INSTALL@"
check "shadowed: succeeds with cosign 2.2.4" '[[ $rc == 0 ]] && grep -q "Using cosign 2.2.4" "$case_dir/out"'
check "shadowed: names the cosign that comes first in PATH" 'grep -q "$work/c4/cosign comes first in your PATH" "$case_dir/out"'

# COSIGN_RELEASE pins the release.
SERVE_TAG=v9.9.8 COSIGN_RELEASE=v9.9.8 run_cosign_block "@INSTALL@"
check "COSIGN_RELEASE=v9.9.8: installs that release without looking up latest" \
  '[[ $rc == 0 ]] && grep -q "/download/v9.9.8/$asset$" "$case_dir/curl.log" && ! grep -q "releases/latest" "$case_dir/curl.log"'

# Failed downloads keep cosign 2.x, but stop without cosign or with cosign 1.x.
fake_cosign "$work/c6/cosign" 2.2.4
CURL_MODE=fail run_cosign_block "@INSTALL@:$work/c6"
check "download fails, cosign 2.2.4: kept with a warning" \
  '[[ $rc == 0 && ! -e "$case_dir/install/cosign" ]] && grep -q "Using cosign 2.2.4" "$case_dir/out"'
CURL_MODE=fail run_cosign_block "@INSTALL@"
check "download fails, no cosign: stops" '[[ $rc == 1 ]] && grep -q "We need cosign >= 2.0.0" "$case_dir/out"'
fake_cosign "$work/c8/cosign" v1.13.1
CURL_MODE=fail run_cosign_block "@INSTALL@:$work/c8"
check "download fails, cosign 1.13.1: stops" '[[ $rc == 1 ]]'

# A binary with a wrong checksum is not installed.
serve_release "$work/v9.9.9" 0000000000000000000000000000000000000000000000000000000000000000
run_cosign_block "@INSTALL@"
check "checksum mismatch: stops without installing" \
  '[[ $rc == 1 && ! -e "$case_dir/install/cosign" ]] && grep -q "does not match cosign_checksums.txt" "$case_dir/out"'

# A binary that does not run here (e.g., a Linux binary on macOS) is not installed.
printf '#!/nonexistent/interpreter\n' > "$work/not-runnable"
serve_release "$work/not-runnable"
run_cosign_block "@INSTALL@"
check "binary that does not run here: stops without installing" \
  '[[ $rc == 1 && ! -e "$case_dir/install/cosign" ]] && grep -q "does not run on this machine" "$case_dir/out"'

# sconecli.md: package images need cosign >= 2.0.0, the workshop image cosign >= 3.0.0.
awk '/^COSIGN_MIN_VERSION=/{p=1} /^function verify_image\(\)/{exit} p' "$repo_root/sconecli.md" > "$work/sconecli-cosign.sh"
check "sconecli.md contains the cosign version checks" 'grep -q "^function cosign_version_ok()" "$work/sconecli-cosign.sh"'
for entry in v1.13.1:no:no 2.2.4:yes:no v2.5.3:yes:no v3.0.0:yes:yes v10.0.0:yes:yes devel:no:no; do
  IFS=: read -r version want_package want_workshop <<<"$entry"
  fake_cosign "$work/s-$version/cosign" "$version"
  got_package=no; got_workshop=no
  PATH="$work/s-$version:/usr/bin:/bin" "$BASH" -euo pipefail -c 'source "$1"; cosign_version_ok' _ "$work/sconecli-cosign.sh" && got_package=yes
  PATH="$work/s-$version:/usr/bin:/bin" "$BASH" -euo pipefail -c 'source "$1"; cosign_version_ok "$COSIGN_BUNDLE_MIN_VERSION"' _ "$work/sconecli-cosign.sh" && got_workshop=yes
  check "sconecli.md: cosign $version verifies package images: $want_package, workshop image: $want_workshop" \
    '[[ $got_package == "$want_package" && $got_workshop == "$want_workshop" ]]'
done

# With cosign 2.x the workshop step is skipped before anything is pulled or verified.
awk '/^SCONE_WORKSHOP_IMAGE=/{p=1} p{print} p&&/^fi$/{exit}' "$repo_root/sconecli.md" > "$work/workshop.sh"
fake_cosign "$work/w/cosign" 2.2.4
: > "$work/workshop.calls"
rc=0
PATH="$work/w:/usr/bin:/bin" "$BASH" -euo pipefail -c '
  source "$1"
  create_cosign_verification_key() { cosign_public_key_file=/dev/null; }
  docker() { echo "docker $*" >> "$2"; }
  REPO=r IMAGE=i SCONE_VERSION=6.0.8
  source "$3"
' _ "$work/sconecli-cosign.sh" "$work/workshop.calls" "$work/workshop.sh" > "$work/workshop.out" 2>&1 || rc=$?
check "workshop step with cosign 2.2.4: skipped" \
  '[[ $rc == 0 ]] && grep -q "older than 3.0.0, so workshop image .* cannot be verified" "$work/workshop.out"'
check "workshop step with cosign 2.2.4: nothing pulled" '[[ ! -s "$work/workshop.calls" ]]'

exit "$failures"
