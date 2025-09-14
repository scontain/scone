#!/usr/bin/env bash
set -Eeuo pipefail

# -------- Settings (tweak as you like) --------
TYPE_SPEED="${TYPE_SPEED:-25}"        # characters per second
PAUSE_AFTER_CMD="${PAUSE_AFTER_CMD:-0.6}"  # seconds to linger after each command
SHELLRC="${SHELLRC:-/dev/null}"       # don't load user rc for determinism
PROMPT="${PROMPT:-$'\\[\\e[1;32m\\]demo\\[\\e[0m\\]:\\[\\e[1;34m\\]~\\[\\e[0m\\]\\$ '}"
COLUMNS="${COLUMNS:-100}"; LINES="${LINES:-26}"  # fixed terminal size for nice playback

# -------- Helpers --------
slow_type() {
  local text="$*"
  local delay=$(awk "BEGIN { print 1 / $TYPE_SPEED }")
  # print without a trailing newline
  for ((i=0; i<${#text}; i++)); do
    printf "%s" "${text:i:1}"
    sleep "$delay"
  done
}

# Type a command, press Enter, then execute it
pe() {
  local cmd="$*"
  slow_type "$cmd"
  printf "\n"
  eval "$cmd"
  sleep "$PAUSE_AFTER_CMD"
}

# -------- Deterministic shell env --------
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export COLUMNS LINES
export PS1="$PROMPT"
stty cols "$COLUMNS" rows "$LINES"

# -------- Your scripted demo --------
CAS="cas"
CAS_NAMESPACE="default"

pe '# Checking prerequisites and installing SCONE CLI...'
pe 'scripts/prerequisite_check.sh'
pe '# Next, we install the SCONE operator including SCONE SGX Plugin, SCONE Local Attestation Service, and SCONE Configuration and Attestation Service...' 
pe 'scripts/reconcile_scone_operator.sh'
pe "# Installing CAS $CAS in namespace $CAS_NAMESPACE ..."
pe 'scripts/install_cas.sh'
pe "kubectl get cas -n $CAS_NAMESPACE -o wide"
pe '# DONE'

# Done
sleep 10
