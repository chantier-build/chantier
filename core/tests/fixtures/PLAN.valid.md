---
plan_id: fixture-valid-plan
phase: fixture-phase
created: 2026-05-29
status: draft
declared_skills: []
---

# Plan — Fixture valid plan

## Goal

This fixture exercises the PLAN.md schema validation path. Both tasks carry all required
fields per ADR 0001 Surface 1: task, skill, state_writes, and acceptance with at least
two bullet items each.

## Task `t1` — Scaffold output directory

```yaml
task: t1
skill: inline
inputs:
  target_dir: .planning/phases/fixture-phase/tasks/t1
state_reads: []
state_writes:
  - .planning/STATE.md
depends_on: []
acceptance:
  - "Output directory exists at the declared state_writes path"
  - "Directory is empty except for a .gitkeep placeholder"
```

## Task `t2` — Write output summary

```yaml
task: t2
skill: inline
inputs:
  format: markdown
state_reads:
  - .planning/STATE.md
state_writes:
  - .planning/phases/fixture-phase/tasks/t2/output.md
  - .planning/phases/fixture-phase/tasks/t2/output.json
depends_on: [t1]
acceptance:
  - "output.md exists and contains a non-empty summary paragraph"
  - "output.json parses as valid JSON with at least one key"
```
