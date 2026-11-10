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
case "$1" in
    run) exit "${MOCK_IMAGE_CHECK_RC:-0}" ;;
    create)
        # Save the install script (the argument after -c) for the Values.yaml check.
        args=("$@")
        for ((i = 0; i < ${#args[@]} - 1; i++)); do
            if [[ "${args[i]}" == -c && -n "${MOCK_INSTALL_SCRIPT:-}" ]]; then
                printf '%s\n' "${args[i + 1]}" > "$MOCK_INSTALL_SCRIPT"
            fi
        done
        echo mock-install-container ;;
    start) exit "${MOCK_INSTALL_RC:-0}" ;;
    image)
        if [[ "$2" == inspect ]]; then
            ref="${*: -1}"
            echo "${ref%:*}@sha256:0123456789abcdef"
        fi ;;
esac
MOCK
cat > "$work/bin/cosign" <<'MOCK'
#!/usr/bin/env bash
printf 'cosign %s password=%s\n' "$*" "${COSIGN_PASSWORD:-}" >> "$MOCK_CALLS"
MOCK
chmod +x "$work/bin/cargo" "$work/bin/docker" "$work/bin/cosign"
export MOCK_CALLS="$work/calls" MOCK_TOOL="$work/tool" MOCK_INSTALL_SCRIPT="$work/install-script"
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

# This must fail before override validation, Docker, or any deployment attempt.
rc=0
"$fixture/scripts/build.sh" --version 6.0.8 --test > "$work/output" 2>&1 || rc=$?
check 'test without push fails early' test "$rc" = 1
check 'test without push explains the required option' grep -Fq -- '--test requires --push or --push-to' "$work/output"
check 'test without push never invokes external tools' test ! -s "$MOCK_CALLS"

# Pushing signs the image: missing cosign settings must fail before anything is built.
for unset_vars in "COSIGN_KEY COSIGN_PASSWORD" COSIGN_KEY COSIGN_PASSWORD; do
    : > "$MOCK_CALLS"
    rc=0
    unset_args=()
    for name in $unset_vars; do unset_args+=(-u "$name"); done
    env COSIGN_KEY=/keys/cosign.key COSIGN_PASSWORD=secret env "${unset_args[@]}" \
        "$fixture/scripts/build.sh" --version 6.0.8 --push > "$work/output" 2>&1 || rc=$?
    check "push without $unset_vars fails" test "$rc" = 1
    check "push without $unset_vars names the missing settings" grep -Fq "requires: $unset_vars" "$work/output"
    check "push without $unset_vars never invokes external tools" test ! -s "$MOCK_CALLS"
done
# shellcheck disable=SC2016 # The inner shell expands $1.
check 'help documents COSIGN_KEY' bash -c '"$1" --help | grep -q "COSIGN_KEY "' _ "$fixture/scripts/build.sh"
# shellcheck disable=SC2016 # The inner shell expands $1.
check 'help documents COSIGN_PASSWORD' bash -c '"$1" --help | grep -q "COSIGN_PASSWORD "' _ "$fixture/scripts/build.sh"
export COSIGN_KEY=/keys/cosign.key COSIGN_PASSWORD=secret

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
    printf 'preserve this file\n' > "$fixture/registry.credentials.yaml"
    printf 'preserve this file\n' > "$fixture/registy.credentials.yaml"
    check 'valid overrides allow the build' run_build 0 env
    check 'build uses the requested SCONE release' grep -Fq -- '--build-arg SCONE_VERSION=6.0.8' "$MOCK_CALLS"
    # tplenv prefers Values.yaml over SCONE_VERSION: a stale Values.yaml must not win
    # over --version. Run the saved install script with the real tplenv and yq.
    # A confined yq (e.g., the snap) cannot edit files below $work: skip then.
    printf 'a: 1\n' > "$work/probe.yaml"
    if command -v tplenv >/dev/null && yq -i '.b = 2' "$work/probe.yaml" 2>/dev/null; then
        install_root="$work/install-root"
        mkdir -p "$install_root/scripts"
        cp "$repo_root/environment-variables.md" "$install_root/"
        printf 'environment:\n  REGISTRY: registry.scontain.com\n  SCONE_VERSION: 6.0.7\n' > "$install_root/Values.yaml"
        printf '#!/bin/sh\n' > "$install_root/scripts/prerequisite_check.sh"
        cat > "$install_root/scripts/install_sconecli.sh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
eval "$(tplenv --file environment-variables.md --create-values-file --eval --output /dev/null </dev/null)"
echo "$SCONE_VERSION" > installed-version
MOCK
        chmod +x "$install_root/scripts/"*.sh
        sed "s#/root/scone#$install_root#" "$MOCK_INSTALL_SCRIPT" > "$work/install-script.local"
        bash "$work/install-script.local" 6.0.8 > "$work/output" 2>&1 || true
        check '--version wins over a stale Values.yaml' grep -qx 6.0.8 "$install_root/installed-version"
        check 'Values.yaml keeps its other settings' grep -Fq 'REGISTRY: registry.scontain.com' "$install_root/Values.yaml"
        rm -f "$install_root/Values.yaml" "$install_root/installed-version"
        bash "$work/install-script.local" 6.0.8 > "$work/output" 2>&1 || true
        check '--version is used without a Values.yaml' grep -qx 6.0.8 "$install_root/installed-version"
    else
        echo 'skip - --version over Values.yaml (needs tplenv and a yq that can edit $work)'
    fi
    check 'build loads the base image into the local daemon' grep -Fq -- 'docker buildx build --load' "$MOCK_CALLS"
    check 'build never uses the Docker TCP endpoint' bash -c '! grep -Eq -- "--context dind|tcp://" "$1"' _ "$MOCK_CALLS"
    check 'install step reaches Docker via the mounted host socket' grep -Fq -- 'src=/var/run/docker.sock,dst=/mnt/docker.sock' "$MOCK_CALLS"
    check 'install step mounts credentials read-only below the tmpfs' grep -Fq -- "src=$HOME/.kube/config,dst=/mnt/kube/config,readonly" "$MOCK_CALLS"
    check 'commit restores the toolbox entrypoint' grep -Fq -- 'commit --change ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"] --change CMD ["/bin/bash"] mock-install-container scone:latest' "$MOCK_CALLS"
    check 'build passes prepared overrides as a named context' grep -Fq -- "--build-context overrides=$fixture/overwrite" "$MOCK_CALLS"
    check 'completed image is checked without entrypoint/network' grep -Fq -- 'run --rm --network none --entrypoint /bin/bash -e SCONE_VERSION=6.0.8' "$MOCK_CALLS"
    check 'completed image is tagged' grep -Fq -- 'docker tag scone:latest registry.scontain.com/workshop/scone:6.0.8' "$MOCK_CALLS"
    check 'build preserves Values credentials' grep -Fq 'preserve this file' "$fixture/Values.credentials.yaml"
    check 'build preserves registry credentials' grep -Fq 'preserve this file' "$fixture/registry.credentials.yaml"
    check 'build preserves registry credentials of the earlier name' grep -Fq 'preserve this file' "$fixture/registy.credentials.yaml"
    check 'failed install step fails the build' run_build 1 env MOCK_INSTALL_RC=1
    check 'failed install step is not committed' bash -c '! grep -Fq "docker commit" "$1"' _ "$MOCK_CALLS"
    check 'failed install container is removed' grep -Fq 'docker rm -f mock-install-container' "$MOCK_CALLS"
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
grep -Fq "docker push $CLI_IMAGE" "$MOCK_CALLS"
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
    check 'non-stable release does not move latest' bash -c '! grep -Fq "scone:latest registry.scontain.com/workshop/scone:latest" "$1"' _ "$MOCK_CALLS"
    # Releasing the stable.txt version also pushes and signs the "latest" tag.
    stable_backup="$(cat "$fixture/stable.txt")"
    echo 6.0.8 > "$fixture/stable.txt"
    : > "$MOCK_CALLS"
    check 'stable release builds and pushes' run_demo_test
    check 'stable release pushes latest' grep -Fq 'docker push registry.scontain.com/workshop/scone:latest' "$MOCK_CALLS"
    check 'stable release signs latest by digest' test "$(grep -c '^cosign sign --yes --key /keys/cosign.key registry.scontain.com/workshop/scone@sha256:0123456789abcdef' "$MOCK_CALLS")" = 2
    latest_push_line="$(grep -n '^docker push registry.scontain.com/workshop/scone:latest' "$MOCK_CALLS" | cut -d: -f1 | head -1)"
    latest_sign_line="$(grep -n '^cosign sign' "$MOCK_CALLS" | cut -d: -f1 | tail -1)"
    check 'latest is signed after it is pushed' test -n "$latest_push_line" -a "${latest_sign_line:-0}" -gt "${latest_push_line:-0}"
    : > "$MOCK_CALLS"
    run_validation_test() {
        "$fixture/scripts/build.sh" --version 6.0.8 \
            --push-to registry.scontain.com/workshop/scone-validation \
            --image-tag 6.0.8-0123456789ab --test > "$work/output" 2>&1
    }
    check 'custom validation tag is pushed and tested' run_validation_test
    check 'validation tag of the stable version does not move latest' bash -c '! grep -Eq "(push|tag scone:latest) .*-validation:latest" "$1"' _ "$MOCK_CALLS"
    printf '%s\n' "$stable_backup" > "$fixture/stable.txt"
    check 'validation uses one registry repository' grep -Fq 'push registry.scontain.com/workshop/scone-validation:6.0.8-0123456789ab' "$MOCK_CALLS"
    check 'custom image tag preserves SCONE build release' grep -Fq -- '--build-arg SCONE_VERSION=6.0.8' "$MOCK_CALLS"
    check 'pushed image is signed by digest' grep -Fq 'cosign sign --yes --key /keys/cosign.key registry.scontain.com/workshop/scone-validation@sha256:0123456789abcdef password=secret' "$MOCK_CALLS"
    push_line="$(grep -n '^docker push' "$MOCK_CALLS" | cut -d: -f1 | head -1)"
    sign_line="$(grep -n '^cosign sign' "$MOCK_CALLS" | cut -d: -f1 | head -1)"
    check 'image is signed after the push' test -n "$push_line" -a -n "$sign_line" -a "${sign_line:-0}" -gt "${push_line:-0}"
    check 'deployment uses the candidate tag' grep -Fq 'toolbox deployed registry.scontain.com/workshop/scone-validation:6.0.8-0123456789ab' "$MOCK_CALLS"
else
    echo 'skip - wrapper Docker tests require kubeconfig and Docker config files to exist'
fi

# Execute the exact defaulting statement from the generated prerequisite script.
version_statement="$(sed -n '/^export SCONE_VERSION=/{p;q;}' "$repo_root/scripts/prerequisite_check.sh")"
SCONE_VERSION=6.0.9 bash -c "$version_statement"$'\n[[ "$SCONE_VERSION" == 6.0.9 ]]' > "$work/output" 2>&1 \
    || { echo 'FAIL - prerequisite script resets requested SCONE_VERSION'; failures=$((failures + 1)); }
check 'Docker context excludes local credentials' grep -Fxq 'Values.credentials.yaml' "$repo_root/.dockerignore"
check 'Docker context excludes registry credentials' grep -Fxq 'registry.credentials.yaml' "$repo_root/.dockerignore"
check 'Docker context excludes registry credentials of the earlier name' grep -Fxq 'registy.credentials.yaml' "$repo_root/.dockerignore"
# shellcheck disable=SC2016 # Match the literal variable expansion in build.sh.
check 'build passes SCONE_VERSION to the installer' grep -Fq 'export SCONE_VERSION="$1" VERSION="$1"' "$repo_root/scripts/build.sh"
exit "$failures"
