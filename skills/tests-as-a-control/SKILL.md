---
name: tests-as-a-control
description: Use when writing or modifying tests, when a test breaks during a refactor, or when testing permission/role rules. Symptoms — tempted to edit a test to make it pass, testing only the happy path, a deny-test that started passing, flaky tests, or unsure what to assert.
---

# Tests as a Control

## Overview

A test is a **control specimen**: it holds an expectation fixed so any change in behavior becomes *visible*. The discipline is *don't fix the test to match the code; understand why they disagree.*

## The Rules

- **Refactors must not edit tests; requirement changes must.** Different acts:
  - A *refactor* breaks a test → the test caught an unintended behavior change. **Stop and understand it.** Editing the test to make a refactor pass destroys your instrumentation.
  - A *requirement* genuinely changed → update the test **deliberately, as its own reviewable change**, recorded as such.
  - The forbidden move is silent re-baselining.
- **Symmetric coverage — every rule tested both directions.** Prove the authorized actor **can** *and* the unauthorized actor **cannot**. Happy-path-only tests half a rule.
- **Permission/role rules are a matrix:** every meaningful (role × action × resource) cell, **allow and deny**. A new role is incomplete until its **deny** cases exist. A deny-test that suddenly passes-through is a **security regression** — review and accept explicitly, never re-baseline.
- **Entry points are never added/removed silently.** Routes, commands, endpoints each get existence-and-smoke coverage so add/remove forces a test change.
- **Test by size:** **small** (pure logic, no I/O, constant), **medium** (real DB/process, hermetic), **large** (full stack). Many small, fewer medium, fewest large. Watch the **missing middle** — server/app logic neither unit nor integration covers because each layer assumes the other tests it.
- **Flaky tests are quarantined on sight.** A test that passes/fails without a code change destroys trust in the whole suite. Quarantine immediately (out of the blocking gate, file a fix) — never leave intermittently failing, never delete silently. Small tests must be deterministic: no real clock, randomness, or network.
- **Test code is DAMP, not DRY.** *Descriptive And Meaningful Phrases* over de-duplication. A test must be obvious read in isolation. Applying DRY to tests is a violation, not a virtue (see `change-hygiene-and-code-craft`).

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "The test is wrong now, I'll just update it" | Only if a *requirement* changed. If you're refactoring, the test caught a real change — investigate. |
| "I tested the happy path, that's enough" | A rule isn't tested until the deny case is too. |
| "This deny-test passes now, great, ship it" | A forbidden action succeeding is a security regression, not progress. |
| "The test is flaky, just re-run CI" | Flakiness masks real bugs and trains everyone to ignore failures. Quarantine and fix. |
| "Let me DRY up these tests with a shared helper" | Tests are DAMP. Duplication that aids in-place clarity stays. |

## Red Flags — STOP

- Editing a test during a refactor to make it green
- A new permission with no deny-case test
- Re-baselining a snapshot/assertion without understanding why it changed
- A test with a real `sleep`, `Date.now()`, random data, or network call
- Refactoring test code to remove duplication at the cost of readability

Full rationale: `docs/engineering-constitution.md` Article IV. For the GraphQL/route contract specifics see `graphql-contract-testing`.
