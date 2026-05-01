# Context Management Toolkit — Design Spec

## Overview

A toolkit for managing Claude Code's token and context usage by providing profile-based skill loading, MCP/LSP management, document lifecycle automation, and `.claudeignore` hygiene. This repo (`agent-skills`) is both the skill library and the toolkit — users clone it, set a path variable, and import a Justfile into their projects.

## Problem

- Claude Code auto-discovers all skills in `.github/skills/`, consuming tokens regardless of relevance to the current task.
- Specs and plans written for human readability accumulate and bloat context over time.
- MCP/LSP configuration is manual and tedious per-project.
- No mechanism to scope Claude's context to the current activity.

## Architecture

### Central Repository

This repo is cloned to a user-chosen location (e.g., `~/local/agent-skills`). Projects reference it via the `AGENT_SKILLS_DIR` environment variable.

```
agent-skills/
├── profiles/                          # Profile definitions (YAML)
│   ├── brainstorm.yml
│   ├── design.yml
│   ├── code.yml
│   ├── ship.yml
│   └── minimal.yml
│
├── scripts/                           # Shell scripts doing the work
│   ├── profile-activate.sh
│   ├── skill-add.sh
│   ├── skill-rm.sh
│   ├── claudeignore-sync.sh
│   ├── mcp-configure.sh
│   ├── doc-archive.sh
│   ├── index-rebuild.sh
│   └── profile-lock.sh
│
├── hooks/                             # Claude Code hook scripts
│   ├── pre-session.sh
│   └── post-session.sh
│
├── templates/                         # Templates for doc conversion
│   └── decision-record.md
│
├── mcps/                              # MCP server definitions (YAML)
│   ├── context7.yml
│   ├── postgres.yml
│   ├── browser.yml
│   └── ...
│
├── lsps/                              # LSP server definitions (YAML)
│   ├── typescript.yml
│   ├── python.yml
│   └── ...
│
├── Justfile                           # Importable recipes
├── .github/skills/                    # All skills (source of truth)
├── skills/                            # Core plugin skills
└── docs/
```

### How Projects Use It

User sets `AGENT_SKILLS_DIR` in shell config:

```bash
export AGENT_SKILLS_DIR="$HOME/local/agent-skills"
```

Each project's Justfile imports:

```justfile
agent_skills_dir := env("AGENT_SKILLS_DIR", "~/local/agent-skills")

import agent_skills_dir / "Justfile"
```

## Profiles

Profiles define which skills, MCPs, and `.claudeignore` patterns are active for a given activity.

### Profile Definitions

| Profile | Purpose | Key Skills | MCPs |
|---------|---------|------------|------|
| `brainstorm` | Ideation, specs, plans | brainstorming, idea-refine, spec-driven-dev, planning-and-task-breakdown, writing-plans, context-engineering, documentation-and-adrs | context7 |
| `design` | UI/UX design, mockups, visual work | frontend-ui-engineering, browser-testing-with-devtools, brainstorming | context7, browser |
| `code` | Implementation, debugging, testing, committing | incremental-implementation, test-driven-development, systematic-debugging, debugging-and-error-recovery, git-workflow-and-versioning, security-and-hardening, verification-before-completion | context7 + project-specific |
| `ship` | Push, PR, archive, cleanup | ship-it, finishing-a-development-branch, code-review-and-quality | context7 |
| `minimal` | Dormant state, nothing loaded | (none) | (none) |

### Profile YAML Format

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
  - "node_modules/**"
  - "docs/superpowers/archive/**"

hooks:
  pre_session: true
  post_session: true
```

### Activation Flow

When `just claude-brainstorm` is invoked:

1. **Lock check** — if `.claude-profile.lock` exists with a different PID still alive, warn and abort.
2. **Write lock** — write current PID + profile name to `.claude-profile.lock`.
3. **Clear existing symlinks** — remove all symlinks in project's `.github/skills/` (only symlinks, never real files).
4. **Create new symlinks** — for each skill in the profile, symlink `$AGENT_SKILLS_DIR/.github/skills/<name>` → project's `.github/skills/<name>`.
5. **Merge project overrides** — if `.claude-profiles.yml` exists, apply `skills_add`, `skills_remove`, `mcps_add`, `mcps_remove` for the active profile.
6. **Sync `.claudeignore`** — update the managed section, preserve manual entries.
7. **Configure MCPs** — activate MCPs listed in profile + project config; deactivate others.
8. **Report** — print what's active (skills, MCPs, ignored patterns).

### Per-Skill Overrides

```bash
just claude-add-skill performance-optimization
just claude-rm-skill security-and-hardening
```

Overrides persist until the next profile switch (which resets to baseline).

### Concurrency

- Different projects: no conflict (each has its own `.github/skills/` and lock file).
- Same project, different modes: use git worktrees for intentional parallelism.
- Accidental conflict: lock file with PID prevents concurrent profile switches on the same directory.

## Document Lifecycle

### Directory Structure (Per Project)

```
docs/superpowers/
├── specs/                    # Active specs (human-friendly, current work)
├── plans/                    # Active plans (current work)
├── decisions/                # Compact LLM-optimized decision records
├── archive/                  # Originals after conversion (.claudeignored)
│   ├── specs/
│   └── plans/
└── index.md                  # Auto-generated master index
```

### Decision Record Format

```markdown
---
title: Auth Flow
date: 2026-04-28
component: authentication
status: implemented
supersedes: null
dependencies: [user-management, session-store]
---

## Decisions

- OAuth2 + PKCE for all external auth; session cookies for internal
- JWT access tokens (15min), opaque refresh tokens (7d) in Redis
- Rate limit: 5 failed attempts → 15min lockout per IP+account

## Interfaces

- `POST /auth/login` → `{ access_token, refresh_token, expires_in }`
- `POST /auth/refresh` → `{ access_token, expires_in }`
- `AuthMiddleware` checks Bearer token, attaches `req.user`

## Constraints

- No third-party auth libraries (company policy)
- Must support multi-tenant: tenant ID embedded in JWT claims
```

~30-50 lines per record vs 200-400 line originals. YAML frontmatter enables index generation.

### Master Index

Auto-generated from decision record frontmatter (`docs/superpowers/index.md`):

```markdown
# Project Decision Index

## Active Decisions

| Component | Title | Date | Dependencies |
|-----------|-------|------|--------------|
| authentication | Auth Flow | 2026-04-28 | user-management, session-store |
| user-management | User CRUD | 2026-04-25 | database |

## Superseded

| Component | Title | Superseded By |
|-----------|-------|---------------|
```

Claude reads this index every session (~20-40 lines). Reads specific decision records on demand.

### Conversion Flow

Primary path: the `ship-it` skill instructs Claude to check for unconverted specs/plans during the shipping flow and offers to convert them in-session.

Fallback path: `just claude-update-archive` scans for unconverted docs, generates a conversion prompt to paste into a Claude session.

Post-conversion: originals move to `archive/`, index is rebuilt, `.claudeignore` ensures archive is invisible.

## `.claudeignore` Management

Managed section approach — manual entries are never touched:

```gitignore
# Your manual entries here (untouched):
*.env
secrets/

# --- agent-skills:managed:start ---
# Auto-managed by agent-skills profiles. Do not edit this section.
docs/superpowers/archive/**
src/**
tests/**
# --- agent-skills:managed:end ---
```

Rules:
- Profile activation replaces content between markers.
- Content outside markers is never modified.
- If markers don't exist, they're appended at end of file.
- `just claude-minimal` empties the managed section.

## MCP/LSP Management

### MCP Definition Format

```yaml
# mcps/context7.yml
name: context7
description: "Documentation lookup for any library/framework"
install: "npx -y @anthropic/claude-code mcp add context7 -- npx -y @context7/mcp"
profiles: [brainstorm, code, ship, design]
languages: []
```

### LSP Definition Format

```yaml
# lsps/typescript.yml
name: typescript
description: "TypeScript/JavaScript language intelligence"
install: "npm install -g typescript-language-server typescript"
detect: ["package.json", "tsconfig.json"]
```

### Per-Project Configuration

`.claude-profiles.yml` (created by `just claude-init` or manually):

```yaml
mcps:
  - typescript-lsp
  - postgres
```

Project-level MCPs merge into any active profile. Profile-specific overrides:

```yaml
code:
  skills_add:
    - frontend-ui-engineering
  skills_remove: []
  mcps_add:
    - browser
  mcps_remove: []
```

### MCP Activation Logic

An MCP activates when:
- It's listed in the active profile's `mcps` field, OR
- It's listed in the project's `.claude-profiles.yml`

An MCP deactivates when the active profile doesn't include it AND the project config doesn't list it.

## Hooks

### Pre-Session (`hooks/pre-session.sh`)

- Checks if a profile is active (`.claude-profile.lock` exists)
- If no profile: prints reminder to activate one
- If stale lock (dead PID): cleans it up
- Validates symlinks are intact

### Post-Session (`hooks/post-session.sh`)

- Reverts to `minimal` profile (removes skill symlinks, resets `.claudeignore` managed section)
- Deactivates profile-specific MCPs
- Removes lock file
- Prints summary

Note: The post-session revert is opt-in per profile (`hooks.post_session: true` in profile YAML). Users who prefer persistent profiles across sessions can set `post_session: false` — the profile stays active until explicitly switched.

## `just claude-init`

Interactive first-time setup:

1. **Environment check** — verify `AGENT_SKILLS_DIR` is set. If not, detect the current clone path and offer to append `export AGENT_SKILLS_DIR="<path>"` to the user's shell config (`.zshrc`, `.bashrc`, or `.profile` — auto-detected).
2. **Justfile import** — check if the project has a Justfile. If yes, check for existing import; if missing, offer to prepend the import lines. If no Justfile exists, offer to create one.
3. Detect project language (package.json → TypeScript, pyproject.toml → Python, etc.)
4. Suggest relevant MCPs and LSPs based on detection
5. Ask which profiles the user will use
6. Create `.claude-profiles.yml`
7. Set up `.github/skills/` directory
8. Create `.claudeignore` with managed section markers
9. Install selected MCPs and LSPs
10. Print summary with next steps

## Command Reference

### Profiles

| Command | Description |
|---------|-------------|
| `just claude-brainstorm` | Activate brainstorm profile (ideation, specs, plans) |
| `just claude-design` | Activate design profile (UI/UX, mockups, browser) |
| `just claude-code` | Activate code profile (implementation, debug, test) |
| `just claude-ship` | Activate ship profile (push, PR, archive, cleanup) |
| `just claude-minimal` | Deactivate all — dormant state |
| `just claude-active-profile` | Show current profile + any overrides |

### Skills

| Command | Description |
|---------|-------------|
| `just claude-list-skills` | All available skills with descriptions and profile associations |
| `just claude-list-active-skills` | Currently active skills with descriptions |
| `just claude-add-skill <name>` | Add a skill on top of current profile |
| `just claude-rm-skill <name>` | Remove a skill from current profile |

### MCPs

| Command | Description |
|---------|-------------|
| `just claude-list-mcps` | All available MCPs with descriptions |
| `just claude-list-active-mcps` | MCPs configured for this project |
| `just claude-add-mcp <name>` | Install + add MCP to project config |
| `just claude-rm-mcp <name>` | Remove + deactivate MCP |

### LSPs

| Command | Description |
|---------|-------------|
| `just claude-list-lsps` | All available LSPs with descriptions |
| `just claude-setup-lsp <name>` | Install an LSP server |

### Docs & Archive

| Command | Description |
|---------|-------------|
| `just claude-update-archive` | Convert unconverted specs/plans → decision records |
| `just claude-rebuild-index` | Regenerate master index from decision records |

### Setup

| Command | Description |
|---------|-------------|
| `just claude-init` | Interactive first-time project setup |
| `just claude-help` | Show all commands with descriptions |

## `ship-it` Skill

Replaces the existing `branch-push-pr` skill. Full shipping lifecycle:

1. Stage and commit remaining changes
2. Push branch
3. Create PR
4. Wait for user confirmation on merge
5. Post-merge: check for unconverted specs/plans corresponding to this work
6. Offer to convert → decision records (in-session, Claude does the conversion)
7. Rebuild master index
8. Post-merge cleanup (delete branch, pull main)

Archival only happens after the PR is merged — never before. This ensures specs/plans remain accessible if the PR needs revisions or is rejected.

## Deliverables

1. Profile YAML files (`profiles/`)
2. Shell scripts (`scripts/`)
3. Hook scripts (`hooks/`)
4. Decision record template (`templates/`)
5. MCP definitions (`mcps/`)
6. LSP definitions (`lsps/`)
7. Importable Justfile
8. `ship-it` skill (replacing `branch-push-pr`)
9. Updated README explaining the full toolkit
10. Skill-to-profile mapping metadata (for `just claude-list-skills`)

## Out of Scope

- Dynamic CLAUDE.md generation
- Session summaries / continuity between sessions
- Vector database indexing (simple file-based index is sufficient)
- Auto-detection of which profile to use (always explicit activation)
