---
name: zero-downtime-migrations
description: Use when changing a database schema where data must survive the change — adding/removing/renaming columns, constraints, indexes, or backfilling. Symptoms — a destructive migration bundled with a code deploy, a NOT NULL column with a backfill, a table-locking UPDATE, or a rename. Keywords — expand/contract, parallel change, backfill, NOT VALID, CREATE INDEX CONCURRENTLY, graphile-migrate.
---

# Zero-Downtime Migrations

## Overview

Schema change discipline that keeps a running system up during a rolling deploy. During a rollout, old pods and new pods **share one database** — so the schema must be compatible with **both app versions at once.** Combining a destructive migration with the deploy that needs it is the classic self-inflicted outage.

## Authoring Rules (all projects)

- **Two kinds of migration, kept distinct:** the idempotent **`current/`** set (dev iteration — re-run every cycle, `CREATE OR REPLACE` / `IF NOT EXISTS`, objects in **final form**, no post-creation `ALTER`) and **committed** migrations (immutable, ordered, what actually ships). `ALTER DEFAULT PRIVILEGES` is the lone accepted inline `ALTER`.
- **Ownership comes from how migrations are run**, not scattered `ALTER ... OWNER`.
- **One bootstrap source of truth** shared by the local/Docker init path and the shadow/test DB — every environment built identically.

## Expand/Contract (Parallel Change)

**Applies when:** the database holds data that must survive the deploy (alpha-with-data, production). **Exempt:** local/reset-friendly projects — but write committed migrations *as if* this applies, so promotion is never a rewrite.

A schema change is split across **three releases**, never one:

1. **Expand** — add the new shape *additively*, backward-compatibly: new nullable column, new table, new function. App version *N* keeps running untouched.
2. **Migrate** — backfill in **bounded batches** (never one table-locking `UPDATE`); dual-write from app *N+1* if needed; switch reads to the new shape. Only now add `NOT NULL` (add the constraint `NOT VALID`, then `VALIDATE` separately).
3. **Contract** — only after app *N* is fully retired, remove the old column/constraint in a *later* release.

## Postgres Footguns

| Footgun | Safe approach |
|---|---|
| `NOT NULL` column with volatile/large backfill default | Add nullable → backfill in batches → add constraint `NOT VALID` → `VALIDATE` |
| Adding a constraint | Add `NOT VALID` first, then `VALIDATE CONSTRAINT` (weaker lock) |
| Building an index | `CREATE INDEX CONCURRENTLY` — **cannot run in a transaction**; isolate from migration-tool transaction wrapping |
| A blocked migration freezing prod | Set `lock_timeout` / `statement_timeout` so it fails fast |
| Renaming a column | It's expand/contract: add new → backfill → switch reads → drop old, across releases |

## Why "final-form CREATE OR REPLACE" isn't enough in prod

That rule is *developer ergonomics* and is correct in dev. In production with live users and a rolling deploy, both app versions share the schema for the rollout's duration — so expand/contract is what makes the change safe. Don't conflate the two.

Full rationale: `docs/engineering-constitution.md` Article XVII. Deploy pipeline: `cloud-delivery-aks`.
