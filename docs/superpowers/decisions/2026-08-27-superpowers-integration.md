---
title: Align house skills with superpowers workflows
date: 2026-08-27
component: skills
status: implemented
supersedes: null
dependencies: []
---

## Architecture

The two skill sets divide as **policy vs. mechanism**. obra's superpowers plugin
supplies the workflow engine (how to run a stage); the house skills supply the
constitution it runs under (when a stage is mandatory, what its output must
satisfy). They already shared an artifact path — superpowers writes specs to
`docs/superpowers/specs/` and plans to `docs/superpowers/plans/`, which
`recording-decisions` and `ship-it` consume — so this work connected the seams
that path convention implied but never enforced.

- `skills/ship-it/SKILL.md` — Phase 0 (verify + delegate), Phase 6 (worktree teardown)
- `skills/tests-as-a-control/SKILL.md` — test-first, structural gate, contract-boundary rule
- `skills/engineering-constitution/references/engineering-constitution.md` — bundled charter
- `.github/workflows/pull-request.yml` — `No AI Attribution` job

## Decisions

- **`ship-it` delegates to superpowers rather than absorbing it.** Absorbing
  obra's environment-detection and worktree-cleanup bash would have made
  `ship-it` self-contained, but it is vendoring plugin code — the exact practice
  this repo was refactored to eliminate (see "plugins are the source of truth").
  Delegation keeps the policy/mechanism split intact.
- **The test-green gate is *not* delegated.** "A red suite never becomes a PR" is
  policy, not mechanism, so `ship-it` owns it directly. It is also two lines.
- **The integration menu is pre-decided.** `finishing-a-development-branch`
  offers "merge back to base locally" as option 1 and instructs the agent to
  present the menu verbatim. That option bypasses both the PR preview deployment
  and the CI gate, so it is declared unavailable. "Keep the branch as-is"
  remains valid — deferring is not bypassing.
- **Availability is checked against the agent's own skill list, not the
  filesystem.** A probe of `~/.claude/plugins/cache/` returns paths for plugins
  that are installed but *disabled*, and misses skills supplied by other
  mechanisms. This was found empirically: the first implementation returned a
  path from a marketplace copy that had been disabled the previous day.
- **A rename that crosses a contract boundary is not a refactor.** The question
  is not "did behavior change?" but "is this name observable to something I do
  not control?" Internal symbols are structural (gate: existing suite passes
  unedited). Exported functions, API/GraphQL fields, routes, CLI flags, DB
  columns, event names, and config keys are behavioral — the name *was* the
  contract (Article XI, Hyrum's Law) — and follow add-and-deprecate under
  test-first. This resolves the apparent contradiction between obra's Iron Law
  ("no production code without a failing test") and Article V's
  structural-before-behavioral rule: two different acts, two different gates.
- **The AI-attribution gate matches trailer and footer forms only.** This repo's
  commit subjects legitimately mention Claude and Anthropic, so a bare
  keyword match would block ordinary work. Human `Co-authored-by` trailers are
  explicitly permitted — only AI attribution is rejected.
- **The constitution is bundled into its skill.** Sixteen skills cited
  `docs/engineering-constitution.md` as a relative path; installed globally, that
  resolved against whatever project was open, so the citation was dead in every
  use outside this repo. Same fix already applied to `recording-decisions`.

## Interfaces

- `ship-it` Phase 0 expects `superpowers:finishing-a-development-branch` by name,
  and defines a fallback (run tests directly, treat upstream/`main` as base,
  skip worktree cleanup) when it is absent.
- `install.sh --global` now prunes symlinks pointing into the pool at skills that
  no longer exist. Links to other targets are left alone.
- The `No AI Attribution` job reads `github.event.pull_request.body` and the
  `base..head` commit range.

## Constraints

- Never vendor a skill an installed plugin already ships.
- Delegation references obra's skill by *behavior*, never by step number — his
  step numbering is free to change.
- Every merge goes through a PR: the PR is the preview deployment and the CI gate.

## Gotchas

- Bash single quotes do not expand `\xNN` escapes. An emoji written that way
  inside a workflow's `run:` block silently never matches.
- `gh api .../branches/main/protection` returns 404 when protection is expressed
  as a **ruleset** instead. The ruleset here was active with an empty rule list,
  so no check gated anything despite CI appearing green-and-blocking.
- Squash-merge discards branch commit bodies, so linting them adds little; the
  PR *title* is the commit that ships. The PR *body* becomes the commit body and
  does need scanning.

## Rejected Alternatives

- **Absorb obra's git plumbing into `ship-it`.** Rejected: vendoring plugin code
  contradicts the repo's source-of-truth principle and creates silent drift when
  upstream changes. Accepted cost: a delegation can break if obra restructures,
  mitigated by referencing behavior rather than step numbers.
- **Fork `finishing-a-development-branch` with the menu removed.** Rejected: a
  fork must be maintained forever to track upstream, to change three lines.
- **Assert precedence only in CLAUDE.md.** Rejected as the *sole* mechanism —
  correct (superpowers defers to CLAUDE.md by its own documented priority) but
  invisible to anyone reading `ship-it`. The rule now lives in the skill, where
  it is read at the moment it applies.
- **Add test-first as a ninth inviolable principle.** Rejected: eight is a clean
  charter and renumbering ripples through sixteen skill footers. Amended
  Principle 3 and Article IV instead.
- **Block all `Co-authored-by` trailers.** Rejected: it would reject legitimate
  human co-authors, which the user explicitly wanted preserved.
- **Rename only the description, not the skill**, to fix the `verification-*`
  collision. Rejected: the names still sit adjacent in every skill listing, so it
  solves half the problem.
