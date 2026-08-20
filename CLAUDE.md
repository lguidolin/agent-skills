# lguidolin/agent-skills

Custom skills for repository automation and commit history management.

## Project Structure

```
skills-available/  → The skill pool (SKILL.md per directory) — source of truth
profiles/          → Profile definitions (skills + agents + mcps + plugins)
scripts/           → Pool management: bootstrap, registry, profile activation
tests/             → Bash test suite (tests/run.sh)
docs/              → Setup guides for different tools
```

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

- Every skill lives in `skills-available/<name>/SKILL.md`
- A skill name must not collide with one shipped by an installed plugin;
  `scripts/plugin-skills.sh` lists those names and the registry rejects collisions
- YAML frontmatter with `name` and `description` fields
- Description starts with trigger conditions ("Use when...")
- Every skill has: Overview, When to Use, When NOT to Use, Process
