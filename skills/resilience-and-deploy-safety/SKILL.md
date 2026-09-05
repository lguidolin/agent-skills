---
name: resilience-and-deploy-safety
description: Use when planning a deploy, designing a rollback, or responding to an incident or writing a postmortem. Keywords — deploy safety, rollback, immutable artifact, progressive delivery, canary, blast radius, incident response, blameless postmortem, error budget.
---

# Resilience and Deploy Safety

## Overview

Things will break. The stance is not "prevent all failure" but **fail small, recover fast, and learn every time.** Reliability is not the absence of failure; it is the bounded blast radius and short recovery time when failure comes.

## Deploy Safety — Every Deploy Reversible and Progressively Exposed

- **The artifact is immutable and promoted, not rebuilt.** One image, built once in CI and identified by its **content digest**, moves preview → staging → production unchanged. Rebuilding per environment means deploying something you never tested.
- **Tags are mutable pointers; the digest is the identity.** A tag can be overwritten and silently point somewhere new. A content digest cannot. Each environment records the digest it validated, and **production runs only a digest a lower environment validated** — so "the exact thing we tested" is a property the pipeline enforces, not a discipline someone has to remember.
- **A human decision precedes production.** For a solo maintainer this is a deliberate pause and an audit record rather than separation of duties. Say which it is; do not oversell it.
- **The running version is injected at deploy time, never baked into the image.** A version baked as a build argument forces a rebuild to stamp a release, and the rebuild is exactly what promotion exists to avoid.
- **When infrastructure lives in its own repository, coordinate by expand/contract.** Infrastructure **expands** first (additive, backward-compatible), the application consumes the new capability in a later deploy, and infrastructure **contracts** only once no live artifact depends on the old shape — the same discipline as a schema change (see `zero-downtime-migrations`). The invariant: **never ship an application artifact that requires an infrastructure change not yet live.** Held to that, each repository is independently reversible, which is what makes rollback tractable when the two are out of step.
- **Roll forward only when you can roll back.** A rollback path exists and is tested *before* a risky change ships. "How do we undo this?" is answered in the plan, not during the incident.
- **Rollback is redeploying the previously-good digest.** That digest is still in the registry and still immutable, so rolling back is promotion in reverse — never a rebuild, and never a rebuild "as it was".
- **Progressive exposure.** New versions reach users gradually (health-gated rollout, canary where supported), so a bad release harms a fraction, not everyone.
- **Schema changes are decoupled from code deploys** and follow expand/contract (see `zero-downtime-migrations`). A deploy must never require a simultaneous destructive migration.
- **A deploy-readiness checklist gates production:** observability in place, rollback verified, migrations expand-safe, SLOs unbroken.

## Incident Response — Failure Is a Learning Input

- **Classify by severity** and respond proportionally; have a known path to engage the right people.
- **Blameless postmortems for every user-facing incident.** Written timeline, contributing causes (systemic, not personal), concrete action items. The question is "what about the system let this happen," never "who messed up."
- **Action items are tracked, not forgotten** — they flow into the Future Considerations doc (see `recording-decisions`) and become real work.
- **The error budget governs.** When reliability is spent, reliability work outranks features until the budget recovers.

## Quick Reference

| Before a risky deploy | Confirm |
|---|---|
| Artifact | Built once in CI; promoted by digest; the same one staging validated |
| Gate | A human decision recorded before production |
| Rollback | Path exists and is tested |
| Exposure | Gradual/canary, not all-at-once |
| Schema | Expand-safe, decoupled from the code deploy |
| Observability | Can you see if it's going wrong? |

## When to scale this

Local/pre-launch projects write these rules now, activate on first real users. The properties are portable — build once, promote what you tested, decide before production, be able to roll back — but the mechanisms are not: a digest promotion is meaningful on a container host and largely moot for a static site, and a managed platform may supply preview environments and instant rollback for free. Name the mechanism in the project's delivery skill; keep the property here. Stack mechanisms (k8s probes, canary, per-PR envs): `cloud-delivery-aks`.

Full rationale: Article XII of the constitution, bundled at `engineering-constitution/references/engineering-constitution.md`.
