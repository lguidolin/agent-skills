# Centralized Tool Pool — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert agent-skills from a per-repo skill manager into a centralized inventory + per-project activation system for skills, agents, MCPs, and plugins.

**Architecture:** A central pool at `~/local/agent-skills/{skills,agents,mcps,plugins}-available/` plus a `registry.yml` is the single source of truth. Three operations: `bootstrap` (one-time global discovery), `claude-init` (per-project migration), `profile-activate` (per-project symlink + config writes). Existing scripts (profile-activate.sh, profile-lock.sh, claudeignore-sync.sh) are preserved and extended.

**Tech Stack:** bash, `yq` (Mike Farah), `jq`, just (command runner). Tests are plain bash scripts using a fixture `$TEST_HOME`.

---

## File Structure

**New files:**
- `scripts/registry.sh` — library: CRUD operations on `registry.yml`
- `scripts/bootstrap.sh` — one-time global discovery
- `scripts/tool-list.sh` — render inventory
- `scripts/plugin-toggle.sh` — write project's `.claude/settings.json` `enabledPlugins`
- `scripts/mcp-write.sh` — write project's `.mcp.json` from registry
- `tests/lib/assert.sh` — shared bash test helpers
- `tests/lib/fixture.sh` — shared fixture-setup helpers
- `tests/test_registry.sh`, `tests/test_bootstrap.sh`, `tests/test_profile_activate.sh`, `tests/test_claude_init.sh`, `tests/test_tool_list.sh`, `tests/test_e2e.sh`
- `agents-available/.gitkeep`, `plugins-available/.gitkeep`

**Renamed:**
- `mcps/` → `mcps-available/`
- `skills/` → `skills-available/`

**Modified:**
- `scripts/profile-activate.sh` — extend for agents, MCPs, plugins, `active_in` tracking
- `scripts/claude-init.sh` — replace body with project-tool migration logic
- `scripts/mcp-configure.sh` — delete (replaced by `mcp-write.sh`)
- `Justfile` — add `claude-bootstrap`, `claude-list`, update other commands
- `README.md` — document the new model
- `.gitignore` — ignore generated `registry.yml`, `managed-projects.yml`, backup files

**Convention used in tests:**
- Each test sets `export HOME=$TEST_HOME` (a temp dir) and `export AGENT_SKILLS_DIR=$TEST_HOME/agent-skills` so scripts read/write the fixture, not the real system.
- Each test self-cleans on exit via `trap`.

---

## Phase 1 — Foundations

### Task 1: Add bash test framework helpers

**Files:**
- Create: `tests/lib/assert.sh`
- Create: `tests/lib/fixture.sh`

- [ ] **Step 1: Create assertion helpers**

```bash
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
  actual=$(yq -r "$path" "$file" 2>/dev/null || echo "<error>")
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
```

- [ ] **Step 2: Create fixture helpers**

```bash
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
```

- [ ] **Step 3: Commit**

```bash
git add tests/lib/assert.sh tests/lib/fixture.sh
git commit -m "test: add shared bash assertion and fixture helpers"
```

---

### Task 2: Rename `mcps/` to `mcps-available/` and `skills/` to `skills-available/`

**Files:**
- Move: `mcps/` → `mcps-available/`
- Move: `skills/` → `skills-available/`
- Modify: any references in scripts and docs

- [ ] **Step 1: Rename directories with git mv (preserves history)**

```bash
git mv mcps mcps-available
git mv skills skills-available
```

- [ ] **Step 2: Find all references that need updating**

Run: `grep -RIln '\bmcps/\|\bskills/' scripts Justfile docs README.md 2>/dev/null`

Expected files (will need updating in the next step):
- `scripts/mcp-configure.sh` — references `$AGENT_SKILLS_DIR/mcps`
- `scripts/profile-activate.sh` — references `$AGENT_SKILLS_DIR/.github/skills` (NOT `skills/`, leave this)
- `Justfile` — references both
- `README.md`
- `docs/DEVELOPMENT.md`, `docs/claude-code-setup.md`

- [ ] **Step 3: Update `scripts/mcp-configure.sh` (only place `mcps/` is hardcoded in scripts)**

Change line 11:

```bash
# OLD
MCPS_DIR="$AGENT_SKILLS_DIR/mcps"
# NEW
MCPS_DIR="$AGENT_SKILLS_DIR/mcps-available"
```

- [ ] **Step 4: Update `Justfile` references**

Replace each occurrence of `"{{_agent_skills_dir}}"/mcps/` with `"{{_agent_skills_dir}}"/mcps-available/`. Same for `skills/`.

Run: `grep -n 'mcps/\|skills/' Justfile`
Then for each match (excluding `.github/skills/`), edit.

- [ ] **Step 5: Verify the existing flow still works**

```bash
# In a scratch project dir:
cd /tmp && mkdir -p test-rename && cd test-rename
AGENT_SKILLS_DIR=$REPO_ROOT just --justfile $REPO_ROOT/Justfile claude-list-skills
```

Expected: lists skills from `.github/skills/` (this hasn't changed). No errors about missing `mcps/` directory.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: rename mcps/ to mcps-available/ and skills/ to skills-available/"
```

---

### Task 3: Add empty `agents-available/` and `plugins-available/` directories

**Files:**
- Create: `agents-available/.gitkeep`
- Create: `plugins-available/.gitkeep`

- [ ] **Step 1: Create directories with placeholders**

```bash
mkdir -p agents-available plugins-available
touch agents-available/.gitkeep plugins-available/.gitkeep
```

- [ ] **Step 2: Commit**

```bash
git add agents-available/.gitkeep plugins-available/.gitkeep
git commit -m "chore: add empty agents-available/ and plugins-available/ pool dirs"
```

---

### Task 4: Add `.gitignore` entries for runtime-generated files

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Append entries**

```bash
cat >> .gitignore <<'EOF'

# Runtime state — populated by bootstrap, init, and activation scripts
/registry.yml
/managed-projects.yml
*.bak
EOF
```

- [ ] **Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: gitignore runtime state files (registry, managed-projects, backups)"
```

---

### Task 5: Write the failing test for the registry library

**Files:**
- Create: `tests/test_registry.sh`

- [ ] **Step 1: Write the failing test**

```bash
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
echo "$out" | grep -q '^foo	skill$' && _pass || _fail "list missing foo: '$out'"

# 8. get: prints a yaml subtree for one asset
out=$("$LIB" get foo)
echo "$out" | grep -q 'type: skill' && _pass || _fail "get returned: '$out'"

report_results
```

- [ ] **Step 2: Run the test, expect failure**

```bash
chmod +x tests/test_registry.sh
bash tests/test_registry.sh
```

Expected: exits non-zero with messages like "command not found" or "expected file" because `scripts/registry.sh` doesn't exist yet.

---

### Task 6: Implement `scripts/registry.sh`

**Files:**
- Create: `scripts/registry.sh`

- [ ] **Step 1: Implement the registry library**

```bash
#!/usr/bin/env bash
# scripts/registry.sh — CRUD operations on registry.yml
# All operations are atomic (write to temp, mv into place).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="${AGENT_SKILLS_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
REG="$AGENT_SKILLS_DIR/registry.yml"

require_yq() {
  command -v yq >/dev/null || { echo "registry.sh: 'yq' is required" >&2; exit 1; }
}
require_yq

ensure_init() {
  if [[ ! -f "$REG" ]]; then
    printf 'version: 1\nassets: {}\n' > "$REG"
  fi
}

write_atomic() {
  local content="$1"
  local tmp="$REG.tmp.$$"
  printf '%s' "$content" > "$tmp"
  mv "$tmp" "$REG"
}

cmd_init() {
  ensure_init
}

cmd_add() {
  # Usage: add <name> type=<t> source=<s> [origin=<o>]
  ensure_init
  local name="$1"; shift
  local type="" source="" origin=""
  for kv in "$@"; do
    case "$kv" in
      type=*)   type="${kv#type=}" ;;
      source=*) source="${kv#source=}" ;;
      origin=*) origin="${kv#origin=}" ;;
      *) echo "registry.sh: unknown key in '$kv'" >&2; exit 1 ;;
    esac
  done
  [[ -n "$type" && -n "$source" ]] || { echo "registry.sh: add requires type= and source=" >&2; exit 1; }

  # Build the new asset block. Preserve existing profiles/active_in if present.
  local existing_profiles existing_active
  existing_profiles=$(yq -r ".assets.\"$name\".profiles // [] | @json" "$REG" 2>/dev/null || echo '[]')
  existing_active=$(yq -r ".assets.\"$name\".active_in // [] | @json" "$REG" 2>/dev/null || echo '[]')

  local new
  new=$(yq -y \
    --arg name "$name" --arg type "$type" --arg source "$source" --arg origin "$origin" \
    --argjson profiles "$existing_profiles" --argjson active "$existing_active" \
    '.assets[$name] = {type: $type, source: $source, profiles: $profiles, active_in: $active}
     | if $origin != "" then .assets[$name].origin = $origin else . end' "$REG")
  write_atomic "$new"
}

cmd_has() {
  ensure_init
  local name="$1"
  local present
  present=$(yq -r ".assets | has(\"$name\")" "$REG")
  [[ "$present" == "true" ]]
}

cmd_get() {
  ensure_init
  local name="$1"
  yq -y ".assets.\"$name\"" "$REG"
}

cmd_list() {
  ensure_init
  yq -r '.assets | to_entries | .[] | "\(.key)\t\(.value.type)"' "$REG"
}

cmd_set_profiles() {
  # Usage: set-profiles <name> <profile1> [profile2 ...]
  ensure_init
  local name="$1"; shift
  local json
  json=$(printf '%s\n' "$@" | yq -R . | yq -s '.' )  # array of strings
  local new
  new=$(yq -y --arg name "$name" --argjson profiles "$json" \
    '.assets[$name].profiles = $profiles' "$REG")
  write_atomic "$new"
}

cmd_add_active() {
  # Usage: add-active <name> <project_path>
  ensure_init
  local name="$1" project="$2"
  local new
  new=$(yq -y --arg name "$name" --arg project "$project" \
    '.assets[$name].active_in = ((.assets[$name].active_in // []) + [$project] | unique)' "$REG")
  write_atomic "$new"
}

cmd_remove_active() {
  # Usage: remove-active <name> <project_path>
  ensure_init
  local name="$1" project="$2"
  local new
  new=$(yq -y --arg name "$name" --arg project "$project" \
    '.assets[$name].active_in = ((.assets[$name].active_in // []) | map(select(. != $project)))' "$REG")
  write_atomic "$new"
}

usage() {
  echo "Usage: $(basename "$0") {init|add|has|get|list|set-profiles|add-active|remove-active} [args...]" >&2
  exit 1
}

case "${1:-}" in
  init)           shift; cmd_init "$@" ;;
  add)            shift; cmd_add "$@" ;;
  has)            shift; cmd_has "$@" ;;
  get)            shift; cmd_get "$@" ;;
  list)           shift; cmd_list "$@" ;;
  set-profiles)   shift; cmd_set_profiles "$@" ;;
  add-active)     shift; cmd_add_active "$@" ;;
  remove-active)  shift; cmd_remove_active "$@" ;;
  *) usage ;;
esac
```

- [ ] **Step 2: Make executable and run the test**

```bash
chmod +x scripts/registry.sh
bash tests/test_registry.sh
```

Expected: all assertions pass.

- [ ] **Step 3: Commit**

```bash
git add scripts/registry.sh tests/test_registry.sh tests/lib/assert.sh tests/lib/fixture.sh
git commit -m "feat: add registry.sh library for CRUD on registry.yml"
```

---

## Phase 2 — Bootstrap

### Task 7: Write the failing test for plugin discovery

**Files:**
- Create: `tests/test_bootstrap.sh`

- [ ] **Step 1: Write fixture-based test for plugin discovery**

```bash
#!/usr/bin/env bash
# tests/test_bootstrap.sh
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/lib/assert.sh"
source "$REPO_ROOT/tests/lib/fixture.sh"

setup_fixture
trap teardown_fixture EXIT

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

REG="$AGENT_SKILLS_DIR/registry.yml"
assert_file_exists "$REG"
assert_yaml_eq "$REG" '.assets."plugin-alpha".type' 'plugin'
assert_yaml_eq "$REG" '.assets."plugin-alpha".source' "$HOME/.claude/plugins/cache/marketplace-x/plugin-alpha/1.0.0"

# --- Idempotency: run again, expect same state ---
"$AGENT_SKILLS_DIR/scripts/bootstrap.sh" --plugins-only --yes
assert_yaml_eq "$REG" '.assets | length' '2'

report_results
```

- [ ] **Step 2: Run, expect failure**

```bash
chmod +x tests/test_bootstrap.sh
bash tests/test_bootstrap.sh
```

Expected: fails because `bootstrap.sh` doesn't exist.

---

### Task 8: Implement plugin-discovery in `scripts/bootstrap.sh`

**Files:**
- Create: `scripts/bootstrap.sh`

- [ ] **Step 1: Implement the script with `--plugins-only` flag**

```bash
#!/usr/bin/env bash
# scripts/bootstrap.sh — one-time global discovery
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="${AGENT_SKILLS_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
REGISTRY="$SCRIPT_DIR/registry.sh"
ASSUME_YES=0
ONLY_SECTION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y)         ASSUME_YES=1 ;;
    --plugins-only)   ONLY_SECTION="plugins" ;;
    --skills-only)    ONLY_SECTION="skills" ;;
    --mcps-only)      ONLY_SECTION="mcps" ;;
    --plugin-disable-only) ONLY_SECTION="plugin-disable" ;;
    *) echo "bootstrap: unknown flag $1" >&2; exit 1 ;;
  esac
  shift
done

confirm() {
  if [[ "$ASSUME_YES" -eq 1 ]]; then return 0; fi
  read -rp "$1 [Y/n] " ans
  [[ "${ans:-Y}" =~ ^[Yy]?$ ]]
}

discover_plugins() {
  echo "[bootstrap] scanning ~/.claude/plugins/cache..."
  "$REGISTRY" init
  local cache="$HOME/.claude/plugins/cache"
  [[ -d "$cache" ]] || { echo "  (no plugins cache, skipping)"; return; }

  local count=0
  for marketplace_dir in "$cache"/*/; do
    [[ -d "$marketplace_dir" ]] || continue
    local marketplace
    marketplace=$(basename "$marketplace_dir")
    for plugin_dir in "$marketplace_dir"*/; do
      [[ -d "$plugin_dir" ]] || continue
      local plugin
      plugin=$(basename "$plugin_dir")
      # Pick the most recent version directory
      local version_dir
      version_dir=$(ls -td "$plugin_dir"*/ 2>/dev/null | head -n1)
      [[ -n "$version_dir" ]] || continue
      version_dir="${version_dir%/}"

      # Write plugins-available stub
      local stub="$AGENT_SKILLS_DIR/plugins-available/$plugin.yml"
      mkdir -p "$AGENT_SKILLS_DIR/plugins-available"
      cat > "$stub" <<EOF
name: $plugin
marketplace: $marketplace
source: $version_dir
EOF

      "$REGISTRY" add "$plugin" type=plugin source="$version_dir"
      count=$((count + 1))
    done
  done
  echo "  registered $count plugin(s)"
}

discover_global_skills() {
  echo "[bootstrap] scanning ~/.claude/skills..."
  "$REGISTRY" init
  local skills_dir="$HOME/.claude/skills"
  [[ -d "$skills_dir" ]] || { echo "  (no global skills, skipping)"; return; }

  local count=0
  for src in "$skills_dir"/*/; do
    [[ -d "$src" ]] || continue
    local name
    name=$(basename "$src")
    local dest="$AGENT_SKILLS_DIR/skills-available/$name"

    if [[ -e "$dest" ]]; then
      echo "  skip $name (already in pool)"
      "$REGISTRY" add "$name" type=skill source="$dest"
      continue
    fi

    if confirm "  move $name → skills-available/?"; then
      mkdir -p "$AGENT_SKILLS_DIR/skills-available"
      mv "$src" "$dest"
      "$REGISTRY" add "$name" type=skill source="$dest"
      count=$((count + 1))
    fi
  done
  echo "  moved $count skill(s)"
}

discover_global_mcps() {
  echo "[bootstrap] scanning ~/.claude.json..."
  "$REGISTRY" init
  local cfg="$HOME/.claude.json"
  [[ -f "$cfg" ]] || { echo "  (no ~/.claude.json, skipping)"; return; }

  local count
  count=$(jq -r '.mcpServers // {} | keys | length' "$cfg" 2>/dev/null || echo 0)
  [[ "$count" -gt 0 ]] || { echo "  (no MCPs registered)"; return; }

  # Backup first
  cp "$cfg" "$cfg.bak.$(date +%s)"

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    local cmd args
    cmd=$(jq -r ".mcpServers.\"$name\".command" "$cfg")
    args=$(jq -c ".mcpServers.\"$name\".args // []" "$cfg")
    local stub="$AGENT_SKILLS_DIR/mcps-available/$name.yml"
    mkdir -p "$AGENT_SKILLS_DIR/mcps-available"
    cat > "$stub" <<EOF
name: $name
command: $cmd
args: $args
EOF
    "$REGISTRY" add "$name" type=mcp source="$stub"
  done < <(jq -r '.mcpServers // {} | keys[]' "$cfg")

  if confirm "  empty mcpServers in ~/.claude.json (will re-populate per-project)?"; then
    local tmp
    tmp=$(jq '.mcpServers = {}' "$cfg")
    printf '%s' "$tmp" > "$cfg"
  fi
  echo "  registered $count MCP(s)"
}

disable_global_plugins() {
  echo "[bootstrap] disabling enabledPlugins in ~/.claude/settings.json..."
  local cfg="$HOME/.claude/settings.json"
  [[ -f "$cfg" ]] || { echo "  (no settings.json, skipping)"; return; }

  cp "$cfg" "$cfg.bak.$(date +%s)"
  if confirm "  set every entry in enabledPlugins to false?"; then
    local tmp
    tmp=$(jq '(.enabledPlugins // {}) as $p | .enabledPlugins = ($p | map_values(false))' "$cfg")
    printf '%s' "$tmp" > "$cfg"
    echo "  done."
  fi
}

# Dispatch
case "$ONLY_SECTION" in
  plugins)         discover_plugins ;;
  skills)          discover_global_skills ;;
  mcps)            discover_global_mcps ;;
  plugin-disable)  disable_global_plugins ;;
  "")              discover_plugins; discover_global_skills; discover_global_mcps; disable_global_plugins ;;
esac

echo "[bootstrap] done."
```

- [ ] **Step 2: Make executable and run the test**

```bash
chmod +x scripts/bootstrap.sh
bash tests/test_bootstrap.sh
```

Expected: passes.

- [ ] **Step 3: Commit**

```bash
git add scripts/bootstrap.sh tests/test_bootstrap.sh
git commit -m "feat: add bootstrap.sh with plugin discovery"
```

---

### Task 9: Test for global-skill discovery and migration

**Files:**
- Modify: `tests/test_bootstrap.sh`

- [ ] **Step 1: Append a skill-discovery test**

Append to `tests/test_bootstrap.sh` before `report_results`:

```bash
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
```

- [ ] **Step 2: Run the test, expect pass (already implemented in Task 8)**

```bash
bash tests/test_bootstrap.sh
```

Expected: pass.

- [ ] **Step 3: Commit**

```bash
git add tests/test_bootstrap.sh
git commit -m "test: cover global-skill migration in bootstrap"
```

---

### Task 10: Test for MCP discovery + ~/.claude.json emptying

**Files:**
- Modify: `tests/test_bootstrap.sh`

- [ ] **Step 1: Append MCP-discovery test**

Append before `report_results`:

```bash
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
```

- [ ] **Step 2: Run, expect pass**

```bash
bash tests/test_bootstrap.sh
```

- [ ] **Step 3: Commit**

```bash
git add tests/test_bootstrap.sh
git commit -m "test: cover MCP discovery and mcpServers emptying"
```

---

### Task 11: Test for plugin-disable in global settings.json

**Files:**
- Modify: `tests/test_bootstrap.sh`

- [ ] **Step 1: Append plugin-disable test**

Append before `report_results`:

```bash
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
```

- [ ] **Step 2: Run, expect pass**

```bash
bash tests/test_bootstrap.sh
```

- [ ] **Step 3: Add Justfile entry for `claude-bootstrap`**

Edit `Justfile`. Find the `# --- Setup ---` section (or just before it) and add:

```just
# One-time global discovery — populate the central pool from existing system state
claude-bootstrap:
    @{{_agent_skills_dir}}/scripts/bootstrap.sh
```

- [ ] **Step 4: Commit**

```bash
git add tests/test_bootstrap.sh Justfile
git commit -m "feat: add plugin-disable phase and claude-bootstrap just command"
```

---

## Phase 3 — Profile activation extensions

### Task 12: Write failing test for agent symlinking in profile-activate

**Files:**
- Create: `tests/test_profile_activate.sh`

- [ ] **Step 1: Write the test**

```bash
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
v=$(yq -r '.assets."skill-a".active_in[0]' "$AGENT_SKILLS_DIR/registry.yml")
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
```

- [ ] **Step 2: Run the test, expect failure**

```bash
chmod +x tests/test_profile_activate.sh
bash tests/test_profile_activate.sh
```

Expected: fails — current `profile-activate.sh` doesn't symlink agents, write `.mcp.json`, or update settings.json.

---

### Task 13: Extend `profile-activate.sh` — read pool from `skills-available/`

**Files:**
- Modify: `scripts/profile-activate.sh`

- [ ] **Step 1: Replace skill-symlinking block to read from new pool**

Find the existing block (around line 54-63):

```bash
# OLD
for skill in "${skills[@]}"; do
  [[ -z "$skill" ]] && continue
  source_dir="$AGENT_SKILLS_DIR/.github/skills/$skill"
  if [[ -d "$source_dir" ]]; then
    ln -sf "$source_dir" ".github/skills/$skill"
    linked=$((linked + 1))
  else
    echo "WARNING: Skill '$skill' not found in $AGENT_SKILLS_DIR/.github/skills/" >&2
  fi
done
```

Replace with:

```bash
# NEW — read from skills-available pool
for skill in "${skills[@]}"; do
  [[ -z "$skill" ]] && continue
  source_dir="$AGENT_SKILLS_DIR/skills-available/$skill"
  if [[ -d "$source_dir" ]]; then
    ln -sf "$source_dir" ".github/skills/$skill"
    linked=$((linked + 1))
  else
    echo "WARNING: skill '$skill' not in $AGENT_SKILLS_DIR/skills-available/ — skipping" >&2
  fi
done
```

- [ ] **Step 2: Run the existing skill-only behavior to make sure nothing regressed**

In a scratch dir:
```bash
cd /tmp && rm -rf p && mkdir p && cd p
AGENT_SKILLS_DIR=$REPO_ROOT $REPO_ROOT/scripts/profile-activate.sh code .
ls -la .github/skills/
```

Expected: skills are symlinked (still works for the existing repo's skills now sitting in `skills-available/`).

- [ ] **Step 3: Commit**

```bash
git add scripts/profile-activate.sh
git commit -m "refactor: profile-activate reads skills from skills-available/"
```

---

### Task 14: Add agent symlinking to `profile-activate.sh`

**Files:**
- Modify: `scripts/profile-activate.sh`

- [ ] **Step 1: Insert agent block after the skills block**

Locate the skills loop (just edited). Immediately after the closing `done` for skills, add:

```bash
# Step 6.5: Tear down old agent symlinks, then create new ones
mkdir -p .claude/agents
find .claude/agents -maxdepth 1 -type l -exec rm {} \; 2>/dev/null || true

mapfile -t agents < <(yq -r '.agents // [] | .[]' "$PROFILE_FILE" 2>/dev/null || true)

# project-level overrides for agents
if [[ -f ".claude-profiles.yml" ]]; then
  mapfile -t agents_add    < <(yq -r ".${PROFILE_NAME}.agents_add // [] | .[]" ".claude-profiles.yml" 2>/dev/null || true)
  mapfile -t agents_remove < <(yq -r ".${PROFILE_NAME}.agents_remove // [] | .[]" ".claude-profiles.yml" 2>/dev/null || true)
  for a in "${agents_add[@]}";    do [[ -n "$a" ]] && agents+=("$a"); done
  for r in "${agents_remove[@]}"; do agents=("${agents[@]/$r/}"); done
fi

agents_linked=0
for agent in "${agents[@]}"; do
  [[ -z "$agent" ]] && continue
  src="$AGENT_SKILLS_DIR/agents-available/$agent"
  if [[ -d "$src" ]]; then
    ln -sf "$src" ".claude/agents/$agent"
    agents_linked=$((agents_linked + 1))
  else
    echo "WARNING: agent '$agent' not in $AGENT_SKILLS_DIR/agents-available/ — skipping" >&2
  fi
done
```

Also: at the bottom of the script, update the report block to include agents:

```bash
echo "  Skills: $linked symlinked"
echo "  Agents: $agents_linked symlinked"
```

- [ ] **Step 2: Run the targeted test**

```bash
bash tests/test_profile_activate.sh 2>&1 | head -40
```

Expected: at least the agent assertions pass; later assertions (.mcp.json, settings.json) still fail because we haven't done those yet.

- [ ] **Step 3: Commit**

```bash
git add scripts/profile-activate.sh
git commit -m "feat: profile-activate symlinks agents from agents-available/"
```

---

### Task 15: Implement `scripts/mcp-write.sh` (writes per-project `.mcp.json`)

**Files:**
- Create: `scripts/mcp-write.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# scripts/mcp-write.sh — write project's .mcp.json from registry MCP entries
# Usage: mcp-write.sh <project_dir> [<mcp_name> ...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="${AGENT_SKILLS_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

PROJECT_DIR="${1:?usage: mcp-write.sh <project_dir> [mcp_name...]}"
shift || true

OUT="$PROJECT_DIR/.mcp.json"

# Build mcpServers JSON object
servers='{}'
for name in "$@"; do
  [[ -z "$name" ]] && continue
  yml="$AGENT_SKILLS_DIR/mcps-available/$name.yml"
  if [[ ! -f "$yml" ]]; then
    echo "WARNING: mcp '$name' not in mcps-available/ — skipping" >&2
    continue
  fi
  cmd=$(yq -r '.command' "$yml")
  args=$(yq -o=json -I=0 '.args // []' "$yml")
  servers=$(jq --arg n "$name" --arg cmd "$cmd" --argjson args "$args" \
    '.[$n] = {command: $cmd, args: $args}' <<<"$servers")
done

# Write .mcp.json (always overwrite — profile activation owns this file)
echo "{\"mcpServers\": $servers}" | jq '.' > "$OUT"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/mcp-write.sh
```

- [ ] **Step 3: Smoke-test manually**

```bash
mkdir -p /tmp/mcp-write-smoke && cd /tmp/mcp-write-smoke
mkdir -p $REPO_ROOT/mcps-available
cat > $REPO_ROOT/mcps-available/_tmp.yml <<'EOF'
name: _tmp
command: echo
args: ["hi"]
EOF
AGENT_SKILLS_DIR=$REPO_ROOT $REPO_ROOT/scripts/mcp-write.sh . _tmp
cat .mcp.json
rm $REPO_ROOT/mcps-available/_tmp.yml
```

Expected output: `{ "mcpServers": { "_tmp": { "command": "echo", "args": ["hi"] } } }`

- [ ] **Step 4: Commit**

```bash
git add scripts/mcp-write.sh
git commit -m "feat: add mcp-write.sh to render per-project .mcp.json"
```

---

### Task 16: Wire `mcp-write.sh` into `profile-activate.sh`

**Files:**
- Modify: `scripts/profile-activate.sh`

- [ ] **Step 1: Replace the existing MCP step (Step 8 in the script)**

Find:

```bash
# Step 8: Configure MCPs (best effort, script may not exist yet)
if [[ -x "$SCRIPT_DIR/mcp-configure.sh" ]]; then
  "$SCRIPT_DIR/mcp-configure.sh" "$PROFILE_NAME" "$PROJECT_DIR" 2>/dev/null || true
fi
```

Replace with:

```bash
# Step 8: Write per-project .mcp.json from profile MCP list
mapfile -t mcps < <(yq -r '.mcps // [] | .[]' "$PROFILE_FILE" 2>/dev/null || true)
if [[ -f ".claude-profiles.yml" ]]; then
  mapfile -t mcps_add    < <(yq -r ".${PROFILE_NAME}.mcps_add // [] | .[]" ".claude-profiles.yml" 2>/dev/null || true)
  mapfile -t mcps_remove < <(yq -r ".${PROFILE_NAME}.mcps_remove // [] | .[]" ".claude-profiles.yml" 2>/dev/null || true)
  for m in "${mcps_add[@]}";    do [[ -n "$m" ]] && mcps+=("$m"); done
  for r in "${mcps_remove[@]}"; do mcps=("${mcps[@]/$r/}"); done
fi
"$SCRIPT_DIR/mcp-write.sh" "$PROJECT_DIR" "${mcps[@]}"
```

- [ ] **Step 2: Delete the now-unused `scripts/mcp-configure.sh`**

```bash
git rm scripts/mcp-configure.sh
```

- [ ] **Step 3: Run targeted test**

```bash
bash tests/test_profile_activate.sh 2>&1 | head -50
```

Expected: agent and MCP assertions pass; plugin / registry / lock assertions still fail.

- [ ] **Step 4: Commit**

```bash
git add scripts/profile-activate.sh
git commit -m "feat: profile-activate writes .mcp.json via mcp-write.sh"
```

---

### Task 17: Implement `scripts/plugin-toggle.sh`

**Files:**
- Create: `scripts/plugin-toggle.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# scripts/plugin-toggle.sh — write project's .claude/settings.json enabledPlugins
# Usage: plugin-toggle.sh <project_dir> <enabled_plugin_name> [...]
# Sets every plugin in registry to false, then sets the listed ones to true.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="${AGENT_SKILLS_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
REGISTRY="$SCRIPT_DIR/registry.sh"

PROJECT_DIR="${1:?usage: plugin-toggle.sh <project_dir> [name...]}"
shift || true

mkdir -p "$PROJECT_DIR/.claude"
SETTINGS="$PROJECT_DIR/.claude/settings.json"

# Build full enabled map: every registry plugin → false; then the args → true
all_plugins=()
while IFS=$'\t' read -r name type; do
  [[ "$type" == "plugin" ]] && all_plugins+=("$name")
done < <("$REGISTRY" list 2>/dev/null || true)

map='{}'
for p in "${all_plugins[@]}"; do
  map=$(jq --arg p "$p" '.[$p] = false' <<<"$map")
done
for p in "$@"; do
  [[ -z "$p" ]] && continue
  map=$(jq --arg p "$p" '.[$p] = true' <<<"$map")
done

# Merge into existing settings.json if present, else create
if [[ -f "$SETTINGS" ]]; then
  tmp=$(jq --argjson m "$map" '.enabledPlugins = $m' "$SETTINGS")
  printf '%s' "$tmp" > "$SETTINGS"
else
  printf '{"enabledPlugins": %s}\n' "$map" | jq '.' > "$SETTINGS"
fi
```

- [ ] **Step 2: Wire into `profile-activate.sh`**

In `scripts/profile-activate.sh`, just before the report block (Step 9 area), insert:

```bash
# Step 8.5: Write per-project enabledPlugins
mapfile -t plugins < <(yq -r '.plugins // [] | .[]' "$PROFILE_FILE" 2>/dev/null || true)
if [[ -f ".claude-profiles.yml" ]]; then
  mapfile -t plugins_add    < <(yq -r ".${PROFILE_NAME}.plugins_add // [] | .[]" ".claude-profiles.yml" 2>/dev/null || true)
  mapfile -t plugins_remove < <(yq -r ".${PROFILE_NAME}.plugins_remove // [] | .[]" ".claude-profiles.yml" 2>/dev/null || true)
  for p in "${plugins_add[@]}";    do [[ -n "$p" ]] && plugins+=("$p"); done
  for r in "${plugins_remove[@]}"; do plugins=("${plugins[@]/$r/}"); done
fi
"$SCRIPT_DIR/plugin-toggle.sh" "$PROJECT_DIR" "${plugins[@]}"
```

- [ ] **Step 3: Make executable**

```bash
chmod +x scripts/plugin-toggle.sh
```

- [ ] **Step 4: Run test**

```bash
bash tests/test_profile_activate.sh 2>&1 | head -60
```

Expected: skill / agent / MCP / plugin assertions pass; lock and active_in still fail.

- [ ] **Step 5: Commit**

```bash
git add scripts/plugin-toggle.sh scripts/profile-activate.sh
git commit -m "feat: profile-activate writes per-project enabledPlugins via plugin-toggle.sh"
```

---

### Task 18: Update `active_in` in registry on activation/deactivation

**Files:**
- Modify: `scripts/profile-activate.sh`

- [ ] **Step 1: Track previously-active set, then update registry**

At the top of the script (after computing `AGENT_SKILLS_DIR`), add:

```bash
REGISTRY="$SCRIPT_DIR/registry.sh"
"$REGISTRY" init
```

After computing the final `skills` / `agents` / `mcps` / `plugins` arrays (i.e., after all add/remove merging) but before exiting, insert this block. (Place it after Step 8.5.)

```bash
# Step 8.7: Update registry active_in tracking
# Build the full set of "now active" tool names for this project
now_active=()
for s in "${skills[@]}";  do [[ -n "$s" ]] && now_active+=("$s"); done
for a in "${agents[@]}";  do [[ -n "$a" ]] && now_active+=("$a"); done
for m in "${mcps[@]}";    do [[ -n "$m" ]] && now_active+=("$m"); done
for p in "${plugins[@]}"; do [[ -n "$p" ]] && now_active+=("$p"); done

# For every tool in registry: if it's in now_active, add this project; else remove this project
while IFS=$'\t' read -r name _type; do
  [[ -z "$name" ]] && continue
  in_active=0
  for n in "${now_active[@]}"; do [[ "$n" == "$name" ]] && in_active=1 && break; done
  if [[ "$in_active" -eq 1 ]]; then
    "$REGISTRY" add-active "$name" "$PROJECT_DIR"
  else
    "$REGISTRY" remove-active "$name" "$PROJECT_DIR"
  fi
done < <("$REGISTRY" list)
```

- [ ] **Step 2: Confirm lock writes profile name (it already does via profile-lock.sh acquire)**

Open `scripts/profile-lock.sh` and confirm `cmd_acquire` writes `<pid>\n<profile_name>` to `.claude-profile.lock`. If yes (it does at line 48), nothing more to do.

- [ ] **Step 3: Run the full activation test**

```bash
bash tests/test_profile_activate.sh
```

Expected: all assertions pass.

- [ ] **Step 4: Commit**

```bash
git add scripts/profile-activate.sh
git commit -m "feat: profile-activate updates registry active_in for activated/deactivated tools"
```

---

## Phase 4 — claude-init rewrite

### Task 19: Write failing test for project-tool migration

**Files:**
- Create: `tests/test_claude_init.sh`

- [ ] **Step 1: Write the test**

```bash
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
assert_file_exists "$AGENT_SKILLS_DIR/plugins-available/local-plugin@mp.yml" \
  || assert_file_exists "$AGENT_SKILLS_DIR/plugins-available/local-plugin.yml"

# Registry has entries with origin tag
REG="$AGENT_SKILLS_DIR/registry.yml"
assert_yaml_eq "$REG" '.assets."local-skill".origin' "$(basename "$PROJ")"
assert_yaml_eq "$REG" '.assets."local-agent".origin' "$(basename "$PROJ")"

# managed-projects.yml has the project
MGD="$AGENT_SKILLS_DIR/managed-projects.yml"
assert_file_exists "$MGD"
v=$(yq -r '.projects[]' "$MGD" | grep -c "^$PROJ\$")
[[ "$v" == "1" ]] && _pass || _fail "project not in managed-projects: $v"

# Idempotency: re-running shouldn't error or duplicate
"$AGENT_SKILLS_DIR/scripts/claude-init.sh" --profile minimal --yes
v=$(yq -r '.projects | length' "$MGD")
[[ "$v" == "1" ]] && _pass || _fail "managed-projects duplicated: $v"

report_results
```

- [ ] **Step 2: Run, expect failure**

```bash
chmod +x tests/test_claude_init.sh
bash tests/test_claude_init.sh
```

Expected: fails — the current `claude-init.sh` is a different (interactive setup) script.

---

### Task 20: Rewrite `scripts/claude-init.sh` for migration

**Files:**
- Modify: `scripts/claude-init.sh`

- [ ] **Step 1: Replace the script body**

```bash
#!/usr/bin/env bash
# scripts/claude-init.sh — per-project init: migrate project-local tools into the central pool
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="${AGENT_SKILLS_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
REGISTRY="$SCRIPT_DIR/registry.sh"

PROJECT_DIR="$(pwd)"
PROFILE=""
ASSUME_YES=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --yes|-y)  ASSUME_YES=1; shift ;;
    *) echo "claude-init: unknown flag $1" >&2; exit 1 ;;
  esac
done

confirm() { [[ "$ASSUME_YES" -eq 1 ]] || { read -rp "$1 [Y/n] " a; [[ "${a:-Y}" =~ ^[Yy]?$ ]]; }; }

"$REGISTRY" init

# 1. Migrate skills
if [[ -d "$PROJECT_DIR/.github/skills" ]]; then
  for src in "$PROJECT_DIR/.github/skills"/*/; do
    [[ -d "$src" ]] || continue
    [[ -L "${src%/}" ]] && continue   # already a symlink — nothing to migrate
    name=$(basename "$src")
    dest="$AGENT_SKILLS_DIR/skills-available/$name"
    if [[ -e "$dest" ]]; then
      echo "  skip skill $name (already in pool)"; continue
    fi
    if confirm "  migrate skill $name → pool?"; then
      mkdir -p "$AGENT_SKILLS_DIR/skills-available"
      mv "$src" "$dest"
      "$REGISTRY" add "$name" type=skill source="$dest" origin="$(basename "$PROJECT_DIR")"
    fi
  done
fi

# 2. Migrate agents
if [[ -d "$PROJECT_DIR/.claude/agents" ]]; then
  for src in "$PROJECT_DIR/.claude/agents"/*/; do
    [[ -d "$src" ]] || continue
    [[ -L "${src%/}" ]] && continue
    name=$(basename "$src")
    dest="$AGENT_SKILLS_DIR/agents-available/$name"
    if [[ -e "$dest" ]]; then
      echo "  skip agent $name (already in pool)"; continue
    fi
    if confirm "  migrate agent $name → pool?"; then
      mkdir -p "$AGENT_SKILLS_DIR/agents-available"
      mv "$src" "$dest"
      "$REGISTRY" add "$name" type=agent source="$dest" origin="$(basename "$PROJECT_DIR")"
    fi
  done
fi

# 3. Migrate MCPs from .mcp.json → mcps-available stubs
if [[ -f "$PROJECT_DIR/.mcp.json" ]]; then
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    yml="$AGENT_SKILLS_DIR/mcps-available/$name.yml"
    if [[ -e "$yml" ]]; then
      echo "  skip mcp $name (already in pool)"; continue
    fi
    if confirm "  migrate mcp $name → pool?"; then
      mkdir -p "$AGENT_SKILLS_DIR/mcps-available"
      cmd=$(jq -r ".mcpServers.\"$name\".command" "$PROJECT_DIR/.mcp.json")
      args=$(jq -c ".mcpServers.\"$name\".args // []" "$PROJECT_DIR/.mcp.json")
      cat > "$yml" <<EOF
name: $name
command: $cmd
args: $args
EOF
      "$REGISTRY" add "$name" type=mcp source="$yml" origin="$(basename "$PROJECT_DIR")"
    fi
  done < <(jq -r '.mcpServers // {} | keys[]' "$PROJECT_DIR/.mcp.json")
fi

# 4. Register plugins from project's .claude/settings.json (don't move; Claude owns the cache)
if [[ -f "$PROJECT_DIR/.claude/settings.json" ]]; then
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    plugin="${entry%@*}"   # strip "@marketplace" suffix for asset name
    yml="$AGENT_SKILLS_DIR/plugins-available/$plugin.yml"
    [[ -e "$yml" ]] && continue
    mkdir -p "$AGENT_SKILLS_DIR/plugins-available"
    cat > "$yml" <<EOF
name: $plugin
fullname: $entry
source: $HOME/.claude/plugins/cache
EOF
    "$REGISTRY" add "$plugin" type=plugin source="$HOME/.claude/plugins/cache" origin="$(basename "$PROJECT_DIR")"
  done < <(jq -r '.enabledPlugins // {} | to_entries | map(select(.value == true)) | .[] | .key' "$PROJECT_DIR/.claude/settings.json" 2>/dev/null || true)
fi

# 5. managed-projects.yml
MGD="$AGENT_SKILLS_DIR/managed-projects.yml"
if [[ ! -f "$MGD" ]]; then
  printf 'projects: []\n' > "$MGD"
fi
new=$(yq -y --arg p "$PROJECT_DIR" '.projects = ((.projects // []) + [$p] | unique)' "$MGD")
printf '%s' "$new" > "$MGD"

# 6. Activate the chosen profile (default: minimal)
if [[ -z "$PROFILE" ]]; then
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    PROFILE="minimal"
  else
    echo ""
    echo "Choose a starting profile:"
    ls "$AGENT_SKILLS_DIR/profiles/" | sed 's/.yml$//' | sed 's/^/  /'
    read -rp "Profile: " PROFILE
    PROFILE="${PROFILE:-minimal}"
  fi
fi
"$SCRIPT_DIR/profile-activate.sh" "$PROFILE" "$PROJECT_DIR"

echo ""
echo "✓ claude-init complete"
```

- [ ] **Step 2: Run the test**

```bash
bash tests/test_claude_init.sh
```

Expected: passes (some warnings about plugin/mcp `@` parsing are OK — adjust if a specific assertion fails).

- [ ] **Step 3: Commit**

```bash
git add scripts/claude-init.sh
git commit -m "feat: rewrite claude-init.sh as project migration + profile activation"
```

---

## Phase 5 — Inventory

### Task 21: Test for `tool-list.sh`

**Files:**
- Create: `tests/test_tool_list.sh`

- [ ] **Step 1: Write the test**

```bash
#!/usr/bin/env bash
# tests/test_tool_list.sh
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/lib/assert.sh"
source "$REPO_ROOT/tests/lib/fixture.sh"

setup_fixture
trap teardown_fixture EXIT

R="$AGENT_SKILLS_DIR/scripts/registry.sh"
"$R" init
"$R" add skill-a type=skill source=/tmp/a
"$R" add skill-b type=skill source=/tmp/b
"$R" add agent-x type=agent source=/tmp/x
"$R" add browser type=mcp source=/tmp/browser.yml
"$R" set-profiles skill-a brainstorm code
"$R" set-profiles skill-b code
"$R" set-profiles browser design code
"$R" add-active skill-a /work/proj-a

# 1. Default output: groups by type, marks active with ●
out=$("$AGENT_SKILLS_DIR/scripts/tool-list.sh")
echo "$out" | grep -q 'SKILLS' && _pass || _fail "missing SKILLS header"
echo "$out" | grep -q 'AGENTS' && _pass || _fail "missing AGENTS header"
echo "$out" | grep -q 'MCPS' && _pass || _fail "missing MCPS header"
echo "$out" | grep -q '●.*skill-a' && _pass || _fail "skill-a not marked active"
echo "$out" | grep -q '○.*skill-b' && _pass || _fail "skill-b should be inactive"

# 2. --type filter
out=$("$AGENT_SKILLS_DIR/scripts/tool-list.sh" --type=skill)
echo "$out" | grep -q skill-a && _pass || _fail "skill-a missing in --type=skill"
echo "$out" | grep -q browser && _fail "browser leaked into --type=skill" || _pass

# 3. --profile filter
out=$("$AGENT_SKILLS_DIR/scripts/tool-list.sh" --profile=design)
echo "$out" | grep -q browser && _pass || _fail "browser missing in --profile=design"
echo "$out" | grep -q skill-b && _fail "skill-b leaked into --profile=design" || _pass

# 4. --project filter
out=$("$AGENT_SKILLS_DIR/scripts/tool-list.sh" --project=/work/proj-a)
echo "$out" | grep -q skill-a && _pass || _fail "skill-a missing in --project filter"
echo "$out" | grep -q skill-b && _fail "skill-b leaked into --project filter" || _pass

report_results
```

- [ ] **Step 2: Run, expect failure**

```bash
chmod +x tests/test_tool_list.sh
bash tests/test_tool_list.sh
```

Expected: fails — `tool-list.sh` doesn't exist.

---

### Task 22: Implement `scripts/tool-list.sh`

**Files:**
- Create: `scripts/tool-list.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# scripts/tool-list.sh — render the inventory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="${AGENT_SKILLS_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
REG="$AGENT_SKILLS_DIR/registry.yml"

[[ -f "$REG" ]] || { echo "registry.yml is empty — run 'just claude-bootstrap' first."; exit 0; }

FILTER_TYPE=""
FILTER_PROFILE=""
FILTER_PROJECT=""
for arg in "$@"; do
  case "$arg" in
    --type=*)    FILTER_TYPE="${arg#--type=}" ;;
    --profile=*) FILTER_PROFILE="${arg#--profile=}" ;;
    --project=*) FILTER_PROJECT="${arg#--project=}" ;;
    *) echo "tool-list: unknown flag $arg" >&2; exit 1 ;;
  esac
done

# Build a list of (name, type, active_count, profiles_csv, active_in_csv, origin) rows
rows=$(yq -r '
  .assets // {}
  | to_entries
  | .[]
  | [
      .key,
      .value.type,
      ((.value.active_in // []) | length | tostring),
      ((.value.profiles  // []) | join(",")),
      ((.value.active_in // []) | join(",")),
      (.value.origin // "")
    ]
  | @tsv
' "$REG")

filter_row() {
  local name="$1" type="$2" profs="$4" actv="$5"
  [[ -n "$FILTER_TYPE"    && "$type" != "$FILTER_TYPE" ]] && return 1
  [[ -n "$FILTER_PROFILE" ]] && {
    echo ",$profs," | grep -q ",$FILTER_PROFILE," || return 1
  }
  [[ -n "$FILTER_PROJECT" ]] && {
    echo ",$actv," | grep -q ",$FILTER_PROJECT," || return 1
  }
  return 0
}

print_section() {
  local section_type="$1"
  local pretty="$2"
  local printed=0
  while IFS=$'\t' read -r name type count profs actv origin; do
    [[ -z "$name" ]] && continue
    [[ "$type" != "$section_type" ]] && continue
    filter_row "$name" "$type" "$count" "$profs" "$actv" || continue
    if [[ "$printed" -eq 0 ]]; then
      printf '\n%s\n' "$pretty"
      printed=1
    fi
    local mark='○'
    [[ "$count" -gt 0 ]] && mark='●'
    local origin_tag=""
    [[ -n "$origin" ]] && origin_tag="  [from: $origin]"
    printf '  %s %-30s  profiles: %-25s  active_in: %s%s\n' \
      "$mark" "$name" "${profs:-(none)}" "${actv:-(none)}" "$origin_tag"
  done <<< "$rows"
}

print_section plugin "PLUGINS"
print_section skill  "SKILLS"
print_section agent  "AGENTS"
print_section mcp    "MCPS"
echo ""
```

- [ ] **Step 2: Make executable and run test**

```bash
chmod +x scripts/tool-list.sh
bash tests/test_tool_list.sh
```

Expected: passes.

- [ ] **Step 3: Commit**

```bash
git add scripts/tool-list.sh tests/test_tool_list.sh
git commit -m "feat: add tool-list.sh inventory display with --type / --profile / --project filters"
```

---

### Task 23: Add Justfile entries for `claude-list`, expose `tool-list.sh`

**Files:**
- Modify: `Justfile`

- [ ] **Step 1: Add list commands**

In the `# --- Skills ---` section (or a new `# --- Inventory ---` section), add:

```just
# Show the inventory: all tools, marked active/inactive, with profile membership
claude-list:
    @{{_agent_skills_dir}}/scripts/tool-list.sh

# Show only tools of a specific type (skill, agent, mcp, plugin)
claude-list-type type:
    @{{_agent_skills_dir}}/scripts/tool-list.sh --type={{type}}

# Show tools in a specific profile
claude-list-profile profile:
    @{{_agent_skills_dir}}/scripts/tool-list.sh --profile={{profile}}
```

- [ ] **Step 2: Smoke test**

```bash
just --justfile $REPO_ROOT/Justfile claude-list || echo "(empty registry — expected on fresh repo)"
```

- [ ] **Step 3: Commit**

```bash
git add Justfile
git commit -m "feat: add claude-list / claude-list-type / claude-list-profile commands"
```

---

## Phase 6 — End-to-end & docs

### Task 24: End-to-end integration test

**Files:**
- Create: `tests/test_e2e.sh`

- [ ] **Step 1: Write the integration test**

```bash
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
cd "$PROJ"

# Profile that uses the just-migrated skills + an MCP + plugin
cat > "$AGENT_SKILLS_DIR/profiles/work.yml" <<'EOF'
name: work
skills: [global-skill, proj-skill]
agents: []
mcps: [browser]
plugins: [superpowers]
claudeignore: []
EOF

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
echo "$out" | grep -q '○.*global-skill' && _pass || _fail "global-skill should be inactive after switch"
echo "$out" | grep -q '○.*proj-skill'   && _pass || _fail "proj-skill should be inactive after switch"

report_results
```

- [ ] **Step 2: Run the integration test**

```bash
chmod +x tests/test_e2e.sh
bash tests/test_e2e.sh
```

Expected: all pass.

- [ ] **Step 3: Commit**

```bash
git add tests/test_e2e.sh
git commit -m "test: end-to-end integration covering bootstrap, init, activate, switch, list"
```

---

### Task 25: Add a `tests/run.sh` runner

**Files:**
- Create: `tests/run.sh`

- [ ] **Step 1: Write the runner**

```bash
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fails=0
for t in "$REPO_ROOT"/tests/test_*.sh; do
  echo "─── $(basename "$t") ───"
  if bash "$t"; then
    echo "  OK"
  else
    fails=$((fails + 1))
  fi
done
echo ""
echo "$fails test file(s) failed"
exit "$fails"
```

- [ ] **Step 2: Make executable and run**

```bash
chmod +x tests/run.sh
bash tests/run.sh
```

Expected: all test files pass.

- [ ] **Step 3: Add `just test` Justfile entry**

In `Justfile`:

```just
# Run all bash tests
test:
    @{{_agent_skills_dir}}/tests/run.sh
```

- [ ] **Step 4: Commit**

```bash
git add tests/run.sh Justfile
git commit -m "test: add tests/run.sh runner and 'just test' command"
```

---

### Task 26: Update `README.md` for the new model

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace the "Quick Start" and "How It Works" sections**

In `README.md`, replace the Quick Start section (lines 7-34 approximately) with:

```markdown
## Quick Start

1. **Clone this repo** to a stable location:
   ```bash
   git clone https://github.com/lguidolin/agent-skills.git ~/local/agent-skills
   ```

2. **Set the env var** in your shell config:
   ```bash
   export AGENT_SKILLS_DIR="$HOME/local/agent-skills"
   ```

3. **Bootstrap** — one-time discovery of tools already installed on this machine:
   ```bash
   just --justfile $AGENT_SKILLS_DIR/Justfile claude-bootstrap
   ```

4. **Per project** — import the Justfile and run init once:
   ```justfile
   import "~/local/agent-skills/Justfile"
   ```
   ```bash
   just claude-init           # migrates project-local tools into the pool
   just claude-code           # activate the 'code' profile in this project
   ```
```

Replace "How It Works" with:

```markdown
## How It Works

`agent-skills` is a centralized inventory + per-project activation system. All your tools — skills, agents, MCPs, plugins — live in one pool at `~/local/agent-skills/{skills,agents,mcps,plugins}-available/`. A `registry.yml` tracks what exists and where.

**Profile activation** is per-project: it creates symlinks in `<project>/.github/skills/` and `<project>/.claude/agents/`, writes `<project>/.mcp.json`, and toggles `enabledPlugins` in `<project>/.claude/settings.json`. Other projects are unaffected.

**Inventory:**
```
just claude-list                    # all tools, grouped by type
just claude-list-type skill         # filter by type
just claude-list-profile code       # filter by profile
```
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: update README for centralized pool and per-project activation"
```

---

## Self-Review Notes

After implementation, verify:

- [ ] **Spec coverage:**
  - Bootstrap discovery (plugins, skills, MCPs, plugin-disable) — Tasks 7-11
  - Per-project init migration (skills, agents, MCPs, plugins) — Tasks 19-20
  - Profile activation (skills, agents, MCPs, plugins, registry update, lock) — Tasks 12-18
  - Inventory + filters — Tasks 21-23
  - Error handling (lock conflict, missing tool, real file in `.github/skills/`, idempotency) — covered in tests at Tasks 12, 19
  - Migration (existing toolkit) — Tasks 2 (rename) + 26 (README docs)

- [ ] **Placeholder scan:** All steps include code or exact commands. No "implement later".

- [ ] **Type/name consistency:**
  - Pool dirs: `skills-available/`, `agents-available/`, `mcps-available/`, `plugins-available/` — used consistently.
  - Registry fields: `type`, `source`, `profiles`, `active_in`, `origin` — consistent across `registry.sh`, `bootstrap.sh`, `claude-init.sh`, `tool-list.sh`.
  - Script names: `bootstrap.sh`, `claude-init.sh`, `profile-activate.sh`, `mcp-write.sh`, `plugin-toggle.sh`, `registry.sh`, `tool-list.sh` — consistent.

---

## Notes for the executor

- **`yq` flavor**: This plan assumes the **Mike Farah** `yq` (Go), which supports both `yq -y` and `yq -r`. If the system has the Python kislyuk `yq`, the syntax differs in places — verify with `yq --version` before starting and adjust the `yq` calls (the most-likely-affected commands are in `registry.sh` and `tool-list.sh`).
- **Test isolation**: Every test sets `HOME` to a temp dir. Do not run tests with the real `HOME`. The `setup_fixture` helper handles this.
- **Idempotency is required**, not nice-to-have. Most operations the user runs are reruns. Tests already cover this for bootstrap and init.
- **Frequent commits**: each task ends with a commit. Don't squash — small commits make bisection easier if something goes wrong.
