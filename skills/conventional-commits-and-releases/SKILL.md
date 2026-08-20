---
name: conventional-commits-and-releases
description: Use when committing, writing a commit message, opening a PR that will be squash-merged, or configuring automated versioning/changelogs. Keywords — conventional commits, release-please, semver, feat/fix/chore, breaking change, changelog.
---

# Conventional Commits and Releases

## Overview

Commit messages are a **machine-read interface**, not just prose. Automated versioning and changelog generation parse them; a malformed message produces a wrong public version or a broken release. Discipline in the small (one well-formed message) yields correctness in the large (accurate changelog, correct version bump) for free.

## The Format

`<type>(<scope>): <description>`

| Type | Effect / use |
|---|---|
| `feat` | New feature — **minor** bump |
| `fix` | Bug fix — **patch** bump |
| `docs` | Documentation only |
| `chore` | Maintenance, deps, config |
| `refactor` | Behavior-preserving code change |
| `test` | Tests only |
| `ci` / `build` | Pipeline / build-system changes |

- **Imperative mood:** "add X", not "added X" or "adds X".
- **Breaking changes:** `feat!:` or a `BREAKING CHANGE:` footer — triggers a **major** bump.
- **Scope** optional but encouraged: `feat(auth):`, `fix(db):`.

## Load-Bearing Details

- **The type↔version link means a mistyped `feat` vs `fix` ships a wrong version.** Pick the type deliberately: "add" = new feature, "update" = enhancement to existing, "fix" = bug.
- **Squash-merge: the PR title becomes the commit that ships.** It must itself be a valid Conventional Commit, or the release is wrong.
- **Human-authored voice.** No AI/assistant attribution, no `Co-authored-by` trailers, no generated-by footers. Commits read as a human wrote them.

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "The message doesn't really matter" | It drives the changelog and the version number. It matters mechanically. |
| "`chore` is close enough for this feature" | `chore` won't bump the version; users won't get your feature in a release. Use the right type. |
| "I'll fix the PR title later" | On squash-merge the title is final at merge. Fix it before. |
| "A Co-authored-by trailer is harmless" | Project rule forbids AI attribution. No exceptions. |

## Red Flags — STOP

- A commit message with no type prefix
- Using `chore`/`docs` for something that adds or fixes user-facing behavior
- A squash PR title that isn't a valid conventional commit
- Any AI attribution or `Co-authored-by` line

**Enforcement:** commitlint in CI (blocking) on messages and squash PR titles.

Full rationale: `docs/engineering-constitution.md` Article III.
