# Context Management Toolkit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a profile-based context management toolkit that reduces Claude Code token usage through skill symlinks, `.claudeignore` management, MCP/LSP toggling, and document lifecycle automation.

**Architecture:** Justfile recipes call shell scripts that manipulate symlinks, config files, and ignore patterns. Profile definitions in YAML drive all behavior. Projects import a single Justfile from the central clone.

**Tech Stack:** Justfile, Bash scripts, YAML (parsed with `yq`), Claude Code CLI for MCP management

---

## File Structure

```
agent-skills/
├── Justfile                              # Importable recipes (new)
├── profiles/                             # Profile definitions (new)
│   ├── brainstorm.yml
│   ├── design.yml
│   ├── code.yml
│   ├── ship.yml
│   └── minimal.yml
├── scripts/                              # Shell scripts (new)
│   ├── profile-activate.sh
│   ├── skill-add.sh
│   ├── skill-rm.sh
│   ├── claudeignore-sync.sh
│   ├── mcp-configure.sh
│   ├── doc-archive.sh
│   ├── index-rebuild.sh
│   └── profile-lock.sh
├── hooks/                                # Claude Code hooks (new)
│   ├── pre-session.sh
│   └── post-session.sh
├── templates/                            # Templates (new)
│   └── decision-record.md
├── mcps/                                 # MCP definitions (new)
│   ├── context7.yml
│   ├── postgres.yml
│   └── browser.yml
├── lsps/                                 # LSP definitions (new)
│   ├── typescript.yml
│   └── python.yml
├── skills/
│   ├── ship-it/SKILL.md                  # New (replaces branch-push-pr)
│   ├── repo-automation-setup/SKILL.md    # Existing
│   └── commit-history-rewrite/SKILL.md   # Existing
├── .github/skills/                       # Existing skills (source of truth)
├── README.md                             # Rewrite (existing file)
└── docs/
```

---

### Task 1: Core Infrastructure — Profile Lock & `.claudeignore` Sync Scripts

**Files:**
- Create: `scripts/profile-lock.sh`
- Create: `scripts/claudeignore-sync.sh`

These are foundational utilities used by all other scripts.

- [ ] **Step 1: Create `scripts/profile-lock.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Profile lock management: acquire, release, check
# Lock file: .claude-profile.lock in the project root

LOCK_FILE=".claude-profile.lock"

usage() {
  echo "Usage: $0 {acquire|release|check|current} [profile_name]"
  exit 1
}

acquire() {
  local profile="$1"
  if [[ -f "$LOCK_FILE" ]]; then
    local existing_pid existing_profile
    existing_pid=$(sed -n '1p' "$LOCK_FILE")
    existing_profile=$(sed -n '2p' "$LOCK_FILE")
    if kill -0 "$existing_pid" 2>/dev/null; then
      echo "ERROR: Profile '$existing_profile' is active (PID $existing_pid)." >&2
      echo "Run 'just claude-minimal' to deactivate, or use a different worktree." >&2
      exit 1
    fi
    # Stale lock — clean up
    rm -f "$LOCK_FILE"
  fi
  echo "$$" > "$LOCK_FILE"
  echo "$profile" >> "$LOCK_FILE"
}

release() {
  rm -f "$LOCK_FILE"
}

check() {
  if [[ ! -f "$LOCK_FILE" ]]; then
    echo "none"
    exit 0
  fi
  local existing_pid existing_profile
  existing_pid=$(sed -n '1p' "$LOCK_FILE")
  existing_profile=$(sed -n '2p' "$LOCK_FILE")
  if kill -0 "$existing_pid" 2>/dev/null; then
    echo "$existing_profile"
  else
    # Stale lock
    rm -f "$LOCK_FILE"
    echo "none"
  fi
}

current() {
  check
}

case "${1:-}" in
  acquire) acquire "${2:?Profile name required}" ;;
  release) release ;;
  check|current) current ;;
  *) usage ;;
esac
```

- [ ] **Step 2: Create `scripts/claudeignore-sync.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Manages the agent-skills section in .claudeignore
# Usage: claudeignore-sync.sh <patterns_file|->
# Reads patterns from file or stdin (one per line)
# Pass empty input to clear the managed section

CLAUDEIGNORE=".claudeignore"
START_MARKER="# --- agent-skills:managed:start ---"
END_MARKER="# --- agent-skills:managed:end ---"
MANAGED_COMMENT="# Auto-managed by agent-skills profiles. Do not edit this section."

# Read new patterns from argument file or stdin
if [[ "${1:-}" == "-" ]] || [[ -z "${1:-}" ]]; then
  new_patterns=$(cat)
else
  new_patterns=$(cat "$1")
fi

# If .claudeignore doesn't exist, create it with markers
if [[ ! -f "$CLAUDEIGNORE" ]]; then
  {
    echo "$START_MARKER"
    echo "$MANAGED_COMMENT"
    echo "$new_patterns"
    echo "$END_MARKER"
  } > "$CLAUDEIGNORE"
  exit 0
fi

# If markers don't exist, append them
if ! grep -qF "$START_MARKER" "$CLAUDEIGNORE"; then
  {
    echo ""
    echo "$START_MARKER"
    echo "$MANAGED_COMMENT"
    echo "$new_patterns"
    echo "$END_MARKER"
  } >> "$CLAUDEIGNORE"
  exit 0
fi

# Replace content between markers
tmp=$(mktemp)
in_managed=false
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" == "$START_MARKER" ]]; then
    echo "$START_MARKER" >> "$tmp"
    echo "$MANAGED_COMMENT" >> "$tmp"
    echo "$new_patterns" >> "$tmp"
    in_managed=true
  elif [[ "$line" == "$END_MARKER" ]]; then
    echo "$END_MARKER" >> "$tmp"
    in_managed=false
  elif [[ "$in_managed" == false ]]; then
    echo "$line" >> "$tmp"
  fi
done < "$CLAUDEIGNORE"
mv "$tmp" "$CLAUDEIGNORE"
```

- [ ] **Step 3: Make scripts executable and test**

Run:
```bash
chmod +x scripts/profile-lock.sh scripts/claudeignore-sync.sh
```

Test lock:
```bash
./scripts/profile-lock.sh check
# Expected: "none"
./scripts/profile-lock.sh acquire brainstorm
cat .claude-profile.lock
# Expected: PID on line 1, "brainstorm" on line 2
./scripts/profile-lock.sh check
# Expected: "brainstorm"
./scripts/profile-lock.sh release
./scripts/profile-lock.sh check
# Expected: "none"
rm -f .claude-profile.lock
```

Test claudeignore:
```bash
echo -e "src/**\ntests/**" | ./scripts/claudeignore-sync.sh -
cat .claudeignore
# Expected: markers with src/** and tests/** inside
echo "" | ./scripts/claudeignore-sync.sh -
cat .claudeignore
# Expected: markers with empty managed section
rm -f .claudeignore
```

- [ ] **Step 4: Commit**

```bash
git add scripts/profile-lock.sh scripts/claudeignore-sync.sh
git commit -m "feat(scripts): add profile lock and claudeignore sync utilities"
```

---

### Task 2: Profile Definitions

**Files:**
- Create: `profiles/brainstorm.yml`
- Create: `profiles/design.yml`
- Create: `profiles/code.yml`
- Create: `profiles/ship.yml`
- Create: `profiles/minimal.yml`

- [ ] **Step 1: Create `profiles/brainstorm.yml`**

```yaml
name: brainstorm
description: "Ideation, spec writing, and design exploration"

skills:
  - brainstorming
  - idea-refine
  - spec-driven-development
  - planning-and-task-breakdown
  - writing-plans
  - context-engineering
  - documentation-and-adrs

mcps:
  - context7

claudeignore:
  - "src/**"
  - "tests/**"
  - "dist/**"
  - "build/**"
  - "node_modules/**"
  - "docs/superpowers/archive/**"

hooks:
  pre_session: true
  post_session: false
```

- [ ] **Step 2: Create `profiles/design.yml`**

```yaml
name: design
description: "UI/UX design, mockups, and visual work"

skills:
  - frontend-ui-engineering
  - browser-testing-with-devtools
  - brainstorming
  - spec-driven-development
  - writing-plans

mcps:
  - context7
  - browser

claudeignore:
  - "tests/**"
  - "dist/**"
  - "build/**"
  - "node_modules/**"
  - "docs/superpowers/archive/**"

hooks:
  pre_session: true
  post_session: false
```

- [ ] **Step 3: Create `profiles/code.yml`**

```yaml
name: code
description: "Implementation, debugging, testing, and committing"

skills:
  - incremental-implementation
  - test-driven-development
  - systematic-debugging
  - debugging-and-error-recovery
  - git-workflow-and-versioning
  - security-and-hardening
  - verification-before-completion

mcps:
  - context7

claudeignore:
  - "docs/superpowers/archive/**"

hooks:
  pre_session: true
  post_session: false
```

- [ ] **Step 4: Create `profiles/ship.yml`**

```yaml
name: ship
description: "Push, PR, archive decisions, merge cleanup"

skills:
  - ship-it
  - finishing-a-development-branch
  - code-review-and-quality

mcps:
  - context7

claudeignore:
  - "docs/superpowers/archive/**"

hooks:
  pre_session: true
  post_session: true
```

- [ ] **Step 5: Create `profiles/minimal.yml`**

```yaml
name: minimal
description: "Dormant state — no skills, no MCPs, no ignore patterns"

skills: []

mcps: []

claudeignore: []

hooks:
  pre_session: false
  post_session: false
```

- [ ] **Step 6: Commit**

```bash
git add profiles/
git commit -m "feat(profiles): add brainstorm, design, code, ship, and minimal profiles"
```

---

### Task 3: Profile Activation Script

**Files:**
- Create: `scripts/profile-activate.sh`

- [ ] **Step 1: Create `scripts/profile-activate.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Activate a profile: symlink skills, configure MCPs, sync .claudeignore
# Usage: profile-activate.sh <profile_name> [project_dir]
# Requires: yq (https://github.com/mikefarah/yq)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="${2:-$(pwd)}"
PROFILE_NAME="${1:?Usage: profile-activate.sh <profile_name> [project_dir]}"
PROFILE_FILE="$AGENT_SKILLS_DIR/profiles/${PROFILE_NAME}.yml"

if [[ ! -f "$PROFILE_FILE" ]]; then
  echo "ERROR: Profile '$PROFILE_NAME' not found at $PROFILE_FILE" >&2
  echo "Available profiles:" >&2
  ls "$AGENT_SKILLS_DIR/profiles/"*.yml 2>/dev/null | xargs -I{} basename {} .yml >&2
  exit 1
fi

# Check for yq
if ! command -v yq &>/dev/null; then
  echo "ERROR: 'yq' is required but not installed." >&2
  echo "Install: https://github.com/mikefarah/yq#install" >&2
  exit 1
fi

cd "$PROJECT_DIR"

# Step 1: Acquire lock
"$SCRIPT_DIR/profile-lock.sh" acquire "$PROFILE_NAME"

# Step 2: Ensure .github/skills/ exists
mkdir -p .github/skills

# Step 3: Remove existing symlinks (only symlinks, never real files/dirs)
find .github/skills -maxdepth 1 -type l -exec rm {} \;

# Step 4: Read skills from profile
mapfile -t skills < <(yq -r '.skills[]' "$PROFILE_FILE" 2>/dev/null || true)

# Step 5: Merge project overrides if .claude-profiles.yml exists
if [[ -f ".claude-profiles.yml" ]]; then
  mapfile -t skills_add < <(yq -r ".${PROFILE_NAME}.skills_add // [] | .[]" ".claude-profiles.yml" 2>/dev/null || true)
  mapfile -t skills_remove < <(yq -r ".${PROFILE_NAME}.skills_remove // [] | .[]" ".claude-profiles.yml" 2>/dev/null || true)

  # Add project-specific skills
  for skill in "${skills_add[@]}"; do
    [[ -n "$skill" ]] && skills+=("$skill")
  done

  # Remove excluded skills
  for remove in "${skills_remove[@]}"; do
    skills=("${skills[@]/$remove/}")
  done
fi

# Step 6: Create symlinks
linked=0
for skill in "${skills[@]}"; do
  [[ -z "$skill" ]] && continue
  source_dir="$AGENT_SKILLS_DIR/.github/skills/$skill"
  if [[ -d "$source_dir" ]]; then
    ln -sf "$source_dir" ".github/skills/$skill"
    ((linked++))
  else
    echo "WARNING: Skill '$skill' not found in $AGENT_SKILLS_DIR/.github/skills/" >&2
  fi
done

# Step 7: Sync .claudeignore
patterns=$(yq -r '.claudeignore // [] | .[]' "$PROFILE_FILE" 2>/dev/null || true)
echo "$patterns" | "$SCRIPT_DIR/claudeignore-sync.sh" -

# Step 8: Configure MCPs
"$SCRIPT_DIR/mcp-configure.sh" "$PROFILE_NAME" "$PROJECT_DIR" 2>/dev/null || true

# Step 9: Report
echo ""
echo "✓ Profile '$PROFILE_NAME' activated"
echo "  Skills: $linked symlinked"
echo "  Directory: $PROJECT_DIR/.github/skills/"
echo ""
echo "Active skills:"
for skill in "${skills[@]}"; do
  [[ -z "$skill" ]] && continue
  desc=$(yq -r '.description // "No description"' "$AGENT_SKILLS_DIR/.github/skills/$skill/SKILL.md" 2>/dev/null | head -1 || echo "")
  echo "  - $skill"
done
echo ""
echo "Run 'just claude-active-skills' for details or 'just claude-add-skill <name>' to add more."
```

- [ ] **Step 2: Make executable and test**

```bash
chmod +x scripts/profile-activate.sh
```

Test (dry run — will need yq installed):
```bash
which yq || echo "Install yq first: https://github.com/mikefarah/yq#install"
```

- [ ] **Step 3: Commit**

```bash
git add scripts/profile-activate.sh
git commit -m "feat(scripts): add profile activation script"
```

---

### Task 4: Skill Add/Remove Scripts

**Files:**
- Create: `scripts/skill-add.sh`
- Create: `scripts/skill-rm.sh`

- [ ] **Step 1: Create `scripts/skill-add.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Add a skill on top of the current profile
# Usage: skill-add.sh <skill_name>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_NAME="${1:?Usage: skill-add.sh <skill_name>}"

source_dir="$AGENT_SKILLS_DIR/.github/skills/$SKILL_NAME"

if [[ ! -d "$source_dir" ]]; then
  echo "ERROR: Skill '$SKILL_NAME' not found." >&2
  echo "Available skills:" >&2
  ls "$AGENT_SKILLS_DIR/.github/skills/" >&2
  exit 1
fi

mkdir -p .github/skills

if [[ -L ".github/skills/$SKILL_NAME" ]]; then
  echo "Skill '$SKILL_NAME' is already active."
  exit 0
fi

ln -sf "$source_dir" ".github/skills/$SKILL_NAME"
echo "✓ Added skill: $SKILL_NAME"
```

- [ ] **Step 2: Create `scripts/skill-rm.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Remove a skill from the current profile
# Usage: skill-rm.sh <skill_name>

SKILL_NAME="${1:?Usage: skill-rm.sh <skill_name>}"

target=".github/skills/$SKILL_NAME"

if [[ ! -L "$target" ]]; then
  if [[ -d "$target" ]]; then
    echo "ERROR: '$SKILL_NAME' is a real directory, not a symlink. Won't remove." >&2
    exit 1
  fi
  echo "Skill '$SKILL_NAME' is not active."
  exit 0
fi

rm "$target"
echo "✓ Removed skill: $SKILL_NAME"
```

- [ ] **Step 3: Make executable and test**

```bash
chmod +x scripts/skill-add.sh scripts/skill-rm.sh
```

- [ ] **Step 4: Commit**

```bash
git add scripts/skill-add.sh scripts/skill-rm.sh
git commit -m "feat(scripts): add skill add/remove scripts"
```

---

### Task 5: MCP Configuration Script

**Files:**
- Create: `scripts/mcp-configure.sh`
- Create: `mcps/context7.yml`
- Create: `mcps/postgres.yml`
- Create: `mcps/browser.yml`

- [ ] **Step 1: Create MCP definition files**

`mcps/context7.yml`:
```yaml
name: context7
description: "Documentation lookup for any library/framework"
install: "claude mcp add context7 -- npx -y @upstash/context7-mcp"
remove: "claude mcp remove context7"
profiles: [brainstorm, design, code, ship]
languages: []
```

`mcps/postgres.yml`:
```yaml
name: postgres
description: "Query and manage PostgreSQL databases"
install: "claude mcp add postgres -- npx -y @anthropic/mcp-postgres"
remove: "claude mcp remove postgres"
profiles: [code]
languages: [typescript, python]
```

`mcps/browser.yml`:
```yaml
name: browser
description: "Browser automation and visual testing via DevTools"
install: "claude mcp add browser -- npx -y @anthropic/mcp-browser"
remove: "claude mcp remove browser"
profiles: [design, code]
languages: []
```

- [ ] **Step 2: Create `scripts/mcp-configure.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Configure MCPs based on active profile + project config
# Usage: mcp-configure.sh <profile_name> [project_dir]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE_NAME="${1:?Usage: mcp-configure.sh <profile_name>}"
PROJECT_DIR="${2:-$(pwd)}"
MCPS_DIR="$AGENT_SKILLS_DIR/mcps"

if ! command -v yq &>/dev/null; then
  echo "WARNING: 'yq' not installed — skipping MCP configuration." >&2
  exit 0
fi

# Gather desired MCPs from profile
PROFILE_FILE="$AGENT_SKILLS_DIR/profiles/${PROFILE_NAME}.yml"
mapfile -t profile_mcps < <(yq -r '.mcps // [] | .[]' "$PROFILE_FILE" 2>/dev/null || true)

# Gather project-level MCPs from .claude-profiles.yml
project_mcps=()
if [[ -f "$PROJECT_DIR/.claude-profiles.yml" ]]; then
  mapfile -t project_mcps < <(yq -r '.mcps // [] | .[]' "$PROJECT_DIR/.claude-profiles.yml" 2>/dev/null || true)

  # Profile-specific MCP overrides
  mapfile -t mcps_add < <(yq -r ".${PROFILE_NAME}.mcps_add // [] | .[]" "$PROJECT_DIR/.claude-profiles.yml" 2>/dev/null || true)
  mapfile -t mcps_remove < <(yq -r ".${PROFILE_NAME}.mcps_remove // [] | .[]" "$PROJECT_DIR/.claude-profiles.yml" 2>/dev/null || true)
fi

# Merge: profile MCPs + project MCPs + profile-specific adds
desired_mcps=("${profile_mcps[@]}" "${project_mcps[@]}" "${mcps_add[@]:-}")

# Remove excluded
for remove in "${mcps_remove[@]:-}"; do
  desired_mcps=("${desired_mcps[@]/$remove/}")
done

# Deduplicate
mapfile -t desired_mcps < <(printf '%s\n' "${desired_mcps[@]}" | grep -v '^$' | sort -u)

# Get currently installed MCPs (best effort)
current_mcps=()
if command -v claude &>/dev/null; then
  mapfile -t current_mcps < <(claude mcp list 2>/dev/null | awk '{print $1}' || true)
fi

# Activate desired MCPs that aren't installed
for mcp in "${desired_mcps[@]}"; do
  [[ -z "$mcp" ]] && continue
  mcp_file="$MCPS_DIR/${mcp}.yml"
  if [[ ! -f "$mcp_file" ]]; then
    echo "WARNING: MCP definition '$mcp' not found in $MCPS_DIR/" >&2
    continue
  fi

  # Check if already installed
  already_installed=false
  for current in "${current_mcps[@]}"; do
    [[ "$current" == "$mcp" ]] && already_installed=true && break
  done

  if [[ "$already_installed" == false ]]; then
    install_cmd=$(yq -r '.install' "$mcp_file")
    echo "Installing MCP: $mcp"
    eval "$install_cmd" || echo "WARNING: Failed to install MCP '$mcp'" >&2
  fi
done

# Report
echo ""
echo "MCPs for profile '$PROFILE_NAME':"
for mcp in "${desired_mcps[@]}"; do
  [[ -z "$mcp" ]] && continue
  mcp_file="$MCPS_DIR/${mcp}.yml"
  if [[ -f "$mcp_file" ]]; then
    desc=$(yq -r '.description' "$mcp_file")
    echo "  ✓ $mcp — $desc"
  else
    echo "  ? $mcp — (no definition file)"
  fi
done
```

- [ ] **Step 3: Make executable**

```bash
chmod +x scripts/mcp-configure.sh
```

- [ ] **Step 4: Commit**

```bash
git add mcps/ scripts/mcp-configure.sh
git commit -m "feat(mcps): add MCP definitions and configuration script"
```

---

### Task 6: LSP Definitions

**Files:**
- Create: `lsps/typescript.yml`
- Create: `lsps/python.yml`

- [ ] **Step 1: Create LSP definitions**

`lsps/typescript.yml`:
```yaml
name: typescript
description: "TypeScript/JavaScript language intelligence"
install: "npm install -g typescript-language-server typescript"
detect: ["package.json", "tsconfig.json"]
```

`lsps/python.yml`:
```yaml
name: python
description: "Python language intelligence (pylsp)"
install: "pip install python-lsp-server[all]"
detect: ["pyproject.toml", "requirements.txt", "setup.py", "Pipfile"]
```

- [ ] **Step 2: Commit**

```bash
git add lsps/
git commit -m "feat(lsps): add TypeScript and Python LSP definitions"
```

---

### Task 7: Document Lifecycle Scripts & Template

**Files:**
- Create: `scripts/doc-archive.sh`
- Create: `scripts/index-rebuild.sh`
- Create: `templates/decision-record.md`

- [ ] **Step 1: Create `templates/decision-record.md`**

```markdown
---
title: {{TITLE}}
date: {{DATE}}
component: {{COMPONENT}}
status: implemented
supersedes: null
dependencies: []
---

## Decisions

- [Key decisions made, one per bullet]

## Interfaces

- [Public APIs, endpoints, type signatures, contracts]

## Constraints

- [Hard limits, policies, non-negotiable requirements]
```

- [ ] **Step 2: Create `scripts/index-rebuild.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Rebuild the master decision index from decision record frontmatter
# Usage: index-rebuild.sh [decisions_dir] [output_file]

DECISIONS_DIR="${1:-docs/superpowers/decisions}"
INDEX_FILE="${2:-docs/superpowers/index.md}"

if [[ ! -d "$DECISIONS_DIR" ]]; then
  echo "No decisions directory found at $DECISIONS_DIR"
  exit 0
fi

if ! command -v yq &>/dev/null; then
  echo "ERROR: 'yq' is required for index generation." >&2
  exit 1
fi

# Collect records
active_rows=""
superseded_rows=""

for file in "$DECISIONS_DIR"/*.md; do
  [[ ! -f "$file" ]] && continue

  # Extract YAML frontmatter
  title=$(sed -n '/^---$/,/^---$/p' "$file" | yq -r '.title // "Untitled"' 2>/dev/null || echo "Untitled")
  date=$(sed -n '/^---$/,/^---$/p' "$file" | yq -r '.date // "Unknown"' 2>/dev/null || echo "Unknown")
  component=$(sed -n '/^---$/,/^---$/p' "$file" | yq -r '.component // "general"' 2>/dev/null || echo "general")
  status=$(sed -n '/^---$/,/^---$/p' "$file" | yq -r '.status // "implemented"' 2>/dev/null || echo "implemented")
  supersedes=$(sed -n '/^---$/,/^---$/p' "$file" | yq -r '.supersedes // "null"' 2>/dev/null || echo "null")
  deps=$(sed -n '/^---$/,/^---$/p' "$file" | yq -r '.dependencies // [] | join(", ")' 2>/dev/null || echo "")

  if [[ "$status" == "superseded" ]]; then
    superseded_rows+="| $component | $title | $supersedes |\n"
  else
    active_rows+="| $component | $title | $date | $deps |\n"
  fi
done

# Write index
mkdir -p "$(dirname "$INDEX_FILE")"
cat > "$INDEX_FILE" <<EOF
# Project Decision Index

## Active Decisions

| Component | Title | Date | Dependencies |
|-----------|-------|------|--------------|
$(echo -e "$active_rows")

## Superseded

| Component | Title | Superseded By |
|-----------|-------|---------------|
$(echo -e "$superseded_rows")
EOF

echo "✓ Index rebuilt: $INDEX_FILE ($(echo -e "$active_rows" | grep -c '|' || echo 0) active records)"
```

- [ ] **Step 3: Create `scripts/doc-archive.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Identify unconverted specs/plans and generate a conversion prompt
# Usage: doc-archive.sh [specs_dir] [plans_dir] [decisions_dir] [archive_dir]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECS_DIR="${1:-docs/superpowers/specs}"
PLANS_DIR="${2:-docs/superpowers/plans}"
DECISIONS_DIR="${3:-docs/superpowers/decisions}"
ARCHIVE_DIR="${4:-docs/superpowers/archive}"

# Find unconverted specs (no matching decision record)
unconverted=()

if [[ -d "$SPECS_DIR" ]]; then
  for spec in "$SPECS_DIR"/*.md; do
    [[ ! -f "$spec" ]] && continue
    basename=$(basename "$spec")
    # Strip date prefix and -design suffix for matching
    stem=$(echo "$basename" | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-//; s/-design\.md$//')

    # Check if a decision record exists with this stem
    found=false
    if [[ -d "$DECISIONS_DIR" ]]; then
      for decision in "$DECISIONS_DIR"/*"$stem"*.md; do
        [[ -f "$decision" ]] && found=true && break
      done
    fi

    if [[ "$found" == false ]]; then
      unconverted+=("$spec")
    fi
  done
fi

if [[ ${#unconverted[@]} -eq 0 ]]; then
  echo "✓ All specs have corresponding decision records. Nothing to archive."
  exit 0
fi

echo "Unconverted specs (${#unconverted[@]}):"
for spec in "${unconverted[@]}"; do
  echo "  - $spec"
done
echo ""

# Generate conversion prompt
TEMPLATE=$(cat "$SCRIPT_DIR/../templates/decision-record.md")

echo "=== CONVERSION PROMPT ==="
echo ""
echo "Paste the following into a Claude session to convert these specs:"
echo ""
echo "---"
echo ""
echo "Convert the following specs into compact decision records. For each spec:"
echo "1. Read the spec file"
echo "2. Create a decision record in $DECISIONS_DIR/ using this template:"
echo ""
echo "$TEMPLATE"
echo ""
echo "3. Move the original spec to $ARCHIVE_DIR/specs/"
echo "4. If there's a matching plan in $PLANS_DIR/, move it to $ARCHIVE_DIR/plans/"
echo ""
echo "Specs to convert:"
for spec in "${unconverted[@]}"; do
  echo "  - $spec"
done
echo ""
echo "After conversion, run: just claude-rebuild-index"
echo ""
echo "---"
```

- [ ] **Step 4: Make executable**

```bash
chmod +x scripts/doc-archive.sh scripts/index-rebuild.sh
```

- [ ] **Step 5: Commit**

```bash
git add templates/ scripts/doc-archive.sh scripts/index-rebuild.sh
git commit -m "feat(docs): add decision record template, archive, and index rebuild scripts"
```

---

### Task 8: Hook Scripts

**Files:**
- Create: `hooks/pre-session.sh`
- Create: `hooks/post-session.sh`

- [ ] **Step 1: Create `hooks/pre-session.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Pre-session hook: validate profile state
# Called before Claude Code starts a session

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check if profile is active
if [[ -f ".claude-profile.lock" ]]; then
  profile=$(sed -n '2p' .claude-profile.lock)
  pid=$(sed -n '1p' .claude-profile.lock)

  # Check if lock is stale
  if ! kill -0 "$pid" 2>/dev/null; then
    rm -f .claude-profile.lock
    echo "⚠ Stale profile lock cleaned up. No profile active."
    echo "  Run: just claude-<profile> to activate one."
    exit 0
  fi

  # Validate symlinks are intact
  broken=0
  for link in .github/skills/*/; do
    [[ ! -L "${link%/}" ]] && continue
    if [[ ! -e "${link%/}" ]]; then
      ((broken++))
    fi
  done

  if [[ $broken -gt 0 ]]; then
    echo "⚠ Profile '$profile' has $broken broken skill symlinks."
    echo "  Run: just claude-$profile to refresh."
  fi
else
  echo "ℹ No profile active. Run: just claude-<profile>"
  echo "  Available: brainstorm, design, code, ship, minimal"
fi
```

- [ ] **Step 2: Create `hooks/post-session.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Post-session hook: optionally revert to minimal
# Only acts if the active profile has post_session: true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ ! -f ".claude-profile.lock" ]]; then
  exit 0
fi

profile=$(sed -n '2p' .claude-profile.lock)
PROFILE_FILE="$AGENT_SKILLS_DIR/profiles/${profile}.yml"

if [[ ! -f "$PROFILE_FILE" ]]; then
  exit 0
fi

# Check if post_session is enabled for this profile
if command -v yq &>/dev/null; then
  post_session=$(yq -r '.hooks.post_session // false' "$PROFILE_FILE")
  if [[ "$post_session" == "true" ]]; then
    echo "Profile '$profile' auto-reverting to minimal..."
    "$SCRIPT_DIR/../scripts/profile-activate.sh" minimal
  fi
fi
```

- [ ] **Step 3: Make executable**

```bash
chmod +x hooks/pre-session.sh hooks/post-session.sh
```

- [ ] **Step 4: Commit**

```bash
git add hooks/
git commit -m "feat(hooks): add pre-session and post-session hook scripts"
```

---

### Task 9: The Justfile

**Files:**
- Create: `Justfile`

- [ ] **Step 1: Create `Justfile`**

```justfile
# Agent Skills — Context Management Toolkit
# Import this from your project: import "~/local/agent-skills/Justfile"

# Path to this repo (auto-detected from Justfile location)
_agent_skills_dir := justfile_directory()

# --- Profiles ---

# Activate brainstorm profile (ideation, specs, plans)
claude-brainstorm:
    @{{_agent_skills_dir}}/scripts/profile-activate.sh brainstorm

# Activate design profile (UI/UX, mockups, browser)
claude-design:
    @{{_agent_skills_dir}}/scripts/profile-activate.sh design

# Activate code profile (implementation, debug, test, commit)
claude-code:
    @{{_agent_skills_dir}}/scripts/profile-activate.sh code

# Activate ship profile (push, PR, archive, cleanup)
claude-ship:
    @{{_agent_skills_dir}}/scripts/profile-activate.sh ship

# Deactivate all — dormant state
claude-minimal:
    @{{_agent_skills_dir}}/scripts/profile-activate.sh minimal

# Show current profile and any overrides
claude-active-profile:
    @{{_agent_skills_dir}}/scripts/profile-lock.sh current

# --- Skills ---

# List all available skills with descriptions and profile associations
claude-list-skills:
    #!/usr/bin/env bash
    echo "Available skills:"
    echo ""
    for dir in "{{_agent_skills_dir}}"/.github/skills/*/; do
      skill=$(basename "$dir")
      desc=""
      if [[ -f "$dir/SKILL.md" ]]; then
        desc=$(grep -m1 '^description:' "$dir/SKILL.md" 2>/dev/null | sed 's/^description: *//' | head -c 80 || true)
      fi
      # Find which profiles include this skill
      profiles=""
      for pfile in "{{_agent_skills_dir}}"/profiles/*.yml; do
        pname=$(basename "$pfile" .yml)
        if yq -r '.skills // [] | .[]' "$pfile" 2>/dev/null | grep -qx "$skill"; then
          profiles+="$pname,"
        fi
      done
      profiles="${profiles%,}"
      printf "  %-35s [%s]\n" "$skill" "${profiles:-none}"
      if [[ -n "$desc" ]]; then
        printf "    %s\n" "$desc"
      fi
    done

# List currently active skills with descriptions
claude-list-active-skills:
    #!/usr/bin/env bash
    echo "Active skills:"
    echo ""
    for link in .github/skills/*/; do
      [[ ! -L "${link%/}" ]] && continue
      skill=$(basename "$link")
      desc=""
      if [[ -f "$link/SKILL.md" ]]; then
        desc=$(grep -m1 '^description:' "$link/SKILL.md" 2>/dev/null | sed 's/^description: *//' | head -c 80 || true)
      fi
      echo "  - $skill"
      if [[ -n "$desc" ]]; then
        echo "    $desc"
      fi
    done

# Add a skill on top of current profile
claude-add-skill skill:
    @{{_agent_skills_dir}}/scripts/skill-add.sh {{skill}}

# Remove a skill from current profile
claude-rm-skill skill:
    @{{_agent_skills_dir}}/scripts/skill-rm.sh {{skill}}

# --- MCPs ---

# List all available MCPs with descriptions
claude-list-mcps:
    #!/usr/bin/env bash
    echo "Available MCPs:"
    echo ""
    for mcp_file in "{{_agent_skills_dir}}"/mcps/*.yml; do
      [[ ! -f "$mcp_file" ]] && continue
      name=$(yq -r '.name' "$mcp_file")
      desc=$(yq -r '.description' "$mcp_file")
      profiles=$(yq -r '.profiles // [] | join(", ")' "$mcp_file")
      printf "  %-20s [%s]\n" "$name" "$profiles"
      printf "    %s\n" "$desc"
    done

# List MCPs configured for this project
claude-list-active-mcps:
    #!/usr/bin/env bash
    echo "Active MCPs for this project:"
    echo ""
    if command -v claude &>/dev/null; then
      claude mcp list 2>/dev/null || echo "  (could not query claude mcp list)"
    else
      echo "  (claude CLI not found)"
    fi
    echo ""
    if [[ -f ".claude-profiles.yml" ]]; then
      echo "Project config (.claude-profiles.yml):"
      yq -r '.mcps // [] | .[]' .claude-profiles.yml 2>/dev/null | sed 's/^/  - /'
    fi

# Add an MCP to this project
claude-add-mcp mcp:
    #!/usr/bin/env bash
    mcp_file="{{_agent_skills_dir}}/mcps/{{mcp}}.yml"
    if [[ ! -f "$mcp_file" ]]; then
      echo "ERROR: MCP '{{mcp}}' not found." >&2
      echo "Available:" >&2
      ls "{{_agent_skills_dir}}"/mcps/*.yml 2>/dev/null | xargs -I{} basename {} .yml >&2
      exit 1
    fi
    # Add to .claude-profiles.yml
    if [[ ! -f ".claude-profiles.yml" ]]; then
      echo "mcps:" > .claude-profiles.yml
    fi
    if ! yq -r '.mcps // [] | .[]' .claude-profiles.yml 2>/dev/null | grep -qx "{{mcp}}"; then
      yq -i '.mcps += ["{{mcp}}"]' .claude-profiles.yml
      echo "✓ Added '{{mcp}}' to .claude-profiles.yml"
    else
      echo "'{{mcp}}' already in .claude-profiles.yml"
    fi
    # Install
    install_cmd=$(yq -r '.install' "$mcp_file")
    echo "Installing: $install_cmd"
    eval "$install_cmd"

# Remove an MCP from this project
claude-rm-mcp mcp:
    #!/usr/bin/env bash
    if [[ -f ".claude-profiles.yml" ]]; then
      yq -i 'del(.mcps[] | select(. == "{{mcp}}"))' .claude-profiles.yml
      echo "✓ Removed '{{mcp}}' from .claude-profiles.yml"
    fi
    mcp_file="{{_agent_skills_dir}}/mcps/{{mcp}}.yml"
    if [[ -f "$mcp_file" ]]; then
      remove_cmd=$(yq -r '.remove // ""' "$mcp_file")
      if [[ -n "$remove_cmd" ]]; then
        echo "Removing: $remove_cmd"
        eval "$remove_cmd" || true
      fi
    fi

# --- LSPs ---

# List all available LSPs
claude-list-lsps:
    #!/usr/bin/env bash
    echo "Available LSPs:"
    echo ""
    for lsp_file in "{{_agent_skills_dir}}"/lsps/*.yml; do
      [[ ! -f "$lsp_file" ]] && continue
      name=$(yq -r '.name' "$lsp_file")
      desc=$(yq -r '.description' "$lsp_file")
      detect=$(yq -r '.detect // [] | join(", ")' "$lsp_file")
      printf "  %-20s %s\n" "$name" "$desc"
      printf "    Detected by: %s\n" "$detect"
    done

# Install an LSP server
claude-setup-lsp lsp:
    #!/usr/bin/env bash
    lsp_file="{{_agent_skills_dir}}/lsps/{{lsp}}.yml"
    if [[ ! -f "$lsp_file" ]]; then
      echo "ERROR: LSP '{{lsp}}' not found." >&2
      exit 1
    fi
    install_cmd=$(yq -r '.install' "$lsp_file")
    echo "Installing LSP: {{lsp}}"
    eval "$install_cmd"
    echo "✓ LSP '{{lsp}}' installed"

# --- Docs & Archive ---

# Identify unconverted specs/plans and generate conversion prompt
claude-update-archive:
    @{{_agent_skills_dir}}/scripts/doc-archive.sh

# Rebuild master decision index from decision records
claude-rebuild-index:
    @{{_agent_skills_dir}}/scripts/index-rebuild.sh

# --- Setup ---

# Interactive first-time project setup
claude-init:
    @{{_agent_skills_dir}}/scripts/claude-init.sh

# Show all available commands
claude-help:
    #!/usr/bin/env bash
    echo ""
    echo "Agent Skills — Context Management Toolkit"
    echo "=========================================="
    echo ""
    echo "PROFILES (activate a mode for your Claude session):"
    echo "  just claude-brainstorm      Ideation, specs, plans"
    echo "  just claude-design          UI/UX, mockups, browser testing"
    echo "  just claude-code            Implementation, debug, test, commit"
    echo "  just claude-ship            Push, PR, archive decisions, cleanup"
    echo "  just claude-minimal         Deactivate all (dormant state)"
    echo "  just claude-active-profile  Show current profile"
    echo ""
    echo "SKILLS (manage individual skills):"
    echo "  just claude-list-skills         All skills + profile associations"
    echo "  just claude-list-active-skills  Currently active skills"
    echo "  just claude-add-skill <name>    Add skill to current profile"
    echo "  just claude-rm-skill <name>     Remove skill from current profile"
    echo ""
    echo "MCPs (Model Context Protocol servers):"
    echo "  just claude-list-mcps           All available MCPs"
    echo "  just claude-list-active-mcps    MCPs configured for this project"
    echo "  just claude-add-mcp <name>      Add + install MCP"
    echo "  just claude-rm-mcp <name>       Remove MCP"
    echo ""
    echo "LSPs (Language Server Protocol):"
    echo "  just claude-list-lsps           All available LSPs"
    echo "  just claude-setup-lsp <name>    Install an LSP"
    echo ""
    echo "DOCS & ARCHIVE:"
    echo "  just claude-update-archive      Find unconverted specs, generate prompt"
    echo "  just claude-rebuild-index       Rebuild decision index"
    echo ""
    echo "SETUP:"
    echo "  just claude-init                First-time project setup"
    echo "  just claude-help                This help message"
    echo ""
```

- [ ] **Step 2: Test Justfile syntax**

```bash
just --list --justfile Justfile
```

Expected: all recipes listed without errors.

- [ ] **Step 3: Commit**

```bash
git add Justfile
git commit -m "feat: add importable Justfile with all claude-* recipes"
```

---

### Task 10: `claude-init` Script

**Files:**
- Create: `scripts/claude-init.sh`

- [ ] **Step 1: Create `scripts/claude-init.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Interactive first-time project setup
# Usage: claude-init.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ""
echo "🔧 Agent Skills — Project Setup"
echo ""

# Step 1: Check AGENT_SKILLS_DIR env var
if [[ -z "${AGENT_SKILLS_DIR_ENV:-}" ]]; then
  echo "Environment variable AGENT_SKILLS_DIR is not set in your shell."
  echo "Detected clone location: $AGENT_SKILLS_DIR"
  echo ""

  # Detect shell config file
  shell_config=""
  if [[ -f "$HOME/.zshrc" ]]; then
    shell_config="$HOME/.zshrc"
  elif [[ -f "$HOME/.bashrc" ]]; then
    shell_config="$HOME/.bashrc"
  elif [[ -f "$HOME/.profile" ]]; then
    shell_config="$HOME/.profile"
  fi

  if [[ -n "$shell_config" ]]; then
    read -rp "Add 'export AGENT_SKILLS_DIR=\"$AGENT_SKILLS_DIR\"' to $shell_config? [Y/n] " answer
    if [[ "${answer:-Y}" =~ ^[Yy]?$ ]]; then
      echo "" >> "$shell_config"
      echo "# Agent Skills context management" >> "$shell_config"
      echo "export AGENT_SKILLS_DIR=\"$AGENT_SKILLS_DIR\"" >> "$shell_config"
      echo "✓ Added to $shell_config (restart shell or run: source $shell_config)"
    fi
  fi
fi

# Step 2: Check/create Justfile import
echo ""
if [[ -f "Justfile" ]]; then
  if grep -q "agent-skills" Justfile 2>/dev/null; then
    echo "✓ Justfile already imports agent-skills"
  else
    read -rp "Add agent-skills import to existing Justfile? [Y/n] " answer
    if [[ "${answer:-Y}" =~ ^[Yy]?$ ]]; then
      # Prepend import
      tmp=$(mktemp)
      {
        echo "# Agent Skills context management"
        echo "import env(\"AGENT_SKILLS_DIR\", \"$AGENT_SKILLS_DIR\") / \"Justfile\""
        echo ""
        cat Justfile
      } > "$tmp"
      mv "$tmp" Justfile
      echo "✓ Import added to Justfile"
    fi
  fi
else
  read -rp "No Justfile found. Create one with agent-skills import? [Y/n] " answer
  if [[ "${answer:-Y}" =~ ^[Yy]?$ ]]; then
    cat > Justfile <<EOF
# Project Justfile

# Agent Skills context management
import env("AGENT_SKILLS_DIR", "$AGENT_SKILLS_DIR") / "Justfile"
EOF
    echo "✓ Justfile created"
  fi
fi

# Step 3: Detect project language
echo ""
echo "Detecting project..."
languages=()
if [[ -f "package.json" ]] || [[ -f "tsconfig.json" ]]; then
  languages+=("typescript")
  echo "  Found: TypeScript/JavaScript project"
fi
if [[ -f "pyproject.toml" ]] || [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]]; then
  languages+=("python")
  echo "  Found: Python project"
fi
if [[ -f "Cargo.toml" ]]; then
  languages+=("rust")
  echo "  Found: Rust project"
fi
if [[ -f "go.mod" ]]; then
  languages+=("go")
  echo "  Found: Go project"
fi
if [[ ${#languages[@]} -eq 0 ]]; then
  echo "  No specific language detected"
fi

# Step 4: Suggest MCPs
echo ""
echo "Suggested MCPs:"
suggested_mcps=("context7")
echo "  ✓ context7 (always recommended)"

for mcp_file in "$AGENT_SKILLS_DIR"/mcps/*.yml; do
  [[ ! -f "$mcp_file" ]] && continue
  mcp_name=$(yq -r '.name' "$mcp_file")
  [[ "$mcp_name" == "context7" ]] && continue

  mcp_langs=$(yq -r '.languages // [] | .[]' "$mcp_file" 2>/dev/null || true)
  relevant=false

  if [[ -z "$mcp_langs" ]]; then
    relevant=true  # Universal MCP
  else
    for lang in "${languages[@]}"; do
      if echo "$mcp_langs" | grep -q "$lang"; then
        relevant=true
        break
      fi
    done
  fi

  if [[ "$relevant" == true ]]; then
    desc=$(yq -r '.description' "$mcp_file")
    read -rp "  ? $mcp_name — $desc [y/N] " answer
    if [[ "${answer:-N}" =~ ^[Yy]$ ]]; then
      suggested_mcps+=("$mcp_name")
    fi
  fi
done

# Step 5: Create .claude-profiles.yml
echo ""
if [[ ${#suggested_mcps[@]} -gt 0 ]]; then
  echo "mcps:" > .claude-profiles.yml
  for mcp in "${suggested_mcps[@]}"; do
    echo "  - $mcp" >> .claude-profiles.yml
  done
  echo "✓ Created .claude-profiles.yml"
fi

# Step 6: Set up directories
mkdir -p .github/skills
echo "✓ Created .github/skills/ directory"

# Step 7: Create .claudeignore with markers
if [[ ! -f ".claudeignore" ]]; then
  "$SCRIPT_DIR/claudeignore-sync.sh" - <<< ""
  echo "✓ Created .claudeignore with managed section"
fi

# Step 8: Install MCPs
echo ""
for mcp in "${suggested_mcps[@]}"; do
  mcp_file="$AGENT_SKILLS_DIR/mcps/${mcp}.yml"
  if [[ -f "$mcp_file" ]]; then
    install_cmd=$(yq -r '.install' "$mcp_file")
    echo "Installing MCP: $mcp..."
    eval "$install_cmd" 2>/dev/null || echo "  ⚠ Failed to install $mcp (install manually later)"
  fi
done

# Step 9: Suggest LSP
echo ""
for lang in "${languages[@]}"; do
  lsp_file="$AGENT_SKILLS_DIR/lsps/${lang}.yml"
  if [[ -f "$lsp_file" ]]; then
    desc=$(yq -r '.description' "$lsp_file")
    read -rp "Install LSP for $lang ($desc)? [Y/n] " answer
    if [[ "${answer:-Y}" =~ ^[Yy]?$ ]]; then
      install_cmd=$(yq -r '.install' "$lsp_file")
      eval "$install_cmd" || echo "  ⚠ Failed (install manually)"
    fi
  fi
done

# Done
echo ""
echo "════════════════════════════════════════"
echo "✓ Setup complete!"
echo ""
echo "Start with:"
echo "  just claude-brainstorm    — for ideation"
echo "  just claude-code          — for implementation"
echo "  just claude-help          — see all commands"
echo ""
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/claude-init.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/claude-init.sh
git commit -m "feat(scripts): add interactive claude-init setup script"
```

---

### Task 11: `ship-it` Skill

**Files:**
- Create: `skills/ship-it/SKILL.md`
- Remove: `skills/branch-push-pr/SKILL.md` (after creating ship-it)

- [ ] **Step 1: Create `skills/ship-it/SKILL.md`**

```markdown
---
name: ship-it
description: Use when the user wants to ship work — push, PR, archive decision records, merge, and clean up. Handles the full lifecycle from committing final changes through post-merge cleanup including converting specs/plans to compact decision records.
---

# Ship It

Handle the complete shipping lifecycle: stage, commit, push, open a PR, archive decision records post-merge, and clean up.

## Overview

**Every change goes through a branch and PR.** Never push directly to main. This skill handles the full wrap-up cycle including post-merge documentation archival.

**Commit messages are documentation.** The PR title becomes the squash-merge commit on main and appears in the changelog. Get it right at PR creation time.

**Archive after merge, never before.** Specs and plans remain accessible until the PR is merged. Only after merge do we convert them to compact decision records.

## When to Use

- User says "push", "ship it", "let's ship", "open a PR", "create a PR"
- User says "merged", "it's merged", "pull and cleanup" after a PR was opened
- User has completed implementation and wants to wrap up
- After completing a plan where the next step is to submit the work

## When NOT to Use

- User explicitly wants to push directly to main (confirm this is intentional first)
- Repo has no remote configured
- Changes are work-in-progress the user isn't ready to push yet
- User just wants to commit without shipping (use git-workflow-and-versioning)

## Process

### Phase 1: Stage & Commit

```bash
git status --short
git branch --show-current
git log --oneline @{upstream}..HEAD 2>/dev/null || echo "No upstream set"
```

**Decision tree:**
- On main with uncommitted changes → create branch, commit, push, PR
- On feature branch with uncommitted changes → commit, push, PR (or update existing PR)
- On feature branch with unpushed commits → push, PR (or update existing PR)
- On feature branch with existing PR → push (PR already exists)

**If there are unstaged changes:**
- Ask the user if all changes should be included or specific files
- If changes span multiple concerns, suggest splitting

**Craft the commit message:**

| Type | When |
|------|------|
| `feat` | New functionality |
| `fix` | Bug fixes |
| `docs` | Documentation only |
| `chore` | Config, dependencies, tooling |
| `refactor` | Code restructuring, no behavior change |
| `test` | Adding or modifying tests |
| `ci` | CI/CD workflow changes |

Format: `<type>[optional scope]: <imperative description>`

Present proposed commit message to user and confirm before committing.

### Phase 2: Branch & Push

If on main, create a branch:
```
<type>/<short-description>
```

Push:
```bash
git push -u origin $(git branch --show-current)
```

### Phase 3: Open PR

PR title = conventional commit message (used for squash-merge on main).

PR body structure:
```markdown
## What changed

[Specific description of additions/modifications/removals]

## Why

[Motivation — what problem does this solve?]
```

```bash
gh pr create --title "<conventional commit message>" --body "<PR body>"
```

### Phase 4: Wait for Merge

After PR is created, ask: "Let me know when it's merged and I'll handle cleanup and archival."

Wait for user confirmation (e.g., "merged", "done", "it's merged").

### Phase 5: Post-Merge — Archive Decision Records

**Only after the PR is merged**, check for unconverted specs/plans:

```bash
# Look for specs that correspond to the work just shipped
ls docs/superpowers/specs/ 2>/dev/null
ls docs/superpowers/decisions/ 2>/dev/null
```

**If unconverted specs/plans exist:**

1. Ask the user: "I found specs/plans that may correspond to this work. Want me to convert them to compact decision records and archive the originals?"

2. If yes, for each spec:
   - Read the spec content
   - Generate a decision record with YAML frontmatter:
     ```yaml
     ---
     title: <extracted from spec>
     date: <from spec filename>
     component: <inferred from content>
     status: implemented
     supersedes: null
     dependencies: [<inferred>]
     ---
     ```
   - Write ~30-50 lines capturing: key decisions, interfaces, constraints
   - Save to `docs/superpowers/decisions/<date>-<topic>.md`
   - Move original spec to `docs/superpowers/archive/specs/`
   - Move matching plan to `docs/superpowers/archive/plans/`

3. Rebuild the master index:
   - Regenerate `docs/superpowers/index.md` from all decision record frontmatter

4. Commit the archival:
   ```bash
   git add docs/superpowers/
   git commit -m "docs: archive specs and update decision index"
   ```

### Phase 6: Cleanup

```bash
git checkout main
git pull
git branch -d <branch-name>
git push origin --delete <branch-name> 2>/dev/null || true
git fetch --prune
```

Verify clean state:
```bash
git branch --show-current
git log --oneline -3
```

## Key Principles

- **Never push to main directly** — always branch + PR
- **Conventional commits** — the PR title is the changelog entry
- **Archive after merge only** — specs stay accessible during review
- **Decision records are compact** — ~30-50 lines, YAML-indexed, LLM-optimized
- **Clean up completely** — no stale branches or tracking refs
```

- [ ] **Step 2: Remove old `skills/branch-push-pr/` directory**

```bash
rm -rf skills/branch-push-pr/
```

- [ ] **Step 3: Update `.claude/commands/push.md`** to reference ship-it

Read the current file, then update the skill reference from `branch-push-pr` to `ship-it`.

- [ ] **Step 4: Commit**

```bash
git add skills/ship-it/ skills/branch-push-pr/
git add .claude/commands/push.md
git commit -m "feat(skills): replace branch-push-pr with ship-it skill"
```

---

### Task 12: README Rewrite

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Rewrite README.md**

The README should cover:
1. What this repo is (skill library + context management toolkit)
2. Quick start (clone, set env var, import Justfile, run init)
3. Profiles explained (what each does, when to use)
4. Command reference (all `just claude-*` commands)
5. How skill profiles work (symlinks, `.claudeignore`, MCPs)
6. Document lifecycle (specs → decision records → archive)
7. Adding new skills/MCPs/LSPs
8. Prerequisites (`yq`, `just`, `gh` CLI)

Structure:
```markdown
# Agent Skills

Token-efficient context management for Claude Code.

## Quick Start
## Profiles
## Commands
## How It Works
## Document Lifecycle
## Adding Skills / MCPs / LSPs
## Prerequisites
## Contributing
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README for context management toolkit"
```

---

### Task 13: Final Integration Test

- [ ] **Step 1: Install prerequisites**

```bash
# Ensure yq is available
which yq || (echo "Install yq" && exit 1)
# Ensure just is available
which just || (echo "Install just" && exit 1)
```

- [ ] **Step 2: Test full workflow from a temp project**

```bash
cd /tmp
mkdir test-project && cd test-project
git init
echo '{}' > package.json

# Import Justfile
cat > Justfile <<'EOF'
import env("AGENT_SKILLS_DIR") / "Justfile"
EOF

# Test commands
just claude-help
just claude-list-skills
just claude-brainstorm
just claude-list-active-skills
just claude-add-skill performance-optimization
just claude-list-active-skills
just claude-rm-skill performance-optimization
just claude-minimal
just claude-list-active-skills

# Cleanup
cd /tmp && rm -rf test-project
```

- [ ] **Step 3: Verify no regressions on existing skills**

```bash
ls -la .github/skills/  # Should still have all original skills
ls -la skills/          # Should have ship-it, repo-automation-setup, commit-history-rewrite
```

- [ ] **Step 4: Final commit if any fixes needed**

```bash
# Only if integration testing revealed issues
git add -A
git commit -m "fix: integration test fixes"
```
