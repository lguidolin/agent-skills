#!/usr/bin/env bash
set -euo pipefail

# Remove a skill from the current profile
# Usage: skill-rm.sh <skill_name>

SKILL_NAME="${1:?Usage: skill-rm.sh <skill_name>}"

target=".github/skills/$SKILL_NAME"

if [[ ! -L "$target" ]]; then
  if [[ -d "$target" ]]; then
    echo "ERROR: '$SKILL_NAME' is a real directory, not a symlink. Won't remove." >&2
    exit 1
  fi
  echo "Skill '$SKILL_NAME' is not active."
  exit 0
fi

rm "$target"
echo "✓ Removed skill: $SKILL_NAME"
