---
plan_id: 01-foundation-bootstrap
phase: 01-foundation
created: 2026-05-29
status: completed
declared_skills: []
note: |
  Phase 1 was executed before the skill library existed. All tasks are inline (no skill invocation).
  This plan is a retroactive record of work that has already shipped; its primary purpose is to
  validate that the PLAN.md schema (ADR 0001) can describe Chantier's own history.
  Treat as a worked example of the schema, not as a forward-looking plan.
---

# Plan — Foundation bootstrap

## Goal

Establish the architectural foundation for Chantier: research the inheritance from GSD redux and Superpowers, define the state/skill contract (ADR 0001), and ship a repository skeleton under a community-governed GitHub org with collective MIT copyright. No runtime code.

## Task `t1` — Verify identity availability

```yaml
task: t1
skill: inline
inputs:
  resources:
    - chantier.dev
    - npm/chantier
    - npm/@chantier/core
    - github.com/chantier-build
state_reads: []
state_writes:
  - .planning/STATE.md
depends_on: []
acceptance:
  - "All four resources verified free as of 2026-05-29"
  - "GitHub user 'chantier' is the known dormant squatter (acceptable per brief)"
```

## Task `t2` — Research GSD redux and Superpowers

```yaml
task: t2
skill: inline
inputs:
  sources:
    - https://github.com/open-gsd/get-shit-done-redux
    - https://github.com/open-gsd/get-shit-done-redux/discussions/109
    - https://github.com/open-gsd/get-shit-done-redux/discussions/1
    - https://github.com/obra/superpowers
    - https://blog.fsck.com/2025/10/09/superpowers/
    - https://github.com/obra/superpowers/issues/237
state_reads: []
state_writes:
  - docs/research/inheritance-map.md
depends_on: []
acceptance:
  - "Twelve concepts covered with GSD / Superpowers / Chantier-synthesis rows"
  - "Issue #237 surfaced as load-bearing constraint for ADR 0001"
  - "What-we-drop and what-we-invent sections explicit"
```

## Task `t3` — Write ADR 0001 (state/skill contract)

```yaml
task: t3
skill: inline
inputs:
  questions_to_answer:
    - "How does PLAN.md declare the skills it will invoke?"
    - "How does a skill access current state portably?"
    - "How does a skill record its output in the state?"
state_reads:
  - docs/research/inheritance-map.md
state_writes:
  - docs/adr/0001-state-skill-contract.md
depends_on: [t2]
acceptance:
  - "Three surfaces formally specified"
  - "At least five alternatives considered and rejected with rationale"
  - "Approved by founding contributors before any runtime code"
```

## Task `t4` — Scaffold repository

```yaml
task: t4
skill: inline
inputs:
  files:
    - README.md
    - LICENSE
    - LICENSE-CREDITS
    - CONTRIBUTING.md
    - docs/vision.md
    - .gitignore
  directories:
    - skills/
    - core/
    - .planning/
state_reads:
  - docs/adr/0001-state-skill-contract.md
state_writes:
  - README.md
  - LICENSE
  - LICENSE-CREDITS
  - CONTRIBUTING.md
  - docs/vision.md
  - .gitignore
  - skills/.gitkeep
  - core/.gitkeep
  - .planning/README.md
depends_on: [t3]
acceptance:
  - "MIT license with collective copyright (Chantier Contributors)"
  - "LICENSE-CREDITS attributes both predecessors with reciprocal credit"
  - "CONTRIBUTING describes multi-contributor governance model and non-negotiables"
```

## Task `t5` — Publish to GitHub org

```yaml
task: t5
skill: inline
inputs:
  org: chantier-build
  repo: chantier
  visibility: public
state_reads: []
state_writes:
  - .planning/STATE.md
depends_on: [t4]
acceptance:
  - "Repo public at https://github.com/chantier-build/chantier"
  - "Discussions enabled, Wiki disabled, Projects disabled"
  - "MIT license auto-detected by GitHub"
  - "Commits use noreply email — no personal email leak"
```

## Task `t6` — Backfill `.planning/` (dogfood validation)

```yaml
task: t6
skill: inline
inputs:
  format_validation_target: ADR 0001
state_reads:
  - docs/adr/0001-state-skill-contract.md
  - docs/research/inheritance-map.md
state_writes:
  - .planning/PROJECT.md
  - .planning/REQUIREMENTS.md
  - .planning/ROADMAP.md
  - .planning/STATE.md
  - .planning/config.json
  - .planning/phases/01-foundation/PLAN.md
  - .planning/phases/01-foundation/SUMMARY.md
depends_on: [t5]
acceptance:
  - "All seven artifacts exist and parse as valid YAML / Markdown / JSON"
  - "Format inconsistencies surface and are noted in SUMMARY.md as input to ADR 0002"
  - "Phase 02-runtime-core declared as next in ROADMAP.md and STATE.md"
```
