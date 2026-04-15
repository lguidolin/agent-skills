---
name: repo-automation-setup
description: Use when setting up a new repository with conventional commits, release-please, and CI automation, or when retrofitting an existing repository that lacks automated versioning and PR validation workflows.
---

# Repository Automation Setup

Scaffold the complete conventional-commits + release-please + CI automation stack in any repository. Works on empty repos and repos with existing content.

## When to Use

- Starting a new repository and need release automation from day one
- Existing repo has no automated versioning or changelog generation
- Migrating from manual release processes or other release tools
- Repository needs PR title validation and auto-labeling

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

### Step 2: Detect Existing Files

Before creating anything, check for conflicts:

```bash
for f in .github/workflows/pull-request.yml .github/workflows/main-branch.yml \
         .github/release-please-config.json .release-please-manifest.json \
         .github/dependabot.yml .github/pull_request_template.md docs/DEVELOPMENT.md; do
  [[ -f "$f" ]] && echo "EXISTS: $f"
done
```

If files exist, show a diff of what would change and ask before overwriting.

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

#### 3f. `.github/pull_request_template.md`

```markdown
## What changed

[Describe the changes in detail - this goes into the changelog]

## Checklist

- [ ] PR title follows conventional commits format
- [ ] Description explains what and why
```

#### 3g. `docs/DEVELOPMENT.md`

Generate a development guide covering:
- Branch workflow (create branch → commit freely → PR with conventional title → squash merge)
- PR title format table (feat, fix, docs, chore, refactor, test, ci)
- Automated checks explained (PR title validation, auto-labeling, CI)
- Release process (release-please creates release PR → merge → GitHub release + tags)
- Version progression rules (pre-1.0 vs post-1.0 bumping)
- Troubleshooting section

Use `{{PROJECT_NAME}}` in headings and references.

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

## Rationalizations

| Excuse | Rebuttal |
|--------|----------|
| "We'll add automation later" | Automation is cheaper to add on day one than to retrofit. Set it up now. |
| "We don't need changelogs yet" | Changelogs are generated free from conventional commits. No reason to skip. |
| "CI checks slow us down" | Non-blocking CI checks don't slow anything — they only inform. Graduate to required after validation. |
| "Squash merge loses history" | Branch history is preserved in the PR. Main gets a clean, meaningful log. |
| "We can just tag manually" | Manual tags drift, get forgotten, and lack changelog integration. Automate it. |
| "Monorepo is overkill" | If you picked single-package, the config is minimal. The question was asked, not assumed. |

## Red Flags

- Skipping the conflict detection step on an existing repo
- Using `release-type: simple` when the repo has a `package.json` (use `node` instead)
- Forgetting to set branch protection after the workflows are in place
- Making CI checks required before they've been validated through a few PRs
