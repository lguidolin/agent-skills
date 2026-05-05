#!/usr/bin/env bash
# scripts/tool-list.sh — inventory display for the centralized tool pool
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="${AGENT_SKILLS_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
REG="$AGENT_SKILLS_DIR/registry.yml"

# --- Parse arguments ---
filter_type=""
filter_profile=""
filter_project=""

for arg in "$@"; do
  case "$arg" in
    --type=*)    filter_type="${arg#--type=}" ;;
    --profile=*) filter_profile="${arg#--profile=}" ;;
    --project=*) filter_project="${arg#--project=}" ;;
    *) echo "tool-list.sh: unknown flag '$arg'" >&2; exit 1 ;;
  esac
done

case "$filter_type" in
  ""|plugin|skill|agent|mcp) ;;
  *) echo "tool-list.sh: unknown --type=$filter_type (expected: plugin|skill|agent|mcp)" >&2; exit 2 ;;
esac

if [[ ! -f "$REG" ]]; then
  echo "No registry found at $REG. Run 'just claude-bootstrap' to populate."
  exit 0
fi

# --- Build TSV rows from registry ---
# Columns: name, type, active_count, profiles_csv, active_in_csv, origin
rows=$(yq '
  .assets // {}
  | to_entries
  | .[]
  | [
      .key,
      .value.type,
      ((.value.active_in // []) | length | tostring),
      ((.value.profiles  // []) | join(",")),
      ((.value.active_in // []) | join(",")),
      (.value.origin // "")
    ]
  | @tsv
' "$REG")

# --- filter_row: returns 0 (include) or 1 (exclude) ---
filter_row() {
  local type="$1" profiles_csv="$2" active_in_csv="$3"

  # --type filter
  if [[ -n "$filter_type" && "$type" != "$filter_type" ]]; then
    return 1
  fi

  # --profile filter: asset must list the profile
  if [[ -n "$filter_profile" ]]; then
    local found=0
    IFS=',' read -ra plist <<< "$profiles_csv"
    for p in "${plist[@]}"; do
      [[ "$p" == "$filter_profile" ]] && found=1 && break
    done
    [[ $found -eq 0 ]] && return 1
  fi

  # --project filter: asset must be active in the project
  if [[ -n "$filter_project" ]]; then
    local found=0
    IFS=',' read -ra alist <<< "$active_in_csv"
    for a in "${alist[@]}"; do
      [[ "$a" == "$filter_project" ]] && found=1 && break
    done
    [[ $found -eq 0 ]] && return 1
  fi

  return 0
}

# --- Render a section ---
render_section() {
  local section_type="$1"
  local header="$2"
  local printed_header=0

  [[ -z "$rows" ]] && return

  while IFS=$'\t' read -r name type active_count profiles_csv active_in_csv origin; do
    [[ "$type" != "$section_type" ]] && continue
    filter_row "$type" "$profiles_csv" "$active_in_csv" || continue

    if [[ $printed_header -eq 0 ]]; then
      echo ""
      echo "$header"
      printed_header=1
    fi

    # Active marker
    local marker="○"
    [[ "$active_count" -gt 0 ]] && marker="●"

    # Build display line
    local line="  $marker $name"
    if [[ -n "$profiles_csv" ]]; then
      line+="  [profiles: $profiles_csv]"
    fi
    if [[ -n "$active_in_csv" ]]; then
      line+="  (active in: $active_in_csv)"
    fi
    if [[ -n "$origin" ]]; then
      line+="  [from: $origin]"
    fi
    echo "$line"
  done <<< "$rows"
}

# Print sections in order
render_section "plugin" "PLUGINS"
render_section "skill"  "SKILLS"
render_section "agent"  "AGENTS"
render_section "mcp"    "MCPS"
echo ""
