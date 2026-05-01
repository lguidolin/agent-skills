#!/usr/bin/env bash
set -euo pipefail

# Identify unconverted specs/plans and generate a conversion prompt
# Usage: doc-archive.sh [specs_dir] [plans_dir] [decisions_dir] [archive_dir]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECS_DIR="${1:-docs/superpowers/specs}"
PLANS_DIR="${2:-docs/superpowers/plans}"
DECISIONS_DIR="${3:-docs/superpowers/decisions}"
ARCHIVE_DIR="${4:-docs/superpowers/archive}"

# Find unconverted specs (no matching decision record)
unconverted=()

if [[ -d "$SPECS_DIR" ]]; then
  for spec in "$SPECS_DIR"/*.md; do
    [[ ! -f "$spec" ]] && continue
    basename_file=$(basename "$spec")
    # Strip date prefix and -design suffix for matching
    stem=$(echo "$basename_file" | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-//; s/-design\.md$//; s/\.md$//')

    # Check if a decision record exists with this stem
    found=false
    if [[ -d "$DECISIONS_DIR" ]]; then
      for decision in "$DECISIONS_DIR"/*"$stem"*.md; do
        [[ -f "$decision" ]] && found=true && break
      done
    fi

    if [[ "$found" == false ]]; then
      unconverted+=("$spec")
    fi
  done
fi

if [[ ${#unconverted[@]} -eq 0 ]]; then
  echo "✓ All specs have corresponding decision records. Nothing to archive."
  exit 0
fi

echo "Unconverted specs (${#unconverted[@]}):"
for spec in "${unconverted[@]}"; do
  echo "  - $spec"
done
echo ""

# Generate conversion prompt
TEMPLATE=$(cat "$SCRIPT_DIR/../templates/decision-record.md")

echo "=== CONVERSION PROMPT ==="
echo ""
echo "Paste the following into a Claude session to convert these specs:"
echo ""
echo "---"
echo ""
echo "Convert the following specs into compact decision records. For each spec:"
echo "1. Read the spec file"
echo "2. Create a decision record in $DECISIONS_DIR/ using this template:"
echo ""
echo "$TEMPLATE"
echo ""
echo "3. Move the original spec to $ARCHIVE_DIR/specs/"
echo "4. If there's a matching plan in $PLANS_DIR/, move it to $ARCHIVE_DIR/plans/"
echo ""
echo "Specs to convert:"
for spec in "${unconverted[@]}"; do
  echo "  - $spec"
done
echo ""
echo "After conversion, run: just claude-rebuild-index"
echo ""
echo "---"
