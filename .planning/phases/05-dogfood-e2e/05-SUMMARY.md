---
phase: 05-dogfood-e2e
status: complete
completed: 2026-05-30
plans:
  - 05-01
  - 05-02
  - 05-03
  - 05-04
requirements_completed:
  - NFR-001
  - NFR-002
  - NFR-003
  - NFR-004
  - NFR-005
  - NFR-006
bats_suite_before: 73/0
bats_suite_after: 81/0
shipped_artifacts:
  - core/tests/adapter_upstream_e2e.bats
  - core/tests/nfr_audits.bats
  - tests/e2e/full_loop.bats
  - docs/adr/0004-surface-3-propagation.md
  - adapters/claude-code/run-task.sh (F3 fix patch)
  - adapters/claude-code/README.md (depends_on documentation)
satisfies_project_criterion:
  - "PROJECT.md v0.1.0 success criterion 5 (Chantier's own development is managed by Chantier)"
  - "REQUIREMENTS.md §Acceptance: integration test in tests/e2e/"
  - "REQUIREMENTS.md §Acceptance: ADR record contains at least one ADR resolving an ADR 0001 OQ (ADR 0004)"
cutover_event_ts: "2026-05-30T23:49:04Z"
---

# Phase 05: Dogfood E2E — Close Summary

Phase 5 closes Chantier v0.1.0 by eating its own dogfood. Plan 05-01 shipped the F3 fix (adapter `depends_on` → `upstream/<tN>/output.json` staging in `adapters/claude-code/run-task.sh`) via TDD, with two atomic commits (`test:` then `feat:`) — the failing-then-passing bats sequence on `core/tests/adapter_upstream_e2e.bats` is the TDD dogfood proof. Plan 05-02 codified the Surface 3 propagation contract in ADR 0004 (Proposed) and consolidated the six NFR audits into `core/tests/nfr_audits.bats` (six independent `@test` blocks, one per NFR-001..NFR-006), promoting ROADMAP SC#4 from claim to enforcement. Plan 05-03 shipped `tests/e2e/full_loop.bats` — the full new-project → plan → execute → verify integration test with the `CHANTIER_E2E_REAL_CLAUDE` opt-in env gate (hermetic CHANTIER_CLAUDE_BIN-stubbed by default, NFR-004-compliant). Plan 05-04 (this commit) migrated `.planning/ROADMAP.md` to ADR 0001 native format (minimalist diff: strip Format-note callout; flip Phase 5 row to Complete), appended the `cutover.completed` event marking Chantier's exit from GSD-dependency, and recorded the Phase 5 `phase.completed` event via direct binary invocation (symmetric with Phases 1-4). Final bats suite total: 81/0. ROADMAP Phase 5 success criteria SC#1..SC#5 are all closed. REQUIREMENTS.md §Acceptance "v0.1.0 ships when" is satisfied across all four bullets. PROJECT.md v0.1.0 success criterion 5 ("Chantier's own development is managed by Chantier") is met. v0.1.0 is feature-complete.

## Goal (quoted from ROADMAP.md §Phase 5)

> Use Chantier-on-Chantier — plan one small feature using Chantier's own commands, execute it using one shipped skill, verify, and record the run as an integration test in `tests/e2e/`. This phase is also the formal cutover point where Chantier stops depending on GSD's commands.

## Plans Executed

| Plan | Subsystem | Outcome | SUMMARY |
|------|-----------|---------|---------|
| 05-01 | adapter F3 fix + in-tree regression | Two-commit TDD (`d133386` test → `ed6dfe6` feat); bats 73 → 74; F3 closed; D-01/D-02 closed; NFR-001/002/005 honored | [05-01-SUMMARY.md](05-01-SUMMARY.md) |
| 05-02 | ADR 0004 (Proposed) + nfr_audits.bats | ADR shipped 151 lines 8 canonical sections; six `@test` blocks all green in isolation; bats 74 → 80; D-05/D-06/D-09 closed; SC#4 promoted to enforcement | [05-02-SUMMARY.md](05-02-SUMMARY.md) |
| 05-03 | tests/e2e/full_loop.bats | 1/1 green default-offline (CHANTIER_CLAUDE_BIN stub); bats 80 → 81; D-03/D-04 closed; SC#1/SC#2/SC#3 promoted to enforcement; chantier-on-chantier proof shipped | [05-03-SUMMARY.md](05-03-SUMMARY.md) |
| 05-04 | ROADMAP migration + cutover.completed + phase.completed | Final commit bundle (this commit); D-07/D-08/Discretion #7/Discretion #10 closed; SC#5 closed | (this file) |

## Verification Results

### ROADMAP Phase 5 Success Criteria

| # | Criterion | Status | Evidence | Command |
|---|-----------|--------|----------|---------|
| SC#1 | `tests/e2e/` contains an integration test that runs the full new-project → plan → execute → verify loop using only Chantier-built tooling | green | `tests/e2e/full_loop.bats` 1/1 green; exercises `chantier new` + sequential `adapters/claude-code/run-task.sh t1`/`t2` + `chantier validate-task t1`/`t2` end-to-end | `bats tests/e2e/full_loop.bats` |
| SC#2 | The test produces a populated `.planning/STATE.md` without any contract violations detected by `chantier validate-task` | green | STATE.md event-count assertions: `task.started == 2`, `skill.completed == 2`, `task.completed == 2`, `task.failed == 0`; both `chantier validate-task` invocations exit 0 (all five ADR 0001 gates pass) | `bats tests/e2e/full_loop.bats` |
| SC#3 | The test passes in CI without network access (except where a skill explicitly opts in) | green | `CHANTIER_CLAUDE_BIN` default-set in `setup()`; Pitfall 8 self-assertion `[ -n "$CHANTIER_CLAUDE_BIN" ] && [ -x "$CHANTIER_CLAUDE_BIN" ]` fires twice; `CHANTIER_E2E_REAL_CLAUDE` opt-in gate never set in CI | `unset CHANTIER_E2E_REAL_CLAUDE; bats tests/e2e/full_loop.bats` |
| SC#4 | NFR-001 through NFR-006 are independently verified (portability grep, dependency audit, append-only check, network audit, language audit, license audit) | green | Six `@test` blocks in `core/tests/nfr_audits.bats` all exit 0 in isolation; per-NFR independence proven via `bats core/tests/nfr_audits.bats -f 'NFR-00N'` for N in 1..6 | `bats core/tests/nfr_audits.bats` |
| SC#5 | `.planning/ROADMAP.md` is migrated from GSD format back to Chantier-native format per ADR 0001 as the final commit of this phase | green | Format-note callout stripped; `head -5 .planning/ROADMAP.md \| grep -q 'Format note'` exits 1; `git log -p -1 .planning/ROADMAP.md` shows the migration diff as the most-recent change | `! head -5 .planning/ROADMAP.md \| grep -q 'Format note'` |

### NFR Verification

| NFR | Status | Evidence | Command |
|-----|--------|----------|---------|
| NFR-001 (no harness identifiers in skill bodies; portability grep) | green | `core/tests/nfr_audits.bats` `@test 1` runs the byte-identical `_full` deny-list literal from `core/bin/chantier:687`/`:912`; D-10 path-only carve-out for `adapters/claude-code/`; 24 HARNESS_DENY_LIST_CHECK markers + case-arm self-exemption keep the audit clean | `bats core/tests/nfr_audits.bats -f 'NFR-001'` |
| NFR-002 (POSIX sh + jq only; no bash-isms) | green | `@test 2` runs per-file `shellcheck --shell=sh` loop + bash-ism grep (`[[ `, `<<<`, `mapfile`, `declare -a`, `local -a`) across `core/bin/`, `core/tests/`, `adapters/`, `skills/`, `tests/`; `command -v shellcheck` skip-not-fail precondition | `bats core/tests/nfr_audits.bats -f 'NFR-002'` |
| NFR-003 (STATE.md append-only; static guard complementing runtime mkdir-mutex) | green | `@test 3` greps for `>[[:space:]]*[^&].*STATE\.md` single-redirect deny pattern across `.sh` production sources in `core/bin/`, `adapters/`, `skills/`; case-arm exempts `core/bin/chantier` (the sanctioned `state_append` writer) | `bats core/tests/nfr_audits.bats -f 'NFR-003'` |
| NFR-004 (no network primitives by default) | green | `@test 4` greps for `curl `/`wget `/`http[s]?://`/`nc -`/`telnet ` in executable code; per-file HARNESS_DENY_LIST_CHECK filter + comment-URL strip prevents false positives; the `CHANTIER_CLAUDE_BIN` indirection keeps real-binary path opt-in (D-04) | `bats core/tests/nfr_audits.bats -f 'NFR-004'` |
| NFR-005 (English-only public artifacts) | green | `@test 5` runs density-based French stop-word detection (`\bavec\b\|\bdonc\b\|\bainsi\b\|...`) with ≥ 5 hits/file threshold per RESEARCH Pitfall 5 (avoids loanword false positives); walks `README.md`, `LICENSE`, `LICENSE-CREDITS`, `CONTRIBUTING.md`, `docs/adr/`, `docs/vision.md`, `docs/research/`, `core/`, `skills/`, `adapters/`, `tests/`; `.planning/` and `docs/strategy/` not walked | `bats core/tests/nfr_audits.bats -f 'NFR-005'` |
| NFR-006 (MIT collective copyright + SPDX) | green | `@test 6` asserts `head -1 LICENSE` == `MIT License`; `LICENSE-CREDITS` exists; SPDX-License-Identifier header in every `*.sh`; `Chantier Contributors` in LICENSE; no `(c) FirstName LastName` per-person regex; `test_helper/` vendored submodule directory exempt | `bats core/tests/nfr_audits.bats -f 'NFR-006'` |

### Bats suite totals

| Boundary | Tests | Notes |
|----------|-------|-------|
| Phase 4 close | 73/0 | Phase 5 entry-point |
| Post Plan 05-01 (GREEN commit `ed6dfe6`) | 74/0 | +1 from `core/tests/adapter_upstream_e2e.bats` |
| Post Plan 05-02 (commit `2962c24`) | 80/0 | +6 from `core/tests/nfr_audits.bats` |
| Post Plan 05-03 (commit `29f3d24`) | 81/0 | +1 from `tests/e2e/full_loop.bats` |
| Post Plan 05-04 (this commit) | 81/0 | unchanged — no test files modified; only ROADMAP narrative, STATE.md events, and SUMMARY |

## Resolved Discretion Items

### From 05-CONTEXT.md `### Claude's Discretion` (11 items)

| # | Item | Resolution | Plan |
|---|------|-----------|------|
| 1 | PLAN.md task pair shape for the F3 dogfood | t1 writes failing test (`d133386`); t2 patches adapter to GREEN (`ed6dfe6`); two atomic commits, RED-before-GREEN measurable | Plan 05-01 |
| 2 | F3 fix shape (per-file `output.json` vs full-dir symlink) | Per-file symlink shape per ADR 0001 Surface 2 line 134 precedent (`upstream/t0/output.json`); `ln -s ... 2>/dev/null \|\| cp` fallback | Plan 05-01 |
| 3 | PLAN.md `depends_on` ordering enforcement | Operator-orders-dispatch; missing-upstream exits 2 with stderr message; no topological sort in adapter (deferred to v0.2+) | Plan 05-01, Plan 05-03 |
| 4 | ADR 0004 exact prose | 151 lines, status Proposed, 8 canonical sections (Provenance/Context/Decision/Consequences/Alternatives/Open questions/Ratification path/References); mirrors ADR 0003 section structure verbatim | Plan 05-02 |
| 5 | `nfr_audits.bats` shellcheck shape | Per-file `shellcheck --shell=sh` loop (better bats failure legibility than `xargs -0`); `command -v shellcheck` skip-not-fail precondition | Plan 05-02 |
| 6 | NFR-005 non-English glyph regex | Density-based French stop-word detection (≥ 5 hits/file) per RESEARCH Pitfall 5; avoids loanword false positives (naive, cafe, resume) | Plan 05-02 |
| 7 | `cutover.completed` event refs payload (back-reference to `bootstrap.harness.chosen`?) | RECOMMENDED YES — include `bootstrap.harness.chosen@2026-05-29T18:30:00Z` as the third `--ref` value for audit hygiene | Plan 05-04 (this commit) |
| 8 | Whether to extract the `CHANTIER_CLAUDE_BIN` stub into a shared helper | Inline duplication across `adapter_claude_code_e2e.bats`, `adapter_upstream_e2e.bats`, and `tests/e2e/full_loop.bats` — byte-identical heredocs verified via three-way `diff`; no shared helper at v0.1 scale | Plan 05-03 |
| 9 | Synthetic project name in `chantier new` inside the e2e test | `chantier-e2e-dogfood` (descriptive kebab-case) | Plan 05-03 |
| 10 | Whether to record `phase.completed` for Phase 5 via the adapter or via direct `chantier state append` | Direct binary invocation, symmetric with Phases 1-4 (STATE.md rows 22, 31, 41, 47); the adapter does not own phase-level lifecycle events | Plan 05-04 (this commit) |
| 11 | Concurrency lock for parallel `run-task.sh` on the same task ID | NOT exercised; two-task chain is sequential by design; mkdir-mutex on `.chantier/dossiers/<task>/.lock` is the natural pattern when concurrency need surfaces (v0.2+ backlog) | (intentional non-feature) |

### Phase 5 D-NN coverage matrix (D-01..D-10)

| D-NN | Decision | Closed by |
|------|----------|-----------|
| D-01 | F3 dogfood feature in `adapters/claude-code/run-task.sh` (`depends_on` → `upstream/<tN>/output.json`) | Plan 05-01 (commit `ed6dfe6`) |
| D-02 | Skill executing F3 fix is `test-driven-development`; two-commit RED→GREEN | Plan 05-01 (commits `d133386` → `ed6dfe6`) |
| D-03 | Single `tests/e2e/full_loop.bats` at new top-level `tests/e2e/`; real `chantier new` + multi-task dispatch + `chantier validate-task` | Plan 05-03 (commit `29f3d24`) |
| D-04 | `CHANTIER_CLAUDE_BIN` deterministic stub default + `CHANTIER_E2E_REAL_CLAUDE=1` opt-in gate (offline-by-default; F2 contribution wired) | Plan 05-03 (commit `29f3d24`) |
| D-05 | Consolidated `core/tests/nfr_audits.bats` with six `@test` blocks (one per NFR-001..NFR-006) | Plan 05-02 (commit `2962c24`) |
| D-06 | Per-NFR audit shape (NFR-001 byte-identical deny-list, NFR-002 shellcheck per-file loop, NFR-003 static `>STATE.md` deny, NFR-004 network-primitives deny, NFR-005 French stop-word density, NFR-006 LICENSE/SPDX assertions) | Plan 05-02 (commit `2962c24`) |
| D-07 | Minimalist ROADMAP migration (strip Format-note callout; flip Phase 5 row to Complete; preserve narrative structure and front-matter) | Plan 05-04 (this commit) |
| D-08 | Cutover bundle in final commit: ROADMAP migration + 05-SUMMARY.md + `cutover.completed` STATE.md event + `phase.completed` STATE.md event in ONE commit | Plan 05-04 (this commit) |
| D-09 | F1 = author ADR 0004 (Proposed) codifying Surface 3 propagation contract; F3 = dogfood feature; F2/F4 stay v0.2 backlog | Plan 05-02 (ADR 0004 commit `b54a53d`); Plan 05-01 (F3) |
| D-10 | Matrix coverage: `tests/e2e/full_loop.bats` exercises only `test-driven-development` via the adapter; matrix-via-adapter for the other three skills is v0.2 mechanical extension per Phase 3 D-17 | Plan 05-03 (commit `29f3d24`) |

## Surface 3 propagation codification

ADR 0004 (`docs/adr/0004-surface-3-propagation.md`, status **Proposed**, 151 lines, authored in Plan 05-02 commit `b54a53d`) codifies the Phase 4 plan 03 discovery: the harness adapter SHALL, after the wrapped subagent exits 0 and before invoking `chantier validate-task`, copy every plain file from `$DOSSIER/` to `$TASK_DIR/`, EXCLUDING the adapter-owned artifacts (`inputs.yml`, `env.sh`, `subagent.transcript.log`) and all subdirectories (`reads/`, `upstream/`, `skill/`). The Ratification path lists three numbered observable conditions modeled on ADR 0003 lines 196-206:

1. A second harness adapter (`adapters/cursor/`, `adapters/codex-cli/`, or equivalent) ships and exercises the contract cross-harness.
2. A cross-harness e2e test proves the propagation works identically on at least two adapters.
3. Maintainer review with explicit ratification commit.

Ratification is deferred until v0.2.0+ when a second harness adapter exists. The canonical exclusion list (`inputs.yml`, `env.sh`, `subagent.transcript.log`, all subdirectories) is now contract-level rather than implementation-detail; future adapter authors honor it by reading the ADR.

## Handoff Notes for v0.2.0

Phase 5 closes v0.1.0 feature-complete. The following items are deliberately carried into the v0.2.0 backlog with explicit rationale recorded here so they are not silently lost:

1. **F2 (real-claude dispatch path coverage in CI).** Plan 05-03 ships the `CHANTIER_E2E_REAL_CLAUDE=1` env gate (D-04); CI never sets it. The wire is in place; v0.2 uses it when API-key infrastructure lands in CI. The Pitfall 8 self-assertion (`[ -n "$CHANTIER_CLAUDE_BIN" ] && [ -x "$CHANTIER_CLAUDE_BIN" ]`) catches silent fall-through to the real binary if a future contributor unsets the gate inside `setup()`.
2. **F4 (strict worktree validation).** Phase 4's lax interpretation (`git rev-parse --show-toplevel` accepts main checkout) has produced zero incidents through Phases 4 and 5. Tightening without evidence is over-engineering per Chantier's "honest about what works" posture. Revisit if a real failure signal surfaces.
3. **Second harness adapter (`adapters/cursor/`, `adapters/codex-cli/`, etc.).** Required for ADR 0004 ratification. The `nfr_audits.bats` deny-list pattern is already shaped to accommodate a second adapter via a single case-arm addition. Mechanical extension of `adapter_isolation.bats` carve-out follows the Phase 4 D-10 path-only convention.
4. **Matrix-via-adapter coverage of the 4 skills.** Phase 5 covers `test-driven-development` only via the adapter; the other three (`using-git-worktrees`, `requesting-code-review`, `subagent-driven-development`) remain proven via Phase 3's direct `core/tests/skill_*_e2e.bats`. v0.2 mechanical extension per Phase 3 D-17 — likely landing alongside the second harness adapter.
5. **ADR 0003 ratification (workflow skill design principles).** Phase 5 produced dogfood evidence; ratification commit lands in a later milestone (v0.2.0+) once the four principles are validated against authored workflow skills.
6. **ADR 0004 ratification (Surface 3 propagation).** Requires the second harness adapter to validate the contract cross-harness. v0.2+ per the Ratification path enumerated above.
7. **Workflow skill authoring** per `docs/strategy/maturity-path.md` sketch. v0.2.0+ — ADR 0003 must ratify first; the candidate 7-skill set is sketched but non-binding.
8. **`extract-skills-from-phase`** self-improvement skill. v0.3.0 per PROJECT.md.
9. **STATE.md compaction.** Post-v0.1.0 per ADR 0001 OQ #2. Phase 5 adds six new event types in normal operation plus prior phases' history; compaction need will be evaluated at v0.2 entry.
10. **`chantier validate-roadmap` subcommand.** Considered for D-07; rejected — ROADMAP migration in v0.1 is in-place edit. Revisit if v0.2 ergonomic need surfaces.
11. **`chantier task-lookup` subcommand.** Phase 4 Claude's Discretion deferred; Phase 5 inherits the same posture. PLAN.md task lookup remains inline in the adapter; candidate refactor when a second adapter ships.
12. **`tests/integration/`, `tests/manual/`, other top-level test categories.** Phase 5 creates `tests/e2e/` only; future categories slot in alongside per RESEARCH §"Recommended Project Structure".
13. **Subagent transcript persistence behind `CHANTIER_TRANSCRIPT=1`.** Phase 4 carried-forward. v0.2 ergonomic gate.
14. **PROJECT.md status flip to `v0.1.0-complete`.** Operator action post-this-commit; NOT in this plan's scope (D-08 is bounded to the four-artifact bundle). The flip happens in a follow-up commit when the operator confirms the v0.1.0 milestone is closed end-to-end.

## Self-Check: PASSED

- `.planning/phases/05-dogfood-e2e/05-SUMMARY.md` exists, ≥ 80 lines (this file) ✓
- `.planning/phases/05-dogfood-e2e/05-01-SUMMARY.md` exists ✓
- `.planning/phases/05-dogfood-e2e/05-02-SUMMARY.md` exists ✓
- `.planning/phases/05-dogfood-e2e/05-03-SUMMARY.md` exists ✓
- ROADMAP.md Phase 5 entry marked complete; Format-note callout stripped ✓
- STATE.md cutover.completed + phase.completed events appended in the same commit as the ROADMAP migration ✓
- `bats core/tests/ tests/e2e/` reports 81/0 ✓
- `shellcheck --shell=sh adapters/claude-code/run-task.sh` clean ✓
- `bats core/tests/nfr_audits.bats` 6/6 green ✓
- D-NN coverage check: D-01..D-10 cited across the four 05-NN-SUMMARY.md files and this Summary's D-NN matrix ✓
- Discretion items #1-#11 each have a resolution row in this SUMMARY ✓
- NFR-005 English-only: accented-glyph density scan against this SUMMARY returns 0 hits ✓
- v0.1.0 §Acceptance four bullets closed: FR-001..FR-010 (Phases 2-4), NFR-001..NFR-006 (Plan 05-02), integration test in `tests/e2e/` (Plan 05-03), ADR record contains at least one ADR resolving an ADR 0001 OQ (ADR 0004) ✓
