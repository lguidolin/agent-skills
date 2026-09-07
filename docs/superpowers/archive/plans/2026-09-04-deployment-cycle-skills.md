# Deployment Cycle Skills — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write the `local dev → preview → staging → production` pipeline into the house skills as portable rules with swappable mechanisms, retiring the local-build exception and the ambiguous "alpha" tier.

**Architecture:** Three layers of specificity. Layer 1 (constitution, `resilience-and-deploy-safety`, `merge-gates-and-automation`) states properties and may not name a cloud, orchestrator, or plan tier. Layer 2 (`cloud-delivery-aks`) carries the Kubernetes mechanisms behind a stack trigger. Layer 3 (the launchpad cycle skill) is a separate plan in a separate repo. Each prose change is locked in by an assertion in `tests/test_skills.sh` first, so the rule is enforced rather than merely written.

**Tech Stack:** Markdown skills, Bash test suite (`tests/run.sh`, `tests/lib/assert.sh`), conventional commits, release-please.

**Spec:** `docs/superpowers/specs/2026-09-04-deployment-cycle-design.md`

## Global Constraints

- Tier names are exactly `local dev`, `preview`, `staging`, `production`. The word `alpha` must not appear in `skills/` at all.
- No Layer 1 rule may name Azure, Kubernetes, GitHub, or a pricing tier. Mechanisms belong in `cloud-delivery-aks`.
- The artifact's identity is its **content digest**. Tags are mutable pointers and are never the unit of promotion.
- Skill frontmatter rules are enforced by the suite: `name:` must equal the directory name, `description:` must start with "Use when".
- Every skill keeps its `Full rationale:` footer citing `engineering-constitution/references/engineering-constitution.md`.
- Run `./tests/run.sh` before every commit. A red suite never becomes a commit.
- **Line numbers cited below are from the files as they stand before Task 1.** Earlier edits shift them. Match on the quoted text, never on the line number.
- Commit messages: conventional commits, no AI attribution of any kind.

---

### Task 1: Retire the "alpha" tier name

**Files:**
- Modify: `tests/test_skills.sh` (append before `report_results`)
- Modify: `skills/resilience-and-deploy-safety/SKILL.md:14`
- Modify: `skills/cloud-delivery-aks/SKILL.md:15-16`
- Modify: `skills/zero-downtime-migrations/SKILL.md:20`
- Modify: `skills/engineering-constitution/references/engineering-constitution.md:217,321,359,360`

**Interfaces:**
- Produces: the vocabulary every later task uses — `preview` (ephemeral, per-PR), `staging` (persistent, receives every merge to main), `production`.

- [ ] **Step 1: Write the failing assertion**

Append to `tests/test_skills.sh`, immediately before the final `report_results` line:

```bash
# Tier names are preview → staging → production. "Alpha" was ambiguous — a
# persistent tier in Article XIX, an ephemeral per-PR namespace in the
# launchpad templates — and is retired.
stale_alpha=$(grep -rln '\balpha\b' "$POOL" --include='*.md' || true)
if [[ -z "$stale_alpha" ]]; then
  _pass
else
  _fail "skills use the retired tier name 'alpha'" "$(echo "$stale_alpha" | tr '\n' ' ')"
fi
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./tests/run.sh`
Expected: FAIL — `skills use the retired tier name 'alpha'`, listing four files.

- [ ] **Step 3: Rename in `resilience-and-deploy-safety/SKILL.md`**

Replace line 14 in full:

```markdown
- **The artifact is immutable and promoted, not rebuilt.** One image, built once, tagged by commit SHA, moves dev → alpha → prod unchanged. Rebuilding per environment means deploying something you never tested.
```

with:

```markdown
- **The artifact is immutable and promoted, not rebuilt.** One image, built once in CI and identified by its **content digest**, moves preview → staging → production unchanged. Rebuilding per environment means deploying something you never tested.
```

- [ ] **Step 4: Rename in `cloud-delivery-aks/SKILL.md`**

Replace lines 15-16 in full:

```markdown
- **Images build locally → GHCR, tagged by commit SHA** (the deliberate CI exception from `merge-gates-and-automation`), then **promoted unchanged** dev → alpha → prod. Never rebuilt per environment.
- **Per-PR ephemeral alpha environments.** Each PR deploys to its own isolated namespace on AKS for review, **torn down on merge/close.** The integration-test bed; cheap to create and destroy.
```

with:

```markdown
- **Images build in CI → GHCR, identified by content digest**, then **promoted unchanged** preview → staging → production. Never rebuilt per environment.
- **Per-PR ephemeral preview environments.** Each PR deploys to its own isolated namespace on AKS for review, **torn down on merge/close.** The integration-test bed; cheap to create and destroy.
```

- [ ] **Step 5: Rename in `zero-downtime-migrations/SKILL.md`**

Replace on line 20: `(alpha-with-data, production)` → `(staging-with-data, production)`

- [ ] **Step 6: Rename in the constitution reference**

Line 217 — replace in full:

```markdown
- **The artifact is immutable and promoted, not rebuilt.** One image, built once, tagged by commit SHA, moves dev → alpha → prod unchanged. Rebuilding per environment means you deploy something you never tested.
```

with:

```markdown
- **The artifact is immutable and promoted, not rebuilt.** One image, built once in CI and identified by its **content digest**, moves preview → staging → production unchanged. Tags are mutable pointers; the digest is the artifact's identity and the unit of promotion. Rebuilding per environment means you deploy something you never tested.
- **The running version comes from the environment, not from the build.** Baking a version into the image forces a rebuild to stamp a release, which destroys build-once. Inject it at deploy time.
```

Line 321 — replace `(alpha-with-data and production)` with `(staging-with-data and production)`.

Lines 359-360 — replace in full:

```markdown
- **Images build locally → GHCR, tagged by commit SHA** (the Article VIII exception), then **promoted unchanged** dev → alpha → prod. Never rebuilt per environment.
- **Per-PR ephemeral alpha environments.** Each PR deploys to its own isolated namespace (or equivalent) on AKS for review, and is **torn down on merge/close**. This is the integration-test bed; it must be cheap to create and destroy.
```

with:

```markdown
- **Images build in CI → GHCR and are promoted by digest** (Article VIII), moving preview → staging → production unchanged. Never rebuilt per environment.
- **Per-PR ephemeral preview environments.** Each PR deploys to its own isolated namespace (or equivalent) on AKS for review, and is **torn down on merge/close**. This is the integration-test bed; it must be cheap to create and destroy.
- **A persistent staging tier receives every merge to main**, so staging always reflects main's tip and cannot drift from it. Production promotes the digest staging validated, after a human decision.
```

- [ ] **Step 7: Run the suite to verify it passes**

Run: `./tests/run.sh`
Expected: PASS, one more assertion than before.

- [ ] **Step 8: Commit**

```bash
git add tests/test_skills.sh skills/
git commit -m "refactor!: rename the alpha tier to preview

'Alpha' named two different things: a persistent tier in Article XIX and
an ephemeral per-PR namespace in the launchpad templates. Tiers are now
local dev -> preview -> staging -> production, with staging introduced as
the persistent tier that receives every merge to main.

A test assertion holds the vocabulary in place."
```

---

### Task 2: Retire the local-build exception (Article VIII)

**Files:**
- Modify: `tests/test_skills.sh`
- Modify: `skills/engineering-constitution/references/engineering-constitution.md:157,159,161`

**Interfaces:**
- Consumes: tier vocabulary from Task 1.
- Produces: the CI-builds rule that `merge-gates-and-automation` (Task 3) and `cloud-delivery-aks` (Task 5) both cite.

- [ ] **Step 1: Write the failing assertion**

Append to `tests/test_skills.sh` before `report_results`:

```bash
CONST="$POOL/engineering-constitution/references/engineering-constitution.md"
assert_file_contains "$CONST" "Container images build in CI"
assert_file_contains "$CONST" "Enforcement mode is declared, never assumed"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./tests/run.sh`
Expected: FAIL — `does not contain: Container images build in CI`.

> The repo-wide "no local builds" check lands in Task 3, once the last
> occurrence (in `merge-gates-and-automation`) has also been removed. Adding it
> here would leave the suite red at this task's commit.

- [ ] **Step 3: Replace the exception bullet**

Line 157 — replace the whole bullet beginning `- **The one deliberate exception:` with:

```markdown
- **Container images build in CI, never on a developer machine.** The shipped artifact's provenance is a hermetic runner, which is what makes build attestation meaningful. Two conditions keep this honest and affordable: **registry layer caching** (`cache-to`/`cache-from`, or a self-hosted runner) so build latency never pushes anyone back to a laptop build, and a **published provenance attestation** for every image. Images are identified by **content digest**; tags are mutable pointers and are never the unit of promotion.
- **Enforcement mode is declared, never assumed.** An unbypassable gate requires branch protection, which is not available on every plan — it is free on public repositories and paid on private ones. A project therefore declares its mode in its first decision record: **`enforced`** (CI blocks merge via rulesets; what CI says is what counts) or **`advisory`** (CI runs and reports; the gate is discipline). Advisory is legitimate for a solo or pre-launch project. Presenting advisory as enforced is not. State what would move the project to enforced.
```

- [ ] **Step 4: Rewrite the Named tension paragraph**

Line 159 — replace in full:

```markdown
> **Named tension, eyes open.** A bypassable local presubmit is fast but unenforceable; an authoritative CI is enforceable but slower. We resolve it by giving each a *different mandate* — the hook optimizes for the inner loop, CI for correctness of record — and by making CI, not the hook, the thing that can block a merge. The local image build is the single conscious crack in the "CI is the source of truth" wall, accepted for latency and fenced with provenance mitigations.
```

with:

```markdown
> **Named tension, eyes open.** A bypassable local presubmit is fast but unenforceable; an authoritative CI is enforceable but slower. We resolve it by giving each a *different mandate* — the hook optimizes for the inner loop, CI for correctness of record — and by making CI, not the hook, the thing that can block a merge. The image build was once the conscious crack in that wall, carved out for latency; it has been closed. We pay the latency and buy it back with a layer cache, because an artifact built on a laptop cannot carry provenance anyone else can verify.
```

- [ ] **Step 5: Update the Article VIII enforcement line**

Line 161 — replace in full:

```markdown
**Enforcement:** the CI pipeline definition itself (branch protection requiring CI to pass before merge); the task runner (e.g. `just`) as the recipe registry.
```

with:

```markdown
**Enforcement:** the CI pipeline definition itself (branch protection requiring CI to pass before merge, where the plan permits it — otherwise the declared advisory mode); the task runner (e.g. `just`) as the recipe registry.
```

- [ ] **Step 6: Update the Article XIX CI line**

Replace the bullet beginning `- **CI is the gate (Article VIII):**` with:

```markdown
- **CI is the gate (Article VIII):** lint, typecheck, contract checks, tests, and security scans block merge. CI also **builds the image and publishes its provenance attestation**.
```

- [ ] **Step 7: Run the suite to verify it passes**

Run: `./tests/run.sh`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add tests/test_skills.sh skills/
git commit -m "feat!: build images in CI and declare enforcement mode

Retires the Article VIII local-build exception. Provenance on a developer
machine cannot be verified by anyone else, and SLSA build attestation is
unreachable from a laptop. Conditional on layer caching so latency does
not push the build back off CI.

Adds declared enforcement modes. Branch protection is not available on
every plan, so a project states whether its gate is enforced or advisory
rather than silently implying enforcement it does not have."
```

---

### Task 3: Enforcement modes and exception removal in `merge-gates-and-automation`

**Files:**
- Modify: `tests/test_skills.sh`
- Modify: `skills/merge-gates-and-automation/SKILL.md:18,31,38`

**Interfaces:**
- Consumes: the CI-builds rule and enforcement-mode definitions from Task 2.

- [ ] **Step 1: Write the failing assertion**

Append to `tests/test_skills.sh` before `report_results`:

```bash
assert_file_contains "$POOL/merge-gates-and-automation/SKILL.md" "advisory"
assert_file_contains "$POOL/merge-gates-and-automation/SKILL.md" "enforced"

# The Article VIII local-build exception is retired everywhere: images build in CI.
local_build=$(grep -rln 'build locally' "$POOL" --include='*.md' || true)
if [[ -z "$local_build" ]]; then
  _pass
else
  _fail "skills still describe local image builds" "$(echo "$local_build" | tr '\n' ' ')"
fi
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./tests/run.sh`
Expected: FAIL — `does not contain: advisory`.

- [ ] **Step 3: Replace the exception bullet**

Line 18 — replace in full:

```markdown
- **One deliberate exception: container images build locally and push to the registry, not in CI** — when CI image-build latency is unacceptable. This is a **known, accepted trade-off**, not an ideal: the artifact's provenance is a developer machine. Mitigate — build only from clean git state at a tagged SHA, pin toolchain and base-image digests, tag the image with the SHA.
```

with:

```markdown
- **Container images build in CI**, identified by content digest and published with a provenance attestation. Keep it affordable with registry layer caching or a self-hosted runner — never by moving the build back to a laptop, where the artifact's provenance cannot be verified by anyone else.
- **Declare the enforcement mode.** `enforced` — CI blocks merge via branch protection; what CI says is what counts. `advisory` — CI runs and reports, and the gate is discipline, because branch protection is unavailable (a private repository on a free plan). Advisory is legitimate; claiming enforcement you do not have is not. State the mode in the project's first decision record, and what would move it to enforced.
```

- [ ] **Step 4: Replace the Common Rationalizations row**

Line 31 — replace in full:

```markdown
| "Let's build the prod image in CI for purity" | Allowed, but latency may justify the local-build exception. If local, pin SHAs/digests and accept the provenance trade-off consciously. |
```

with:

```markdown
| "CI builds are slow, I'll build the image locally" | A laptop-built artifact carries provenance no one else can verify. Fix the latency with a layer cache or a self-hosted runner. |
| "Branch protection costs money, so the rules don't apply" | The rules apply; the *enforcement* differs. Declare advisory mode and keep the discipline, or make the repository public and get protection free. |
```

- [ ] **Step 5: Replace the Red Flag line**

Line 38 — replace `- A locally-built image with no SHA tag or pinned digests` with:

```markdown
- An image built anywhere but CI, or promoted by tag rather than by digest
- A project behaving as though CI gates merge when no branch protection exists
```

- [ ] **Step 6: Run the suite to verify it passes**

Run: `./tests/run.sh`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add tests/test_skills.sh skills/merge-gates-and-automation/SKILL.md
git commit -m "feat!: replace the local-build exception with enforcement modes

Aligns the skill with the amended Article VIII and adds the enforced vs
advisory distinction so a free-plan private repository states what its
gate actually guarantees."
```

---

### Task 4: The promotion property in `resilience-and-deploy-safety`

**Files:**
- Modify: `tests/test_skills.sh`
- Modify: `skills/resilience-and-deploy-safety/SKILL.md` (Deploy Safety section, Quick Reference table, When to scale this)

**Interfaces:**
- Consumes: tier vocabulary (Task 1), digest identity (Task 2).
- Produces: the Layer 1 promotion property that `cloud-delivery-aks` (Task 5) implements.

- [ ] **Step 1: Write the failing assertion**

Append to `tests/test_skills.sh` before `report_results`:

```bash
assert_file_contains "$POOL/resilience-and-deploy-safety/SKILL.md" "digest"
assert_file_contains "$POOL/resilience-and-deploy-safety/SKILL.md" "A human decision precedes production"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./tests/run.sh`
Expected: FAIL — `does not contain: A human decision precedes production`.

- [ ] **Step 3: Add the promotion property**

Immediately after the (already renamed) immutable-artifact bullet in the "Deploy Safety" section, insert:

```markdown
- **Promotion moves a digest; it never rebuilds.** Tags are mutable pointers and can be overwritten. A content digest cannot. Each environment records the digest it validated, and **production runs only a digest a lower environment validated** — so "the exact thing we tested" is a property the pipeline enforces, not a discipline someone has to remember.
- **A human decision precedes production.** For a solo maintainer this is a deliberate pause and an audit record rather than separation of duties. Say which it is; do not oversell it.
- **The running version is injected at deploy time, never baked into the image.** A version baked as a build argument forces a rebuild to stamp a release, and the rebuild is exactly what promotion exists to avoid.
```

- [ ] **Step 4: Add the two-repo coordination rule**

Append to the "Deploy Safety" section, after the version-injection bullet:

```markdown
- **When infrastructure lives in its own repository, coordinate by expand/contract.** Infrastructure **expands** first (additive, backward-compatible), the application consumes the new capability in a later deploy, and infrastructure **contracts** only once no live artifact depends on the old shape — the same discipline as a schema change (see `zero-downtime-migrations`). The invariant: **never ship an application artifact that requires an infrastructure change not yet live.** Held to that, each repository is independently reversible, which is what makes rollback tractable when the two are out of step.
```

- [ ] **Step 5: Extend the Quick Reference table**

Replace the `| Artifact |` row with:

```markdown
| Artifact | Built once in CI; promoted by digest; the same one staging validated |
| Gate | A human decision recorded before production |
```

- [ ] **Step 6: Rewrite "When to scale this"**

Replace that section's body in full with:

```markdown
Local/pre-launch projects write these rules now, activate on first real users. The properties are portable — build once, promote what you tested, decide before production, be able to roll back — but the mechanisms are not: a digest promotion is meaningful on a container host and largely moot for a static site, and a managed platform may supply preview environments and instant rollback for free. Name the mechanism in the project's delivery skill; keep the property here. Stack mechanisms (k8s probes, canary, per-PR envs): `cloud-delivery-aks`.
```

- [ ] **Step 7: Run the suite to verify it passes**

Run: `./tests/run.sh`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add tests/test_skills.sh skills/resilience-and-deploy-safety/SKILL.md
git commit -m "feat: state promotion by digest as a portable deploy property

Separates the property (build once, promote what you tested, decide
before production) from the mechanism, so the same rule holds on AKS, a
VPS, or a managed platform."
```

---

### Task 5: The tier table and retag mechanics in `cloud-delivery-aks`

**Files:**
- Modify: `tests/test_skills.sh`
- Modify: `skills/cloud-delivery-aks/SKILL.md` (Delivery Rules, new Pipeline section, Quick Reference)

**Interfaces:**
- Consumes: the promotion property (Task 4), digest identity (Task 2), tier names (Task 1).

- [ ] **Step 1: Write the failing assertion**

Append to `tests/test_skills.sh` before `report_results`:

```bash
assert_file_contains "$POOL/cloud-delivery-aks/SKILL.md" "imagetools create"
assert_file_contains "$POOL/cloud-delivery-aks/SKILL.md" "workflow_dispatch"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./tests/run.sh`
Expected: FAIL — `does not contain: imagetools create`.

- [ ] **Step 3: Add the pipeline section**

Insert a new `## The Pipeline` section immediately after `## Delivery Rules`:

````markdown
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
````

- [ ] **Step 4: Extend the Quick Reference table**

Add these rows:

```markdown
| Promotion | Retag the digest; never rebuild per environment |
| Approval | Environment reviewers (enforced) or manual dispatch (advisory) |
```

- [ ] **Step 5: Run the suite to verify it passes**

Run: `./tests/run.sh`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add tests/test_skills.sh skills/cloud-delivery-aks/SKILL.md
git commit -m "feat: document the preview to production promotion path on AKS

Adds the tier table, the digest retag mechanics with its tree-equality
guard, and both approval-gate mechanisms."
```

---

### Task 6: `ship-it` stops at the preview

**Files:**
- Modify: `tests/test_skills.sh`
- Modify: `skills/ship-it/SKILL.md` (Phase 3, Key Principles)

**Interfaces:**
- Consumes: tier names (Task 1).

- [ ] **Step 1: Write the failing assertion**

Append to `tests/test_skills.sh` before `report_results`:

```bash
assert_file_contains "$POOL/ship-it/SKILL.md" "Shipping ends at the preview"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./tests/run.sh`
Expected: FAIL — `does not contain: Shipping ends at the preview`.

- [ ] **Step 3: Add preview verification to Phase 3**

Append to the end of the `### Phase 3: Open PR` section, after the `gh pr create` block and the `gh` fallback line:

````markdown
**Verify the preview environment came up.** If the project deploys per-PR
previews, wait for that workflow and confirm the environment is reachable
before handing the PR over:

```bash
gh pr checks --watch
```

If the preview fails to deploy, report it and stop. A PR nobody can review is
not shipped.

**Where this skill stops.** `ship-it` ends its deployment awareness at the
preview. Staging and production promotion are not its job — they belong to the
project's delivery skill (`cloud-delivery-aks`, or its equivalent). Phases 4-6
below are git and documentation hygiene, not deployment.
````

- [ ] **Step 4: Add the Key Principles line**

Add to the `## Key Principles` list, after the "Never push to main directly" entry:

```markdown
- **Shipping ends at the preview** — merge, archival, and cleanup are hygiene; promotion to staging and production is a separate skill's job
```

- [ ] **Step 5: Run the suite to verify it passes**

Run: `./tests/run.sh`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add tests/test_skills.sh skills/ship-it/SKILL.md
git commit -m "feat(ship-it): verify the preview and stop there

ship-it now confirms the per-PR preview came up before handing over the
PR, and states explicitly that staging and production promotion are not
its concern."
```

---

### Task 7: Close and reopen the future considerations

**Files:**
- Modify: `docs/superpowers/future-considerations.md`

**Interfaces:**
- Consumes: everything above; this records what was deliberately not done.

- [ ] **Step 1: Mark the deploy entry done**

In the `## Deploy pipeline: staging promotion and infra-repo coordination` entry, change `- **Status:** \`open\`` to `- **Status:** \`done\`` and append this line to the entry:

```markdown
- **Resolved:** 2026-09-04 by the deployment cycle design; see the decision record. Layer 3 (the launchpad cycle skill) and the template remediation below remain.
```

- [ ] **Step 2: Add the scale-down audit entry**

Append a new section:

```markdown
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
```

- [ ] **Step 3: Add the launchpad remediation entry**

Append a second new section:

```markdown
## Launchpad deployment templates contradict the promotion design

- **Status:** `open`
- **Raised:** 2026-09-04
- **Trigger:** before `gphin-plus` (or any app repo) adopts the deployment CI.

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
- **Preview namespaces copy secrets out of the production namespace**, so every
  PR environment receives production credentials — a least-privilege violation
  under `defense-in-depth-security`, and the most urgent item here.
```

- [ ] **Step 4: Run the suite**

Run: `./tests/run.sh`
Expected: PASS (unchanged count — this task touches no skill).

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/future-considerations.md
git commit -m "docs: close the deploy pipeline entry and record the follow-ons

Records the collection-wide scale-down gap and the launchpad template
deviations, including preview namespaces receiving production secrets."
```

---

## Follow-on plan (not this plan)

**Plan B — `gphin-plus-launchpad`:** author the `gphin-plus-deployment-cycle` skill (thin `SKILL.md` pointer plus `procedure-sha256` guard over a canonical `CYCLE.md`), sibling to `install-gphin-plus-deployment-ci`. It cites the house rules landed here rather than restating them, and carries the Known Deviations list from Task 7 Step 3. It belongs in that repo, needs its own PR, and depends on this plan being merged first.
