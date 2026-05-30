---
phase: 02-runtime-core
plan: "06"
subsystem: docs-and-state
tags:
  - adr
  - state-migration
  - jsonl
  - phase-close
dependency_graph:
  requires:
    - 02-05
  provides:
    - ADR 0002 accepted
    - STATE.md JSONL format v0.1.0
  affects:
    - .planning/STATE.md
    - docs/adr/
tech_stack:
  added: []
  patterns:
    - MADR ADR style (mirroring ADR 0001)
    - JSONL event log migration
    - dogfood state append via binary
key_files:
  created:
    - docs/adr/0002-runtime-binary-and-state-format.md
    - .planning/phases/02-runtime-core/02-06-SUMMARY.md
  modified:
    - .planning/STATE.md
    - .planning/ROADMAP.md
decisions:
  - "ADR 0002 published Accepted: codifies D-01 through D-13, mkdir-mutex (not flock), frontmatter subset profile, JSON Schema subset profile, 5 schemas inline, actor fallback to unknown"
  - "STATE.md migrated from Markdown table to JSONL in dedicated commit per D-04; pre-migration table preserved verbatim in commit body"
  - "Dogfood phase.completed event appended via chantier binary proving round-trip correctness"
  - "ADR 0001 four open questions explicitly re-flagged as still deferred"
metrics:
  duration: "~25 minutes"
  completed: "2026-05-30"
---

# Phase 02 Plan 06: ADR 0002, STATE.md Migration, and Phase 2 Close Summary

ADR 0002 published (status Accepted, 496 lines, MADR-shaped) codifying the runtime binary and STATE.md JSONL format contract; STATE.md migrated from Markdown table to JSONL in a dedicated commit; Phase 2 dogfood `phase.completed` event appended via the binary proving round-trip correctness.

## What Was Shipped

### Task 1: ADR 0002

`docs/adr/0002-runtime-binary-and-state-format.md` — 496 lines, status Accepted, mirroring ADR 0001's MADR house style.

Sections published:
- **Context**: three forcing findings (NFR-002 dep budget, flock absent on macOS, no pure-jq draft-07 validator) + three Phase-1 open items closed by Phase 2.
- **Decision**: 9 thematic subsections covering STATE.md JSONL format, actor fallback, event taxonomy and shape regex `^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$`, frontmatter subset profile, JSON Schema subset profile, schemas (inline), hybrid strict/permissive validation, mkdir-mutex concurrency, exit-code matrix, self-test gates, and migration.
- **Schemas (inline)**: all 5 schemas quoted byte-for-byte from `core/schemas/*.json` — verified via python3 JSON parse + equality check.
- **Consequences**: positive / negative / neutral.
- **Alternatives considered**: A through F (Markdown table, flock, ajv, yq, full draft-07, permanent migrate subcommand) — all rejected.
- **Open questions**: ADR 0001's 4 questions explicitly re-flagged as still deferred; 2 new questions added (self-test drift check, actor fallback refinement).
- **Approval**: `[x]` checkboxes, Chantier founding contributors, 2026-05-30.

Two Claude's Discretion items revised:
- **#4 (lock)**: mkdir-mutex replaces flock (flock absent on macOS; direct env probe confirmed).
- **#11 (self-test)**: gates expanded to include mkdir-lock-works, no-CRLF-in-self, harness-deny-list-in-self.

Two new sub-profiles formally introduced:
- **Frontmatter subset profile**: top-level scalars + simple lists; nested maps and anchors not supported.
- **JSON Schema subset profile**: 7 supported keywords (`type`, `required`, `properties`, `additionalProperties`, `pattern`, `enum`, `items`); explicit NOT-supported list.

**Commit**: `3c88256` — `docs(02-06): publish ADR 0002 runtime binary and STATE.md format`

### Task 2: STATE.md Migration

`.planning/STATE.md` migrated from Markdown table (format_version 0.1.0-interim) to JSONL (format_version 0.1.0) in a dedicated commit per D-04.

- 16 rows migrated (11 Phase-1/Phase-2-bootstrap events with actor `MAoDzi` + 5 plan.completed rows with actor `claude-sonnet-4-6`).
- All rows receive `task: null`, `skill: null` (historical rows carried no task/skill association per PATTERNS.md per-row mapping rule).
- Pre-migration table preserved verbatim in the commit body per RESEARCH Open Question 2.
- No `.bak` file committed; git history is the backup.

**Migration commit**: `d51b382` — `chore(02-06): migrate STATE.md from Markdown table to JSONL (format_version 0.1.0)`

### Task 2 (dogfood): phase.completed Event

After migration, `chantier state append -e phase.completed -m "..." -r ... -r ...` was executed against the migrated file. Binary appended exactly one JSONL line with proper timestamp, actor `MAoDzi`, `task: null`, `skill: null`, and refs array.

`git diff .planning/STATE.md` confirmed single-line addition.

**Dogfood commit**: `22f4d1b` — `chore(02-06): record phase.completed for Phase 02-runtime-core`

## Validation Results

### Migration validation
```
format_version: 0.1.0          OK
No 0.1.0-interim               OK
Body line count (post-append): 17
All lines valid JSON:          OK
All event fields pass D-09 regex: OK
Actors present: MAoDzi, claude-sonnet-4-6
No .bak file:                  OK
```

### chantier state show (first 10 lines of output)
```
TS                    EVENT                      ACTOR              TASK  SKILL  SUMMARY  REFS
2026-05-29T17:00:00Z  bootstrap.session.started  MAoDzi             -     -      Brief received, session plan proposed, all seven ADR sign-offs validated  brief
2026-05-29T17:15:00Z  research.completed         MAoDzi             -     -      Inheritance map written from GSD redux, Superpowers, and obra/superpowers#237 finding  docs/research/inheritance-map.md
2026-05-29T17:25:00Z  adr.accepted               MAoDzi             -     -      ADR 0001 (state/skill contract) accepted; 7 surface decisions ratified, 4 questions deferred  docs/adr/0001-state-skill-contract.md
...
2026-05-30T05:25:24Z  phase.completed            MAoDzi             -     -      Phase 02-runtime-core complete: FR-001..FR-004 satisfied; ADR 0002 published Accepted; STATE.md migrated to JSONL.  .planning/phases/02-runtime-core/02-06-SUMMARY.md, docs/adr/0002-runtime-binary-and-state-format.md
```

### bats test suite
All 64 tests pass (no regression). `chantier --self-test: all green`.

## Phase 2 Requirements Status

| Requirement | Status | Evidence |
|-------------|--------|----------|
| FR-001: core/bin/chantier binary | Complete | plan 02-03; 975-line binary; 64 bats green |
| FR-002: chantier new scaffold | Complete | plan 02-05; new_project() with 5 scaffold files |
| FR-003: chantier state append | Complete | plan 02-04; mkdir-mutex; concurrent-safe |
| FR-004: chantier validate-task | Complete | plan 02-05; all 5 ADR 0001 gates enforced |

## Phase 2 Success Criteria

| # | Criterion | Status |
|---|-----------|--------|
| 1 | `core/bin/chantier` exists, POSIX sh + jq, no harness deps | Done |
| 2 | `chantier state append` appends exactly one event row | Done |
| 3 | `chantier validate-task` exits non-zero on contract violations | Done |
| 4 | `chantier new <name>` scaffolds `.planning/` | Done |
| 5 | ADR 0002 published status Accepted; schemas published | Done (this plan) |

## Deviations from Plan

### Deviation 1: 16 rows migrated (not 10)

The planning documents described "10 historical events + 5 plan.completed rows". The actual STATE.md at migration time contained 11 Phase-1/Phase-2-bootstrap rows (the plan_coordination documents counted 10, but `phase.context.gathered` at `2026-05-30T00:06:01Z` was appended during Phase 2 context gathering, making the true count 11). Combined with 5 plan.completed rows, the total is 16.

The acceptance criteria required `>= 11 JSONL lines post-migration`, which is satisfied. All 16 rows pass validation. This is not a bug — the orchestrator-track appended rows were correctly preserved.

## Open Issues (deferred to Phase 3 and beyond)

1. **Skill versioning / chantier.lock** (ADR 0001 OQ #1, re-flagged in ADR 0002 OQ #1): deferred.
2. **STATE.md compaction** (ADR 0001 OQ #2, re-flagged in ADR 0002 OQ #2): deferred.
3. **inputs_schema strictness** (ADR 0001 OQ #3, re-flagged in ADR 0002 OQ #3): deferred.
4. **Skill-to-skill composition** (ADR 0001 OQ #4, re-flagged in ADR 0002 OQ #4): deferred.
5. **--self-test drift check** (ADR 0002 OQ #5): should `--self-test` compare inline ADR 0002 schemas with `core/schemas/*.json` byte-for-byte? Deferred.
6. **Actor fallback refinement** (ADR 0002 OQ #6): distinguish `unknown` / `ci` / `system` in v0.2. Deferred.

## Note for Phase 3

The SKILL.md frontmatter schema (`core/schemas/skill.json`) is in place and `chantier validate-task` gate 4 is wired. The four reference skills (`using-git-worktrees`, `test-driven-development`, `requesting-code-review`, `subagent-driven-development`) can now be authored against a real, stable contract. ADR 0002 is their load-bearing reference.

## Self-Check: PASSED

- `docs/adr/0002-runtime-binary-and-state-format.md` exists: FOUND
- `.planning/STATE.md` format_version 0.1.0: FOUND
- Migration commit `d51b382` exists: FOUND
- Dogfood commit `22f4d1b` exists: FOUND
- ADR commit `3c88256` exists: FOUND
- 64 bats tests green: CONFIRMED
- chantier --self-test: CONFIRMED green
