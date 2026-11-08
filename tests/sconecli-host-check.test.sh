#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016  # the check expressions are eval-ed later
# Tests that sconecli.md and scripts/install_sconecli.sh stop early, with a message,
# on hosts other than x86_64 Linux: a mocked uname reports the host, and tplenv,
# docker, cosign, sudo, dpkg and getconf are mocks that only log their calls.
#   tests/sconecli-host-check.test.sh
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

failures=0
check() {
  if eval "$2"; then echo "ok   - $1"; else echo "FAIL - $1"; failures=$((failures + 1)); fi
}

# The host check of sconecli.md, exactly as documented: from the uname check to its fi.
awk '/^if \[\[ "\$\(uname -s\)" != Linux /{p=1} p{print} p&&/^fi$/{exit}' \
  "$repo_root/sconecli.md" > "$work/host-check.sh"
# Without a block, the checks below would pass vacuously.
check "sconecli.md contains the host check" '[[ -s "$work/host-check.sh" ]] && grep -q "exit 1" "$work/host-check.sh"'

sysbin="$work/sysbin"
mkdir -p "$sysbin" "$work/mock"
for tool in cat grep; do
  ln -s "$(command -v "$tool")" "$sysbin/$tool"
done
cat > "$work/mock/uname" <<'MOCK'
#!/bin/sh
case "$1" in -m) echo "$MOCK_CPU" ;; *) echo "$MOCK_OS" ;; esac
MOCK
for tool in tplenv docker cosign sudo dpkg dpkg-deb getconf ldd; do
  printf '#!/bin/sh\necho "%s $*" >> "$CALLS"\n' "$tool" > "$work/mock/$tool"
done
chmod +x "$work/mock"/*

run() { # OS CPU SCRIPT: runs SCRIPT on a mocked host; sets $rc and $out
  : > "$work/calls"
  rc=0
  out="$(env -i HOME="$work" PATH="$work/mock:$sysbin" CALLS="$work/calls" MOCK_OS="$1" MOCK_CPU="$2" \
    CONFIRM_ALL_ENVIRONMENT_VARIABLES="" "$BASH" -euo pipefail "$3" < /dev/null 2>&1)" || rc=$?
}

for host in Darwin:arm64 Darwin:x86_64 Linux:aarch64 Linux:armv7l; do
  IFS=: read -r os cpu <<<"$host"
  run "$os" "$cpu" "$work/host-check.sh"
  check "$os $cpu: stops" '[[ $rc == 1 ]]'
  check "$os $cpu: names the host" '[[ "$out" == *"x86_64 Linux, but this host runs $os on $cpu"* ]]'
  check "$os $cpu: points to the workshop image and k8s_cli.sh" \
    '[[ "$out" == *"Run the Workshop Image"* && "$out" == *"./scripts/k8s_cli.sh"* ]]'
done
run Linux x86_64 "$work/host-check.sh"
check "Linux x86_64: continues" '[[ $rc == 0 && -z "$out" ]]'

# The generated script stops before it asks for input or touches docker, dpkg or sudo.
run Darwin arm64 "$repo_root/scripts/install_sconecli.sh"
check "scripts/install_sconecli.sh on macOS arm64: stops with the message" \
  '[[ $rc == 1 && "$out" == *"x86_64 Linux, but this host runs Darwin on arm64"* ]]'
check "scripts/install_sconecli.sh on macOS arm64: runs nothing else" '[[ ! -s "$work/calls" ]]'

exit "$failures"
