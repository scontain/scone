#!/usr/bin/env bash
# Verify latest validation stages a candidate and invokes the full workshop test flow.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fixture="$work/repo"
mkdir -p "$fixture/scripts" "$fixture/overwrite/bin" "$work/bin"
cp "$repo_root/overwrite.sh" "$repo_root/stable.txt" "$fixture/"

cat > "$fixture/scripts/check-scone-tooling.sh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == --overrides-dir ]]
[[ -x "$2/scone-td-build" && -x "$2/kubectl-scone" && -x "$2/kubectl-provision" ]]
printf 'checked %s\n' "$2" >> "$MOCK_CALLS"
MOCK
cat > "$fixture/scripts/build.sh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'SCONE_OVERRIDE_DIR=%s\n' "$SCONE_OVERRIDE_DIR" >> "$MOCK_CALLS"
printf 'build args: %s\n' "$*" >> "$MOCK_CALLS"
printf 'candidate: '
"$SCONE_OVERRIDE_DIR/bin/scone-td-build" --version
MOCK
chmod +x "$fixture/scripts/check-scone-tooling.sh" "$fixture/scripts/build.sh"

cat > "$work/tool" <<'MOCK'
#!/usr/bin/env bash
case "${0##*/}" in
    scone-td-build) version=0.4.1 ;;
    kubectl-scone) version=6.0.5 ;;
    *) version=6.0.8 ;;
esac
case "$*" in
    --version) echo "${0##*/} $version" ;;
    --help) exit 0 ;;
    *) exit 99 ;;
esac
MOCK
chmod +x "$work/tool"
cat > "$work/bin/git" <<'MOCK'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >> "$MOCK_CALLS"
[[ "$*" == 'ls-remote https://github.com/scontain/scone-td-build.git refs/heads/main' ]]
printf '%s\trefs/heads/main\n' 0123456789abcdef0123456789abcdef01234567
MOCK
cat > "$work/bin/cargo" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'cargo %s\n' "$*" >> "$MOCK_CALLS"
root=""; crate=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --root) root="$2"; shift 2 ;;
        --git|--rev|--branch) shift 2 ;;
        install|--locked) shift ;;
        *) crate="$1"; shift ;;
    esac
done
mkdir -p "$root/bin"
if [[ "$crate" == kubectl-scone-azure ]]; then
    cp "$MOCK_TOOL" "$root/bin/kubectl-scone_azure"
else
    cp "$MOCK_TOOL" "$root/bin/$crate"
fi
MOCK
chmod +x "$work/bin/git" "$work/bin/cargo"
printf '#!/usr/bin/env bash\necho provision\n' > "$work/provision"
chmod +x "$work/provision"
printf 'preserve this installed override\n' > "$fixture/overwrite/bin/scone-td-build"
sha256sum "$fixture/overwrite/bin/scone-td-build" > "$work/before"
export MOCK_CALLS="$work/calls" MOCK_TOOL="$work/tool"
export KUBECTL_PROVISION_BINARY="$work/provision"
export PATH="$work/bin:$PATH"
: > "$MOCK_CALLS"
SCONE_VERSION=6.0.8 "$fixture/overwrite.sh" --validate-latest > "$work/output" 2>&1
sha256sum "$fixture/overwrite/bin/scone-td-build" > "$work/after"
cmp -s "$work/before" "$work/after"
grep -Fq -- '--rev 0123456789abcdef0123456789abcdef01234567 --locked' "$MOCK_CALLS"
grep -Fq -- '--push-to registry.scontain.com/workshop/scone-validation --image-tag 6.0.8-0123456789ab --test' "$MOCK_CALLS"
grep -Fq 'candidate: scone-td-build 0.4.1' "$work/output"
grep -Fq 'current overwrite/bin files will not be changed' "$work/output"
printf 'ok - latest validation stages candidate, runs full-test command, and preserves installed override\n'
