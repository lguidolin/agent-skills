---
name: interface-craft-and-accessibility
description: Use when building or styling UI — components, layouts, forms, design tokens — or making accessibility decisions. Keywords — a11y, WCAG, keyboard navigation, focus state, contrast, design system, minimalist UI, component reuse, ARIA, semantic HTML.
---

# Interface Craft and Accessibility

## Overview

The standard is **accessible, minimalist, and beautiful — by construction, not by polish.** Taste is unactionable as a rule, so it's converted into constraints, precedent, and escalation. The agent isn't asked to invent taste, only to honor constraints and escalate the rest.

## Accessibility — a Requirement, Not a Finishing Pass

Checkable rules:

- Every interactive element is **keyboard-reachable** with a **visible focus state**.
- Every control has an **accessible name**; every form field has an associated **label** and clear error messaging.
- **Semantic HTML and landmarks** over `div` soup.
- **Color contrast meets WCAG AA**; meaning is **never** conveyed by color alone.
- Honor **reduced-motion** preferences.

## Beautiful and Minimalist — as Constraints, Not Vibes

- **Consistency through constraint.** Use the design system's tokens — spacing, type scale, color scale. No one-off magic numbers. Coherence *is* the aesthetic.
- **Existing screens are the style guide.** Match the established visual language before inventing.
- **Restraint (UI-YAGNI).** Every element earns its place; remove until removing breaks something. Hierarchy and whitespace over density and decoration.
- **Prefer the component library's patterns** before building custom UI.
- **Two similar UI elements → one parameterized component.** Differences are props/variants, never copy-paste. A third copy is a defect. (DRY applied to the interface.)

## The Escalation Rule

**Taste decisions escalate; they are never freelanced.** When a choice is genuinely aesthetic and **underdetermined by tokens or precedent**, do not silently guess:

1. Follow the nearest existing precedent, or
2. Surface options (mockups, side-by-side comparisons) for a human taste call.

## Quick Reference

| Situation | Do |
|---|---|
| New component resembles an existing one | Parameterize the existing one; don't copy |
| A spacing/color value isn't in the tokens | Use the nearest token; don't invent a magic number |
| Genuinely novel visual decision | Escalate with options; don't freelance |
| Adding an interactive element | Keyboard + focus + accessible name, from the start |

**Enforcement:** a11y linting/tests in CI (e.g. `eslint-plugin-jsx-a11y`, axe) for the checkable rules; aesthetic restraint is reviewer judgment via the escalation rule.

Full rationale: `docs/engineering-constitution.md` Article VII.
