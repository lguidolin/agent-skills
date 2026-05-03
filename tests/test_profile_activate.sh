#!/usr/bin/env bash
# tests/test_profile_activate.sh
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/lib/assert.sh"
source "$REPO_ROOT/tests/lib/fixture.sh"

setup_fixture
trap teardown_fixture EXIT

# --- Pool setup ---
mkdir -p "$AGENT_SKILLS_DIR/skills-available/skill-a/{,sub}"
echo "x" > "$AGENT_SKILLS_DIR/skills-available/skill-a/SKILL.md"
mkdir -p "$AGENT_SKILLS_DIR/agents-available/agent-x"
echo "x" > "$AGENT_SKILLS_DIR/agents-available/agent-x/AGENT.md"
mkdir -p "$AGENT_SKILLS_DIR/mcps-available"
cat > "$AGENT_SKILLS_DIR/mcps-available/browser.yml" <<'EOF'
name: browser
command: npx
args: ["-y", "@anthropic/mcp-browser"]
EOF

# Registry
"$AGENT_SKILLS_DIR/scripts/registry.sh" add skill-a type=skill source="$AGENT_SKILLS_DIR/skills-available/skill-a"
"$AGENT_SKILLS_DIR/scripts/registry.sh" add agent-x type=agent source="$AGENT_SKILLS_DIR/agents-available/agent-x"
"$AGENT_SKILLS_DIR/scripts/registry.sh" add browser type=mcp source="$AGENT_SKILLS_DIR/mcps-available/browser.yml"
"$AGENT_SKILLS_DIR/scripts/registry.sh" add superpowers type=plugin source=/fake/path

# Profile
cat > "$AGENT_SKILLS_DIR/profiles/test.yml" <<'EOF'
name: test
skills: [skill-a]
agents: [agent-x]
mcps: [browser]
plugins: [superpowers]
claudeignore: []
EOF

# --- Project ---
PROJ="$TEST_HOME/proj"
mkdir -p "$PROJ"
cd "$PROJ"

"$AGENT_SKILLS_DIR/scripts/profile-activate.sh" test "$PROJ"

# --- Assertions ---
# Skills symlinked
assert_symlink "$PROJ/.github/skills/skill-a"
assert_symlink_target "$PROJ/.github/skills/skill-a" "$AGENT_SKILLS_DIR/skills-available/skill-a"

# Agents symlinked
assert_symlink "$PROJ/.claude/agents/agent-x"
assert_symlink_target "$PROJ/.claude/agents/agent-x" "$AGENT_SKILLS_DIR/agents-available/agent-x"

# MCPs written to .mcp.json
assert_file_exists "$PROJ/.mcp.json"
v=$(jq -r '.mcpServers.browser.command' "$PROJ/.mcp.json")
[[ "$v" == "npx" ]] && _pass || _fail "browser.command in .mcp.json: $v"

# Plugins toggled in .claude/settings.json
assert_file_exists "$PROJ/.claude/settings.json"
v=$(jq -r '.enabledPlugins."superpowers"' "$PROJ/.claude/settings.json")
[[ "$v" == "true" ]] && _pass || _fail "superpowers should be true: $v"

# Registry active_in updated
assert_yaml_eq "$AGENT_SKILLS_DIR/registry.yml" '.assets."skill-a".active_in | length' '1'
v=$(yq '.assets."skill-a".active_in[0]' "$AGENT_SKILLS_DIR/registry.yml")
[[ "$v" == "$PROJ" ]] && _pass || _fail "skill-a active_in[0]: $v"

# Lock file written with profile name
assert_file_exists "$PROJ/.claude-profile.lock"
v=$(sed -n '2p' "$PROJ/.claude-profile.lock")
[[ "$v" == "test" ]] && _pass || _fail "lock profile name: $v"

# --- Tear down safety: a real (non-symlink) file in .github/skills must NOT be deleted ---
echo "real" > "$PROJ/.github/skills/REAL-FILE.md"
"$AGENT_SKILLS_DIR/scripts/profile-activate.sh" test "$PROJ"
assert_file_exists "$PROJ/.github/skills/REAL-FILE.md"

# --- Profile switch: switching to a different profile clears symlinks ---
cat > "$AGENT_SKILLS_DIR/profiles/other.yml" <<'EOF'
name: other
skills: []
agents: []
mcps: []
plugins: []
claudeignore: []
EOF
"$AGENT_SKILLS_DIR/scripts/profile-activate.sh" other "$PROJ"
assert_file_missing "$PROJ/.github/skills/skill-a"
assert_file_missing "$PROJ/.claude/agents/agent-x"
# Registry active_in cleared
assert_yaml_eq "$AGENT_SKILLS_DIR/registry.yml" '.assets."skill-a".active_in | length' '0'
# .mcp.json should now have empty mcpServers
v=$(jq -r '.mcpServers | length' "$PROJ/.mcp.json")
[[ "$v" == "0" ]] && _pass || _fail "mcpServers should be empty: $v"

report_results
