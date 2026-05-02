# tests/lib/fixture.sh
# Source from each test. Provides setup_fixture / teardown_fixture.

setup_fixture() {
  TEST_HOME=$(mktemp -d -t agent-skills-test.XXXXXX)
  export HOME="$TEST_HOME"
  export AGENT_SKILLS_DIR="$TEST_HOME/agent-skills"
  mkdir -p \
    "$AGENT_SKILLS_DIR/skills-available" \
    "$AGENT_SKILLS_DIR/agents-available" \
    "$AGENT_SKILLS_DIR/mcps-available" \
    "$AGENT_SKILLS_DIR/plugins-available" \
    "$AGENT_SKILLS_DIR/profiles" \
    "$AGENT_SKILLS_DIR/scripts" \
    "$TEST_HOME/.claude/plugins/cache" \
    "$TEST_HOME/.claude/skills"
  # Copy real scripts into the fixture so paths resolve consistently.
  cp -r "$REPO_ROOT/scripts/." "$AGENT_SKILLS_DIR/scripts/"
}

teardown_fixture() {
  if [[ -n "${TEST_HOME:-}" && -d "$TEST_HOME" ]]; then
    rm -rf "$TEST_HOME"
  fi
}

# Convenience: $REPO_ROOT is the actual repo root, set by the test runner.
