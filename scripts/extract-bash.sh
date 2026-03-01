#!/usr/bin/env bash

set -euo pipefail

show_help() {
  cat <<USAGE
Usage: $0 [OPTIONS] <markdown-file> [output-script]

Extracts all \`\`\`bash or \`\`\`sh code blocks from a Markdown file
and writes them as a standalone executable shell script.

Modes:
  default     Emits colored markdown + code, then executes code blocks.
  --docs-pe   Emits a demo-style script where each code line runs via pe 'COMMAND'.

Options:
  --docs-pe    Generate a docs runner script that uses pe for each code line.
  --help       Show this help message and exit.

Examples:
  $0 doc.md
  $0 doc.md script.sh
  $0 --docs-pe doc.md docs/script.sh
USAGE
}

mode="default"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      show_help
      exit 0
      ;;
    --docs-pe)
      mode="docs-pe"
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: Unknown option '$1'." >&2
      show_help >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -lt 1 || $# -gt 2 ]]; then
  show_help >&2
  exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-}"

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Error: File '$INPUT_FILE' not found." >&2
  exit 1
fi

TMP_OUTPUT=$(mktemp)
trap 'rm -f "$TMP_OUTPUT"' EXIT

write_default_header() {
  {
    echo "#!/usr/bin/env bash"
    echo
    echo "set -euo pipefail"
    echo
    echo "VIOLET='\\033[38;5;141m'"
    echo "ORANGE='\\033[38;5;208m'"
    echo "RESET='\\033[0m'"
    echo
  } >>"$TMP_OUTPUT"
}

write_docs_header() {
  cat >>"$TMP_OUTPUT" <<'EOF'
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
  local display_cmd
  display_cmd=$(printf "%s" "$cmd" | sed 's/\$/\\$/g')
  printf "%b" "$ORANGE"
  slow_type "$display_cmd"
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

EOF
}

escape_single_quotes() {
  printf "%s" "$1" | sed "s/'/'\\\\''/g"
}

escape_dollars_for_display() {
  printf "%s" "$1" | sed 's/\$/\\$/g'
}

if [[ "$mode" == "docs-pe" ]]; then
  write_docs_header
else
  write_default_header
fi

in_block=false
code_block=false
markdown_buffer=()
code_buffer=()

flush_markdown() {
  if [[ ${#markdown_buffer[@]} -gt 0 ]]; then
    if [[ "$mode" == "docs-pe" ]]; then
      echo 'printf "%b" "$LILAC"' >> "$TMP_OUTPUT"
      echo "cat <<'EOF'" >> "$TMP_OUTPUT"
      for line in "${markdown_buffer[@]}"; do
        echo "$line" >> "$TMP_OUTPUT"
      done
      echo "EOF" >> "$TMP_OUTPUT"
      echo 'printf "%b" "$RESET"' >> "$TMP_OUTPUT"
      echo "" >> "$TMP_OUTPUT"
      markdown_buffer=()
      return
    fi

    echo 'printf "${VIOLET}"' >> "$TMP_OUTPUT"
    echo "cat <<'EOF'" >> "$TMP_OUTPUT"
    for line in "${markdown_buffer[@]}"; do
      echo "$line" >> "$TMP_OUTPUT"
    done
    echo "EOF" >> "$TMP_OUTPUT"
    echo 'printf "${RESET}"' >> "$TMP_OUTPUT"
    echo "" >> "$TMP_OUTPUT"
    markdown_buffer=()
  fi
}

flush_code_block() {
  if [[ ${#code_buffer[@]} -eq 0 ]]; then
    return
  fi

  if [[ "$mode" == "docs-pe" ]]; then
    for line in "${code_buffer[@]}"; do
      escaped_line=$(escape_single_quotes "$line")
      echo "pe '$escaped_line'" >> "$TMP_OUTPUT"
    done
    echo "" >> "$TMP_OUTPUT"
    code_buffer=()
    return
  fi

  echo 'printf "${ORANGE}"' >> "$TMP_OUTPUT"
  echo "cat <<'EOF'" >> "$TMP_OUTPUT"
  for line in "${code_buffer[@]}"; do
    escape_dollars_for_display "$line" >> "$TMP_OUTPUT"
  done
  echo "EOF" >> "$TMP_OUTPUT"
  echo 'printf "${RESET}"' >> "$TMP_OUTPUT"
  echo "" >> "$TMP_OUTPUT"
  for line in "${code_buffer[@]}"; do
    echo "$line" >> "$TMP_OUTPUT"
  done
  echo "" >> "$TMP_OUTPUT"
  code_buffer=()
}

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ ^\s*\`\`\`(bash|sh)\s*$ ]]; then
    flush_markdown
    in_block=true
    code_block=true
    continue
  elif [[ "$line" =~ ^\s*\`\`\` ]]; then
    if $in_block && $code_block; then
      flush_code_block
    fi
    in_block=false
    code_block=false
    continue
  fi

  if $in_block && $code_block; then
    code_buffer+=("$line")
  elif ! $in_block; then
    markdown_buffer+=("$line")
  fi
done < "$INPUT_FILE"

flush_markdown
flush_code_block

if [[ -n "$OUTPUT_FILE" ]]; then
  mv "$TMP_OUTPUT" "$OUTPUT_FILE"
  chmod +x "$OUTPUT_FILE"
  echo "✅ Script written to '$OUTPUT_FILE' and made executable."
else
  cat "$TMP_OUTPUT"
fi

trap - EXIT
