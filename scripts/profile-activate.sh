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
  source_dir="$AGENT_SKILLS_DIR/skills-available/$skill"
  if [[ -d "$source_dir" ]]; then
    ln -sf "$source_dir" ".github/skills/$skill"
    linked=$((linked + 1))
  else
    echo "WARNING: skill '$skill' not in $AGENT_SKILLS_DIR/skills-available/ — skipping" >&2
  fi
done

# Step 6.5: Tear down old agent symlinks, then create new ones
mkdir -p .claude/agents
find .claude/agents -maxdepth 1 -type l -exec rm {} \; 2>/dev/null || true

mapfile -t agents < <(yq '.agents // [] | .[]' "$PROFILE_FILE" 2>/dev/null || true)

# project-level overrides for agents
if [[ -f ".claude-profiles.yml" ]]; then
  mapfile -t agents_add    < <(yq ".${PROFILE_NAME}.agents_add // [] | .[]" ".claude-profiles.yml" 2>/dev/null || true)
  mapfile -t agents_remove < <(yq ".${PROFILE_NAME}.agents_remove // [] | .[]" ".claude-profiles.yml" 2>/dev/null || true)
  for a in "${agents_add[@]}";    do [[ -n "$a" ]] && agents+=("$a"); done
  for r in "${agents_remove[@]}"; do agents=("${agents[@]/$r/}"); done
fi

agents_linked=0
for agent in "${agents[@]}"; do
  [[ -z "$agent" ]] && continue
  src="$AGENT_SKILLS_DIR/agents-available/$agent"
  if [[ -d "$src" ]]; then
    ln -sf "$src" ".claude/agents/$agent"
    agents_linked=$((agents_linked + 1))
  else
    echo "WARNING: agent '$agent' not in $AGENT_SKILLS_DIR/agents-available/ — skipping" >&2
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
echo "  Agents: $agents_linked symlinked"
echo "  Directory: $PROJECT_DIR/.github/skills/"
echo ""
echo "Active skills:"
for skill in "${skills[@]}"; do
  [[ -z "$skill" ]] && continue
  echo "  - $skill"
done
echo ""
echo "Run 'just claude-list-active-skills' for details or 'just claude-add-skill <name>' to add more."
