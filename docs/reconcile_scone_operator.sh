#!/usr/bin/env bash

set -Eeuo pipefail

TYPE_SPEED="${TYPE_SPEED:-25}"
PAUSE_AFTER_CMD="${PAUSE_AFTER_CMD:-0.6}"
SHELLRC="${SHELLRC:-/dev/null}"
PROMPT="${PROMPT:-$'\[\e[1;32m\]demo\[\e[0m\]:\[\e[1;34m\]~\[\e[0m\]\$ '}"
COLUMNS="${COLUMNS:-100}"
LINES="${LINES:-26}"
ORANGE="${ORANGE:-\033[38;5;208m}"
LILAC="${LILAC:-\033[38;5;141m}"
RESET="${RESET:-\033[0m}"

slow_type() {
  local text="$*"
  local delay
  delay=$(awk "BEGIN { print 1 / $TYPE_SPEED }")
  for ((i=0; i<${#text}; i++)); do
    printf "%s" "${text:i:1}"
    sleep "$delay"
  done
}

pe() {
  local cmd="$*"
  printf "%b" "$ORANGE"
  slow_type "$cmd"
  printf "%b" "$RESET"
  printf "\n"

  if [[ -n "${PE_BUFFER:-}" ]]; then
    PE_BUFFER+=$'\n'
  fi
  PE_BUFFER+="$cmd"

  # Execute only when buffered lines form a complete shell command.
  if bash -n <(printf '%s\n' "$PE_BUFFER") 2>/dev/null; then
    eval "$PE_BUFFER"
    PE_BUFFER=""
  fi

  sleep "$PAUSE_AFTER_CMD"
}

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export COLUMNS LINES
export PS1="$PROMPT"
stty cols "$COLUMNS" rows "$LINES"

printf "%b" "$LILAC"
cat <<'EOF'
## Installation of the SCONE Platform

To install or update the SCONE platform in a Kubernetes cluster, please perform the following steps.

You can execute the steps automatically by running the script `scripts/reconcile_scone_operator.sh`. The script expects the cluster already be installed, i.e., it only upgrades to the latest stable version.

## Determine the current stable version of the SCONE platform

EOF
printf "%b" "$RESET"

pe 'export SCONE_VERSION=$(cat stable.txt)'
pe 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""'

printf "%b" "$LILAC"
cat <<'EOF'

`tplenv` will now ask the user for all environment variables that are described in file `environment-variables.md`
but that are not set yet. In case `--force` is set, the values of all environment variables need to confirmed by the user:

export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--force"

Let's ask the user and set the environment variables depending on the input of the user:

EOF
printf "%b" "$RESET"

pe 'eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'

printf "%b" "$LILAC"
cat <<'EOF'

## Make sure that we actually want to update the current cluster

EOF
printf "%b" "$RESET"

pe '# Get the current Kubernetes context'
pe 'K8S_CONTEXT=$(kubectl config current-context 2>/dev/null)'
pe ''
pe 'if [[ -z "$K8S_CONTEXT" ]]; then'
pe '  echo "❌ Could not determine the current Kubernetes context."'
pe '  exit 1'
pe 'fi'
pe ''
pe 'echo "📦 Current Kubernetes context: $K8S_CONTEXT"'
pe ''
pe '# Ask for confirmation'
pe 'read -rp "Do you want to proceed install SCONE version $SCONE_VERSION with this context? [y/N] " confirm'
pe 'confirm=${confirm,,}  # Convert to lowercase'
pe ''
pe 'if [[ "$confirm" != "y" && "$confirm" != "yes" ]]; then'
pe '  echo "❌ Aborted by user."'
pe '  exit 1'
pe 'fi'
pe ''
pe 'echo "✅ Proceeding with context: $K8S_CONTEXT"'

printf "%b" "$LILAC"
cat <<'EOF'

## Download the script to install the SCONE platform:

To simplify the cleanup, we download the installation script into a temporary directory:

EOF
printf "%b" "$RESET"

pe 'mkdir -p /tmp/SCONE_OPERATOR_CONTROLLER'
pe 'cd /tmp/SCONE_OPERATOR_CONTROLLER'
pe 'curl -fsSL https://raw.githubusercontent.com/scontain/SH/master/$SCONE_VERSION/operator_controller > operator_controller'
pe 'chmod a+x operator_controller'
pe 'echo "Downloaded script '\''operator_controller'\'' into directory $PWD"'

printf "%b" "$LILAC"
cat <<'EOF'

## Verify the signature of the script:

Download the signature of the operator controller:

EOF
printf "%b" "$RESET"

pe 'curl -fsSL https://raw.githubusercontent.com/scontain/SH/master/$SCONE_VERSION/operator_controller.asc > operator_controller.asc'
pe 'echo "Downloaded signature of '\''operator_controller'\'' to file '\''operator_controller.asc'\''"'

printf "%b" "$LILAC"
cat <<'EOF'

Define bash functions:

- `create_gpg_verification_key`: create a temporary file that contains the public key to verify the signature of the script.
- `verify_file`: verifies that the signature matches the file and the given public key.

EOF
printf "%b" "$RESET"

pe 'function create_gpg_verification_key() {'
pe '    local tmp_gpg'
pe ''
pe '    export gpg_public_key_file="$(mktemp)-pub.gpg"'
pe '    tmp_gpg="${gpg_public_key_file}.base64"'
pe ''
pe '    cat > $tmp_gpg <<EOF'
pe 'mQINBF5tGZkBEACPxl1oBdP5xKWB/EaEkW3UwMEnpNJeOFjVysT5B3ZfK6OGqtZDYKsQEGtptJ54'
pe 'Wy9dvd33UpZUNRmCL6X1GeEd/DLd7t+sk3Cm414pC9Qmx9tkTeLMkCZb6QHufblz3kJkV1E86vre'
pe 'PbrVTZ2q4cLJl4G/IlNKwHsY/7/4yEcBkEZ8L1TOgsotnLnuYOlf/XbPcF4tqdEV+H1nTHGjwcSP'
pe 'qbIHDA3N8a0aNELRvcTH5tj9YluSUCgC4S4EqwgL09BfOITN6lSJihgZMqP9sHlbj4SWfxvVOyXd'
pe '7lSpNSB+nq0DQS1q6lNURnynTZYDwsbmKWbtd/qft2Z1Rs3lBIsIM/sVyVGRS5oOuzVo5CHuhfuP'
pe '1LUCPQpRXamJvS64Tx0eWl4s+HD37Cz1H9MN0zo9dScSEi3c5pJo8GgH6FQyM0miqXmP5VmuUFN8'
pe 'Qe76wkrBE+TJGSSiLewBCOlowrE1m8fX9ZZ0V17sJx9ya0jvinwXMEzN9zLppychdMyJoLEyGplr'
pe '3swCYTPytRwdwOq87srkd63LvXSXg29ozWt1Rx25VagBZflZXg1H0dHDgNvzxsFwEQWYDBmG3vh5'
pe 'i75Ny7DfrRJVeMbPds7McWEiusO/Rk8JXpLJqwA2fjkUC2kavzfCrVMxJ927QJyaOXGx53nXDBSg'
pe 'wmjC3yYRK4LohQARAQABtC5DaHJpc3RvZiBGZXR6ZXIgPGNocmlzdG9mLmZldHplckBzY29udGFp'
pe 'bi5jb20+iQJOBBMBCgA4FiEEW8rTHcyNXXIre3q9Lr4E58yBbTIFAl5tGZkCGwMFCwkIBwIGFQoJ'
pe 'CAsCBBYCAwECHgECF4AACgkQLr4E58yBbTKwVg//SJ6T9x+7YItMCevjU6td7wDJKwOyvFINXP/0'
pe 'ktDRGfrdy+YDCMkuQUMxkL0j65/AjaicndmvEj/ThGN7cJfyA2FrnmL402glJPWScL+LiMiwonBn'
pe 'h6Y9hkTTRmbDPBNuPaa+fXdqfZRfa2Pzhj8aW7e3kKChxGCoLG4uM5+yEI07LsmsIG8VkkWTplhG'
pe 'LQaXc3wRN4oMTNflG8OlmvtooxpuGNgOoAgj7k1T35LjoZ+mE9mNH8a41eDk3c2PAB3t7/rYxstK'
pe 'CGPcJd0K9R5ZXDlkbqvDKuAO83E0pI0zw1BsksA3W5XfmCo8Jf2UqtWW4XBxWJvDS8ywVTXduZR8'
pe 'ean681VEICrYUBtTWDrAfWKGNNQMD7w6KWK8gwWRTqECr2eSzYkaFX7tyd2Dc47/R8uTHXgg4chR'
pe 'Ke0oL+yiAmPqcOjwEn2Y0e7I2Wj70N69EBcf/lFXy1Q67RGO+oCifwjhwkYkELdRt5NVpaUnnEkS'
pe '2p82fOomo2Vxrh8wGaTABub+fzLYicnKda1zO7VjzrOmjC0GMo8wApyNJhv+JfWXDJ1pOCpRIuMc'
pe 'PJykpFXTRw7KN88924etDM8j1sOBV/YcL8nPiRMdAzp4X1fg2QNndiGaWDejoD8NF3yVssInKmg+'
pe 'neRUytPu75nke9AcdaY6bMlTWbGNOekuwe1oRfC5Ag0EXm0ZmQEQAKXucWCoTWN7jViqpS3NnLgF'
pe 'JfPvsvePT99WRUHIODuXTskLMipLG41U7s0E3IM3orY00GlmI3IfNjzPKMQV98yfldgZ1gnA91Uy'
pe 'UnrjI+7kPr6wa5cDdLMNj+BUcp2V6t8qUE2YT7v2af4VgIWUnXnhQAx/DNhncUpPCQqJ8kZ3s9LA'
pe 'Ezy74Cqgu/0/3v5wVTszh67uMwfm1QMj0u2hzr3ZkEHnVdGpWfvG5dQj+3WqLT3miVcNFIVPgY2P'
pe 'hiivlekxn1MX9BG4kn/QtibNmBZvLyj0F0mssUKN+DFr7M7JxTlNxxDhtvaIAllXsBs06zPxKTou'
pe 'A2Q1iNZQYoVr43MTocfvbY8LlB618qmVUO/8hQvSl8Fh72uE986xB4+a1PDWJkDRlHxi409Y1mXR'
pe 'pkCNWrA5xvcX0IHgpnwR/NxFX6SvAuwNeCC6fo9zQ5GoZWnmCrI0dthLfluslrK4uvMdpDqLYpVm'
pe 'i6B1uB+oOBV9umIB1NhMi6u6SaQJ8pefLveGDCqmCbF5yAuVXXT+n2XQZBeOefiyAhtDwqDKXvI5'
pe 'M2Smw5nzMqgXu5bs5WLMNqn0zvphKam11bF0LHtxp/UCZXO+o6L22le2luMxFjDMcI0Sah73Jwno'
pe 'hqFkxG34tws0WR5lioi+PgoEa0jXYGexyFO74Xvo8XWH5TjiS3dTABEBAAGJAjYEGAEKACAWIQRb'
pe 'ytMdzI1dcit7er0uvgTnzIFtMgUCXm0ZmQIbIAAKCRAuvgTnzIFtMjaBD/9iYzR0h6tg+uVG8FA5'
pe 'iy/wi/Qb8C86UnSr73sZZJlH17rVjz51httE7fmN48QkQ2VKYRDh50NWC05W/2cRbtIwqmlkXzAS'
pe 'ys04uBuROMAj5zeM4v9SqLCSWUguO1LItOuFqqqML12uwm3EfhmTmseZB2LND+ZxZG8OiZeun1d1'
pe '+CyZHrgn+xQ5SyUt9bzdZp/JAu05iN/e7E9/zrulCW0RPtOl8C4lgeaoNIBOAOYrvjUtD8vvNuiO'
pe 'S6goGwsUUMhap8UdW1O8b+acpQaRcdlNxaNXoz/TpG7GeguXyyWvHNKHjlV/PMX35ItVGl9FZ1ph'
pe 'zNe+xTBjpI7U505bTfekfyS5Y6kTI0v+HvptNZFNF7Iubssl0tCxp0u+iPMz6xuIy2FWGQIWDUta'
pe '16CcaolmluBmoFJ4BfAjh4ur60jEfe+UaHyat09khfF6HRZpIM7henB7C+GFeVROHMRdQaw1y7EF'
pe '7xgN6hxuM5OTWwlYxQkNu84hWzjxwhj6/KKV8Tz1vmJPglChTQLY7COpD4q/vOQmJyGFCDu3RYxb'
pe 'rIIkr/itIAyQXgsxtlqTVAyU6F7r3pIM91nj8QxYNW5c3os7Z0gdXpe3Dbdvt3vn4MZqhB/9haIO'
pe 'NyTbLJcUrjHio1AmCo3k1ued73dDdneWdn7TKITKfU/8lb9v6XEdkSHJxLkCDQRebRmZARAAiPvf'
pe '2FfDfORqIlGk5Is/5MaBTzrQj/VABF5HzsOqVEKF557CVmKu5qa0B7W1jsrPKyWkqTzGUyfejSgI'
pe 'YUBAocaaQHE/mIS3CQLwKDPRIRg4onzHXZjmjcwDjjFcGMjakMkFgNgfMw61LT2LH621g/vLm0qq'
pe 'KClWYqVY++yoJcJC1RSiNKam24bsYwZeGaGHCulga7igqB1U1dW8KsyBzW2Z5I1yXWc+fgm3Q4DS'
pe 'ulpiuSMKGSmAg/uNUfVyFEjIFBQk2Ls+8XvuGux5+0ICig6gLazb3fdymtmBi7VIsozsp2r5KC4h'
pe '+4QqZjDZ6QOjBFScB79XDDQ/hLJMfYerWBM5LyMKuLnsFVa6mQckpikpyl2BujlNTzFD58hDcpsm'
pe 'qI3BXbqqbGEQWuaoTNWVqQv1qu9mwqDacTthX9fdTGnzibbm2/0hQSpbQ3ZexGvzzhT4bB1Cgc8X'
pe '7C2vPclpi8H4kzcOo7gIicwJuwLaOD8QRGqKPZIta32Agzb3tDB2MXGuhOL2eCSAx2aDosAzlLD6'
pe '2mnrHelc6vKchhViQBiZKPFiNSL7KN+vEbhstB+mx9UltcopwcuynoTPm8HuVpM2HFJLPlkK5gTb'
pe 'xtCUlW9fGREx2jwqioYuju4mfS2kcbqR8O8+lvnkoiIYxLk9x+SXTOCtWq8wG+3uqiCvqd0AEQEA'
pe 'AYkCNgQYAQoAIBYhBFvK0x3MjV1yK3t6vS6+BOfMgW0yBQJebRmZAhsMAAoJEC6+BOfMgW0yn70P'
pe '/AqRl7P7d2NX1Y0ZAqm2XlHrO6q+yltKC27Yu+mvzo0vIpiCsx2moUwXKpnbUE+ovQieDtRswvDz'
pe '6LWVyvM/c3ogQJ3/cLbu9aAsTkUF1TFWFyYs9WGDmt+mv9q1+99HdPw1dG683B0gEjQxIuKeKiii'
pe 'e64SdHNU51FM81HjXh94kFj5HPQ0QJ1/DzXdFLu9aG3Ja5Nl2mMK+BOY1B3SXNZGwoSk0oZM3Su1'
pe 'VkvxlQlLi8B8CBLUEE+JNhw1qNx55LGZJSB95DoIrvloADqy7braEKNgDZ3GBWjupMt6MeX2n/Fk'
pe 'R4xMEkNO4Qlwy7eARz1Yx9WTjFT8L6a/xp2PEKe8zmTkObUQzRTwDvcoXbl/B3nT0w/RlbLaXEtd'
pe 'dTC5h5UPz9avSlLYSblGFxf84PXuEKIKWpDQzybMAfRwqBc5OTOnkkl6OXYiXLxdVEsaRlTtYHI4'
pe 'QSvBZDzbO12jXPv78zVVkRjr7mljcPMB2iDRSeWO073ov1oxEeCmzzhyq8/7q0SrjR3J6g3b4k15'
pe 'NSHb32Obz9x+L+3Oo/r5oYf+T0B51YvOfz6O9BxoI3icZL1KJ2MtbtmYkE/UNNnNB4XApQGoZk5i'
pe 'BtcmftSsf9VCHB0IDPbyH6sro8MNyF81i5MewmQ99tdYE9UIiwNYa/10PRUClKWrEvxIOAK/K3sW'
pe 'EOF'
pe '    cat "$tmp_gpg" | base64 -d > $gpg_public_key_file'
pe '}'
pe ''
pe '#'
pe '# Public Key used to sign manifests'
pe '#'
pe ''
pe 'SIGNER="5BCAD31DCC8D5D722B7B7ABD2EBE04E7CC816D32"'
pe ''
pe 'function verify_file() {'
pe '    file=$1'
pe ''
pe '    export gpg_public_key_file=${gpg_public_key_file:-""}'
pe '    if [[ "$gpg_public_key_file" == "" ]]; then'
pe '        create_gpg_verification_key'
pe '    fi'
pe '    LC_ALL=en_US.UTF-8 gpg --no-default-keyring --keyring $gpg_public_key_file --verify --status-fd=1 "$file.asc" "$file" 2>/dev/null | grep -e " VALIDSIG $SIGNER" >/dev/null || { echo "Signature check FAILED" ; return 1; }'
pe '}'

printf "%b" "$LILAC"
cat <<'EOF'

Next, we verify the signature of the script `operator_controller`:

EOF
printf "%b" "$RESET"

pe 'verify_file operator_controller'

printf "%b" "$LILAC"
cat <<'EOF'

Please check that output is empty. Stop if error message `Signature check FAILED` is printed.

## Verifying if the cluster is properly installed:

We first define a cleanup function to cleanup after the `operator_controller`:

EOF
printf "%b" "$RESET"

pe 'operator_cleanup() {'
pe 'rm -f operator_controller \'
pe 'operator_controller.asc \'
pe 'operator_controller.tgz.asc \'
pe '.las-manifest.template \'
pe '.las-manifest.template.asc \'
pe '.las-manifest.yaml \'
pe '.sgxplugin-manifest.template \'
pe '.sgxplugin-manifest.template.asc \'
pe '.sgxplugin-manifest.yaml'
pe '}'

printf "%b" "$LILAC"
cat <<'EOF'

We ensure that the correct `kubectl provision` plugin is installed:

EOF
printf "%b" "$RESET"

pe './operator_controller --set-version $SCONE_VERSION  --only-plugin  --reconcile --update'

printf "%b" "$LILAC"
cat <<'EOF'

## Set your Intel API Key

To install the SCONE platform, you need an Intel API key. Please visit <https://api.portal.trustedservices.intel.com/manage-subscriptions> to generate or copy your DCAP API Key. Store this API key in a local environment variable:

export DCAP_KEY="..."

In case your cluster has already been installed, you can extract the DCAP_API_KEY as follows:

EOF
printf "%b" "$RESET"

pe '    export DEFAULT_DCAP_KEY="00000000000000000000000000000000"'
pe '    export DCAP_KEY=${DCAP_KEY:-$DEFAULT_DCAP_KEY}'
pe '    if [[ "$DCAP_KEY" == "$DEFAULT_DCAP_KEY" ]] ; then'
pe '        echo "WARNING: No DCAP API Key in environment variable DCAP_KEY specified"'
pe '        EXISTING_DCAP_KEY=$(kubectl get las las -o json 2> /dev/null | jq -r '\''.spec.dcapKey'\'' || echo "null" )'
pe ''
pe '        if [[ "$EXISTING_DCAP_KEY" == "null" ]] ; then'
pe '            echo "WARNING: Extraction of DCAP_KEY from LAS failed - using default DCAP_KEY=$DEFAULT_DCAP_KEY - not recommended."'
pe '        else'
pe '            DCAP_KEY="$EXISTING_DCAP_KEY"'
pe '            echo "WARNING: Using DCAP_KEY extracted from LAS - not recommended."'
pe '        fi'
pe '    fi'

printf "%b" "$LILAC"
cat <<'EOF'

In case we use the default DCAP API key, we ask the user for some input:

EOF
printf "%b" "$RESET"

pe '# Check if DCAP_KEY is empty or unset'
pe 'if [[ "$DCAP_KEY" == "$DEFAULT_DCAP_KEY" ]]; then'
pe '  while true; do'
pe '    read -rp "Please enter a 32-character hexadecimal DCAP_KEY: " input'
pe ''
pe '    # Check if input is 32 hex chars (case-insensitive)'
pe '    if [[ "$input" =~ ^[0-9a-fA-F]{32}$ ]]; then'
pe '      DCAP_KEY="$input"'
pe '      export DCAP_KEY'
pe '      echo "✅ DCAP_KEY set."'
pe '      break'
pe '    else'
pe '      echo "❌ Invalid input. Must be exactly 32 hex characters (0-9, a-f)."'
pe '    fi'
pe '  done'
pe 'fi'

printf "%b" "$LILAC"
cat <<'EOF'

Next, we run the `operator_controller` to check if the proper version is installed:

EOF
printf "%b" "$RESET"

pe 'kubectl get deployment scone-controller-manager -n scone-system -o json | \'
pe '  jq -e "any(.status.conditions[]; .type == \"Available\" and .status == \"True\") and (.spec.template.spec.containers[0].image | contains(\":$SCONE_VERSION\"))" && \'
pe '  { echo "SCONE Version $SCONE_VERSION already installed" ; operator_cleanup ; exit 0; } || echo "Scone Operator is not installed, ready or version does NOT match."'

printf "%b" "$LILAC"
cat <<'EOF'

If the latest stable version is installed and healthy, we can stop here. Otherwise, if we need to update or reconcile the platform, please continue with step 5. If the SCONE platform is not yet installed, please continue with step 6.

In case we upgrade from version 5 to version 6, we need to delete CRD `vault`. We ignore if the removal fails because vault crd might not exist:

EOF
printf "%b" "$RESET"

pe 'kubectl delete crd vaults.services.scone.cloud || true'

printf "%b" "$LILAC"
cat <<'EOF'

## Ensure that the image pull secret `sconeapps` exists

We check if we can read the secret:

EOF
printf "%b" "$RESET"

pe 'export install_sconeapps_secret=0'
pe ''
pe 'kubectl get secret sconeapps -n scone-system >/dev/null 2>&1 && echo "\"sconeapps\" image pull secret exists" || { echo "Secret does not exist" ; export install_sconeapps_secret=1; }'
pe 'kubectl get secret scone-operator-pull -n scone-system >/dev/null 2>&1 && echo "\"sconeapps\" image pull secret exists" || { echo "Secret does not exist" ; export install_sconeapps_secret=1; }'

printf "%b" "$LILAC"
cat <<'EOF'

We assume that you use the `scone.cloud` image registry, you would need to deploy image pull secrets. For this, you will need to set environment variables:

For more details, please read the following document: [Create an Access Token](https://sconedocs.github.io/registry/#create-an-access-token). In the script (i.e., `reconcile_scone_operator.sh`), we
ask the user to input the values for these variables:

EOF
printf "%b" "$RESET"

pe 'if [[ $install_sconeapps_secret == 1 ]] ; then'
pe '    # ask user for the credentials for accessing the registry'
pe '  eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --create-values-file --eval --force )'
pe ''

printf "%b" "$LILAC"
cat <<'EOF'

We install/fix/update the installed version:

EOF
printf "%b" "$RESET"

pe '    ./operator_controller --set-version $SCONE_VERSION --reconcile --update --plugin --verbose --dcap-api "$DCAP_KEY" --secret-operator  --username $REGISTRY_USER --access-token $REGISTRY_TOKEN --email info@scontain.com'

printf "%b" "$LILAC"
cat <<'EOF'

## Updating the SCONE platform

In case an older version of the SCONE platform was already installed (i.e., when the `sconeapps` secret already exists), we can update the platform by executing the following command:

EOF
printf "%b" "$RESET"

pe 'else'
pe '    ./operator_controller --set-version $SCONE_VERSION --update --reconcile --plugin  --verbose --dcap-api "$DCAP_KEY"'
pe 'fi'

printf "%b" "$LILAC"
cat <<'EOF'

## Cleaning up temporary files

EOF
printf "%b" "$RESET"

pe 'operator_cleanup'
pe 'echo "✅ SCONE Operator upgraded to version $SCONE_VERSION."'

printf "%b" "$LILAC"
cat <<'EOF'

## Wait for LAS to become healthy

EOF
printf "%b" "$RESET"

pe 'cd -'
pe 'COND=HEALTHY TIMEOUT=300 INTERVAL=2 NAMESPACE= scripts/wait-crd-state.sh las'

