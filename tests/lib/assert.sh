# tests/lib/assert.sh
# Source from each test. Exits non-zero on failure with a clear message.

ASSERT_FAILS=0
ASSERT_PASSES=0

_fail() {
  printf '\033[31mFAIL\033[0m: %s\n' "$1" >&2
  if [[ -n "${2:-}" ]]; then
    printf '       %s\n' "$2" >&2
  fi
  ASSERT_FAILS=$((ASSERT_FAILS + 1))
}

_pass() {
  ASSERT_PASSES=$((ASSERT_PASSES + 1))
}

assert_file_exists() {
  if [[ -f "$1" ]]; then _pass; else _fail "expected file: $1"; fi
}

assert_file_missing() {
  if [[ ! -e "$1" ]]; then _pass; else _fail "expected file to be missing: $1"; fi
}

assert_dir_exists() {
  if [[ -d "$1" ]]; then _pass; else _fail "expected directory: $1"; fi
}

assert_symlink() {
  if [[ -L "$1" ]]; then _pass; else _fail "expected symlink: $1"; fi
}

assert_symlink_target() {
  local link="$1" expected="$2"
  if [[ ! -L "$link" ]]; then
    _fail "not a symlink: $link"
    return
  fi
  local actual
  actual=$(readlink "$link")
  if [[ "$actual" == "$expected" ]]; then
    _pass
  else
    _fail "symlink $link → $actual" "expected: $expected"
  fi
}

assert_file_contains() {
  local file="$1" needle="$2"
  if grep -qF -- "$needle" "$file"; then _pass; else _fail "$file does not contain: $needle"; fi
}

assert_yaml_eq() {
  # assert_yaml_eq <file> <yq-path> <expected>
  local file="$1" path="$2" expected="$3"
  local actual
  actual=$(yq "$path" "$file" 2>/dev/null || echo "<error>")
  if [[ "$actual" == "$expected" ]]; then
    _pass
  else
    _fail "yq '$path' on $file = '$actual'" "expected: '$expected'"
  fi
}

assert_exit_zero() {
  if [[ "$1" == "0" ]]; then _pass; else _fail "expected exit 0, got $1"; fi
}

assert_exit_nonzero() {
  if [[ "$1" != "0" ]]; then _pass; else _fail "expected nonzero exit, got 0"; fi
}

report_results() {
  printf '\n%d passed, %d failed\n' "$ASSERT_PASSES" "$ASSERT_FAILS"
  if [[ "$ASSERT_FAILS" -gt 0 ]]; then exit 1; fi
}
