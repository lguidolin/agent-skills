# lguidolin/agent-skills

Custom skills for repository automation and commit history management.

## Project Structure

```
skills/       → Core skills (SKILL.md per directory)
docs/         → Setup guides for different tools
```

## Skills

- **repo-automation-setup** — Scaffold conventional commits + release-please + CI automation
- **commit-history-rewrite** — Rewrite messy commit history to conform to conventional commits

## Conventions

- Every skill lives in `skills/<name>/SKILL.md`
- YAML frontmatter with `name` and `description` fields
- Description starts with trigger conditions ("Use when...")
- Every skill has: Overview, When to Use, When NOT to Use, Process
