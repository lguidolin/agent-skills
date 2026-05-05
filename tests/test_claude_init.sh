#!/usr/bin/env bash
# tests/test_claude_init.sh
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/lib/assert.sh"
source "$REPO_ROOT/tests/lib/fixture.sh"

setup_fixture
trap teardown_fixture EXIT

# Pre-populate registry so plugin-toggle won't choke
"$AGENT_SKILLS_DIR/scripts/registry.sh" init

PROJ="$TEST_HOME/proj"
mkdir -p "$PROJ/.github/skills/local-skill"
echo "x" > "$PROJ/.github/skills/local-skill/SKILL.md"
mkdir -p "$PROJ/.claude/agents/local-agent"
echo "x" > "$PROJ/.claude/agents/local-agent/AGENT.md"
cat > "$PROJ/.mcp.json" <<'EOF'
{"mcpServers": {"local-mcp": {"command": "echo", "args": ["hi"]}}}
EOF
cat > "$PROJ/.claude/settings.json" <<'EOF'
{"enabledPlugins": {"local-plugin@mp": true}}
EOF

# Minimal profile so post-init activation has something to do
cat > "$AGENT_SKILLS_DIR/profiles/minimal.yml" <<'EOF'
name: minimal
skills: []
agents: []
mcps: []
plugins: []
claudeignore: []
EOF

cd "$PROJ"
# Run init non-interactively (--profile minimal --yes skip prompts)
"$AGENT_SKILLS_DIR/scripts/claude-init.sh" --profile minimal --yes

# Skills migrated
assert_dir_exists "$AGENT_SKILLS_DIR/skills-available/local-skill"
assert_file_exists "$AGENT_SKILLS_DIR/skills-available/local-skill/SKILL.md"

# Agents migrated
assert_dir_exists "$AGENT_SKILLS_DIR/agents-available/local-agent"

# MCPs migrated to YAML stub
assert_file_exists "$AGENT_SKILLS_DIR/mcps-available/local-mcp.yml"
assert_yaml_eq "$AGENT_SKILLS_DIR/mcps-available/local-mcp.yml" '.command' 'echo'

# Plugin registered (source = current global path placeholder)
if [[ -f "$AGENT_SKILLS_DIR/plugins-available/local-plugin@mp.yml" ]]; then
  _pass
else
  assert_file_exists "$AGENT_SKILLS_DIR/plugins-available/local-plugin.yml"
fi

# Registry has entries with origin tag
REG="$AGENT_SKILLS_DIR/registry.yml"
assert_yaml_eq "$REG" '.assets."local-skill".origin' "$(basename "$PROJ")"
assert_yaml_eq "$REG" '.assets."local-agent".origin' "$(basename "$PROJ")"

# managed-projects.yml has the project
MGD="$AGENT_SKILLS_DIR/managed-projects.yml"
assert_file_exists "$MGD"
v=$(yq '.projects[]' "$MGD" | grep -c "^$PROJ\$")
[[ "$v" == "1" ]] && _pass || _fail "project not in managed-projects: $v"

# Idempotency: re-running shouldn't error or duplicate
"$AGENT_SKILLS_DIR/scripts/claude-init.sh" --profile minimal --yes
v=$(yq '.projects | length' "$MGD")
[[ "$v" == "1" ]] && _pass || _fail "managed-projects duplicated: $v"

report_results
