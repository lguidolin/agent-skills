# Agent Skills

Token-efficient context management for Claude Code.

Manage your Claude Code sessions with profile-based skill loading, MCP/LSP configuration, document lifecycle automation, and `.claudeignore` hygiene — all through simple `just` commands.

## Quick Start

1. **Clone this repo** to a stable location:
   ```bash
   git clone https://github.com/lguidolin/agent-skills.git ~/local/agent-skills
   ```

2. **Set the env var** in your shell config (`.zshrc`, `.bashrc`):
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

## How It Works

`agent-skills` is a centralized inventory + per-project activation system. All your tools — skills, agents, MCPs, plugins — live in one pool at `~/local/agent-skills/{skills,agents,mcps,plugins}-available/`. A `registry.yml` tracks what exists and where.

**Profile activation** is per-project: it creates symlinks in `<project>/.github/skills/` and `<project>/.claude/agents/`, writes `<project>/.mcp.json`, and toggles `enabledPlugins` in `<project>/.claude/settings.json`. Other projects are unaffected.

**Inventory:**
```
just claude-list                    # all tools, grouped by type
just claude-list-type skill         # filter by type
just claude-list-profile code       # filter by profile
```

## What Belongs in This Repo

This repo is **not** a mirror of other people's skill libraries. Installed
plugins are the source of truth for the skills they ship, and vendoring a copy
here only creates a stale fork that shadows the maintained one.

**In scope — `skills-available/`:**

- **House rules** — the engineering constitution, commit conventions, review
  gates, and deploy discipline this org follows (`engineering-constitution`,
  `conventional-commits-and-releases`, `verification-gate-and-automation`, …).
- **Stack-specific skills** — guidance tied to tooling we actually run
  (`postgres-postgraphile-rls-and-sql`, `graphql-contract-testing`,
  `zero-downtime-migrations`, `cloud-delivery-aks`).
- **Repo automation** — `init-repo-CI`, `commit-history-rewrite`, `ship-it`.

**Out of scope — install from the source instead:**

| Source | Provides | Install |
|--------|----------|---------|
| [obra/superpowers](https://github.com/obra/superpowers) (plugin `superpowers`) | Workflow methodology: brainstorming, writing/executing plans, TDD, systematic debugging, code review, worktrees, subagent-driven development | Claude Code marketplace — `/plugin` |
| [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | Production engineering skills (spec-driven-development, source-driven-development, context-engineering, browser-testing-with-devtools, …) and agent personas | `git clone` + copy into `.github/skills/`, or add to the pool under a non-colliding name |

**Enforced, not just documented.** `scripts/plugin-skills.sh` lists every skill
name shipped by an installed plugin. `registry.sh add` refuses to register a
pool skill that reuses one of those names, and `profile-activate.sh` refuses to
activate a profile that lists one — both fail loudly rather than silently
symlinking one copy over the other. `tests/test_plugin_collision.sh` asserts the
pool and every profile stay clean. Override with
`ALLOW_PLUGIN_SKILL_COLLISION=1` only while migrating a name.

If a plugin skill is *almost* right, do not fork it — add a narrowly scoped
house skill that says what we do differently and cross-links the plugin skill it
complements.

## Profiles

| Profile | Purpose | House Skills | Plugins |
|---------|---------|--------------|---------|
| `brainstorm` | Ideation, specs, plans | designing-before-building, recording-decisions | superpowers |
| `design` | UI/UX, mockups, visual work | interface-craft-and-accessibility, designing-before-building | superpowers |
| `code` | Implementation, debug, test | change-hygiene-and-code-craft, tests-as-a-control, defense-in-depth-security | superpowers |
| `ship` | Push, PR, archive, cleanup | ship-it, conventional-commits-and-releases, resilience-and-deploy-safety | superpowers |
| `constitution` | Always-on engineering discipline | the 12 Tier-1 constitution skills | — |
| `minimal` | Dormant — nothing loaded | (none) | — |

Activate with: `just claude-<profile>`

Profiles list only **house skills** under `skills:`. Methodology skills such as
brainstorming, writing-plans, TDD, and systematic debugging come from the
`superpowers` plugin, listed under `plugins:` — see
[What belongs in this repo](#what-belongs-in-this-repo).

### Per-Skill Overrides

Layer individual skills on top of any profile:

```bash
just claude-add-skill performance-and-scale
just claude-rm-skill defense-in-depth-security
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
    - interface-craft-and-accessibility
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

### Inventory

| Command | Description |
|---------|-------------|
| `just claude-list` | All tools in the pool, marked active/inactive |
| `just claude-list-type <type>` | Filter by type (skill, agent, mcp, plugin) |
| `just claude-list-profile <profile>` | Tools belonging to a profile |

### Setup

| Command | Description |
|---------|-------------|
| `just claude-bootstrap` | One-time global discovery — populate the pool |
| `just claude-init` | Per-project init: migrate local tools into the pool |
| `just test` | Run the bash test suite |
| `just claude-help` | Show all commands |

## Constitution Skills

The **engineering constitution** is a portable charter of engineering practice, decomposed into 16 individually-loadable skills. Each skill's `description` controls *when* it loads, so guidance reaches an agent exactly when the task calls for it — and stack-specific guidance (e.g. Kubernetes/Azure) stays dormant in projects that don't use that stack.

- **12 Tier-1 skills** — universal building and operating discipline (design, decisions, commits, testing, code craft, UI/a11y, CI gates, observability, security, performance, resilience). Load in every project.
- **4 Tier-2 skills** — stack mechanisms (`postgres-postgraphile-rls-and-sql`, `graphql-contract-testing`, `zero-downtime-migrations`, `cloud-delivery-aks`). Self-activate only when their tooling/topic is present.

The full charter lives in `docs/engineering-constitution.md`; each skill links back to its articles.

### Install

```bash
# One-time: clone the pool (if you haven't already)
git clone https://github.com/lguidolin/agent-skills.git ~/local/agent-skills

# Personal, all-projects: symlink all 16 into ~/.claude/skills/
~/local/agent-skills/scripts/constitution-install.sh --global

# Per-project, team-shared: copy the portable set into a repo's .claude/skills/ and commit it
~/local/agent-skills/scripts/constitution-install.sh --project ~/path/to/repo
```

`--project` copies the 15 stack-portable skills and **excludes `cloud-delivery-aks`** (a project with no Kubernetes deploy shouldn't carry Azure guidance); pass `--all` to include it. The `--global` symlinks auto-update when you `git pull` the pool.

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

Add a `SKILL.md` to `skills-available/<name>/` with YAML frontmatter:

```yaml
---
name: my-skill
description: Use when [trigger conditions]
---
```

Then add it to relevant profiles in `profiles/*.yml`.

The name must not collide with a skill shipped by an installed plugin — see
[What Belongs in This Repo](#what-belongs-in-this-repo). Check before you start:

```bash
$AGENT_SKILLS_DIR/scripts/plugin-skills.sh          # plugin-owned names
$AGENT_SKILLS_DIR/scripts/plugin-skills.sh --with-plugin   # and their owners
```

Registering a colliding name fails loudly; it is not silently accepted.

### New MCP

Create `mcps-available/<name>.yml`:

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
