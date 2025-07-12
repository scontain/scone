#!/usr/bin/env bash

set -euo pipefail

show_help() {
  cat <<EOF
Usage: $0 [OPTIONS] <markdown-file> [output-script]

Extracts all \`\`\`bash or \`\`\`sh code blocks from a Markdown file
and writes them as a standalone executable shell script.

Markdown sections are embedded as inline heredocs (cat <<'EOF'),
with \$ and \\\` properly escaped to prevent unintended execution.

Options:
  --help        Show this help message and exit.

Examples:
  $0 doc.md                   # Print to stdout
  $0 doc.md script.sh         # Write to file and make it executable
EOF
}

# Check for --help
if [[ "${1:-}" == "--help" ]]; then
  show_help
  exit 0
fi

# Validate arguments
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

echo "#!/usr/bin/env bash" >> "$TMP_OUTPUT"
echo "" >> "$TMP_OUTPUT"
echo "set -euo pipefail " >> "$TMP_OUTPUT"


in_block=false
code_block=false
markdown_buffer=()

# Escape $ and ` for safe heredoc
escape_markdown_line() {
  echo "$1" | sed -e 's/\\/\\\\/g' -e 's/`/'\''/g' -e 's/\$/\\\$/g'
}

flush_markdown() {
  if [[ ${#markdown_buffer[@]} -gt 0 ]]; then
    echo "LILAC='\033[1;35m'" >> "$TMP_OUTPUT"
    echo "RESET='\033[0m'" >> "$TMP_OUTPUT"
    echo 'printf "${LILAC}"' >> "$TMP_OUTPUT"
    echo "cat <<EOF" >> "$TMP_OUTPUT"
    for line in "${markdown_buffer[@]}"; do
      escape_markdown_line "$line" >> "$TMP_OUTPUT"
    done
    echo "EOF" >> "$TMP_OUTPUT"
    echo 'printf "${RESET}"' >> "$TMP_OUTPUT"
    echo "" >> "$TMP_OUTPUT"
    markdown_buffer=()
  fi
}

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ ^\s*\`\`\`(bash|sh)\s*$ ]]; then
    flush_markdown
    in_block=true
    code_block=true
    continue
  elif [[ "$line" =~ ^\s*\`\`\` ]]; then
    in_block=false
    code_block=false
    continue
  fi

  if $in_block && $code_block; then
    echo "$line" >> "$TMP_OUTPUT"
  elif ! $in_block; then
    markdown_buffer+=("$line")
  fi
done < "$INPUT_FILE"

flush_markdown

# Output result
if [[ -n "$OUTPUT_FILE" ]]; then
  mv "$TMP_OUTPUT" "$OUTPUT_FILE"
  chmod +x "$OUTPUT_FILE"
  echo "✅ Script written to '$OUTPUT_FILE' and made executable."
else
  cat "$TMP_OUTPUT"
fi

trap - EXIT
