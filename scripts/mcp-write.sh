#!/usr/bin/env bash
# scripts/mcp-write.sh — write project's .mcp.json from registry MCP entries
# Usage: mcp-write.sh <project_dir> [<mcp_name> ...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="${AGENT_SKILLS_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

PROJECT_DIR="${1:?usage: mcp-write.sh <project_dir> [mcp_name...]}"
shift || true

OUT="$PROJECT_DIR/.mcp.json"

# Build mcpServers JSON object
servers='{}'
for name in "$@"; do
  [[ -z "$name" ]] && continue
  yml="$AGENT_SKILLS_DIR/mcps-available/$name.yml"
  if [[ ! -f "$yml" ]]; then
    echo "WARNING: mcp '$name' not in mcps-available/ — skipping" >&2
    continue
  fi
  cmd=$(yq '.command' "$yml")
  args=$(yq -o=json -I=0 '.args // []' "$yml")
  servers=$(jq --arg n "$name" --arg cmd "$cmd" --argjson args "$args" \
    '.[$n] = {command: $cmd, args: $args}' <<<"$servers")
done

# Write .mcp.json (always overwrite — profile activation owns this file)
echo "{\"mcpServers\": $servers}" | jq '.' > "$OUT"
