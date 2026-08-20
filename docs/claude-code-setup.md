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

### Skills Install (recommended)

The skills in `skills/` install directly into the directories Claude Code reads:

```bash
git clone https://github.com/lguidolin/agent-skills.git ~/local/agent-skills

# Personal — symlink into ~/.claude/skills, updates on git pull
~/local/agent-skills/scripts/install.sh --global

# Team — copy into a repo's .claude/skills and commit
~/local/agent-skills/scripts/install.sh --project .
```

There is no profile or activation step: Claude Code loads each skill's
description up front and the body only when the skill is invoked, so the whole
set costs little context. See "Why There Is No Profile System" in the README.

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

Do not copy superpowers skills into this repo. `scripts/install.sh` refuses to
install a skill whose name a plugin already owns, and `tests/test_skills.sh`
asserts the pool stays clean — so a vendored copy fails loudly instead of
silently shadowing the maintained one. Run `scripts/plugin-skills.sh` to see
which names are taken.
