#!/usr/bin/env bash
# Exercise build/version gates with fake tools; never build/push an actual image.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fixture="$work/repo"
mkdir -p "$fixture/scripts" "$work/bin"
cp "$repo_root/scripts/build.sh" "$repo_root/scripts/check-scone-tooling.sh" "$fixture/scripts/"
cp "$repo_root/overwrite.sh" "$repo_root/stable.txt" "$fixture/"

cat > "$work/tool" <<'MOCK'
#!/usr/bin/env bash
case "${0##*/}" in
    scone-td-build) version="${MOCK_TD_VERSION:-0.4.0}" ;;
    kubectl-scone) version="${MOCK_PLUGIN_VERSION:-6.0.5}" ;;
    *) version=6.0.8 ;;
esac
case "$*" in
    --version) echo "${0##*/} $version" ;;
    --help) exit 0 ;;
    'apply --help') echo 'Usage: scone-td-build apply [OPTIONS] --file <FILE>' ;;
    *) exit 99 ;;
esac
MOCK
chmod +x "$work/tool"
cp "$work/tool" "$work/kubectl-provision"
for name in scone-td-build kubectl-scone kubectl-scone-azure; do
    cp "$work/tool" "$work/bin/$name"
done
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
cat > "$work/bin/docker" <<'MOCK'
#!/usr/bin/env bash
printf 'docker %s\n' "$*" >> "$MOCK_CALLS"
if [[ "$*" == *' run '* ]]; then
    exit "${MOCK_IMAGE_CHECK_RC:-0}"
fi
MOCK
chmod +x "$work/bin/cargo" "$work/bin/docker"
export MOCK_CALLS="$work/calls" MOCK_TOOL="$work/tool"
export KUBECTL_PROVISION_BINARY="$work/kubectl-provision"
export PATH="$work/bin:$PATH"
: > "$MOCK_CALLS"
failures=0
check() {
    local name="$1"
    shift
    if "$@"; then
        echo "ok   - $name"
    else
        echo "FAIL - $name"
        cat "$work/output"
        failures=$((failures + 1))
    fi
}
run_build() {
    local expected="$1"; shift
    local rc=0
    : > "$MOCK_CALLS"
    "$@" "$fixture/scripts/build.sh" --version 6.0.8 > "$work/output" 2>&1 || rc=$?
    [[ "$rc" == "$expected" ]]
}

check 'missing overrides fail before Docker, despite compatible host tools' run_build 1 env
check 'Docker was not invoked' test ! -s "$MOCK_CALLS"

SCONE_VERSION=6.0.8 "$fixture/overwrite.sh" > "$work/output" 2>&1
check 'source build pins scone-td-build 0.4.0 revision' grep -Fq -- '--rev b607bdc7009fc8990c2f083fdf02180f436c5369 --locked' "$MOCK_CALLS"
check 'source build pins the v6 plugin instead of main' grep -Fq -- '--rev 00044d0bbe70f005398833eb9a5efac394fd93d4 --locked' "$MOCK_CALLS"
check 'validated binaries are installed' test -x "$fixture/overwrite/bin/scone-td-build"
check 'Cargo Azure name is normalized for kubectl' test -x "$fixture/overwrite/bin/kubectl-scone-azure"
check 'Cargo Azure underscore name is not published' test ! -e "$fixture/overwrite/bin/kubectl-scone_azure"

check 'old build override fails' run_build 1 env MOCK_TD_VERSION=0.3.0
check 'invalid override never starts Docker' test ! -s "$MOCK_CALLS"
check '7.x plugin override fails' run_build 1 env MOCK_PLUGIN_VERSION=7.0.0-alpha.3
check 'plugin error names the override file' grep -Fq "$fixture/overwrite/bin/kubectl-scone" "$work/output"

mv "$fixture/overwrite/bin/scone-td-build" "$work/saved-td-build"
check 'missing override cannot fall back to host PATH' run_build 1 env
mv "$work/saved-td-build" "$fixture/overwrite/bin/scone-td-build"

sha256sum "$fixture/overwrite/bin/"* > "$work/before"
rc=0
SCONE_VERSION=6.0.8 MOCK_PLUGIN_VERSION=7.0.0-alpha.3 "$fixture/overwrite.sh" > "$work/output" 2>&1 || rc=$?
check 'failed source validation aborts publication' test "$rc" = 1
sha256sum "$fixture/overwrite/bin/"* > "$work/after"
check 'failed source validation preserves previous overrides' cmp -s "$work/before" "$work/after"

# Fail after one file has been fully staged, before any existing file is replaced.
mkdir "$work/fault"
cat > "$work/fault/sitecustomize.py" <<'FAULT'
import errno
import shutil
original = shutil.copyfileobj
calls = 0
def full_disk(*args, **kwargs):
    global calls
    calls += 1
    if calls == 2:
        raise OSError(errno.ENOSPC, "simulated full disk")
    return original(*args, **kwargs)
shutil.copyfileobj = full_disk
FAULT
rc=0
SCONE_VERSION=6.0.8 PYTHONPATH="$work/fault" "$fixture/overwrite.sh" > "$work/output" 2>&1 || rc=$?
check 'full disk stops publication' test "$rc" = 1
sha256sum "$fixture/overwrite/bin/"* > "$work/after"
check 'full disk preserves every old override' cmp -s "$work/before" "$work/after"
check 'full disk reports the storage error' grep -Fq 'simulated full disk' "$work/output"

# No credentials are read by mock Docker. The wrapper only checks their presence.
if [[ -f "$HOME/.kube/config" && -f "$HOME/.docker/config.json" ]]; then
    printf 'preserve this file\n' > "$fixture/Values.credentials.yaml"
    printf 'preserve this file\n' > "$fixture/registy.credentials.yaml"
    check 'valid overrides allow the build' run_build 0 env
    check 'build uses the requested SCONE release' grep -Fq -- '--build-arg SCONE_VERSION=6.0.8' "$MOCK_CALLS"
    check 'build loads the image into dind' grep -Fq -- '--context dind buildx build --load' "$MOCK_CALLS"
    check 'build passes prepared overrides as a named context' grep -Fq -- "--build-context overrides=$fixture/overwrite" "$MOCK_CALLS"
    check 'completed image is checked without entrypoint/network' grep -Fq -- 'run --rm --network none --entrypoint /bin/bash -e SCONE_VERSION=6.0.8' "$MOCK_CALLS"
    check 'tag uses the same dind context' grep -Fq -- '--context dind tag scone:latest registry.scontain.com/workshop/scone:6.0.8' "$MOCK_CALLS"
    check 'build preserves Values credentials' grep -Fq 'preserve this file' "$fixture/Values.credentials.yaml"
    check 'build preserves registry credentials' grep -Fq 'preserve this file' "$fixture/registy.credentials.yaml"
    check 'failed image check fails the build' run_build 1 env MOCK_IMAGE_CHECK_RC=1
    if grep -Eq 'docker .* (tag|push) ' "$MOCK_CALLS"; then
        echo 'FAIL - image validation failure still tagged or pushed an image'
        failures=$((failures + 1))
    else
        echo 'ok   - failed image check prevents tagging/pushing'
    fi
    # Fail the test if build.sh inspects or executes an old pod before deployment finishes.
    cat > "$fixture/scripts/k8s_cli.sh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ "$K8S_CLI_DEPLOY_ONLY" == true && "$SCONE_VERSION" == 6.0.8 ]]
grep -Fq "docker --context dind push $CLI_IMAGE" "$MOCK_CALLS"
sleep 0.1
printf 'toolbox deployed %s\n' "$CLI_IMAGE" >> "$MOCK_CALLS"
MOCK
    cat > "$work/bin/kubectl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
grep -Fq "toolbox deployed $CLI_IMAGE" "$MOCK_CALLS"
if [[ "$*" == *'get deployment scone-toolbox'* ]]; then
    printf '%s' "$CLI_IMAGE"
elif [[ "$*" == *'exec '* ]]; then
    [[ "$*" == *'./scripts/run-all-scripts.sh'* ]]
    printf 'tested candidate image\n' >> "$MOCK_CALLS"
fi
MOCK
    chmod +x "$fixture/scripts/k8s_cli.sh" "$work/bin/kubectl"
    : > "$MOCK_CALLS"
    run_demo_test() {
        "$fixture/scripts/build.sh" --version 6.0.8 --push --test > "$work/output" 2>&1
    }
    check 'tests await deployment and execute the actual demo runner' run_demo_test
    check 'candidate is tested after synchronous deployment' grep -Fq 'tested candidate image' "$MOCK_CALLS"
else
    echo 'skip - wrapper Docker tests require kubeconfig and Docker config files to exist'
fi

# Execute the exact defaulting statement from the generated prerequisite script.
version_statement="$(sed -n '/^export SCONE_VERSION=/{p;q;}' "$repo_root/scripts/prerequisite_check.sh")"
SCONE_VERSION=6.0.9 bash -c "$version_statement"$'\n[[ "$SCONE_VERSION" == 6.0.9 ]]' > "$work/output" 2>&1 \
    || { echo 'FAIL - prerequisite script resets requested SCONE_VERSION'; failures=$((failures + 1)); }
check 'Docker context excludes local credentials' grep -Fxq 'Values.credentials.yaml' "$repo_root/.dockerignore"
# shellcheck disable=SC2016 # Match the literal Dockerfile variable expansion.
check 'Docker passes SCONE_VERSION to the installer' grep -Fq 'SCONE_VERSION="${SCONE_VERSION}" VERSION="${SCONE_VERSION}" ./scripts/install_sconecli.sh' "$repo_root/Dockerfile"
exit "$failures"
