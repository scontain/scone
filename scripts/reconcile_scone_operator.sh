#!/usr/bin/env bash

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

printf "${VIOLET}"
printf '%s\n' '## Installation of the SCONE Platform'
printf '%s\n' ''
printf '%s\n' 'To install or update the SCONE platform in a Kubernetes cluster, please perform the following steps.'
printf '%s\n' ''
printf '%s\n' '![Screencast](docs/reconcile_scone_operator.gif)'
printf '%s\n' ''
printf '%s\n' 'You can execute the steps automatically by running the script `scripts/reconcile_scone_operator.sh`. The script expects the cluster already be installed, i.e., it only upgrades to the latest stable version.'
printf '%s\n' ''
printf '%s\n' '## Determine the current stable version of the SCONE platform'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'export SCONE_VERSION=$(cat stable.txt)'
printf '%s\n' 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""'
printf "${RESET}"

export SCONE_VERSION=$(cat stable.txt)
export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '`tplenv` will now ask the user for all environment variables that are described in file `environment-variables.md`'
printf '%s\n' 'but that are not set yet. In case `--force` is set, the values of all environment variables need to confirmed by the user:'
printf '%s\n' ''
printf '%s\n' 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--force"'
printf '%s\n' ''
printf '%s\n' 'Let'\''s ask the user and set the environment variables depending on the input of the user:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'
printf "${RESET}"

eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Make sure that we actually want to update the current cluster'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Get the current Kubernetes context'
printf '%s\n' 'K8S_CONTEXT=$(kubectl config current-context 2>/dev/null)'
printf '%s\n' ''
printf '%s\n' 'if [[ -z "$K8S_CONTEXT" ]]; then'
printf '%s\n' '  echo "❌ Could not determine the current Kubernetes context."'
printf '%s\n' '  exit 1'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' 'echo "📦 Current Kubernetes context: $K8S_CONTEXT"'
printf '%s\n' ''
printf '%s\n' '# Ask for confirmation'
printf '%s\n' 'read -rp "Do you want to proceed install SCONE version $SCONE_VERSION with this context? [y/N] " confirm'
printf '%s\n' 'confirm=${confirm,,}  # Convert to lowercase'
printf '%s\n' ''
printf '%s\n' 'if [[ "$confirm" != "y" && "$confirm" != "yes" ]]; then'
printf '%s\n' '  echo "❌ Aborted by user."'
printf '%s\n' '  exit 1'
printf '%s\n' 'fi'
printf '%s\n' ''
printf '%s\n' 'echo "✅ Proceeding with context: $K8S_CONTEXT"'
printf "${RESET}"

# Get the current Kubernetes context
K8S_CONTEXT=$(kubectl config current-context 2>/dev/null)

if [[ -z "$K8S_CONTEXT" ]]; then
  echo "❌ Could not determine the current Kubernetes context."
  exit 1
fi

echo "📦 Current Kubernetes context: $K8S_CONTEXT"

# Ask for confirmation
read -rp "Do you want to proceed install SCONE version $SCONE_VERSION with this context? [y/N] " confirm
confirm=${confirm,,}  # Convert to lowercase

if [[ "$confirm" != "y" && "$confirm" != "yes" ]]; then
  echo "❌ Aborted by user."
  exit 1
fi

echo "✅ Proceeding with context: $K8S_CONTEXT"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Download the script to install the SCONE platform:'
printf '%s\n' ''
printf '%s\n' 'To simplify the cleanup, we download the installation script into a temporary directory:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'mkdir -p /tmp/SCONE_OPERATOR_CONTROLLER'
printf '%s\n' 'cd /tmp/SCONE_OPERATOR_CONTROLLER'
printf '%s\n' 'curl -fsSL https://raw.githubusercontent.com/scontain/SH/master/$SCONE_VERSION/operator_controller > operator_controller'
printf '%s\n' 'chmod a+x operator_controller'
printf '%s\n' 'echo "Downloaded script '\''operator_controller'\'' into directory $PWD"'
printf "${RESET}"

mkdir -p /tmp/SCONE_OPERATOR_CONTROLLER
cd /tmp/SCONE_OPERATOR_CONTROLLER
curl -fsSL https://raw.githubusercontent.com/scontain/SH/master/$SCONE_VERSION/operator_controller > operator_controller
chmod a+x operator_controller
echo "Downloaded script 'operator_controller' into directory $PWD"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Verify the signature of the script:'
printf '%s\n' ''
printf '%s\n' 'Download the signature of the operator controller:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'curl -fsSL https://raw.githubusercontent.com/scontain/SH/master/$SCONE_VERSION/operator_controller.asc > operator_controller.asc'
printf '%s\n' 'echo "Downloaded signature of '\''operator_controller'\'' to file '\''operator_controller.asc'\''"'
printf '%s\n' 'export GPG_PUBLIC_KEY_FILE=${GPG_PUBLIC_KEY_FILE:-""}'
printf "${RESET}"

curl -fsSL https://raw.githubusercontent.com/scontain/SH/master/$SCONE_VERSION/operator_controller.asc > operator_controller.asc
echo "Downloaded signature of 'operator_controller' to file 'operator_controller.asc'"
export GPG_PUBLIC_KEY_FILE=${GPG_PUBLIC_KEY_FILE:-""}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Define bash functions:'
printf '%s\n' ''
printf '%s\n' '- `create_gpg_verification_key`: create a temporary file that contains the public key to verify the signature of the script.'
printf '%s\n' '- `verify_file`: verifies that the signature matches the file and the given public key.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'function create_gpg_verification_key() {'
printf '%s\n' '    local tmp_gpg'
printf '%s\n' ''
printf '%s\n' '    export GPG_PUBLIC_KEY_FILE="$(mktemp)-pub.gpg"'
printf '%s\n' '    tmp_gpg="${GPG_PUBLIC_KEY_FILE}.base64"'
printf '%s\n' ''
printf '%s\n' '    cat > $tmp_gpg <<SEOF'
printf '%s\n' 'mQINBF5tGZkBEACPxl1oBdP5xKWB/EaEkW3UwMEnpNJeOFjVysT5B3ZfK6OGqtZDYKsQEGtptJ54'
printf '%s\n' 'Wy9dvd33UpZUNRmCL6X1GeEd/DLd7t+sk3Cm414pC9Qmx9tkTeLMkCZb6QHufblz3kJkV1E86vre'
printf '%s\n' 'PbrVTZ2q4cLJl4G/IlNKwHsY/7/4yEcBkEZ8L1TOgsotnLnuYOlf/XbPcF4tqdEV+H1nTHGjwcSP'
printf '%s\n' 'qbIHDA3N8a0aNELRvcTH5tj9YluSUCgC4S4EqwgL09BfOITN6lSJihgZMqP9sHlbj4SWfxvVOyXd'
printf '%s\n' '7lSpNSB+nq0DQS1q6lNURnynTZYDwsbmKWbtd/qft2Z1Rs3lBIsIM/sVyVGRS5oOuzVo5CHuhfuP'
printf '%s\n' '1LUCPQpRXamJvS64Tx0eWl4s+HD37Cz1H9MN0zo9dScSEi3c5pJo8GgH6FQyM0miqXmP5VmuUFN8'
printf '%s\n' 'Qe76wkrBE+TJGSSiLewBCOlowrE1m8fX9ZZ0V17sJx9ya0jvinwXMEzN9zLppychdMyJoLEyGplr'
printf '%s\n' '3swCYTPytRwdwOq87srkd63LvXSXg29ozWt1Rx25VagBZflZXg1H0dHDgNvzxsFwEQWYDBmG3vh5'
printf '%s\n' 'i75Ny7DfrRJVeMbPds7McWEiusO/Rk8JXpLJqwA2fjkUC2kavzfCrVMxJ927QJyaOXGx53nXDBSg'
printf '%s\n' 'wmjC3yYRK4LohQARAQABtC5DaHJpc3RvZiBGZXR6ZXIgPGNocmlzdG9mLmZldHplckBzY29udGFp'
printf '%s\n' 'bi5jb20+iQJOBBMBCgA4FiEEW8rTHcyNXXIre3q9Lr4E58yBbTIFAl5tGZkCGwMFCwkIBwIGFQoJ'
printf '%s\n' 'CAsCBBYCAwECHgECF4AACgkQLr4E58yBbTKwVg//SJ6T9x+7YItMCevjU6td7wDJKwOyvFINXP/0'
printf '%s\n' 'ktDRGfrdy+YDCMkuQUMxkL0j65/AjaicndmvEj/ThGN7cJfyA2FrnmL402glJPWScL+LiMiwonBn'
printf '%s\n' 'h6Y9hkTTRmbDPBNuPaa+fXdqfZRfa2Pzhj8aW7e3kKChxGCoLG4uM5+yEI07LsmsIG8VkkWTplhG'
printf '%s\n' 'LQaXc3wRN4oMTNflG8OlmvtooxpuGNgOoAgj7k1T35LjoZ+mE9mNH8a41eDk3c2PAB3t7/rYxstK'
printf '%s\n' 'CGPcJd0K9R5ZXDlkbqvDKuAO83E0pI0zw1BsksA3W5XfmCo8Jf2UqtWW4XBxWJvDS8ywVTXduZR8'
printf '%s\n' 'ean681VEICrYUBtTWDrAfWKGNNQMD7w6KWK8gwWRTqECr2eSzYkaFX7tyd2Dc47/R8uTHXgg4chR'
printf '%s\n' 'Ke0oL+yiAmPqcOjwEn2Y0e7I2Wj70N69EBcf/lFXy1Q67RGO+oCifwjhwkYkELdRt5NVpaUnnEkS'
printf '%s\n' '2p82fOomo2Vxrh8wGaTABub+fzLYicnKda1zO7VjzrOmjC0GMo8wApyNJhv+JfWXDJ1pOCpRIuMc'
printf '%s\n' 'PJykpFXTRw7KN88924etDM8j1sOBV/YcL8nPiRMdAzp4X1fg2QNndiGaWDejoD8NF3yVssInKmg+'
printf '%s\n' 'neRUytPu75nke9AcdaY6bMlTWbGNOekuwe1oRfC5Ag0EXm0ZmQEQAKXucWCoTWN7jViqpS3NnLgF'
printf '%s\n' 'JfPvsvePT99WRUHIODuXTskLMipLG41U7s0E3IM3orY00GlmI3IfNjzPKMQV98yfldgZ1gnA91Uy'
printf '%s\n' 'UnrjI+7kPr6wa5cDdLMNj+BUcp2V6t8qUE2YT7v2af4VgIWUnXnhQAx/DNhncUpPCQqJ8kZ3s9LA'
printf '%s\n' 'Ezy74Cqgu/0/3v5wVTszh67uMwfm1QMj0u2hzr3ZkEHnVdGpWfvG5dQj+3WqLT3miVcNFIVPgY2P'
printf '%s\n' 'hiivlekxn1MX9BG4kn/QtibNmBZvLyj0F0mssUKN+DFr7M7JxTlNxxDhtvaIAllXsBs06zPxKTou'
printf '%s\n' 'A2Q1iNZQYoVr43MTocfvbY8LlB618qmVUO/8hQvSl8Fh72uE986xB4+a1PDWJkDRlHxi409Y1mXR'
printf '%s\n' 'pkCNWrA5xvcX0IHgpnwR/NxFX6SvAuwNeCC6fo9zQ5GoZWnmCrI0dthLfluslrK4uvMdpDqLYpVm'
printf '%s\n' 'i6B1uB+oOBV9umIB1NhMi6u6SaQJ8pefLveGDCqmCbF5yAuVXXT+n2XQZBeOefiyAhtDwqDKXvI5'
printf '%s\n' 'M2Smw5nzMqgXu5bs5WLMNqn0zvphKam11bF0LHtxp/UCZXO+o6L22le2luMxFjDMcI0Sah73Jwno'
printf '%s\n' 'hqFkxG34tws0WR5lioi+PgoEa0jXYGexyFO74Xvo8XWH5TjiS3dTABEBAAGJAjYEGAEKACAWIQRb'
printf '%s\n' 'ytMdzI1dcit7er0uvgTnzIFtMgUCXm0ZmQIbIAAKCRAuvgTnzIFtMjaBD/9iYzR0h6tg+uVG8FA5'
printf '%s\n' 'iy/wi/Qb8C86UnSr73sZZJlH17rVjz51httE7fmN48QkQ2VKYRDh50NWC05W/2cRbtIwqmlkXzAS'
printf '%s\n' 'ys04uBuROMAj5zeM4v9SqLCSWUguO1LItOuFqqqML12uwm3EfhmTmseZB2LND+ZxZG8OiZeun1d1'
printf '%s\n' '+CyZHrgn+xQ5SyUt9bzdZp/JAu05iN/e7E9/zrulCW0RPtOl8C4lgeaoNIBOAOYrvjUtD8vvNuiO'
printf '%s\n' 'S6goGwsUUMhap8UdW1O8b+acpQaRcdlNxaNXoz/TpG7GeguXyyWvHNKHjlV/PMX35ItVGl9FZ1ph'
printf '%s\n' 'zNe+xTBjpI7U505bTfekfyS5Y6kTI0v+HvptNZFNF7Iubssl0tCxp0u+iPMz6xuIy2FWGQIWDUta'
printf '%s\n' '16CcaolmluBmoFJ4BfAjh4ur60jEfe+UaHyat09khfF6HRZpIM7henB7C+GFeVROHMRdQaw1y7EF'
printf '%s\n' '7xgN6hxuM5OTWwlYxQkNu84hWzjxwhj6/KKV8Tz1vmJPglChTQLY7COpD4q/vOQmJyGFCDu3RYxb'
printf '%s\n' 'rIIkr/itIAyQXgsxtlqTVAyU6F7r3pIM91nj8QxYNW5c3os7Z0gdXpe3Dbdvt3vn4MZqhB/9haIO'
printf '%s\n' 'NyTbLJcUrjHio1AmCo3k1ued73dDdneWdn7TKITKfU/8lb9v6XEdkSHJxLkCDQRebRmZARAAiPvf'
printf '%s\n' '2FfDfORqIlGk5Is/5MaBTzrQj/VABF5HzsOqVEKF557CVmKu5qa0B7W1jsrPKyWkqTzGUyfejSgI'
printf '%s\n' 'YUBAocaaQHE/mIS3CQLwKDPRIRg4onzHXZjmjcwDjjFcGMjakMkFgNgfMw61LT2LH621g/vLm0qq'
printf '%s\n' 'KClWYqVY++yoJcJC1RSiNKam24bsYwZeGaGHCulga7igqB1U1dW8KsyBzW2Z5I1yXWc+fgm3Q4DS'
printf '%s\n' 'ulpiuSMKGSmAg/uNUfVyFEjIFBQk2Ls+8XvuGux5+0ICig6gLazb3fdymtmBi7VIsozsp2r5KC4h'
printf '%s\n' '+4QqZjDZ6QOjBFScB79XDDQ/hLJMfYerWBM5LyMKuLnsFVa6mQckpikpyl2BujlNTzFD58hDcpsm'
printf '%s\n' 'qI3BXbqqbGEQWuaoTNWVqQv1qu9mwqDacTthX9fdTGnzibbm2/0hQSpbQ3ZexGvzzhT4bB1Cgc8X'
printf '%s\n' '7C2vPclpi8H4kzcOo7gIicwJuwLaOD8QRGqKPZIta32Agzb3tDB2MXGuhOL2eCSAx2aDosAzlLD6'
printf '%s\n' '2mnrHelc6vKchhViQBiZKPFiNSL7KN+vEbhstB+mx9UltcopwcuynoTPm8HuVpM2HFJLPlkK5gTb'
printf '%s\n' 'xtCUlW9fGREx2jwqioYuju4mfS2kcbqR8O8+lvnkoiIYxLk9x+SXTOCtWq8wG+3uqiCvqd0AEQEA'
printf '%s\n' 'AYkCNgQYAQoAIBYhBFvK0x3MjV1yK3t6vS6+BOfMgW0yBQJebRmZAhsMAAoJEC6+BOfMgW0yn70P'
printf '%s\n' '/AqRl7P7d2NX1Y0ZAqm2XlHrO6q+yltKC27Yu+mvzo0vIpiCsx2moUwXKpnbUE+ovQieDtRswvDz'
printf '%s\n' '6LWVyvM/c3ogQJ3/cLbu9aAsTkUF1TFWFyYs9WGDmt+mv9q1+99HdPw1dG683B0gEjQxIuKeKiii'
printf '%s\n' 'e64SdHNU51FM81HjXh94kFj5HPQ0QJ1/DzXdFLu9aG3Ja5Nl2mMK+BOY1B3SXNZGwoSk0oZM3Su1'
printf '%s\n' 'VkvxlQlLi8B8CBLUEE+JNhw1qNx55LGZJSB95DoIrvloADqy7braEKNgDZ3GBWjupMt6MeX2n/Fk'
printf '%s\n' 'R4xMEkNO4Qlwy7eARz1Yx9WTjFT8L6a/xp2PEKe8zmTkObUQzRTwDvcoXbl/B3nT0w/RlbLaXEtd'
printf '%s\n' 'dTC5h5UPz9avSlLYSblGFxf84PXuEKIKWpDQzybMAfRwqBc5OTOnkkl6OXYiXLxdVEsaRlTtYHI4'
printf '%s\n' 'QSvBZDzbO12jXPv78zVVkRjr7mljcPMB2iDRSeWO073ov1oxEeCmzzhyq8/7q0SrjR3J6g3b4k15'
printf '%s\n' 'NSHb32Obz9x+L+3Oo/r5oYf+T0B51YvOfz6O9BxoI3icZL1KJ2MtbtmYkE/UNNnNB4XApQGoZk5i'
printf '%s\n' 'BtcmftSsf9VCHB0IDPbyH6sro8MNyF81i5MewmQ99tdYE9UIiwNYa/10PRUClKWrEvxIOAK/K3sW'
printf '%s\n' 'SEOF'
printf '%s\n' ''
printf '%s\n' '    cat "$tmp_gpg" | base64 -d > $GPG_PUBLIC_KEY_FILE'
printf '%s\n' '}'
printf '%s\n' ''
printf '%s\n' '#'
printf '%s\n' '# Public Key used to sign manifests'
printf '%s\n' '#'
printf '%s\n' ''
printf '%s\n' 'SIGNER="5BCAD31DCC8D5D722B7B7ABD2EBE04E7CC816D32"'
printf '%s\n' ''
printf '%s\n' 'function verify_file() {'
printf '%s\n' '    file=$1'
printf '%s\n' ''
printf '%s\n' '    export GPG_PUBLIC_KEY_FILE=${GPG_PUBLIC_KEY_FILE:-""}'
printf '%s\n' '    if [[ "$GPG_PUBLIC_KEY_FILE" == "" ]]; then'
printf '%s\n' '        create_gpg_verification_key'
printf '%s\n' '    fi'
printf '%s\n' '    LC_ALL=en_US.UTF-8 gpg --no-default-keyring --keyring $GPG_PUBLIC_KEY_FILE --verify --status-fd=1 "$file.asc" "$file" 2>/dev/null | grep -e " VALIDSIG $SIGNER" >/dev/null || { echo "Signature check FAILED" ; return 1; }'
printf '%s\n' '}'
printf "${RESET}"

function create_gpg_verification_key() {
    local tmp_gpg

    export GPG_PUBLIC_KEY_FILE="$(mktemp)-pub.gpg"
    tmp_gpg="${GPG_PUBLIC_KEY_FILE}.base64"

    cat > $tmp_gpg <<SEOF
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
SEOF

    cat "$tmp_gpg" | base64 -d > $GPG_PUBLIC_KEY_FILE
}

#
# Public Key used to sign manifests
#

SIGNER="5BCAD31DCC8D5D722B7B7ABD2EBE04E7CC816D32"

function verify_file() {
    file=$1

    export GPG_PUBLIC_KEY_FILE=${GPG_PUBLIC_KEY_FILE:-""}
    if [[ "$GPG_PUBLIC_KEY_FILE" == "" ]]; then
        create_gpg_verification_key
    fi
    LC_ALL=en_US.UTF-8 gpg --no-default-keyring --keyring $GPG_PUBLIC_KEY_FILE --verify --status-fd=1 "$file.asc" "$file" 2>/dev/null | grep -e " VALIDSIG $SIGNER" >/dev/null || { echo "Signature check FAILED" ; return 1; }
}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Next, we verify the signature of the script `operator_controller`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'verify_file operator_controller'
printf "${RESET}"

verify_file operator_controller

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Please check that output is empty. Stop if error message `Signature check FAILED` is printed.'
printf '%s\n' ''
printf '%s\n' '## Verifying if the cluster is properly installed:'
printf '%s\n' ''
printf '%s\n' 'We first define a cleanup function to cleanup after the `operator_controller`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'operator_cleanup() {'
printf '%s\n' 'rm -f operator_controller \'
printf '%s\n' 'operator_controller.asc \'
printf '%s\n' 'operator_controller.tgz.asc \'
printf '%s\n' '.las-manifest.template \'
printf '%s\n' '.las-manifest.template.asc \'
printf '%s\n' '.las-manifest.yaml \'
printf '%s\n' '.sgxplugin-manifest.template \'
printf '%s\n' '.sgxplugin-manifest.template.asc \'
printf '%s\n' '.sgxplugin-manifest.yaml'
printf '%s\n' '}'
printf "${RESET}"

operator_cleanup() {
rm -f operator_controller \
operator_controller.asc \
operator_controller.tgz.asc \
.las-manifest.template \
.las-manifest.template.asc \
.las-manifest.yaml \
.sgxplugin-manifest.template \
.sgxplugin-manifest.template.asc \
.sgxplugin-manifest.yaml
}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'We ensure that the correct `kubectl provision` plugin is installed:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' './operator_controller --set-version $SCONE_VERSION  --only-plugin  --reconcile --update'
printf "${RESET}"

./operator_controller --set-version $SCONE_VERSION  --only-plugin  --reconcile --update

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Set your Intel API Key'
printf '%s\n' ''
printf '%s\n' 'To install the SCONE platform, you need an Intel API key. Please visit <https://api.portal.trustedservices.intel.com/manage-subscriptions> to generate or copy your DCAP API Key. Store this API key in a local environment variable:'
printf '%s\n' ''
printf '%s\n' 'export DCAP_KEY="..."'
printf '%s\n' ''
printf '%s\n' 'In case your cluster has already been installed, you can extract the DCAP_API_KEY as follows:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '    export DEFAULT_DCAP_KEY="00000000000000000000000000000000"'
printf '%s\n' '    export DCAP_KEY=${DCAP_KEY:-$DEFAULT_DCAP_KEY}'
printf '%s\n' '    if [[ "$DCAP_KEY" == "$DEFAULT_DCAP_KEY" ]] ; then'
printf '%s\n' '        echo "WARNING: No DCAP API Key in environment variable DCAP_KEY specified"'
printf '%s\n' '        EXISTING_DCAP_KEY=$(kubectl get las las -o json 2> /dev/null | jq -r '\''.spec.dcapKey'\'' || echo "null" )'
printf '%s\n' ''
printf '%s\n' '        if [[ "$EXISTING_DCAP_KEY" == "null" ]] ; then'
printf '%s\n' '            echo "WARNING: Extraction of DCAP_KEY from LAS failed - using default DCAP_KEY=$DEFAULT_DCAP_KEY - not recommended."'
printf '%s\n' '        else'
printf '%s\n' '            DCAP_KEY="$EXISTING_DCAP_KEY"'
printf '%s\n' '            echo "WARNING: Using DCAP_KEY extracted from LAS - not recommended."'
printf '%s\n' '        fi'
printf '%s\n' '    fi'
printf "${RESET}"

    export DEFAULT_DCAP_KEY="00000000000000000000000000000000"
    export DCAP_KEY=${DCAP_KEY:-$DEFAULT_DCAP_KEY}
    if [[ "$DCAP_KEY" == "$DEFAULT_DCAP_KEY" ]] ; then
        echo "WARNING: No DCAP API Key in environment variable DCAP_KEY specified"
        EXISTING_DCAP_KEY=$(kubectl get las las -o json 2> /dev/null | jq -r '.spec.dcapKey' || echo "null" )

        if [[ "$EXISTING_DCAP_KEY" == "null" ]] ; then
            echo "WARNING: Extraction of DCAP_KEY from LAS failed - using default DCAP_KEY=$DEFAULT_DCAP_KEY - not recommended."
        else
            DCAP_KEY="$EXISTING_DCAP_KEY"
            echo "WARNING: Using DCAP_KEY extracted from LAS - not recommended."
        fi
    fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'In case we use the default DCAP API key, we ask the user for some input:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Check if DCAP_KEY is empty or unset'
printf '%s\n' 'if [[ "$DCAP_KEY" == "$DEFAULT_DCAP_KEY" ]]; then'
printf '%s\n' '  while true; do'
printf '%s\n' '    read -rp "Please enter a 32-character hexadecimal DCAP_KEY: " input'
printf '%s\n' ''
printf '%s\n' '    # Check if input is 32 hex chars (case-insensitive)'
printf '%s\n' '    if [[ "$input" =~ ^[0-9a-fA-F]{32}$ ]]; then'
printf '%s\n' '      DCAP_KEY="$input"'
printf '%s\n' '      export DCAP_KEY'
printf '%s\n' '      echo "✅ DCAP_KEY set."'
printf '%s\n' '      break'
printf '%s\n' '    else'
printf '%s\n' '      echo "❌ Invalid input. Must be exactly 32 hex characters (0-9, a-f)."'
printf '%s\n' '    fi'
printf '%s\n' '  done'
printf '%s\n' 'fi'
printf "${RESET}"

# Check if DCAP_KEY is empty or unset
if [[ "$DCAP_KEY" == "$DEFAULT_DCAP_KEY" ]]; then
  while true; do
    read -rp "Please enter a 32-character hexadecimal DCAP_KEY: " input

    # Check if input is 32 hex chars (case-insensitive)
    if [[ "$input" =~ ^[0-9a-fA-F]{32}$ ]]; then
      DCAP_KEY="$input"
      export DCAP_KEY
      echo "✅ DCAP_KEY set."
      break
    else
      echo "❌ Invalid input. Must be exactly 32 hex characters (0-9, a-f)."
    fi
  done
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Next, we run the `operator_controller` to check if the proper version is installed:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl get deployment scone-controller-manager -n scone-system -o json | \'
printf '%s\n' '  jq -e "any(.status.conditions[]; .type == \"Available\" and .status == \"True\") and (.spec.template.spec.containers[0].image | contains(\":$SCONE_VERSION\"))" && \'
printf '%s\n' '  { echo "SCONE Version $SCONE_VERSION already installed" ; operator_cleanup ; exit 0; } || echo "Scone Operator is not installed, ready or version does NOT match."'
printf "${RESET}"

kubectl get deployment scone-controller-manager -n scone-system -o json | \
  jq -e "any(.status.conditions[]; .type == \"Available\" and .status == \"True\") and (.spec.template.spec.containers[0].image | contains(\":$SCONE_VERSION\"))" && \
  { echo "SCONE Version $SCONE_VERSION already installed" ; operator_cleanup ; exit 0; } || echo "Scone Operator is not installed, ready or version does NOT match."

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'If the latest stable version is installed and healthy, we can stop here. Otherwise, if we need to update or reconcile the platform, please continue with step 5. If the SCONE platform is not yet installed, please continue with step 6.'
printf '%s\n' ''
printf '%s\n' 'In case we upgrade from version 5 to version 6, we need to delete CRD `vault`. We ignore if the removal fails because vault crd might not exist:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl delete crd vaults.services.scone.cloud || true'
printf "${RESET}"

kubectl delete crd vaults.services.scone.cloud || true

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Ensure that the image pull secret `sconeapps` exists'
printf '%s\n' ''
printf '%s\n' 'We check if we can read the secret:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'export install_sconeapps_secret=0'
printf '%s\n' ''
printf '%s\n' 'kubectl get secret sconeapps -n scone-system >/dev/null 2>&1 && echo "\"sconeapps\" image pull secret exists" || { echo "Secret does not exist" ; export install_sconeapps_secret=1; }'
printf '%s\n' 'kubectl get secret scone-operator-pull -n scone-system >/dev/null 2>&1 && echo "\"sconeapps\" image pull secret exists" || { echo "Secret does not exist" ; export install_sconeapps_secret=1; }'
printf "${RESET}"

export install_sconeapps_secret=0

kubectl get secret sconeapps -n scone-system >/dev/null 2>&1 && echo "\"sconeapps\" image pull secret exists" || { echo "Secret does not exist" ; export install_sconeapps_secret=1; }
kubectl get secret scone-operator-pull -n scone-system >/dev/null 2>&1 && echo "\"sconeapps\" image pull secret exists" || { echo "Secret does not exist" ; export install_sconeapps_secret=1; }

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'We assume that you use the `scone.cloud` image registry, you would need to deploy image pull secrets. For this, you will need to set environment variables:'
printf '%s\n' ''
printf '%s\n' 'For more details, please read the following document: [Create an Access Token](https://sconedocs.github.io/registry/#create-an-access-token). In the script (i.e., `reconcile_scone_operator.sh`), we'
printf '%s\n' 'ask the user to input the values for these variables:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'if [[ $install_sconeapps_secret == 1 ]] ; then'
printf '%s\n' '    # ask user for the credentials for accessing the registry'
printf '%s\n' '  eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --create-values-file --eval --force )'
printf '%s\n' ''
printf "${RESET}"

if [[ $install_sconeapps_secret == 1 ]] ; then
    # ask user for the credentials for accessing the registry
  eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --create-values-file --eval --force )


printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'We install/fix/update the installed version:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '    ./operator_controller --set-version $SCONE_VERSION --reconcile --update --plugin --verbose --dcap-api "$DCAP_KEY" --secret-operator  --username $REGISTRY_USER --access-token $REGISTRY_TOKEN --email info@scontain.com'
printf "${RESET}"

    ./operator_controller --set-version $SCONE_VERSION --reconcile --update --plugin --verbose --dcap-api "$DCAP_KEY" --secret-operator  --username $REGISTRY_USER --access-token $REGISTRY_TOKEN --email info@scontain.com

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Updating the SCONE platform'
printf '%s\n' ''
printf '%s\n' 'In case an older version of the SCONE platform was already installed (i.e., when the `sconeapps` secret already exists), we can update the platform by executing the following command:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'else'
printf '%s\n' '    ./operator_controller --set-version $SCONE_VERSION --update --reconcile --plugin  --verbose --dcap-api "$DCAP_KEY"'
printf '%s\n' 'fi'
printf "${RESET}"

else
    ./operator_controller --set-version $SCONE_VERSION --update --reconcile --plugin  --verbose --dcap-api "$DCAP_KEY"
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Cleaning up temporary files'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'operator_cleanup'
printf '%s\n' 'echo "✅ SCONE Operator upgraded to version $SCONE_VERSION."'
printf "${RESET}"

operator_cleanup
echo "✅ SCONE Operator upgraded to version $SCONE_VERSION."

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Wait for LAS to become healthy'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'cd -'
printf '%s\n' 'COND=HEALTHY TIMEOUT=300 INTERVAL=2 NAMESPACE= scripts/wait-crd-state.sh las'
printf "${RESET}"

cd -
COND=HEALTHY TIMEOUT=300 INTERVAL=2 NAMESPACE= scripts/wait-crd-state.sh las

