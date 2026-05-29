---
plan_id: 01-foundation-bootstrap
phase: 01-foundation
date_started: 2026-05-29
date_completed: 2026-05-29
status: completed
duration_estimated: 2h-2h30
duration_actual: one session
---

# Summary — Foundation phase

## What shipped

1. `docs/research/inheritance-map.md` — twelve concepts covered with explicit derivation from GSD redux and Superpowers, including four explicit "drop" decisions and three explicit "invent" decisions.
2. `docs/adr/0001-state-skill-contract.md` — founding ADR, status **Accepted**. Three surfaces defined: how `PLAN.md` declares skills, how a skill reads state, how a skill writes state. Five alternatives considered and rejected with rationale.
3. `README.md`, `docs/vision.md`, `LICENSE` (MIT collective), `LICENSE-CREDITS`, `CONTRIBUTING.md`, `.gitignore`.
4. Empty directory seeds: `skills/`, `core/`, `.planning/` (with explanatory README).
5. Public repository at `github.com/chantier-build/chantier` with topics, Discussions enabled, MIT badge detected by GitHub.
6. This `.planning/` directory backfilled as dogfood validation of the format.

## What was deferred

Four open questions kept out of ADR 0001 to avoid scope creep, all flagged for later ADRs:
- Skill versioning and `chantier.lock`.
- `STATE.md` compaction strategy.
- `inputs_schema` strictness model.
- Skill-to-skill composition syntax.

## Surprises and lessons

- **Superpowers issue #237 reshaped the contract within minutes of being read.** The empirical finding that subagents miss `SessionStart`-injected discipline forced the contract to be entirely file-based, with no hook propagation as a load-bearing mechanism. This was not in the brief but became non-negotiable.
- **The brief's "monolithic `gsd-tools.cjs`" reference is stale.** GSD redux has reorganized into `commands/gsd/`, `agents/`, and `bin/install.js`; no monolithic file by that name remains. Worth correcting in any document that quotes the brief verbatim.
- **The collective-copyright move was easier to commit to than expected.** Once `Copyright (c) 2026 Chantier Contributors` is in place, every later governance choice falls out of it naturally.

## Validation of ADR 0001 schema (the point of this backfill)

Writing this phase's `PLAN.md` retroactively exercised the schema for the first time. Findings to feed ADR 0002:

- ✅ Inline tasks (`skill: inline`) work fine for bootstrap or trivial glue.
- ✅ YAML task blocks fenced under Markdown headings stay readable and greppable.
- ⚠ Current `STATE.md` format (Markdown table) is workable but not machine-friendly. ADR 0002 should decide between Markdown table, JSON Lines, or hybrid.
- ⚠ Front-matter fields are not yet schema-validated. ADR 0002 should publish JSON Schemas for `PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `PLAN.md`, and `SKILL.md`.
- ⚠ No formal namespace for event types in `STATE.md`. The events used here (`bootstrap.session.started`, `adr.accepted`, `phase.completed`, etc.) are reasonable but ad-hoc. ADR 0002 should define a controlled vocabulary or naming convention.

## Recommendation for next phase

**Phase 2 — `02-runtime-core`.** Implement `core/bin/chantier` as POSIX shell + jq, with at minimum `chantier state append` and `chantier validate-task` commands. Companion ADR 0002 codifies the `STATE.md` format and the front-matter schemas. Three of the four deferred ADR 0001 questions can stay deferred; one of them — `STATE.md` format — is now blocking and must be resolved in ADR 0002.

Phase 3 (skill library) waits until Phase 2 lands, so that the first skills can call the real `chantier` binary in their `run.sh` scripts.

## Verification

- Repository live and browsable: ✅
- License badge detected: ✅ (MIT)
- All committed files render in GitHub: pending visual check after this `.planning/` commit lands.
