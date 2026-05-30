#!/usr/bin/env bats

# End-to-end test for adapters/claude-code/run-task.sh (Phase 4 / FR-008). # HARNESS_DENY_LIST_CHECK
#
# Exercises D-13, D-14, D-15:
#   D-13 -- red-phase fixture of test-driven-development (test_command: "false"
#           exits 1 deterministically; output.json.red_exit_code == 1;
#           red_step_timestamp matches ISO-8601 UTC second precision;
#           invariants_applied length >= 4).
#   D-14 -- file location (core/tests/adapter_claude_code_e2e.bats) and the
#           mirror relationship with core/tests/skill_test_driven_development_e2e.bats
#           (this file is a structural copy with the adapter inserted in the middle).
#   D-15 -- CHANTIER_CLAUDE_BIN deterministic stub policy (offline + no API key
#           per NFR-004); the stub cd's the dossier, sources env.sh, execs
#           skill/run.sh.
#
# Worktree per D-05: the test acts as the operator and pre-creates a worktree
# via `git worktree add`. The adapter is invoked from inside that worktree.
#
# The stub at $BATS_TEST_TMPDIR/stub/claude lives outside the repo's audit
# scope (D-11 walks core/, skills/, adapters/ only); it carries the substring
# `claude` legitimately because it IS the stub for the `claude` binary.
#
# Setup mirrors core/tests/skill_test_driven_development_e2e.bats:19-52 for the
# loaders / REPO_ROOT canonicalization / PATH-prepend / TMPHOME (pwd -P for the
# macOS /var -> /private/var symlink mismatch). Phase 4 setup ADDS: git init +
# worktree creation, and the inline CHANTIER_CLAUDE_BIN stub.

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
    # pwd -P to avoid the macOS /var -> /private/var symlink mismatch
    # (validate_task.bats lines 14-17 / skill_test_driven_development_e2e.bats:38-40).
    mkdir -p "$BATS_TEST_TMPDIR/home"
    cd "$BATS_TEST_TMPDIR/home"
    export TMPHOME
    TMPHOME=$(pwd -P)

    # D-05 worktree creation: operator pre-creates the worktree; the test
    # acts as operator. The adapter is invoked from inside the worktree
    # (git rev-parse --show-toplevel returns $WORKTREE on entry).
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

    # D-15 CHANTIER_CLAUDE_BIN stub: ~14-line POSIX sh stub written inline
    # via quoted heredoc (<<'STUB_EOF' disables ALL expansion so the stub's
    # own $1, $PROMPT, $DOSSIER are NOT evaluated at bats-setup time).
    # The stub accepts -p|--print (and ignores all other flags); parses the
    # absolute dossier path from the prompt via grep -oE (non-greedy POSIX
    # alternative -- the equivalent sed `.*` capture is greedy and would
    # truncate the leading directory components of the absolute path on the
    # multi-line prompt the adapter emits); cd's there; sources env.sh;
    # execs skill/run.sh; propagates the exit code. Trace echo on stdout
    # for fidelity. Lives outside the audit scope under $BATS_TEST_TMPDIR.
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

# make_plan: build a minimal PLAN.md at
# $WORKTREE/.planning/phases/test-phase/PLAN.md with one task block whose
# skill: field names the skill under test, state_writes: lists the per-task
# write paths, acceptance: bullets match what the skill's run.sh writes
# verbatim into output.md (gate 5 does substring match), and inputs: embeds
# the four Phase 3 fixture scalars (target_file / test_framework / phase /
# test_command) which the adapter's awk extracts into the dossier inputs.yml.
#
# Args: $1 task id, $2 newline-separated state_writes paths,
#       $3 newline-separated acceptance bullets, $4 skill id,
#       $5 newline-separated `key: "value"` inputs lines.
make_plan() {
    _mp_task="$1"
    _mp_sw="$2"
    _mp_acceptance="$3"
    _mp_skill="$4"
    _mp_inputs="$5"
    mkdir -p "$WORKTREE/.planning/phases/test-phase"
    _mp_sw_yaml=""
    while IFS= read -r _mp_path; do
        [ -n "$_mp_path" ] || continue
        _mp_sw_yaml="${_mp_sw_yaml}  - \"${_mp_path}\"
"
    done <<EOF_SW
$_mp_sw
EOF_SW
    _mp_acc_yaml=""
    while IFS= read -r _mp_item; do
        [ -n "$_mp_item" ] || continue
        _mp_acc_yaml="${_mp_acc_yaml}  - \"${_mp_item}\"
"
    done <<EOF_ACC
$_mp_acceptance
EOF_ACC
    _mp_in_yaml=""
    while IFS= read -r _mp_in_line; do
        [ -n "$_mp_in_line" ] || continue
        _mp_in_yaml="${_mp_in_yaml}  ${_mp_in_line}
"
    done <<EOF_IN
$_mp_inputs
EOF_IN
    cat > "$WORKTREE/.planning/phases/test-phase/PLAN.md" <<EOF
---
plan_id: test-plan
phase: test-phase
created: 2026-05-30
status: draft
declared_skills: ["$_mp_skill"]
---

## Task \`$_mp_task\` -- adapter e2e fixture task

\`\`\`yaml
task: $_mp_task
skill: $_mp_skill
inputs:
$_mp_in_yaml
state_writes:
$_mp_sw_yaml
depends_on: []
acceptance:
$_mp_acc_yaml
\`\`\`
EOF
}

@test "claude-code adapter dispatches test-driven-development red phase end-to-end via CHANTIER_CLAUDE_BIN stub" { # HARNESS_DENY_LIST_CHECK
    TASK="t1"
    SKILL="test-driven-development"

    # Copy the live skill body into the worktree. The adapter resolves
    # $WORKTREE/skills/$SKILL_ID/ and copies SKILL.md + PRESSURE.md + run.sh
    # into the dossier under skill/ (D-02 + RESEARCH Pattern 2 self-contained).
    mkdir -p "$WORKTREE/skills/$SKILL"
    cp "$REPO_ROOT/skills/$SKILL/SKILL.md"    "$WORKTREE/skills/$SKILL/SKILL.md"
    cp "$REPO_ROOT/skills/$SKILL/PRESSURE.md" "$WORKTREE/skills/$SKILL/PRESSURE.md"
    cp "$REPO_ROOT/skills/$SKILL/run.sh"      "$WORKTREE/skills/$SKILL/run.sh"
    chmod +x "$WORKTREE/skills/$SKILL/run.sh"

    # Acceptance bullets MUST be byte-identical to the ones run.sh writes
    # into output.md (gate 5 does substring match on each one in turn).
    # Source: skills/test-driven-development/run.sh:194-196.
    ACC1="A failing test was observed before any production code was written for this task."
    ACC2="After the production change, the same test command exits zero."

    # Inputs: four scalars byte-identical to the Phase 3 fixture
    # core/tests/fixtures/skills/test-driven-development/dossier/inputs.yml.
    # The adapter's awk extracts this block from PLAN.md and writes it as
    # $DOSSIER/inputs.yml; the round-trip is part of this test.
    INPUTS='target_file: "core/bin/chantier"
test_framework: "bats"
phase: "red"
test_command: "false"'

    make_plan "$TASK" \
        ".planning/phases/test-phase/tasks/$TASK/" \
        "$(printf '%s\n%s' "$ACC1" "$ACC2")" \
        "$SKILL" \
        "$INPUTS"

    # D-05: the adapter is invoked from inside the worktree. After this cd,
    # `git rev-parse --show-toplevel` inside the adapter returns $WORKTREE.
    cd "$WORKTREE"
    run "$ADAPTER" "$TASK"

    # On non-zero status, surface the adapter output and the STATE.md log to
    # stderr so the failure mode is debuggable (mirrors analog lines 166-168).
    if [ "$status" -ne 0 ]; then
        printf 'adapter exit: %s\n' "$status" >&2
        printf 'adapter output: %s\n' "$output" >&2
        printf 'state log:\n' >&2
        cat "$WORKTREE/.planning/STATE.md" >&2 || true
    fi
    [ "$status" -eq 0 ]

    # Dossier existence (D-08 preservation): the adapter staged a Surface 2
    # dossier and did NOT delete it on success.
    DOSSIER="$WORKTREE/.chantier/dossiers/$TASK"
    [ -d "$DOSSIER" ]
    [ -f "$DOSSIER/env.sh" ]
    [ -f "$DOSSIER/inputs.yml" ]
    [ -f "$DOSSIER/skill/SKILL.md" ]
    [ -f "$DOSSIER/skill/run.sh" ]

    # env.sh contract (D-07 layer 1): three exports present with the right
    # values. CHANTIER_TASK_ID matches "$TASK", CHANTIER_PHASE matches
    # "test-phase" (the phase dir basename), CHANTIER_WORKTREE matches the
    # absolute worktree path.
    grep -qE "^CHANTIER_TASK_ID=\"$TASK\"$" "$DOSSIER/env.sh"
    grep -qE '^CHANTIER_PHASE="test-phase"$' "$DOSSIER/env.sh"
    grep -qE "^CHANTIER_WORKTREE=\"$WORKTREE\"$" "$DOSSIER/env.sh"

    # Outputs: the skill wrote output.md + output.json into the task dir
    # (Phase 3 contract). The adapter then ran chantier validate-task green
    # (D-04 green boundary).
    TASK_DIR="$WORKTREE/.planning/phases/test-phase/tasks/$TASK"
    [ -f "$TASK_DIR/output.md" ]
    [ -f "$TASK_DIR/output.json" ]

    # D-13 measurable signals (copied from analog lines 144-157):
    run jq -e '.red_step_timestamp | type == "string"' "$TASK_DIR/output.json"
    [ "$status" -eq 0 ]
    run jq -e '.red_exit_code | type == "number"' "$TASK_DIR/output.json"
    [ "$status" -eq 0 ]
    # The fixture's test_command is "false" -- the POSIX builtin exits 1
    # deterministically. Verify the red-step exit was captured as 1 both
    # via direct jq -r extraction (for legibility) and via jq -e equality
    # (for assertion-style failure surfaces on mismatch).
    _red_exit=$(jq -r '.red_exit_code' "$TASK_DIR/output.json")
    [ "$_red_exit" -eq 1 ]
    run jq -e '.red_exit_code == 1' "$TASK_DIR/output.json"
    [ "$status" -eq 0 ]
    # The red timestamp must be ISO-8601 UTC second-precision.
    run jq -e '.red_step_timestamp | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")' "$TASK_DIR/output.json"
    [ "$status" -eq 0 ]
    # invariants_applied must contain at least the four canonical entries
    # (kernel 1-3 + skill #4 red-before-green).
    run jq -e '.invariants_applied | length >= 4' "$TASK_DIR/output.json"
    [ "$status" -eq 0 ]

    # D-03 three-event signal: task.started + skill.completed + task.completed
    # all present exactly once. Split into three separate assertions so a
    # failure surfaces which event is missing.
    #   - task.started: emitted by the adapter before claude -p dispatch.
    #   - skill.completed: emitted by the skill's run.sh after output.json
    #     emission (Phase 3 D-04 contract).
    #   - task.completed: emitted by the adapter after validate-task green
    #     (D-04 green boundary).
    _started=$(grep -cE '"event":"task\.started"' "$WORKTREE/.planning/STATE.md")
    [ "$_started" -eq 1 ]
    _skill=$(grep -cE '"event":"skill\.completed"' "$WORKTREE/.planning/STATE.md")
    [ "$_skill" -eq 1 ]
    _completed=$(grep -cE '"event":"task\.completed"' "$WORKTREE/.planning/STATE.md")
    [ "$_completed" -eq 1 ]

    # validate-task gate idempotence: the adapter already ran validate-task
    # green (D-04). Re-running it directly confirms gate idempotence and
    # defends against an adapter bug that masks a red gate.
    cd "$WORKTREE"
    run "$CHANTIER" validate-task "$TASK"
    if [ "$status" -ne 0 ]; then
        printf 'validate-task re-run output: %s\n' "$output" >&2
    fi
    [ "$status" -eq 0 ]
}

# Decisions implemented: D-13 (red-phase fixture), D-14 (file location),
# D-15 (CHANTIER_CLAUDE_BIN stub policy).
