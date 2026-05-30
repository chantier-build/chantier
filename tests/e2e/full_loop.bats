#!/usr/bin/env bats

# tests/e2e/full_loop.bats -- Phase 5 dogfood E2E integration test.
#
# Per .planning/phases/05-dogfood-e2e/05-CONTEXT.md D-03 + D-04 and PLAN.md
# Task 05-03-01: this file is the only test under the new top-level tests/e2e/
# directory at v0.1.0. Future top-level test categories (tests/integration/,
# tests/manual/) slot in alongside; v0.1.0 ships only tests/e2e/full_loop.bats.
#
# Purpose -- the Chantier-on-Chantier proof:
#   1. Scaffold a synthetic project via the real `chantier new` binary (SC#1).
#   2. Author a synthetic two-task PLAN.md mirroring the F3 dogfood shape
#      (t1 depends_on: []; t2 depends_on: [t1]).
#   3. Dispatch both tasks sequentially via adapters/claude-code/run-task.sh
#      with the Plan 05-01 F3 fix that stages upstream/t1/output.json into
#      t2's dossier before the subagent runs.
#   4. Run `chantier validate-task` on both -- five ADR 0001 gates per task.
#   5. Assert the populated STATE.md contains exactly six dispatch events
#      (task.started x2, skill.completed x2, task.completed x2) and zero
#      task.failed (SC#2).
#   6. Assert the F3 fix proof: upstream/t1/output.json exists in t2's
#      dossier (D-01 + D-02 propagated to the full-loop scale).
#
# This file closes ROADMAP Phase 5 SC#1, SC#2, SC#3 simultaneously and
# satisfies the v0.1.0 acceptance criterion from .planning/REQUIREMENTS.md
# (non-trivial end-to-end demo as an integration test in tests/e2e/).
#
# Default offline (NFR-004 + SC#3): the CHANTIER_CLAUDE_BIN inline stub is
# set unless the operator opts in. The stub heredoc body is byte-identical
# to core/tests/adapter_claude_code_e2e.bats:84-100 and to # HARNESS_DENY_LIST_CHECK
# core/tests/adapter_upstream_e2e.bats:85-101 per Discretion #8 (inline
# duplication over shared-helper extraction at this scale).
#
# Opt-in real-claude (D-04, dev-only, CI never sets this flag):
#   CHANTIER_E2E_REAL_CLAUDE=1 bats tests/e2e/full_loop.bats
# unsets the stub so the adapter falls through to the real `claude` binary
# on PATH. Pitfall 8 mitigation: a defensive self-assertion in the @test
# body catches the case where a dev forgot to set CHANTIER_CLAUDE_BIN and
# the test would otherwise silently fall through to the local binary.
#
# Setup mirrors core/tests/adapter_claude_code_e2e.bats:29-103 with the # HARNESS_DENY_LIST_CHECK
# path-relative-loader adjustment for tests/e2e/ -> core/tests/test_helper/.

setup() {
    load '../../core/tests/test_helper/bats-support/load'
    load '../../core/tests/test_helper/bats-assert/load'

    # REPO_ROOT canonicalization: from tests/e2e/, ../.. lands at repo root.
    # pwd -P resolves the macOS /var -> /private/var symlink so the adapter's
    # `git rev-parse --show-toplevel` output matches our cd target.
    export REPO_ROOT
    REPO_ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)
    export CHANTIER="$REPO_ROOT/core/bin/chantier"
    export ADAPTER="$REPO_ROOT/adapters/claude-code/run-task.sh" # HARNESS_DENY_LIST_CHECK

    # Expose chantier on PATH so the skill's `chantier state append`
    # subprocess call resolves inside the adapter subagent.
    export PATH="$REPO_ROOT/core/bin:$PATH"

    # TMPHOME setup: per-@test isolated working tree, canonicalized via
    # pwd -P to defend against the macOS /var -> /private/var mismatch.
    mkdir -p "$BATS_TEST_TMPDIR/home"
    cd "$BATS_TEST_TMPDIR/home"
    export TMPHOME
    TMPHOME=$(pwd -P)

    # CHANTIER_CLAUDE_BIN inline stub per Discretion #8 (duplicate inline,
    # do not extract to a shared helper). Single-quoted heredoc disables
    # ALL expansion so the stub's own $1, $PROMPT, $DOSSIER are NOT
    # evaluated at bats-setup time. Body is byte-identical to the analogs
    # in core/tests/adapter_claude_code_e2e.bats and core/tests/adapter_upstream_e2e.bats.
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

    # D-04 opt-in: CHANTIER_E2E_REAL_CLAUDE=1 -> unset CHANTIER_CLAUDE_BIN so
    # the adapter falls back to the real claude binary on PATH. CI never sets
    # this flag -- NFR-004 default-offline holds. Pitfall 8: explicitly set
    # CHANTIER_CLAUDE_BIN unless opt-in (catches the silent fall-through
    # failure mode where a dev's local claude binary masks a misconfigured stub).
    if [ "${CHANTIER_E2E_REAL_CLAUDE:-}" != "1" ]; then
        export CHANTIER_CLAUDE_BIN="$BATS_TEST_TMPDIR/stub/claude"
    fi
}

@test "tests/e2e/full_loop: chantier new + 2-task chain + adapter dispatch + validate-task green (SC#1, SC#2, SC#3, D-01, D-02, D-03, D-04)" {
    # ----- Step 1: Pitfall 8 defensive self-assertion (unless opt-in) -----
    # Before any dispatch, verify CHANTIER_CLAUDE_BIN is set and executable
    # when the opt-in env var is unset. If the setup() default ever breaks
    # (or a refactor accidentally unsets the var), this assertion fails
    # BEFORE the adapter reaches the real claude binary -- catching the
    # misconfiguration immediately and defending NFR-004 hermetic guarantee.
    if [ "${CHANTIER_E2E_REAL_CLAUDE:-}" != "1" ]; then
        [ -n "$CHANTIER_CLAUDE_BIN" ]
        [ -x "$CHANTIER_CLAUDE_BIN" ]
    fi

    # ----- Step 2: chantier new (SC#1) -----
    # The real chantier binary scaffolds the synthetic project. Discretion #9
    # locks the project name to chantier-e2e-dogfood (descriptive kebab-case).
    cd "$TMPHOME"
    run "$CHANTIER" new chantier-e2e-dogfood
    [ "$status" -eq 0 ]
    cd "$TMPHOME/chantier-e2e-dogfood"

    # Assert all five scaffolded files landed (T-05-03-SCAFFOLD-GAP defence:
    # if a future chantier new patch breaks the scaffold, this test fails
    # BEFORE adapter dispatch with a clear localized error).
    [ -f .planning/PROJECT.md ]
    [ -f .planning/REQUIREMENTS.md ]
    [ -f .planning/ROADMAP.md ]
    [ -f .planning/STATE.md ]
    [ -f .planning/config.json ]

    # ----- Step 3: make the project a git work tree -----
    # The adapter requires `git rev-parse --show-toplevel` to succeed
    # (D-05 lax interpretation accepts the main checkout -- Phase 4 A5).
    git init -q
    git config user.email "test@chantier"
    git config user.name "test"
    git add -A
    git commit -q -m "scaffold"

    # ----- Step 4: copy the live test-driven-development skill body -----
    # The adapter resolves $WORKTREE/skills/test-driven-development/ and
    # copies SKILL.md + PRESSURE.md + run.sh into each task's dossier under
    # skill/ (D-02 + RESEARCH Pattern 2 self-contained dossier). The
    # "test-driven-development" identifier is a SKILL NAME, not a harness
    # identifier -- no HARNESS_DENY_LIST_CHECK marker needed here.
    mkdir -p skills/test-driven-development
    cp "$REPO_ROOT/skills/test-driven-development/SKILL.md"    skills/test-driven-development/
    cp "$REPO_ROOT/skills/test-driven-development/PRESSURE.md" skills/test-driven-development/
    cp "$REPO_ROOT/skills/test-driven-development/run.sh"      skills/test-driven-development/
    chmod +x skills/test-driven-development/run.sh
    git add -A
    git commit -q -m "scaffold-skill"

    # ----- Step 5: write the synthetic two-task PLAN.md -----
    # Mirrors core/tests/adapter_upstream_e2e.bats:134-179 PLAN body: same
    # phase id (dogfood-phase), same skill, same deterministic four-scalar
    # inputs fixture, same TDD acceptance bullets. t2 declares depends_on: [t1]
    # so the F3 fix from Plan 05-01 stages upstream/t1/output.json into
    # t2's dossier before dispatch. Single-quoted PLAN_EOF heredoc disables
    # shell expansion so the YAML body is written verbatim.
    mkdir -p .planning/phases/dogfood-phase
    cat > .planning/phases/dogfood-phase/PLAN.md <<'PLAN_EOF'
---
plan_id: 01-dogfood
phase: dogfood-phase
created: 2026-05-30
status: draft
declared_skills: ["test-driven-development"]
---

## Task `t1` -- full-loop dogfood producer

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

## Task `t2` -- full-loop dogfood downstream consumer (exercises F3 fix)

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
    git add -A
    git commit -q -m "scaffold-plan"

    # ----- Step 6: sequential dispatch (Discretion #3 operator-orders-dispatch) -----
    # Dispatch t1 first: produces output.json which t2 will consume via the
    # F3 fix. Out-of-order dispatch (t2 before t1) would exit 2 with stderr
    # `run-task: depends_on=t1 but <path>/output.json not found; dispatch t1
    # first` -- this test does NOT exercise that failure mode by design.
    run "$ADAPTER" t1
    if [ "$status" -ne 0 ]; then
        printf 'adapter t1 exit: %s\n' "$status" >&2
        printf 'adapter t1 output: %s\n' "$output" >&2
        printf 'state log:\n' >&2
        cat .planning/STATE.md >&2 || true
    fi
    [ "$status" -eq 0 ]

    # Surface 3 propagation (Phase 4 plan 03 / ADR 0004 Proposed): t1's
    # output.json must land in its TASK_DIR so t2's F3 staging can target it.
    [ -f ".planning/phases/dogfood-phase/tasks/t1/output.json" ]

    # Dispatch t2: the F3-fix-exercising call. The adapter parses
    # depends_on:[t1] and stages $DOSSIER_T2/upstream/t1/output.json before
    # running the subagent. With the fix landed (Plan 05-01 task t2,
    # commit ed6dfe6), this dispatch exits 0.
    run "$ADAPTER" t2
    if [ "$status" -ne 0 ]; then
        printf 'adapter t2 exit: %s\n' "$status" >&2
        printf 'adapter t2 output: %s\n' "$output" >&2
        printf 'state log:\n' >&2
        cat .planning/STATE.md >&2 || true
    fi
    [ "$status" -eq 0 ]

    # Surface 3 propagation for t2.
    [ -f ".planning/phases/dogfood-phase/tasks/t2/output.json" ]

    # ----- Step 7: validate-task green on both tasks (SC#2) -----
    # All five ADR 0001 gates (path containment, output.md exists,
    # output.json matches outputs_schema, deny-list scan, acceptance items)
    # pass for each task independently. Re-running after the adapter
    # already ran validate-task green internally is the gate-idempotence
    # check.
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

    # ----- Step 8: STATE.md event-count assertions (SC#2) -----
    # Six dispatch events expected (two tasks x three events each):
    #   task.started     x 2 (one per adapter invocation, before claude -p)
    #   skill.completed  x 2 (one per skill run.sh, after output.json emission)
    #   task.completed   x 2 (one per adapter invocation, after validate-task green)
    # Zero task.failed events: both dispatches green from start to finish.
    # `chantier new` produced an empty STATE.md (frontmatter + JSONL-empty
    # body), so prior bootstrap events are NOT in the count.
    _started=$(grep -cE '"event":"task\.started"' .planning/STATE.md)
    [ "$_started" -eq 2 ]
    _skill=$(grep -cE '"event":"skill\.completed"' .planning/STATE.md)
    [ "$_skill" -eq 2 ]
    _completed=$(grep -cE '"event":"task\.completed"' .planning/STATE.md)
    [ "$_completed" -eq 2 ]
    # grep -c returns exit 1 when no match is found; `|| true` defends
    # against set -e aborting the @test on a legitimately-zero count.
    _failed=$(grep -cE '"event":"task\.failed"' .planning/STATE.md || true)
    [ "$_failed" -eq 0 ]

    # ----- Step 9: F3 fix proof at full-loop scale (D-01 + D-02) -----
    # t2's dossier MUST contain upstream/t1/output.json staged by the
    # adapter's depends_on loop. Use -e (not -f or -L) to accept both
    # regular files and symlinks per 05-PATTERNS.md §"F3-specific
    # assertion". This is the load-bearing dogfood claim: the F3 fix from
    # Plan 05-01 works through the FULL loop (chantier new + multi-task
    # PLAN.md + sequential adapter dispatch + validate-task green), not
    # just the in-tree regression. If a future patch breaks the F3 fix,
    # this assertion goes red.
    [ -e ".chantier/dossiers/t2/upstream/t1/output.json" ]

    # ----- Step 10: NFR-004 self-defense (SC#3 + Pitfall 8 final assertion) -----
    # Confirm the stub was actually used and not bypassed by a refactor
    # that silently unset CHANTIER_CLAUDE_BIN. Defends against a future
    # change that breaks the setup() default and causes CI to fall through
    # to the real claude binary on the runner (which would either hang
    # waiting for network or exit 3 with `claude binary not found`).
    if [ "${CHANTIER_E2E_REAL_CLAUDE:-}" != "1" ]; then
        [ -n "$CHANTIER_CLAUDE_BIN" ]
        [ -x "$CHANTIER_CLAUDE_BIN" ]
    fi
}

# Decisions implemented: D-03 (single-bats top-level tests/e2e/ integration),
# D-04 (CHANTIER_CLAUDE_BIN default-stub + CHANTIER_E2E_REAL_CLAUDE opt-in gate).
# Closes ROADMAP Phase 5 SC#1, SC#2, SC#3 and v0.1.0 §Acceptance "non-trivial
# end-to-end demo as integration test in tests/e2e/".
