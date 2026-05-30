#!/usr/bin/env bats

# F3 regression test for adapters/claude-code/run-task.sh (Phase 5 / D-01 + D-02). # HARNESS_DENY_LIST_CHECK
#
# This file exists to close Finding F3 from the Phase 4 handoff:
# .planning/phases/04-claude-code-adapter/04-SUMMARY.md §Handoff Notes records # HARNESS_DENY_LIST_CHECK
# that the adapter emits an empty `upstream/` directory in every dossier even
# when a task declares `depends_on: [tN]`. Phase 5 D-01 fixes that gap; this
# bats file is the regression that demonstrates the fix red-then-green.
#
# Two-task chain (Phase 5 D-02):
#   t1: depends_on: []          -- produces output.json
#   t2: depends_on: [t1]        -- proves upstream/t1/output.json is staged
#
# The skill dispatched twice is test-driven-development (Phase 5 D-02 lock).
# Both tasks consume the deterministic red-phase fixture (test_command:
# "false"), so the red-step exit is 1 every run, and the round-trip is
# offline + deterministic per NFR-004.
#
# RED step: with the F3 fix NOT yet landed in adapters/claude-code/run-task.sh, # HARNESS_DENY_LIST_CHECK
# this file's F3-specific assertion (`[ -e "$DOSSIER_T2/upstream/t1/output.json" ]`)
# fails because the adapter emits empty `upstream/` regardless of depends_on.
# GREEN step (Task 05-01-02): patching run-task.sh with the depends_on loop
# makes that same assertion succeed.
#
# Discretion #11 (Phase 4 carry-forward concurrency lock) is NOT exercised
# here: the two-task chain is sequential by design (t1 then t2). Parked for
# v0.2 if real parallelism need surfaces.
#
# Setup mirrors core/tests/adapter_claude_code_e2e.bats:29-103 byte-shape-
# identically (loaders, REPO_ROOT canonicalization, TMPHOME pwd -P guard,
# git init + worktree add, inline CHANTIER_CLAUDE_BIN stub). The stub
# heredoc body is copied verbatim from the analog per 05-PATTERNS.md
# §"CHANTIER_CLAUDE_BIN stub" and RESEARCH Discretion #8 (inline-duplicate
# over shared-helper extraction at this scale).

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'

    # Repo-relative paths -- BATS_TEST_DIRNAME is core/tests/
    export CHANTIER="$BATS_TEST_DIRNAME/../bin/chantier"
    export FIXTURES="$BATS_TEST_DIRNAME/fixtures"
    export REPO_ROOT
    REPO_ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)
    export ADAPTER="$REPO_ROOT/adapters/claude-code/run-task.sh" # HARNESS_DENY_LIST_CHECK

    # Expose chantier on PATH so the skill's final `chantier state append`
    # call resolves inside the adapter subprocess.
    export PATH="$REPO_ROOT/core/bin:$PATH"

    # TMPHOME setup: per-@test isolated working tree, canonicalized via
    # pwd -P to avoid the macOS /var -> /private/var symlink mismatch.
    mkdir -p "$BATS_TEST_TMPDIR/home"
    cd "$BATS_TEST_TMPDIR/home"
    export TMPHOME
    TMPHOME=$(pwd -P)

    # D-05 worktree creation (Phase 4 carry-forward): operator pre-creates
    # the worktree; the test acts as operator. The adapter is invoked from
    # inside the worktree (git rev-parse --show-toplevel returns $WORKTREE).
    git init -q "$TMPHOME"
    cd "$TMPHOME"
    git config user.email "test@chantier"
    git config user.name "test"
    mkdir -p .planning/phases
    cat > .planning/STATE.md <<'EOF'
---
format_version: 0.1.0
---
EOF
    git add -A
    git commit -q -m "initial"

    WORKTREE_DIR="$BATS_TEST_TMPDIR/wt"
    git worktree add -q "$WORKTREE_DIR" -b test-branch
    export WORKTREE
    WORKTREE=$(cd "$WORKTREE_DIR" && pwd -P)

    # D-15 CHANTIER_CLAUDE_BIN stub (Phase 4 D-15 carry-forward via Phase 5
    # D-04). Single-quoted heredoc disables ALL expansion so the stub's own
    # $1, $PROMPT, $DOSSIER are NOT evaluated at bats-setup time. Body is
    # byte-identical to core/tests/adapter_claude_code_e2e.bats:84-100.
    mkdir -p "$BATS_TEST_TMPDIR/stub"
    cat > "$BATS_TEST_TMPDIR/stub/claude" <<'STUB_EOF'
#!/bin/sh
set -eu
PROMPT=""
while [ $# -gt 0 ]; do
    case "$1" in
        -p|--print) shift; PROMPT="$1" ;;
        *) ;;
    esac
    shift 2>/dev/null || true
done
DOSSIER=$(printf '%s\n' "$PROMPT" | grep -oE '/[^ "]+/\.chantier/dossiers/[^ "]+' | head -n 1)
[ -n "$DOSSIER" ] || { printf 'stub: no dossier in prompt\n' >&2; exit 1; }
printf 'subagent (stub): cd %s\n' "$DOSSIER"
cd "$DOSSIER" && . ./env.sh && sh ./skill/run.sh
exit $?
STUB_EOF
    chmod +x "$BATS_TEST_TMPDIR/stub/claude"
    export CHANTIER_CLAUDE_BIN="$BATS_TEST_TMPDIR/stub/claude"
}

@test "adapter_upstream_e2e: F3 fix -- depends_on: [t1] stages upstream/t1/output.json into t2's dossier (D-01, D-02)" {
    SKILL="test-driven-development"
    PHASE_DIR="dogfood-phase"

    # Copy the live test-driven-development skill body into the worktree.
    # The adapter resolves $WORKTREE/skills/$SKILL_ID/ and copies SKILL.md +
    # PRESSURE.md + run.sh into each task's dossier under skill/ (D-02 +
    # RESEARCH Pattern 2 self-contained dossier). The skill body is the
    # one being dogfooded -- it is what makes both t1 and t2 measurable.
    mkdir -p "$WORKTREE/skills/$SKILL"
    cp "$REPO_ROOT/skills/$SKILL/SKILL.md"    "$WORKTREE/skills/$SKILL/SKILL.md"
    cp "$REPO_ROOT/skills/$SKILL/PRESSURE.md" "$WORKTREE/skills/$SKILL/PRESSURE.md"
    cp "$REPO_ROOT/skills/$SKILL/run.sh"      "$WORKTREE/skills/$SKILL/run.sh"
    chmod +x "$WORKTREE/skills/$SKILL/run.sh"

    # Stage the skill body in git so the worktree has a clean commit floor.
    cd "$WORKTREE"
    git add -A
    git commit -q -m "scaffold-skill"

    # Two-task PLAN.md authoring per 05-PATTERNS.md §"Two-task PLAN.md
    # authoring". Single-quoted heredoc so YAML body is written verbatim
    # (no shell expansion at bats-eval time). Both tasks consume the same
    # deterministic four-scalar inputs fixture (target_file / test_framework
    # / phase / test_command) byte-identical to
    # core/tests/fixtures/skills/test-driven-development/dossier/inputs.yml.
    # t2 declares depends_on: [t1] -- this is the load-bearing line for F3.
    mkdir -p ".planning/phases/$PHASE_DIR"
    cat > ".planning/phases/$PHASE_DIR/PLAN.md" <<'PLAN_EOF'
---
plan_id: 01-dogfood
phase: dogfood-phase
created: 2026-05-30
status: draft
declared_skills: ["test-driven-development"]
---

## Task `t1` -- F3 dogfood upstream producer

```yaml
task: t1
skill: test-driven-development
inputs:
  target_file: "src/dummy.sh"
  test_framework: "bats"
  phase: "red"
  test_command: "false"
state_writes:
  - ".planning/phases/dogfood-phase/tasks/t1/"
depends_on: []
acceptance:
  - "A failing test was observed before any production code was written for this task."
  - "After the production change, the same test command exits zero."
```

## Task `t2` -- F3 dogfood downstream consumer

```yaml
task: t2
skill: test-driven-development
inputs:
  target_file: "src/dummy.sh"
  test_framework: "bats"
  phase: "red"
  test_command: "false"
state_writes:
  - ".planning/phases/dogfood-phase/tasks/t2/"
depends_on:
  - t1
acceptance:
  - "A failing test was observed before any production code was written for this task."
  - "After the production change, the same test command exits zero."
```
PLAN_EOF

    # Sequential dispatch -- t1 first, then t2. Operator-orders-dispatch
    # per Discretion #3 / RESEARCH Pitfall 4. A hypothetical out-of-order
    # invocation (`$ADAPTER t2` before `$ADAPTER t1`) would exit 2 with
    # stderr `run-task: depends_on=t1 but <path>/output.json not found;
    # dispatch t1 first` -- this regression test does NOT exercise that
    # failure mode (commented documentation only).

    # Dispatch t1: produces output.json which t2 will consume.
    cd "$WORKTREE"
    run "$ADAPTER" t1
    if [ "$status" -ne 0 ]; then
        printf 'adapter t1 exit: %s\n' "$status" >&2
        printf 'adapter t1 output: %s\n' "$output" >&2
        printf 'state log:\n' >&2
        cat "$WORKTREE/.planning/STATE.md" >&2 || true
    fi
    [ "$status" -eq 0 ]

    # Surface 3 propagation (Phase 4 plan 03 fix): t1's output.json must
    # land in its TASK_DIR so t2's F3 staging can target it.
    [ -f ".planning/phases/$PHASE_DIR/tasks/t1/output.json" ]

    # Dispatch t2: this is the F3-fix-exercising call. With the fix landed
    # (Task 05-01-02), the adapter parses depends_on:[t1] and stages
    # $DOSSIER_T2/upstream/t1/output.json before running the skill. Without
    # the fix (RED state pre-Task 05-01-02), the adapter still exits 0
    # (the dossier-staging step does not check depends_on) and the F3
    # assertion below is the one that fails.
    run "$ADAPTER" t2
    if [ "$status" -ne 0 ]; then
        printf 'adapter t2 exit: %s\n' "$status" >&2
        printf 'adapter t2 output: %s\n' "$output" >&2
        printf 'state log:\n' >&2
        cat "$WORKTREE/.planning/STATE.md" >&2 || true
    fi
    [ "$status" -eq 0 ]

    # Three-event-per-task signal (D-03 from Phase 4, multiplied by 2):
    # each adapter invocation emits task.started + skill.completed +
    # task.completed. Two invocations -> 6 events total.
    _started=$(grep -cE '"event":"task\.started"' "$WORKTREE/.planning/STATE.md")
    [ "$_started" -eq 2 ]
    _skill=$(grep -cE '"event":"skill\.completed"' "$WORKTREE/.planning/STATE.md")
    [ "$_skill" -eq 2 ]
    _completed=$(grep -cE '"event":"task\.completed"' "$WORKTREE/.planning/STATE.md")
    [ "$_completed" -eq 2 ]

    # validate-task gate idempotence: both tasks must validate green
    # (all five ADR 0001 gates pass independently per task).
    cd "$WORKTREE"
    run "$CHANTIER" validate-task t1
    if [ "$status" -ne 0 ]; then
        printf 'validate-task t1 output: %s\n' "$output" >&2
    fi
    [ "$status" -eq 0 ]
    run "$CHANTIER" validate-task t2
    if [ "$status" -ne 0 ]; then
        printf 'validate-task t2 output: %s\n' "$output" >&2
    fi
    [ "$status" -eq 0 ]

    # F3 fix proof (D-01): t2's dossier MUST contain upstream/t1/output.json
    # staged from the adapter's depends_on loop. Use -e (not -f or -L) to
    # accept both regular files and symlinks per 05-PATTERNS.md
    # §"F3-specific assertion". This is the assertion that FAILS in the
    # current tree (RED, before Task 05-01-02) and PASSES after the fix
    # lands (GREEN). Failure here is the load-bearing TDD signal for the
    # dogfood per Phase 3 D-07 "every invariant has a measurable proof".
    DOSSIER_T2="$WORKTREE/.chantier/dossiers/t2"
    [ -e "$DOSSIER_T2/upstream/t1/output.json" ]
}

# Decisions implemented: D-01 (F3 = dogfood feature), D-02 (TDD red->green
# with two atomic commits -- this file is the RED commit's payload).
