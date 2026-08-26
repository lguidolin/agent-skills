---
name: verification-gate-and-automation
description: Use when setting up or changing CI, pre-push hooks, or a task runner, or deciding what must pass before merge. Symptoms — tempted to put authoritative checks only in a local hook, skip CI, bypass with --no-verify, or unsure what gates a merge vs. runs locally.
---

# Verification Gate and Automation

## Overview

Where verification lives and what makes it real. **CI is the source of truth; the local hook is a convenience mirror.** A rule not enforced by an unbypassable gate is a suggestion (Principle 7).

## The Rules

- **One task runner is the canonical entry to every everyday operation** — test, build, dev, deploy are named recipes. A procedure that lives only in someone's head doesn't reliably happen and can't be handed to an agent.
- **CI is the source of truth — authoritative, shared, unbypassable.** Lint, typecheck, contract checks, tests, security scans, commit validation all run here and **must pass before merge**. What CI says is what counts.
- **The pre-push hook is a presubmit mirror, not a wall.** It runs the same fast checks locally so you *probably* pass CI before pushing. It is explicitly **bypassable** (`--no-verify`) and only runs where the toolchain is installed. Its job is speed and early feedback, not enforcement. **The hook never gates; CI gates.**
- **Keep CI fast by tiering, not by removing checks.** When the full suite outgrows every-PR, split **presubmit** (fast subset, blocks PR) from **postsubmit** (full suite, after merge, blocks promotion) — never move authoritative checks back to the bypassable hook.
- **One deliberate exception: container images build locally and push to the registry, not in CI** — when CI image-build latency is unacceptable. This is a **known, accepted trade-off**, not an ideal: the artifact's provenance is a developer machine. Mitigate — build only from clean git state at a tagged SHA, pin toolchain and base-image digests, tag the image with the SHA.

## The Named Tension

A bypassable local presubmit is *fast but unenforceable*; authoritative CI is *enforceable but slower*. Resolve by giving each a different mandate — the hook optimizes the inner loop, CI the correctness of record — and by making **CI, not the hook**, the thing that blocks a merge.

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "The pre-push hook runs the tests, so CI can be minimal" | The hook is bypassable and toolchain-dependent. It cannot be the source of truth. CI must re-run everything. |
| "I'll just `--no-verify` this once" | Fine — because CI will still catch it. That's exactly why CI, not the hook, is the gate. |
| "CI is slow, let's move tests to the hook" | Tier CI (presubmit/postsubmit); never relocate authoritative checks to a bypassable gate. |
| "Let's build the prod image in CI for purity" | Allowed, but latency may justify the local-build exception. If local, pin SHAs/digests and accept the provenance trade-off consciously. |

## Red Flags — STOP

- Authoritative checks that exist *only* in a local hook
- CI that doesn't re-run what the hook ran
- A merge allowed while CI is red
- A locally-built image with no SHA tag or pinned digests

Full rationale: `docs/engineering-constitution.md` Article VIII. Deploy/k8s specifics: `cloud-delivery-aks`.
