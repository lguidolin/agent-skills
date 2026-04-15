# Using lguidolin/agent-skills with Claude Code

## Setup

### Marketplace Install

```
/plugin marketplace add lguidolin/agent-skills
/plugin install lguidolin-agent-skills@lguidolin-agent-skills
```

> **SSH errors?** The marketplace clones repos via SSH. If you don't have SSH keys configured, switch to HTTPS:
> ```bash
> git config --global url."https://github.com/".insteadOf "git@github.com:"
> ```

### Local / Development Install

```bash
git clone https://github.com/lguidolin/agent-skills.git
claude --plugin-dir /path/to/agent-skills
```

## Slash Commands

Once installed, two slash commands are available:

| Command | Skill |
|---------|-------|
| `/setup-repo` | repo-automation-setup |
| `/rewrite-history` | commit-history-rewrite |

## Usage

- **Set up automation:** `/setup-repo` or ask Claude to set up conventional commits and release-please
- **Rewrite history:** `/rewrite-history` or ask Claude to clean up commit history to conventional commits
