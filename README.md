# Agent Skills

House engineering skills for Claude Code.

This repo holds the skills we actually maintain — an engineering constitution,
stack-specific guidance, and repo automation — and installs them where Claude
Code looks for them. It is deliberately **not** a mirror of other people's skill
libraries.

## Install

Clone the repo to a stable location, then pick one of the two install modes.
`install.sh` is idempotent — re-run it any time, including after `git pull`.

```bash
git clone https://github.com/lguidolin/agent-skills.git ~/local/agent-skills
```

### Personal (all your projects)

Symlinks every skill into `~/.claude/skills/`, so they track this repo and a
`git pull` updates them everywhere at once:

```bash
~/local/agent-skills/scripts/install.sh --global
```

Verify — you should see one symlink per skill and no broken links:

```bash
ls -l ~/.claude/skills | head
find ~/.claude/skills -maxdepth 1 -xtype l    # must print nothing
```

### Team (one repo, committed)

Copies the skills into a project so they ship with it:

```bash
cd /path/to/project
~/local/agent-skills/scripts/install.sh --project .        # portable skills
~/local/agent-skills/scripts/install.sh --project . --all  # include stack-specific
git add .claude/skills && git commit -m "chore: add engineering skills"
```

Stack-specific skills (`cloud-delivery-aks`, `postgres-postgraphile-rls-and-sql`,
`graphql-contract-testing`) are held back unless you pass `--all` — a repo with
no Kubernetes deploy should not carry Azure guidance.

### What the installer guarantees

These are the rules that make the install repeatable rather than a pile of
`ln` commands, and each is covered by `tests/test_install.sh`:

| Guarantee | Why |
|---|---|
| **Idempotent** — re-running changes nothing | Safe to run after every `git pull` |
| **Stale copies replaced** — a real directory left by an older install is swapped for a symlink | Otherwise that one skill silently stops updating |
| **Collision refusal** — aborts if a skill name is already shipped by an installed plugin | Prevents shadowing the maintained copy; see below |
| **Bundled assets travel** — a skill's `scripts/` and `templates/` come along, executable | Skills stay self-contained wherever they land |
| **No external tooling** — bash only, no `jq`/`yq`/`just` | Installs on a bare machine |

Restart Claude Code after installing so it re-reads the skills directory.

### Prerequisites

`bash` and `git`. Nothing else — `just` is optional convenience, and the test
suite is pure bash.

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

**What actually costs context** is different from what the profile system was
gating:

- **MCP tool schemas**, which load in full. Claude Code already gates those
  natively — per-project `.mcp.json` and `enabledPlugins` in
  `.claude/settings.json`. Use those; this repo does not wrap them.
- **Long design documents**, which are charged in full every time one is
  opened. That is a real cost, and it is what the
  [document lifecycle](#document-lifecycle) addresses — by shrinking the
  artifact rather than by hiding it behind a profile.

Skill *gating* was the wrong lever. Artifact *reduction* is the right one.

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

This is the one context-saving mechanism in the repo that earns its keep.

Specs and plans are verbose *on purpose* — they are written for a human
following the reasoning. That verbosity is charged to context every time Claude
opens one. After the work merges, each spec is reduced to a **decision record**:
~30-50 lines carrying only what is needed to move forward — the decisions and
their *why*, interfaces, constraints, gotchas, rejected alternatives. The
original moves to `archive/`, still readable by a human, costing nothing until
someone deliberately opens it.

```
docs/superpowers/
  specs/      → in-flight specs (verbose, human-facing)
  plans/      → in-flight plans
  decisions/  → compact decision records (what Claude reads)
  archive/    → originals, preserved after conversion
  index.md    → generated from decision frontmatter
```

The tooling ships **inside the `recording-decisions` skill**, not in this
repo's `scripts/`, so it works in any project the skill is installed into:

```
recording-decisions/
  scripts/doc-archive.sh      list specs lacking a decision record
  scripts/index-rebuild.sh    regenerate index.md from frontmatter
  templates/decision-record.md
```

Both are dependency-free bash. `ship-it` locates them at ship time and falls
back to doing the work by hand if the skill is not installed — no skill in this
repo depends on this repo's Justfile.

From inside this repo you can also use `just claude-update-archive` and
`just claude-rebuild-index`.

## Adding a Skill

Add a `SKILL.md` to `skills/<name>/` with YAML frontmatter:

```yaml
---
name: my-skill
description: Use when [trigger conditions]
---
```

A skill may bundle its own assets — put them in `skills/<name>/scripts/` and
`skills/<name>/templates/` and reference them by a path relative to `SKILL.md`.
Both install modes carry them along with the executable bit intact, which is how
a skill stays self-contained in whatever repo it lands in. Never reference this
repo's `Justfile` from a skill: it will not exist where the skill is installed.

The tests enforce that `name` matches the directory, that `description` states
trigger conditions, and that the name does not collide with a plugin-owned one.
Check what is taken before you start:

```bash
just claude-plugin-skills
```

Then run `just test`.

## License

GPL-3.0 — see [LICENSE](LICENSE).
