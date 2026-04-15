# Agent Skills — Development Guide

## Branch Workflow

We use trunk-based development with short-lived feature branches:

- **Feature branches** merge back to `main` within 1-3 days
- **Branch naming:** `feature/<desc>`, `fix/<desc>`, `chore/<desc>`
- All changes reach `main` through pull requests with squash merge

## Commit Discipline

Commit freely within your branch — any message format is fine during development. Only the **PR title** matters: it becomes the squash-merge commit message on `main` and appears in the changelog.

## PR Title Format

PR titles must follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type: lowercase description
type(scope): lowercase description
```

| Type | Purpose | Version Bump |
|------|---------|-------------|
| `feat` | New feature | Minor (0.x → 0.x+1) |
| `fix` | Bug fix | Patch (0.x.y → 0.x.y+1) |
| `docs` | Documentation only | None |
| `chore` | Maintenance, deps | None |
| `refactor` | Code restructuring | None |
| `test` | Test changes | None |
| `ci` | CI/CD changes | None |

**Breaking changes:** Use `feat!:` or `fix!:` prefix, or add `BREAKING CHANGE:` in the PR body. Pre-1.0, breaking changes bump minor. Post-1.0, they bump major.

## Change Sizing

- **Target:** ~100 lines per PR
- **Acceptable:** ~300 lines for a single logical change
- **Must split:** 1000+ lines
- **Separate** refactoring from feature work — they are different changes

## PR Descriptions

- First line: short, imperative, standalone
- Body: what is changing and **why**
- Anti-patterns: "Fix bug", "Update file", "Phase 1"

The PR template will guide you through the required sections.

## Automated Checks

| Check | Status | Effect |
|-------|--------|--------|
| PR title validation | Required | Blocks merge if title doesn't follow conventional commits |
| Auto-labeling | Informational | Adds labels based on PR title type |
| CI checks (YAML lint) | Non-blocking | Informational only (will be graduated to required) |

## Release Process

Releases are fully automated via [release-please](https://github.com/googleapis/release-please):

1. Merge PRs to `main` with conventional commit titles
2. release-please automatically creates/updates a Release PR
3. The Release PR accumulates changes and updates the changelog
4. Merge the Release PR → GitHub Release is created with tags

**Version progression (pre-1.0):**
- `feat` → minor bump (0.1.0 → 0.2.0)
- `fix` → patch bump (0.1.0 → 0.1.1)

**Version progression (post-1.0):**
- `feat` → minor bump (1.0.0 → 1.1.0)
- `fix` → patch bump (1.0.0 → 1.0.1)
- `BREAKING CHANGE` → major bump (1.0.0 → 2.0.0)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| PR title validation fails | Edit the PR title to follow `type: description` format |
| CI check failures | Check the workflow logs, fix the issue, push again |
| Merge blocked | Ensure all required status checks pass |
| Release PR not created | Verify `main` branch has new conventional commits since last release |
