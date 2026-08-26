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

## Bundled Tooling

This skill ships its own scripts and template, so they work in any repo the
skill is installed into. They live next to `SKILL.md`:

```
recording-decisions/
  scripts/doc-archive.sh      find specs/plans lacking a decision record
  scripts/index-rebuild.sh    regenerate the index from record frontmatter
  templates/decision-record.md
```

Locate them — the skill may be installed per-project or globally:

```bash
for base in .claude/skills ~/.claude/skills; do
  d="$base/recording-decisions/scripts"
  [ -d "$d" ] && echo "$d" && break
done
```

**`doc-archive.sh [specs_dir] [plans_dir] [decisions_dir] [archive_dir]`**
Lists specs with no matching decision record and prints a conversion prompt
built from the template. Defaults to `docs/superpowers/{specs,plans,decisions,archive}`.

**`index-rebuild.sh [decisions_dir] [output_file]`**
Rewrites `docs/superpowers/index.md` from every record's frontmatter — an
Active table (component, title, date, dependencies) and a Superseded table
(component, title, superseded by). Regenerated wholesale, so never hand-edit it.

Both are dependency-free bash: a project using this skill does not need `yq`,
`jq`, or a task runner. If the scripts are missing, the procedures above are
self-contained — do the work directly.

### Why this matters for context

Specs and plans are verbose on purpose; they are written for a human following
the reasoning. That verbosity is charged to context every time Claude opens
one. A decision record keeps what is needed to move forward — decisions, the
why, interfaces, constraints, gotchas, rejected alternatives — in ~30-50 lines,
while the original spec moves to `archive/` where it stays readable for humans
and costs nothing until deliberately opened.

## When NOT to use

Trivial, self-evident changes don't need a record. The test: *would someone later ask "why was this done this way?"* If yes, record it.

Full rationale: `docs/engineering-constitution.md` Article II.
