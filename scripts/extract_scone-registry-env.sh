#!/usr/bin/env bash
# Extract Docker creds for registry.scontain.com (or :5050) into scone-registry.env
# Robust with Docker Desktop/cred helpers; only writes when user+token are non-empty.

set -euo pipefail

# ---------- config ----------
OUT_FILE="scone-registry.env"
REGISTRIES=("registry.scontain.com" "registry.scontain.com:5050")
DOCKER_CONFIG_DIR="${DOCKER_CONFIG:-$HOME/.docker}"
DOCKER_CONFIG_JSON="$DOCKER_CONFIG_DIR/config.json"
USE_HELPERS="${USE_HELPERS:-1}"            # set 0 to skip docker-credential-* lookups
HELPER_TIMEOUT_SECS="${HELPER_TIMEOUT_SECS:-2}"
VERBOSE="${VERBOSE:-1}"

# ---------- logging ----------
c0=$'\033[0m'; cR=$'\033[31m'; cG=$'\033[32m'; cY=$'\033[33m'; cB=$'\033[34m'
info() { printf "${cB}[INFO]${c0} %s\n" "$*"; }
ok()   { printf "${cG}[OK]${c0} %s\n"   "$*"; }
warn() { printf "${cY}[WARN]${c0} %s\n" "$*"; }
err()  { printf "${cR}[ERR]${c0} %s\n"  "$*" >&2; }
dbg() {
  case "${VERBOSE:-0}" in
    1|true|TRUE|yes|YES|y|Y)
      # print each arg on its own line; to keep as one line, use "$*"
      for msg in "$@"; do
        printf '[DBG] %s\n' "$msg" >&2
      done
      ;;
  esac
}
die()  { err "$*"; exit 3; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }

trim() { sed -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+$//'; }

# Try to base64-decode across GNU/BSD variants
b64dec() {
  if echo | base64 --decode >/dev/null 2>&1; then base64 --decode
  elif echo | base64 -d       >/dev/null 2>&1; then base64 -d
  elif echo | base64 -D       >/dev/null 2>&1; then base64 -D
  else die "No suitable base64 decoder found"; fi
}

# jq wrapper: first arg is file, everything after is passed through to jq
jq_get() {
  local file="$1"; shift
  jq -r "$@" "$file"
}

valid_pair() {
  local u="$(printf '%s' "$1" | trim)"
  local t="$(printf '%s' "$2" | trim)"
  [ -n "$u" ] && [ -n "$t" ] && [ "$u" != "null" ] && [ "$t" != "null" ]
}

decode_auth_field() {
  # input: base64("user:token"); stdout "user:token" if valid; else prints nothing
  local b="$1" dec user token
  dec="$(printf '%s' "$b" | b64dec 2>/dev/null | tr -d '\r\n')"
  [[ "$dec" == *:* ]] || { printf ''; return 0; }
  user="${dec%%:*}"; token="${dec#*:}"
  user="$(printf '%s' "$user" | trim)"
  token="$(printf '%s' "$token" | trim)"
  if valid_pair "$user" "$token"; then printf '%s:%s' "$user" "$token"; else printf ''; fi
}

extract_direct_for_registry() {
  # stdout "user:token" or nothing
  local reg="$1" a u p it out

  # 1) .auth (try several common key shapes)
  a="$(jq_get "$DOCKER_CONFIG_JSON" --arg s "$reg" '
      (.auths[$s].auth)
   // (.auths["https://"+$s].auth)
   // (.auths["https://"+$s+"/v2/"].auth)
   // (.auths["https://"+$s+"/v1/"].auth)
   // (.auths["http://"+$s].auth)
   // (.auths["http://"+$s+"/v2/"].auth)
   // (.auths["http://"+$s+"/v1/"].auth)
   // empty
  ')"
  if [ -n "${a:-}" ]; then
    out="$(decode_auth_field "$a")"
    [ -n "$out" ] && { printf '%s' "$out"; return 0; }
    dbg "Direct .auth present for $reg but invalid/empty after decode."
  fi

  # 2) explicit username/password
  u="$(jq_get "$DOCKER_CONFIG_JSON" --arg s "$reg" '
      (.auths[$s].username)
   // (.auths["https://"+$s].username)
   // (.auths["https://"+$s+"/v2/"].username)
   // (.auths["http://"+$s].username)
   // (.auths["http://"+$s+"/v2/"].username)
   // empty
  ')"
  p="$(jq_get "$DOCKER_CONFIG_JSON" --arg s "$reg" '
      (.auths[$s].password)
   // (.auths["https://"+$s].password)
   // (.auths["https://"+$s+"/v2/"].password)
   // (.auths["http://"+$s].password)
   // (.auths["http://"+$s+"/v2/"].password)
   // empty
  ')"
  if valid_pair "$u" "$p"; then printf '%s:%s' "$u" "$p"; return 0; fi

  # 3) identitytoken (use "token:<idtoken>")
  it="$(jq_get "$DOCKER_CONFIG_JSON" --arg s "$reg" '
      (.auths[$s].identitytoken)
   // (.auths["https://"+$s].identitytoken)
   // (.auths["https://"+$s+"/v2/"].identitytoken)
   // (.auths["http://"+$s].identitytoken)
   // (.auths["http://"+$s+"/v2/"].identitytoken)
   // empty
  ')"
  if [ -n "${it:-}" ]; then printf 'token:%s' "$it"; return 0; fi

  printf ''
}

helper_prog_for() {
  local reg="$1" helper
  helper="$(jq_get "$DOCKER_CONFIG_JSON" --arg s "$reg" '
      (.credHelpers[$s])
   // (.credHelpers["https://"+$s])
   // (.credsStore)
   // empty
  ')"
  [ -n "$helper" ] || return 1
  printf 'docker-credential-%s' "$helper"
}

# pick a timeout command if available (Linux: timeout, macOS: gtimeout)
_timeout() {
  if command -v timeout >/dev/null 2>&1; then timeout "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$@"
  else
    # No timeout available — safer to skip helpers than hang
    return 127
  fi
}

helper_get_pair() {
  # stdout "user:token" or nothing
  local helper="$1" reg="$2" out user secret
  command -v "$helper" >/dev/null 2>&1 || { printf ''; return 0; }

  if out="$(_timeout "$HELPER_TIMEOUT_SECS" \
            "$helper" get <<<"$(printf '{"ServerURL":"https://%s"}' "$reg")" 2>/dev/null)"; then :
  elif out="$(_timeout "$HELPER_TIMEOUT_SECS" \
            "$helper" get <<<"$(printf '{"ServerURL":"%s"}' "$reg")" 2>/dev/null)"; then :
  else
    printf ''; return 0
  fi

  user="$(jq -r '.Username // empty' <<<"$out" | trim)"
  secret="$(jq -r '.Secret   // empty' <<<"$out" | trim)"
  if valid_pair "$user" "$secret"; then printf '%s:%s' "$user" "$secret"; else printf ''; fi
}

write_env() {
  local user="$1" token="$2"
  umask 077
  cat >"$OUT_FILE" <<EOF
export SCONE_REGISTRY_ACCESS_TOKEN="${token}"
export SCONE_REGISTRY_USERNAME="${user}"
EOF
  ok "Wrote $OUT_FILE"
}

# ---------- main ----------
need jq
[ -f "$DOCKER_CONFIG_JSON" ] || die "Docker config not found: $DOCKER_CONFIG_JSON"
info "Using Docker config: $DOCKER_CONFIG_JSON"

# Pass 1: direct extraction (no helpers)
for reg in "${REGISTRIES[@]}"; do
  pair="$(extract_direct_for_registry "$reg" || true)"
  if [ -n "${pair:-}" ]; then
    user="${pair%%:*}"; token="${pair#*:}"
    if valid_pair "$user" "$token"; then
      info "Found credentials for $reg (direct)."
      write_env "$user" "$token"; exit 0
    else
      warn "Direct entry for $reg had empty user/token; continuing…"
    fi
  else
    dbg "No usable direct entry for $reg"
  fi
done

# Pass 2: helpers (optional)
if [ "$USE_HELPERS" = "1" ]; then
  if ! command -v timeout >/dev/null 2>&1 && ! command -v gtimeout >/dev/null 2>&1; then
    warn "timeout/gtimeout not found; skipping helper lookups (set USE_HELPERS=0 to silence)."
  else
    for reg in "${REGISTRIES[@]}"; do
      if helper="$(helper_prog_for "$reg" 2>/dev/null)"; then
        dbg "Trying credential helper $helper for $reg"
        pair="$(helper_get_pair "$helper" "$reg" || true)"
        if [ -n "${pair:-}" ]; then
          user="${pair%%:*}"; token="${pair#*:}"
          if valid_pair "$user" "$token"; then
            info "Found credentials for $reg via helper ($helper)."
            write_env "$user" "$token"; exit 0
          else
            warn "Helper $helper for $reg returned empty user/token; continuing…"
          fi
        fi
      fi
    done
  fi
fi

# Guaranteed error
printf >&2 '%s\n' "[ERR] Could not extract non-empty Docker credentials for:"
printf >&2 '      - %s\n' "${REGISTRIES[@]}"
printf >&2 '%s\n\n' "Troubleshooting:"
printf >&2 '  • docker login registry.scontain.com:5050\n'
printf >&2 '  • Headless host + Docker Desktop creds?  USE_HELPERS=0 ./script.sh\n'
printf >&2 '  • Validate JSON (no trailing commas!): jq . "%s"\n\n' "$DOCKER_CONFIG_JSON"
printf >&2 '%s\n' "Need a token? See: https://sconedocs.github.io/registry/#create-an-access-token"
exit 2
