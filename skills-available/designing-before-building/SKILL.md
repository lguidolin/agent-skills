---
name: designing-before-building
description: Use when starting a feature, fixing a non-trivial bug, or about to write implementation code — before any code exists. Symptoms you need this: "this is simple, I'll just code it", reaching for the editor before a design is approved, or an idea that hasn't been turned into a spec and plan.
---

# Designing Before Building

## Overview

Work flows through five stages, in order: **Brainstorm → Spec → Plan → Execute → Record.** No implementation begins before a design is articulated and approved. The simplest task is where unexamined assumptions cost the most.

**Violating the letter of this rule is violating the spirit of it.** "I'll design as I code" is not designing.

## The Five Stages

1. **Brainstorm.** Explore intent, constraints, success criteria. Ask one question at a time. Propose 2–3 approaches with trade-offs and a recommendation. Converge on a design and get **explicit approval**. No code here.
2. **Spec.** Write the approved design to a dated document. The spec is the contract for what gets built.
3. **Plan.** Decompose the spec into an ordered, reviewable implementation plan before touching code.
4. **Execute.** Implement against the plan, with review checkpoints.
5. **Record.** Distill what was built and *why* into a decision record (see `recording-decisions`).

**Decompose large efforts.** If a request spans multiple independent subsystems, stop and decompose before refining details. Each sub-project runs its own cycle, built in dependency order.

## When NOT to use

Genuinely trivial, reversible edits (a typo, a log line, a config value) skip straight to Execute. The test: *would a wrong guess here cost more than the design step?* If yes, design first.

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "This is too simple to need a design" | Simple tasks hide assumptions. A few sentences of design is cheap; a rewrite is not. |
| "I'll design as I go" | Code written before the design is settled is code rewritten. Design is a separate act. |
| "The user told me what to build, that IS the design" | A request states *what*, not *how*. The how is the design. |
| "Exploring the codebase first will tell me the approach" | Exploration informs design; it doesn't replace approval of one. |
| "We're in a hurry" | Hurry is exactly when skipped design produces throwaway work. |

## Red Flags — STOP

- Opening the editor before an approved design exists
- "Let me just prototype it real quick" (a prototype with no spec is unreviewed scope)
- Starting a multi-file change with no plan
- Treating the user's one-line request as a finished spec

**All of these mean: stop, design, get approval, then build.**

Full rationale: `docs/engineering-constitution.md` Article I.
