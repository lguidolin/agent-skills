# Centralized Tool Pool — Design Spec

## Overview

Expand `agent-skills` from a per-repo skill manager into a centralized inventory and activation system for all Claude Code / Copilot tooling — skills, agents, MCPs, and plugins. One pool of tools at `~/local/agent-skills/`; per-project profile activation creates symlinks and writes project-scoped config so Claude/Copilot find the right subset for the current activity. Other projects are unaffected.

## Problem

The current toolkit only manages skills inside the `agent-skills` repo itself. In practice the user has:

- Plugins installed globally in `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`, toggled via `enabledPlugins` in `~/.claude/settings.json`.
- Skills in both `~/.claude/skills/` (global) and `<project>/.github/skills/` (per-project).
- MCPs registered in `~/.claude.json` (global) and/or `<project>/.mcp.json` (per-project).
- Project-local agents in `<project>/.claude/agents/`.

Consequences:

1. **No inventory.** The user can't see what's installed, where, or which profile uses it.
2. **Tool loss on init.** Running `just claude-init` in a project that already had local tools removed the symlinks but had nothing to fall back to — tools were effectively lost.
3. **No reuse.** A skill written for project A can't easily be used in project B.
4. **Token bloat.** Every plugin, every MCP, every skill that's globally enabled loads into every session regardless of profile.

## Goals

- Single source of truth for tools at `~/local/agent-skills/`.
- Discovery is **non-destructive**: tools are *moved* into the pool, never deleted.
- Profile activation is **per-project** so projects don't interfere with each other.
- One inventory command shows everything: what exists, what's active, where, and on which profile.
- Works for both Claude Code and Copilot (both read from `.github/`, `.claude/`, and `.mcp.json` per-project).

## Non-Goals

- Replacing Claude Code's plugin marketplace. Plugin install/uninstall still goes through `claude plugin` commands.
- Managing tool *versions*. The pool tracks what's installed; upgrades are out of band.
- Cross-machine sync. The pool lives on one machine; sync is the user's problem (e.g., dotfiles repo).

## Architecture

### Directory Layout

```
~/local/agent-skills/
├── skills-available/           # the skill pool (one tool = one subdirectory)
├── agents-available/           # the agent pool
├── mcps-available/             # the MCP pool (YAML metadata; MCPs aren't directories)
├── plugins-available/          # the plugin pool (registry stubs; install path stays in ~/.claude/plugins/cache/)
├── profiles/
│   ├── brainstorm.yml
│   ├── code.yml
│   ├── design.yml
│   ├── ship.yml
│   └── minimal.yml
├── registry.yml               # the inventory: every tool, type, source path, profiles, active_in
├── managed-projects.yml       # list of projects that have run `just claude-init`
├── scripts/
│   ├── bootstrap.sh           # one-time global discovery
│   ├── claude-init.sh         # per-project init + migration
│   ├── profile-activate.sh    # symlink + config writes
│   ├── profile-lock.sh
│   ├── tool-list.sh           # inventory display
│   └── ...
└── Justfile                   # imported by each managed project
```

**Why one pool dir per type, suffixed `-available`:** Same pattern as nginx's `sites-available/` + `sites-enabled/` — the `-available` directory is the inventory of everything that *could* be linked, and per-project symlinks act as the "enabled" set. With per-project activation a tool can be active in project A and inactive in project B at the same time, so there's no coherent "globally active" location to put it in. The pool always lives in the `*-available/` directories; "active" state is the existence of a symlink in a specific project.

### registry.yml — the inventory

```yaml
version: 1
assets:
  superpowers:
    type: plugin
    source: ~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7
    profiles: [brainstorm, code]
    active_in: [~/work/project-a]      # projects where the tool is currently activated
  my-custom-skill:
    type: skill
    source: ~/local/agent-skills/skills-available/my-custom-skill
    profiles: [code]
    active_in: []
    origin: project-a                  # for tools migrated from project-local
  browser:
    type: mcp
    source: ~/local/agent-skills/mcps-available/browser.yml
    profiles: [design, code]
    active_in: []
```

The registry is the single source of truth for which tools exist, where their files live, which profiles include them, and which projects currently have them activated. There is no global `state: active|inactive` field — a tool can be active in one project and inactive in another at the same time, so state is tracked as the list of projects that currently link to it (`active_in`). Profile YAMLs reference tools by name only; sources come from the registry.

### Profile YAML

```yaml
name: code
description: "Implementation, debugging, testing"
skills: [test-driven-development, systematic-debugging, my-custom-skill]
agents: []
mcps: [browser]
plugins: [superpowers, context7]
claudeignore:
  - "docs/superpowers/archive/**"
hooks:
  pre_session: true
  post_session: false
```

## Operational Flow

### One-time bootstrap (`just claude-bootstrap`)

Runs once. Idempotent — reruns only register new things that have appeared since.

1. Scan `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`. For each, write a `plugins-available/<name>.yml` metadata stub and add a registry entry with `source` pointing at the install path. Plugins are **not moved**; Claude manages that directory.
2. Scan `~/.claude/skills/`. For each skill, **move** it into `skills-available/`. Update registry.
3. Read `~/.claude.json`'s `mcpServers` section. For each MCP, write `mcps-available/<name>.yml` with the install/remove commands. Update registry.
4. Back up the global `mcpServers` section, then empty it from `~/.claude.json` so MCPs no longer auto-load into every session. (Profile activation re-adds them per-project via `.mcp.json`.)
5. Optionally back up `enabledPlugins` from `~/.claude/settings.json` and set every entry to `false`. Per-project settings will turn the right ones back on.

### Per-project init (`just claude-init`)

Runs once per project. Idempotent.

1. Detect project-local tools and **move** them into the pool's `*-available/` directories:
   - `<project>/.github/skills/<name>/` → `skills-available/<name>/`
   - `<project>/.claude/agents/<name>/` → `agents-available/<name>/`
   - `<project>/.mcp.json` entries → `mcps-available/<name>.yml`
   - `<project>/.claude/settings.json`'s `enabledPlugins` → register in `plugins-available/<name>.yml` (pointing at the global install)
2. Tag migrated tools in the registry with `origin: <project-name>` so the user can later re-add them to a profile.
3. Add the project to `managed-projects.yml`.
4. Prompt for an initial profile and call `profile-activate.sh`.

### Profile activation (`just claude-<profile>`)

Runs every time the user switches modes inside a project.

1. Acquire `<project>/.claude-profile.lock` to prevent concurrent activation.
2. Tear down only **symlinks** in `<project>/.github/skills/` and `<project>/.claude/agents/` (never real files or directories).
3. **Skills.** For each skill in the profile, `ln -s ~/local/agent-skills/skills-available/<name>  <project>/.github/skills/<name>`. Claude follows the symlink and reads the target.
4. **Agents.** Same pattern into `<project>/.claude/agents/`.
5. **MCPs.** Read each `mcps-available/<name>.yml` and write a `<project>/.mcp.json` whose `mcpServers` block contains exactly the profile's MCPs. Replace, don't merge.
6. **Plugins.** Write `<project>/.claude/settings.json` with `enabledPlugins` set to `true` only for the profile's plugins, `false` for everything else in the registry. Project settings override global per Claude Code's settings hierarchy.
7. Sync `<project>/.claudeignore` from the profile.
8. Update each affected tool's `active_in` list in the registry: add `<project>` for tools the profile activated, remove `<project>` for tools no longer in the active set.
9. Update `<project>/.claude-profile.lock` with `<pid>\n<profile-name>` so the user (and other scripts) can see which profile is currently active in the project.
10. Report a summary.

### Inventory (`just claude-list`)

Reads `registry.yml` and prints, grouped by type:

- ● if `active_in` is non-empty, ○ otherwise
- For each: name, projects currently active in, profile membership, origin (if migrated)

Filters: `just claude-list --type=skill`, `just claude-list --profile=code`, `just claude-list --project=<path>`.

## Component Responsibilities

| Component | Responsibility |
|---|---|
| `bootstrap.sh` | Global one-time discovery; populates the pool from existing system state |
| `claude-init.sh` | Per-project migration + initial profile activation |
| `profile-activate.sh` | Tear down old symlinks/configs, install new ones for the chosen profile |
| `tool-list.sh` | Read registry and render inventory |
| `registry.yml` | Single source of truth for what exists, where, and on which profiles |
| `managed-projects.yml` | List of projects under management; allows global queries like "where is `my-custom-skill` active right now?" |
| Profile YAMLs | Declare which tools belong to a profile (by name only — sources come from registry) |
| Project's `.claude/settings.json` | Per-project `enabledPlugins` overrides — written by `profile-activate.sh` |
| Project's `.mcp.json` | Per-project MCP registrations — written by `profile-activate.sh` |

## Data Flow

```
[bootstrap]                                      [profile activate]
~/.claude/plugins/cache  ──┐                ┌──> <project>/.github/skills/  (symlinks)
~/.claude/skills          ─┼─> registry.yml ─┼──> <project>/.claude/agents/  (symlinks)
~/.claude.json (mcps)     ─┘   pool dirs    ├──> <project>/.mcp.json
                                            └──> <project>/.claude/settings.json (enabledPlugins)
                              [project init]
<project>/.github/skills    ─┐
<project>/.claude/agents    ─┼─> moved into pool, registered
<project>/.mcp.json         ─┘
```

## Error Handling

- **Lock conflict.** If `<project>/.claude-profile.lock` exists with a different PID, abort and instruct the user to release it manually.
- **Missing tool.** If a profile references a tool not in the registry, warn and skip it (don't fail the whole activation).
- **Bootstrap re-run.** Detect already-registered entries by source path; skip them silently.
- **Init on a project with broken symlinks.** Treat broken symlinks as "no tool" — don't move them, just report.
- **Tear down safety.** Activation only deletes files in `<project>/.github/skills/` and `<project>/.claude/agents/` if they are symlinks. Real files or directories are left in place and reported as a warning.

## Testing Strategy

- **Bootstrap** — set up a fixture `$HOME` containing fake `~/.claude/plugins/`, `~/.claude/skills/`, `~/.claude.json`. Run bootstrap. Assert pool contents and registry state.
- **Per-project init** — fixture with `.github/skills/foo/`, `.claude/agents/bar/`. Run init. Assert files moved, registry updated, original dirs empty.
- **Activation** — set up a registry + profile, run activate, assert symlinks point at the right targets and `.mcp.json` / `.claude/settings.json` are written correctly.
- **Tear down safety** — put a real file (not a symlink) in `.github/skills/`, run activation, assert it's not deleted.
- **Idempotency** — run bootstrap twice; assert no duplicate registry entries.
- **Profile switch** — activate `code`, then activate `brainstorm`, assert the previous symlinks are gone and the new ones are present.

## Migration

Existing users of the current toolkit:

1. Pull the new version. Existing `profiles/*.yml` keep working — schema is a superset.
2. Run `just claude-bootstrap`. Their globally-installed tools get registered in the pool.
3. For each managed project, run `just claude-init` once. Project-local tools get migrated.
4. The first profile activation after migration writes the new `.mcp.json` and `.claude/settings.json` files. Old `claude mcp add`-style global registrations are no longer needed.

## Open Questions

None at design time. Implementation may surface specifics of how Claude Code resolves `.claude/settings.json` precedence in edge cases (e.g., conflicting `enabledPlugins` between user and project) — these will be tested during implementation.
