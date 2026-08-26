---
name: resilience-and-deploy-safety
description: Use when planning a deploy, designing a rollback, or responding to an incident or writing a postmortem. Keywords — deploy safety, rollback, immutable artifact, progressive delivery, canary, blast radius, incident response, blameless postmortem, error budget.
---

# Resilience and Deploy Safety

## Overview

Things will break. The stance is not "prevent all failure" but **fail small, recover fast, and learn every time.** Reliability is not the absence of failure; it is the bounded blast radius and short recovery time when failure comes.

## Deploy Safety — Every Deploy Reversible and Progressively Exposed

- **The artifact is immutable and promoted, not rebuilt.** One image, built once, tagged by commit SHA, moves dev → alpha → prod unchanged. Rebuilding per environment means deploying something you never tested.
- **Roll forward only when you can roll back.** A rollback path exists and is tested *before* a risky change ships. "How do we undo this?" is answered in the plan, not during the incident.
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
| Artifact | Immutable, SHA-tagged, same one tested in lower envs |
| Rollback | Path exists and is tested |
| Exposure | Gradual/canary, not all-at-once |
| Schema | Expand-safe, decoupled from the code deploy |
| Observability | Can you see if it's going wrong? |

## When to scale this

Local/pre-launch projects write these rules now, activate on first real users. Stack mechanisms (k8s probes, canary, per-PR envs): `cloud-delivery-aks`.

Full rationale: `docs/engineering-constitution.md` Article XII.
