# The Engineering Constitution

*A portable charter of working practices and stack laws, written to be handed to an AI agent (or human) starting a new project. It encodes how we work, why we work that way, how we operate what we ship, and how to adapt when the project differs.*

> **How to read this document.** Tier 1 is universal and travels to every project unchanged. Tier 2 is a *map* of the mechanism layer: each of its articles names the Tier 1 principle it implements and the stack skill that owns the mechanism. Which stack a project actually uses is declared in that project's first decision record (Article XX) — never assumed here. Every article carries an **Enforcement** line naming the tooling that makes it real — or labeling it honestly as reviewer judgment. Where an article only applies at a certain scale or lifecycle stage, an **Applies when** line says so.

---

## Preamble — Inviolable Principles

Everything in this document derives from eight principles. When a specific article is silent or ambiguous, reason from these.

1. **Understand before building.** No code is written before a design is articulated and approved. The simplest task is where unexamined assumptions cost the most.
2. **Record every decision with its rationale — and what you rejected.** A decision without its *why* is a landmine for the next person. A decision without its *rejected alternatives* invites relitigating settled questions.
3. **Tests are a control, not a formality — and behavioral change is test-first.** A test encodes an expectation. A failing test is information to be understood and explicitly accepted — never silently edited away. Behavioral change begins with a test that fails for the right reason; structural change is gated instead by the existing suite passing unedited.
4. **YAGNI, ruthlessly.** Build what is needed now. Anticipated needs are guesses; guesses become dead weight.
5. **Automate the repeatable.** Anything done by hand more than twice becomes a recipe. A task that lives only in someone's memory does not reliably happen.
6. **Software engineering is programming integrated over time.** The cost of a system is dominated by what happens *after* the first commit: operating it, changing it safely, and recovering when it breaks. Optimize for the long-lived system, not the first deploy.
7. **A rule not enforced is a suggestion.** Bind every rule to tooling that checks it, or label it explicitly as reviewer judgment. Never let aspiration masquerade as enforced law. Mechanism beats memo.
8. **The user's explicit instructions outrank this document.** This constitution overrides default behavior and habit. It does not override a direct human instruction. Precedence is always: **User instructions → this Constitution → tool defaults.**

---

# TIER 1 — CORE

*Universal discipline. These articles apply to every project regardless of language, framework, or domain. Part A is how you **build**; Part B is how you **operate what you build over time**.*

## Part A — Building Discipline

## Article I — The Development Pipeline

Work flows through five stages, in order: **Brainstorm → Spec → Plan → Execute → Record.**

- **Brainstorm.** Explore intent, constraints, and success criteria before proposing solutions. Ask one question at a time. Propose two or three approaches with trade-offs and a recommendation. Converge on a design and get explicit approval. *No implementation begins here.*
- **Spec.** Write the approved design to a dated document. The spec is the contract for what will be built.
- **Plan.** Decompose the spec into an ordered, reviewable implementation plan before touching code.
- **Execute.** Implement against the plan, with review checkpoints.
- **Record.** Distill what was built and *why* into a permanent decision record (Article II).

**Decompose large efforts.** If a request spans multiple independent subsystems, stop and decompose it before refining details. Each sub-project runs its own Brainstorm→Record cycle, built in dependency order.

> **Why.** The stages separate *deciding what to build* from *building it*. Conflating them is the most common source of wasted work: code written before the design is settled is code rewritten.

**Enforcement:** process (human discipline); the spec and plan documents are the reviewable artifacts.

## Article II — The Record System

Decisions are durable infrastructure. Memory and chat history are not.

**Every non-trivial decision produces a record** with a fixed shape, so any reader knows where to look:

- **Architecture** — the shape of the solution and the key files.
- **Data Model** — entities, fields, relationships.
- **Decisions (with WHY)** — each choice paired with its rationale. The *why* is mandatory.
- **Interfaces** — how other code uses this.
- **Constraints** — what must remain true.
- **Gotchas** — the non-obvious traps for the next person.
- **Rejected Alternatives** — what was considered and discarded, *and why.* This prevents relitigating settled questions.

**Maintain three companion artifacts:**

- **An index** of all decisions with explicit **dependency tracking** (which decision builds on which) and a **superseded** section.
- **A "Future Considerations" doc** — deferred ideas and known concerns, consulted when starting new work so nothing is silently forgotten. **Incident action items and deferred-with-trigger decisions land here** (Articles XII, XX).
- **An archive** — when a decision is superseded, it moves to the archive rather than being deleted. History is preserved, not overwritten.

> **Why.** The cost of a decision record is paid once; the cost of a *lost* decision is paid every time someone reverse-engineers intent from code. Dependency tracking turns a pile of decisions into a navigable graph.

**Enforcement:** process (human discipline); records are reviewed as part of the change that creates them.

## Article III — Commits & Releases

Commit messages are a machine-read interface, not just prose.

- **Conventional Commits are mandatory** — `<type>(<scope>): <description>`. Automated versioning and changelog generation parse these; a malformed message breaks the release pipeline.
- **Types** carry semantic weight: `feat` (minor bump), `fix` (patch), plus `docs`, `chore`, `refactor`, `test`, `ci`, `build`. **Breaking changes** are marked with `!` or a `BREAKING CHANGE:` footer.
- **Imperative mood** — "add X," not "added X." Scope is optional but encouraged.
- **Human-authored voice.** No attribution to AI tools or assistants. No `Co-authored-by` or generated-by trailers. Commits read as a human wrote them.
- **Releases are automated** from commit history. Humans write good commits; the tooling writes the changelog and picks the version.
- **The type↔version link is load-bearing, so guard it.** A mistyped `feat` vs `fix` produces a wrong public version. When the team squash-merges, the **PR title** is the commit that ships — it must itself be a valid Conventional Commit.

> **Why.** When commit messages drive automation, discipline in the small (one well-formed message) produces correctness in the large (an accurate changelog and a correct version bump) for free.

**Enforcement:** `commitlint` in CI (blocking) on commit messages and on squash PR titles; release tooling (e.g. release-please) in CI.

## Article IV — Tests as a Control

A test is a control specimen: it holds an expectation fixed so that any change in behavior is *visible*.

- **Behavioral change is test-first.** Write the failing test, watch it fail *for the right reason*, then write the minimal code that passes. Code written before its test was never specified by one — it was merely accompanied by one written to fit. If you did not watch the test fail, you do not know what it tests.
- **Structural change is verified by the unchanged suite.** A pure structural change — rename, move, split, extract, with no observable behavior change — requires no new test. Its gate is the inverse: the entire existing suite passes **with no test edited**. Test-first does not apply, because there is no behavior to specify and therefore no test that could meaningfully fail first. A structural change that forces a test edit was not structural.
- **A rename that crosses a contract boundary is not a refactor.** The test is not "did the code change behavior?" but "is this name observable to something I do not control?" An internal symbol is structural. An exported function, API or GraphQL field, route, CLI flag, database column, event name, or config key is **behavioral** — the name *was* the contract (Article XI, Hyrum's Law), and renaming it breaks consumers even though the code does the same thing to the same data. Such a rename follows add-and-deprecate under test-first, not the structural gate.
- **Refactors must not edit tests; requirement changes must.** These are different acts. If a *refactor* breaks a test, the test has caught an unintended behavior change — stop and understand it. If a *requirement* genuinely changed, update the test **deliberately, as its own reviewable change**, recorded as such. The forbidden move is editing a test to make a refactor pass; the required move is updating a test when the spec moves. Never silently re-baseline.
- **Symmetric coverage — every behavioral rule is tested in both directions.** Prove the authorized actor **can**, *and* the unauthorized actor **cannot**. Testing only the happy path tests half a rule.
- **Permission and role rules are tested as a matrix** — every meaningful (role × action × resource) cell, both **allow** and **deny**. A new role or permission is incomplete until its **deny** cases exist. A deny test that suddenly passes-through (the forbidden action now succeeds) is a security regression to review and accept explicitly.
- **Entry points are never added or removed silently.** Routes, commands, public endpoints — each has at least existence-and-smoke coverage, so adding or removing one *forces* a corresponding test change (mechanism in Article XV).
- **Test by size, and mind the middle.** Classify tests as **small** (no I/O, pure logic, run constantly), **medium** (integration against a real DB/process, hermetic), or **large** (end-to-end through the full stack). Favor many small, fewer medium, fewest large (the pyramid). Watch for the **missing middle** — application/server logic that has neither unit nor integration coverage because the DB layer and the UI layer each assume the other tests it.
- **Flaky tests are quarantined on sight.** A test that passes and fails without a code change destroys trust in the entire suite. Quarantine it immediately (move it out of the blocking gate, file a fix task) — do not leave it failing intermittently and do not delete it silently. Small tests must be deterministic: no real clock, no randomness, no network, seeded data only.
- **Test code is DAMP, not DRY.** *Descriptive And Meaningful Phrases* over de-duplication. A test must be obvious read in isolation; tolerate duplication that a production-code reviewer would refactor away. (This is the deliberate exception to Article VI — see the named tension there.)

> **Why.** The discipline is *don't fix the test to match the code; understand why they disagree.* A negative test is as load-bearing as a positive one — it's often the only thing standing between you and a security regression. And a control you can't read, or can't trust, isn't a control.

**Enforcement:** CI (blocking) runs the suite; flaky-quarantine and size-tiering are reviewer judgment backed by CI timing reports.

## Article V — Change Hygiene

- **Structural changes before behavioral changes,** validated independently. Reorganizing (splitting files, renaming, adding comments) is a separate, independently-checkable step from changing behavior (new constraints, altered logic). Never mix them in one indivisible change.
- **One concern per change.** A change should have a single, statable purpose.
- **Improve the code you're working in** when its problems affect your task — the way a careful developer leaves a campsite cleaner. **Do not** embark on unrelated refactoring; stay focused on the goal.

> **Why.** When structure and behavior change together, a reviewer cannot tell which diff lines are safe reshuffling and which are real logic changes. Separating them makes both reviewable.

**Enforcement:** reviewer judgment (aspirational); supported by small, single-purpose PRs.

## Article VI — Code Craft

- **Explicit over implicit.** No wildcards where names belong, no implicit casts, no empty-string or magic sentinels. Say what you mean.
- **Descriptive names.** Functions and variables describe what they do. Follow the idioms of the language and ecosystem.
- **Comment intent, not mechanics.** Explain *why* when it isn't obvious; skip comments on self-evident code.
- **Small, single-purpose units.** For any unit you should be able to say what it does, how to use it, and what it depends on — without reading its internals. A file that has grown large is usually doing too much.
- **DRY in production code, with judgment.** Duplication is a *signal*, not an automatic error. The **second** near-identical occurrence triggers a deliberate decision: abstract it, or record why not. Abstract shared **meaning**, never coincidental shape — two things that look alike today but change for different reasons should stay apart.
- **Follow ecosystem standards.** Use the established idioms, conventions, and well-supported libraries a competent practitioner would expect. Don't reinvent what the platform or community already solved well.

> **Named tension: DRY vs. premature abstraction, and DRY vs. DAMP.** Resolution — *production* code abstracts on **demonstrated repetition of intent**, not anticipated repetition of shape; YAGNI governs the tie-break (when unsure, wait for the third occurrence). *Test* code (Article IV) deliberately relaxes DRY in favor of in-place clarity. Applying DRY to tests is a constitution violation, not a virtue.

**Enforcement:** linter + formatter in CI (blocking) for the mechanical rules (e.g. ESLint, Prettier, no-wildcard, naming); DRY/abstraction calls are reviewer judgment.

## Article VII — Interface Craft (UX & Accessibility)

The standard is **accessible, minimalist, and beautiful — by construction, not by polish.** Taste is real but unactionable as a rule, so it is converted here into constraints, precedent, and escalation.

**Accessibility is a requirement, not a finishing pass.** Checkable rules:

- Every interactive element is keyboard-reachable and has a visible focus state.
- Every control has an accessible name; every form field has an associated label and clear error messaging.
- Semantic structure and landmarks over undifferentiated containers.
- Color contrast meets at least WCAG AA; meaning is **never** conveyed by color alone.
- Honor reduced-motion preferences.

**Beautiful and minimalist, expressed as constraints rather than vibes:**

- **Consistency through constraint.** Use the design system's tokens — spacing, type scale, color scale. No one-off magic numbers. Coherence *is* the aesthetic.
- **Existing screens are the style guide.** Match the established visual language before inventing a new one.
- **Restraint (UI-YAGNI).** Every element earns its place; remove until removing would break something. Prefer hierarchy and whitespace over density and decoration.
- **Prefer the component library's patterns** before building custom UI.
- **Two similar UI elements → one parameterized component.** Express the differences as props or variants, never as copy-paste. A third copy is a defect. (This is Article VI's DRY, applied to the interface.)

> **The escalation rule** — *taste decisions escalate; they are never freelanced.* When a choice is genuinely aesthetic and **underdetermined by tokens or precedent**, do not silently guess. Follow the nearest existing precedent, or surface options (mockups, side-by-side comparisons) for a human taste call. The agent is not asked to invent taste, only to honor constraints and escalate the rest.

**Enforcement:** automated a11y linting/tests in CI (blocking) for the checkable rules (e.g. `eslint-plugin-jsx-a11y`, axe in component/route tests); aesthetic restraint and precedent-matching are reviewer judgment via the escalation rule.

## Article VIII — Automation & the Verification Gate

- **One task runner is the canonical entry to every everyday operation.** Running tests, building, starting local dev, deploying — each is a named recipe. The recipe is the source of truth; a procedure that exists only in someone's head does not reliably happen and cannot be handed to an agent.
- **CI is the source of truth — authoritative, shared, and unbypassable wherever the platform allows it.** It is the wall: lint, typecheck, the contract checks (Article XV), the test suite, security scans, and commit validation all run here and **must pass before merge** in `enforced` mode. What CI says is what counts. Where branch protection is unavailable the project declares `advisory` mode (below): the same checks run and report, and the wall is discipline rather than machinery. The checks never shrink; only their enforceability differs.
- **The pre-push hook is a presubmit mirror, not a wall.** It runs the same fast checks locally so you *probably* pass CI before you push — saving a round-trip. It is explicitly **bypassable** (`--no-verify`) and only runs where the toolchain is installed. We accept that; its job is speed and early feedback, not enforcement. CI re-runs everything regardless. **The hook never gates; CI gates wherever the platform allows it.**
- **Keep CI fast by tiering, not by removing checks.** While the full suite is fast, run it all on every PR. When it outgrows that, split **presubmit** (fast subset, blocks the PR) from **postsubmit** (full suite, runs after merge, blocks promotion) — never move authoritative checks back to the bypassable hook.
- **Container images build in CI, never on a developer machine.** The shipped artifact's provenance is a hermetic runner, which is what makes build attestation meaningful. Two conditions keep this honest and affordable: **registry layer caching** (`cache-to`/`cache-from`, or a self-hosted runner) so build latency never pushes anyone back to a laptop build, and a **published provenance attestation** for every image. Images are identified by **content digest**; tags are mutable pointers and are never the unit of promotion.
- **Enforcement mode is declared, never assumed.** An unbypassable gate requires branch protection, which is not available on every plan — it is free on public repositories and paid on private ones. A project therefore declares its mode in its first decision record: **`enforced`** (CI blocks merge via rulesets; what CI says is what counts) or **`advisory`** (CI runs and reports; the gate is discipline). Advisory is legitimate for a solo or pre-launch project. Presenting advisory as enforced is not. State what would move the project to enforced.

> **Named tension, eyes open.** A bypassable local presubmit is fast but unenforceable; an authoritative CI is enforceable but slower. We resolve it by giving each a *different mandate* — the hook optimizes for the inner loop, CI for correctness of record — and by making CI, not the hook, the thing that can block a merge. The image build was once the conscious crack in that wall, carved out for latency; it has been closed. We pay the latency and buy it back with a layer cache, because an artifact built on a laptop cannot carry provenance anyone else can verify.

**Enforcement:** the CI pipeline definition itself (branch protection requiring CI to pass before merge, where the plan permits it — otherwise the declared advisory mode); the task runner (e.g. `just`) as the recipe registry.

## Part B — Operating Discipline

*These articles state universal principles for running software over time (Preamble §6). The concrete mechanisms for this stack live in Tier 2. A project that does not run as a service — a pure library or CLI — applies these only where they make sense and records the omission.*

## Article IX — Observability & Operability

You cannot operate, debug, or improve what you cannot see. Observability is designed in, not bolted on after the first outage.

- **The three signals.** Emit **structured logs** (machine-parseable, not free text), **metrics** (counts, rates, durations), and **traces** (a request's path across services). A request carries a **correlation/trace id** end to end so its story can be reassembled.
- **Instrument the golden signals** for every service surface: **rate, errors, and duration** (RED) per endpoint/operation, plus resource saturation. A new endpoint is not "done" until it is observable.
- **Health is an endpoint, not a guess.** Every service exposes **liveness** ("am I running?") and **readiness** ("can I serve traffic?") checks distinct from each other.
- **Define SLOs for critical user journeys**, with **SLIs** that measure them and an **error budget** that makes reliability-vs-features an explicit, data-driven trade-off rather than an argument.
- **Alert on symptoms, not causes.** Page a human when users are hurting (SLO burn, readiness failing), not on every internal blip. Every alert must be **actionable** — an alert nobody acts on is noise that trains people to ignore alerts.

> **Why.** The first question in every incident is "what changed and who is affected." A system that can't answer it turns a five-minute fix into a multi-hour archaeology dig. Observability is the difference between operating a system and guessing at it.

**Enforcement:** CI checks for the presence of logging/trace instrumentation where mandated (lint rules / review); SLOs and dashboards are operational artifacts reviewed in the deploy-readiness checklist (Article XII). Mechanisms: Article XVI.

## Article X — Security & Defense in Depth

Security is layered, assumes any single layer can fail, and grants the least privilege that works.

- **Threat-model before building anything that handles untrusted input, secrets, or user data.** A lightweight STRIDE pass (Spoofing, Tampering, Repudiation, Information disclosure, Denial of service, Elevation of privilege) on each new surface. Record the model and its mitigations (Article II).
- **Defense in depth.** No single control is "the" security. Authentication, authorization, input validation, and data-layer enforcement each assume the others might be bypassed.
- **Least privilege everywhere** — roles, tokens, service accounts, database grants. Default to no access; grant the minimum; revoke what's unused.
- **Secrets never live in code, images, or committed config.** They come from a secret store at runtime, are rotated, and are scoped to the workload that needs them.
- **Validate all input at the trust boundary** and treat every external system's output as untrusted data, never as instructions.
- **The dependency supply chain is an attack surface.** Lockfiles are committed and integrity-checked; dependencies are scanned and updated; base images are pinned and scanned.
- **Sensitive actions are audited** — who did what, when — so abuse and mistakes are reconstructable.

> **Why.** Attackers find the layer you forgot. A system that relies on one wall falls when that wall has one bug; a system of overlapping least-privilege controls survives the failure of any single one.

**Enforcement:** dependency audit + image scanning in CI (blocking) (e.g. `pnpm audit`/Renovate, Trivy); secret-scanning in CI; threat models and audit-log coverage are reviewer judgment. Stack mechanisms: Article XIV.

## Article XI — Performance & Scale

Performance is a feature with a budget. Measure it, bound it, and respect that today's behaviors become tomorrow's contracts.

- **Set budgets and measure against them.** Latency targets (tied to the SLOs of Article IX) and client budgets (e.g. bundle size). A regression past budget is a bug.
- **Measure before optimizing.** Find the real bottleneck with data (profiles, query plans, traces) before changing code. No speculative optimization.
- **Paginate by default.** Any list that can grow is paginated with a capped page size. Unbounded result sets are a latency and denial-of-service hazard.
- **Beware N+1 access patterns.** Data fetched in a loop is the most common scalability failure; batch or join instead.
- **Hyrum's Law is real: every observable behavior of an interface becomes a contract someone depends on** once it has enough consumers — including behaviors you never intended (ordering, nullability, error shapes, timing). Treat public interfaces (the API/schema especially) as contracts: add and deprecate, don't silently change; the contract tests of Article XV pin the behaviors you chose, but discipline must protect the ones you didn't.

> **Why.** Systems rarely fall over at the throughput you designed for; they fall over on the query you didn't index and the list you didn't paginate. And at scale you don't get to choose which behaviors matter — your users already did.

**Enforcement:** performance budgets checked in CI where mechanizable (e.g. bundle-size limits, query-cost limits — Article XIV); pagination and N+1 avoidance are reviewer judgment backed by load testing and query-plan review.

## Article XII — Resilience, Deploy Safety & Incident Response

Things will break. The constitution's stance is not "prevent all failure" but "fail small, recover fast, and learn every time."

**Deploy safety — every deploy is reversible and progressively exposed.**

- **The artifact is immutable and promoted, not rebuilt.** One image, built once in CI and identified by its **content digest**, moves preview → staging → production unchanged. Tags are mutable pointers; the digest is the artifact's identity and the unit of promotion. Rebuilding per environment means you deploy something you never tested.
- **The running version comes from the environment, not from the build.** Baking a version into the image forces a rebuild to stamp a release, which destroys build-once. Inject it at deploy time.
- **Roll forward only when you can roll back.** A rollback path exists and is tested *before* a risky change ships. "How do we undo this?" is answered in the plan, not during the incident.
- **Progressive exposure.** New versions reach users gradually (health-gated rollout, and canary where the platform supports it), so a bad release harms a fraction, not everyone.
- **Schema changes are decoupled from code deploys** and follow expand/contract (Article XVII). A deploy must never require a simultaneous destructive migration.
- **A deploy-readiness checklist gates production:** observability in place (Article IX), rollback verified, migrations expand-safe, SLOs unbroken.

**Incident response — failure is a learning input.**

- **Classify by severity** and respond proportionally; have a known path to engage the right people.
- **Blameless postmortems for every user-facing incident.** Written timeline, contributing causes (systemic, not personal), and concrete action items. The question is "what about the system let this happen," never "who messed up."
- **Action items are tracked, not forgotten** — they flow into the Future Considerations doc and become real work (Article II).
- **The error budget governs.** When reliability is spent, reliability work outranks features until the budget recovers.

> **Why.** Reliability is not the absence of failure; it is the bounded blast radius and short recovery time when failure comes. A blameless culture is what makes people surface problems early instead of hiding them until they're catastrophic.

**Enforcement:** CI/CD pipeline gates (immutable digests, health-gated rollout, rollback step); deploy-readiness checklist in the delivery pipeline; postmortems are process (human discipline) with tracked action items. Stack mechanisms: Article XIX.

---

# TIER 2 — STACK PROFILE

*The mechanism layer — a map, not the text. Each article names the Tier 1 principle it implements and the skill that owns its mechanism; that skill carries the detail and loads only when a task touches its stack. A project on different tooling therefore never has another stack's laws asserted at it. Swapping this tier (Article XX) means adopting different stack skills, not editing this document.*

## Article XIII — The Data Path

*Implements: Article X (defense in depth).*

**Owned by:** `postgres-postgraphile-rls-and-sql` — a different data layer still names exactly one legal path for application data, and still passes session context as hints validated downstream rather than trusted as authorization.

## Article XIV — Security Mechanisms: RLS & Query Hardening

*Implements: Article X (security & defense in depth), Article XI (DoS via unbounded queries).*

**Owned by:** `postgres-postgraphile-rls-and-sql` — a different datastore still pushes final enforcement as low as it goes, so the store is the wall and the layers above are convenience; and still bounds query cost, depth and result size.

## Article XV — The Contract Layer

*Implements: Article IV (tests as a control) and Article XI (interfaces are contracts), applied to the seams between layers.*

**Owned by:** `graphql-contract-testing` — a different client or transport still defines its contract seams: one shared artifact, asserted on contract rather than string, breaking in both directions when it changes.

## Article XVI — Observability Mechanisms

*Implements: Article IX (observability & operability).*

**Owned by:** `observability-and-slos` — a different runtime still exposes health endpoints, emits structured logs carrying a correlation id, and publishes the metrics its SLOs are computed from.

## Article XVII — Migrations & Zero-Downtime Schema Change

*Implements: Article XII (deploy safety) at the schema layer.*

**Owned by:** `zero-downtime-migrations` — a different schema tool still evolves data by expand/contract, and still never bundles a destructive migration with the deploy that depends on it.

## Article XVIII — Schema Style

*Implements: Article VI (code craft) at the schema layer.*

**Owned by:** `postgres-postgraphile-rls-and-sql` — a different schema language still favours idempotent, final-form definitions in a navigable one-object-per-file layout.

## Article XIX — Delivery

*Implements: Article XII (deploy safety) and Article VIII (the verification gate) at the delivery layer.*

**Owned by:** `cloud-delivery-aks` — a different runtime still delivers through health-gated, reversible, progressive rollout, promoting one artifact unchanged through preview → staging → production rather than rebuilding it per environment.

---

## Article XX — Adapting to a New Project

This constitution is built to travel.

- **Tier 1 (Core) is portable as-is** — both the building discipline (Part A) and the operating discipline (Part B). The pipeline, records, commits, tests-as-a-control, change hygiene, code craft, interface craft, the verification gate, observability, security, performance, and resilience apply to any long-lived system.
- **Tier 2 (Stack Profile) is swappable.** When the tooling differs, replace these articles with the equivalents for the new stack, keeping the *spirit* and the Tier 1 principle each one implements:
  - A different data layer still names its **one legal data path** (XIII) and pushes **final enforcement as low as it goes** (XIV).
  - A different client/transport still defines its **contract seams** (XV) — one shared artifact, asserted on *contract not string*, broken in both directions; GraphQL is just this stack's instance.
  - A different runtime still has **observability mechanisms** (XVI), **zero-downtime schema/data evolution** (XVII), and **health-gated, reversible, progressive delivery** (XIX) — Kubernetes is this stack's instance; a PaaS or VM fleet substitutes its own.
  - Schema management still favors **idempotent, final-form definitions** (XVII) and a **navigable one-object-per-file layout** (XVIII).
- **Scale the operating articles to the project's lifecycle.** A local-only or pre-launch project applies expand/contract, canary, and formal incident process as *write-the-rule-now, activate-on-trigger*; a project with real users in production activates them immediately. State which mode a project is in, in its first decision record.
- **Declare the stack profile.** The first decision record names which stack skills the project adopts, and which Tier 2 articles it drops. An undeclared profile is the default one, which is rarely what a new project wants.
- **When a project lacks a layer entirely** (a pure library, a CLI, a batch pipeline with no browser), drop the inapplicable article rather than contorting the project to fit it. Record the omission.
- **Extending the Core:** new universal practices are added as Tier 1 articles with the same rigor — state the rule, the *why*, the named tension it resolves, and the **Enforcement** line. An article without an enforcement mechanism or an honest aspirational label does not belong here (Principle 7).
- **Precedence is always:** User instructions → this Constitution → tool defaults. When a project's own `CLAUDE.md`/`AGENTS.md`/equivalent conflicts with this document, that project file wins — and the conflict is worth a decision record.

> **Why.** The durable asset is the *reasoning*, not the specific tool. A new stack changes the nouns in Tier 2; it should never change the verbs in Tier 1.

**Enforcement:** this article is process; the first decision record of each new project states its lifecycle mode and any dropped articles.
