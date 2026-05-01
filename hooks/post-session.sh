#!/usr/bin/env bash
set -euo pipefail

# Post-session hook: optionally revert to minimal
# Only acts if the active profile has post_session: true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ ! -f ".claude-profile.lock" ]]; then
  exit 0
fi

profile=$(sed -n '2p' .claude-profile.lock)
PROFILE_FILE="$AGENT_SKILLS_DIR/profiles/${profile}.yml"

if [[ ! -f "$PROFILE_FILE" ]]; then
  exit 0
fi

# Check if post_session is enabled for this profile
if command -v yq &>/dev/null; then
  post_session=$(yq -r '.hooks.post_session // false' "$PROFILE_FILE")
  if [[ "$post_session" == "true" ]]; then
    echo "Profile '$profile' auto-reverting to minimal..."
    "$SCRIPT_DIR/../scripts/profile-activate.sh" minimal
  fi
fi
