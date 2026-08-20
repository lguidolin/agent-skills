---
name: commit-history-rewrite
description: Use when an existing repository has messy commit history that needs to conform to conventional commits before adopting release-please, or when intermediate WIP/fixup/merge commits need to be cleaned up.
---

# Commit History Rewrite

Rewrite an existing repository's commit history to conform to conventional commits. Analyzes commits, classifies them by type, identifies squash candidates, and executes the rewrite with full safety gates.

## Overview

**History is documentation.** Every commit message on main is a permanent record that future engineers (and agents) use to understand *what* changed and *why*. Messages like "fix", "update", "wip" destroy this documentation. Release-please parses commit messages to determine version bumps — non-conforming messages produce wrong or no releases.

**Code is a liability.** Hyrum's Law applies to git history too: with enough tooling depending on commit messages (changelogs, release automation, `git bisect`, `git blame`), the format of those messages becomes a contract. Cleaning up history before adopting automation prevents the old messages from polluting every downstream tool.

This skill rewrites the *messages*, not the *code*. The file tree must be identical before and after — only commit metadata changes.

## When to Use

- Adopting conventional commits in a repo with existing non-conforming history
- Commit log is polluted with WIP, fixup, merge, or meaningless messages
- Preparing a repo for release-please (which needs conventional commits to function)
- Cleaning up before open-sourcing or transferring a repository

## When NOT to Use

- Repo has already been published with conventional commits (nothing to rewrite)
- Shared branches with active collaborators who haven't been notified
- You only need to fix the *last few* commits (use `git rebase -i HEAD~N` directly)
- Repo is a fork where upstream controls the commit format

## Process

### Step 1: Assess the Repository

```bash
# Count total commits
git rev-list --count HEAD

# Show commit message summary
git log --oneline --no-merges

# Check for collaborators (authorship diversity)
git shortlog -sne --no-merges

# Identify merge commit density
git log --merges --oneline | wc -l
```

**Decision point:** If commit count < 50, use interactive rebase. If >= 50, use git-filter-repo.

### Step 2: Classify Existing Commits

Analyze each commit using *two signals*: the message text and the files changed. When the message is ambiguous (e.g., "update stuff"), the diff is the source of truth.

#### Signal 1: Message Content

| Signal in message | Assigned Type |
|-------------------|--------------|
| "add", "new", "implement", "create", "introduce", "support" | `feat` |
| "fix", "bug", "patch", "resolve", "correct", "handle error" | `fix` |
| "refactor", "restructure", "reorganize", "simplify", "extract", "move" | `refactor` |
| "update dep", "bump", "upgrade", "version", "config", "setup" | `chore` |
| "test", "spec", "coverage", "assert" | `test` |
| "doc", "readme", "comment", "typo in doc" | `docs` |
| "ci", "workflow", "pipeline", "action", "deploy" | `ci` |

#### Signal 2: Changed Files (when message is ambiguous)

```bash
git show --stat --format="" <hash>
```

| File pattern | Assigned Type |
|-------------|--------------|
| Only `*.md`, `docs/**` | `docs` |
| Only `*test*`, `*spec*`, `__tests__/**` | `test` |
| Only `.github/workflows/**`, `.gitlab-ci.yml`, `Jenkinsfile` | `ci` |
| Only `package.json`, `*.lock`, `requirements.txt`, `Cargo.toml` | `chore` |
| Only config files (`.eslintrc`, `tsconfig.json`, `.prettierrc`) | `chore` |

#### Squash Candidates

| Signal | Action |
|--------|--------|
| Message is "WIP", "wip", "temp", "save", "checkpoint", single word, or empty | **squash into nearest meaningful commit** |
| Message is "fixup", "fix typo", "oops", "lint", "formatting" | **squash into previous** |
| Merge commits (from non-squash merges) | **squash candidate** — evaluate if content is already on main |

For ambiguous commits, check the full diff (`git show <hash>`) to determine type from content.

### Step 3: Write Quality Messages

Rewritten messages must follow commit message standards:

```
<type>[optional scope]: <short imperative description>

[optional body explaining WHY, not what]
```

**Good rewrites:**
```
"initial setup"           →  "chore: initial project setup"
"added login"             →  "feat: add user login"
"fix bug"                 →  "fix: resolve login redirect loop"
"Update README.md"        →  "docs: update README with setup instructions"
"updated deps"            →  "chore(deps): update dependencies"
```

**Bad rewrites** (don't do these):
```
"stuff"                   →  "chore: stuff"          ← still meaningless
"changes"                 →  "feat: changes"         ← no description
"fix"                     →  "fix: fix"              ← redundant
```

When the original message is meaningless, **read the diff** to write a proper description. If the diff is too large or ambiguous, ask the user what the commit was about.

### Step 4: Present the Rewrite Plan

Before any destructive action, show the user a complete plan:

```
REWRITE PLAN
============
Total commits: 47
Commits to rewrite: 32
Commits to squash: 8
Commits already conforming: 7
Authors preserved: 3 (Alice <alice@co>, Bob <bob@co>, CI Bot <bot@co>)

PROPOSED CHANGES:
  abc1234  "initial setup"           →  "chore: initial project setup"
  def5678  "added login"             →  "feat: add user login"
  ghi9012  "wip"                     →  [SQUASH into def5678]
  jkl3456  "fix bug"                 →  "fix: resolve login redirect loop"
  mno7890  "Update README.md"        →  "docs: update README with setup instructions"
  pqr1234  "feat: add search"        →  [KEEP — already conforming]
  ...

SAFETY:
  ✓ Backup branch: backup/pre-rewrite-<timestamp>
  ⚠ Force push required after rewrite
  ⚠ All collaborators must re-clone or reset after push

UNCHANGED:
  - File tree (zero content changes)
  - Author name, email, and date on every commit
  - Commit order and parent relationships (except squashed commits)
```

**Wait for explicit user approval before proceeding.** Don't proceed on "sounds good" — require "yes" or equivalent.

### Step 5: Create Backup

```bash
# Create a backup branch at current HEAD
git branch "backup/pre-rewrite-$(date +%Y%m%d-%H%M%S)"

# Verify backup exists
git branch -l 'backup/*'

# Optionally push backup to remote for extra safety
git push origin "backup/pre-rewrite-$(date +%Y%m%d-%H%M%S)"
```

### Step 6: Execute the Rewrite

#### Option A: Interactive Rebase (< 50 commits)

```bash
# Rebase from root
git rebase -i --root
```

In the editor:
- Mark squash candidates with `squash` or `fixup`
- Mark message rewrites with `reword`
- Preserve commit order

**Authorship preservation:** Interactive rebase preserves author name, email, and date by default. Do NOT use `--reset-author`. Do NOT use `--committer-date-is-author-date` unless specifically asked.

#### Option B: git-filter-repo (>= 50 commits)

Create a Python callback script (`rewrite-messages.py`) that maps old messages to new ones:

```python
import re

REWRITES = {
    b'old hash prefix': b'new message',
    # ... generated from the plan
}

def rewrite(commit, metadata):
    # Look up by original message or hash
    if commit.original_id in REWRITES:
        commit.message = REWRITES[commit.original_id]
```

Apply with:

```bash
git filter-repo --commit-callback "$(cat rewrite-messages.py)" --force
```

**Authorship preservation:** git-filter-repo preserves authorship by default. Do NOT use `--mailmap` or author-rewriting flags unless the user explicitly requests it.

#### Squashing Commits

For squash candidates, combine into the nearest meaningful commit. The resulting commit:
- Uses the conventional commit message from the meaningful commit
- Preserves the **original author** of the meaningful commit (not the squash target)
- Combines all changes from the squashed range

### Step 7: Verify

Run all verification checks. Every check must pass before proceeding to push.

```bash
# 1. Review the rewritten log
git log --oneline --no-merges

# 2. Validate ALL messages match conventional commits
FAILURES=$(git log --format="%s" --no-merges | grep -cvE "^(feat|fix|docs|chore|refactor|test|ci)(\(.+\))?!?: .+")
if [[ "$FAILURES" -gt 0 ]]; then
  echo "FAIL: $FAILURES non-conforming commits found:"
  git log --format="%h %s" --no-merges | grep -vE "^[a-f0-9]+ (feat|fix|docs|chore|refactor|test|ci)(\(.+\))?!?: .+"
  exit 1
fi
echo "PASS: all commits conform"

# 3. Verify ZERO content changes (critical — this proves only messages changed)
DIFF=$(git diff "backup/pre-rewrite-"*..HEAD --stat)
if [[ -n "$DIFF" ]]; then
  echo "FAIL: content differences detected — rewrite changed code, not just messages"
  echo "$DIFF"
  exit 1
fi
echo "PASS: file tree identical"

# 4. Verify author preservation
echo "=== Authors before ==="
git -C . log backup/pre-rewrite-* --format="%an <%ae>" --no-merges | sort -u
echo "=== Authors after ==="
git log --format="%an <%ae>" --no-merges | sort -u
# These two lists must be identical
```

**If any check fails, do NOT push.** Reset to backup and investigate:
```bash
git reset --hard backup/pre-rewrite-*
```

### Step 8: Push (with Confirmation)

**This is destructive for remote collaborators.** Confirm with the user:

```
⚠ FORCE PUSH WARNING
  Branch: main
  Remote: origin
  Action: git push --force-with-lease origin main

  After this push, all collaborators must run:
    git fetch origin
    git reset --hard origin/main

  Type "yes" to proceed:
```

```bash
git push --force-with-lease origin main
```

Use `--force-with-lease` (not `--force`) to prevent overwriting concurrent remote changes. If `--force-with-lease` is rejected, someone pushed to the branch since the rewrite — investigate before retrying.

## Post-Rewrite Cleanup

After successful push and collaborator notification:

```bash
# Verify remote matches local
git log --oneline -5
git log --oneline -5 origin/main
# These should be identical

# Keep backup branch for at least 2 weeks, then delete
# git branch -D backup/pre-rewrite-*
# git push origin --delete backup/pre-rewrite-*
```

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "The old history doesn't matter" | Release-please parses commit messages to determine versions. Non-conforming history produces wrong or no releases. `git bisect`, `git blame`, and `git log --grep` all depend on meaningful messages. |
| "I'll just start fresh from this commit" | You lose blame, authorship, and context. An `--orphan` branch destroys the development narrative. Rewriting preserves everything except bad messages. |
| "It's too risky to rewrite" | The backup branch makes this fully reversible. Verify the diff shows zero content changes. If anything goes wrong: `git reset --hard backup/pre-rewrite-*`. |
| "I'll rewrite later when it matters" | History rewrites get harder over time as more people clone and branch from it. Do it now, before more downstream dependencies exist. |
| "Force pushing is dangerous" | `--force-with-lease` protects against overwriting others' work. Combined with the backup branch, this is safe. |
| "The messages are close enough" | "Close enough" means release-please won't parse them. Conventional commits are a strict format — either a message conforms or it doesn't. |
| "I can just manually tag releases" | Manual tags drift, get forgotten, and lack changelog integration. The whole point is automation — but automation needs parseable input. |

## Red Flags

- Skipping the backup branch creation
- Using `--force` instead of `--force-with-lease`
- Rewriting a branch that others are actively working on without notification
- Content differences showing up in the Step 7 diff (means the rewrite changed code, not just messages)
- Author counts changing after rewrite (means authorship was not preserved)
- Proceeding without user approval of the rewrite plan
- Rewritten messages that are still meaningless (e.g., `"chore: stuff"`)
- Squashing commits across different authors without discussion
- Not keeping the backup branch for at least 2 weeks after the rewrite
