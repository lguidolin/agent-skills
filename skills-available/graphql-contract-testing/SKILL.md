---
name: graphql-contract-testing
description: Use when writing a GraphQL query/mutation that the UI and a test will share, or building route/schema contract or smoke tests. Symptoms — copying a query into a test, a test asserting on query text, schema change that didn't break the UI build, or RLS/permission drift. Keywords — graphql-codegen, typed document, contract test, route smoke test.
---

# GraphQL Contract Testing

## Overview

Tests that sit *on the seam between layers* and break when either side moves without the other's consent — `tests-as-a-control` applied to boundaries. **The cardinal rule: assert on the contract — the data shape and access semantics the consumer depends on — never on the query string itself.** A test that breaks on a cosmetic query edit is a change-detector anti-pattern; a test that breaks when the *guaranteed shape or permission* moves is a control.

## §1 — The GraphQL Query Contract

- **Every operation is authored once as a typed document in a known location, exported to be imported.** The UI imports it; the test imports the **exact same** artifact — never a re-typed copy. Copying a query into a test silently kills the contract (editing the UI query no longer breaks the test). DRY made load-bearing.
- **It breaks in both directions, by construction:**
  - **DB → UI drift, at compile time.** `graphql-codegen` generates TypeScript types from the **live schema**. Rename or drop a used field and `tsc` fails on every usage *and* the shared document — build breaks before a user sees a blank panel. *This is why codegen-against-live-schema is mandatory.*
  - **UI → DB / permission drift, at runtime.** The shared document runs against a **seeded test DB through the real call path**, under role context, asserting on the **returned shape and access outcome** — not the query text.
- **Contract tests and the RLS role matrix are the same harness.** Run the one document through PostGraphile as role A (expect data) and role B (expect denied/empty). One mechanism proves three things: query still matches schema, UI assumptions still hold, RLS still enforces the boundary.

### Worked example — how a real bug gets caught

- *DB→UI:* a migration removes `equipment.is_active`. Codegen regenerates from the new schema; the generated type loses the field; `tsc` fails on the shared document and every component using it — **caught at build, before merge.** No test asserts "query text == X."
- *UI→DB:* a dev widens the UI query to pull `cancellation_reason` (RLS exposes it only to elevated roles). The runtime test running **as a plain member** asserts the member-visible shape, now gets null/denied, and **fails — forcing "did we mean to expose this?"**

## §2 — Route Contract and Smoke Tests

- **Routes enumerated from a single source.** Each route has a smoke test: **renders without error** + shows a **minimal required element set** (a heading, a landmark, a key control — not detailed interaction).
- **Adding/removing a route forces a matching test change** — a new URL is incomplete without its smoke test; a removed URL removes its test. URLs never appear or vanish silently.
- **Explicitly NOT detailed UI/interaction testing** — deliberate, scope-limited. The question is "does this URL work and render the essentials," nothing more.

**Enforcement:** `graphql-codegen` + `tsc` in CI (blocking) for the compile-time half; runtime contract + route smoke tests in CI against a seeded DB.

Full rationale: `docs/engineering-constitution.md` Article XV.
