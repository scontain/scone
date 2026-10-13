#!/usr/bin/env bash
# Regression tests for the installer validation; no packages or cluster required.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/older"

cat > "$work/bin/tool" <<'MOCK'
#!/bin/bash
case "${0##*/}" in
    kubectl)
        case "$*" in
            'scone --help') exec kubectl-scone --help ;;
            'scone-azure --help') exec kubectl-scone-azure --help ;;
            *) echo "unexpected kubectl request: $*" >&2; exit 99 ;;
        esac ;;
    scone) version="${MOCK_SCONE:-6.0.7}" ;;
    kubectl-scone) version="${MOCK_PLUGIN:-6.0.4}" ;;
    kubectl-scone-azure) exit "${MOCK_AZURE_RC:-0}" ;;
    scone-td-build) version="${MOCK_TD_BUILD:-0.4.0}" ;;
esac
case "$*" in
    --version)
        [[ "${MOCK_BROKEN_TOOL:-}" != "${0##*/}" ]] || exit 1
        if [[ "${MOCK_VERSION_NOISE:-0}" == 1 ]]; then
            echo "Runtime warning: library 1.2.5" >&2
        fi
        echo "${0##*/} $version" ;;
    --help) exit 0 ;;
    'apply --help')
        [[ "${MOCK_APPLY_RC:-0}" == 0 ]] || exit 1
        if [[ "${MOCK_LEGACY_APPLY:-0}" == 1 ]]; then
            echo 'Usage: scone-td-build apply --cas-address <CAS_ADDRESS> --file <FILE>'
        else
            echo 'Usage: scone-td-build apply [OPTIONS] --file <FILE>'
        fi ;;
    *) echo "unexpected tool invocation: $*" >&2; exit 99 ;;
esac
MOCK
chmod +x "$work/bin/tool"
for tool in scone kubectl kubectl-scone kubectl-scone-azure scone-td-build; do
    ln -s tool "$work/bin/$tool"
done
# A second installation must not hide the incompatible first binary.
cp "$work/bin/tool" "$work/older/kubectl-scone"

# Run the actual final installer block, so successful --help checks alone cannot
# produce the installer's success message. This excludes all installation steps.
awk '/^# Validate the tools selected by PATH\./{p=1} p{print}' \
    "$repo_root/scripts/install_sconecli.sh" > "$work/installer-check.sh"
[[ -s "$work/installer-check.sh" ]]

failures=0
run_case() {
    local name="$1" expected_rc="$2" expected_text="$3" rc=0
    shift 3
    (
        cd "$repo_root"
        env PATH="$work/bin:$work/older:/usr/bin:/bin" SCONE_VERSION=6.0.8 "$@" \
            bash -e "$work/installer-check.sh"
    ) > "$work/output" 2>&1 || rc=$?
    if [[ "$rc" == "$expected_rc" ]] && grep -Fq -- "$expected_text" "$work/output"; then
        echo "ok   - $name"
    else
        echo "FAIL - $name (exit $rc, expected $expected_rc)"
        cat "$work/output"
        failures=$((failures + 1))
    fi
    if [[ "$expected_rc" != 0 ]] && grep -Fq 'All required SCONE commands installed' "$work/output"; then
        echo "FAIL - incompatible tooling reported installation success"
        failures=$((failures + 1))
    fi
}

run_case 'patch skew within the stable release line is accepted' 0 'All required SCONE commands installed'
run_case '7.x plugin is rejected for 6.0 CAS' 1 'incompatible CAS schema' MOCK_PLUGIN=7.0.0-alpha.3
run_case 'earlier PATH binary is diagnosed' 1 "$work/bin/kubectl-scone" MOCK_PLUGIN=7.0.0-alpha.3
run_case 'alternative installation is listed' 1 "$work/older/kubectl-scone" MOCK_PLUGIN=7.0.0-alpha.3
run_case 'old build tool is rejected' 1 'stable scone-td-build >= 0.4.0' MOCK_TD_BUILD=0.3.0
run_case 'legacy apply interface is rejected even with a new version' 1 'expected manifest workflow' MOCK_LEGACY_APPLY=1
run_case 'numeric build version comparison' 0 'checks passed' MOCK_TD_BUILD=0.10.0
run_case 'build prerelease is rejected' 1 'unsupported by the demos' MOCK_TD_BUILD=0.4.0-rc.1
run_case 'CLI release mismatch is rejected' 1 'install a 6.0.x tool' MOCK_SCONE=7.0.0
run_case 'plugin minor mismatch is rejected' 1 'install a 6.0.x tool' MOCK_PLUGIN=6.1.0
run_case 'prerelease cannot satisfy a stable target' 1 'cannot satisfy stable' MOCK_PLUGIN=6.0.8-rc.1
run_case 'explicit prerelease target is supported' 0 'checks passed' SCONE_VERSION=7.0.0-alpha.3 MOCK_SCONE=7.0.0-alpha.3 MOCK_PLUGIN=7.0.0-alpha.3
run_case 'version metadata is accepted' 0 'checks passed' MOCK_PLUGIN=6.0.7+build.1
run_case 'runtime warning versions are ignored' 0 'checks passed' MOCK_VERSION_NOISE=1
run_case 'malformed version is rejected' 1 'cannot read version' MOCK_TD_BUILD=unknown
run_case 'failed version command is rejected' 1 '--version failed' MOCK_BROKEN_TOOL=scone
run_case 'failed plugin dispatch is rejected' 1 'kubectl scone-azure --help failed' MOCK_AZURE_RC=1
run_case 'failed apply help is rejected' 1 'apply --help failed' MOCK_APPLY_RC=1
run_case 'invalid target is rejected' 2 'invalid SCONE_VERSION' SCONE_VERSION=unknown
rm "$work/bin/scone-td-build"
run_case 'missing build tool is rejected' 1 'scone-td-build: not installed'
ln -s tool "$work/bin/scone-td-build"

# The standalone checker defaults to stable.txt, even outside the repository.
(
    cd "$work"
    unset SCONE_VERSION
    PATH="$work/bin:/usr/bin:/bin" "$repo_root/scripts/check-scone-tooling.sh"
) > "$work/output" 2>&1 || failures=$((failures + 1))
if ! grep -Fq 'checks passed' "$work/output"; then
    echo 'FAIL - standalone checker defaults to stable.txt outside the repository'
    cat "$work/output"
    failures=$((failures + 1))
else
    echo 'ok   - standalone checker defaults to stable.txt outside the repository'
fi

exit "$failures"
