---
phase: 05-dogfood-e2e
plan: 03
subsystem: dogfood-e2e-integration-test
tags: [e2e, dogfood, bats, integration-test, chantier-on-chantier, multi-task, full-loop, opt-in-env-gate, phase-05]
requires:
  - core/bin/chantier (new + validate-task + state append subcommands -- the public surface the integration test exercises end-to-end)
  - adapters/claude-code/run-task.sh (Phase 4 D-NN decisions + Plan 05-01 F3 fix; the dispatch primitive under exercise)
  - skills/test-driven-development/ (SKILL.md + PRESSURE.md + run.sh -- the live skill body copied into the synthetic project)
  - core/tests/adapter_claude_code_e2e.bats (PRIMARY analog -- shape mirror at full-loop scale; setup() body, stub heredoc, error-surface block)
  - core/tests/adapter_upstream_e2e.bats (SECONDARY analog -- Plan 05-01 in-tree regression; two-task PLAN.md heredoc shape, F3 assertion pattern)
  - core/tests/test_helper/bats-support + core/tests/test_helper/bats-assert (path-relative-loaded from tests/e2e/)
  - core/tests/fixtures/skills/test-driven-development/dossier/inputs.yml (the deterministic four-scalar TDD red-phase fixture mirrored verbatim into both task blocks)
provides:
  - tests/e2e/full_loop.bats (Phase 5 dogfood E2E integration test -- single @test, ~307 lines, chantier-on-chantier proof)
  - SC#1 promotion from claim to enforcement (full new-project -> plan -> execute -> verify loop)
  - SC#2 promotion from claim to enforcement (populated STATE.md with six dispatch events + zero task.failed + validate-task green on both)
  - SC#3 promotion from claim to enforcement (hermetic CI default offline via CHANTIER_CLAUDE_BIN stub)
  - F3 fix proof at full-loop scale (.chantier/dossiers/t2/upstream/t1/output.json exists; assertion goes red if Plan 05-01 fix regresses)
  - CHANTIER_E2E_REAL_CLAUDE=1 opt-in wire (D-04; the v0.1 contribution to F2's v0.2 work)
  - v0.1.0 §Acceptance "non-trivial end-to-end demo as integration test in tests/e2e/" satisfied
affects:
  - tests/ (new top-level directory; v0.1.0 ships only tests/e2e/full_loop.bats; future tests/integration/, tests/manual/ slot in alongside per RESEARCH §"Recommended Project Structure")
  - bats suite delta: 80/0 -> 81/0 (exactly one new bats file contributing exactly one new @test)
  - .planning/STATE.md (task.completed event for 05-03-01; plan.completed for 05-03)
  - .planning/ROADMAP.md (Phase 5 progress row 2/4 -> 3/4)
tech-stack:
  added: []
  patterns:
    - Path-relative loader from tests/e2e/ to ../../core/tests/test_helper/{bats-support,bats-assert}/load (no new submodule, no new helpers directory)
    - chantier new + git init main-checkout pattern (D-05 lax interpretation per Phase 4 A5; not the linked-worktree pattern from adapter_claude_code_e2e.bats)
    - Skill body inlined into synthetic project via three cp calls (SKILL.md + PRESSURE.md + run.sh) -- mirrors skill_test_driven_development_e2e.bats:178-183
    - Two-task PLAN.md heredoc with depends_on: [] on t1 and depends_on: [t1] on t2 (single PLAN_EOF quoted heredoc for verbatim YAML)
    - Sequential operator-orders-dispatch (Discretion #3; t1 then t2; out-of-order failure mode documented but not exercised)
    - Six-event STATE.md count pattern (grep -cE per event name; multiplied x2 over the analog because two tasks dispatch)
    - Zero-task.failed assertion with `|| true` defending against grep -c exit 1 on no-match
    - F3-fix-proof assertion at full-loop scale ([ -e ".chantier/dossiers/t2/upstream/t1/output.json" ]) -- the load-bearing dogfood signal
    - CHANTIER_E2E_REAL_CLAUDE=1 opt-in env gate in setup() AND defensive self-assertion in @test body (Pitfall 8 double-belt)
    - HARNESS_DENY_LIST_CHECK marker convention on the four lines mentioning harness identifiers (defensive future-proofing; current NFR-001 scope does NOT walk tests/ but the markers prevent self-trigger if the scope ever widens)
    - Stub heredoc byte-identical across the three bats files (adapter_claude_code_e2e + adapter_upstream_e2e + tests/e2e/full_loop) per Discretion #8
key-files:
  created:
    - tests/e2e/full_loop.bats (307 lines, 1 @test, ~80-line setup() block with inline CHANTIER_CLAUDE_BIN stub + CHANTIER_E2E_REAL_CLAUDE opt-in conditional)
    - .planning/phases/05-dogfood-e2e/05-03-SUMMARY.md (this file)
  modified:
    - .planning/STATE.md (task.completed for 05-03-01 + plan.completed for 05-03; progress frontmatter completed_plans 18 -> 19, percent 90 -> 95)
    - .planning/ROADMAP.md (05-03-PLAN.md row checkbox flipped; Phase 5 progress 2/4 -> 3/4)
decisions:
  - D-03 implemented: single-bats file at tests/e2e/, loads same submodule helpers via path-relative loader, scaffolds via real chantier new, exercises the full multi-task chain through adapters/claude-code/run-task.sh, validates via chantier validate-task
  - D-04 implemented: CHANTIER_CLAUDE_BIN inline-stub default + CHANTIER_E2E_REAL_CLAUDE=1 opt-in gate; CI never sets the opt-in flag; Pitfall 8 mitigation via @test body self-assertion catches silent fall-through
  - Discretion #8 implemented: stub duplicated inline (not extracted to core/tests/test_helper/stubs/claude.sh) -- the e2e variant has the same shape as Phase 4 D-15 and no e2e-specific behavior is needed
  - Discretion #9 implemented: project name `chantier-e2e-dogfood` (descriptive kebab-case)
  - Discretion #3 implemented: operator-orders-dispatch (test dispatches t1 then t2; the F3 fix from Plan 05-01 handles the depends_on staging at dispatch time)
metrics:
  duration: ~20 minutes
  completed: 2026-05-30
  tasks: 1
  commits: 1 (test only; this Summary's commit is the metadata commit)
  bats_delta: 80/0 -> 81/0 (+1 test, +1 file, +1 new top-level directory tests/e2e/)
  files_touched: 1 (one new; zero modified)
  rule_4_checkpoints: 0
  rule_1_3_autofixes: 1 (Rule 1 -- `|| true` added to the `_failed=$(grep -c ...)` line because grep -c returns exit 1 when no match is found, and `set -e` from bats aborted the @test on the legitimately-zero count)
---

# Phase 5 Plan 03: tests/e2e/full_loop.bats Dogfood E2E Integration Test - Summary

One-liner: Ships `tests/e2e/full_loop.bats` (~307 lines, 1 @test) -- the Phase 5 Chantier-on-Chantier proof that runs the FULL new-project -> plan -> execute -> verify loop using only Chantier-built tooling (chantier new + adapters/claude-code/run-task.sh + chantier validate-task + chantier state append via the skill body), promoting ROADMAP SC#1, SC#2, SC#3 from claim to enforcement and satisfying the v0.1.0 acceptance criterion for a non-trivial end-to-end demo in `tests/e2e/`.

## What shipped

### Task 05-03-01 (commit `29f3d24`)

Authored `tests/e2e/full_loop.bats` -- one comprehensive @test executing the full Chantier loop end-to-end:

| Step | What it exercises |
|------|-------------------|
| 1. Pitfall 8 self-assertion | `[ -n "$CHANTIER_CLAUDE_BIN" ] && [ -x "$CHANTIER_CLAUDE_BIN" ]` when opt-in unset; catches silent fall-through to real claude binary |
| 2. `chantier new chantier-e2e-dogfood` | SC#1 scaffold step; asserts all five scaffolded files land (PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md, config.json) |
| 3. `git init -q` + commit | D-05 lax interpretation: main checkout satisfies `git rev-parse --show-toplevel` (Phase 4 A5) |
| 4. Copy live skill body | `cp` SKILL.md + PRESSURE.md + run.sh from `$REPO_ROOT/skills/test-driven-development/` into the synthetic project's `skills/test-driven-development/`; commit |
| 5. Write synthetic two-task PLAN.md | Quoted `PLAN_EOF` heredoc; t1 `depends_on: []`, t2 `depends_on: [t1]`; same four-scalar deterministic TDD inputs (target_file: src/dummy.sh, test_framework: bats, phase: red, test_command: false); commit |
| 6. Sequential dispatch | `run "$ADAPTER" t1` then `run "$ADAPTER" t2`; error-surface wrapper on both (adapter exit + output + STATE.md to stderr on non-zero); SC#1 |
| 7. validate-task green on both | `run "$CHANTIER" validate-task t1` then t2; gate-idempotence (adapter already ran validate-task internally) |
| 8. STATE.md event-count assertions | `task.started == 2`, `skill.completed == 2`, `task.completed == 2`, `task.failed == 0` (`\|\| true` on the no-match grep); SC#2 |
| 9. F3 fix proof at full-loop scale | `[ -e ".chantier/dossiers/t2/upstream/t1/output.json" ]`; D-01 + D-02 propagated to e2e scale; load-bearing dogfood signal |
| 10. NFR-004 self-defense | Final Pitfall 8 re-assertion after dispatch; SC#3 |

Bats output (one green ok line):

```
1..1
ok 1 tests/e2e/full_loop: chantier new + 2-task chain + adapter dispatch + validate-task green (SC#1, SC#2, SC#3, D-01, D-02, D-03, D-04)
```

Full suite output:

```
$ bats core/tests/ tests/e2e/ | tail -3
ok 79 missing TASK_ID arg exits 3 with usage message
ok 80 unknown task ID exits 3 with not-found message
ok 81 tests/e2e/full_loop: chantier new + 2-task chain + adapter dispatch + validate-task green (SC#1, SC#2, SC#3, D-01, D-02, D-03, D-04)
```

81/0 reported on the final line; zero `not ok` lines.

## Verification result matrix

| Criterion | Evidence | Status |
|-----------|----------|--------|
| **D-03 implemented** | Single file `tests/e2e/full_loop.bats` at new top-level `tests/e2e/`; loads `../../core/tests/test_helper/bats-{support,assert}/load`; invokes real `chantier new` + multi-task dispatch + `chantier validate-task`. | OK |
| **D-04 implemented** | `setup()` sets `CHANTIER_CLAUDE_BIN` unless `CHANTIER_E2E_REAL_CLAUDE=1`; `@test` body asserts `[ -n "$CHANTIER_CLAUDE_BIN" ] && [ -x "$CHANTIER_CLAUDE_BIN" ]` twice (defensive double-check); `grep -c CHANTIER_E2E_REAL_CLAUDE tests/e2e/full_loop.bats` returns 6. | OK |
| **bats tests/e2e/full_loop.bats green** | Default invocation (no opt-in) reports `1..1` followed by `ok 1`; exit 0. | OK |
| **bats core/tests/ tests/e2e/ 81/0** | Reports `ok 81` on the final line; zero `not ok` lines. | OK |
| **Phase 4 e2e unaffected** | `bats core/tests/adapter_claude_code_e2e.bats` reports `1..1 ok 1`. | OK |
| **Plan 05-01 regression unaffected** | `bats core/tests/adapter_upstream_e2e.bats` reports `1..1 ok 1`. | OK |
| **Plan 05-02 NFR audits unaffected** | `bats core/tests/nfr_audits.bats` reports `1..6` followed by six `ok` lines. | OK |
| **adapter_isolation unaffected** | `bats core/tests/adapter_isolation.bats` reports `1..1 ok 1`. | OK |
| **chantier --self-test unaffected** | `./core/bin/chantier --self-test` exits 0 with `self-test: all green`. | OK |
| **HARNESS_DENY_LIST_CHECK density** | `grep -c HARNESS_DENY_LIST_CHECK tests/e2e/full_loop.bats` returns 4 (>= 2 required). | OK |
| **Effective deny-list residue** | `grep -v '^#' ... \| grep -v 'HARNESS_DENY_LIST_CHECK' \| grep -cE 'mcp__\|claude_ai_\|@codebase\|claude-code\|cursor\|codex-cli\|copilot-cli\|gemini-cli\|opencode'` returns 0. | OK |
| **NFR-005 English-only** | `grep -c '[À-ÿ]' tests/e2e/full_loop.bats` returns 0. | OK |
| **Stub heredoc byte-identical** | 3-way diff of the `<<'STUB_EOF' ... STUB_EOF` block across `tests/e2e/full_loop.bats`, `core/tests/adapter_claude_code_e2e.bats`, `core/tests/adapter_upstream_e2e.bats` -- all three identical (zero diff output). | OK |
| **CHANTIER_E2E_REAL_CLAUDE opt-in wired** | `grep -c CHANTIER_E2E_REAL_CLAUDE tests/e2e/full_loop.bats` returns 6 (>= 2 required). | OK |
| **Discretion #9 project name** | `grep -c chantier-e2e-dogfood tests/e2e/full_loop.bats` returns 3 (>= 1 required). | OK |
| **Plan automated verify** | `cd "$(git rev-parse --show-toplevel)" && unset CHANTIER_E2E_REAL_CLAUDE && bats tests/e2e/full_loop.bats && bats core/tests/ tests/e2e/` exits 0. | OK |

## Stub heredoc byte-identical proof (3-way diff)

```
$ diff <(awk '/^cat > "\$BATS_TEST_TMPDIR\/stub\/claude" <<'\''STUB_EOF'\''$/,/^STUB_EOF$/' tests/e2e/full_loop.bats) \
        <(awk '/^cat > "\$BATS_TEST_TMPDIR\/stub\/claude" <<'\''STUB_EOF'\''$/,/^STUB_EOF$/' core/tests/adapter_claude_code_e2e.bats)
$ echo $?
0

$ diff <(awk '/^cat > "\$BATS_TEST_TMPDIR\/stub\/claude" <<'\''STUB_EOF'\''$/,/^STUB_EOF$/' tests/e2e/full_loop.bats) \
        <(awk '/^cat > "\$BATS_TEST_TMPDIR\/stub\/claude" <<'\''STUB_EOF'\''$/,/^STUB_EOF$/' core/tests/adapter_upstream_e2e.bats)
$ echo $?
0
```

All three sources carry the byte-identical CHANTIER_CLAUDE_BIN stub heredoc body per Discretion #8 (inline duplication over shared-helper extraction at v0.1 scale).

## HARNESS_DENY_LIST_CHECK marker count and effective residue

```
$ grep -c 'HARNESS_DENY_LIST_CHECK' tests/e2e/full_loop.bats
4

$ grep -v '^#' tests/e2e/full_loop.bats \
    | grep -v 'HARNESS_DENY_LIST_CHECK' \
    | grep -cE 'mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode'
0
```

Four markers on the lines that mention harness identifiers (`# HARNESS_DENY_LIST_CHECK` ends each); effective deny-list residue under the standard filter is 0. The current NFR-001 audit walks `find core skills adapters` only (NOT `tests/`), so the markers are defensive future-proofing for the case where the audit scope ever widens to include `tests/`. The marker convention works today regardless.

## NFR-005 English-only confirmation

```
$ grep -c '[À-ÿ]' tests/e2e/full_loop.bats
0
```

Zero accented chars; the file body contains no French. The NFR-005 stop-word density scan (>= 5 French stop-words per file) walks `tests/` (line 208 of `nfr_audits.bats`: `_scan_dirs='docs/adr docs/vision.md docs/research core skills adapters tests'`); `tests/e2e/full_loop.bats` is in scope but contains zero stop-word hits.

## Manual probe for the CHANTIER_E2E_REAL_CLAUDE opt-in path (NOT a CI gate)

```
$ CHANTIER_E2E_REAL_CLAUDE=1 bats tests/e2e/full_loop.bats
# Result depends on whether the dev host has a real `claude` binary on PATH.
# If yes: the adapter dispatches via the real binary; the test exits 0 if
#         the real claude binary returns sane output for both dispatches.
# If no:  the adapter exits 3 with `run-task: claude binary not found and
#         CHANTIER_CLAUDE_BIN unset (D-15)` -- and the test fails fast at
#         the first `run "$ADAPTER" t1` assertion.
```

The opt-in path is dev-only by D-04 design. CI never sets `CHANTIER_E2E_REAL_CLAUDE=1`, so the default-stub path is the only one exercised in automated builds; NFR-004 default-offline holds.

## SC#1 / SC#2 / SC#3 -> assertion mapping

| ROADMAP SC | Plan claim | Assertion location in tests/e2e/full_loop.bats | Status |
|------------|------------|------------------------------------------------|--------|
| SC#1 | Full new-project -> plan -> execute -> verify loop using only Chantier-built tooling | Step 2 (`chantier new`), Step 4 (skill copy), Step 5 (PLAN.md write), Step 6 (sequential adapter dispatch), Step 7 (validate-task) | Enforced |
| SC#2 | Populated STATE.md with no contract violations + validate-task green | Step 8 (six-event count assertion + zero task.failed) + Step 7 (validate-task t1 + t2 both exit 0) | Enforced |
| SC#3 | Passes in CI without network access | Step 1 + Step 10 (Pitfall 8 self-assertion); setup() conditional `CHANTIER_E2E_REAL_CLAUDE` opt-in gate keeps the stub in place by default | Enforced |
| (SC#4) | Each of NFR-001..NFR-006 independently verified | Already enforced by Plan 05-02 `core/tests/nfr_audits.bats`; not in this plan's scope but listed for completeness | Inherited (Plan 05-02) |
| (SC#5) | ROADMAP migration + cutover.completed event | Handled by Plan 05-04 (Phase close); not in this plan's scope | Pending (Plan 05-04) |

## Citation -- what was closed

`.planning/REQUIREMENTS.md` §Acceptance "v0.1.0 ships when" line:

> A non-trivial end-to-end demo exists as an integration test in `tests/e2e/`.

Closed by commit `29f3d24` (`tests/e2e/full_loop.bats` -- 307 lines, 1 @test, the chantier-on-chantier full-loop proof).

## Deviations from plan

**Auto-fixed Issues**

1. **[Rule 1 - Bug] `_failed` grep -c needs `\|\| true` to defend against set -e**
   - **Found during:** Task 05-03-01 first bats run after writing the file.
   - **Issue:** The line `_failed=$(grep -cE '"event":"task\.failed"' .planning/STATE.md)` returned exit 1 because no `task.failed` events were present in STATE.md (the legitimate happy-path outcome). With `set -e` implicit in the bats @test wrapper, the @test aborted before reaching the `[ "$_failed" -eq 0 ]` assertion. The bats output showed:
     ```
     # (in test file tests/e2e/full_loop.bats, line 276)
     #   `_failed=$(grep -cE '"event":"task\.failed"' .planning/STATE.md)' failed
     ```
   - **Fix:** Appended ` || true` to the grep -c command and added an explanatory comment citing the failure mode. The analog files (adapter_upstream_e2e.bats) don't expose this because they only count events they expect to exist (positive counts); the new file's stricter zero-failures assertion needed the defensive `|| true`. The fix is consistent with the pattern used in skills/test-driven-development/run.sh:130 (`grep -cE '^(ok|not ok) [0-9]+' "$TASK_DIR/${PHASE_FLAG}.out" 2>/dev/null || true`).
   - **Files modified:** `tests/e2e/full_loop.bats` (one line patched pre-commit; the file landed already passing).
   - **Commit:** 29f3d24 (the fix was applied before the first commit; the file landed already passing).

No Rule-2 (missing critical functionality), Rule-3 (blocking issues), or Rule-4 (architectural) deviations. The task executed end-to-end exactly as the plan specified, with the one Rule-1 correction above.

## Threat Flags

None. The new artifact introduces no new threat surface beyond what the plan's `<threat_model>` modeled (T-NFR-004 mitigated by inline stub, T-05-03-PITFALL-8 mitigated by defensive self-assertion, T-05-03-SCAFFOLD-GAP mitigated by per-file existence assertions after `chantier new`, T-05-03-NFR-001 mitigated by HARNESS_DENY_LIST_CHECK markers + scope-out via current NFR-001 walk, T-05-03-PATH-SPACE mitigated by uniform double-quoting + `pwd -P`, T-05-03-BSD-GNU mitigated by POSIX-only constructs). All mitigations from the threat register are honored.

## Known Stubs

None. The integration test is substantively complete: it exercises the real `chantier new` binary, the real `adapters/claude-code/run-task.sh` (with the Plan 05-01 F3 fix), the real `skills/test-driven-development/` body, and the real `chantier validate-task` gates. The CHANTIER_CLAUDE_BIN stub is the deliberate hermeticity choice per D-04 + Phase 4 D-15, not a stub-as-placeholder.

## Self-Check: PASSED

- File `tests/e2e/full_loop.bats`: FOUND (307 lines, 1 @test).
- File `.planning/phases/05-dogfood-e2e/05-03-SUMMARY.md`: FOUND (this file).
- Commit `29f3d24`: FOUND in `git log --oneline -3` (test commit).
- bats `tests/e2e/full_loop.bats` 1/1: confirmed via `bats tests/e2e/full_loop.bats | tail -1` showing `ok 1`.
- bats `core/tests/ tests/e2e/` 81/0: confirmed via `bats core/tests/ tests/e2e/ | tail -1` showing `ok 81`.
- adapter_isolation, adapter_claude_code_e2e, adapter_upstream_e2e, nfr_audits all green: confirmed via combined run (9/0).
- chantier `--self-test` green: confirmed via `./core/bin/chantier --self-test` exit 0.
- HARNESS_DENY_LIST_CHECK count >= 2: confirmed via `grep -c HARNESS_DENY_LIST_CHECK tests/e2e/full_loop.bats` returning 4.
- Effective deny-list residue 0: confirmed via the standard `grep -v '^#' | grep -v 'HARNESS_DENY_LIST_CHECK' | grep -cE ...` pipeline.
- NFR-005 English-only: confirmed via `grep -c '[À-ÿ]' tests/e2e/full_loop.bats` returning 0.
- Stub heredoc byte-identical to both analogs: confirmed via two awk-bracketed `diff` invocations (zero diff output).
- CHANTIER_E2E_REAL_CLAUDE mentions >= 2: confirmed via `grep -c CHANTIER_E2E_REAL_CLAUDE tests/e2e/full_loop.bats` returning 6.
- Discretion #9 project name: confirmed via `grep -c chantier-e2e-dogfood tests/e2e/full_loop.bats` returning 3.
