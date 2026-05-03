#!/usr/bin/env bash
# scripts/claude-init.sh — per-project init: migrate project-local tools into the central pool
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="${AGENT_SKILLS_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
REGISTRY="$SCRIPT_DIR/registry.sh"

PROJECT_DIR="$(pwd)"
PROFILE=""
ASSUME_YES=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --yes|-y)  ASSUME_YES=1; shift ;;
    *) echo "claude-init: unknown flag $1" >&2; exit 1 ;;
  esac
done

confirm() { [[ "$ASSUME_YES" -eq 1 ]] || { read -rp "$1 [Y/n] " a; [[ "${a:-Y}" =~ ^[Yy]?$ ]]; }; }

"$REGISTRY" init

# 1. Migrate skills
if [[ -d "$PROJECT_DIR/.github/skills" ]]; then
  for src in "$PROJECT_DIR/.github/skills"/*/; do
    [[ -d "$src" ]] || continue
    [[ -L "${src%/}" ]] && continue   # already a symlink — nothing to migrate
    name=$(basename "$src")
    dest="$AGENT_SKILLS_DIR/skills-available/$name"
    if [[ -e "$dest" ]]; then
      echo "  skip skill $name (already in pool)"; continue
    fi
    if confirm "  migrate skill $name → pool?"; then
      mkdir -p "$AGENT_SKILLS_DIR/skills-available"
      mv "$src" "$dest"
      "$REGISTRY" add "$name" type=skill source="$dest" origin="$(basename "$PROJECT_DIR")"
    fi
  done
fi

# 2. Migrate agents
if [[ -d "$PROJECT_DIR/.claude/agents" ]]; then
  for src in "$PROJECT_DIR/.claude/agents"/*/; do
    [[ -d "$src" ]] || continue
    [[ -L "${src%/}" ]] && continue
    name=$(basename "$src")
    dest="$AGENT_SKILLS_DIR/agents-available/$name"
    if [[ -e "$dest" ]]; then
      echo "  skip agent $name (already in pool)"; continue
    fi
    if confirm "  migrate agent $name → pool?"; then
      mkdir -p "$AGENT_SKILLS_DIR/agents-available"
      mv "$src" "$dest"
      "$REGISTRY" add "$name" type=agent source="$dest" origin="$(basename "$PROJECT_DIR")"
    fi
  done
fi

# 3. Migrate MCPs from .mcp.json → mcps-available stubs
if [[ -f "$PROJECT_DIR/.mcp.json" ]]; then
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    yml="$AGENT_SKILLS_DIR/mcps-available/$name.yml"
    if [[ -e "$yml" ]]; then
      echo "  skip mcp $name (already in pool)"; continue
    fi
    if confirm "  migrate mcp $name → pool?"; then
      mkdir -p "$AGENT_SKILLS_DIR/mcps-available"
      cmd=$(jq -r ".mcpServers.\"$name\".command" "$PROJECT_DIR/.mcp.json")
      args=$(jq -c ".mcpServers.\"$name\".args // []" "$PROJECT_DIR/.mcp.json")
      tmp=$(mktemp)
      ( export n="$name" cmd="$cmd" args_json="$args"
        yq -n '
          .name = strenv(n)
          | .command = strenv(cmd)
          | .args = (strenv(args_json) | from_json)
        ' > "$tmp"
      )
      mv "$tmp" "$yml"
      "$REGISTRY" add "$name" type=mcp source="$yml" origin="$(basename "$PROJECT_DIR")"
    fi
  done < <(jq -r '.mcpServers // {} | keys[]' "$PROJECT_DIR/.mcp.json")
fi

# 4. Register plugins from project's .claude/settings.json (don't move; Claude owns the cache)
if [[ -f "$PROJECT_DIR/.claude/settings.json" ]]; then
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    plugin="${entry%@*}"   # strip "@marketplace" suffix for asset name
    yml="$AGENT_SKILLS_DIR/plugins-available/$plugin.yml"
    [[ -e "$yml" ]] && continue
    mkdir -p "$AGENT_SKILLS_DIR/plugins-available"
    tmp=$(mktemp)
    ( export n="$plugin" full="$entry" src="$HOME/.claude/plugins/cache"
      yq -n '
        .name = strenv(n)
        | .fullname = strenv(full)
        | .source = strenv(src)
      ' > "$tmp"
    )
    mv "$tmp" "$yml"
    "$REGISTRY" add "$plugin" type=plugin source="$HOME/.claude/plugins/cache" origin="$(basename "$PROJECT_DIR")"
  done < <(jq -r '.enabledPlugins // {} | to_entries | map(select(.value == true)) | .[] | .key' "$PROJECT_DIR/.claude/settings.json" 2>/dev/null || true)
fi

# 5. managed-projects.yml
MGD="$AGENT_SKILLS_DIR/managed-projects.yml"
if [[ ! -f "$MGD" ]]; then
  printf 'projects: []\n' > "$MGD"
fi
( export proj="$PROJECT_DIR"
  yq -i '.projects = ((.projects // []) + [strenv(proj)] | unique)' "$MGD"
)

# 6. Activate the chosen profile (default: minimal)
if [[ -z "$PROFILE" ]]; then
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    PROFILE="minimal"
  else
    echo ""
    echo "Choose a starting profile:"
    ls "$AGENT_SKILLS_DIR/profiles/" | sed 's/.yml$//' | sed 's/^/  /'
    read -rp "Profile: " PROFILE
    PROFILE="${PROFILE:-minimal}"
  fi
fi
"$SCRIPT_DIR/profile-activate.sh" "$PROFILE" "$PROJECT_DIR"

echo ""
echo "✓ claude-init complete"
