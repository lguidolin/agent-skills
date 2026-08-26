---
name: performance-and-scale
description: Use when working on hot paths, list endpoints, pagination, data-access in loops, or public interfaces/schemas. Symptoms — unbounded queries, N+1 access, no latency budget, optimizing without measuring, or changing an interface many consumers depend on. Keywords — pagination, N+1, Hyrum's Law, performance budget, bundle size.
---

# Performance and Scale

## Overview

Performance is a feature with a budget. Measure it, bound it, and respect that today's behaviors become tomorrow's contracts. Systems rarely fall over at the throughput you designed for — they fall over on the query you didn't index and the list you didn't paginate.

## The Principles

- **Set budgets and measure against them.** Latency targets (tied to the SLOs of `observability-and-slos`) and client budgets (e.g. bundle size). A regression past budget is a bug.
- **Measure before optimizing.** Find the real bottleneck with data — profiles, query plans, traces — before changing code. No speculative optimization.
- **Paginate by default.** Any list that can grow is paginated with a capped page size. Unbounded result sets are a latency and denial-of-service hazard.
- **Beware N+1 access patterns.** Data fetched in a loop is the most common scalability failure; batch or join instead. (On this stack: use the GraphQL layer's look-ahead/DataLoader rather than per-row resolution.)
- **Hyrum's Law is real: every observable behavior of an interface becomes a contract someone depends on** once it has enough consumers — including behaviors you never intended (ordering, nullability, error shapes, timing). Treat public interfaces (the API/schema especially) as contracts: **add and deprecate, don't silently change.** The contract tests of `graphql-contract-testing` pin the behaviors you chose; discipline protects the ones you didn't.

## Quick Reference

| Smell | Fix |
|---|---|
| Query inside a loop | Batch or join; use look-ahead |
| List endpoint with no limit | Add capped pagination |
| "Let me optimize this" with no measurement | Profile first; find the real bottleneck |
| Changing a field's type/nullability/order | It's a contract change — add new, deprecate old |
| No latency or bundle target | Set a budget; treat regressions as bugs |

**Enforcement:** budgets checked in CI where mechanizable (bundle-size limits, query-cost limits); pagination and N+1 avoidance are reviewer judgment backed by load testing and query-plan review.

Full rationale: `docs/engineering-constitution.md` Article XI.
