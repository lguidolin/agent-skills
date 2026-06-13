---
name: recording-decisions
description: Use when a design or architecture decision has been made and needs to be captured — writing a decision record or ADR, updating a decision index, noting a deferred idea, or superseding a past decision. Keywords — ADR, decision record, rationale, rejected alternatives, dependency index.
---

# Recording Decisions

## Overview

Decisions are durable infrastructure; memory and chat history are not. The cost of a record is paid once; the cost of a *lost* decision is paid every time someone reverse-engineers intent from code.

## The Record Shape

Every non-trivial decision produces a record with a fixed structure, so any reader knows where to look:

| Section | Contains |
|---|---|
| **Architecture** | The shape of the solution and the key files |
| **Data Model** | Entities, fields, relationships |
| **Decisions (with WHY)** | Each choice paired with its rationale — *why* is mandatory |
| **Interfaces** | How other code uses this |
| **Constraints** | What must remain true |
| **Gotchas** | Non-obvious traps for the next person |
| **Rejected Alternatives** | What was considered and discarded, *and why* — prevents relitigating settled questions |

## The Three Companion Artifacts

- **An index** of all decisions with explicit **dependency tracking** (which builds on which) and a **superseded** section. Turns a pile of records into a navigable graph.
- **A "Future Considerations" doc** — deferred ideas and known concerns, consulted when starting new work so nothing is silently forgotten. **Incident action items and deferred-with-trigger decisions land here.**
- **An archive** — superseded records move here rather than being deleted. History is preserved, not overwritten.

## Quick Reference

- Record location convention: `docs/superpowers/decisions/YYYY-MM-DD-<topic>.md` with YAML frontmatter (`title`, `date`, `component`, `status`, `supersedes`, `dependencies`).
- Frontmatter feeds the auto-generated index — keep it accurate.
- The *why* and the *rejected alternatives* are the two highest-value sections. A record without them is a landmine.
- Write the record at the **Record** stage of the pipeline (see `designing-before-building`), after Execute.

## When NOT to use

Trivial, self-evident changes don't need a record. The test: *would someone later ask "why was this done this way?"* If yes, record it.

Full rationale: `docs/engineering-constitution.md` Article II.
