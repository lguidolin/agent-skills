# The Engineering Constitution

*A portable charter of working practices and stack laws, written to be handed to an AI agent (or human) starting a new project. It encodes how we work, why we work that way, how we operate what we ship, and how to adapt when the project differs.*

> **How to read this document.** Tier 1 is universal and travels to every project unchanged. Tier 2 is the mechanism for a specific stack (PostgreSQL · PostGraphile · graphile-migrate · React/TanStack · Docker · Azure Kubernetes) and is swapped when the stack differs. Every article carries an **Enforcement** line naming the tooling that makes it real — or labeling it honestly as reviewer judgment. Where an article only applies at a certain scale or lifecycle stage, an **Applies when** line says so.

---

## Preamble — Inviolable Principles

Everything in this document derives from eight principles. When a specific article is silent or ambiguous, reason from these.

1. **Understand before building.** No code is written before a design is articulated and approved. The simplest task is where unexamined assumptions cost the most.
2. **Record every decision with its rationale — and what you rejected.** A decision without its *why* is a landmine for the next person. A decision without its *rejected alternatives* invites relitigating settled questions.
3. **Tests are a control, not a formality.** A test encodes an expectation. A failing test is information to be understood and explicitly accepted — never silently edited away.
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
- **CI is the source of truth — authoritative, shared, unbypassable.** It is the wall: lint, typecheck, the contract checks (Article XV), the test suite, security scans, and commit validation all run here and **must pass before merge**. What CI says is what counts.
- **The pre-push hook is a presubmit mirror, not a wall.** It runs the same fast checks locally so you *probably* pass CI before you push — saving a round-trip. It is explicitly **bypassable** (`--no-verify`) and only runs where the toolchain is installed. We accept that; its job is speed and early feedback, not enforcement. CI re-runs everything regardless. **The hook never gates; CI gates.**
- **Keep CI fast by tiering, not by removing checks.** While the full suite is fast, run it all on every PR. When it outgrows that, split **presubmit** (fast subset, blocks the PR) from **postsubmit** (full suite, runs after merge, blocks promotion) — never move authoritative checks back to the bypassable hook.
- **The one deliberate exception: container images build locally and push to the registry (GHCR), not in CI.** Rationale: CI image-build latency is unacceptable for the team's loop. **This is a known, accepted trade-off, not an ideal** — the shipped artifact's provenance is a developer machine rather than a hermetic CI runner. Mitigate it: build only from a clean git state at a tagged commit SHA, pin the toolchain and base-image digests, and tag the image with the SHA so it is traceable. *Trigger to revisit:* if build provenance becomes a compliance or trust requirement, or the team grows past easy coordination, move the build into CI with a layer cache.

> **Named tension, eyes open.** A bypassable local presubmit is fast but unenforceable; an authoritative CI is enforceable but slower. We resolve it by giving each a *different mandate* — the hook optimizes for the inner loop, CI for correctness of record — and by making CI, not the hook, the thing that can block a merge. The local image build is the single conscious crack in the "CI is the source of truth" wall, accepted for latency and fenced with provenance mitigations.

**Enforcement:** the CI pipeline definition itself (branch protection requiring CI to pass before merge); the task runner (e.g. `just`) as the recipe registry.

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

- **The artifact is immutable and promoted, not rebuilt.** One image, built once, tagged by commit SHA, moves dev → alpha → prod unchanged. Rebuilding per environment means you deploy something you never tested.
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

**Enforcement:** CI/CD pipeline gates (immutable tags, health-gated rollout, rollback step); deploy-readiness checklist in the delivery pipeline; postmortems are process (human discipline) with tracked action items. Stack mechanisms: Article XIX.

---

# TIER 2 — STACK PROFILE

*The mechanism layer for this stack — PostgreSQL · PostGraphile · graphile-migrate · React/TanStack · Docker · Azure Kubernetes (AKS). When a project uses different tooling, this entire tier is **swapped** (Article XX); Tier 1 stays. Each article names the Tier 1 principle it implements.*

## Article XIII — The Data Path

*Implements: Article X (defense in depth).* There is exactly one legal path for application data:

**Browser → App server → PostGraphile → PostgreSQL.**

- The browser never talks to the GraphQL or database layer directly.
- The app server never queries the database directly for application data — all application data flows through the GraphQL layer.
- The app server passes **session context as headers only** (e.g. user id, org hint). It contains **no authorization logic**; context hints are validated downstream, not trusted.

> **Why.** A single data path means a single place to enforce every cross-cutting concern — auth context, validation, row-level security. Side channels are exactly the holes that bypass those enforcement points.

**Enforcement:** architectural lint/review — server-only modules may not be imported by client code; the app layer has no direct DB driver dependency (dependency-boundary check in CI where possible).

## Article XIV — Security Mechanisms: RLS & GraphQL Hardening

*Implements: Article X (security & defense in depth), Article XI (DoS via unbounded queries).*

- **RLS is the final enforcement layer.** Application-layer checks are convenience and UX; the database is the wall. Data isolation is enforced where the data lives.
- **Roles model real session states** — "not logged in," "logged in without active org context," "logged in with confirmed context," plus a connection-only role and a migration-only role. Roles mean something; they are not arbitrary labels.
- **The privileged connection role never executes application queries.** Application queries run under a constrained role subject to RLS.
- **`SECURITY DEFINER` functions set `search_path` inline** in their definition — every time, no exceptions.
- **Absence is `NULL`, never an empty string.** Empty strings as sentinels are forbidden; omit the value entirely when absent.
- **GraphQL is a denial-of-service surface — bound it.** Enforce **query depth limits** and **cost/complexity analysis**; reject queries past budget. Cap pagination page size. Set a database **`statement_timeout`** for the application roles. **Disable introspection in production** (or restrict it) unless a deliberate reason requires it.
- **Secrets via the platform store.** On AKS: Azure Key Vault surfaced through the Secrets Store CSI driver (or sealed secrets) — never baked into images or committed `.env` files. Rotate on a schedule and on suspected exposure.
- **Supply chain in CI.** Committed lockfiles, `pnpm audit` / Renovate (or Dependabot), pinned and Trivy-scanned base images.
- **Audit sensitive mutations** at the database layer where feasible (who/what/when), distinct from application logs.

> **Why.** RLS guarantees that even a bug in the layers above cannot leak another tenant's rows. Query-cost limiting guarantees that a single crafted GraphQL query cannot exhaust the database. Together they make the data layer safe by default rather than safe by vigilance.

**Enforcement:** pgTAP role-matrix tests in CI (blocking) for RLS (Article XV §role context); depth/cost limits configured in PostGraphile and asserted by tests; `pnpm audit`/Trivy/secret-scan in CI (blocking).

## Article XV — The Contract Layer

*Implements: Article IV (tests as a control) and Article XI (interfaces are contracts), applied to the seams between layers.* Two seams are governed here. **The cardinal rule: assert on the contract — the data shape and access semantics the consumer depends on — never on the query string itself.** A test that breaks on a cosmetic query edit is a change-detector anti-pattern; a test that breaks when the *guaranteed shape or permission* moves is a control.

### §1 — The GraphQL Query Contract

- **Every operation is authored once as a typed document in a known location, exported to be imported.** The UI imports it. The test imports the **exact same** artifact — never a re-typed copy. Copying a query into a test silently kills the contract (editing the UI query no longer breaks the test). This is Article VI's DRY made load-bearing.
- **The contract breaks in both directions, by construction:**
  - **DB → UI drift, caught at compile time.** `graphql-codegen` generates TypeScript types from the **live PostGraphile schema**. Rename or drop a field the document uses and `tsc` fails on every usage *and* on the shared document — the build breaks before a user sees a blank panel. *This is why codegen-against-live-schema is mandatory, not optional.*
  - **UI → DB / permission drift, caught at runtime.** The shared document is executed against a **seeded test database through the real call path**, under role context, asserting on the **returned shape and access outcome** — not the query text. Add a field RLS only exposes to elevated roles, and the test running *as a plain member* now sees null/denied and breaks, forcing "did we mean to expose this?"
- **Contract tests and the Article XIV role matrix are the same harness.** Run the one shared document through PostGraphile as role A (expect data) and role B (expect denied/empty). One mechanism proves three things at once: the query still matches the schema, the UI's data assumptions still hold, and RLS still enforces the boundary.

*Worked example of catching a real bug:* a migration renames `equipment.is_active` → removes the field. Codegen regenerates from the new schema; the generated type loses the field; `tsc` fails on the shared document and every component using it — **caught at build, by the type system, before merge.** Conversely, a dev widens the UI query to pull `cancellation_reason`; the runtime test as a member asserts the member-visible shape, now gets a denial/null, and **fails — forcing a deliberate decision.** Neither test asserts "the query text equals X"; both assert the *contract*.

### §2 — The Route Contract & Smoke Tests

- **Routes are enumerated from a single source.** Each route has a smoke test asserting it **renders without error** and shows a **minimal required set of elements** (a heading, a landmark, a key control — not detailed interaction).
- **Adding or removing a route forces a matching test change** — a new URL is incomplete without its smoke test; a removed URL must remove its test. URLs never appear or vanish silently.
- **Explicitly *not* detailed UI/interaction testing.** Deliberate, scope-limited: the question is "does this URL work and render the essentials," nothing more. Deeper UI testing is deferred until there's a considered approach.

> **Why.** A contract test converts an invisible coupling (the UI assumes the DB returns field X; this URL is assumed to exist) into a visible, enforced one. Move either side of the seam and the build tells you — Principle 3 operating at the boundary instead of inside a unit.

**Enforcement:** `graphql-codegen` + `tsc` in CI (blocking) for the compile-time half; runtime contract + route smoke tests in CI (blocking) against a seeded test DB.

## Article XVI — Observability Mechanisms

*Implements: Article IX.*

- **Structured JSON logs to stdout**, collected by the platform (AKS → Azure Monitor / Log Analytics). No free-text logging in services.
- **OpenTelemetry** in the app server and PostGraphile; export traces and metrics to **Azure Monitor / Application Insights** (or a Prometheus/Grafana stack where preferred). 
- **Correlation id propagated across the data path** — generated at the edge, passed Browser → App → PostGraphile (alongside the existing context headers), attached to every log line and span so one request is reconstructable end to end.
- **RED metrics** per HTTP route and per GraphQL operation; **PostgreSQL slow-query logging** and `pg_stat_statements` for the database.
- **Liveness and readiness endpoints** wired to Kubernetes probes (Article XIX). Readiness reflects real dependency health (can it reach the DB?), not just process-up.
- **Frontend:** report **web-vitals** and client errors to the same telemetry backend.
- **SLOs defined per critical journey** with dashboards and **burn-rate alerts**; alerts are actionable and symptom-based.

**Enforcement:** instrumentation presence checked in review/lint; probe endpoints verified by a route smoke test (Article XV §2); SLO/alert definitions live as code in the ops repo and are reviewed.

## Article XVII — Migrations & Zero-Downtime Schema Change

*Implements: Article XII (deploy safety) at the schema layer.*

**Authoring rules (all projects):**

- **Two kinds of migration, kept distinct:** the idempotent **`current/`** set (dev iteration — re-run every cycle, written `CREATE OR REPLACE` / `IF NOT EXISTS`, objects in **final form**, no post-creation `ALTER`) and **committed** migrations (the immutable, ordered migrations that actually ship). `ALTER DEFAULT PRIVILEGES` is the lone accepted inline `ALTER`.
- **Ownership comes from how migrations are run**, not scattered `ALTER ... OWNER`.
- **One bootstrap source of truth** shared by the local/Docker init path and the shadow/test database, so every environment is built identically.

**Zero-downtime rules — expand/contract (parallel change).**
**Applies when:** the database holds data that must survive the deploy (alpha-with-data and production). **Exempt:** local/reset-friendly projects (e.g. rendvu local-only), where final-form definitions suffice — but write committed migrations as if expand/contract applies, so promotion to a real environment is never a rewrite.

A schema change that an app version depends on is split across **three releases**, never one:

1. **Expand** — add the new shape *additively* and backward-compatibly: new nullable column, new table, new function. App version *N* keeps running untouched.
2. **Migrate** — backfill data in **bounded batches** (never one table-locking `UPDATE`); dual-write from app *N+1* if needed; switch reads to the new shape. Only now make a new column `NOT NULL` (add the constraint `NOT VALID`, then `VALIDATE` separately).
3. **Contract** — only after app *N* is fully retired, remove the old column/constraint in a *later* release.

**PostgreSQL footguns to respect:**
- Adding a `NOT NULL` column with a volatile/large backfill default rewrites/locks the table — add nullable, backfill in batches, then constrain.
- Add constraints `NOT VALID` first, then `VALIDATE CONSTRAINT` (takes a weaker lock).
- Build indexes `CONCURRENTLY` — and note this **cannot run inside a transaction**, which interacts with migration-tool transaction wrapping; isolate such steps.
- Set `lock_timeout` / `statement_timeout` on migrations so a blocked migration fails fast instead of freezing production.

> **Why.** "Final-form `CREATE OR REPLACE`" is a *developer-ergonomics* rule and is correct in dev. In production with live users and a rolling deploy, the running old pods and the new pods share one database for the duration of the rollout — so the schema must be compatible with **both** app versions at once. Expand/contract is what makes that true. Combining a destructive migration with the deploy that needs it is the classic self-inflicted outage.

**Enforcement:** migrations run in CI against a shadow DB (blocking); expand/contract adherence is reviewer judgment guided by this article's checklist; destructive-statement detection in CI where mechanizable.

## Article XVIII — SQL Style

*Implements: Article VI (code craft) for SQL.*

- **One object per file** — each table, function, policy, and grant set in its own file.
- **Organized `schema/object_type/name`** — directory structure mirrors the database's own organization.
- **Include order is dependency order;** the include manifest doubles as the table of contents for the whole schema.
- **Document inline.** `COMMENT ON` statements live in the same file as the object, explaining *what* and *why* — especially for non-obvious behavior.
- **Descriptive aliases** (the singular of the table name, not single letters). Follow the database's own naming idioms for session-context getters.
- **Types and user-facing roles are data, not hardcoded constraints** — lookup tables with key/label/description, validated by foreign keys, extensible without schema changes.

> **Why.** One-object-per-file plus dependency-ordered includes means the file tree is a faithful, navigable map of the database — and a focused file is one an agent can hold in context and edit reliably.

**Enforcement:** SQL linter/formatter in CI where available; structure and commenting are reviewer judgment.

## Article XIX — Delivery: Kubernetes, Per-PR Environments, Canary & Rollback

*Implements: Article XII (deploy safety) and Article VIII (delivery) on Azure Kubernetes.*

- **Local dev runs the full stack** via Docker Compose, one command, comprehensive — a first-class requirement.
- **Images build locally → GHCR, tagged by commit SHA** (the Article VIII exception), then **promoted unchanged** dev → alpha → prod. Never rebuilt per environment.
- **Per-PR ephemeral alpha environments.** Each PR deploys to its own isolated namespace (or equivalent) on AKS for review, and is **torn down on merge/close**. This is the integration-test bed; it must be cheap to create and destroy.
- **Kubernetes health gating.** Every workload defines **liveness, readiness, and startup probes** (wired to Article XVI endpoints), a **rolling update** strategy with bounded `maxUnavailable`/`maxSurge`, and a **PodDisruptionBudget**. Use a **HorizontalPodAutoscaler** for load.
- **Progressive delivery to prod.** Canary or blue-green via the platform (e.g. Argo Rollouts / Flagger) with automated metric analysis tied to SLOs (Article IX); a failed canary aborts automatically.
- **Rollback is first-class and rehearsed.** Because images are immutable and SHA-tagged, rollback is redeploying the prior tag (`kubectl rollout undo` / abort the rollout). Verified before risky changes ship.
- **Migrations are a separate, ordered step** in the pipeline, expand-safe (Article XVII), run before the code that depends on them — never bundled into the pod that needs the new schema.
- **CI is the gate (Article VIII):** lint, typecheck, contract checks, tests, and security scans block merge; CI **does not build the production image** (that is local), but it does validate the source the image is built from.
- **Dev/prod parity & config from the environment.** Secrets from Key Vault (Article XIV); ports/config from env; dev-only tooling (pgTAP, test runners) never ships in production images.

> **Why.** Immutable SHA-tagged artifacts plus health-gated progressive rollout plus a rehearsed rollback turn "deploy" from a held-breath event into a routine, reversible, low-blast-radius operation — which is the whole point of Article XII.

**Enforcement:** the CI/CD pipeline and Kubernetes manifests are the enforcement (probes, PDB, rollout strategy, promotion flow defined as code); branch protection requires CI green before merge.

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
- **When a project lacks a layer entirely** (a pure library, a CLI, a batch pipeline with no browser), drop the inapplicable article rather than contorting the project to fit it. Record the omission.
- **Extending the Core:** new universal practices are added as Tier 1 articles with the same rigor — state the rule, the *why*, the named tension it resolves, and the **Enforcement** line. An article without an enforcement mechanism or an honest aspirational label does not belong here (Principle 7).
- **Precedence is always:** User instructions → this Constitution → tool defaults. When a project's own `CLAUDE.md`/`AGENTS.md`/equivalent conflicts with this document, that project file wins — and the conflict is worth a decision record.

> **Why.** The durable asset is the *reasoning*, not the specific tool. A new stack changes the nouns in Tier 2; it should never change the verbs in Tier 1.

**Enforcement:** this article is process; the first decision record of each new project states its lifecycle mode and any dropped articles.
