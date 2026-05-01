#!/usr/bin/env bash
set -euo pipefail

# Rebuild the master decision index from decision record frontmatter
# Usage: index-rebuild.sh [decisions_dir] [output_file]

DECISIONS_DIR="${1:-docs/superpowers/decisions}"
INDEX_FILE="${2:-docs/superpowers/index.md}"

if [[ ! -d "$DECISIONS_DIR" ]]; then
  echo "No decisions directory found at $DECISIONS_DIR"
  exit 0
fi

if ! command -v yq &>/dev/null; then
  echo "ERROR: 'yq' is required for index generation." >&2
  exit 1
fi

# Collect records
active_rows=""
superseded_rows=""

for file in "$DECISIONS_DIR"/*.md; do
  [[ ! -f "$file" ]] && continue

  # Extract YAML frontmatter (between first two --- lines)
  frontmatter=$(sed -n '/^---$/,/^---$/p' "$file" | sed '1d;$d')

  title=$(echo "$frontmatter" | yq -r '.title // "Untitled"')
  date=$(echo "$frontmatter" | yq -r '.date // "Unknown"')
  component=$(echo "$frontmatter" | yq -r '.component // "general"')
  status=$(echo "$frontmatter" | yq -r '.status // "implemented"')
  supersedes=$(echo "$frontmatter" | yq -r '.supersedes // ""')
  deps=$(echo "$frontmatter" | yq -r '.dependencies // [] | join(", ")')

  if [[ "$status" == "superseded" ]]; then
    superseded_rows+="| $component | $title | $supersedes |\n"
  else
    active_rows+="| $component | $title | $date | $deps |\n"
  fi
done

# Write index
mkdir -p "$(dirname "$INDEX_FILE")"
cat > "$INDEX_FILE" <<EOF
# Project Decision Index

## Active Decisions

| Component | Title | Date | Dependencies |
|-----------|-------|------|--------------|
$(echo -e "$active_rows")

## Superseded

| Component | Title | Superseded By |
|-----------|-------|---------------|
$(echo -e "$superseded_rows")
EOF

echo "✓ Index rebuilt: $INDEX_FILE"
