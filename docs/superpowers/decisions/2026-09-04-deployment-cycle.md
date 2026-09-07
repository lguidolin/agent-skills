---
title: Define the preview to production deployment cycle
date: 2026-09-04
component: skills
status: implemented
supersedes: null
dependencies: [2026-08-27-superpowers-integration]
---

## Architecture

Three layers of specificity, so one collection serves both GoC/AKS work and
solo projects. **Layer 1** states properties and may name no cloud,
orchestrator, or pricing tier. **Layer 2** carries stack mechanisms behind a
trigger. **Layer 3** (a launchpad-side cycle skill) is deferred to its own
cycle in the infrastructure repo.

The pipeline is `local dev → preview → staging → production`.

- `skills/resilience-and-deploy-safety/SKILL.md` — the promotion property (Layer 1)
- `skills/merge-gates-and-automation/SKILL.md` — enforcement modes (Layer 1)
- `skills/cloud-delivery-aks/SKILL.md` — `## The Pipeline`: tiers, retag, gates (Layer 2)
- `skills/engineering-constitution/references/` — Articles VIII, XII, XIX amended
- `skills/ship-it/SKILL.md` — preview verification; deploy awareness ends there
- `tests/test_skills.sh` — 11 assertions holding the above in place (155 → 166)

## Decisions

- **The artifact's identity is its content digest**, not a tag. Tags are mutable
  pointers and are never the unit of promotion or rollback. This is what makes
  "the exact thing we tested" a property the pipeline enforces rather than a
  discipline someone remembers.
- **Build once at the PR head, retag the digest on merge.** The reviewed image
  is the shipped image. Guarded by requiring branches up to date before merging
  *and* by comparing the squash tree to the PR head tree — unequal means the
  content differs, so it rebuilds and enters staging as a fresh candidate that
  was never reviewed as a preview.
- **The Article VIII local-build exception is retired.** Images build in CI,
  conditioned on layer caching and provenance attestation. Provenance on a
  developer machine cannot be verified by anyone else. The latency that
  justified the exception is a solvable problem; unverifiable provenance is not.
- **Enforcement mode is declared, never assumed** — `enforced` (branch
  protection blocks merge) or `advisory` (CI reports; the gate is discipline).
  Branch protection is unavailable on private repos under a free plan, so
  without this the collection's central rule would be silently false wherever it
  is most tempting to ignore.
- **Every merge to main deploys to staging.** Production promotes the digest of
  the release commit's *parent* — the release commit changes only a changelog
  and manifest, so its tree is never one staging soaked.
- **The version is injected at deploy time, never baked into the image.** A
  baked version forces a rebuild to stamp a release, destroying build-once.
- **Two repos coordinate by expand/contract.** Infrastructure expands, the app
  consumes, infrastructure contracts. Never ship an app artifact requiring an
  infrastructure change not yet live — that keeps each repo independently
  reversible.
- **`ship-it` ends its deployment awareness at the preview.** Promotion belongs
  to the delivery skill; Phases 4-6 remain git and documentation hygiene.

## Rejected alternatives

- **Forking the collection for solo projects.** ~80 tokens per dormant skill
  versus duplicating 19 skills to vary a minority of their content, then
  applying every fix twice. The repo had already deleted a profile system for
  the same reason. Discipline is invariant; only mechanism and enforcement
  substrate flex.
- **Describing the pipeline as the templates actually behave today** (per-env
  rebuilds, version tags). Would have ratified a practice the constitution
  calls wrong.
- **Keeping the local build with tightened mitigations.** Rejected after
  weighing SLSA provenance and separation of duties against build latency.
- **Naming the middle tier `testing`.** Collides with the word for automated
  tests in skills that discuss both.
- **Qualifying "never rebuilt per environment" at its source.** The invariant is
  intact — an unequal tree is different content, not one artifact rebuilt per
  target — so the carve-out is reconciled locally instead.

## Constraints

- Layer 1 rules name no vendor, cloud, orchestrator, or pricing tier.
- A test assertion must fail if the change it guards is reverted. Two assertions
  in the original plan passed on pre-existing text and were retargeted.
- The word `alpha` and the phrase `build locally` are barred from `skills/` by
  repo-wide greps.

## Deferred

- Layer 3, the launchpad `gphin-plus-deployment-cycle` skill.
- Launchpad template remediation, including a latent defect where the template
  copies production secrets into per-PR namespaces (not present in the one repo
  that has adopted it; verified 2026-09-04 across two repos only).
- Collection-wide scale-down audit — 17 of 19 skills lack "When to scale this".

All three are recorded in `docs/superpowers/future-considerations.md`.
