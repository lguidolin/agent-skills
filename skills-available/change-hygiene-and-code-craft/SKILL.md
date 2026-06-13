---
name: change-hygiene-and-code-craft
description: Use when writing or refactoring code, structuring a commit or PR, or deciding whether to abstract duplication. Symptoms — mixing reorg with logic changes, a PR doing several things at once, a file growing large, the second copy of similar code, or unsure whether to DRY something up.
---

# Change Hygiene and Code Craft

## Overview

How changes are shaped and how code is written. Two themes: **separate structural from behavioral change**, and **say what you mean with the least cleverness that works.**

## Change Hygiene

- **Structural changes before behavioral changes, validated independently.** Reorganizing (splitting files, renaming, adding comments) is a *separate, independently-checkable step* from changing behavior (new constraints, altered logic). Never mix them in one indivisible change — a reviewer can't tell safe reshuffling from real logic changes.
- **One concern per change.** A change has a single, statable purpose.
- **Improve the code you're working in** when its problems affect your task (leave the campsite cleaner) — but **don't** start unrelated refactoring. Stay focused on the goal.

## Code Craft

- **Explicit over implicit.** No wildcards where names belong, no implicit casts, no empty-string or magic sentinels. Say what you mean.
- **Descriptive names.** Functions/variables describe what they do; follow language and ecosystem idioms.
- **Comment intent, not mechanics.** Explain *why* when non-obvious; skip comments on self-evident code.
- **Small, single-purpose units.** For any unit you should be able to state what it does, how to use it, what it depends on — without reading its internals. A large file is usually doing too much.
- **DRY in production code, with judgment.** Duplication is a *signal*, not an automatic error. The **second** near-identical occurrence triggers a deliberate decision: abstract, or record why not. Abstract shared **meaning**, never coincidental shape — things that look alike but change for different reasons stay apart.
- **Follow ecosystem standards.** Use the idioms and well-supported libraries a competent practitioner expects. Don't reinvent what the platform solved.

## The Named Tensions

- **DRY vs. premature abstraction:** production code abstracts on *demonstrated repetition of intent*, not anticipated repetition of shape. When unsure, wait for the third occurrence (YAGNI governs the tie-break).
- **DRY vs. DAMP:** *production* code is DRY; *test* code is DAMP (clarity over de-duplication, see `tests-as-a-control`). Applying DRY to tests is a violation.

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "I'll rename and add the feature in one commit" | Structure and behavior in one diff are unreviewable. Split them. |
| "Two copies, I must DRY it now" | Second occurrence = *decide*. Same shape ≠ same meaning. Coincidental duplication should stay apart. |
| "While I'm here, let me refactor this other module" | Unrelated refactoring expands scope and risk. Note it; don't do it now. |
| "A clever one-liner is more elegant" | Explicit beats clever. Optimize for the next reader. |

## Red Flags — STOP

- A diff that both moves code and changes its behavior
- A PR whose purpose needs the word "and" to describe
- Abstracting on the first sight of similarity, or on anticipated (not actual) repetition
- A file you can no longer hold in your head

Full rationale: `docs/engineering-constitution.md` Articles V & VI.
