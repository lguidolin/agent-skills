# Future Considerations

Deferred ideas, known concerns, and incident action items. Consulted when
starting new work so nothing is silently forgotten. See the
`recording-decisions` skill.

| Status | Meaning |
|---|---|
| `open` | Not started, still wanted |
| `triggered` | Its activation condition has been met — schedule it |
| `done` | Landed; move the rationale into a decision record |
| `dropped` | Deliberately abandoned; keep the row and say why |

---

## Deploy pipeline: staging promotion and infra-repo coordination

- **Status:** `done`
- **Raised:** 2026-08-27
- **Trigger:** next substantive change to the deploy path, or the next release
  that needs a staging soak.
- **Resolved:** 2026-09-04 by the deployment cycle design; see the decision record. Layer 3 (the launchpad cycle skill) and the template remediation below remain.

The intended pipeline is **PR → preview deployment → merge → staging →
approval → production**. Today this is undocumented in any skill:
`resilience-and-deploy-safety` covers immutable artifacts and progressive
exposure in principle, and `cloud-delivery-aks` covers the k8s mechanisms, but
neither names this promotion path or the approval gate between staging and prod.

Complicating factor: the infrastructure lives in a **separate repository**, so
the promotion is a two-repo coordination problem — an app merge has to trigger
or await an infra action, and the two repos' pipelines need a defined contract
(who promotes, what artifact identity travels, where the approval gate lives).

**What to decide when this is picked up:**

- Where the promotion is expressed — app repo, infra repo, or a shared workflow.
- What identifies the artifact across the boundary (commit SHA per
  `resilience-and-deploy-safety`'s immutable-artifact rule).
- Where the human approval gate lives, and who can pass it.
- Whether `ship-it` Phase 4 should learn about staging, or whether promotion is
  outside the wrap-up skill's scope entirely.
- How rollback works when the two repos are out of step.

**Do not** start this before the current skills-integration work is merged —
they touch `ship-it` and `resilience-and-deploy-safety` in overlapping places.

---

## Scale-down guidance is missing from 17 of 19 skills

- **Status:** `open`
- **Raised:** 2026-09-04
- **Trigger:** next time a skill is applied to a solo or pre-launch project and
  its mechanism does not fit.

Only `resilience-and-deploy-safety` and `observability-and-slos` carry a "When to
scale this" section. The collection is wanted for solo projects (SaaS, apps,
CLIs) as well as GoC work, and the discipline is invariant across both — but the
mechanisms are not, and most skills state mechanism and intent in the same
breath.

**What to decide when this is picked up:** whether every skill gets a "When to
scale this" section, or whether the distinction belongs in one place that the
others cite.

---

## Launchpad deployment templates contradict the promotion design

- **Status:** `open`
- **Raised:** 2026-09-04
- **Trigger:** before another app repo adopts the deployment CI, or before `gphin-plus` does.
- **Adoption status (verified 2026-09-04):** `gphin/mass-gathering-report-web` has already installed these workflows. `gphin/gphin-plus` has not — it has no `.github/workflows` at all.

`gphin-plus-launchpad/templates/install-deployment-ci/` predates the promotion
design and disagrees with it:

- Builds are local and per-environment; there is no promotion. `:pr-<N>` is a
  mutable tag, and production consumes a separately built `:<semver>` image.
- `build-push.sh.tmpl` satisfies none of the old Article VIII mitigations
  (clean tree, pinned digests, SHA tag) — the exception was invoked, never
  implemented.
- `APP_VERSION` is baked in as a build argument, which makes build-once
  impossible.
- No staging tier exists in `tofu/environments/` (`bootstrap` and `prod` only).
- No approval gate: `release: published` deploys straight to production.
- Plain rolling update; no canary, though Article XIX requires one.
- **The template copies secrets out of the production namespace into every per-PR
  namespace** — `alpha-deploy.yml.tmpl`, step "Copy app secrets from prod
  namespace" — so a preview environment would receive production credentials, a
  least-privilege violation under `defense-in-depth-security`. **Verified
  2026-09-04:** the one repo that has adopted these workflows,
  `mass-gathering-report-web`, does NOT carry that step; its copy requires the
  secret to be seeded into the namespace beforehand and fails if it is absent.
  This is therefore a latent defect in the template that takes effect on the next
  adoption, not a confirmed live exposure — and it is the most urgent item here.
  The check covered those two repositories only.

---

## `ship-it` Phase 5 pushes to `main`, which its own rules forbid

- **Status:** `open`
- **Raised:** 2026-09-06
- **Trigger:** next time `ship-it` runs its post-merge archival, i.e. the next
  spec/plan that reaches merge.

Phase 5 step 4 instructs `git add docs/superpowers/ && git commit && git push`
while the working tree is on `main` — Phase 6 has already run `git checkout
main`. That contradicts the skill's own Key Principle, *"Never push to main
directly — always branch + PR"*, and it cannot succeed in this repository at
all: ruleset `15161858` requires a pull request for `main`, so the push is
rejected.

Found by executing the skill: the 2026-09-04 deployment-cycle archival had to
branch and open PR #23 instead of following Phase 5 literally.

**What to decide when this is picked up:** whether Phase 5 gains its own
branch-and-PR steps, or whether archival is folded into the feature branch
before merge (which would contradict "archive after merge, never before"), or
whether Phases 5-6 are reordered so archival happens before the return to
`main`.

---

## Nothing checks that a new test assertion would fail without its change

- **Status:** `open`
- **Raised:** 2026-09-06
- **Trigger:** next plan that specifies test assertions, or next time
  `tests-as-a-control` is revised.

An assertion satisfied by text that already existed is decoration, not a
control: it passes before the change lands and would keep passing if the change
were reverted. Two such assertions were written into the 2026-09-04 deployment
cycle plan and shipped into `tests/test_skills.sh` before review caught them —
one matched a pre-existing sentence containing the word "enforced", the other a
pre-existing "content digest". Both were retargeted to strings unique to the new
content, and the fix was proved by deleting the guarded text and watching the
suite go red.

`tests-as-a-control` requires test-first but does not state the property that
makes test-first meaningful — that the test must be *observed* failing, and that
an assertion which never failed has not been shown to guard anything. The
plan-authoring side has the same gap: `superpowers:writing-plans`' self-review
checks placeholders, spec coverage and type consistency, but never asks whether
each specified assertion would fail if its change were absent.

**What to decide when this is picked up:** whether the rule belongs in
`tests-as-a-control` as a house rule about non-vacuous assertions (this repo can
change that), and separately whether to report the plan-authoring gap upstream
to the superpowers plugin (this repo must not vendor a copy of that skill — see
"What Belongs in This Repo" in README.md).
