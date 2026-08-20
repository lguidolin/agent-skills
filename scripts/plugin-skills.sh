#!/usr/bin/env bash
# scripts/plugin-skills.sh — list skill names shipped by installed plugins.
#
# Installed plugins are the source of truth for the skills they ship. A local
# skill in skills/ that reuses one of these names would shadow (or be
# shadowed by) the plugin copy depending on symlink order, so the registry and
# profile activation refuse such names and use this script to detect them.
#
# Usage:
#   plugin-skills.sh                 # every plugin-owned skill name, one per line
#   plugin-skills.sh --with-plugin   # "<plugin>\t<skill>" pairs
#   plugin-skills.sh <plugin_name>   # only that plugin's skill names
#
# Layout scanned: $CLAUDE_PLUGIN_CACHE/<marketplace>/<plugin>/<version>/skills/<name>/SKILL.md
# All installed versions are unioned — a name owned by any version counts.
set -euo pipefail

WITH_PLUGIN=0
WANT=""
for arg in "$@"; do
  case "$arg" in
    --with-plugin) WITH_PLUGIN=1 ;;
    -*) echo "plugin-skills.sh: unknown flag $arg" >&2; exit 1 ;;
    *) WANT="$arg" ;;
  esac
done

cache="${CLAUDE_PLUGIN_CACHE:-$HOME/.claude/plugins/cache}"
[[ -d "$cache" ]] || exit 0

for marketplace_dir in "$cache"/*/; do
  [[ -d "$marketplace_dir" ]] || continue
  for plugin_dir in "$marketplace_dir"*/; do
    [[ -d "$plugin_dir" ]] || continue
    plugin=$(basename "$plugin_dir")
    [[ -n "$WANT" && "$plugin" != "$WANT" ]] && continue
    for version_dir in "$plugin_dir"*/; do
      [[ -d "$version_dir/skills" ]] || continue
      for skill_dir in "$version_dir"skills/*/; do
        [[ -f "$skill_dir/SKILL.md" ]] || continue
        skill=$(basename "$skill_dir")
        if [[ "$WITH_PLUGIN" -eq 1 ]]; then
          printf '%s\t%s\n' "$plugin" "$skill"
        else
          printf '%s\n' "$skill"
        fi
      done
    done
  done
done | sort -u
