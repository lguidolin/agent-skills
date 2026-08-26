#!/usr/bin/env bash
# tests/test_skills.sh — lint the skill pool.
# These are the invariants that make a skill discoverable and correctly
# triggered by Claude Code, so they are worth enforcing on every commit.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/lib/assert.sh"

POOL="$REPO_ROOT/skills"

assert_dir_exists "$POOL"

count=0
for dir in "$POOL"/*/; do
  [[ -d "$dir" ]] || continue
  name=$(basename "$dir")
  skill="$dir/SKILL.md"
  count=$((count + 1))

  # Every skill directory must actually hold a SKILL.md.
  if [[ -f "$skill" ]]; then _pass; else _fail "$name: missing SKILL.md"; continue; fi

  # Frontmatter must open on line 1 and close again, or the loader ignores it.
  if [[ "$(head -1 "$skill")" == "---" ]]; then
    _pass
  else
    _fail "$name: SKILL.md must start with '---' frontmatter"
    continue
  fi
  if [[ "$(sed -n '2,40p' "$skill" | grep -cx -- '---')" -ge 1 ]]; then
    _pass
  else
    _fail "$name: frontmatter is not closed within the first 40 lines"
    continue
  fi

  fm=$(sed -n '2,/^---$/p' "$skill")

  # name: must be present and match the directory, or invocation breaks.
  fm_name=$(grep -m1 '^name:' <<<"$fm" | sed 's/^name:[[:space:]]*//; s/^"//; s/"$//' || true)
  if [[ -n "$fm_name" ]]; then _pass; else _fail "$name: frontmatter has no 'name:'"; fi
  if [[ "$fm_name" == "$name" ]]; then
    _pass
  else
    _fail "$name: frontmatter name '$fm_name' does not match directory" "they must be identical"
  fi

  # description: is the only part always loaded into context — it decides
  # whether the skill triggers at the right moment.
  fm_desc=$(grep -m1 '^description:' <<<"$fm" | sed 's/^description:[[:space:]]*//; s/^"//; s/"$//' || true)
  if [[ -n "$fm_desc" ]]; then _pass; else _fail "$name: frontmatter has no 'description:'"; fi
  if [[ "${#fm_desc}" -ge 40 ]]; then
    _pass
  else
    _fail "$name: description is too short (${#fm_desc} chars)" "state the trigger conditions"
  fi
  if grep -qi "use when\|use this when\|use before\|use during" <<<"$fm_desc"; then
    _pass
  else
    _fail "$name: description should start from trigger conditions ('Use when ...')" "got: $fm_desc"
  fi
done

if [[ "$count" -gt 0 ]]; then _pass; else _fail "skills/ contains no skills"; fi

# No skill may reuse a name shipped by an installed plugin — the plugin owns it.
plugin_skills=$("$REPO_ROOT/scripts/plugin-skills.sh" 2>/dev/null || true)
if [[ -n "$plugin_skills" ]]; then
  collided=""
  while read -r s; do
    [[ -z "$s" ]] && continue
    [[ -d "$POOL/$s" ]] && collided="$collided $s"
  done <<<"$plugin_skills"
  if [[ -z "$collided" ]]; then
    _pass
  else
    _fail "skills/ reuses plugin-owned name(s):$collided" "the installed plugin is the source of truth"
  fi
fi

report_results
