---
phase: 05-dogfood-e2e
plan: 01
subsystem: claude-code-adapter
tags: [adapter, f3-fix, depends_on, upstream, posix-shell, tdd, dogfood, phase-05]
requires:
  - adapters/claude-code/run-task.sh (Phase 4 plan 02 -- baseline before F3 patch)
  - adapters/claude-code/README.md (Phase 4 plan 02 -- baseline before depends_on prose)
  - core/tests/adapter_claude_code_e2e.bats (Phase 4 plan 03 -- structural analog)
  - skills/test-driven-development (Phase 3 -- the skill exercised twice in the chain)
  - core/tests/fixtures/skills/test-driven-development/dossier/inputs.yml (Phase 3 -- the four-scalar deterministic red fixture cloned into the two-task PLAN.md)
provides:
  - F3 fix loop in run-task.sh staging upstream/<tN>/output.json per depends_on item (D-01)
  - core/tests/adapter_upstream_e2e.bats regression test (D-02; bats 74/0)
  - README.md prose documenting the new operator-observable behavior in English (NFR-005)
  - Closes Finding F3 from .planning/phases/04-claude-code-adapter/04-SUMMARY.md §Handoff Notes
  - Demonstrable TDD red->green sequence with two atomic commits (the dogfood proof)
affects:
  - adapters/claude-code/run-task.sh (one extraction line + ~17-line loop block)
  - adapters/claude-code/README.md (dossier-layout table row updated + new paragraph)
  - .planning/STATE.md (task.completed t1, task.completed t2, plan.completed 05-01)
  - .planning/ROADMAP.md (Phase 5 plan progress row for 05-01)
tech-stack:
  added: []
  patterns:
    - byte-template clone of state_reads symlink loop for the F3 fix (same printf | while IFS= read -r ... [ -n ... ] || continue idiom)
    - ln -s with cp fallback (preserved from state_reads loop)
    - operator-orders-dispatch with exit-2 + stderr message when upstream output missing (Discretion #3)
    - per-file output.json symlink shape over full-dir symlink (ADR 0001 Surface 2 line 134 precedent)
    - HARNESS_DENY_LIST_CHECK marker on every comment line mentioning a deny-list token
    - byte-identical CHANTIER_CLAUDE_BIN stub heredoc inline-duplicated from adapter_claude_code_e2e.bats (Discretion #8)
key-files:
  created:
    - core/tests/adapter_upstream_e2e.bats
    - .planning/phases/05-dogfood-e2e/05-01-SUMMARY.md
  modified:
    - adapters/claude-code/run-task.sh (DEPENDS_ON extraction + F3 fix loop; 18 net additions, 0 deletions)
    - adapters/claude-code/README.md (dossier layout row + new English paragraph; 13 net additions, 1 deletion)
decisions:
  - F3 fix shipped as per-file output.json symlink (not full-dir symlink) per Discretion #2 + ADR 0001 Surface 2 line 134 precedent
  - Missing-upstream case exits 2 with stderr; no topological sort in adapter (Discretion #3 operator-orders-dispatch)
  - CHANTIER_CLAUDE_BIN stub inline-duplicated in new bats file (Discretion #8; no shared helper extraction at this scale)
  - HARNESS_DENY_LIST_CHECK markers placed only on lines that need them to keep adapter_isolation green
metrics:
  duration: ~25 minutes
  completed: 2026-05-30
  tasks: 2
  commits: 2 (test + feat)
  bats_delta: 73/0 -> 74/0 (+1 test)
  files_touched: 3 (1 new, 2 modified)
  rule_4_checkpoints: 0
  rule_1_3_autofixes: 1 (added HARNESS_DENY_LIST_CHECK markers to two comment lines that the audit flagged post-write)
---

# Phase 5 Plan 01: Dogfood F3 fix end-to-end via TDD - Summary

One-liner: F3 dogfood fix shipped red-then-green using the test-driven-development skill itself -- the failing-then-passing bats sequence on `core/tests/adapter_upstream_e2e.bats` is the dogfood proof, and the adapter's new `depends_on` loop now stages `upstream/<tN>/output.json` per ADR 0001 Surface 2.

## What shipped

### Task 1 - RED (commit `d133386`)

Authored `core/tests/adapter_upstream_e2e.bats`: a 254-line bats file with one `@test` block exercising the F3 dogfood end-to-end. The test sets up a real linked git worktree, copies the live `test-driven-development` skill body into it, writes a synthetic two-task `PLAN.md` (`t1` with `depends_on: []`, `t2` with `depends_on: [t1]`), and dispatches `$ADAPTER t1` then `$ADAPTER t2` under the verbatim Phase 4 `CHANTIER_CLAUDE_BIN` stub. After both dispatches, the test asserts:

1. Both adapter invocations exit 0.
2. `t1`'s `output.json` lands at `$WORKTREE/.planning/phases/dogfood-phase/tasks/t1/output.json` (Phase 4 plan 03 Surface 3 propagation working).
3. Three D-03 events per task (`task.started`, `skill.completed`, `task.completed`) - 6 total events.
4. `chantier validate-task t1` and `chantier validate-task t2` both exit 0 (all 5 gates pass per task).
5. **The F3-specific assertion**: `[ -e "$WORKTREE/.chantier/dossiers/t2/upstream/t1/output.json" ]`.

Against the Phase 4 baseline adapter (no F3 fix), this final assertion fails:
```
not ok 1 adapter_upstream_e2e: F3 fix -- depends_on: [t1] stages upstream/t1/output.json into t2's dossier (D-01, D-02)
# (in test file core/tests/adapter_upstream_e2e.bats, line 250)
#   `[ -e "$DOSSIER_T2/upstream/t1/output.json" ]' failed
```

This is the RED step. `bats core/tests/adapter_upstream_e2e.bats` exited 1; all 73 prior tests remained green (bats suite: 73 ok + 1 not ok = 74 total, the F3 line being the only new failure).

### Task 2 - GREEN (commit `ed6dfe6`)

Patched `adapters/claude-code/run-task.sh` with the F3 fix loop. Two insertion points:

**Insertion 1** (after line 111, alongside existing extraction calls):
```sh
DEPENDS_ON=$(extract_task_field  "$TASK_ID" depends_on   block-dash   "$PLAN_PATH")
```

**Insertion 2** (after the state_reads symlink loop, before Section 3 header):
```sh
# F3 fix (Phase 5 D-01): stage upstream/<tN>/output.json for every tN in depends_on.
# Per-file symlink shape (ADR 0001 Surface 2 line 134 example uses upstream/t0/output.json).
# Symlink chosen over copy: tighter least-privilege; downstream reads only.
# If upstream output is missing, exit 2 (invocation error) -- operator must dispatch tN first.
# Empty depends_on is a no-op per Pitfall 4 (printf | while ... [ -n ... ] || continue).
printf '%s\n' "$DEPENDS_ON" | while IFS= read -r _up_task; do
    [ -n "$_up_task" ] || continue
    _up_out="$WORKTREE/.planning/phases/$PHASE/tasks/$_up_task/output.json"
    if [ ! -f "$_up_out" ]; then
        printf 'run-task: depends_on=%s but %s not found; dispatch %s first\n' \
            "$_up_task" "$_up_out" "$_up_task" >&2
        exit 2
    fi
    mkdir -p "$DOSSIER/upstream/$_up_task"
    ln -s "$_up_out" "$DOSSIER/upstream/$_up_task/output.json" 2>/dev/null || \
        cp "$_up_out" "$DOSSIER/upstream/$_up_task/output.json"
done
```

The loop is the byte-template twin of the existing state_reads loop at lines 139-143: same `printf | while IFS= read -r ... [ -n ... ] || continue` shape, same `ln -s ... 2>/dev/null || cp` fallback, same POSIX-sh constraint (NFR-002). Net diff to `run-task.sh`: 18 additions, 0 deletions.

**README update**: Updated the dossier-layout code block to show `upstream/<tN>/output.json` (was: `reserved for depends_on outputs (Phase 5)`) and appended a paragraph documenting the new operator-observable behavior - the staging pattern, the operator-dispatch-order requirement, and the exit-2 stderr message format. All in English; `grep '[À-ÿ]' adapters/claude-code/README.md` returns 0 (NFR-005 respected).

## Verification result matrix

| Decision | Evidence | Status |
|----------|----------|--------|
| **D-01** (F3 fix in run-task.sh) | `grep -c "F3 fix" adapters/claude-code/run-task.sh` returns 1; `grep -c "DEPENDS_ON=" adapters/claude-code/run-task.sh` returns 1; `bats core/tests/adapter_upstream_e2e.bats` exits 0 with `[ -e $DOSSIER_T2/upstream/t1/output.json ]` passing. Commit `ed6dfe6`. | ✓ |
| **D-02** (TDD two atomic commits, red->green) | `git log --oneline -2`: `ed6dfe6 feat(05-01): stage upstream/<tN>/output.json from depends_on (F3 fix)` on top, `d133386 test(05-01): add failing F3 regression test (adapter_upstream_e2e.bats)` below. `bats core/tests/adapter_upstream_e2e.bats` exit code transitioned 1 -> 0 across the two commits. | ✓ |
| **NFR-001** (no harness-id leakage outside path-only carve-out) | `bats core/tests/adapter_isolation.bats` exits 0 with the new bats file present; 7 HARNESS_DENY_LIST_CHECK markers placed on lines that legitimately mention deny-list tokens. | ✓ |
| **NFR-002** (POSIX-sh purity) | `shellcheck --shell=sh adapters/claude-code/run-task.sh` exits 0 post-patch. No bash-isms (`[[ ]]`, `<<<`, `mapfile`, arrays); new loop uses only `printf`, `while IFS= read -r`, `[`-test, `mkdir -p`, `ln -s`, `cp`. | ✓ |
| **NFR-005** (English-only docs) | `grep -c '[À-ÿ]' adapters/claude-code/README.md` returns 0. No French leakage in README diff or in run-task.sh comments. | ✓ |
| Phase 4 regression preserved | `bats core/tests/adapter_claude_code_e2e.bats` exits 0 (single-task Pitfall 4 empty-depends_on no-op holds). | ✓ |
| Bats suite delta | 73/0 (Phase 4 close) -> 74/0 (Phase 5 plan 01 close); exactly one new test file with exactly one new `@test`. | ✓ |
| F3 finding closed | Phase 4 SUMMARY §Handoff Notes line "F3: adapter emits empty upstream/ for tasks with depends_on" is resolved by commit `ed6dfe6` in `run-task.sh` and by commit `d133386` in `adapter_upstream_e2e.bats` (regression). | ✓ |

## Git log excerpt (the TDD dogfood proof)

```
ed6dfe6 feat(05-01): stage upstream/<tN>/output.json from depends_on (F3 fix)
d133386 test(05-01): add failing F3 regression test (adapter_upstream_e2e.bats)
```

Two commits, test before feat, both signed-off under the Phase 4 collective-copyright convention (no individual `Co-Authored-By` tags, per Chantier `LICENSE` and `LICENSE-CREDITS`). The bats exit-code transition (1 -> 0) across these two commits is the measurable TDD proof for the dogfood per Phase 3 D-07 ("every invariant has a measurable proof"): the executing skill is `test-driven-development`, the failing-before-passing sequence is observable, and the bats run shows which assertion failed at the RED step (the F3-specific line, not any prior assertion).

## README diff excerpt

```diff
 inputs.yml                  -- extracted from PLAN.md inputs: block
 env.sh                      -- the three exports above
 reads/                      -- symlinks to declared state_reads paths
-upstream/                   -- reserved for depends_on outputs (Phase 5)
+upstream/<tN>/output.json   -- one entry per depends_on task ID
 skill/SKILL.md              -- copied from skills/<skill-id>/
 skill/PRESSURE.md           -- copied from skills/<skill-id>/
 skill/run.sh                -- copied from skills/<skill-id>/ (executable)
 subagent.transcript.log     -- real-claude path only
 ```
 
+When a task declares `depends_on: [tN, ...]` in its PLAN.md task block, the
+adapter populates `upstream/<tN>/output.json` as a symlink (with `cp`
+fallback when the filesystem rejects symlinks) to the prior task's
+`.planning/phases/<phase>/tasks/<tN>/output.json`. The depending task's
+skill body can then read upstream artifacts via `./upstream/<tN>/output.json`
+from inside the dossier. The operator dispatches upstream tasks first; if a
+`depends_on` target's `output.json` is not yet on disk, the adapter exits 2
+(invocation error) with a clear `depends_on=<tN> but <path> not found;
+dispatch <tN> first` message on stderr. v0.1 does not topologically sort
+the dispatch order in the adapter; future versions may add that affordance.
+
```

## Deviations from plan

**Auto-fixed Issues**

1. **[Rule 2 - Compliance] Added HARNESS_DENY_LIST_CHECK markers to two comment lines flagged by the cross-tree audit**
   - **Found during:** Task 05-01-01 immediately after Write (before commit)
   - **Issue:** The new bats file's comment header carried two lines mentioning the deny-list tokens `04-claude-code-adapter` (path reference to Phase 4 dir) and `claude-code/run-task.sh` (path reference to the adapter file). Both were inside `#` comment blocks and not marked with `HARNESS_DENY_LIST_CHECK`. The audit at `adapter_isolation.bats` (which runs `grep -v 'HARNESS_DENY_LIST_CHECK'` before the deny-list `grep`) flagged the new bats file when it was first written.
   - **Fix:** Appended ` # HARNESS_DENY_LIST_CHECK` to the two flagged lines. The audit pattern is per Phase 4 D-11 / RESEARCH A3 marker convention. No structural change to the test logic; pure annotation.
   - **Files modified:** `core/tests/adapter_upstream_e2e.bats` (two lines).
   - **Commit:** d133386 (the marker fixes were applied pre-commit; the file landed already audit-compliant).

No Rule-1 (bug) or Rule-3 (blocking) issues. No Rule-4 (architectural) checkpoints. The plan executed exactly as written from `read_first` through `done` for both tasks.

## Threat Flags

None. The F3 patch introduces no new threat surface beyond what was modeled in the plan's `<threat_model>` (T-05-01-SYMLINK / T-05-01-INJECTION / T-05-01-PORTABILITY / T-05-01-EMPTY-LIST / T-05-01-NFR-001-DRIFT / T-05-01-SC). All mitigations from the threat register are in place: the symlink target is derived from already-validated `extract_task_field` output, the existence check (`[ ! -f "$_up_out" ]`) catches missing upstream files and exits 2 before any filesystem write, variable references are double-quoted, and the loop reuses the proven `state_reads` portable idiom.

## Citation - what was closed

Phase 4 `.planning/phases/04-claude-code-adapter/04-SUMMARY.md` §Handoff Notes line:
> **F3** -- adapter emits empty `upstream/` directory for tasks with `depends_on`; deferred to Phase 5 per the comment at `run-task.sh:139` ("upstream/ on depends_on deferred to Phase 5").

Resolved by commits `d133386` (regression test) and `ed6dfe6` (fix).

## Self-Check: PASSED

- File `core/tests/adapter_upstream_e2e.bats`: FOUND.
- File `adapters/claude-code/run-task.sh`: FOUND (modified, 19 net additions visible in `git diff HEAD~1`).
- File `adapters/claude-code/README.md`: FOUND (modified, 13 net additions visible in `git diff HEAD~1`).
- File `.planning/phases/05-dogfood-e2e/05-01-SUMMARY.md`: FOUND (this file).
- Commit `d133386`: FOUND in `git log --oneline -3`.
- Commit `ed6dfe6`: FOUND in `git log --oneline -3`.
- Bats suite 74/0: confirmed via `bats core/tests/ | tail -1` showing `ok 74 unknown task ID exits 3 with not-found message`.
- shellcheck clean: confirmed via `shellcheck --shell=sh adapters/claude-code/run-task.sh; echo $?` returning 0.
- adapter_isolation green: confirmed via `bats core/tests/adapter_isolation.bats` exit 0.
- adapter_claude_code_e2e green: confirmed via `bats core/tests/adapter_claude_code_e2e.bats` exit 0.
- NFR-005 English-only: confirmed via `grep -c '[À-ÿ]' adapters/claude-code/README.md` returning 0.
