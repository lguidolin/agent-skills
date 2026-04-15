---
name: commit-history-rewrite
description: Use when an existing repository has messy commit history that needs to conform to conventional commits before adopting release-please, or when intermediate WIP/fixup/merge commits need to be cleaned up.
---

# Commit History Rewrite

Rewrite an existing repository's commit history to conform to conventional commits. Analyzes commits, classifies them by type, identifies squash candidates, and executes the rewrite with full safety gates.

## When to Use

- Adopting conventional commits in a repo with existing non-conforming history
- Commit log is polluted with WIP, fixup, merge, or meaningless messages
- Preparing a repo for release-please (which needs conventional commits to function)
- Cleaning up before open-sourcing or transferring a repository

## When NOT to Use

- Repo has already been published with conventional commits (nothing to rewrite)
- Shared branches with active collaborators who haven't been notified
- You only need to fix the *last few* commits (use `git rebase -i HEAD~N` directly)

## Process

### Step 1: Assess the Repository

```bash
# Count total commits
git rev-list --count HEAD

# Show commit message summary
git log --oneline --no-merges

# Check for collaborators (authorship diversity)
git shortlog -sne --no-merges
```

**Decision point:** If commit count < 50, use interactive rebase. If >= 50, use git-filter-repo.

### Step 2: Classify Existing Commits

Analyze each commit message and changed files to assign a conventional commit type:

| Signal | Assigned Type |
|--------|--------------|
| Message contains "add", "new", "implement", "create", "introduce" | `feat` |
| Message contains "fix", "bug", "patch", "resolve", "correct" | `fix` |
| Only `.md` files or `docs/` changed | `docs` |
| Only test files changed | `test` |
| Only CI/workflow files changed | `ci` |
| Message contains "refactor", "restructure", "reorganize", "simplify" | `refactor` |
| Message contains "update dep", "bump", "upgrade" | `chore` |
| Message is "WIP", "wip", "temp", "save", "checkpoint", single word | **squash candidate** |
| Merge commits | **squash candidate** |
| Message is "fixup", "fix typo", "oops", "lint" | **squash into previous** |

For ambiguous commits, check the diff (`git show --stat <hash>`) to determine type from changed files.

### Step 3: Present the Rewrite Plan

Before any destructive action, show the user a complete plan:

```
REWRITE PLAN
============
Total commits: 47
Commits to rewrite: 32
Commits to squash: 8
Authors preserved: 3

PROPOSED CHANGES:
  abc1234  "initial setup"           →  "chore: initial project setup"
  def5678  "added login"             →  "feat: add user login"
  ghi9012  "wip"                     →  [SQUASH into previous]
  jkl3456  "fix bug"                 →  "fix: resolve login redirect loop"
  mno7890  "Update README.md"        →  "docs: update README with setup instructions"
  ...

SAFETY:
  ✓ Backup branch: backup/pre-rewrite-<timestamp>
  ⚠ Force push required after rewrite
  ⚠ All collaborators must re-clone or reset after push
```

**Wait for explicit user approval before proceeding.**

### Step 4: Create Backup

```bash
# Create a backup branch at current HEAD
git branch "backup/pre-rewrite-$(date +%Y%m%d-%H%M%S)"

# Verify backup exists
git branch -l 'backup/*'
```

### Step 5: Execute the Rewrite

#### Option A: Interactive Rebase (< 50 commits)

```bash
# Rebase from root
git rebase -i --root
```

In the editor:
- Mark squash candidates with `squash` or `fixup`
- Mark message rewrites with `reword`
- Preserve commit order and authorship

**Authorship preservation:** Interactive rebase preserves author name, email, and date by default. Do NOT use `--reset-author`.

#### Option B: git-filter-repo (>= 50 commits)

Create a message rewrite map file (`commit-map.txt`):

```
<old-hash>=<new-message>
```

Then apply:

```bash
git filter-repo --message-callback '
import re
# Apply rewrite map loaded from commit-map.txt
msg = message.decode("utf-8")
# ... classification logic here
return message
' --force
```

**Authorship preservation:** git-filter-repo preserves authorship by default. Do NOT use `--mailmap` or author-rewriting flags unless the user explicitly requests it.

#### Squashing Commits

For squash candidates, combine into the nearest meaningful commit. The resulting commit:
- Uses the conventional commit message from the meaningful commit
- Preserves the **original author** of the meaningful commit
- Combines all changes from the squashed range

### Step 6: Verify

```bash
# Review the rewritten log
git log --oneline --no-merges

# Validate all messages match conventional commits
git log --format="%s" --no-merges | grep -vE "^(feat|fix|docs|chore|refactor|test|ci)(\(.+\))?!?: .+" && echo "FAIL: non-conforming commits found" || echo "PASS: all commits conform"

# Compare file tree to ensure no content was lost
git diff backup/pre-rewrite-<timestamp>..HEAD --stat
# Should show NO differences (only messages changed, not content)

# Verify author preservation
git shortlog -sne --no-merges
# Should match the output from Step 1
```

### Step 7: Push (with Confirmation)

**This is destructive for remote collaborators.** Confirm with the user:

```
⚠ FORCE PUSH WARNING
  Branch: main
  Remote: origin
  Action: git push --force-with-lease origin main

  All collaborators must run:
    git fetch origin
    git reset --hard origin/main

  Type "yes" to proceed:
```

```bash
git push --force-with-lease origin main
```

Use `--force-with-lease` (not `--force`) to prevent overwriting concurrent remote changes.

## Rationalizations

| Excuse | Rebuttal |
|--------|----------|
| "The old history doesn't matter" | Release-please parses commit messages to determine versions. Non-conforming history produces wrong or no releases. |
| "I'll just start fresh from this commit" | You lose blame, authorship, and context. Rewriting preserves everything except bad messages. |
| "It's too risky to rewrite" | The backup branch makes this fully reversible. Verify the diff shows zero content changes. |
| "I'll rewrite later when it matters" | History rewrites get harder over time as more people clone and branch from it. Do it now. |
| "Force pushing is dangerous" | `--force-with-lease` protects against overwriting others' work. Combined with the backup branch, this is safe. |

## Red Flags

- Skipping the backup branch creation
- Using `--force` instead of `--force-with-lease`
- Rewriting a branch that others are actively working on without notification
- Content differences showing up in the Step 6 diff (means the rewrite changed code, not just messages)
- Author counts changing after rewrite (means authorship was not preserved)
- Proceeding without user approval of the rewrite plan
