#!/usr/bin/env bash
set -euo pipefail

# Activate a profile: symlink skills, configure MCPs, sync .claudeignore
# Usage: profile-activate.sh <profile_name> [project_dir]
# Requires: yq (https://github.com/mikefarah/yq)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="${2:-$(pwd)}"
PROFILE_NAME="${1:?Usage: profile-activate.sh <profile_name> [project_dir]}"
PROFILE_FILE="$AGENT_SKILLS_DIR/profiles/${PROFILE_NAME}.yml"

if [[ ! -f "$PROFILE_FILE" ]]; then
  echo "ERROR: Profile '$PROFILE_NAME' not found at $PROFILE_FILE" >&2
  echo "Available profiles:" >&2
  ls "$AGENT_SKILLS_DIR/profiles/"*.yml 2>/dev/null | xargs -I{} basename {} .yml >&2
  exit 1
fi

# Check for yq
if ! command -v yq &>/dev/null; then
  echo "ERROR: 'yq' is required but not installed." >&2
  echo "Install: https://github.com/mikefarah/yq#install" >&2
  exit 1
fi

cd "$PROJECT_DIR"

# Step 1: Acquire lock
"$SCRIPT_DIR/profile-lock.sh" acquire "$PROFILE_NAME"

# Step 2: Ensure .github/skills/ exists
mkdir -p .github/skills

# Step 3: Remove existing symlinks (only symlinks, never real files/dirs)
find .github/skills -maxdepth 1 -type l -exec rm {} \;

# Step 4: Read skills from profile
mapfile -t skills < <(yq -r '.skills[]' "$PROFILE_FILE" 2>/dev/null || true)

# Step 5: Merge project overrides if .claude-profiles.yml exists
if [[ -f ".claude-profiles.yml" ]]; then
  mapfile -t skills_add < <(yq -r ".${PROFILE_NAME}.skills_add // [] | .[]" ".claude-profiles.yml" 2>/dev/null || true)
  mapfile -t skills_remove < <(yq -r ".${PROFILE_NAME}.skills_remove // [] | .[]" ".claude-profiles.yml" 2>/dev/null || true)

  # Add project-specific skills
  for skill in "${skills_add[@]}"; do
    [[ -n "$skill" ]] && skills+=("$skill")
  done

  # Remove excluded skills
  for remove in "${skills_remove[@]}"; do
    skills=("${skills[@]/$remove/}")
  done
fi

# Step 6: Create symlinks
linked=0
for skill in "${skills[@]}"; do
  [[ -z "$skill" ]] && continue
  source_dir="$AGENT_SKILLS_DIR/.github/skills/$skill"
  if [[ -d "$source_dir" ]]; then
    ln -sf "$source_dir" ".github/skills/$skill"
    linked=$((linked + 1))
  else
    echo "WARNING: Skill '$skill' not found in $AGENT_SKILLS_DIR/.github/skills/" >&2
  fi
done

# Step 7: Sync .claudeignore
patterns=$(yq -r '.claudeignore // [] | .[]' "$PROFILE_FILE" 2>/dev/null || true)
echo "$patterns" | "$SCRIPT_DIR/claudeignore-sync.sh" -

# Step 8: Configure MCPs (best effort, script may not exist yet)
if [[ -x "$SCRIPT_DIR/mcp-configure.sh" ]]; then
  "$SCRIPT_DIR/mcp-configure.sh" "$PROFILE_NAME" "$PROJECT_DIR" 2>/dev/null || true
fi

# Step 9: Report
echo ""
echo "✓ Profile '$PROFILE_NAME' activated"
echo "  Skills: $linked symlinked"
echo "  Directory: $PROJECT_DIR/.github/skills/"
echo ""
echo "Active skills:"
for skill in "${skills[@]}"; do
  [[ -z "$skill" ]] && continue
  echo "  - $skill"
done
echo ""
echo "Run 'just claude-list-active-skills' for details or 'just claude-add-skill <name>' to add more."
