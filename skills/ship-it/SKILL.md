---
name: ship-it
description: Use when the user wants to ship work — push, PR, archive decision records, merge, and clean up. Handles the full lifecycle from committing final changes through post-merge cleanup including converting specs/plans to compact decision records.
---

# Ship It

Handle the complete shipping lifecycle: stage, commit, push, open a PR, archive decision records post-merge, and clean up.

## Overview

**Every change goes through a branch and PR.** Never push directly to main. This skill handles the full wrap-up cycle including post-merge documentation archival.

**Commit messages are documentation.** The PR title becomes the squash-merge commit on main and appears in the changelog. Get it right at PR creation time.

**Archive after merge, never before.** Specs and plans remain accessible until the PR is merged. Only after merge do we convert them to compact decision records.

## When to Use

- User says "push", "ship it", "let's ship", "open a PR", "create a PR"
- User says "merged", "it's merged", "pull and cleanup" after a PR was opened
- User has completed implementation and wants to wrap up
- After completing a plan where the next step is to submit the work

## When NOT to Use

- User explicitly wants to push directly to main (confirm this is intentional first)
- Repo has no remote configured
- Changes are work-in-progress the user isn't ready to push yet
- User just wants to commit without shipping (use git-workflow-and-versioning)

## Process

### Phase 1: Stage & Commit

```bash
git status --short
git branch --show-current
git log --oneline @{upstream}..HEAD 2>/dev/null || echo "No upstream set"
```

**Decision tree:**
- On main with uncommitted changes → create branch, commit, push, PR
- On feature branch with uncommitted changes → commit, push, PR (or update existing PR)
- On feature branch with unpushed commits → push, PR (or update existing PR)
- On feature branch with existing PR → push (PR already exists)

**If there are unstaged changes:**
- Ask the user if all changes should be included or specific files
- If changes span multiple concerns, suggest splitting

**Craft the commit message:**

| Type | When |
|------|------|
| `feat` | New functionality |
| `fix` | Bug fixes |
| `docs` | Documentation only |
| `chore` | Config, dependencies, tooling |
| `refactor` | Code restructuring, no behavior change |
| `test` | Adding or modifying tests |
| `ci` | CI/CD workflow changes |

Format: `<type>[optional scope]: <imperative description>`

Rules:
- Imperative mood ("add", not "added" or "adds")
- Lowercase first word after colon
- No period at the end
- Short (50 chars or less for the subject)
- Describe *what* the commit does, not *how*

Present proposed commit message to user and confirm before committing.

### Phase 2: Branch & Push

If on main, create a branch:
```
<type>/<short-description>
```

Examples:
- `feat/oauth-login`
- `fix/null-response-handling`
- `docs/copilot-setup-permissions`

Push:
```bash
git push -u origin $(git branch --show-current)
```

### Phase 3: Open PR

PR title = conventional commit message (used for squash-merge on main).

PR body structure:
```markdown
## What changed

[Specific description of additions/modifications/removals]

## Why

[Motivation — what problem does this solve?]
```

Create using gh CLI:
```bash
gh pr create --title "<conventional commit message>" --body "<PR body>"
```

If `gh` is not available, provide the PR URL from git push output or construct it.

### Phase 4: Wait for Merge

After PR is created, ask: "Let me know when it's merged and I'll handle cleanup and archival."

Wait for user confirmation (e.g., "merged", "done", "it's merged").

### Phase 5: Post-Merge — Archive Decision Records

**Only after the PR is merged**, check for unconverted specs/plans:

```bash
ls docs/superpowers/specs/ 2>/dev/null
ls docs/superpowers/decisions/ 2>/dev/null
```

**If unconverted specs/plans exist:**

1. Ask the user: "I found specs/plans that may correspond to this work. Want me to convert them to compact decision records and archive the originals?"

2. If yes, for each spec:
   - Read the spec content
   - Generate a decision record with YAML frontmatter:
     ```yaml
     ---
     title: <extracted from spec>
     date: <from spec filename>
     component: <inferred from content>
     status: implemented
     supersedes: null
     dependencies: [<inferred>]
     ---
     ```
   - Write ~30-50 lines capturing: key decisions, interfaces, constraints
   - Save to `docs/superpowers/decisions/<date>-<topic>.md`
   - Move original spec to `docs/superpowers/archive/specs/`
   - Move matching plan to `docs/superpowers/archive/plans/`

3. Rebuild the master index:
   - Regenerate `docs/superpowers/index.md` from all decision record frontmatter
   - Or run: `just claude-rebuild-index`

4. Commit the archival:
   ```bash
   git add docs/superpowers/
   git commit -m "docs: archive specs and update decision index"
   git push
   ```

### Phase 6: Cleanup

```bash
git checkout main
git pull
git branch -d <branch-name>
git push origin --delete <branch-name> 2>/dev/null || true
git fetch --prune
```

Verify clean state:
```bash
git branch --show-current
git log --oneline -3
```

## Key Principles

- **Never push to main directly** — always branch + PR
- **Conventional commits** — the PR title is the changelog entry
- **Archive after merge only** — specs stay accessible during review
- **Decision records are compact** — ~30-50 lines, YAML-indexed, LLM-optimized
- **Clean up completely** — no stale branches or tracking refs
