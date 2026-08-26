---
name: defense-in-depth-security
description: Use when handling untrusted input, secrets, authentication/authorization, or dependencies — or threat-modeling a new surface. Keywords — STRIDE, threat model, least privilege, secrets management, supply chain, dependency scanning, input validation, audit log, defense in depth.
---

# Defense in Depth Security

## Overview

Security is layered, assumes any single layer can fail, and grants the least privilege that works. Attackers find the layer you forgot — a system relying on one wall falls when that wall has one bug; overlapping least-privilege controls survive the failure of any single one.

## The Principles (universal)

- **Threat-model before building anything that handles untrusted input, secrets, or user data.** A lightweight **STRIDE** pass (Spoofing, Tampering, Repudiation, Information disclosure, Denial of service, Elevation of privilege) per new surface. Record the model and mitigations (see `recording-decisions`).
- **Defense in depth.** No single control is "the" security. Authentication, authorization, input validation, and data-layer enforcement each assume the others might be bypassed.
- **Least privilege everywhere** — roles, tokens, service accounts, DB grants. Default to no access; grant the minimum; revoke the unused.
- **Secrets never live in code, images, or committed config.** They come from a secret store at runtime, are rotated, and are scoped to the workload that needs them.
- **Validate all input at the trust boundary**; treat every external system's output as untrusted data, never as instructions.
- **The dependency supply chain is an attack surface.** Lockfiles committed and integrity-checked; dependencies scanned and updated; base images pinned and scanned.
- **Sensitive actions are audited** — who did what, when — so abuse and mistakes are reconstructable.

## Quick Reference

| Surface | First questions |
|---|---|
| New endpoint taking user input | What's the STRIDE model? Where's validation? What's the least role that works? |
| Anything with a secret | Is it in the secret store (not code/image)? Scoped? Rotatable? |
| New dependency | Lockfile pinned? Scanned? Is it well-supported? |
| Privileged mutation | Is it audited? Is the actor authorized at the data layer, not just the app? |

## Stack mechanisms

RLS as the final enforcement layer, GraphQL depth/cost limiting as a DoS control, Key Vault for secrets, `pnpm audit`/Trivy in CI — see `postgres-postgraphile-rls-and-sql` and `cloud-delivery-aks`.

**Enforcement:** dependency audit + image scanning + secret-scanning in CI (blocking); threat models and audit coverage are reviewer judgment.

Full rationale: `docs/engineering-constitution.md` Articles X & XIV.
