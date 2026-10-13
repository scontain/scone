#!/usr/bin/env bash
# Exercise the actual toolbox script and renderer against stale saved image defaults.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
real_tplenv="$(command -v tplenv)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fixture="$work/repo"
mkdir -p "$fixture/scripts" "$fixture/k8s" "$work/bin"
cp "$repo_root/scripts/k8s_cli.sh" "$repo_root/scripts/configure-toolbox-ssh.py" "$repo_root/scripts/reconcile-toolbox-registry.py" "$fixture/scripts/"
cp "$repo_root"/k8s/*.template.yaml "$fixture/k8s/"
cp "$repo_root/stable.txt" "$repo_root/registry.credentials.md" "$repo_root/toolbox.credentials.md" "$repo_root/environment-variables-k8s.md" "$fixture/"
cat > "$fixture/Values.yaml" <<'VALUES'
environment:
  CLI_IMAGE: registry.scontain.com/workshop/scone
  CLI_NAMESPACE: saved-namespace
  SCONE_VERSION: 6.0.8
  SSH_PUB_KEY: stale-shared-key
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
if [[ "${MOCK_FAIL_VALUES:-false}" == true && "$*" == *environment-variables-k8s.md* ]]; then
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == --values ]]; then
            printf 'partial values\n' > "$2"
            exit 1
        fi
        shift
    done
fi
if [[ "${MOCK_FAIL_CREDENTIALS:-false}" == true && "$*" == *toolbox.credentials.md* ]]; then
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == --values ]]; then
            printf 'partial credentials\n' > "$2"
            exit 1
        fi
        shift
    done
fi
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
#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

arguments = sys.argv[1:]
with open(os.environ["MOCK_CALLS"], "a") as output:
    output.write("kubectl " + " ".join(arguments) + "\n")
if arguments == ["apply", "-f", "-"]:
    content = sys.stdin.read()
    if content.lstrip().startswith("{"):
        secrets = json.loads(content)
        if os.environ.get("MOCK_FAIL_SECRET") == "true":
            # kubectl errors can echo the submitted object. Setup must hide it
            # and stop before replacing the deployment.
            print(content, file=sys.stderr)
            sys.exit(1)
        Path(os.environ["MOCK_SECRETS"]).write_text(json.dumps(secrets))
        with open(os.environ["MOCK_CALLS"], "a") as output:
            output.write("registry secrets applied\n")
elif "get" in arguments and "pod" in arguments:
    print("toolbox-pod")
elif "exec" in arguments and "scone-td-build" in arguments and "--version" in arguments:
    print("scone-td-build 0.4.0")
MOCK
chmod +x "$work/bin/tplenv" "$work/bin/kubectl"
export MOCK_REAL_TPLENV="$real_tplenv" MOCK_CALLS="$work/calls" MOCK_SECRETS="$work/secrets.json"
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
grep -Fq 'value: "test-key"' "$fixture/k8s/deployment.yaml"
grep -Fq 'SSH_PUB_KEY: test-key' "$fixture/Values.credentials.yaml"
grep -Fq 'REGISTRY_TOKEN: test-token' "$fixture/Values.credentials.yaml"
printf 'ok - shared SSH key is ignored and the local key preserves registry credentials\n'

run_toolbox env SSH_PUB_KEY=explicit-key
grep -Fq 'value: "explicit-key"' "$fixture/k8s/deployment.yaml"
printf 'ok - explicit SSH key overrides saved local credentials\n'
run_toolbox env -u SSH_PUB_KEY
grep -Fq 'value: "test-key"' "$fixture/k8s/deployment.yaml"
printf 'ok - saved local SSH key takes precedence over auto-detected defaults\n'

run_toolbox env CLI_IMAGE=registry.scontain.com/workshop/scone-validation:6.0.8-candidate CLI_NAMESPACE=validation SCONE_VERSION=6.0.8 TOOLBOX_SSH_PORT=2200
grep -Fq 'image: registry.scontain.com/workshop/scone-validation:6.0.8-candidate' "$fixture/k8s/deployment.yaml"
for file in deployment dind rbac; do
    grep -Fq 'namespace: validation' "$fixture/k8s/$file.yaml"
done
if grep -Fq -- '-- bash' "$MOCK_CALLS"; then
    echo 'FAIL - deployment-only mode opens an interactive shell' >&2
    exit 1
fi
printf 'ok - candidate image and namespace override saved defaults\n'
grep -Fq 'port-forward deploy/scone-toolbox 2200:22' "$work/output"
grep -Fq -- '-p 2200 root@127.0.0.1' "$work/output"
printf 'ok - toolbox SSH instructions use the configured local port\n'
for namespace in java-demo ci-scone-td-build nfs-demo governance-demo pet-clinic; do
    grep -Fq "create ns $namespace --dry-run=client" "$MOCK_CALLS"
done
# The rendered file holds the last namespace of the list.
grep -Fq 'namespace: pet-clinic' "$fixture/k8s/demo-rbac.yaml"
grep -Fq 'name: scone-demo-runner-validation' "$fixture/k8s/demo-rbac.yaml"
grep -Fq 'namespace: validation' "$fixture/k8s/demo-rbac.yaml"
printf 'ok - standard demo namespaces are provisioned with the selected toolbox account\n'

run_toolbox env TOOLBOX_DEMO_NAMESPACES=custom-demo
grep -Fq 'create ns custom-demo --dry-run=client' "$MOCK_CALLS"
grep -Fq 'namespace: custom-demo' "$fixture/k8s/demo-rbac.yaml"
if grep -Fq 'create ns java-demo --dry-run=client' "$MOCK_CALLS"; then
    echo 'FAIL - custom demo namespace list was ignored' >&2
    exit 1
fi
printf 'ok - demo namespace list can be overridden\n'
run_toolbox env TOOLBOX_DEMO_NAMESPACES=
if grep -Fq 'apply -f ./k8s/demo-rbac.yaml' "$MOCK_CALLS"; then
    echo 'FAIL - empty demo namespace list was ignored' >&2
    exit 1
fi
printf 'ok - explicit empty demo namespace list skips additional provisioning\n'


run_toolbox env -u CLI_IMAGE SCONE_VERSION=6.0.9
grep -Fq 'image: registry.scontain.com/workshop/scone:6.0.9' "$fixture/k8s/deployment.yaml"
printf 'ok - explicit SCONE version overrides saved version\n'

# Ambient credentials must retain tplenv's normal saved-value precedence.
run_toolbox env REGISTRY=ambient.invalid REGISTRY_USER=ambient-user REGISTRY_TOKEN=ambient-token
python3 - "$MOCK_SECRETS" "$MOCK_CALLS" <<'CHECK'
import base64
import json
from pathlib import Path
import sys

items = {item["metadata"]["name"]: item for item in json.loads(Path(sys.argv[1]).read_text())["items"]}
assert set(items) == {"scone-registry", "sconeapps", "scone-registry-env"}
for name in ("scone-registry", "sconeapps"):
    config = json.loads(base64.b64decode(items[name]["data"][".dockerconfigjson"]))
    assert set(config["auths"]) == {"registry.scontain.com"}
    assert base64.b64decode(config["auths"]["registry.scontain.com"]["auth"]).decode() == "test-user:test-token"
log = Path(sys.argv[2]).read_text()
assert log.index("registry secrets applied") < log.index("delete deployment/scone-toolbox")
assert "test-token" not in log and "ambient-token" not in log
CHECK
printf 'ok - tplenv-selected credentials update all secrets before deployment\n'

cp "$fixture/Values.credentials.yaml" "$work/original-credentials"
cat > "$fixture/Values.credentials.yaml.new" <<'VALUES'
environment:
  REGISTRY: alternate.example:5443
  REGISTRY_USER: rotated-user
  REGISTRY_TOKEN: rotated-token
  SSH_PUB_KEY: test-key
VALUES
mv "$fixture/Values.credentials.yaml.new" "$fixture/Values.credentials.yaml"
run_toolbox env CLI_IMAGE=alternate.example:5443/workshop/scone:6.0.8
python3 - "$MOCK_SECRETS" <<'CHECK'
import base64
import json
from pathlib import Path
import sys

items = {item["metadata"]["name"]: item for item in json.loads(Path(sys.argv[1]).read_text())["items"]}
for name in ("scone-registry", "sconeapps"):
    config = json.loads(base64.b64decode(items[name]["data"][".dockerconfigjson"]))
    assert set(config["auths"]) == {"alternate.example:5443"}
    assert base64.b64decode(config["auths"]["alternate.example:5443"]["auth"]).decode() == "rotated-user:rotated-token"
environment = base64.b64decode(items["scone-registry-env"]["data"]["scone-registry-env"]).decode()
assert "REGISTRY=alternate.example:5443" in environment
assert "REGISTRY_USER=rotated-user" in environment
assert "REGISTRY_TOKEN=rotated-token" in environment
CHECK
printf 'ok - rerun rotates existing pull and startup credentials including registry address\n'
[[ ! -f "$fixture/scone-registry.env" ]]
printf 'ok - setup does not write a plaintext registry credential file\n'
: > "$MOCK_CALLS"
if (cd "$fixture" && MOCK_FAIL_SECRET=true ./scripts/k8s_cli.sh > "$work/output" 2>&1); then
    echo 'FAIL - failed secret update reported success' >&2
    exit 1
fi
if grep -Fq 'delete deployment/scone-toolbox' "$MOCK_CALLS"; then
    echo 'FAIL - failed secret update still replaced the toolbox' >&2
    exit 1
fi
if grep -Fq '".dockerconfigjson": "' "$work/output" || grep -Fq '"scone-registry-env": "' "$work/output"; then
    echo 'FAIL - failed secret update leaked credential values' >&2
    exit 1
fi
printf 'ok - secret update failure stops deployment without printing credential payloads\n'
mv "$work/original-credentials" "$fixture/Values.credentials.yaml"


# Cover the first run, when tplenv creates Values.yaml from the environment.
rm "$fixture/Values.yaml"
run_toolbox env -u CLI_IMAGE -u CLI_NAMESPACE SCONE_VERSION=6.0.8
grep -Fxq '  CLI_IMAGE: registry.scontain.com/workshop/scone' "$fixture/Values.yaml"
if grep -q SSH_PUB_KEY "$fixture/Values.yaml"; then
    echo 'FAIL - first run saved a user key in shared Values.yaml' >&2
    exit 1
fi
run_toolbox env -u CLI_IMAGE SCONE_VERSION=6.0.9
grep -Fq 'image: registry.scontain.com/workshop/scone:6.0.9' "$fixture/k8s/deployment.yaml"
printf 'ok - fresh saved default stays untagged and follows later SCONE releases\n'

# Failed updates must preserve saved defaults as well as local credentials.
sha256sum "$fixture/Values.yaml" > "$work/values-before"
if (cd "$fixture" && MOCK_FAIL_VALUES=true ./scripts/k8s_cli.sh > "$work/output" 2>&1); then
    echo 'FAIL - failed values render reported success' >&2
    exit 1
fi
sha256sum "$fixture/Values.yaml" > "$work/values-after"
cmp -s "$work/values-before" "$work/values-after"
printf 'ok - failed shared values update preserves saved defaults\n'

# A failed credential render must preserve all prior local values.
sha256sum "$fixture/Values.credentials.yaml" > "$work/credentials-before"
if (cd "$fixture" && MOCK_FAIL_CREDENTIALS=true ./scripts/k8s_cli.sh > "$work/output" 2>&1); then
    echo 'FAIL - failed credentials render reported success' >&2
    exit 1
fi
sha256sum "$fixture/Values.credentials.yaml" > "$work/credentials-after"
cmp -s "$work/credentials-before" "$work/credentials-after"
printf 'ok - failed credentials update preserves local keys and registry credentials\n'

sha256sum "$fixture/k8s/deployment.yaml" > "$work/before"
if (cd "$fixture" && MOCK_FAIL_RENDER=true ./scripts/k8s_cli.sh > "$work/output" 2>&1); then
    echo 'FAIL - failed manifest render reported success' >&2
    exit 1
fi
sha256sum "$fixture/k8s/deployment.yaml" > "$work/after"
cmp -s "$work/before" "$work/after"
printf 'ok - failed render preserves the previous deployment manifest\n'
