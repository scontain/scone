#!/usr/bin/env bash
# Read-only checks for the SCONE workshop tools selected by PATH.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
override_dir=""
if [[ $# == 2 && "$1" == --overrides-dir ]]; then
    override_dir="$2"
    if [[ ! -d "$override_dir" ]]; then
        echo "ERROR: missing override directory: $override_dir. Run SCONE_VERSION=<release> ./overwrite.sh first." >&2
        exit 1
    fi
    override_dir="$(cd "$override_dir" && pwd)"
elif [[ $# != 0 ]]; then
    echo "Usage: SCONE_VERSION=<release> $0 [--overrides-dir <bin-directory>]" >&2
    exit 2
fi
expected="${SCONE_VERSION:-$(cat "$repo_root/stable.txt")}"
version_pattern='^v?([0-9]+)\.([0-9]+)\.([0-9]+)(-[[:alnum:].-]+)?(\+[[:alnum:].-]+)?$'
if [[ ! "$expected" =~ $version_pattern ]]; then
    echo "ERROR: invalid SCONE_VERSION: $expected" >&2
    exit 2
fi
expected_line="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
expected_prerelease="${BASH_REMATCH[4]}"
failures=0

fail() {
    local tool="$1" message="$2" candidate
    printf 'ERROR: %s: %s\n' "$tool" "$message" >&2
    if [[ -n "$override_dir" ]]; then
        printf '  Required override: %s/%s\n' "$override_dir" "$tool" >&2
    else
        echo "  Executables on PATH, in search order:" >&2
        while IFS= read -r candidate; do
            printf '    %s\n' "$candidate" >&2
        done < <(type -a -p "$tool" || true)
    fi
    failures=$((failures + 1))
}

tool_path() {
    if [[ -n "$override_dir" ]]; then
        [[ -f "$override_dir/$1" && -x "$override_dir/$1" ]] || return 1
        printf '%s/%s\n' "$override_dir" "$1"
    else
        type -P "$1"
    fi
}

check_version() {
    local tool="$1" policy="$2" executable output version major minor prerelease
    # Runtime warnings can precede the version and contain unrelated numbers.
    local output_pattern='(^|'$'\n'')([Ss]cone CLI|SCONE CLI|scone|kubectl scone|kubectl-scone|scone-td-build)[[:space:]]+(v?[0-9]+\.[0-9]+\.[0-9]+([-+][[:alnum:].+-]+)?)([[:space:]]|$)'
    if ! executable=$(tool_path "$tool"); then
        fail "$tool" "not installed"
        return
    fi
    if ! output=$("$executable" --version 2>&1); then
        fail "$tool" "$executable --version failed: $output"
        return
    fi
    if [[ ! "$output" =~ $output_pattern ]]; then
        fail "$tool" "cannot read version from $executable: $output"
        return
    fi
    version="${BASH_REMATCH[3]}"
    if [[ ! "$version" =~ $version_pattern ]]; then
        fail "$tool" "unrecognized version: $version"
        return
    fi
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    prerelease="${BASH_REMATCH[4]}"
    printf '%s: %s (%s)\n' "$tool" "$version" "$executable"

    if [[ "$policy" == release ]]; then
        if [[ "$major.$minor" != "$expected_line" ]]; then
            fail "$tool" "version $version does not match SCONE_VERSION=$expected; install a $expected_line.x tool. A different release line can use an incompatible CAS schema."
        elif [[ -n "$prerelease" && -z "$expected_prerelease" ]]; then
            fail "$tool" "prerelease $version cannot satisfy stable SCONE_VERSION=$expected"
        fi
    elif (( 10#$major == 0 && 10#$minor < 4 )) || [[ -n "$prerelease" ]]; then
        fail "$tool" "version $version is unsupported by the demos; install a stable scone-td-build >= 0.4.0 (workshop revision b607bdc supports the cas-endpoint templates)."
    fi
}

check_command() {
    local tool="$1" output
    shift
    if ! output=$("$@" 2>&1); then
        fail "$tool" "$* failed: $output"
    fi
}

echo "Checking tools for SCONE $expected (patch versions may differ)."
if [[ -z "$override_dir" ]]; then
    check_version scone release
fi
check_version kubectl-scone release
check_version scone-td-build demos
if [[ -n "$override_dir" ]]; then
    # Never let compatible host binaries hide missing/incompatible overrides.
    check_command kubectl-scone "$override_dir/kubectl-scone" --help
    check_command kubectl-scone-azure "$override_dir/kubectl-scone-azure" --help
    if ! tool_path kubectl-provision >/dev/null; then
        fail kubectl-provision "missing executable override"
    fi
else
    # These standalone executables are named with kubectl's plugin prefix, but
    # the Azure CLI is not dispatched as `kubectl scone-azure`.
    check_command kubectl-scone kubectl scone --help
    if azure_tool=$(tool_path kubectl-scone-azure); then
        check_command kubectl-scone-azure "$azure_tool" --help
    else
        fail kubectl-scone-azure "not installed"
    fi
fi

if td_build=$(tool_path scone-td-build) && apply_help=$("$td_build" apply --help 2>&1); then
    if [[ "$apply_help" != *--file* ]] || [[ "$apply_help" =~ Usage:[^$'\n']*--cas-address ]]; then
        fail scone-td-build "apply does not support the expected manifest workflow (apply -f scone.yaml); install the workshop revision b607bdc."
    fi
else
    fail scone-td-build "apply --help failed: ${apply_help:-missing executable}"
fi

if (( failures != 0 )); then
    if [[ -n "$override_dir" ]]; then
        echo "Override checks failed. Rebuild with SCONE_VERSION=$expected ./overwrite.sh before building the image." >&2
    else
        echo "Tooling checks failed. Install compatible binaries or adjust PATH, then rerun ./scripts/check-scone-tooling.sh." >&2
        echo 'An earlier binary (for example in ~/.cargo/bin) overrides a system installation.' >&2
    fi
    exit 1
fi
echo "SCONE tool version and command checks passed."
