#!/usr/bin/env bash
# scripts/registry.sh — CRUD operations on registry.yml (Mike Farah yq v4)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="${AGENT_SKILLS_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
REG="$AGENT_SKILLS_DIR/registry.yml"

require_yq() {
  command -v yq >/dev/null || { echo "registry.sh: 'yq' is required" >&2; exit 1; }
}
require_yq

# An installed plugin owns the skills it ships. Registering a local skill under
# the same name would shadow one copy with the other depending on symlink order,
# so refuse it loudly here rather than let activation silently pick a winner.
# Set ALLOW_PLUGIN_SKILL_COLLISION=1 to override (e.g. while migrating a name).
reject_plugin_skill_collision() {
  local name="$1"
  [[ "${ALLOW_PLUGIN_SKILL_COLLISION:-0}" == "1" ]] && return 0
  local lister="$SCRIPT_DIR/plugin-skills.sh"
  [[ -x "$lister" ]] || return 0
  local owner
  owner=$("$lister" --with-plugin 2>/dev/null | awk -F'\t' -v s="$name" '$2 == s { print $1; exit }') || true
  [[ -n "$owner" ]] || return 0
  echo "registry.sh: refusing to register skill '$name'." >&2
  echo "  The installed plugin '$owner' already ships a skill with this name," >&2
  echo "  and the plugin is the source of truth for its own skills." >&2
  echo "  Fix: remove skills-available/$name, or rename it so it is additive." >&2
  echo "  Override (not recommended): ALLOW_PLUGIN_SKILL_COLLISION=1" >&2
  exit 1
}

ensure_init() {
  if [[ ! -f "$REG" ]]; then
    printf 'version: 1\nassets: {}\n' > "$REG"
  fi
}

cmd_init() {
  ensure_init
}

cmd_add() {
  ensure_init
  local name="$1"; shift
  local type="" source="" origin=""
  for kv in "$@"; do
    case "$kv" in
      type=*)   type="${kv#type=}" ;;
      source=*) source="${kv#source=}" ;;
      origin=*) origin="${kv#origin=}" ;;
      *) echo "registry.sh: unknown key in '$kv'" >&2; exit 1 ;;
    esac
  done
  [[ -n "$type" && -n "$source" ]] || { echo "registry.sh: add requires type= and source=" >&2; exit 1; }
  if [[ "$type" == "skill" ]]; then
    reject_plugin_skill_collision "$name"
  fi
  if [[ "$name" == *,* ]]; then
    echo "registry.sh: tool name '$name' contains ',' — not allowed (CSV delimiter)" >&2
    exit 1
  fi
  ( export name type source origin
    yq -i '
      .assets[strenv(name)].type = strenv(type)
      | .assets[strenv(name)].source = strenv(source)
      | .assets[strenv(name)].profiles = (.assets[strenv(name)].profiles // [])
      | .assets[strenv(name)].active_in = (.assets[strenv(name)].active_in // [])
    ' "$REG"
  )
  if [[ -n "$origin" ]]; then
    ( export name origin
      yq -i '.assets[strenv(name)].origin = strenv(origin)' "$REG"
    )
  fi
}

cmd_has() {
  ensure_init
  local name="$1"
  local present
  present=$(name="$name" yq '.assets | has(strenv(name))' "$REG" 2>/dev/null || echo "false")
  [[ "$present" == "true" ]]
}

cmd_get() {
  ensure_init
  local name="$1"
  if ! cmd_has "$name"; then
    echo "registry.sh: '$name' not found" >&2
    return 1
  fi
  name="$name" yq '.assets[strenv(name)]' "$REG"
}

cmd_list() {
  yq '.assets | to_entries | .[] | .key + "\t" + .value.type' "$REG"
}

cmd_set_profiles() {
  ensure_init
  local name="$1"; shift
  for p in "$@"; do
    if [[ "$p" == *,* ]]; then
      echo "registry.sh: profile name '$p' contains ',' — not allowed (CSV delimiter)" >&2
      exit 1
    fi
  done
  # Build a JSON array of strings using jq for safe quoting.
  local json
  if [[ $# -eq 0 ]]; then
    json='[]'
  else
    json=$(printf '%s\n' "$@" | jq -R . | jq -s .)
  fi
  ( export name profiles_json="$json"
    yq -i '.assets[strenv(name)].profiles = (strenv(profiles_json) | from_json)' "$REG"
  )
}

cmd_add_active() {
  ensure_init
  local name="$1" project="$2"
  if [[ "$project" == *,* ]]; then
    echo "registry.sh: project path '$project' contains ',' — not allowed (CSV delimiter)" >&2
    exit 1
  fi
  ( export name project
    yq -i '.assets[strenv(name)].active_in = ((.assets[strenv(name)].active_in // []) + [strenv(project)] | unique)' "$REG"
  )
}

cmd_remove_active() {
  ensure_init
  local name="$1" project="$2"
  if [[ "$project" == *,* ]]; then
    echo "registry.sh: project path '$project' contains ',' — not allowed (CSV delimiter)" >&2
    exit 1
  fi
  ( export name project
    yq -i '.assets[strenv(name)].active_in = ((.assets[strenv(name)].active_in // []) | map(select(. != strenv(project))))' "$REG"
  )
}

usage() {
  echo "Usage: $(basename "$0") {init|add|has|get|list|set-profiles|add-active|remove-active} [args...]" >&2
  exit 1
}

case "${1:-}" in
  init)           shift; cmd_init "$@" ;;
  add)            shift; cmd_add "$@" ;;
  has)            shift; cmd_has "$@" ;;
  get)            shift; cmd_get "$@" ;;
  list)           shift; cmd_list "$@" ;;
  set-profiles)   shift; cmd_set_profiles "$@" ;;
  add-active)     shift; cmd_add_active "$@" ;;
  remove-active)  shift; cmd_remove_active "$@" ;;
  *) usage ;;
esac
