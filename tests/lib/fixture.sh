# tests/lib/fixture.sh
# Source from each test. Provides setup_fixture / teardown_fixture.
#
# Gives the test an isolated HOME so an install can be exercised without
# touching the developer's real ~/.claude/skills.

setup_fixture() {
  : "${REPO_ROOT:?setup_fixture requires REPO_ROOT to be set}"
  TEST_HOME=$(mktemp -d -t agent-skills-test.XXXXXX)
  export TEST_HOME
  export HOME="$TEST_HOME"
  mkdir -p "$TEST_HOME/.claude/plugins/cache"
}

teardown_fixture() {
  if [[ -n "${TEST_HOME:-}" && -d "$TEST_HOME" ]]; then
    rm -rf "$TEST_HOME"
  fi
}
