# Agent Skills

Skills and agent personas for AI coding agents. Designed for GitHub Copilot, compatible with any agent that accepts markdown instruction files.

## Skills

| Skill | Use When |
|-------|----------|
| [repo-automation-setup](skills/repo-automation-setup/SKILL.md) | Setting up conventional commits, release-please, PR validation, and CI automation in any repository |
| [commit-history-rewrite](skills/commit-history-rewrite/SKILL.md) | Rewriting messy commit history to conform to conventional commits before adopting release-please |

## Agents

| Agent | Role |
|-------|------|
| [code-reviewer](agents/code-reviewer.md) | Five-axis code review (correctness, readability, architecture, security, performance) |
| [test-engineer](agents/test-engineer.md) | Test strategy, coverage analysis, writing tests |
| [security-auditor](agents/security-auditor.md) | Vulnerability detection, threat modeling, OWASP |
| [superpowers-code-reviewer](agents/superpowers-code-reviewer.md) | Review completed plan steps against original spec |

## Installation

### GitHub Copilot (per-repo)

```bash
# Clone into your project
mkdir -p .github/skills .github/agents
git clone https://github.com/lguidolin/agent-skills.git /tmp/agent-skills

# Symlink skills
ln -s /path/to/agent-skills/skills .github/skills/lguidolin-agent-skills

# Copy agents
cp /tmp/agent-skills/agents/*.md .github/agents/
```

### Global (all repos)

```bash
# Persistent clone
git clone https://github.com/lguidolin/agent-skills.git ~/.copilot-assets/repos/lguidolin-agent-skills

# Global skill discovery
mkdir -p ~/.agents/skills
ln -s ~/.copilot-assets/repos/lguidolin-agent-skills/skills ~/.agents/skills/lguidolin-agent-skills
```

### Update

```bash
cd ~/.copilot-assets/repos/lguidolin-agent-skills && git pull
```

## License

MIT
