---
title: Tier 2 becomes a pointer layer, not a second copy of the stack skills
date: 2026-09-16
component: skills
status: implemented
supersedes: null
dependencies: [2026-09-04-deployment-cycle]
---

## Problem

`engineering-constitution` is always-on, and it bundled the full text of
Articles XIII-XIX — the PostgreSQL · PostGraphile · Docker · AKS mechanism
layer. A personal project on Flutter/Dart, or on TanStack Start + Neon +
Cloudflare, therefore had another stack's laws asserted at it on every
invocation. Article XX said Tier 2 was swappable, but its own Enforcement line
admitted "this article is process" — Principle 7's definition of a suggestion.

The mechanism text also existed twice. Article XIV and
`postgres-postgraphile-rls-and-sql` were near-verbatim duplicates, as were XIX
and `cloud-delivery-aks`, XV and `graphql-contract-testing`, XVII and
`zero-downtime-migrations`. The skill copy behaves correctly — it loads only
when a task touches that stack. The constitution copy followed every project.

## Decision

Articles XIII-XIX collapse to stubs. Each keeps its number and title, states the
Tier 1 principle it implements, names the skill that **owns** its mechanism, and
states what a different stack must still provide. Tier 1 (I-XII) and Article XX
are unchanged.

- Stubs rather than deletion: six skills cite these articles by number in their
  `Full rationale:` footers, and Article XX refers to XIII-XIX explicitly.
  Deleting them would dangle every one of those references.
- Titles were de-stack-ified where they named this stack's tooling — XIV
  "GraphQL Hardening" to "Query Hardening", XVIII "SQL Style" to "Schema Style",
  XIX "Delivery: Kubernetes..." to "Delivery". A map should not itself be
  stack-specific.
- Article XX gains one rule: the first decision record names which stack skills
  the project adopts and which Tier 2 articles it drops. An undeclared profile
  is the default one, which is rarely what a new project wants.

Effect: the always-on document drops from 394 to 304 lines, on every project
including GoC work.

## Enforcement

Two assertions in `tests/test_skills.sh`, because Article XX was previously
process-only:

- exactly seven `**Owned by:**` pointers exist in Tier 2 — every stack article
  names its owner
- the Tier 2 section stays under 60 lines — mechanism detail cannot creep back
  into the always-on document

## Rejected alternatives

- **Forking the collection for personal work.** Rejected earlier and again here:
  it duplicates 19 skills to vary a minority of their content.
- **A profile/activation system that gates which skills install.** The repo
  deleted one already; gating was the wrong lever, and skill descriptions cost
  ~80 tokens each dormant. This changes *content ownership*, not installation.
- **Leaving the constitution alone and relying on Article XX.** That is the
  status quo, and it is what produced the problem.
- **Authoring Flutter and Cloudflare/Neon stack skills in the same cycle.**
  Deferred — the separation is what unblocks personal use; new profiles get
  written when a project actually needs one.

## Follow-on

Stack skills for Flutter/Dart and for TanStack Start + Neon + Cloudflare, each
claiming the Tier 2 articles it owns for that stack.
