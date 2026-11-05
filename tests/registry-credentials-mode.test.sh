#!/usr/bin/env bash
# Run the registry credential prompts of the generated scripts with the real
# tplenv. The saved token must be readable only by its owner, both in a new
# file and in one that an earlier run left readable by other users.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
umask 022

for script in prerequisite_check.sh reconcile_scone_operator.sh; do
    # The executed lines, not their printed copies, that save the credentials.
    snippet="$work/$script.snippet"
    awk '!/^printf / && /chmod 600 Values\.credentials\.yaml|tplenv --values Values\.credentials\.yaml/' \
        "$repo_root/scripts/$script" > "$snippet"
    if ! grep -q 'tplenv --values Values.credentials.yaml' "$snippet"; then
        echo "FAIL - $script no longer asks for registry credentials; update this test" >&2
        exit 1
    fi
    for saved in none readable; do
        dir="$work/$script-$saved"
        mkdir -p "$dir"
        cp "$repo_root/registry.credentials.md" "$dir/"
        input=$'registry.scontain.com\nnew-user\nnew-token'
        expected=new-token
        if [[ "$saved" == readable ]]; then
            printf 'environment:\n  REGISTRY: registry.scontain.com\n  REGISTRY_USER: old-user\n  REGISTRY_TOKEN: old-token\n' \
                > "$dir/Values.credentials.yaml"
            chmod 644 "$dir/Values.credentials.yaml"
            input=$'\n\n'
            expected=old-token
        fi
        if ! (
            cd "$dir"
            export WD="$dir"
            # shellcheck source=/dev/null
            source "$snippet"
            [[ "$REGISTRY_TOKEN" == "$expected" ]] || { echo "token is '$REGISTRY_TOKEN'"; exit 1; }
            [[ "$(umask)" == 0022 ]] || { echo "umask changed to $(umask)"; exit 1; }
        ) <<< "$input" > "$dir/log" 2>&1; then
            echo "FAIL - $script with $saved saved credentials:" >&2
            cat "$dir/log" >&2
            exit 1
        fi
        if [[ -z "$(find "$dir/Values.credentials.yaml" -perm 600)" ]]; then
            echo "FAIL - $script with $saved saved credentials leaves this mode:" >&2
            ls -l "$dir/Values.credentials.yaml" >&2
            exit 1
        fi
        grep -Fq "REGISTRY_TOKEN: $expected" "$dir/Values.credentials.yaml"
    done
    printf 'ok - %s keeps saved registry credentials private\n' "$script"
done
