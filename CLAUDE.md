# lguidolin/agent-skills

House engineering skills for Claude Code: the engineering constitution,
stack-specific guidance, and repo automation.

## Project Structure

```
skills/       → The skills (SKILL.md per directory) — the product
scripts/      → install.sh (deploy the pool), plugin-skills.sh (collision check)
tests/        → Bash test suite (tests/run.sh) — skill lint + install
docs/         → Setup guide, constitution reference, decision archive
```

A skill that needs tooling bundles it under `skills/<name>/scripts/` and
`skills/<name>/templates/`, referenced relative to its `SKILL.md` — see
`recording-decisions`. Skills must never reference this repo's `Justfile`;
it does not exist where they are installed.

There is no profile/activation system: skills install globally into
`~/.claude/skills/` (or are copied into a project's `.claude/skills/`).
See "Why There Is No Profile System" in README.md.

## Skills

House rules and stack skills only. Methodology skills (brainstorming, TDD,
writing-plans, systematic debugging, code review) come from the **superpowers
plugin**, which is the source of truth for them — never vendor a copy here.
See "What Belongs in This Repo" in README.md.

- **engineering-constitution** + 11 Tier-1 discipline skills — always-on rules
- **init-repo-CI** — Scaffold conventional commits + release-please + CI automation
- **commit-history-rewrite** — Rewrite messy commit history to conform to conventional commits
- **ship-it** — Push, PR, archive decision records, merge, cleanup

## Conventions

- Every skill lives in `skills/<name>/SKILL.md`
- A skill name must not collide with one shipped by an installed plugin;
  `scripts/plugin-skills.sh` lists those names; `install.sh` and the test suite
  both refuse a collision
- YAML frontmatter with `name` and `description` fields
- Description starts with trigger conditions ("Use when...")
- Skills come in two archetypes, and the required sections differ:
  - **Rule skills** (the constitution and its discipline skills) state standing
    rules. Required: `Overview`, the rules themselves, and a
    `Full rationale:` footer citing the constitution article. Most also carry
    `Common Rationalizations` and `Red Flags` — the two sections that do the
    real work of holding a rule under pressure. They have no `Process`, because
    there is no procedure to run.
  - **Procedural skills** (`ship-it`, `init-repo-CI`, `commit-history-rewrite`)
    walk through an ordered task. Required: `Overview`, `When to Use`,
    `When NOT to Use`, `Process`.
- The constitution text is bundled at
  `skills/engineering-constitution/references/engineering-constitution.md` so it
  travels with the skill. Never cite it by a `docs/` path from inside a skill —
  that path resolves against whatever project is open, not this repo.
