---
name: tests-as-a-control
description: Use when writing or modifying tests, when a test breaks during a refactor, or when testing permission/role rules. Symptoms — tempted to edit a test to make it pass, testing only the happy path, a deny-test that started passing, flaky tests, or unsure what to assert.
---

# Tests as a Control

## Overview

A test is a **control specimen**: it holds an expectation fixed so any change in behavior becomes *visible*. The discipline is *don't fix the test to match the code; understand why they disagree.*

## The Rules

- **Test-first for behavioral change.** Write the failing test, watch it fail
  *for the right reason*, then write the minimal code that passes. If you did
  not watch it fail, you do not know it tests what you think. The loop itself is
  `superpowers:test-driven-development`; this skill governs what the test must
  contain and what a failure means once it exists. The rule holds whether or not
  that skill is installed.

- **Structural change is verified by the unchanged suite.** A pure structural
  change — rename, move, split, extract, with no observable behavior change —
  requires **no new test**. Its gate is the opposite: *the entire existing suite
  passes with no test edited.* This is why test-first does not apply here —
  there is no behavior to specify, so no test can meaningfully fail first.
  If a structural change forces a test edit, it was not structural. Stop and
  reclassify using the next rule.

- **A rename that crosses a contract boundary is not a refactor.** The question
  is not "did the code change behavior?" but "is this name observable to
  something I do not control?"

  | Renamed thing | Classification | Gate |
  |---|---|---|
  | Internal symbol, private helper, local file | Structural | Existing suite passes unedited |
  | Exported function, API/GraphQL field, route, CLI flag, DB column, event name, config key | **Behavioral** — it breaks consumers | Test-first + add-and-deprecate |

  A public rename does the same thing to the same data and is *still* a breaking
  change, because the name was the contract (Hyrum's Law — see
  `performance-and-scale`). Treat it as behavioral: add the new name with a
  failing-test-first cycle, keep the old name and its passing test alive through
  the deprecation window, remove the old only once consumers have migrated.

  The third case is a test that references a name as a *string* — snapshots, DI
  container keys, reflection, fixture paths. These break on an internal rename.
  That is not the rule failing; it is the signal that the test was coupled to
  implementation detail. Fix the coupling, don't re-baseline.

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
| "I'll write the code first, then add tests" | Then the test was fitted to the code, not the requirement. You never watched it fail, so you don't know it tests anything. |
| "It's just a rename, no test needed" | Correct — *if* the name is internal. If it's exported/public, the name was the contract and the rename is behavioral. |
| "I renamed it and had to fix three tests, that's normal" | It isn't. Either you crossed a contract boundary, or those tests were coupled to implementation detail. Reclassify. |
| "The test is wrong now, I'll just update it" | Only if a *requirement* changed. If you're refactoring, the test caught a real change — investigate. |
| "I tested the happy path, that's enough" | A rule isn't tested until the deny case is too. |
| "This deny-test passes now, great, ship it" | A forbidden action succeeding is a security regression, not progress. |
| "The test is flaky, just re-run CI" | Flakiness masks real bugs and trains everyone to ignore failures. Quarantine and fix. |
| "Let me DRY up these tests with a shared helper" | Tests are DAMP. Duplication that aids in-place clarity stays. |

## Red Flags — STOP

- Writing production code for a behavior change before a failing test exists
- A structural change whose diff also touches test files
- Renaming a public/exported name in place instead of add-and-deprecate
- Editing a test during a refactor to make it green
- A new permission with no deny-case test
- Re-baselining a snapshot/assertion without understanding why it changed
- A test with a real `sleep`, `Date.now()`, random data, or network call
- Refactoring test code to remove duplication at the cost of readability

Full rationale: Article IV of the constitution, bundled at `engineering-constitution/references/engineering-constitution.md`. For the GraphQL/route contract specifics see `graphql-contract-testing`.
