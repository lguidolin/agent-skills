#!/usr/bin/env bash
# tests/test_plugin_collision.sh — installed plugins own their skill names.
# The pool (skills-available/) must never reuse one, and registry/activation
# must refuse such a name loudly rather than silently shadowing a copy.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/lib/assert.sh"
source "$REPO_ROOT/tests/lib/fixture.sh"

# --- 1. The real repo's pool must not collide with real installed plugins ---
# Guards against re-vendoring a plugin-owned skill into skills-available/.
real_plugin_skills=$("$REPO_ROOT/scripts/plugin-skills.sh" 2>/dev/null || true)
if [[ -n "$real_plugin_skills" ]]; then
  collided=""
  while read -r skill; do
    [[ -z "$skill" ]] && continue
    if [[ -d "$REPO_ROOT/skills-available/$skill" ]]; then
      collided="$collided $skill"
    fi
  done <<<"$real_plugin_skills"
  if [[ -z "$collided" ]]; then
    _pass
  else
    _fail "skills-available/ contains plugin-owned skill name(s):$collided" \
          "installed plugins are the source of truth for these — delete the local copy"
  fi
else
  # No plugins installed in this environment; nothing to collide with.
  _pass
fi

# --- 2. Every profile skill resolves to a real pool entry ---
# A profile naming a skill the pool lacks silently links nothing.
for pf in "$REPO_ROOT"/profiles/*.yml; do
  while read -r skill; do
    [[ -z "$skill" || "$skill" == "null" ]] && continue
    if [[ -d "$REPO_ROOT/skills-available/$skill" ]]; then
      _pass
    else
      _fail "profile $(basename "$pf") lists unknown skill '$skill'" \
            "not present in skills-available/"
    fi
  done < <(yq '.skills[]' "$pf" 2>/dev/null || true)
done

# --- 3. No profile lists a plugin-owned skill name ---
if [[ -n "$real_plugin_skills" ]]; then
  for pf in "$REPO_ROOT"/profiles/*.yml; do
    while read -r skill; do
      [[ -z "$skill" || "$skill" == "null" ]] && continue
      if grep -qxF "$skill" <<<"$real_plugin_skills"; then
        _fail "profile $(basename "$pf") lists plugin-owned skill '$skill'" \
              "list the plugin under 'plugins:' instead"
      else
        _pass
      fi
    done < <(yq '.skills[]' "$pf" 2>/dev/null || true)
  done
fi

# --- 4. registry.sh refuses to register a plugin-owned skill name ---
setup_fixture
trap teardown_fixture EXIT

# Stage a fake installed plugin that ships a skill named "brainstorming"
mkdir -p "$HOME/.claude/plugins/cache/mp/fakepower/1.0.0/skills/brainstorming"
echo "x" > "$HOME/.claude/plugins/cache/mp/fakepower/1.0.0/skills/brainstorming/SKILL.md"

# plugin-skills.sh sees it
out=$("$AGENT_SKILLS_DIR/scripts/plugin-skills.sh")
if grep -qx "brainstorming" <<<"$out"; then _pass; else _fail "plugin-skills.sh missed staged plugin skill" "got: $out"; fi

# registry add must fail loud
mkdir -p "$AGENT_SKILLS_DIR/skills-available/brainstorming"
echo "x" > "$AGENT_SKILLS_DIR/skills-available/brainstorming/SKILL.md"
set +e
err=$("$AGENT_SKILLS_DIR/scripts/registry.sh" add brainstorming type=skill \
        source="$AGENT_SKILLS_DIR/skills-available/brainstorming" 2>&1)
rc=$?
set -e
assert_exit_nonzero "$rc"
if grep -q "fakepower" <<<"$err"; then _pass; else _fail "error should name the owning plugin" "got: $err"; fi

# ...and must not have written the entry
if ! "$AGENT_SKILLS_DIR/scripts/registry.sh" has brainstorming; then _pass; else _fail "collided skill was registered anyway"; fi

# A non-colliding skill still registers fine
mkdir -p "$AGENT_SKILLS_DIR/skills-available/house-rule"
echo "x" > "$AGENT_SKILLS_DIR/skills-available/house-rule/SKILL.md"
set +e
"$AGENT_SKILLS_DIR/scripts/registry.sh" add house-rule type=skill \
  source="$AGENT_SKILLS_DIR/skills-available/house-rule" >/dev/null 2>&1
rc=$?
set -e
assert_exit_zero "$rc"

# The override escape hatch works
set +e
ALLOW_PLUGIN_SKILL_COLLISION=1 "$AGENT_SKILLS_DIR/scripts/registry.sh" add brainstorming type=skill \
  source="$AGENT_SKILLS_DIR/skills-available/brainstorming" >/dev/null 2>&1
rc=$?
set -e
assert_exit_zero "$rc"

# --- 5. profile-activate.sh refuses a profile listing a plugin-owned skill ---
cat > "$AGENT_SKILLS_DIR/profiles/bad.yml" <<'EOF'
name: bad
skills: [brainstorming]
agents: []
mcps: []
plugins: []
claudeignore: []
EOF
PROJ="$TEST_HOME/proj"
mkdir -p "$PROJ"
set +e
err=$("$AGENT_SKILLS_DIR/scripts/profile-activate.sh" bad "$PROJ" 2>&1)
rc=$?
set -e
assert_exit_nonzero "$rc"
if grep -q "fakepower" <<<"$err"; then _pass; else _fail "activation error should name the owning plugin" "got: $err"; fi
assert_file_missing "$PROJ/.github/skills/brainstorming"

report_results
