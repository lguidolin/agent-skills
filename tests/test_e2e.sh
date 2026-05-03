#!/usr/bin/env bash
# tests/test_e2e.sh — bootstrap → init → activate → switch → list
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/lib/assert.sh"
source "$REPO_ROOT/tests/lib/fixture.sh"

setup_fixture
trap teardown_fixture EXIT

# --- Stage system state ---
mkdir -p "$HOME/.claude/plugins/cache/mp/superpowers/5.0.0"
mkdir -p "$HOME/.claude/skills/global-skill"
echo "x" > "$HOME/.claude/skills/global-skill/SKILL.md"
cat > "$HOME/.claude.json" <<'EOF'
{"mcpServers":{"browser":{"command":"npx","args":["-y","@anthropic/mcp-browser"]}}}
EOF
mkdir -p "$HOME/.claude"
cat > "$HOME/.claude/settings.json" <<'EOF'
{"enabledPlugins":{"superpowers@mp":true}}
EOF

# --- 1. Bootstrap ---
"$AGENT_SKILLS_DIR/scripts/bootstrap.sh" --yes
assert_dir_exists "$AGENT_SKILLS_DIR/skills-available/global-skill"
assert_file_exists "$AGENT_SKILLS_DIR/mcps-available/browser.yml"
assert_file_exists "$AGENT_SKILLS_DIR/plugins-available/superpowers.yml"

# --- 2. Project init ---
PROJ="$TEST_HOME/proj"
mkdir -p "$PROJ/.github/skills/proj-skill"
echo "x" > "$PROJ/.github/skills/proj-skill/SKILL.md"

# Profile that uses the just-migrated skills + an MCP + plugin
cat > "$AGENT_SKILLS_DIR/profiles/work.yml" <<'EOF'
name: work
skills: [global-skill, proj-skill]
agents: []
mcps: [browser]
plugins: [superpowers]
claudeignore: []
EOF

cd "$PROJ"
"$AGENT_SKILLS_DIR/scripts/claude-init.sh" --profile work --yes

# --- 3. Verify activation results ---
assert_symlink "$PROJ/.github/skills/global-skill"
assert_symlink "$PROJ/.github/skills/proj-skill"
v=$(jq -r '.mcpServers.browser.command' "$PROJ/.mcp.json")
[[ "$v" == "npx" ]] && _pass || _fail "browser MCP not in .mcp.json: $v"
v=$(jq -r '.enabledPlugins.superpowers' "$PROJ/.claude/settings.json")
[[ "$v" == "true" ]] && _pass || _fail "superpowers plugin not enabled: $v"

# --- 4. Switch profile ---
cat > "$AGENT_SKILLS_DIR/profiles/quiet.yml" <<'EOF'
name: quiet
skills: []
agents: []
mcps: []
plugins: []
claudeignore: []
EOF
"$AGENT_SKILLS_DIR/scripts/profile-activate.sh" quiet "$PROJ"
assert_file_missing "$PROJ/.github/skills/global-skill"
assert_file_missing "$PROJ/.github/skills/proj-skill"
v=$(jq -r '.mcpServers | length' "$PROJ/.mcp.json")
[[ "$v" == "0" ]] && _pass || _fail "mcpServers should be empty after switch: $v"
v=$(jq -r '.enabledPlugins.superpowers' "$PROJ/.claude/settings.json")
[[ "$v" == "false" ]] && _pass || _fail "superpowers should be false after switch: $v"

# --- 5. Inventory shows correct state ---
out=$("$AGENT_SKILLS_DIR/scripts/tool-list.sh")
echo "$out" | grep -F 'global-skill' | grep -Fq '○' && _pass || _fail "global-skill should be inactive after switch"
echo "$out" | grep -F 'proj-skill'   | grep -Fq '○' && _pass || _fail "proj-skill should be inactive after switch"

report_results
