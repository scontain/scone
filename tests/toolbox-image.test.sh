#!/usr/bin/env bash
# Exercise the actual toolbox script and renderer against stale saved image defaults.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
real_tplenv="$(command -v tplenv)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fixture="$work/repo"
mkdir -p "$fixture/scripts" "$fixture/k8s" "$work/bin"
cp "$repo_root/scripts/k8s_cli.sh" "$repo_root/scripts/configure-toolbox-ssh.py" "$fixture/scripts/"
cp "$repo_root"/k8s/*.template.yaml "$fixture/k8s/"
cp "$repo_root/stable.txt" "$repo_root/registry.credentials.md" "$repo_root/environment-variables-k8s.md" "$fixture/"
cat > "$fixture/Values.yaml" <<'VALUES'
environment:
  CLI_IMAGE: registry.scontain.com/workshop/scone
  CLI_NAMESPACE: saved-namespace
  SCONE_VERSION: 6.0.8
  SSH_PUB_KEY: test-key
  REGISTRY: registry.scontain.com
VALUES
cat > "$fixture/Values.credentials.yaml" <<'VALUES'
environment:
  REGISTRY: registry.scontain.com
  REGISTRY_USER: test-user
  REGISTRY_TOKEN: test-token
VALUES
cat > "$work/bin/tplenv" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${MOCK_FAIL_RENDER:-false}" == true && "$*" == *deployment.template.yaml* ]]; then
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == --output ]]; then
            printf 'partial output\n' > "$2"
            exit 1
        fi
        shift
    done
fi
exec "$MOCK_REAL_TPLENV" "$@"
MOCK
cat > "$work/bin/kubectl" <<'MOCK'
#!/usr/bin/env bash
printf 'kubectl %s\n' "$*" >> "$MOCK_CALLS"
case "$*" in
    *'get pod '*) echo toolbox-pod ;;
    *'exec '*scone-td-build*'--version') echo 'scone-td-build 0.4.0' ;;
esac
exit 0
MOCK
chmod +x "$work/bin/tplenv" "$work/bin/kubectl"
export MOCK_REAL_TPLENV="$real_tplenv" MOCK_CALLS="$work/calls"
export PATH="$work/bin:$PATH" SSH_PUB_KEY=test-key K8S_CLI_DEPLOY_ONLY=true
export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""
export TOOLBOX_SSH_CONFIG="$work/ssh/config"
run_toolbox() {
    : > "$MOCK_CALLS"
    (cd "$fixture" && "$@" ./scripts/k8s_cli.sh > "$work/output" 2>&1) || {
        cat "$work/output"
        return 1
    }
}

run_toolbox env -u CLI_IMAGE -u CLI_NAMESPACE -u SCONE_VERSION
grep -Fq 'image: registry.scontain.com/workshop/scone:6.0.8' "$fixture/k8s/deployment.yaml"
grep -Fq 'namespace: saved-namespace' "$fixture/k8s/deployment.yaml"
printf 'ok - untagged saved default renders the selected SCONE version\n'

run_toolbox env CLI_IMAGE=registry.scontain.com/workshop/scone-validation-candidate:6.0.8 CLI_NAMESPACE=validation SCONE_VERSION=6.0.8
grep -Fq 'image: registry.scontain.com/workshop/scone-validation-candidate:6.0.8' "$fixture/k8s/deployment.yaml"
for file in deployment dind rbac; do
    grep -Fq 'namespace: validation' "$fixture/k8s/$file.yaml"
done
if grep -Fq -- '-- bash' "$MOCK_CALLS"; then
    echo 'FAIL - deployment-only mode opens an interactive shell' >&2
    exit 1
fi
printf 'ok - candidate image and namespace override saved defaults\n'

run_toolbox env -u CLI_IMAGE SCONE_VERSION=6.0.9
grep -Fq 'image: registry.scontain.com/workshop/scone:6.0.9' "$fixture/k8s/deployment.yaml"
printf 'ok - explicit SCONE version overrides saved version\n'

sha256sum "$fixture/k8s/deployment.yaml" > "$work/before"
if (cd "$fixture" && MOCK_FAIL_RENDER=true ./scripts/k8s_cli.sh > "$work/output" 2>&1); then
    echo 'FAIL - failed manifest render reported success' >&2
    exit 1
fi
sha256sum "$fixture/k8s/deployment.yaml" > "$work/after"
cmp -s "$work/before" "$work/after"
printf 'ok - failed render preserves the previous deployment manifest\n'
