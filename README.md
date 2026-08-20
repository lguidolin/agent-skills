# Agent Skills

House engineering skills for Claude Code.

This repo holds the skills we actually maintain — an engineering constitution,
stack-specific guidance, and repo automation — and installs them where Claude
Code looks for them. It is deliberately **not** a mirror of other people's skill
libraries.

## Quick Start

1. **Clone this repo** to a stable location:
   ```bash
   git clone https://github.com/lguidolin/agent-skills.git ~/local/agent-skills
   ```

2. **Install the skills** — symlinks into `~/.claude/skills/`, so they update
   whenever you `git pull`:
   ```bash
   ~/local/agent-skills/scripts/install.sh --global
   ```

That is the whole setup. Claude Code discovers the skills in every project.

To share a subset with a team instead, copy them into a repo and commit them:

```bash
~/local/agent-skills/scripts/install.sh --project .        # portable skills
~/local/agent-skills/scripts/install.sh --project . --all  # include stack-specific
```

Stack-specific skills (`cloud-delivery-aks`, `postgres-postgraphile-rls-and-sql`,
`graphql-contract-testing`) are held back from `--project` unless you pass
`--all` — a repo with no Kubernetes deploy should not carry Azure guidance.

## Why There Is No Profile System

An earlier version of this repo gated skills per project to save context. That
mechanism has been removed, for two reasons.

**It targeted the wrong directory.** Activation symlinked skills into
`<project>/.github/skills/`, which is GitHub Copilot's discovery convention.
Claude Code reads `~/.claude/skills/` and `<project>/.claude/skills/`. Once
Copilot support was dropped, the machinery had no consumer.

**The context saving was a rounding error.** Claude Code loads only each skill's
`name` and `description` up front and reads the body when the skill is actually
invoked:

| | tokens |
|---|---|
| All 19 descriptions (always loaded) | ~1,540 |
| All 19 bodies (loaded on invocation) | ~20,850 |

Gating skills saves roughly a thousand tokens, while the machinery cost ~2,600
lines of scripts, profiles, hooks, and tests to maintain 1,600 lines of skills.

**What actually costs context is MCP tool schemas**, which load in full. Claude
Code already gates those natively — per-project `.mcp.json` and `enabledPlugins`
in `.claude/settings.json`. Use those; this repo does not wrap them.

## What Belongs in This Repo

Installed plugins are the source of truth for the skills they ship. Vendoring a
copy here only creates a stale fork that shadows the maintained one.

**In scope — `skills/`:**

- **House rules** — the engineering constitution, commit conventions, review
  gates, deploy discipline (`engineering-constitution`,
  `conventional-commits-and-releases`, `verification-gate-and-automation`, …).
- **Stack-specific skills** — guidance tied to tooling we actually run
  (`postgres-postgraphile-rls-and-sql`, `graphql-contract-testing`,
  `zero-downtime-migrations`, `cloud-delivery-aks`).
- **Repo automation** — `init-repo-CI`, `commit-history-rewrite`, `ship-it`.

**Out of scope — install from the source instead:**

| Source | Provides | Install |
|--------|----------|---------|
| [obra/superpowers](https://github.com/obra/superpowers) | Workflow methodology: brainstorming, writing/executing plans, TDD, systematic debugging, code review, worktrees, subagent-driven development | Claude Code marketplace — `/plugin` |
| [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | Production engineering skills (spec-driven-development, source-driven-development, context-engineering, browser-testing-with-devtools, …) and agent personas | `git clone` + copy into `.claude/skills/` |

**Enforced, not just documented.** `scripts/plugin-skills.sh` lists every skill
name shipped by an installed plugin. `install.sh` refuses to install a skill
that reuses one of those names, and `tests/test_skills.sh` asserts the pool
stays clean. Override with `ALLOW_PLUGIN_SKILL_COLLISION=1` only while migrating
a name.

If a plugin skill is *almost* right, do not fork it — add a narrowly scoped
house skill that says what we do differently and cross-links the one it
complements.

## Commands

A `Justfile` is provided for convenience. Import it from your project:

```justfile
import "~/local/agent-skills/Justfile"
```

| Command | Description |
|---------|-------------|
| `just claude-install-global` | Symlink all skills into `~/.claude/skills` |
| `just claude-install-project` | Copy portable skills into `./.claude/skills` |
| `just claude-install-project-all` | Same, including stack-specific skills |
| `just claude-list-skills` | List the pool with trigger descriptions |
| `just claude-plugin-skills` | Show plugin-owned names you must not reuse |
| `just claude-update-archive` | Find unconverted specs/plans |
| `just claude-rebuild-index` | Rebuild the decision index |
| `just test` | Run the test suite |

## Skills

Run `just claude-list-skills` for the current list with trigger conditions.

The **engineering constitution** is 12 always-on Tier-1 skills covering design,
decisions, commits, tests, code craft, UI, verification, observability,
security, performance, and deploy safety — plus 4 Tier-2 stack skills that
self-activate only when the relevant tooling is present. See
[docs/engineering-constitution.md](docs/engineering-constitution.md).

## Document Lifecycle

Specs and plans written during design are human-friendly but token-expensive.
After implementation and merge, they are converted to compact **decision
records**:

```
docs/superpowers/
  specs/      → in-flight specs
  plans/      → in-flight plans
  archive/    → converted decision records
```

`just claude-update-archive` finds unconverted documents; `just
claude-rebuild-index` rebuilds the master index.

## Adding a Skill

Add a `SKILL.md` to `skills/<name>/` with YAML frontmatter:

```yaml
---
name: my-skill
description: Use when [trigger conditions]
---
```

The tests enforce that `name` matches the directory, that `description` states
trigger conditions, and that the name does not collide with a plugin-owned one.
Check what is taken before you start:

```bash
just claude-plugin-skills
```

Then run `just test`.

## Prerequisites

- `bash`, `git`
- `just` (optional — the scripts run standalone)
- `yq` (only for `claude-rebuild-index`)

## License

GPL-3.0 — see [LICENSE](LICENSE).
