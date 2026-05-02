#!/usr/bin/env bash
# scripts/bootstrap.sh — one-time global discovery
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="${AGENT_SKILLS_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
REGISTRY="$SCRIPT_DIR/registry.sh"
ASSUME_YES=0
ONLY_SECTION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y)              ASSUME_YES=1 ;;
    --plugins-only)        ONLY_SECTION="plugins" ;;
    --skills-only)         ONLY_SECTION="skills" ;;
    --mcps-only)           ONLY_SECTION="mcps" ;;
    --plugin-disable-only) ONLY_SECTION="plugin-disable" ;;
    *) echo "bootstrap: unknown flag $1" >&2; exit 1 ;;
  esac
  shift
done

confirm() {
  if [[ "$ASSUME_YES" -eq 1 ]]; then return 0; fi
  read -rp "$1 [Y/n] " ans
  [[ "${ans:-Y}" =~ ^[Yy]?$ ]]
}

discover_plugins() {
  echo "[bootstrap] scanning ~/.claude/plugins/cache..."
  "$REGISTRY" init
  local cache="$HOME/.claude/plugins/cache"
  [[ -d "$cache" ]] || { echo "  (no plugins cache, skipping)"; return; }

  local count=0
  for marketplace_dir in "$cache"/*/; do
    [[ -d "$marketplace_dir" ]] || continue
    local marketplace
    marketplace=$(basename "$marketplace_dir")
    for plugin_dir in "$marketplace_dir"*/; do
      [[ -d "$plugin_dir" ]] || continue
      local plugin
      plugin=$(basename "$plugin_dir")
      # Pick the most recent version directory
      local version_dir
      version_dir=$(ls -td "$plugin_dir"*/ 2>/dev/null | head -n1)
      [[ -n "$version_dir" ]] || continue
      version_dir="${version_dir%/}"

      # Write plugins-available stub
      local stub="$AGENT_SKILLS_DIR/plugins-available/$plugin.yml"
      mkdir -p "$AGENT_SKILLS_DIR/plugins-available"
      cat > "$stub" <<EOF
name: $plugin
marketplace: $marketplace
source: $version_dir
EOF

      "$REGISTRY" add "$plugin" type=plugin source="$version_dir"
      count=$((count + 1))
    done
  done
  echo "  registered $count plugin(s)"
}

discover_global_skills() {
  echo "[bootstrap] scanning ~/.claude/skills..."
  "$REGISTRY" init
  local skills_dir="$HOME/.claude/skills"
  [[ -d "$skills_dir" ]] || { echo "  (no global skills, skipping)"; return; }

  local count=0
  for src in "$skills_dir"/*/; do
    [[ -d "$src" ]] || continue
    local name
    name=$(basename "$src")
    local dest="$AGENT_SKILLS_DIR/skills-available/$name"

    if [[ -e "$dest" ]]; then
      echo "  skip $name (already in pool)"
      "$REGISTRY" add "$name" type=skill source="$dest"
      continue
    fi

    if confirm "  move $name → skills-available/?"; then
      mkdir -p "$AGENT_SKILLS_DIR/skills-available"
      mv "$src" "$dest"
      "$REGISTRY" add "$name" type=skill source="$dest"
      count=$((count + 1))
    fi
  done
  echo "  moved $count skill(s)"
}

discover_global_mcps() {
  echo "[bootstrap] scanning ~/.claude.json..."
  "$REGISTRY" init
  local cfg="$HOME/.claude.json"
  [[ -f "$cfg" ]] || { echo "  (no ~/.claude.json, skipping)"; return; }

  local count
  count=$(jq -r '.mcpServers // {} | keys | length' "$cfg" 2>/dev/null || echo 0)
  [[ "$count" -gt 0 ]] || { echo "  (no MCPs registered)"; return; }

  # Backup first
  cp "$cfg" "$cfg.bak.$(date +%s)"

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    local cmd args
    cmd=$(jq -r ".mcpServers.\"$name\".command" "$cfg")
    args=$(jq -c ".mcpServers.\"$name\".args // []" "$cfg")
    local stub="$AGENT_SKILLS_DIR/mcps-available/$name.yml"
    mkdir -p "$AGENT_SKILLS_DIR/mcps-available"
    cat > "$stub" <<EOF
name: $name
command: $cmd
args: $args
EOF
    "$REGISTRY" add "$name" type=mcp source="$stub"
  done < <(jq -r '.mcpServers // {} | keys[]' "$cfg")

  if confirm "  empty mcpServers in ~/.claude.json (will re-populate per-project)?"; then
    local tmp
    tmp=$(jq '.mcpServers = {}' "$cfg")
    printf '%s\n' "$tmp" > "$cfg"
  fi
  echo "  registered $count MCP(s)"
}

disable_global_plugins() {
  echo "[bootstrap] disabling enabledPlugins in ~/.claude/settings.json..."
  local cfg="$HOME/.claude/settings.json"
  [[ -f "$cfg" ]] || { echo "  (no settings.json, skipping)"; return; }

  cp "$cfg" "$cfg.bak.$(date +%s)"
  if confirm "  set every entry in enabledPlugins to false?"; then
    local tmp
    tmp=$(jq '(.enabledPlugins // {}) as $p | .enabledPlugins = ($p | map_values(false))' "$cfg")
    printf '%s\n' "$tmp" > "$cfg"
    echo "  done."
  fi
}

# Dispatch
case "$ONLY_SECTION" in
  plugins)         discover_plugins ;;
  skills)          discover_global_skills ;;
  mcps)            discover_global_mcps ;;
  plugin-disable)  disable_global_plugins ;;
  "")              discover_plugins; discover_global_skills; discover_global_mcps; disable_global_plugins ;;
esac

echo "[bootstrap] done."
