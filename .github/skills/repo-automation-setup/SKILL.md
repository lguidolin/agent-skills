---
name: repo-automation-setup
description: Use when setting up a new repository with conventional commits, release-please, and CI automation, or when retrofitting an existing repository that lacks automated versioning and PR validation workflows.
---

# Repository Automation Setup

Scaffold the complete conventional-commits + release-please + CI automation stack in any repository. Works on empty repos and repos with existing content.

## Overview

**Shift Left:** Catch problems as early as possible. A bad commit message caught at PR time costs seconds; the same message polluting release notes costs credibility. Move validation upstream — enforce commit format at PR title, validate configs in CI, catch issues before they reach main.

**Faster is Safer:** Smaller batches and more frequent releases reduce risk. A release with 3 changes is easier to debug than one with 30. Automated releases build confidence in the release process itself.

This skill sets up the enforcement mechanism: PR title validation ensures every merge to main produces a meaningful, parseable commit. Release-please turns those commits into automated releases with changelogs. CI catches config and code issues before merge.

## When to Use

- Starting a new repository and need release automation from day one
- Existing repo has no automated versioning or changelog generation
- Migrating from manual release processes or other release tools
- Repository needs PR title validation and auto-labeling

## When NOT to Use

- Repo already has release-please or equivalent configured (check first)
- Monorepo with incompatible release tooling (e.g., Lerna with independent versioning already working)
- Repo is a fork where upstream controls the release process

## Process

### Step 1: Gather Configuration

Ask the user for these values before generating any files:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `PROJECT_NAME` | (required) | Human-readable project name for docs |
| `INITIAL_VERSION` | `0.1.0` | Starting semantic version |
| `RELEASE_TYPE` | `simple` | `simple` (single-package) or `node` / `python` / etc. |
| `REPO_LAYOUT` | `single` | `single` (one package at root) or `monorepo` (multiple packages) |
| `PACKAGE_PATHS` | `.` | For monorepo: comma-separated paths like `packages/api,packages/ui` |
| `DEPENDABOT_ECOSYSTEMS` | `github-actions` | Comma-separated: `github-actions`, `npm`, `pip`, `cargo`, etc. |
| `DEFAULT_BRANCH` | `main` | Branch that triggers releases |

**Detect the right `RELEASE_TYPE` automatically:**
- `package.json` exists → suggest `node`
- `setup.py` or `pyproject.toml` exists → suggest `python`
- `Cargo.toml` exists → suggest `rust`
- None of the above → suggest `simple`

### Step 2: Detect Existing Files

Before creating anything, check for conflicts:

```bash
for f in .github/workflows/pull-request.yml .github/workflows/main-branch.yml \
         .github/release-please-config.json .release-please-manifest.json \
         .github/dependabot.yml .github/pull_request_template.md docs/DEVELOPMENT.md; do
  [[ -f "$f" ]] && echo "EXISTS: $f"
done
```

If files exist, show a diff of what would change and ask before overwriting. Don't silently overwrite — existing files may contain project-specific customizations.

### Step 3: Create Configuration Files

Create files in this order (dependencies flow top-down):

#### 3a. `.github/release-please-config.json`

**Single-package:**
```json
{
  "release-type": "{{RELEASE_TYPE}}",
  "bump-minor-pre-major": true,
  "bump-patch-for-minor-pre-major": false,
  "initial-version": "{{INITIAL_VERSION}}",
  "packages": {
    ".": {}
  }
}
```

**Monorepo:** Replace `packages` with one entry per path:
```json
{
  "packages": {
    "packages/api": { "release-type": "node" },
    "packages/ui": { "release-type": "node" }
  }
}
```

Each monorepo package gets its own `release-type` — ask the user per package if they differ.

#### 3b. `.release-please-manifest.json`

**Single-package:**
```json
{
  ".": "{{INITIAL_VERSION}}"
}
```

**Monorepo:** One entry per package path, each with its own version.

#### 3c. `.github/workflows/pull-request.yml`

```yaml
name: Pull Request Validation

on:
  pull_request:
    types: [opened, edited, synchronize, reopened]

permissions:
  pull-requests: write
  contents: read
  statuses: write

jobs:
  validate-pr-title:
    name: Validate PR Title
    runs-on: ubuntu-latest
    steps:
      - uses: amannn/action-semantic-pull-request@v6
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          types: |
            feat
            fix
            docs
            chore
            refactor
            test
            ci
          requireScope: false
          subjectPattern: ^[a-z].+$
          subjectPatternError: |
            The subject "{subject}" found in the pull request title "{title}"
            didn't match the configured pattern. Please ensure that the subject
            starts with a lowercase character (per conventional commits).

  auto-label:
    name: Auto Label PR
    runs-on: ubuntu-latest
    steps:
      - name: Label based on PR title
        uses: actions/github-script@v8
        with:
          script: |
            const title = context.payload.pull_request.title;
            const labelMap = {
              'feat': 'enhancement',
              'fix': 'bug',
              'docs': 'documentation',
              'chore': 'chore',
              'refactor': 'refactor',
              'test': 'test',
              'ci': 'ci'
            };
            for (const [type, label] of Object.entries(labelMap)) {
              if (title.startsWith(`${type}:`) || title.startsWith(`${type}(`)) {
                await github.rest.issues.addLabels({
                  owner: context.repo.owner,
                  repo: context.repo.repo,
                  issue_number: context.payload.pull_request.number,
                  labels: [label]
                });
                break;
              }
            }

  ci-checks:
    name: CI Checks
    runs-on: ubuntu-latest
    continue-on-error: true
    steps:
      - uses: actions/checkout@v6
      - name: Validate YAML syntax
        run: |
          sudo apt-get update && sudo apt-get install -y yamllint
          find . -name "*.yml" -o -name "*.yaml" | while read file; do
            echo "Checking $file"
            yamllint -d "{extends: default, rules: {line-length: disable}}" "$file" || true
          done
```

**CI check graduation path:**
1. Deploy with `continue-on-error: true` (informational, non-blocking)
2. Validate the checks pass on 3-5 real PRs
3. Remove `continue-on-error` and add to branch protection required checks
4. Add project-specific checks (lint, test, build) as the codebase grows

**No gate can be skipped.** If lint fails, fix lint — don't disable the rule. If a test fails, fix the code — don't skip the test. When CI fails, feed the failure output to your agent and fix it before pushing again.

#### 3d. `.github/workflows/main-branch.yml`

```yaml
name: Release Automation

on:
  push:
    branches:
      - {{DEFAULT_BRANCH}}

permissions:
  contents: write
  pull-requests: write

jobs:
  release-please:
    name: Release Please
    runs-on: ubuntu-latest
    outputs:
      release_created: ${{ steps.release.outputs.release_created }}
      tag_name: ${{ steps.release.outputs.tag_name }}
    steps:
      - uses: google-github-actions/release-please-action@v4
        id: release
        with:
          config-file: .github/release-please-config.json
          manifest-file: .release-please-manifest.json

  update-major-tag:
    name: Update Major Version Tag
    needs: release-please
    if: ${{ needs.release-please.outputs.release_created == 'true' }}
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v6
        with:
          ref: ${{ needs.release-please.outputs.tag_name }}
      - name: Update major version tag
        env:
          TAG_NAME: ${{ needs.release-please.outputs.tag_name }}
        run: |
          MAJOR_TAG=$(echo "$TAG_NAME" | sed 's/^\(v[0-9]*\).*/\1/')
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git tag -fa "$MAJOR_TAG" -m "Update $MAJOR_TAG tag to $TAG_NAME"
          git push origin "$MAJOR_TAG" --force
```

#### 3e. `.github/dependabot.yml`

Generate one `updates` entry per ecosystem:

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    labels:
      - "dependencies"
    commit-message:
      prefix: "chore"
      include: "scope"
```

The `commit-message` config ensures Dependabot PRs conform to conventional commits automatically (e.g., `chore(deps): bump actions/checkout from v5 to v6`).

#### 3f. `.github/pull_request_template.md`

```markdown
## What changed

[Describe the changes in detail - this goes into the changelog]

## Why

[Context and motivation for the change]

## Checklist

- [ ] PR title follows conventional commits format (`type: description`)
- [ ] Description explains what and why (not just what)
- [ ] No secrets in code, logs, or version control
- [ ] Tests pass locally
```

The "Why" section is critical — PR descriptions that only say *what* changed are redundant with the diff. The *why* provides context that makes future git-blame useful.

#### 3g. `.gitignore` (if missing)

Check if a `.gitignore` exists. If not, create one appropriate to the project:

```
# Dependencies
node_modules/

# Build output
dist/
build/
.next/

# Environment
.env
.env.local
*.pem

# IDE
.idea/

# OS
.DS_Store
Thumbs.db
```

Adapt to the detected stack. Never commit `node_modules/`, `.env`, or build artifacts.

#### 3h. `docs/DEVELOPMENT.md`

Generate a development guide covering:

- **Branch workflow** — Trunk-based dev: short-lived feature branches (1-3 days), merge back quickly. Branch naming: `feature/<desc>`, `fix/<desc>`, `chore/<desc>`.
- **Commit discipline** — Commit freely within branches (any format). Only the PR title matters — it becomes the squash-merge commit message on main and appears in the changelog.
- **PR title format** — Table of types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`. Breaking changes: `feat!:` or `BREAKING CHANGE:` in body.
- **Change sizing** — Target ~100 lines per PR. ~300 acceptable for single logical changes. ~1000+ must be split. Separate refactoring from feature work — they are different changes.
- **PR descriptions** — First line: short, imperative, standalone. Body: what is changing and *why*. Anti-patterns: "Fix bug", "Update file", "Phase 1".
- **Automated checks** — PR title validation (required, blocks merge), auto-labeling (informational), CI checks (initially non-blocking, graduated to required).
- **Release process** — release-please creates release PR → merge → GitHub release + tags + changelog. Version progression: pre-1.0 (`feat` → minor, `fix` → patch) vs post-1.0 (`feat` → minor, `fix` → patch, `BREAKING CHANGE` → major).
- **Troubleshooting** — Common issues: PR title validation fails (edit title), CI check failures, merge blocked (check required statuses).

Use `{{PROJECT_NAME}}` in headings.

### Step 4: Branch Protection Recommendations

After file creation, present these as manual steps (not auto-applied):

```
Recommended GitHub branch protection settings for {{DEFAULT_BRANCH}}:
  ✓ Require pull request before merging
  ✓ Require status checks: "Validate PR Title"
  ✓ Require branches to be up to date
  ✓ Allow only squash merging
  ✓ Require linear history
```

**Why squash merge:** Branch history (WIP commits, fixups, experiments) is preserved in the PR. Main gets a clean, meaningful, linear log where every commit is a conventional commit. This is what makes release-please and `git log --oneline` useful.

### Step 5: Verify

```bash
# Validate YAML syntax
yamllint .github/workflows/*.yml .github/dependabot.yml

# Validate JSON
python3 -c "import json; json.load(open('.github/release-please-config.json'))"
python3 -c "import json; json.load(open('.release-please-manifest.json'))"

# Check file existence
ls -la .github/workflows/pull-request.yml .github/workflows/main-branch.yml \
       .github/release-please-config.json .release-please-manifest.json \
       .github/dependabot.yml .github/pull_request_template.md docs/DEVELOPMENT.md
```

### Step 6: Bootstrap Strategy (Existing Repos)

For repos with existing content, the file creation must be done carefully:

1. **First commit:** Direct push to main — `chore: add repository automation` with all config files. This bootstraps the system so PRs can be validated going forward.
2. **Or, feature branch:** Create a `chore/repo-automation` branch, add all files, open a PR titled `chore: add repository automation`. This is cleaner but requires the PR validation workflow to already be on main (chicken-and-egg).

**Recommended:** Direct push for the initial commit, then all subsequent changes go through the PR workflow. This avoids the chicken-and-egg problem.

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "We'll add automation later" | Automation is cheaper to add on day one than to retrofit. Every PR merged without validation is a commit you may need to rewrite later. |
| "We don't need changelogs yet" | Changelogs are generated free from conventional commits. They cost nothing and provide value to every consumer. |
| "CI checks slow us down" | Non-blocking CI checks don't slow anything — they only inform. Graduate to required after validation through a few real PRs. |
| "Squash merge loses history" | Branch history is preserved in the PR. Main gets a clean, meaningful log. This is the proven DORA high-performance pattern. |
| "We can just tag manually" | Manual tags drift, get forgotten, and lack changelog integration. Automate it. |
| "Monorepo is overkill" | If you picked single-package, the config is minimal. The question was asked, not assumed. |
| "I'll fix the PR title format later" | The validation check exists precisely because everyone says this. Enforce at submission time. |
| "We don't need a .gitignore" | Until `.env` with production secrets gets committed. Set it up immediately. |

## Red Flags

- Skipping the conflict detection step on an existing repo
- Using `release-type: simple` when the repo has a `package.json` (use `node` instead)
- Forgetting to set branch protection after workflows are in place
- Making CI checks required before they've been validated through a few PRs
- No `.gitignore` in the project
- PR descriptions that only say *what* changed without explaining *why*
- Giant PRs (1000+ lines) that should be split into smaller, focused changes
- Combining formatting/refactoring changes with behavior changes in the same PR
