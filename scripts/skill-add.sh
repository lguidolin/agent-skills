#!/usr/bin/env bash
set -euo pipefail

# Add a skill on top of the current profile
# Usage: skill-add.sh <skill_name>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_NAME="${1:?Usage: skill-add.sh <skill_name>}"

source_dir="$AGENT_SKILLS_DIR/skills-available/$SKILL_NAME"

if [[ ! -d "$source_dir" ]]; then
  echo "ERROR: Skill '$SKILL_NAME' not found in the pool." >&2
  # A plugin-owned name is a common miss: it is available already, via the
  # plugin, and must not be symlinked from the pool.
  if [[ -x "$SCRIPT_DIR/plugin-skills.sh" ]]; then
    owner=$("$SCRIPT_DIR/plugin-skills.sh" --with-plugin 2>/dev/null \
      | awk -F'\t' -v s="$SKILL_NAME" '$2 == s { print $1; exit }') || true
    if [[ -n "$owner" ]]; then
      echo "  '$SKILL_NAME' is shipped by the installed plugin '$owner' and is already available." >&2
      echo "  Enable the plugin for this project instead of adding a pool skill." >&2
      exit 1
    fi
  fi
  echo "Available skills:" >&2
  ls "$AGENT_SKILLS_DIR/skills-available/" >&2
  exit 1
fi

mkdir -p .github/skills

if [[ -L ".github/skills/$SKILL_NAME" ]]; then
  echo "Skill '$SKILL_NAME' is already active."
  exit 0
fi

ln -sf "$source_dir" ".github/skills/$SKILL_NAME"
echo "✓ Added skill: $SKILL_NAME"
