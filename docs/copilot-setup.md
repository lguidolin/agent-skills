# Using lguidolin/agent-skills with GitHub Copilot

## Setup

### Skills

Copilot discovers skills from `.github/skills/<name>/SKILL.md` in your repository.

```bash
# Clone the repo
git clone https://github.com/lguidolin/agent-skills.git /tmp/lguidolin-agent-skills

# Copy skills into your project
mkdir -p .github/skills
cp -r /tmp/lguidolin-agent-skills/skills/* .github/skills/
```

This installs:
- `.github/skills/repo-automation-setup/SKILL.md`
- `.github/skills/commit-history-rewrite/SKILL.md`

### Verify

After copying, confirm the skills appear when you type `/` in Copilot Chat. You should see `repo-automation-setup` and `commit-history-rewrite` in the list.

## Usage

- **Set up automation:** Ask Copilot to set up conventional commits and release-please, or invoke `/repo-automation-setup`
- **Rewrite history:** Ask Copilot to clean up commit history, or invoke `/commit-history-rewrite`

Skills also activate automatically when Copilot detects a relevant task based on the skill's `description` field.
