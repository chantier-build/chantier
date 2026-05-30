# Roadmap: Chantier

> **Format note (temporary):** This roadmap follows GSD's `gsd-tools` parser format because Chantier uses GSD as its bootstrap planning harness until its own runtime exists (Phase 2). The arc is documented in [STATE.md](STATE.md) under the `bootstrap.harness.chosen` event. Once Phase 5 (dogfood-e2e) ships, this file will be migrated back to Chantier's native format per ADR 0001 — at which point GSD will no longer be invoked in Chantier's own workflows.

## Overview

Chantier v0.1.0 ships when a developer can scaffold a new project, plan a phase, execute one task with a shipped skill, verify it, and produce a `STATE.md` that records the events — all through a portable POSIX-shell binary that respects the contract from ADR 0001. The five phases below take us from a paper architecture (foundation, already done) to a working end-to-end loop that has eaten its own dogfood.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3, 4, 5): planned milestone work
- Decimal phases (e.g., 2.1): urgent insertions if they appear later, marked `INSERTED`

- [x] **Phase 1: Foundation** - Architecture proposed and ratified, repo skeleton shipped, GitHub org created, ADR 0001 accepted.
- [ ] **Phase 2: Runtime core** - Implement `core/bin/chantier` POSIX-shell binary with `state append` and `validate-task` commands; codify ADR 0002.
- [ ] **Phase 3: Skill library** - Author four reference skills (`using-git-worktrees`, `test-driven-development`, `requesting-code-review`, `subagent-driven-development`) with PRESSURE.md each.
- [ ] **Phase 4: Claude Code adapter** - Build `adapters/claude-code/` that stages dossiers and dispatches subagents per ADR 0001.
- [ ] **Phase 5: Dogfood E2E** - Use Chantier-on-Chantier; plan one small feature, execute it end-to-end with one shipped skill, surface gaps, record as integration test.

## Phase Details

### Phase 1: Foundation

**Goal**: Establish the architectural foundation for Chantier — research the inheritance from GSD redux and Superpowers, define the state/skill contract (ADR 0001), and ship a repository skeleton under a community-governed GitHub org with collective MIT copyright. No runtime code.
**Depends on**: Nothing (first phase)
**Requirements**: [FR-007]
**Success Criteria** (what must be TRUE):

  1. ADR 0001 (state/skill contract) ratified, status Accepted, and published in `docs/adr/`.
  2. `docs/research/inheritance-map.md` captures derivation from GSD redux and Superpowers, including issue #237 as load-bearing constraint.
  3. Repository public at `github.com/chantier-build/chantier` under MIT with collective copyright (`Chantier Contributors`).
  4. `.planning/` populated and dogfood-validated against ADR 0001 schemas.

**Plans**: 1 plan (complete)

Plans:

- [x] 01-01: foundation-bootstrap — research + ADR 0001 + scaffold + repo publication + `.planning/` backfill

### Phase 2: Runtime core

**Goal**: Implement `core/bin/chantier` POSIX-shell binary with at minimum `state append` and `validate-task` commands, and publish ADR 0002 codifying the STATE.md format and front-matter JSON Schemas left open by ADR 0001.
**Depends on**: Phase 1
**Requirements**: [FR-001, FR-002, FR-003, FR-004]
**Success Criteria** (what must be TRUE):

  1. `core/bin/chantier` exists as a POSIX shell + `jq` executable, no harness-specific dependencies.
  2. `chantier state append --event X --task Y --skill Z --summary "..."` appends exactly one event row to `STATE.md`.
  3. `chantier validate-task <task>` exits non-zero on contract violations (writes outside `state_writes`, missing `output.md`, schema mismatch on `output.json`, missing acceptance section).
  4. `chantier new <name>` scaffolds `.planning/` with empty PROJECT/REQUIREMENTS/ROADMAP/STATE/config files.
  5. ADR 0002 published with status Accepted: STATE.md format finalized (Markdown table vs JSONL vs hybrid) and JSON Schemas published for PROJECT/REQUIREMENTS/ROADMAP/PLAN/SKILL front-matters.

**Plans**: 6 plans
Plans:
**Wave 1**

- [x] 02-01-PLAN.md — Wave 0 infra: install bats-core + shellcheck, vendor bats-support + bats-assert submodules, .gitattributes LF guard, scaffold 5 bats files + 4 fixtures

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 02-02-PLAN.md — Author the 5 JSON Schema draft-07 files under core/schemas/ (project, requirements, roadmap, plan, skill) per D-05/D-06/D-07
- [ ] 02-03-PLAN.md — core/bin/chantier skeleton: shebang, prelude, dispatch, --help, --version, --self-test (REVISED mkdir-lock per RESEARCH), stubs; self_test.bats real assertions

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 02-04-PLAN.md — state_append (FR-003) with mkdir-mutex concurrency primitive + state_show (D-03) with BSD-column collapse mitigation; bats coverage

**Wave 4** *(blocked on Wave 3 completion)*

- [ ] 02-05-PLAN.md — validate_task (FR-004) with all 5 ADR-0001 gates + new_project (FR-002) with heredoc scaffolds; helpers validate_against_schema, extract_frontmatter_as_json

**Wave 5** *(blocked on Wave 4 completion)*

- [ ] 02-06-PLAN.md — Author ADR 0002 (status Accepted, schemas inline, mkdir-mutex documented, ADR-0001 open questions re-flagged); one-shot migrate STATE.md to JSONL in dedicated commit; append phase.completed event via the binary

### Phase 3: Skill library

**Goal**: Author the first four reference skills, exercising ADR 0001's SKILL.md schema with real bodies, and confirm `chantier validate-task` accepts tasks that invoke them.
**Depends on**: Phase 2
**Requirements**: [FR-005, FR-006, FR-009, FR-010]
**Success Criteria** (what must be TRUE):

  1. Four skills shipped: `using-git-worktrees`, `test-driven-development`, `requesting-code-review`, `subagent-driven-development`.
  2. Each skill ships `SKILL.md` with valid front-matter per ADR 0001 (`id`, `version`, `inputs_schema`, `state_reads`, `state_writes`, `outputs_schema`, `portable: true`, `harness_adapters`).
  3. Each skill ships `PRESSURE.md` with at least two adversarial scenarios per Superpowers' tradition.
  4. `chantier validate-task` accepts a task that invokes any of these skills.
  5. No skill body contains harness-specific identifiers (enforced by `chantier validate-task` portability grep).

**Plans**: TBD

Plans:

- [ ] 03-01: TBD (produced by `/gsd-plan-phase 3`)

### Phase 4: Claude Code adapter

**Goal**: Build the first harness adapter at `adapters/claude-code/` that can stage a dossier for a task and dispatch a Claude Code subagent to execute the named skill — without leaking any Claude Code identifier back into skill bodies.
**Depends on**: Phase 3
**Requirements**: [FR-008]
**Success Criteria** (what must be TRUE):

  1. `adapters/claude-code/run-task.sh` stages `.chantier/dossiers/<task>/` containing `inputs.yml`, `reads/`, `upstream/`, and `env.sh` per ADR 0001 surface 2.
  2. The adapter dispatches a Claude Code subagent that reads the dossier and executes the named skill body.
  3. One end-to-end task invocation works (any of the four skills from Phase 3, executed in a worktree).
  4. The adapter is the only file in the repo containing the string `claude-code` outside of documentation — verified by grep.

**Plans**: TBD

Plans:

- [ ] 04-01: TBD (produced by `/gsd-plan-phase 4`)

### Phase 5: Dogfood E2E

**Goal**: Use Chantier-on-Chantier — plan one small feature using Chantier's own commands, execute it using one shipped skill, verify, and record the run as an integration test in `tests/e2e/`. This phase is also the formal cutover point where Chantier stops depending on GSD's commands.
**Depends on**: Phase 4
**Requirements**: [NFR-001, NFR-002, NFR-003, NFR-004, NFR-005, NFR-006]
**Success Criteria** (what must be TRUE):

  1. `tests/e2e/` contains an integration test that runs the full new-project → plan → execute → verify loop using only Chantier-built tooling.
  2. The test produces a populated `.planning/STATE.md` without any contract violations detected by `chantier validate-task`.
  3. The test passes in CI without network access (except where a skill explicitly opts in).
  4. NFR-001 through NFR-006 are independently verified (portability grep, dependency audit, append-only check, network audit, language audit, license audit).
  5. `.planning/ROADMAP.md` is migrated from GSD format back to Chantier-native format per ADR 0001 as the final commit of this phase.

**Plans**: TBD

Plans:

- [ ] 05-01: TBD (produced by `/gsd-plan-phase 5` — the last GSD-driven planning in Chantier's history)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 1/1 | Complete | 2026-05-29 |
| 2. Runtime core | 1/6 | In progress | - |
| 3. Skill library | 0/TBD | Not started | - |
| 4. Claude Code adapter | 0/TBD | Not started | - |
| 5. Dogfood E2E | 0/TBD | Not started | - |
