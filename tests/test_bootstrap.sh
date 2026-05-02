#!/usr/bin/env bash
# tests/test_bootstrap.sh
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/lib/assert.sh"
source "$REPO_ROOT/tests/lib/fixture.sh"

setup_fixture
trap teardown_fixture EXIT

REG="$AGENT_SKILLS_DIR/registry.yml"

# --- Plugin discovery setup ---
mkdir -p "$HOME/.claude/plugins/cache/marketplace-x/plugin-alpha/1.0.0"
mkdir -p "$HOME/.claude/plugins/cache/marketplace-x/plugin-beta/2.1.0"
echo '{"name":"plugin-alpha"}' > "$HOME/.claude/plugins/cache/marketplace-x/plugin-alpha/1.0.0/plugin.json"
echo '{"name":"plugin-beta"}'  > "$HOME/.claude/plugins/cache/marketplace-x/plugin-beta/2.1.0/plugin.json"

# --- Run plugin-discovery sub-command ---
"$AGENT_SKILLS_DIR/scripts/bootstrap.sh" --plugins-only --yes

# --- Assertions ---
assert_file_exists "$AGENT_SKILLS_DIR/plugins-available/plugin-alpha.yml"
assert_file_exists "$AGENT_SKILLS_DIR/plugins-available/plugin-beta.yml"
assert_yaml_eq "$AGENT_SKILLS_DIR/plugins-available/plugin-alpha.yml" '.name' 'plugin-alpha'
assert_yaml_eq "$AGENT_SKILLS_DIR/plugins-available/plugin-alpha.yml" '.marketplace' 'marketplace-x'

assert_file_exists "$REG"
assert_yaml_eq "$REG" '.assets."plugin-alpha".type' 'plugin'
assert_yaml_eq "$REG" '.assets."plugin-alpha".source' "$HOME/.claude/plugins/cache/marketplace-x/plugin-alpha/1.0.0"

# --- Idempotency: run again, expect same state ---
"$AGENT_SKILLS_DIR/scripts/bootstrap.sh" --plugins-only --yes
assert_yaml_eq "$REG" '.assets | length' '2'

# --- Global skill migration ---
mkdir -p "$HOME/.claude/skills/find-skills"
echo "skill body" > "$HOME/.claude/skills/find-skills/SKILL.md"

"$AGENT_SKILLS_DIR/scripts/bootstrap.sh" --skills-only --yes

assert_dir_exists "$AGENT_SKILLS_DIR/skills-available/find-skills"
assert_file_exists "$AGENT_SKILLS_DIR/skills-available/find-skills/SKILL.md"
assert_file_missing "$HOME/.claude/skills/find-skills/SKILL.md"
assert_yaml_eq "$REG" '.assets."find-skills".type' 'skill'

# Idempotent: re-run, no duplicate move, no error
"$AGENT_SKILLS_DIR/scripts/bootstrap.sh" --skills-only --yes
assert_dir_exists "$AGENT_SKILLS_DIR/skills-available/find-skills"

# --- MCP discovery ---
cat > "$HOME/.claude.json" <<'EOF'
{
  "mcpServers": {
    "browser": {"command": "npx", "args": ["-y", "@anthropic/mcp-browser"]},
    "pencil":  {"command": "npx", "args": ["-y", "pencil-mcp"]}
  }
}
EOF

"$AGENT_SKILLS_DIR/scripts/bootstrap.sh" --mcps-only --yes

assert_file_exists "$AGENT_SKILLS_DIR/mcps-available/browser.yml"
assert_file_exists "$AGENT_SKILLS_DIR/mcps-available/pencil.yml"
assert_yaml_eq "$AGENT_SKILLS_DIR/mcps-available/browser.yml" '.command' 'npx'
assert_yaml_eq "$REG" '.assets.browser.type' 'mcp'
# mcpServers should be empty after bootstrap
empty=$(jq -r '.mcpServers | length' "$HOME/.claude.json")
[[ "$empty" == "0" ]] && _pass || _fail "mcpServers not emptied: $empty"

# --- Disable plugins in global settings ---
cat > "$HOME/.claude/settings.json" <<'EOF'
{
  "enabledPlugins": {
    "alpha@mp": true,
    "beta@mp": true,
    "gamma@mp": false
  }
}
EOF

"$AGENT_SKILLS_DIR/scripts/bootstrap.sh" --plugin-disable-only --yes

# All should now be false
for plug in 'alpha@mp' 'beta@mp' 'gamma@mp'; do
  v=$(jq -r ".enabledPlugins.\"$plug\"" "$HOME/.claude/settings.json")
  [[ "$v" == "false" ]] && _pass || _fail "$plug not disabled: $v"
done
# Backup file exists
ls "$HOME/.claude/settings.json.bak."* >/dev/null 2>&1 && _pass || _fail "no backup written"

report_results
