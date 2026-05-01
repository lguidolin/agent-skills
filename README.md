# Agent Skills

Token-efficient context management for Claude Code.

Manage your Claude Code sessions with profile-based skill loading, MCP/LSP configuration, document lifecycle automation, and `.claudeignore` hygiene — all through simple `just` commands.

## Quick Start

1. **Clone this repo** wherever you keep tools:
   ```bash
   git clone https://github.com/lguidolin/agent-skills.git ~/local/agent-skills
   ```

2. **Set the environment variable** in your shell config (`.zshrc`, `.bashrc`):
   ```bash
   export AGENT_SKILLS_DIR="$HOME/local/agent-skills"
   ```

3. **Import into your project's Justfile:**
   ```justfile
   import "~/local/agent-skills/Justfile"
   ```

   Or run the interactive setup:
   ```bash
   just claude-init
   ```

4. **Activate a profile:**
   ```bash
   just claude-brainstorm   # ideation mode
   just claude-code         # implementation mode
   ```

## How It Works

This repo is both a **skill library** and a **context management toolkit**. Claude Code auto-discovers skills from `.github/skills/` in your project. This toolkit manages which skills are visible via symlinks — only the skills relevant to your current activity get linked, reducing token consumption.

### The Problem

Claude Code loads all discovered skills into context, consuming tokens regardless of relevance. A brainstorming session doesn't need debugging skills. A coding session doesn't need deployment skills. Specs written for humans are verbose when an LLM just needs decisions.

### The Solution

- **Profiles** define which skills, MCPs, and ignore patterns apply to each activity
- **Symlinks** make only active skills visible to Claude Code
- **`.claudeignore`** prevents irrelevant files from being read
- **Decision records** replace verbose specs with compact LLM-optimized summaries

## Profiles

| Profile | Purpose | Typical Skills |
|---------|---------|----------------|
| `brainstorm` | Ideation, specs, plans | brainstorming, writing-plans, spec-driven-dev |
| `design` | UI/UX, mockups, visual work | frontend-ui-engineering, browser-testing |
| `code` | Implementation, debug, test | TDD, debugging, incremental-implementation |
| `ship` | Push, PR, archive, cleanup | ship-it, finishing-a-dev-branch |
| `minimal` | Dormant — nothing loaded | (none) |

Activate with: `just claude-<profile>`

### Per-Skill Overrides

Layer individual skills on top of any profile:

```bash
just claude-add-skill performance-optimization
just claude-rm-skill security-and-hardening
```

Overrides reset when you switch profiles.

### Project-Level Customization

Create `.claude-profiles.yml` in your project to customize profiles:

```yaml
# MCPs always active for this project
mcps:
  - typescript-lsp
  - postgres

# Per-profile overrides
code:
  skills_add:
    - frontend-ui-engineering
  mcps_add:
    - browser
```

## Commands

### Profiles

| Command | Description |
|---------|-------------|
| `just claude-brainstorm` | Activate brainstorm profile |
| `just claude-design` | Activate design profile |
| `just claude-code` | Activate code profile |
| `just claude-ship` | Activate ship profile |
| `just claude-minimal` | Deactivate all |
| `just claude-active-profile` | Show current profile |

### Skills

| Command | Description |
|---------|-------------|
| `just claude-list-skills` | All skills + profile associations |
| `just claude-list-active-skills` | Currently active skills |
| `just claude-add-skill <name>` | Add skill to current profile |
| `just claude-rm-skill <name>` | Remove skill from current profile |

### MCPs

| Command | Description |
|---------|-------------|
| `just claude-list-mcps` | All available MCPs |
| `just claude-list-active-mcps` | MCPs for this project |
| `just claude-add-mcp <name>` | Add + install MCP |
| `just claude-rm-mcp <name>` | Remove MCP |

### LSPs

| Command | Description |
|---------|-------------|
| `just claude-list-lsps` | All available LSPs |
| `just claude-setup-lsp <name>` | Install an LSP server |

### Docs & Archive

| Command | Description |
|---------|-------------|
| `just claude-update-archive` | Find unconverted specs, generate prompt |
| `just claude-rebuild-index` | Rebuild decision index |

### Setup

| Command | Description |
|---------|-------------|
| `just claude-init` | Interactive first-time project setup |
| `just claude-help` | Show all commands |

## Document Lifecycle

Specs and plans written during brainstorming are human-friendly but token-expensive. After implementation and merge, they're converted to compact **decision records**:

```
docs/superpowers/
├── specs/        → Active specs (human-friendly)
├── plans/        → Active plans
├── decisions/    → Compact LLM-optimized records (always visible)
├── archive/      → Originals after conversion (.claudeignored)
└── index.md      → Auto-generated master index
```

### Decision Records

~30-50 lines with YAML frontmatter for indexing:

```yaml
---
title: Auth Flow
date: 2026-04-28
component: authentication
status: implemented
supersedes: null
dependencies: [user-management, session-store]
---
```

The master index (`index.md`) is auto-generated and always visible to Claude — giving it awareness of all past decisions without loading full documents.

### Archival Flow

Archival happens **post-merge only** (via the `ship-it` skill or `just claude-update-archive`):

1. Identify unconverted specs/plans
2. Convert to decision records (Claude does this in-session)
3. Move originals to `archive/`
4. Rebuild the master index

## Hooks

Optional Claude Code hooks for automation:

- **Pre-session**: Validates profile state, cleans stale locks, warns about broken symlinks
- **Post-session**: Optionally reverts to minimal profile (configurable per profile)

Install hooks by pointing Claude Code's hook configuration to the `hooks/` directory.

## Adding Skills / MCPs / LSPs

### New Skill

Add a `SKILL.md` to `.github/skills/<name>/` with YAML frontmatter:

```yaml
---
name: my-skill
description: Use when [trigger conditions]
---
```

Then add it to relevant profiles in `profiles/*.yml`.

### New MCP

Create `mcps/<name>.yml`:

```yaml
name: my-mcp
description: "What it does"
install: "claude mcp add my-mcp -- npx -y @scope/package"
remove: "claude mcp remove my-mcp"
profiles: [code, design]
languages: [typescript]
```

### New LSP

Create `lsps/<name>.yml`:

```yaml
name: my-lsp
description: "Language intelligence for X"
install: "npm install -g my-lsp-server"
detect: ["indicator-file.json"]
```

## Prerequisites

- [just](https://github.com/casey/just) — command runner
- [yq](https://github.com/mikefarah/yq) — YAML processor
- [gh](https://cli.github.com/) — GitHub CLI (for PR creation in ship profile)
- [claude](https://docs.anthropic.com/en/docs/claude-code) — Claude Code CLI

## Concurrency

- Different projects: no conflicts (each has its own `.github/skills/` and lock)
- Same project, different modes: use [git worktrees](https://git-scm.com/docs/git-worktree)
- Accidental conflicts: lock file prevents concurrent profile switches

## License

GPL-3.0
