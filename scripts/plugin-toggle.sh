#!/usr/bin/env bash
# scripts/plugin-toggle.sh — write project's .claude/settings.json enabledPlugins
# Usage: plugin-toggle.sh <project_dir> <enabled_plugin_name> [...]
# Sets every plugin in registry to false, then sets the listed ones to true.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="${AGENT_SKILLS_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
REGISTRY="$SCRIPT_DIR/registry.sh"

PROJECT_DIR="${1:?usage: plugin-toggle.sh <project_dir> [name...]}"
shift || true

mkdir -p "$PROJECT_DIR/.claude"
SETTINGS="$PROJECT_DIR/.claude/settings.json"

# Build full enabled map: every registry plugin → false; then the args → true
all_plugins=()
while IFS=$'\t' read -r name type; do
  [[ "$type" == "plugin" ]] && all_plugins+=("$name")
done < <("$REGISTRY" list 2>/dev/null || true)

map='{}'
for p in "${all_plugins[@]}"; do
  map=$(jq --arg p "$p" '.[$p] = false' <<<"$map")
done
for p in "$@"; do
  [[ -z "$p" ]] && continue
  map=$(jq --arg p "$p" '.[$p] = true' <<<"$map")
done

# Merge into existing settings.json if present, else create
out=$(mktemp)
if [[ -f "$SETTINGS" ]]; then
  jq --argjson m "$map" '.enabledPlugins = $m' "$SETTINGS" > "$out"
else
  printf '{"enabledPlugins": %s}\n' "$map" | jq '.' > "$out"
fi
mv "$out" "$SETTINGS"
