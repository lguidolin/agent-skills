#!/usr/bin/env bash
set -euo pipefail

CLAUDEIGNORE=".claudeignore"
MARKER_START="# --- agent-skills:managed:start ---"
MARKER_END="# --- agent-skills:managed:end ---"
MARKER_COMMENT="# Auto-managed by agent-skills profiles. Do not edit this section."

usage() {
  echo "Usage: $(basename "$0") <patterns_file|->" >&2
  exit 1
}

read_patterns() {
  local source="${1:-}"
  if [[ -z "$source" ]]; then
    usage
  fi
  if [[ "$source" == "-" ]]; then
    cat
  else
    if [[ ! -f "$source" ]]; then
      echo "Error: file not found: $source" >&2
      exit 1
    fi
    cat "$source"
  fi
}

main() {
  local patterns
  patterns=$(read_patterns "${1:-}")

  local managed_block
  managed_block="${MARKER_START}
${MARKER_COMMENT}
${patterns}
${MARKER_END}"

  # If .claudeignore doesn't exist, create it with the managed block
  if [[ ! -f "$CLAUDEIGNORE" ]]; then
    printf '%s\n' "$managed_block" > "$CLAUDEIGNORE"
    return
  fi

  local file_content
  file_content=$(cat "$CLAUDEIGNORE")

  # If markers don't exist, append them
  if ! grep -qF "$MARKER_START" "$CLAUDEIGNORE" || ! grep -qF "$MARKER_END" "$CLAUDEIGNORE"; then
    printf '\n%s\n' "$managed_block" >> "$CLAUDEIGNORE"
    return
  fi

  # Markers exist — replace content between them
  local before after
  before=$(sed "/${MARKER_START}/,\$d" "$CLAUDEIGNORE")
  after=$(sed "1,/${MARKER_END}/d" "$CLAUDEIGNORE")

  {
    if [[ -n "$before" ]]; then
      printf '%s\n' "$before"
    fi
    printf '%s\n' "$managed_block"
    if [[ -n "$after" ]]; then
      printf '%s\n' "$after"
    fi
  } > "$CLAUDEIGNORE"
}

main "$@"
