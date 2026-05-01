#!/usr/bin/env bash
set -euo pipefail

# Configure MCPs based on active profile + project config
# Usage: mcp-configure.sh <profile_name> [project_dir]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE_NAME="${1:?Usage: mcp-configure.sh <profile_name>}"
PROJECT_DIR="${2:-$(pwd)}"
MCPS_DIR="$AGENT_SKILLS_DIR/mcps"

if ! command -v yq &>/dev/null; then
  echo "WARNING: 'yq' not installed — skipping MCP configuration." >&2
  exit 0
fi

# Gather desired MCPs from profile
PROFILE_FILE="$AGENT_SKILLS_DIR/profiles/${PROFILE_NAME}.yml"
mapfile -t profile_mcps < <(yq -r '.mcps // [] | .[]' "$PROFILE_FILE" 2>/dev/null || true)

# Gather project-level MCPs from .claude-profiles.yml
project_mcps=()
mcps_add=()
mcps_remove=()
if [[ -f "$PROJECT_DIR/.claude-profiles.yml" ]]; then
  mapfile -t project_mcps < <(yq -r '.mcps // [] | .[]' "$PROJECT_DIR/.claude-profiles.yml" 2>/dev/null || true)
  mapfile -t mcps_add < <(yq -r ".${PROFILE_NAME}.mcps_add // [] | .[]" "$PROJECT_DIR/.claude-profiles.yml" 2>/dev/null || true)
  mapfile -t mcps_remove < <(yq -r ".${PROFILE_NAME}.mcps_remove // [] | .[]" "$PROJECT_DIR/.claude-profiles.yml" 2>/dev/null || true)
fi

# Merge: profile MCPs + project MCPs + profile-specific adds
desired_mcps=("${profile_mcps[@]}" "${project_mcps[@]}" "${mcps_add[@]}")

# Remove excluded
for remove in "${mcps_remove[@]}"; do
  [[ -z "$remove" ]] && continue
  desired_mcps=("${desired_mcps[@]/$remove/}")
done

# Deduplicate
mapfile -t desired_mcps < <(printf '%s\n' "${desired_mcps[@]}" | grep -v '^$' | sort -u)

# Report
echo ""
echo "MCPs for profile '$PROFILE_NAME':"
for mcp in "${desired_mcps[@]}"; do
  [[ -z "$mcp" ]] && continue
  mcp_file="$MCPS_DIR/${mcp}.yml"
  if [[ -f "$mcp_file" ]]; then
    desc=$(yq -r '.description' "$mcp_file")
    echo "  ✓ $mcp — $desc"
  else
    echo "  ? $mcp — (no definition file)"
  fi
done

# Note: Actual MCP install/remove is handled by claude-add-mcp/claude-rm-mcp commands
# This script reports what SHOULD be active. Install happens via just claude-add-mcp.
