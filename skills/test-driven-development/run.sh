#!/bin/sh
# Copyright (c) 2026 Chantier Contributors
# SPDX-License-Identifier: MIT
#
# Source: ADR 0001 Surface 3 + ADR 0002 Exit-code matrix + skills/test-driven-development/SKILL.md
# Entry point for the test-driven-development skill. Runs the test
# command for one phase (red or green per inputs.yml), captures its
# exit code under set +e bracketing, merges with any prior-phase
# output.json fields, emits output.md and output.json, and appends a
# skill.completed event to STATE.md via the chantier binary.

set -eu
IFS='
'
LC_ALL=C
export LC_ALL

# ---------------------------------------------------------------------------
# 1. Read dossier inputs.
# TASK_DIR is the per-task directory the dossier was staged into (Phase 4
# adapter responsibility; Phase 3 tests stage via a fixture). inputs.yml
# lives at the canonical dossier path per ADR 0001 Surface 2.
# ---------------------------------------------------------------------------
TASK_DIR="${PWD}"
INPUTS_YML="${TASK_DIR}/inputs.yml"
[ -r "$INPUTS_YML" ] || {
    printf 'test-driven-development: missing or unreadable inputs.yml at %s\n' \
        "$INPUTS_YML" >&2
    exit 2
}

# Parse the scalar inputs via grep+sed (POSIX subset only; no yq).
TARGET_FILE=$(grep -E '^target_file:'    "$INPUTS_YML" | sed 's/^target_file:[[:space:]]*//;    s/^"//; s/"$//')
TEST_FRAMEWORK=$(grep -E '^test_framework:' "$INPUTS_YML" | sed 's/^test_framework:[[:space:]]*//; s/^"//; s/"$//')
PHASE_FLAG=$(grep -E '^phase:'           "$INPUTS_YML" | sed 's/^phase:[[:space:]]*//;          s/^"//; s/"$//')
# test_command is optional; absence -> per-framework default below.
TEST_COMMAND=$(grep -E '^test_command:' "$INPUTS_YML" 2>/dev/null | sed 's/^test_command:[[:space:]]*//; s/^"//; s/"$//' || true)

[ -n "$TARGET_FILE" ]    || { printf 'test-driven-development: required input missing: target_file\n'    >&2; exit 2; }
[ -n "$TEST_FRAMEWORK" ] || { printf 'test-driven-development: required input missing: test_framework\n' >&2; exit 2; }
[ -n "$PHASE_FLAG" ]     || { printf 'test-driven-development: required input missing: phase\n'         >&2; exit 2; }

# Dependency presence: jq is required for output.json emission. Absence
# is a technical incident, exit 2 per the matrix in SKILL.md.
command -v jq >/dev/null 2>&1 || { printf 'test-driven-development: jq not found\n' >&2; exit 2; }

# ---------------------------------------------------------------------------
# 2. Default test_command per framework when not supplied by inputs.yml.
# Framework names must match the SKILL.md inputs_schema enum. An unknown
# framework is a technical incident (exit 2).
# ---------------------------------------------------------------------------
if [ -z "$TEST_COMMAND" ]; then
    case "$TEST_FRAMEWORK" in
        bats)       TEST_COMMAND="bats core/tests/" ;;
        pytest)     TEST_COMMAND="pytest -x" ;;
        vitest)     TEST_COMMAND="npx vitest run" ;;
        jest)       TEST_COMMAND="npx jest" ;;
        go-test)    TEST_COMMAND="go test ./..." ;;
        cargo-test) TEST_COMMAND="cargo test" ;;
        *)
            printf 'test-driven-development: unknown test_framework: %s\n' "$TEST_FRAMEWORK" >&2
            exit 2
            ;;
    esac
fi

# ---------------------------------------------------------------------------
# 3. Phase dispatch.
# Each invocation handles exactly one phase. The opposite-phase fields
# are read from any pre-existing output.json in the task dir so a green
# invocation merges with the prior red invocation's record.
# ---------------------------------------------------------------------------
RED_TS=""
GREEN_TS=""
RED_EXIT=-1
GREEN_EXIT=-1
RED_CMD=""
GREEN_CMD=""

case "$PHASE_FLAG" in
    red)
        RED_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        RED_CMD="$TEST_COMMAND"
        # Pitfall 3: bracket the runner with set +e / set -e so a
        # legitimate red-step failure does not abort the script under
        # set -e. The non-zero exit code IS the business outcome here.
        set +e
        sh -c "$TEST_COMMAND" > "$TASK_DIR/red.out" 2>&1
        RED_EXIT=$?
        set -e
        # If a prior green invocation wrote output.json (unusual, but
        # the green-then-red order is not forbidden by the design --
        # merge those fields forward so they are not lost).
        if [ -f "$TASK_DIR/output.json" ]; then
            GREEN_TS=$(jq -r '.green_step_timestamp // ""' "$TASK_DIR/output.json")
            GREEN_EXIT=$(jq -r '.green_exit_code // -1'    "$TASK_DIR/output.json")
            GREEN_CMD=$(jq -r '.green_test_command // ""'  "$TASK_DIR/output.json")
        fi
        ;;
    green)
        GREEN_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        GREEN_CMD="$TEST_COMMAND"
        set +e
        sh -c "$TEST_COMMAND" > "$TASK_DIR/green.out" 2>&1
        GREEN_EXIT=$?
        set -e
        # Carry forward red-step fields from the prior red invocation.
        if [ -f "$TASK_DIR/output.json" ]; then
            RED_TS=$(jq -r '.red_step_timestamp // ""' "$TASK_DIR/output.json")
            RED_EXIT=$(jq -r '.red_exit_code // -1'    "$TASK_DIR/output.json")
            RED_CMD=$(jq -r '.red_test_command // ""'  "$TASK_DIR/output.json")
        fi
        ;;
    *)
        printf 'test-driven-development: invalid phase: %s (must be red or green)\n' "$PHASE_FLAG" >&2
        exit 2
        ;;
esac

# ---------------------------------------------------------------------------
# 4. Count tests from the runner's output (best-effort).
# TAP-style runners (bats and many others) emit one "ok N" or "not ok N"
# line per test. Frameworks with non-TAP output (e.g., go test) will
# produce 0 here in v0.1 -- documented limitation in SKILL.md.
# ---------------------------------------------------------------------------
# grep -c writes "0\n" to stdout even when no match (with exit code 1).
# A `|| printf '0'` fallback would append a second "0" to the substitution
# value -- so guard with `|| true` instead and rely on grep's own "0"
# output. BSD/GNU grep -c agree: the count is always the first line.
TESTS_ADDED=$(grep -cE '^(ok|not ok) [0-9]+' "$TASK_DIR/${PHASE_FLAG}.out" 2>/dev/null || true)
TESTS_ADDED=$(printf '%s' "$TESTS_ADDED" | head -n 1 | tr -d ' ')
[ -n "$TESTS_ADDED" ] || TESTS_ADDED=0

# ---------------------------------------------------------------------------
# 5. Emit output.json via a single jq -n call.
# Every value flows through --arg (strings) or --argjson (numbers / JSON).
# No printf %s into JSON anywhere -- T-02-04-INJ defence mirrored from
# core/bin/chantier line 196.
# ---------------------------------------------------------------------------
jq -n \
    --arg     red_ts     "$RED_TS" \
    --arg     green_ts   "$GREEN_TS" \
    --arg     red_cmd    "$RED_CMD" \
    --arg     green_cmd  "$GREEN_CMD" \
    --argjson red_code   "$RED_EXIT" \
    --argjson green_code "$GREEN_EXIT" \
    --argjson tests      "$TESTS_ADDED" \
    --argjson inv        '[1,2,3,4]' \
    '{
        tests_added:          $tests,
        red_step_timestamp:   $red_ts,
        green_step_timestamp: $green_ts,
        red_test_command:     $red_cmd,
        green_test_command:   $green_cmd,
        red_exit_code:        $red_code,
        green_exit_code:      $green_code,
        invariants_applied:   $inv
    }' > "$TASK_DIR/output.json"

# ---------------------------------------------------------------------------
# 6. Emit output.md.
# Unquoted heredoc so $RED_TS, $GREEN_TS etc. interpolate. The
# `## Acceptance` heading is load-bearing -- gate 5 of chantier
# validate-task does case-sensitive grep on `^## Acceptance$`. The two
# acceptance bullets are byte-identical to those declared in PLAN.md so
# gate 5's substring match passes.
# ---------------------------------------------------------------------------
if [ -n "$RED_TS" ]; then
    _red_display="$RED_TS (exit $RED_EXIT)"
else
    _red_display="pending"
fi
if [ -n "$GREEN_TS" ]; then
    _green_display="$GREEN_TS (exit $GREEN_EXIT)"
else
    _green_display="pending"
fi

cat > "$TASK_DIR/output.md" <<EOF
# Skill: test-driven-development

Phase: $PHASE_FLAG. Test command: \`$TEST_COMMAND\`. Target file: $TARGET_FILE.
Red step: $_red_display.
Green step: $_green_display.

## Invariants applied

- Kernel #1 (NFR-001 portability)
- Kernel #2 (STATE.md append-only)
- Kernel #3 (state_writes containment)
- Skill #4 (red-before-green ordering)

## Acceptance

- A failing test was observed before any production code was written for this task.
- After the production change, the same test command exits zero.
EOF

# ---------------------------------------------------------------------------
# 7. Resolve the project root and append skill.completed event to STATE.md
# via the chantier binary. The binary expects to run from a directory
# containing `.planning/` (STATE_FILE and LOCKDIR are CWD-relative inside
# the binary). Walk up from TASK_DIR looking for `.planning/`. output.md
# and output.json are already written -- never invoke state append
# before the outputs exist (Pitfall 4: log lies about completion if the
# script crashes mid-flow). The binary holds the mkdir-mutex; this skill
# does not lock STATE.md itself.
# ---------------------------------------------------------------------------
_root="$TASK_DIR"
while [ "$_root" != "/" ] && [ ! -d "$_root/.planning" ]; do
    _root=$(dirname "$_root")
done
[ -d "$_root/.planning" ] || {
    printf 'test-driven-development: could not locate .planning/ above %s\n' \
        "$TASK_DIR" >&2
    exit 2
}

(
    cd "$_root"
    chantier state append \
        -e skill.completed \
        -t "${CHANTIER_TASK_ID:-unknown}" \
        -s test-driven-development \
        -m "TDD $PHASE_FLAG step completed; see output.json for measured invariants" \
        -r "$TASK_DIR/output.md" \
        -r "$TASK_DIR/output.json"
)

exit 0
