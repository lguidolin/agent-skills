---
name: cloud-delivery-aks
description: Use when deploying to Kubernetes or Azure Kubernetes Service (AKS), configuring cloud secrets, setting up progressive rollout/canary, per-PR ephemeral environments, or k8s health probes. Keywords — Kubernetes, AKS, Key Vault, Argo Rollouts, Flagger, canary, blue-green, liveness, readiness, PodDisruptionBudget, HPA, rollback, GHCR.
---

# Cloud Delivery on AKS

## Overview

The delivery mechanism for Kubernetes/Azure. Implements **deploy safety** and the **verification gate** on AKS. **Stack-specific by design** — this skill only loads when a task involves k8s/AKS, so projects without cloud deployment (e.g. local-only Docker Compose) never see this content.

## Delivery Rules

- **Local dev runs the full stack** via Docker Compose, one command, comprehensive — a first-class requirement.
- **Images build in CI → GHCR, identified by content digest**, then **promoted unchanged** preview → staging → production. Never rebuilt per environment.
- **Per-PR ephemeral preview environments.** Each PR deploys to its own isolated namespace on AKS for review, **torn down on merge/close.** The integration-test bed; cheap to create and destroy.
- **Kubernetes health gating.** Every workload defines **liveness, readiness, and startup probes** (wired to the endpoints in `observability-and-slos`), a **rolling update** strategy with bounded `maxUnavailable`/`maxSurge`, and a **PodDisruptionBudget**. Use an **HPA** for load.
- **Progressive delivery to prod.** Canary or blue-green via Argo Rollouts / Flagger with automated metric analysis tied to SLOs; a failed canary **aborts automatically.**
- **Rollback is first-class and rehearsed.** Immutable SHA-tagged images make rollback a redeploy of the prior tag (`kubectl rollout undo` / abort the rollout). Verified before risky changes ship.
- **Migrations are a separate, ordered pipeline step**, expand-safe (see `zero-downtime-migrations`), run **before** the code that depends on them — never bundled into the pod that needs the new schema.
- **CI is the gate:** lint, typecheck, contract checks, tests, security scans block merge. CI also **builds the image and publishes its provenance attestation**, then promotes that digest unchanged.
- **Dev/prod parity & config from the environment.** Secrets from **Azure Key Vault** (via Secrets Store CSI driver or sealed secrets) — never in images or committed `.env`. Ports/config from env. Dev-only tooling (pgTAP, test runners) never ships in prod images.

## The Pipeline

| Tier | Trigger | Environment | Digest |
|---|---|---|---|
| preview | PR opened / synchronize | ephemeral ns `preview-<app>-pr-<N>` | built here, tagged `sha-<pr-head>` |
| staging | merge to main | persistent ns `staging` | **retag** of the preview digest as `sha-<merge>` |
| production | release published + approval | ns `production` | digest of the release commit's **parent** |

**Why the parent commit.** release-please's release commit changes `CHANGELOG.md` and the manifest, so its tree matches no image ever built. Its parent is the last feature merge — exactly what staging has been soaking. Deriving the digest from git rather than from live cluster state keeps promotion reproducible.

**Retag safety.** Squash-merge produces a different commit SHA and, if main moved while the PR was open, a different *tree*. Two guards:

- Require **"branches up to date before merging"** — a ruleset flag separate from required checks — so the squash tree equals the PR head tree by construction.
- Verify rather than assume: compare `git rev-parse <merge>^{tree}` against the PR head tree. Equal → retag. Unequal → rebuild at the merge SHA.

The retag is a pointer operation — no rebuild, no pull:

```bash
docker buildx imagetools create -t "$REPO:sha-$MERGE_SHA" "$REPO@sha256:$DIGEST"
```

Attestation stays bound to the PR head SHA, so record the head→merge mapping in the deployment record; image config cannot be edited without rebuilding.

**The approval gate — one property, two mechanisms:**

| Mode | Mechanism |
|---|---|
| `enforced` | GitHub Environment `production` with required reviewers |
| `advisory` | A `workflow_dispatch` promote job; running it *is* the decision |

## Quick Reference

| Concern | Mechanism |
|---|---|
| Secrets | Key Vault → CSI driver; rotated; never in image |
| Health | liveness + readiness + startup probes; readiness checks real deps |
| Safe rollout | canary/blue-green, SLO-gated, auto-abort on failure |
| Rollback | redeploy prior SHA tag; rehearsed before risky ships |
| Per-PR env | isolated namespace, torn down on merge |
| Schema | separate ordered step, expand-safe, before code |
| Promotion | Retag the digest; never rebuild per environment |
| Approval | Environment reviewers (enforced) or manual dispatch (advisory) |

**Why this is quarantined:** all Azure/k8s specifics live here behind a stack-specific trigger. A local-only or different-cloud project substitutes its own delivery skill; the *principles* (immutable artifact, reversible + progressive deploy, decoupled migrations) come from `resilience-and-deploy-safety`.

Full rationale: Article XIX of the constitution, bundled at `engineering-constitution/references/engineering-constitution.md`.
