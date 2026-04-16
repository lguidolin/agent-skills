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
- `.github/skills/branch-push-pr/SKILL.md`

### Recommended Companion Skills

These skill libraries are recommended companions that provide a complete workflow alongside the core skills above. **Ask the user if they would like to install either or both:**

| Repo | What it provides | Install command |
|------|-----------------|-----------------|
| [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | 20 production engineering skills + agent personas (code-reviewer, test-engineer, security-auditor) | See below |
| [obra/superpowers](https://github.com/obra/superpowers) | Workflow skills (brainstorming, TDD, systematic debugging, subagent-driven development, code review) | See below |

**To install addyosmani/agent-skills:**
```bash
git clone https://github.com/addyosmani/agent-skills.git /tmp/addyosmani-agent-skills
cp -r /tmp/addyosmani-agent-skills/skills/* .github/skills/
# Also install agent personas if the repo has a .github/agents/ directory convention:
mkdir -p .github/agents
cp -r /tmp/addyosmani-agent-skills/agents/* .github/agents/ 2>/dev/null || true
```

**To install obra/superpowers:**
```bash
git clone https://github.com/obra/superpowers.git /tmp/obra-superpowers
cp -r /tmp/obra-superpowers/skills/* .github/skills/
```

### Repository Permissions

The `repo-automation-setup` skill creates GitHub Actions workflows that require specific repository permissions to function. These must be configured **before the first push to the default branch**, or the release automation will fail.

#### Required: GitHub Actions Workflow Permissions

Go to **GitHub repo → Settings → Actions → General → Workflow permissions** and enable:

- **Read and write permissions** — required for release-please to push changelog commits and create releases
- **Allow GitHub Actions to create and approve pull requests** — required for release-please to open release PRs

Without these settings, the Release Automation workflow will fail with:
> `GitHub Actions is not permitted to create or approve pull requests.`

#### Recommended: Branch Protection

After the initial automation commit is on your default branch, configure branch protection under **GitHub repo → Settings → Branches → Add rule** for your default branch:

- **Require pull request before merging** — all changes go through PR review
- **Require status checks to pass before merging** — add "Validate PR Title" as a required check
- **Require branches to be up to date before merging** — prevent stale merges
- **Allow only squash merging** — ensures every commit on main is a conventional commit (configure under **Settings → General → Pull Requests**)
- **Require linear history** — keeps the commit graph clean

> **Offer to help:** If the user has the GitHub CLI (`gh`) installed and authenticated, you can help configure some of these settings programmatically:
> ```bash
> # Check if gh CLI is available and authenticated
> gh auth status
>
> # Enable squash-merge only
> gh repo edit --enable-squash-merge --delete-branch-on-merge
>
> # Note: Branch protection rules require GitHub API calls or manual setup
> # for repos on free plans. For GitHub Pro/Team/Enterprise:
> gh api repos/{owner}/{repo}/branches/{branch}/protection \
>   --method PUT \
>   --field required_status_checks='{"strict":true,"contexts":["Validate PR Title"]}' \
>   --field enforce_admins=true \
>   --field required_pull_request_reviews='{"required_approving_review_count":0}' \
>   --field restrictions=null
> ```

### Verify

After copying, confirm the skills appear when you type `/` in Copilot Chat. You should see `repo-automation-setup` and `commit-history-rewrite` in the list (plus any companion skills you installed).

## Usage

- **Set up automation:** Ask Copilot to set up conventional commits and release-please, or invoke `/repo-automation-setup`
- **Rewrite history:** Ask Copilot to clean up commit history, or invoke `/commit-history-rewrite`
- **Push changes:** Ask Copilot to push your changes, or invoke `/branch-push-pr`

Skills also activate automatically when Copilot detects a relevant task based on the skill's `description` field.
