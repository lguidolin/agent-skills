#!/usr/bin/env bash
set -euo pipefail

# Pre-session hook: validate profile state
# Called before Claude Code starts a session

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check if profile is active
if [[ -f ".claude-profile.lock" ]]; then
  profile=$(sed -n '2p' .claude-profile.lock)
  pid=$(sed -n '1p' .claude-profile.lock)

  # Check if lock is stale
  if ! kill -0 "$pid" 2>/dev/null; then
    rm -f .claude-profile.lock
    echo "⚠ Stale profile lock cleaned up. No profile active."
    echo "  Run: just claude-<profile> to activate one."
    exit 0
  fi

  # Validate symlinks are intact
  broken=0
  for link in .github/skills/*/; do
    [[ ! -L "${link%/}" ]] && continue
    if [[ ! -e "${link%/}" ]]; then
      broken=$((broken + 1))
    fi
  done

  if [[ $broken -gt 0 ]]; then
    echo "⚠ Profile '$profile' has $broken broken skill symlinks."
    echo "  Run: just claude-$profile to refresh."
  fi
else
  echo "ℹ No profile active. Run: just claude-<profile>"
  echo "  Available: brainstorm, design, code, ship, minimal"
fi
