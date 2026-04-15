# Agent Skills

Custom skills for AI coding agents. Designed for GitHub Copilot, compatible with any agent that accepts markdown instruction files.

## Skills

| Skill | Use When |
|-------|----------|
| [repo-automation-setup](skills/repo-automation-setup/SKILL.md) | Setting up conventional commits, release-please, PR validation, and CI automation in any repository |
| [commit-history-rewrite](skills/commit-history-rewrite/SKILL.md) | Rewriting messy commit history to conform to conventional commits before adopting release-please |

## Dependencies

These skill libraries are recommended companions — install them alongside this repo for a complete workflow:

| Repo | What it provides |
|------|-----------------|
| [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | 20 production engineering skills + agent personas (code-reviewer, test-engineer, security-auditor) |
| [obra/superpowers](https://github.com/obra/superpowers) | Workflow skills (brainstorming, TDD, systematic debugging, subagent-driven development, code review) |

## Installation

### GitHub Copilot (per-repo)

```bash
mkdir -p .github/skills

# Install this repo
git clone https://github.com/lguidolin/agent-skills.git /tmp/lguidolin-agent-skills
ln -s /tmp/lguidolin-agent-skills/skills .github/skills/lguidolin-agent-skills

# Install dependencies (recommended)
git clone https://github.com/addyosmani/agent-skills.git /tmp/addyosmani-agent-skills
ln -s /tmp/addyosmani-agent-skills/skills .github/skills/agent-skills
cp /tmp/addyosmani-agent-skills/agents/*.md .github/agents/

git clone https://github.com/obra/superpowers.git /tmp/superpowers
ln -s /tmp/superpowers/skills .github/skills/superpowers
cp /tmp/superpowers/agents/*.md .github/agents/
```

### Global (all repos)

```bash
mkdir -p ~/.copilot-assets/repos ~/.agents/skills

# Install this repo
git clone https://github.com/lguidolin/agent-skills.git ~/.copilot-assets/repos/lguidolin-agent-skills
ln -s ~/.copilot-assets/repos/lguidolin-agent-skills/skills ~/.agents/skills/lguidolin-agent-skills

# Install dependencies (recommended)
git clone https://github.com/addyosmani/agent-skills.git ~/.copilot-assets/repos/agent-skills
ln -s ~/.copilot-assets/repos/agent-skills/skills ~/.agents/skills/agent-skills

git clone https://github.com/obra/superpowers.git ~/.copilot-assets/repos/superpowers
ln -s ~/.copilot-assets/repos/superpowers/skills ~/.agents/skills/superpowers
```

### Update

```bash
cd ~/.copilot-assets/repos/lguidolin-agent-skills && git pull
cd ~/.copilot-assets/repos/agent-skills && git pull
cd ~/.copilot-assets/repos/superpowers && git pull
```

## Acknowledgments

The skills in this repo incorporate engineering patterns and principles from:

- **[addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)** (MIT License, Copyright 2025 Addy Osmani) — specifically the `git-workflow-and-versioning`, `ci-cd-and-automation`, `code-review-and-quality`, and `deprecation-and-migration` skills
- **[obra/superpowers](https://github.com/obra/superpowers)** (MIT License, Copyright 2025 Jesse Vincent) — workflow patterns for spec-driven development and plan execution

## License

[GPLv3](LICENSE)
