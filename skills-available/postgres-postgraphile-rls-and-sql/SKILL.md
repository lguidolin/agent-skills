---
name: postgres-postgraphile-rls-and-sql
description: Use when writing PostgreSQL, PostGraphile config, Row-Level Security policies, SQL schema files, or working on the Browser→App→PostGraphile→Postgres data path. Keywords — RLS, SECURITY DEFINER, search_path, pgSettings, grants, roles, GraphQL depth limit, query cost, statement_timeout, SQL file organization.
---

# Postgres, PostGraphile, RLS and SQL

## Overview

The data-layer mechanism for this stack. Implements **defense in depth** (RLS as the final wall) and the **one legal data path**. Stack-specific — won't apply to projects without PostGraphile/Postgres.

## The Data Path

**Browser → App server → PostGraphile → PostgreSQL.** Exactly one legal path.

- The browser never talks to GraphQL/DB directly; the app never queries the DB directly for application data.
- The app passes **session context as headers only** (user id, org hint) — **no authorization logic in the app**; context is validated downstream, not trusted.
- A single path = a single place to enforce auth context, validation, and RLS. Side channels are the holes that bypass enforcement.

## Security Rules

- **RLS is the final enforcement layer.** App-layer checks are UX; the database is the wall. Even a bug in the layers above cannot leak another tenant's rows.
- **Roles model real session states** — not-logged-in, logged-in-without-org, logged-in-with-org, a connection-only role, a migration-only role. Roles mean something.
- **The privileged connection role never executes application queries.** App queries run under a constrained, RLS-subject role.
- **`SECURITY DEFINER` functions set `search_path` inline** in their definition — every time, no exceptions.
- **Absence is `NULL`, never an empty string.** Empty-string sentinels are forbidden; omit the value when absent.
- **GraphQL is a DoS surface — bound it.** Enforce **query depth limits** and **cost/complexity analysis**; reject over-budget queries. Cap pagination size. Set a DB **`statement_timeout`** for app roles. **Disable introspection in production** unless deliberately needed.

## SQL Style

- **One object per file** — each table, function, policy, grant set in its own file.
- **Organized `schema/object_type/name`** — directory mirrors the database's organization.
- **Include order is dependency order;** the include manifest is the table of contents.
- **Document inline.** `COMMENT ON` lives in the same file as the object — *what* and *why*.
- **Descriptive aliases** (singular of the table name, not single letters); follow Postgres idioms (`current_*` getters).
- **Types and user-facing roles are data, not hardcoded constraints** — lookup tables with key/label/description, validated by FK, extensible without schema changes.

## Quick Reference

| Rule | Check |
|---|---|
| New `SECURITY DEFINER` function | `search_path` set inline? |
| New table with tenant data | RLS policy + deny tests (see `graphql-contract-testing`)? |
| Absent value | `NULL`, not `''`? |
| New GraphQL surface | Depth/cost limit and pagination cap? |
| New object | Own file, dependency-ordered include, inline `COMMENT ON`? |

Full rationale: `docs/engineering-constitution.md` Articles XIII, XIV, XVIII. Migrations: `zero-downtime-migrations`. Contract tests: `graphql-contract-testing`.
