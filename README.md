# Agent Skills

Custom skills for AI coding agents. Designed for GitHub Copilot and Claude Code, compatible with any agent that accepts markdown instruction files.

## Skills

| Skill | Use When |
|-------|----------|
| [repo-automation-setup](skills/repo-automation-setup/SKILL.md) | Setting up conventional commits, release-please, PR validation, and CI automation in any repository |
| [commit-history-rewrite](skills/commit-history-rewrite/SKILL.md) | Rewriting messy commit history to conform to conventional commits before adopting release-please |
| [branch-push-pr](skills/branch-push-pr/SKILL.md) | Pushing changes through the branch → commit → push → PR workflow with conventional commit messages |

## Dependencies

These skill libraries are recommended companions — install them alongside this repo for a complete workflow:

| Repo | What it provides |
|------|-----------------|
| [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | 20 production engineering skills + agent personas (code-reviewer, test-engineer, security-auditor) |
| [obra/superpowers](https://github.com/obra/superpowers) | Workflow skills (brainstorming, TDD, systematic debugging, subagent-driven development, code review) |

## Quick Start

<details>
<summary><b>Claude Code</b></summary>

**Marketplace install:**

```
/plugin marketplace add lguidolin/agent-skills
/plugin install lguidolin-agent-skills@lguidolin-agent-skills
```

> **SSH errors?** The marketplace clones repos via SSH. If you don't have SSH keys configured:
> ```bash
> git config --global url."https://github.com/".insteadOf "git@github.com:"
> ```

**Local / development:**

```bash
git clone https://github.com/lguidolin/agent-skills.git
claude --plugin-dir /path/to/agent-skills
```

See [docs/claude-code-setup.md](docs/claude-code-setup.md) for details.

</details>

<details>
<summary><b>GitHub Copilot</b></summary>

Copy skills into your project's `.github/skills/` directory:

```bash
git clone https://github.com/lguidolin/agent-skills.git /tmp/lguidolin-agent-skills
mkdir -p .github/skills
cp -r /tmp/lguidolin-agent-skills/skills/* .github/skills/
```

This installs:
- `.github/skills/repo-automation-setup/SKILL.md`
- `.github/skills/commit-history-rewrite/SKILL.md`
- `.github/skills/branch-push-pr/SKILL.md`

> **Companion skills and permissions:** The setup guide covers installing the recommended companion skill repos listed in [Dependencies](#dependencies), plus the GitHub repository permissions needed for the automation workflows to function. See [docs/copilot-setup.md](docs/copilot-setup.md) for the full walkthrough.

</details>

<details>
<summary><b>Other Agents</b></summary>

Skills are plain Markdown — they work with any agent that accepts system prompts or instruction files. Copy the relevant `SKILL.md` into your agent's rules directory, or paste the content into your system prompt.

```bash
git clone https://github.com/lguidolin/agent-skills.git
# Then copy skills/<name>/SKILL.md to your agent's rules location
```

</details>

## Project Structure

```
agent-skills/
├── skills/                       # Core skills (SKILL.md per directory)
│   ├── repo-automation-setup/    #   Conventional commits + release-please + CI
│   ├── commit-history-rewrite/   #   Rewrite messy history to conventional commits
│   └── branch-push-pr/           #   Branch + commit + push + PR workflow
├── .claude-plugin/               # Claude Code plugin manifest
├── .claude/commands/             # Claude Code slash commands
└── docs/                         # Setup guides per tool
```

## Acknowledgments

The skills in this repo incorporate engineering patterns and principles from:

- **[addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)** (MIT License, Copyright 2025 Addy Osmani) — specifically the `git-workflow-and-versioning`, `ci-cd-and-automation`, `code-review-and-quality`, and `deprecation-and-migration` skills
- **[obra/superpowers](https://github.com/obra/superpowers)** (MIT License, Copyright 2025 Jesse Vincent) — workflow patterns for spec-driven development and plan execution

## License

[GPLv3](LICENSE)
