# Deployment Cycle — Design Spec

## Overview

Define how a change travels from pull request to production, and write that
definition into the skills as **portable rules plus swappable mechanisms**.

The pipeline is `local dev → preview → staging → production`. One artifact is
built per change and **promoted by digest** — never rebuilt per environment. A
human decision precedes production. Rollback is redeploying the previous digest.

The rules live in this repo and apply to every project, solo or GoC. The
mechanisms that implement them (AKS, GitHub Environments, `workflow_dispatch`)
are quarantined behind stack- and context-specific triggers, so a solo project on
a free plan follows the same discipline through different machinery.

## Problem

The intended pipeline is undocumented in any skill. `resilience-and-deploy-safety`
covers immutable artifacts in principle and `cloud-delivery-aks` covers the
Kubernetes mechanisms, but neither names the promotion path or the approval gate.

Investigation of the real repos (`gphin/gphin-plus`, `gphin/gphin-plus-launchpad`)
found the gap is wider than a missing staging tier:

1. **There is no promotion at all.** `alpha-deploy.yml.tmpl` builds `:pr-<N>`, a
   *mutable* tag overwritten on every push. `prod-deploy.yml.tmpl` consumes a
   *separately built* `:<semver>` image produced locally. The image that reaches
   production was never the image anyone reviewed.
2. **The Article VIII local-build exception was never actually implemented.** It
   is conditional on three mitigations — clean git state at a tagged SHA, pinned
   toolchain and base-image digests, image tagged with the SHA.
   `build-push.sh.tmpl` does none of them.
3. **No staging tier exists.** `tofu/environments/` contains `bootstrap` and
   `prod` only.
4. **No approval gate.** `release: published` deploys straight to production.
5. **`APP_VERSION` is baked in as a build arg**, which makes build-once
   structurally impossible: the version is not known until release-please mints
   it, long after the artifact should have been built.
6. **`gphin-plus` has no `.github/workflows` at all.** The installer has never
   run there. This is a specification before adoption, not a retrofit.
7. **"Alpha" means two different things.** The constitution's `dev → alpha → prod`
   ladder implies a persistent tier; the templates use `alpha-<app>-pr-N` for
   ephemeral per-PR namespaces.

A second problem surfaced during design. The collection was written for GoC work
(Azure, AKS, paid GitHub) but is wanted for solo projects on a free plan. Only
**2 of 19** skills carry a "When to scale this" section. Critically,
`merge-gates-and-automation`'s premise — CI is an unbypassable gate — depends on
branch protection, which GitHub does not offer on **private** repositories under
a free plan. This repo's own gates work because it is *public*.

## Goals

- A promotion path stated as properties, portable across AKS, a VPS, a PaaS, or
  a static host.
- One artifact per change, promoted by digest, so production runs exactly what
  staging validated.
- An explicit, declared enforcement mode so a project on a free plan is honest
  about what its gates actually guarantee.
- Consistent tier terminology across both repos.
- A launchpad-side skill describing the GPHINplus cycle concretely, citing the
  house rules rather than restating them.

## Non-Goals

- **Changing the launchpad templates or tofu.** This cycle produces skills. The
  template gaps are recorded as known deviations and become a later cycle.
- **Onboarding `gphin-plus` onto the pipeline.** Separate work.
- **A collection-wide scale-down audit.** Adding "When to scale this" to the
  other 17 skills is recorded in future considerations, not done here.
- **Forking the collection for solo use.** Explicitly rejected; see Decisions.

## Decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | Skills describe the **target** pipeline, not current templates | Building twice risks production differing from what was tested |
| 2 | **The build moves into CI**; the Article VIII exception is retired | Provenance; SLSA Build L2 is unreachable from a laptop. Conditional on layer caching + attestation |
| 3 | Build at **PR head**, retag the digest on merge | The reviewed image is the shipped image; one build per change |
| 4 | **Every merge to main** deploys to staging | Maximises soak; staging cannot drift from main |
| 5 | Tiers are `local dev → preview → staging → production` | "Alpha" was ambiguous across the two repos |
| 6 | **No fork.** One collection; discipline invariant, mechanisms flex | ~80 tokens/skill dormant; a fork duplicates 19 skills to vary a minority of content |
| 7 | Enforcement mode is **declared**, not assumed | A free private repo cannot have unbypassable gates; silence would misrepresent them |

## Architecture

Three layers. Each states the same intent at a different level of specificity.

### Layer 1 — House rules (this repo, universal)

Mechanism-free. No layer-1 rule may name Azure, Kubernetes, GitHub, or a plan
tier.

**The promotion property** → `resilience-and-deploy-safety`

- One artifact per change, built once, identified by **content digest**. Tags are
  mutable pointers; digests are not. Promotion moves a digest.
- Promotion never rebuilds.
- Each environment records the digest it validated.
- Production runs only a digest a lower environment validated.
- A human decision precedes production.
- Rollback is redeploying the previously-good digest.

**Enforcement mode** → `merge-gates-and-automation` (new concept)

Declared once, in the project's first decision record:

| Mode | Applies when | Meaning |
|---|---|---|
| `enforced` | Public repo, or paid private | CI gates merge via rulesets. What CI says is what counts. |
| `advisory` | Free private repo | CI runs and reports. The gate is discipline, not enforcement. |

Advisory is legitimate. Presenting advisory as enforced is not. A project in
advisory mode states so, and states what would move it to enforced (make it
public, or pay).

**Build site** → amends Article VIII and its three downstream references. CI
builds. Conditions: registry layer caching (`cache-to`/`cache-from`) or a
self-hosted runner, and build provenance attestation.

**Version injection** → the running version comes from the environment at deploy
time, never from a build arg. Without this, build-once is impossible.

### Layer 2 — Delivery mechanism (`cloud-delivery-aks`, stack-quarantined)

| Tier | Trigger | Environment | Digest |
|---|---|---|---|
| preview | PR opened / synchronize | ephemeral ns `preview-<app>-pr-<N>` | built here, tagged `sha-<pr-head>` |
| staging | merge to main | persistent ns `staging` | **retag** of the preview digest as `sha-<merge>` |
| production | release published + approval | ns `production` | digest of the release commit's **parent** |

**Why the parent commit.** release-please's release commit changes `CHANGELOG.md`
and the manifest, so its tree differs from anything ever built. Its parent is the
last feature merge — exactly what staging has been soaking. Deriving the digest
from git rather than from live cluster state keeps promotion reproducible and
auditable.

**Retag safety.** Squash-merge produces a different commit SHA and, if main moved
while the PR was open, a different *tree*. Two guards:

- Require "branches up to date before merging" (a ruleset flag separate from
  required checks), so the squash tree equals the PR head tree by construction.
- Verify rather than assume: compare `git rev-parse <merge>^{tree}` against the
  PR head tree. Equal → retag. Unequal → rebuild at the merge SHA. The design
  degrades safely instead of mislabelling an artifact.

The retag is a pointer operation, no rebuild and no pull:
`docker buildx imagetools create -t <repo>:sha-<merge> <repo>@sha256:<digest>`.

Attestation remains bound to the PR head SHA, so the head→merge mapping must be
recorded in the deployment record; image config cannot be edited without
rebuilding.

**Approval gate** — one property, two mechanisms:

| Mode | Mechanism |
|---|---|
| `enforced` | GitHub Environment `production` with required reviewers |
| `advisory` | `workflow_dispatch` promote job; running it *is* the decision |

For a solo maintainer the gate is a deliberate pause and an audit record, not
separation of duties. The skill says so rather than overselling it.

### Layer 3 — Launchpad cycle skill (`gphin-plus-launchpad`)

New skill `gphin-plus-deployment-cycle`, sibling to
`install-gphin-plus-deployment-ci`, following the established pattern: a thin
`SKILL.md` pointer plus a `procedure-sha256` drift guard over a canonical
`CYCLE.md`.

It describes GPHINplus concretely — real namespaces, real commands, who
approves, how to roll back — and **cites** the house rules rather than restating
them. It carries a **Known Deviations** section listing where today's templates
fall short of the design, which becomes the to-do list for the template cycle.

## Two-repo coordination and rollback

Infrastructure lives in a separate repository, so promotion crosses a boundary.
This resolves to the **expand/contract** discipline already used for schema
changes (`zero-downtime-migrations`):

- Infrastructure **expands** first (new resource, new capability — additive,
  backward-compatible).
- The application consumes it in a later deploy.
- Infrastructure **contracts** afterwards, once no live digest depends on the old
  shape.

The invariant: **never ship an app digest that requires an infra change not yet
live.** Rolling back the application then never requires touching infrastructure,
and the two repos are independently reversible — which is what makes rollback
tractable when they are out of step.

## Terminology change

`alpha` → `preview` for ephemeral per-PR environments; `staging` is the new
persistent tier.

Affected here: `engineering-constitution` (Article XIX ladder and the
`references/` bundle), `cloud-delivery-aks`, `resilience-and-deploy-safety`.

Affected in launchpad (later cycle): `alpha-<app>-pr-N` namespaces,
`alpha-deploy.yml.tmpl`, `alpha-cleanup.yml.tmpl`, `infra-defaults.json`,
`PROCEDURE.md`.

## Changes required in this repo

| File | Change |
|---|---|
| `engineering-constitution/references/engineering-constitution.md` | Art. VIII: retire the local-build exception, rewrite the Named tension paragraph. Art. XIX: CI builds; ladder renamed; add staging tier |
| `merge-gates-and-automation` | Retire the exception bullet and its Common Rationalizations row; add enforcement modes |
| `resilience-and-deploy-safety` | Add the promotion property; digest-not-tag; version injection |
| `cloud-delivery-aks` | Add the tier table, retag mechanics, approval-gate mechanisms; rename alpha→preview |
| `ship-it` | Phase 3 gains preview verification; skill ends its deploy awareness at preview. Explicitly disclaims staging/production. Phases 4-6 unchanged |
| `docs/superpowers/future-considerations.md` | Close this entry; open two new ones |

## Known deviations (current templates)

Recorded, not fixed:

- Builds are local and per-environment; no promotion
- `build-push.sh` satisfies none of the Article VIII mitigations
- `APP_VERSION` baked as a build arg
- No staging tier in `tofu/environments/`
- No approval gate before production
- Plain rolling update; no canary despite `cloud-delivery-aks` requiring it
- Preview namespaces copy secrets out of the **production** namespace — a
  least-privilege violation under `defense-in-depth-security`

## Open items

- **`ship-it` scope** — resolved: its deployment awareness ends when the preview
  is online. It verifies the preview came up after opening the PR and says
  nothing about staging or production; promotion belongs to the cycle skill.
  Phases 4-6 (merge wait, archival, cleanup) are git/doc hygiene and are
  unaffected.
- **GitHub plan for the `gphin` org** — determines whether the enforced-mode
  approval mechanism is available.

## Verification

The house skills are prose; the check is consistency, enforced by the existing
suite (`tests/run.sh`) plus review:

- No layer-1 rule names a cloud, orchestrator, or plan tier
- No skill still says images build locally
- No skill still uses `alpha` for a per-PR environment
- Every constitution footer still resolves
- `alpha` appears nowhere in `skills/` except a rename note
