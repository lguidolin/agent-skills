#!/usr/bin/env bash
# tests/test_registry.sh
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/lib/assert.sh"
source "$REPO_ROOT/tests/lib/fixture.sh"

setup_fixture
trap teardown_fixture EXIT

REG="$AGENT_SKILLS_DIR/registry.yml"
LIB="$AGENT_SKILLS_DIR/scripts/registry.sh"

# 1. init: empty file with version
"$LIB" init
assert_file_exists "$REG"
assert_yaml_eq "$REG" '.version' '1'

# 2. add: skill entry
"$LIB" add foo type=skill source=/tmp/foo
assert_yaml_eq "$REG" '.assets.foo.type' 'skill'
assert_yaml_eq "$REG" '.assets.foo.source' '/tmp/foo'
assert_yaml_eq "$REG" '.assets.foo.profiles | length' '0'
assert_yaml_eq "$REG" '.assets.foo.active_in | length' '0'

# 3. has: returns 0 when present, 1 when missing
set +e; "$LIB" has foo; rc1=$?; set -e
set +e; "$LIB" has bar; rc2=$?; set -e
assert_exit_zero "$rc1"
assert_exit_nonzero "$rc2"

# 4. add is idempotent: re-adding same entry doesn't duplicate or fail
"$LIB" add foo type=skill source=/tmp/foo
assert_yaml_eq "$REG" '.assets.foo.source' '/tmp/foo'

# 5. set-profiles: replace profile list
"$LIB" set-profiles foo brainstorm code
assert_yaml_eq "$REG" '.assets.foo.profiles | join(",")' 'brainstorm,code'

# 6. add-active / remove-active: track per-project activation
"$LIB" add-active foo /work/proj-a
"$LIB" add-active foo /work/proj-b
assert_yaml_eq "$REG" '.assets.foo.active_in | length' '2'
"$LIB" remove-active foo /work/proj-a
assert_yaml_eq "$REG" '.assets.foo.active_in | join(",")' '/work/proj-b'

# 7. list: emits "<name>\t<type>" lines
out=$("$LIB" list)
echo "$out" | grep -q $'^foo\tskill$' && _pass || _fail "list missing foo: '$out'"

# 8. get: prints a yaml subtree for one asset
out=$("$LIB" get foo)
echo "$out" | grep -q 'type: skill' && _pass || _fail "get returned: '$out'"

# 8b. get on missing asset returns non-zero, no stdout
set +e; out=$("$LIB" get nonexistent 2>/dev/null); rc=$?; set -e
assert_exit_nonzero "$rc"
[[ -z "$out" ]] && _pass || _fail "get nonexistent printed: '$out'"

# 9. add with origin= sets the origin field
"$LIB" add bar type=mcp source=/tmp/bar origin=project-a
assert_yaml_eq "$REG" '.assets.bar.origin' 'project-a'

# 10. add-active deduplicates
"$LIB" add-active foo /work/proj-b   # already there from earlier
assert_yaml_eq "$REG" '.assets.foo.active_in | length' '1'

report_results
