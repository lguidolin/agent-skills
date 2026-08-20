#!/usr/bin/env bash
# tests/test_install.sh — install.sh deploys the pool the way Claude Code reads it.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/lib/assert.sh"
source "$REPO_ROOT/tests/lib/fixture.sh"

setup_fixture
trap teardown_fixture EXIT

INSTALL="$REPO_ROOT/scripts/install.sh"
pool_count=$(find "$REPO_ROOT/skills" -maxdepth 2 -name SKILL.md | wc -l)

# --- Global install: symlinks into ~/.claude/skills ---
"$INSTALL" --global >/dev/null
assert_dir_exists "$HOME/.claude/skills"
n=$(find "$HOME/.claude/skills" -maxdepth 1 -type l | wc -l)
if [[ "$n" -eq "$pool_count" ]]; then _pass; else _fail "global install linked $n, expected $pool_count"; fi

# Links must resolve — a broken link is a silently missing skill.
broken=$(find "$HOME/.claude/skills" -maxdepth 1 -xtype l | wc -l)
if [[ "$broken" -eq 0 ]]; then _pass; else _fail "$broken broken symlink(s) after global install"; fi

# Re-running must be idempotent, not accumulate or fail.
"$INSTALL" --global >/dev/null
n2=$(find "$HOME/.claude/skills" -maxdepth 1 -type l | wc -l)
if [[ "$n2" -eq "$pool_count" ]]; then _pass; else _fail "second global install changed count to $n2"; fi

# A stale real directory from an older install must be replaced by a symlink,
# otherwise that skill silently stops tracking the repo.
rm -rf "$HOME/.claude/skills/ship-it"
mkdir -p "$HOME/.claude/skills/ship-it"
echo "stale" > "$HOME/.claude/skills/ship-it/SKILL.md"
"$INSTALL" --global >/dev/null
assert_symlink "$HOME/.claude/skills/ship-it"

# --- Project install: copies into <DIR>/.claude/skills ---
PROJ="$TEST_HOME/proj"; mkdir -p "$PROJ"
"$INSTALL" --project "$PROJ" >/dev/null
assert_dir_exists "$PROJ/.claude/skills"
assert_file_exists "$PROJ/.claude/skills/engineering-constitution/SKILL.md"
# Copies, not symlinks — they get committed and shared.
if [[ ! -L "$PROJ/.claude/skills/engineering-constitution" ]]; then _pass; else _fail "project install should copy, not symlink"; fi
# Stack-specific skills are held back by default.
assert_file_missing "$PROJ/.claude/skills/cloud-delivery-aks"

# --all includes them.
PROJ2="$TEST_HOME/proj2"; mkdir -p "$PROJ2"
"$INSTALL" --project "$PROJ2" --all >/dev/null
assert_file_exists "$PROJ2/.claude/skills/cloud-delivery-aks/SKILL.md"

# --- Refuses a name an installed plugin already owns ---
mkdir -p "$HOME/.claude/plugins/cache/mp/fakepower/1.0.0/skills/ship-it"
echo "x" > "$HOME/.claude/plugins/cache/mp/fakepower/1.0.0/skills/ship-it/SKILL.md"
set +e
err=$("$INSTALL" --global 2>&1); rc=$?
set -e
assert_exit_nonzero "$rc"
if grep -q "fakepower" <<<"$err"; then _pass; else _fail "error should name the owning plugin" "got: $err"; fi

# Override escape hatch still works.
set +e
ALLOW_PLUGIN_SKILL_COLLISION=1 "$INSTALL" --global >/dev/null 2>&1; rc=$?
set -e
assert_exit_zero "$rc"

# --- Bad usage fails loudly ---
set +e
"$INSTALL" >/dev/null 2>&1; rc=$?
set -e
assert_exit_nonzero "$rc"

report_results
