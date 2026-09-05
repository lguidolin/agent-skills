---
name: merge-gates-and-automation
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
- **Container images build in CI**, identified by content digest and published with a provenance attestation. Keep it affordable with registry layer caching or a self-hosted runner — never by moving the build back to a laptop, where the artifact's provenance cannot be verified by anyone else.
- **Declare the enforcement mode.** `enforced` — CI blocks merge via branch protection; what CI says is what counts. `advisory` — CI runs and reports, and the gate is discipline, because branch protection is unavailable (a private repository on a free plan). Advisory is legitimate; claiming enforcement you do not have is not. State the mode in the project's first decision record, and what would move it to enforced.

## The Named Tension

A bypassable local presubmit is *fast but unenforceable*; authoritative CI is *enforceable but slower*. Resolve by giving each a different mandate — the hook optimizes the inner loop, CI the correctness of record — and by making **CI, not the hook**, the thing that blocks a merge.

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "The pre-push hook runs the tests, so CI can be minimal" | The hook is bypassable and toolchain-dependent. It cannot be the source of truth. CI must re-run everything. |
| "I'll just `--no-verify` this once" | Fine — because CI will still catch it. That's exactly why CI, not the hook, is the gate. |
| "CI is slow, let's move tests to the hook" | Tier CI (presubmit/postsubmit); never relocate authoritative checks to a bypassable gate. |
| "CI builds are slow, I'll build the image locally" | A laptop-built artifact carries provenance no one else can verify. Fix the latency with a layer cache or a self-hosted runner. |
| "Branch protection costs money, so the rules don't apply" | The rules apply; the *enforcement* differs. Declare advisory mode and keep the discipline, or make the repository public and get protection free. |

## Red Flags — STOP

- Authoritative checks that exist *only* in a local hook
- CI that doesn't re-run what the hook ran
- A merge allowed while CI is red
- An image built anywhere but CI, or promoted by tag rather than by digest
- A project behaving as though CI gates merge when no branch protection exists

Full rationale: Article VIII of the constitution, bundled at `engineering-constitution/references/engineering-constitution.md`. Deploy/k8s specifics: `cloud-delivery-aks`.
