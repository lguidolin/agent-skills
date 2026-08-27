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

- **Status:** `open`
- **Raised:** 2026-08-27
- **Trigger:** next substantive change to the deploy path, or the next release
  that needs a staging soak.

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
