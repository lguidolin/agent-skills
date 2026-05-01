#!/usr/bin/env bash
set -euo pipefail

# Add a skill on top of the current profile
# Usage: skill-add.sh <skill_name>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_NAME="${1:?Usage: skill-add.sh <skill_name>}"

source_dir="$AGENT_SKILLS_DIR/.github/skills/$SKILL_NAME"

if [[ ! -d "$source_dir" ]]; then
  echo "ERROR: Skill '$SKILL_NAME' not found." >&2
  echo "Available skills:" >&2
  ls "$AGENT_SKILLS_DIR/.github/skills/" >&2
  exit 1
fi

mkdir -p .github/skills

if [[ -L ".github/skills/$SKILL_NAME" ]]; then
  echo "Skill '$SKILL_NAME' is already active."
  exit 0
fi

ln -sf "$source_dir" ".github/skills/$SKILL_NAME"
echo "✓ Added skill: $SKILL_NAME"
