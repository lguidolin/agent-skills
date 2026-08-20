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

Once installed, three slash commands are available:

| Command | Skill |
|---------|-------|
| `/setup-repo` | init-repo-CI |
| `/rewrite-history` | commit-history-rewrite |
| `/push` | ship-it |

## Usage

- **Set up automation:** `/setup-repo` or ask Claude to set up conventional commits and release-please
- **Rewrite history:** `/rewrite-history` or ask Claude to clean up commit history to conventional commits
- **Push changes:** `/push` or ask Claude to commit, push, and open a PR

## Companion Plugins

This repo deliberately ships **only** house rules, stack skills, and repo
automation. Workflow methodology comes from the
[superpowers](https://github.com/obra/superpowers) plugin, which is the source
of truth for the skills it ships — brainstorming, writing/executing plans, TDD,
systematic debugging, code review, worktrees, and subagent-driven development.

Install it from the Claude Code marketplace:

```
/plugin
```

Do not copy superpowers skills into this repo. `registry.sh` and
`profile-activate.sh` reject a pool skill whose name a plugin already owns, so a
vendored copy fails loudly instead of silently shadowing the maintained one.
Run `scripts/plugin-skills.sh` to see which names are taken.
