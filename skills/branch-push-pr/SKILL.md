---
name: branch-push-pr
description: Use when the user wants to push changes, commit work, create a branch, open a pull request, or ship code. Handles the full workflow of staging, committing with conventional commit messages, creating a feature branch, pushing, and opening a PR.
---

# Branch, Push, and PR

Handle the complete git workflow for shipping changes: stage, commit with conventional commit messages, create a branch, push to remote, and open a pull request.

## Overview

**Every change goes through a branch and PR.** Never push directly to main. This ensures all changes are reviewed, validated by CI, and produce clean conventional commit history when squash-merged.

**Commit messages are documentation.** The PR title becomes the squash-merge commit on main and appears in the changelog. Get it right at PR creation time, not after.

This skill executes the full cycle: assess what changed, craft a proper conventional commit, create a well-named branch, push, and open a PR with a meaningful description.

## When to Use

- User says "push", "commit", "ship it", "let's push", "open a PR", "create a PR"
- User says "merged", "it's merged", "pull and cleanup" after a PR was opened
- User has uncommitted changes and wants to get them into a PR
- User has committed changes on a local branch and wants to push and open a PR
- After completing a task where the next step is to submit the work

## When NOT to Use

- User explicitly wants to push directly to main (confirm this is intentional first)
- Repo has no remote configured
- Changes are work-in-progress the user isn't ready to push yet

## Process

### Step 1: Assess Current State

```bash
# What branch are we on?
git branch --show-current

# Are we on main/master? (need to create a branch)
# Are we already on a feature branch? (may just need to push)

# What's the status?
git status --short

# What's changed? (staged and unstaged)
git diff --stat
git diff --cached --stat

# Any existing commits not yet pushed?
git log --oneline @{upstream}..HEAD 2>/dev/null || echo "No upstream set"
```

**Decision tree:**
- On main with uncommitted changes → create branch, commit, push, PR
- On main with committed changes → create branch (cherry-pick or reset dance), push, PR
- On feature branch with uncommitted changes → commit, push, PR (or update existing PR)
- On feature branch with unpushed commits → push, PR (or update existing PR)
- On feature branch with existing PR → push (PR already exists)

### Step 2: Stage Changes

If there are unstaged changes, determine what to stage:

```bash
# Show what files changed
git status --short
```

**Ask the user** if all changes should be included, or if they want to select specific files. If the changes are clearly all part of one logical unit, stage everything:

```bash
git add -A
```

If changes span multiple concerns, suggest splitting into separate commits/PRs. Each PR should be one logical change.

### Step 3: Craft the Commit Message

Analyze the staged changes to determine the correct conventional commit message:

```bash
# Review what's staged
git diff --cached --stat
git diff --cached
```

#### Determine the commit type

| Type | When |
|------|------|
| `feat` | New functionality, new files that add capabilities |
| `fix` | Bug fixes, error corrections |
| `docs` | Documentation only (README, SKILL.md, comments) |
| `chore` | Config, dependencies, build, tooling, maintenance |
| `refactor` | Code restructuring with no behavior change |
| `test` | Adding or modifying tests |
| `ci` | CI/CD workflow changes |

#### Determine the scope (optional)

Scope narrows the type to a specific area. Use when helpful:
- `feat(auth): add OAuth2 login flow`
- `fix(api): handle null response from upstream`
- `docs(setup): add permissions section`
- `chore(deps): update dependencies`

#### Write the message

Format: `<type>[optional scope]: <imperative description>`

Rules:
- Imperative mood ("add", not "added" or "adds")
- Lowercase first word after colon
- No period at the end
- Short (50 chars or less for the subject)
- Describe *what* the commit does, not *how*

**Present the proposed commit message to the user and confirm before committing.** If the user suggests a different message, use theirs (as long as it follows conventional commits format).

### Step 4: Create the Branch

If currently on main/master, create a branch. Branch naming convention:

```
<type>/<short-description>
```

Examples:
- `feat/oauth-login`
- `fix/null-response-handling`
- `docs/copilot-setup-permissions`
- `chore/update-dependencies`

The type prefix should match the commit type. The description uses kebab-case, is short (2-4 words), and describes the change.

**Propose the branch name to the user and confirm before creating.** Example:

> Proposed branch name: `feat/oauth-login`

```bash
git checkout -b <type>/<short-description>
```

If already on a feature branch, stay on it.

### Step 5: Commit

```bash
git commit -m "<conventional commit message>"
```

If there are multiple logical changes that should be separate commits, make multiple commits on the same branch. Each commit should follow conventional commits format.

### Step 6: Push

```bash
# First push (set upstream)
git push -u origin $(git branch --show-current)

# Subsequent pushes
git push
```

If the push fails due to authentication, help the user troubleshoot:
- SSH key issues: check `ssh -T git@github.com`
- HTTPS token issues: check `gh auth status` or credential helper
- Permission issues: verify write access to the repo

### Step 7: Open a Pull Request

**Determine the PR title.** The PR title should be the conventional commit message (since squash-merge will use it as the commit on main). If there are multiple commits, the PR title should summarize the overall change.

**Write the PR body.** Structure:

```markdown
## What changed

[Describe the changes — be specific about what was added, modified, or removed]

## Why

[Explain the motivation — why was this change needed? What problem does it solve?]
```

**Present the full PR proposal to the user and confirm before creating.** Show the title and body together:

> **PR title:** `feat: add OAuth2 login flow`
>
> **PR body:**
> ## What changed
> Added OAuth2 authentication with Google and GitHub providers...
>
> ## Why
> Users need SSO login to avoid managing separate credentials...

Wait for the user to approve or suggest changes before proceeding.

**Create the PR** using whichever method is available:

```bash
# Preferred: gh CLI
gh pr create --title "<conventional commit message>" --body "<PR body>"

# If gh is not installed, provide the URL from git push output
# or the constructed URL: https://github.com/<owner>/<repo>/pull/new/<branch>
```

If `gh` CLI is not available:
1. Check if the push output included a PR creation URL
2. Construct the URL: `https://github.com/<owner>/<repo>/pull/new/<branch>`
3. Present the URL to the user

### Step 8: Verify

After the PR is created:

```bash
# Confirm PR exists
gh pr view --web 2>/dev/null || echo "Open the PR URL in your browser to verify"
```

If the repo has CI checks (like PR title validation from repo-automation-setup), mention that the user should verify those pass.

### Step 9: Wait for Merge and Clean Up

After the PR is created, **ask the user if they'd like to wait for the merge and clean up**. If yes, pause and wait for the user to confirm the PR has been merged (e.g., "merged", "done", "it's merged").

Once the user confirms the PR is merged:

```bash
# Switch to the default branch
git checkout main

# Pull the merged changes (includes the squash-merge commit)
git pull

# Delete the local feature branch
git branch -d <branch-name>
```

If the remote branch wasn't auto-deleted by GitHub (check repo settings → General → "Automatically delete head branches"):

```bash
# Delete the remote branch
git push origin --delete <branch-name>
```

**Verify clean state:**

```bash
# Confirm we're on main with no stale branches
git branch --show-current
git log --oneline -3
git branch -l
```

If there are stale local branches tracking deleted remotes, clean them up:

```bash
# Prune remote-tracking references
git fetch --prune

# List local branches with gone upstreams
git branch -vv | grep ': gone]'
```

Offer to delete any stale branches found. Don't delete without asking — the user may have local work on them.

## Handling Edge Cases

### Already on a feature branch with an existing PR
Just push. The existing PR will update automatically.

```bash
git push
```

### Multiple unrelated changes
Suggest splitting into separate branches/PRs. Help the user use `git add -p` or selective staging to separate concerns.

### Merge conflicts with main
```bash
git fetch origin
git rebase origin/main
# Resolve conflicts if any
git push --force-with-lease
```

Use `--force-with-lease` (never `--force`) to prevent overwriting others' work.

### Empty diff
If `git status` shows nothing to commit, tell the user — don't create an empty commit.

## Red Flags

- Pushing directly to main without a PR
- Commit messages like "fix", "update", "changes", "wip" as the PR title
- Giant PRs (1000+ lines) that should be split
- Mixing unrelated changes in one PR
- Using `--force` instead of `--force-with-lease`
- Forgetting to set upstream on first push
- PR title that doesn't follow conventional commits format
