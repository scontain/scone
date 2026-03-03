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
printf "%b" "$RESET"

pe "$(cat <<'EOF'
export SCONE_VERSION=$(cat stable.txt)
EOF
)"
pe "$(cat <<'EOF'
export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '`tplenv` will now ask the user for all environment variables that are described in file `environment-variables.md`'
printf '%s\n' 'but that are not set yet. In case `--force` is set, the values of all environment variables need to be confirmed by the user:'
printf '%s\n' ''
printf '%s\n' 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--force"'
printf '%s\n' ''
printf '%s\n' 'Let'\''s ask the user and set the environment variables depending on the input of the user:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Make sure that we actually want to update the current cluster'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Get the current Kubernetes context
EOF
)"
pe "$(cat <<'EOF'
K8S_CONTEXT=$(kubectl config current-context 2>/dev/null)
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
if [[ -z "$K8S_CONTEXT" ]]; then
EOF
)"
pe "$(cat <<'EOF'
  echo "❌ Could not determine the current Kubernetes context."
EOF
)"
pe "$(cat <<'EOF'
  exit 1
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
echo "📦 Current Kubernetes context: $K8S_CONTEXT"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Ask for confirmation
EOF
)"
pe "$(cat <<'EOF'
read -rp "Do you want to proceed install SCONE version $SCONE_VERSION with this context? [y/N] " confirm
EOF
)"
pe "$(cat <<'EOF'
confirm=${confirm,,}  # Convert to lowercase
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
if [[ "$confirm" != "y" && "$confirm" != "yes" ]]; then
EOF
)"
pe "$(cat <<'EOF'
  echo "❌ Aborted by user."
EOF
)"
pe "$(cat <<'EOF'
  exit 1
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
echo "✅ Proceeding with context: $K8S_CONTEXT"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Download the script to install the SCONE platform:'
printf '%s\n' ''
printf '%s\n' 'To simplify the cleanup, we download the installation script into a temporary directory:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
mkdir -p /tmp/SCONE_OPERATOR_CONTROLLER
EOF
)"
pe "$(cat <<'EOF'
cd /tmp/SCONE_OPERATOR_CONTROLLER
EOF
)"
pe "$(cat <<'EOF'
curl -fsSL https://raw.githubusercontent.com/scontain/SH/master/$SCONE_VERSION/operator_controller > operator_controller
EOF
)"
pe "$(cat <<'EOF'
chmod a+x operator_controller
EOF
)"
pe "$(cat <<'EOF'
echo "Downloaded script 'operator_controller' into directory $PWD"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Verify the signature of the script:'
printf '%s\n' ''
printf '%s\n' 'Download the signature of the operator controller:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
curl -fsSL https://raw.githubusercontent.com/scontain/SH/master/$SCONE_VERSION/operator_controller.asc > operator_controller.asc
EOF
)"
pe "$(cat <<'EOF'
echo "Downloaded signature of 'operator_controller' to file 'operator_controller.asc'"
EOF
)"
pe "$(cat <<'EOF'
export GPG_PUBLIC_KEY_FILE=${GPG_PUBLIC_KEY_FILE:-""}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Define bash functions:'
printf '%s\n' ''
printf '%s\n' '- `create_gpg_verification_key`: create a temporary file that contains the public key to verify the signature of the script.'
printf '%s\n' '- `verify_file`: verifies that the signature matches the file and the given public key.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
function create_gpg_verification_key() {
EOF
)"
pe "$(cat <<'EOF'
    local tmp_gpg
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
    export GPG_PUBLIC_KEY_FILE="$(mktemp)-pub.gpg"
EOF
)"
pe "$(cat <<'EOF'
    tmp_gpg="${GPG_PUBLIC_KEY_FILE}.base64"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
    cat > $tmp_gpg <<SEOF
EOF
)"
pe "$(cat <<'EOF'
mQINBF5tGZkBEACPxl1oBdP5xKWB/EaEkW3UwMEnpNJeOFjVysT5B3ZfK6OGqtZDYKsQEGtptJ54
EOF
)"
pe "$(cat <<'EOF'
Wy9dvd33UpZUNRmCL6X1GeEd/DLd7t+sk3Cm414pC9Qmx9tkTeLMkCZb6QHufblz3kJkV1E86vre
EOF
)"
pe "$(cat <<'EOF'
PbrVTZ2q4cLJl4G/IlNKwHsY/7/4yEcBkEZ8L1TOgsotnLnuYOlf/XbPcF4tqdEV+H1nTHGjwcSP
EOF
)"
pe "$(cat <<'EOF'
qbIHDA3N8a0aNELRvcTH5tj9YluSUCgC4S4EqwgL09BfOITN6lSJihgZMqP9sHlbj4SWfxvVOyXd
EOF
)"
pe "$(cat <<'EOF'
7lSpNSB+nq0DQS1q6lNURnynTZYDwsbmKWbtd/qft2Z1Rs3lBIsIM/sVyVGRS5oOuzVo5CHuhfuP
EOF
)"
pe "$(cat <<'EOF'
1LUCPQpRXamJvS64Tx0eWl4s+HD37Cz1H9MN0zo9dScSEi3c5pJo8GgH6FQyM0miqXmP5VmuUFN8
EOF
)"
pe "$(cat <<'EOF'
Qe76wkrBE+TJGSSiLewBCOlowrE1m8fX9ZZ0V17sJx9ya0jvinwXMEzN9zLppychdMyJoLEyGplr
EOF
)"
pe "$(cat <<'EOF'
3swCYTPytRwdwOq87srkd63LvXSXg29ozWt1Rx25VagBZflZXg1H0dHDgNvzxsFwEQWYDBmG3vh5
EOF
)"
pe "$(cat <<'EOF'
i75Ny7DfrRJVeMbPds7McWEiusO/Rk8JXpLJqwA2fjkUC2kavzfCrVMxJ927QJyaOXGx53nXDBSg
EOF
)"
pe "$(cat <<'EOF'
wmjC3yYRK4LohQARAQABtC5DaHJpc3RvZiBGZXR6ZXIgPGNocmlzdG9mLmZldHplckBzY29udGFp
EOF
)"
pe "$(cat <<'EOF'
bi5jb20+iQJOBBMBCgA4FiEEW8rTHcyNXXIre3q9Lr4E58yBbTIFAl5tGZkCGwMFCwkIBwIGFQoJ
EOF
)"
pe "$(cat <<'EOF'
CAsCBBYCAwECHgECF4AACgkQLr4E58yBbTKwVg//SJ6T9x+7YItMCevjU6td7wDJKwOyvFINXP/0
EOF
)"
pe "$(cat <<'EOF'
ktDRGfrdy+YDCMkuQUMxkL0j65/AjaicndmvEj/ThGN7cJfyA2FrnmL402glJPWScL+LiMiwonBn
EOF
)"
pe "$(cat <<'EOF'
h6Y9hkTTRmbDPBNuPaa+fXdqfZRfa2Pzhj8aW7e3kKChxGCoLG4uM5+yEI07LsmsIG8VkkWTplhG
EOF
)"
pe "$(cat <<'EOF'
LQaXc3wRN4oMTNflG8OlmvtooxpuGNgOoAgj7k1T35LjoZ+mE9mNH8a41eDk3c2PAB3t7/rYxstK
EOF
)"
pe "$(cat <<'EOF'
CGPcJd0K9R5ZXDlkbqvDKuAO83E0pI0zw1BsksA3W5XfmCo8Jf2UqtWW4XBxWJvDS8ywVTXduZR8
EOF
)"
pe "$(cat <<'EOF'
ean681VEICrYUBtTWDrAfWKGNNQMD7w6KWK8gwWRTqECr2eSzYkaFX7tyd2Dc47/R8uTHXgg4chR
EOF
)"
pe "$(cat <<'EOF'
Ke0oL+yiAmPqcOjwEn2Y0e7I2Wj70N69EBcf/lFXy1Q67RGO+oCifwjhwkYkELdRt5NVpaUnnEkS
EOF
)"
pe "$(cat <<'EOF'
2p82fOomo2Vxrh8wGaTABub+fzLYicnKda1zO7VjzrOmjC0GMo8wApyNJhv+JfWXDJ1pOCpRIuMc
EOF
)"
pe "$(cat <<'EOF'
PJykpFXTRw7KN88924etDM8j1sOBV/YcL8nPiRMdAzp4X1fg2QNndiGaWDejoD8NF3yVssInKmg+
EOF
)"
pe "$(cat <<'EOF'
neRUytPu75nke9AcdaY6bMlTWbGNOekuwe1oRfC5Ag0EXm0ZmQEQAKXucWCoTWN7jViqpS3NnLgF
EOF
)"
pe "$(cat <<'EOF'
JfPvsvePT99WRUHIODuXTskLMipLG41U7s0E3IM3orY00GlmI3IfNjzPKMQV98yfldgZ1gnA91Uy
EOF
)"
pe "$(cat <<'EOF'
UnrjI+7kPr6wa5cDdLMNj+BUcp2V6t8qUE2YT7v2af4VgIWUnXnhQAx/DNhncUpPCQqJ8kZ3s9LA
EOF
)"
pe "$(cat <<'EOF'
Ezy74Cqgu/0/3v5wVTszh67uMwfm1QMj0u2hzr3ZkEHnVdGpWfvG5dQj+3WqLT3miVcNFIVPgY2P
EOF
)"
pe "$(cat <<'EOF'
hiivlekxn1MX9BG4kn/QtibNmBZvLyj0F0mssUKN+DFr7M7JxTlNxxDhtvaIAllXsBs06zPxKTou
EOF
)"
pe "$(cat <<'EOF'
A2Q1iNZQYoVr43MTocfvbY8LlB618qmVUO/8hQvSl8Fh72uE986xB4+a1PDWJkDRlHxi409Y1mXR
EOF
)"
pe "$(cat <<'EOF'
pkCNWrA5xvcX0IHgpnwR/NxFX6SvAuwNeCC6fo9zQ5GoZWnmCrI0dthLfluslrK4uvMdpDqLYpVm
EOF
)"
pe "$(cat <<'EOF'
i6B1uB+oOBV9umIB1NhMi6u6SaQJ8pefLveGDCqmCbF5yAuVXXT+n2XQZBeOefiyAhtDwqDKXvI5
EOF
)"
pe "$(cat <<'EOF'
M2Smw5nzMqgXu5bs5WLMNqn0zvphKam11bF0LHtxp/UCZXO+o6L22le2luMxFjDMcI0Sah73Jwno
EOF
)"
pe "$(cat <<'EOF'
hqFkxG34tws0WR5lioi+PgoEa0jXYGexyFO74Xvo8XWH5TjiS3dTABEBAAGJAjYEGAEKACAWIQRb
EOF
)"
pe "$(cat <<'EOF'
ytMdzI1dcit7er0uvgTnzIFtMgUCXm0ZmQIbIAAKCRAuvgTnzIFtMjaBD/9iYzR0h6tg+uVG8FA5
EOF
)"
pe "$(cat <<'EOF'
iy/wi/Qb8C86UnSr73sZZJlH17rVjz51httE7fmN48QkQ2VKYRDh50NWC05W/2cRbtIwqmlkXzAS
EOF
)"
pe "$(cat <<'EOF'
ys04uBuROMAj5zeM4v9SqLCSWUguO1LItOuFqqqML12uwm3EfhmTmseZB2LND+ZxZG8OiZeun1d1
EOF
)"
pe "$(cat <<'EOF'
+CyZHrgn+xQ5SyUt9bzdZp/JAu05iN/e7E9/zrulCW0RPtOl8C4lgeaoNIBOAOYrvjUtD8vvNuiO
EOF
)"
pe "$(cat <<'EOF'
S6goGwsUUMhap8UdW1O8b+acpQaRcdlNxaNXoz/TpG7GeguXyyWvHNKHjlV/PMX35ItVGl9FZ1ph
EOF
)"
pe "$(cat <<'EOF'
zNe+xTBjpI7U505bTfekfyS5Y6kTI0v+HvptNZFNF7Iubssl0tCxp0u+iPMz6xuIy2FWGQIWDUta
EOF
)"
pe "$(cat <<'EOF'
16CcaolmluBmoFJ4BfAjh4ur60jEfe+UaHyat09khfF6HRZpIM7henB7C+GFeVROHMRdQaw1y7EF
EOF
)"
pe "$(cat <<'EOF'
7xgN6hxuM5OTWwlYxQkNu84hWzjxwhj6/KKV8Tz1vmJPglChTQLY7COpD4q/vOQmJyGFCDu3RYxb
EOF
)"
pe "$(cat <<'EOF'
rIIkr/itIAyQXgsxtlqTVAyU6F7r3pIM91nj8QxYNW5c3os7Z0gdXpe3Dbdvt3vn4MZqhB/9haIO
EOF
)"
pe "$(cat <<'EOF'
NyTbLJcUrjHio1AmCo3k1ued73dDdneWdn7TKITKfU/8lb9v6XEdkSHJxLkCDQRebRmZARAAiPvf
EOF
)"
pe "$(cat <<'EOF'
2FfDfORqIlGk5Is/5MaBTzrQj/VABF5HzsOqVEKF557CVmKu5qa0B7W1jsrPKyWkqTzGUyfejSgI
EOF
)"
pe "$(cat <<'EOF'
YUBAocaaQHE/mIS3CQLwKDPRIRg4onzHXZjmjcwDjjFcGMjakMkFgNgfMw61LT2LH621g/vLm0qq
EOF
)"
pe "$(cat <<'EOF'
KClWYqVY++yoJcJC1RSiNKam24bsYwZeGaGHCulga7igqB1U1dW8KsyBzW2Z5I1yXWc+fgm3Q4DS
EOF
)"
pe "$(cat <<'EOF'
ulpiuSMKGSmAg/uNUfVyFEjIFBQk2Ls+8XvuGux5+0ICig6gLazb3fdymtmBi7VIsozsp2r5KC4h
EOF
)"
pe "$(cat <<'EOF'
+4QqZjDZ6QOjBFScB79XDDQ/hLJMfYerWBM5LyMKuLnsFVa6mQckpikpyl2BujlNTzFD58hDcpsm
EOF
)"
pe "$(cat <<'EOF'
qI3BXbqqbGEQWuaoTNWVqQv1qu9mwqDacTthX9fdTGnzibbm2/0hQSpbQ3ZexGvzzhT4bB1Cgc8X
EOF
)"
pe "$(cat <<'EOF'
7C2vPclpi8H4kzcOo7gIicwJuwLaOD8QRGqKPZIta32Agzb3tDB2MXGuhOL2eCSAx2aDosAzlLD6
EOF
)"
pe "$(cat <<'EOF'
2mnrHelc6vKchhViQBiZKPFiNSL7KN+vEbhstB+mx9UltcopwcuynoTPm8HuVpM2HFJLPlkK5gTb
EOF
)"
pe "$(cat <<'EOF'
xtCUlW9fGREx2jwqioYuju4mfS2kcbqR8O8+lvnkoiIYxLk9x+SXTOCtWq8wG+3uqiCvqd0AEQEA
EOF
)"
pe "$(cat <<'EOF'
AYkCNgQYAQoAIBYhBFvK0x3MjV1yK3t6vS6+BOfMgW0yBQJebRmZAhsMAAoJEC6+BOfMgW0yn70P
EOF
)"
pe "$(cat <<'EOF'
/AqRl7P7d2NX1Y0ZAqm2XlHrO6q+yltKC27Yu+mvzo0vIpiCsx2moUwXKpnbUE+ovQieDtRswvDz
EOF
)"
pe "$(cat <<'EOF'
6LWVyvM/c3ogQJ3/cLbu9aAsTkUF1TFWFyYs9WGDmt+mv9q1+99HdPw1dG683B0gEjQxIuKeKiii
EOF
)"
pe "$(cat <<'EOF'
e64SdHNU51FM81HjXh94kFj5HPQ0QJ1/DzXdFLu9aG3Ja5Nl2mMK+BOY1B3SXNZGwoSk0oZM3Su1
EOF
)"
pe "$(cat <<'EOF'
VkvxlQlLi8B8CBLUEE+JNhw1qNx55LGZJSB95DoIrvloADqy7braEKNgDZ3GBWjupMt6MeX2n/Fk
EOF
)"
pe "$(cat <<'EOF'
R4xMEkNO4Qlwy7eARz1Yx9WTjFT8L6a/xp2PEKe8zmTkObUQzRTwDvcoXbl/B3nT0w/RlbLaXEtd
EOF
)"
pe "$(cat <<'EOF'
dTC5h5UPz9avSlLYSblGFxf84PXuEKIKWpDQzybMAfRwqBc5OTOnkkl6OXYiXLxdVEsaRlTtYHI4
EOF
)"
pe "$(cat <<'EOF'
QSvBZDzbO12jXPv78zVVkRjr7mljcPMB2iDRSeWO073ov1oxEeCmzzhyq8/7q0SrjR3J6g3b4k15
EOF
)"
pe "$(cat <<'EOF'
NSHb32Obz9x+L+3Oo/r5oYf+T0B51YvOfz6O9BxoI3icZL1KJ2MtbtmYkE/UNNnNB4XApQGoZk5i
EOF
)"
pe "$(cat <<'EOF'
BtcmftSsf9VCHB0IDPbyH6sro8MNyF81i5MewmQ99tdYE9UIiwNYa/10PRUClKWrEvxIOAK/K3sW
EOF
)"
pe "$(cat <<'EOF'
SEOF
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
    cat "$tmp_gpg" | base64 -d > $GPG_PUBLIC_KEY_FILE
EOF
)"
pe "$(cat <<'EOF'
}
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
#
EOF
)"
pe "$(cat <<'EOF'
# Public Key used to sign manifests
EOF
)"
pe "$(cat <<'EOF'
#
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
SIGNER="5BCAD31DCC8D5D722B7B7ABD2EBE04E7CC816D32"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
function verify_file() {
EOF
)"
pe "$(cat <<'EOF'
    file=$1
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
    export GPG_PUBLIC_KEY_FILE=${GPG_PUBLIC_KEY_FILE:-""}
EOF
)"
pe "$(cat <<'EOF'
    if [[ "$GPG_PUBLIC_KEY_FILE" == "" ]]; then
EOF
)"
pe "$(cat <<'EOF'
        create_gpg_verification_key
EOF
)"
pe "$(cat <<'EOF'
    fi
EOF
)"
pe "$(cat <<'EOF'
    LC_ALL=en_US.UTF-8 gpg --no-default-keyring --keyring $GPG_PUBLIC_KEY_FILE --verify --status-fd=1 "$file.asc" "$file" 2>/dev/null | grep -e " VALIDSIG $SIGNER" >/dev/null || { echo "Signature check FAILED" ; return 1; }
EOF
)"
pe "$(cat <<'EOF'
}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Next, we verify the signature of the script `operator_controller`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
verify_file operator_controller
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Please check that output is empty. Stop if error message `Signature check FAILED` is printed.'
printf '%s\n' ''
printf '%s\n' '## Verifying if the cluster is properly installed:'
printf '%s\n' ''
printf '%s\n' 'We first define a cleanup function to cleanup after the `operator_controller`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
operator_cleanup() {
EOF
)"
pe "$(cat <<'EOF'
rm -f operator_controller \
operator_controller.asc \
operator_controller.tgz.asc \
.las-manifest.template \
.las-manifest.template.asc \
.las-manifest.yaml \
.sgxplugin-manifest.template \
.sgxplugin-manifest.template.asc \
.sgxplugin-manifest.yaml
EOF
)"
pe "$(cat <<'EOF'
}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'We ensure that the correct `kubectl provision` plugin is installed:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
./operator_controller --set-version $SCONE_VERSION  --only-plugin  --reconcile --update
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Set your Intel API Key'
printf '%s\n' ''
printf '%s\n' 'To install the SCONE platform, you need an Intel API key. Please visit <https://api.portal.trustedservices.intel.com/manage-subscriptions> to generate or copy your DCAP API Key. Store this API key in a local environment variable:'
printf '%s\n' ''
printf '%s\n' 'export DCAP_KEY="..."'
printf '%s\n' ''
printf '%s\n' 'In case your cluster has already been installed, you can extract the DCAP_API_KEY as follows:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
    export DEFAULT_DCAP_KEY="00000000000000000000000000000000"
EOF
)"
pe "$(cat <<'EOF'
    export DCAP_KEY=${DCAP_KEY:-$DEFAULT_DCAP_KEY}
EOF
)"
pe "$(cat <<'EOF'
    if [[ "$DCAP_KEY" == "$DEFAULT_DCAP_KEY" ]] ; then
EOF
)"
pe "$(cat <<'EOF'
        echo "WARNING: No DCAP API Key in environment variable DCAP_KEY specified"
EOF
)"
pe "$(cat <<'EOF'
        EXISTING_DCAP_KEY=$(kubectl get las las -o json 2> /dev/null | jq -r '.spec.dcapKey' || echo "null" )
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
        if [[ "$EXISTING_DCAP_KEY" == "null" ]] ; then
EOF
)"
pe "$(cat <<'EOF'
            echo "WARNING: Extraction of DCAP_KEY from LAS failed - using default DCAP_KEY=$DEFAULT_DCAP_KEY - not recommended."
EOF
)"
pe "$(cat <<'EOF'
        else
EOF
)"
pe "$(cat <<'EOF'
            DCAP_KEY="$EXISTING_DCAP_KEY"
EOF
)"
pe "$(cat <<'EOF'
            echo "WARNING: Using DCAP_KEY extracted from LAS - not recommended."
EOF
)"
pe "$(cat <<'EOF'
        fi
EOF
)"
pe "$(cat <<'EOF'
    fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'In case we use the default DCAP API key, we ask the user for some input:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Check if DCAP_KEY is empty or unset
EOF
)"
pe "$(cat <<'EOF'
if [[ "$DCAP_KEY" == "$DEFAULT_DCAP_KEY" ]]; then
EOF
)"
pe "$(cat <<'EOF'
  while true; do
EOF
)"
pe "$(cat <<'EOF'
    read -rp "Please enter a 32-character hexadecimal DCAP_KEY: " input
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
    # Check if input is 32 hex chars (case-insensitive)
EOF
)"
pe "$(cat <<'EOF'
    if [[ "$input" =~ ^[0-9a-fA-F]{32}$ ]]; then
EOF
)"
pe "$(cat <<'EOF'
      DCAP_KEY="$input"
EOF
)"
pe "$(cat <<'EOF'
      export DCAP_KEY
EOF
)"
pe "$(cat <<'EOF'
      echo "✅ DCAP_KEY set."
EOF
)"
pe "$(cat <<'EOF'
      break
EOF
)"
pe "$(cat <<'EOF'
    else
EOF
)"
pe "$(cat <<'EOF'
      echo "❌ Invalid input. Must be exactly 32 hex characters (0-9, a-f)."
EOF
)"
pe "$(cat <<'EOF'
    fi
EOF
)"
pe "$(cat <<'EOF'
  done
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Next, we run the `operator_controller` to check if the proper version is installed:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl get deployment scone-controller-manager -n scone-system -o json | \
  jq -e "any(.status.conditions[]; .type == \"Available\" and .status == \"True\") and (.spec.template.spec.containers[0].image | contains(\":$SCONE_VERSION\"))" && \
  { echo "SCONE Version $SCONE_VERSION already installed" ; operator_cleanup ; exit 0; } || echo "Scone Operator is not installed, ready or version does NOT match."
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'If the latest stable version is installed and healthy, we can stop here. Otherwise, if we need to update or reconcile the platform, please continue with step 5. If the SCONE platform is not yet installed, please continue with step 6.'
printf '%s\n' ''
printf '%s\n' 'In case we upgrade from version 5 to version 6, we need to delete CRD `vault`. We ignore if the removal fails because vault crd might not exist:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl delete crd vaults.services.scone.cloud || true
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Ensure that the image pull secret `sconeapps` exists'
printf '%s\n' ''
printf '%s\n' 'We check if we can read the secret:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
export install_sconeapps_secret=0
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
kubectl get secret sconeapps -n scone-system >/dev/null 2>&1 && echo "\"sconeapps\" image pull secret exists" || { echo "Secret does not exist" ; export install_sconeapps_secret=1; }
EOF
)"
pe "$(cat <<'EOF'
kubectl get secret scone-operator-pull -n scone-system >/dev/null 2>&1 && echo "\"sconeapps\" image pull secret exists" || { echo "Secret does not exist" ; export install_sconeapps_secret=1; }
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'We assume that you use the `scone.cloud` image registry, you would need to deploy image pull secrets. For this, you will need to set environment variables:'
printf '%s\n' ''
printf '%s\n' 'For more details, please read the following document: [Create an Access Token](https://sconedocs.github.io/registry/#create-an-access-token). In the script (i.e., `reconcile_scone_operator.sh`), we'
printf '%s\n' 'ask the user to input the values for these variables:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
if [[ $install_sconeapps_secret == 1 ]] ; then
EOF
)"
pe "$(cat <<'EOF'
    # ask user for the credentials for accessing the registry
EOF
)"
pe "$(cat <<'EOF'
  eval $(tplenv --values Values.credentials.yaml --file registry.credentials.md --create-values-file --eval --force )
EOF
)"
pe "$(cat <<'EOF'

EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'We install/fix/update the installed version:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
    ./operator_controller --set-version $SCONE_VERSION --reconcile --update --plugin --verbose --dcap-api "$DCAP_KEY" --secret-operator  --username $REGISTRY_USER --access-token $REGISTRY_TOKEN --email info@scontain.com
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Updating the SCONE platform'
printf '%s\n' ''
printf '%s\n' 'In case an older version of the SCONE platform was already installed (i.e., when the `sconeapps` secret already exists), we can update the platform by executing the following command:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
    ./operator_controller --set-version $SCONE_VERSION --update --reconcile --plugin  --verbose --dcap-api "$DCAP_KEY"
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Cleaning up temporary files'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
operator_cleanup
EOF
)"
pe "$(cat <<'EOF'
echo "✅ SCONE Operator upgraded to version $SCONE_VERSION."
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Wait for LAS to become healthy'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
cd -
EOF
)"
pe "$(cat <<'EOF'
COND=HEALTHY TIMEOUT=300 INTERVAL=2 NAMESPACE= scripts/wait-crd-state.sh las
EOF
)"

