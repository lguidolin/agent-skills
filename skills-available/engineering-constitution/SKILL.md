---
name: engineering-constitution
description: Use when starting work in a project that follows the engineering constitution, orienting to its rules, or deciding which engineering practice applies to a task — spec writing, commits, testing, security, deploys, database, or UI work.
---

# Engineering Constitution

## Overview

A portable charter of engineering practice, decomposed into focused skills. This skill is the **index**: it states the inviolable principles and routes you to the specific skill for your task. The full reasoning lives in `docs/engineering-constitution.md` (in this repo and in `agent-skills/docs/`).

**Core idea:** *Software engineering is programming integrated over time.* Optimize for the long-lived system — operating it, changing it safely, recovering when it breaks — not the first deploy.

## The Eight Inviolable Principles

1. **Understand before building.** No code before an approved design.
2. **Record every decision with its rationale — and what you rejected.**
3. **Tests are a control, not a formality.** A failing test is information, never edited away.
4. **YAGNI, ruthlessly.**
5. **Automate the repeatable.**
6. **Software engineering is programming integrated over time.**
7. **A rule not enforced is a suggestion.** Bind rules to tooling or label them reviewer-judgment.
8. **The user's explicit instructions outrank this document.** Precedence: User → Constitution → tool defaults.

## Which Skill Do I Need?

**Tier 1 — universal (applies to every project):**

| Your task | Skill |
|---|---|
| Starting a feature, turning an idea into a spec/plan | `designing-before-building` |
| A decision was made; writing it down (ADR, index, deferred ideas) | `recording-decisions` |
| Committing, writing messages, automated releases | `conventional-commits-and-releases` |
| Writing/changing tests; permission/role rules; a test broke in a refactor | `tests-as-a-control` |
| Writing or refactoring code; structuring a change; DRY decisions | `change-hygiene-and-code-craft` |
| Building UI, components, styling, accessibility | `interface-craft-and-accessibility` |
| CI, pre-push hooks, task runners, merge gates | `verification-gate-and-automation` |
| Logging, metrics, tracing, health checks, SLOs, alerts | `observability-and-slos` |
| Untrusted input, secrets, auth, dependencies, threat modeling | `defense-in-depth-security` |
| Hot paths, pagination, N+1, list endpoints, public interfaces | `performance-and-scale` |
| Planning a deploy, rollback, or incident/postmortem | `resilience-and-deploy-safety` |

**Tier 2 — stack-specific (load only when the tooling/topic is present):**

| Your task | Skill |
|---|---|
| PostgreSQL, PostGraphile, RLS, SQL files, the app→GraphQL→DB path | `postgres-postgraphile-rls-and-sql` |
| GraphQL queries shared between UI and tests; route/schema contract tests | `graphql-contract-testing` |
| Schema change with data that must survive — migrations, backfills | `zero-downtime-migrations` |
| Deploying to Kubernetes/AKS, cloud secrets, progressive rollout, per-PR envs | `cloud-delivery-aks` |

## How These Skills Apply to a New Project

- **Tier 1 travels unchanged.** Every skill above the line applies to any project — web app, pipeline, CLI, library.
- **Tier 2 is swappable.** When the stack differs, the Tier-2 skills won't trigger (their descriptions are stack-specific) and you substitute equivalents. The *principles* they implement (one data path, final enforcement low, contract seams, reversible deploys) still hold.
- **Scale to lifecycle.** A pre-launch or local-only project applies zero-downtime migrations, canary, and formal incident process as *write-the-rule-now, activate-on-trigger*. State the project's mode in its first decision record.

## Red Flag

If you're about to write code, commit, deploy, or change a test and you have **not** consulted the relevant skill above — stop and load it first. The constitution overrides default habit (Principle 7); habit is what it's correcting for.
