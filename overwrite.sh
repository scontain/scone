#!/usr/bin/env bash
# Build and validate the binaries copied into the workshop image.
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: SCONE_VERSION=<release> ./overwrite.sh [--validate-latest]

Without options, build and install the pinned workshop tool overrides.
--validate-latest  Build the latest scone-td-build main revision in a temporary
                   override set, push a validation image, and run all demos.
                   Requires Docker, registry push access, and a disposable cluster.
USAGE
}

validate_latest=false
case "${1:-}" in
    "") ;;
    --validate-latest)
        [[ $# == 1 ]] || { usage >&2; exit 2; }
        validate_latest=true
        ;;
    --help|-h)
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target_version="${SCONE_VERSION:-$(cat "$repo_root/stable.txt")}"
# This revision is 0.4.0 and supports the demos' cas-endpoint manifests.
td_build_rev="${SCONE_TD_BUILD_REV:-b607bdc7009fc8990c2f083fdf02180f436c5369}"
if [[ "$validate_latest" == true ]]; then
    command -v git >/dev/null || { echo "ERROR: missing git" >&2; exit 1; }
    latest_ref="$(git ls-remote https://github.com/scontain/scone-td-build.git refs/heads/main | awk '$2 == "refs/heads/main" { print $1; exit }')"
    if [[ ! "$latest_ref" =~ ^[[:xdigit:]]{40}$ ]]; then
        echo "ERROR: could not resolve the latest scone-td-build main revision" >&2
        exit 1
    fi
    td_build_rev="$latest_ref"
    echo "Validating latest scone-td-build main revision: $td_build_rev"
fi
# This revision is kubectl-scone 6.0.5 with the v6 boolean autoUpdate schema.
plugin_rev="${SCONE_KUBECTL_PLUGIN_REV:-}"
if [[ -z "$plugin_rev" ]]; then
    case "$target_version" in
        6.0.*) plugin_rev=00044d0bbe70f005398833eb9a5efac394fd93d4 ;;
        *) echo "ERROR: set SCONE_KUBECTL_PLUGIN_REV to a compatible revision for SCONE $target_version" >&2; exit 1 ;;
    esac
fi

for tool in cargo python3; do
    command -v "$tool" >/dev/null || { echo "ERROR: missing $tool" >&2; exit 1; }
done
provision_binary="${KUBECTL_PROVISION_BINARY:-$HOME/.cargo/bin/kubectl-provision}"
[[ -f "$provision_binary" && -x "$provision_binary" ]] || {
    echo "ERROR: missing executable $provision_binary; set KUBECTL_PROVISION_BINARY" >&2
    exit 1
}

# Build in a temporary root. Failed builds/checks preserve the previous overrides.
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
export CARGO_NET_GIT_FETCH_WITH_CLI=true
printf 'Building overrides for SCONE %s: td-build %s, kubectl-scone %s\n' \
    "$target_version" "$td_build_rev" "$plugin_rev"

cargo install tplenv --locked --root "$staging"
cargo install retry-spinner --locked --root "$staging"
cargo install --git https://github.com/scontain/scone-td-build.git \
    --rev "$td_build_rev" --locked --root "$staging" scone-td-build
cargo install --git https://github.com/scontain/kubectl-plugin \
    --rev "$plugin_rev" --locked --root "$staging" kubectl-scone
cp "$provision_binary" "$staging/bin/kubectl-provision"
cargo install --git https://github.com/scontain-gmbh/kubectl-scone-azure.git \
    --branch laerson/workshop --locked --root "$staging" kubectl-scone-azure
# Cargo maps the crate target's underscore to a binary name with an underscore;
# kubectl requires the plugin executable to use the hyphenated command name.
if [[ -x "$staging/bin/kubectl-scone_azure" ]]; then
    mv "$staging/bin/kubectl-scone_azure" "$staging/bin/kubectl-scone-azure"
fi

SCONE_VERSION="$target_version" "$repo_root/scripts/check-scone-tooling.sh" --overrides-dir "$staging/bin"

if [[ "$validate_latest" == true ]]; then
    revision_suffix="${td_build_rev:0:12}"
    validation_repository="registry.scontain.com/workshop/scone-validation"
    validation_tag="${target_version}-${revision_suffix}"
    echo "Running the workshop demo suite using ${validation_repository}:${validation_tag}."
    echo "The validation image will remain in the registry; the current overwrite/bin files will not be changed."
    SCONE_OVERRIDE_DIR="$staging" "$repo_root/scripts/build.sh" \
        --version "$target_version" --push-to "$validation_repository" --image-tag "$validation_tag" --test
    echo "Latest scone-td-build revision $td_build_rev passed the workshop demo suite."
    printf 'To install this validated revision: SCONE_VERSION=%q SCONE_TD_BUILD_REV=%q %q\n' \
        "$target_version" "$td_build_rev" "$repo_root/overwrite.sh"
    exit 0
fi

# Copy every file fully and fsync it before replacing any existing binary.
# Temporary files live on the destination filesystem, so rename is atomic.
python3 - "$staging/bin" "$repo_root/overwrite/bin" <<'PUBLISH'
import os
from pathlib import Path
import shutil
import sys
import tempfile

source, destination = map(Path, sys.argv[1:])
destination.mkdir(parents=True, exist_ok=True)
pending = []
try:
    for binary in sorted(source.iterdir()):
        fd, temporary = tempfile.mkstemp(prefix=f".{binary.name}.", dir=destination)
        pending.append((temporary, destination / binary.name))
        with os.fdopen(fd, "wb") as output, binary.open("rb") as input_file:
            shutil.copyfileobj(input_file, output)
            output.flush()
            os.fchmod(output.fileno(), 0o755)
            os.fsync(output.fileno())
    for temporary, binary in pending:
        os.replace(temporary, binary)
    directory = os.open(destination, os.O_DIRECTORY)
    try:
        os.fsync(directory)
    finally:
        os.close(directory)
finally:
    for temporary, _ in pending:
        if os.path.exists(temporary):
            os.unlink(temporary)
PUBLISH

echo "Validated overrides installed in $repo_root/overwrite/bin"
