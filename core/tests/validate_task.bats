#!/usr/bin/env bats

# Tests for chantier validate-task — FR-004
# Covers: all 5 ADR 0001 gates, usage errors, happy path.
# Tests run inside TMPHOME with a synthetic .planning/ tree.

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    export CHANTIER="$BATS_TEST_DIRNAME/../bin/chantier"
    export FIXTURES="$BATS_TEST_DIRNAME/fixtures"
    mkdir -p "$BATS_TEST_TMPDIR/home"
    cd "$BATS_TEST_TMPDIR/home"
    # Canonicalize TMPHOME to avoid macOS /var -> /private/var symlink mismatch.
    # This ensures skill paths built from TMPHOME match the resolved repo root.
    export TMPHOME
    TMPHOME=$(pwd -P)
    mkdir -p "$TMPHOME/.planning"
    cat > "$TMPHOME/.planning/STATE.md" <<'EOF'
---
format_version: 0.1.0
---
EOF
}

# Helper: create a minimal PLAN.md with a task block for task id $1,
# state_writes $2 (one path per line), acceptance items $3 (newline-separated).
# Writes to $TMPHOME/.planning/phases/test-phase/PLAN.md.
make_plan() {
    _mp_task="$1"
    _mp_sw="$2"
    _mp_acceptance="$3"
    mkdir -p "$TMPHOME/.planning/phases/test-phase"
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
    cat > "$TMPHOME/.planning/phases/test-phase/PLAN.md" <<EOF
---
plan_id: test-plan
phase: test-phase
created: 2026-05-29
status: draft
declared_skills: []
---

## Task \`$_mp_task\` -- test task

\`\`\`yaml
task: $_mp_task
skill: test-skill
state_writes:
$_mp_sw_yaml
depends_on: []
acceptance:
$_mp_acc_yaml
\`\`\`
EOF
}

# Helper: create the task output directory for task $1 with output.md content $2.
# Optionally writes output.json as $3 (empty string = skip).
make_task_dir() {
    _mtd_task="$1"
    _mtd_output_md="$2"
    _mtd_output_json="${3:-}"
    _mtd_dir="$TMPHOME/.planning/phases/test-phase/tasks/$_mtd_task"
    mkdir -p "$_mtd_dir"
    if [ -n "$_mtd_output_md" ]; then
        printf '%s\n' "$_mtd_output_md" > "$_mtd_dir/output.md"
    fi
    if [ -n "$_mtd_output_json" ]; then
        printf '%s\n' "$_mtd_output_json" > "$_mtd_dir/output.json"
    fi
}

# Helper: create a minimal SKILL.md for skill "test-skill".
# Args: portable ($1 = true/false), plus optional outputs_schema.json path ($2)
make_skill() {
    _ms_portable="${1:-false}"
    _ms_schema="${2:-}"
    mkdir -p "$TMPHOME/skills/test-skill"
    cat > "$TMPHOME/skills/test-skill/SKILL.md" <<EOF
---
id: test-skill
version: 0.1.0
portable: $_ms_portable
inputs_schema: {}
state_reads: []
state_writes: []
outputs_schema: {}
harness_adapters: []
---

Test skill body. No harness-specific content.
EOF
    if [ -n "$_ms_schema" ]; then
        cp "$_ms_schema" "$TMPHOME/skills/test-skill/outputs_schema.json"
    fi
}

# Valid output.md with correct Acceptance section and matching criteria
VALID_ACCEPTANCE_MD='# Task t1 output

Task completed successfully.

## Acceptance

- Output directory exists at the declared state_writes path
- Directory is empty except for a .gitkeep placeholder'

VALID_SW='.planning/phases/test-phase/tasks/t1/output.md'
VALID_ACC='Output directory exists at the declared state_writes path
Directory is empty except for a .gitkeep placeholder'

# --------------------------------------------------------------------------
# Test 1: Gate 1 fail — path traversal (../../etc/passwd) exits 1
# --------------------------------------------------------------------------
@test "gate 1: path traversal outside repo root exits 1 with containment message" {
    make_plan t1 '../../etc/passwd' 'something done'
    make_skill false
    make_task_dir t1 "$VALID_ACCEPTANCE_MD" '{}'
    run "$CHANTIER" validate-task t1 --plan "$TMPHOME/.planning/phases/test-phase/PLAN.md"
    assert_failure 1
    assert_output --partial "outside"
}

# --------------------------------------------------------------------------
# Test 2: Gate 1 happy — writes inside declared state_writes passes gate 1
# --------------------------------------------------------------------------
@test "gate 1: writes inside declared state_writes passes gate 1 (no containment error)" {
    make_plan t1 "$VALID_SW" "$VALID_ACC"
    make_skill false
    make_task_dir t1 "$VALID_ACCEPTANCE_MD" '{}'
    run "$CHANTIER" validate-task t1 --plan "$TMPHOME/.planning/phases/test-phase/PLAN.md"
    # Gate 1 should pass — check that the containment message is NOT in output
    refute_output --partial "outside state_writes"
    refute_output --partial "path outside"
}

# --------------------------------------------------------------------------
# Test 3: Gate 2 fail — output.md missing exits 1
# --------------------------------------------------------------------------
@test "gate 2: missing output.md exits 1 with missing-or-empty message" {
    make_plan t1 "$VALID_SW" "$VALID_ACC"
    make_skill false
    mkdir -p "$TMPHOME/.planning/phases/test-phase/tasks/t1"
    # No output.md created
    run "$CHANTIER" validate-task t1 --plan "$TMPHOME/.planning/phases/test-phase/PLAN.md"
    assert_failure 1
    assert_output --partial "output.md missing or empty"
}

# --------------------------------------------------------------------------
# Test 4: Gate 2 fail — output.md zero-byte exits 1
# --------------------------------------------------------------------------
@test "gate 2: zero-byte output.md exits 1 with missing-or-empty message" {
    make_plan t1 "$VALID_SW" "$VALID_ACC"
    make_skill false
    mkdir -p "$TMPHOME/.planning/phases/test-phase/tasks/t1"
    printf '' > "$TMPHOME/.planning/phases/test-phase/tasks/t1/output.md"
    run "$CHANTIER" validate-task t1 --plan "$TMPHOME/.planning/phases/test-phase/PLAN.md"
    assert_failure 1
    assert_output --partial "output.md missing or empty"
}

# --------------------------------------------------------------------------
# Test 5: Gate 3 fail — output.json missing a required field exits 1
# --------------------------------------------------------------------------
@test "gate 3: output.json missing required field exits 1 with schema violation" {
    make_plan t1 "$VALID_SW" "$VALID_ACC"
    # Create a schema that requires field "result"
    _schema_file="$BATS_TEST_TMPDIR/outputs_schema.json"
    printf '{"type":"object","required":["result"],"properties":{"result":{"type":"string"}}}\n' \
        > "$_schema_file"
    make_skill false "$_schema_file"
    # output.json is missing the "result" field
    make_task_dir t1 "$VALID_ACCEPTANCE_MD" '{"other_field": "value"}'
    run "$CHANTIER" validate-task t1 --plan "$TMPHOME/.planning/phases/test-phase/PLAN.md"
    assert_failure 1
    assert_output --partial "schema violation"
}

# --------------------------------------------------------------------------
# Test 6: Gate 3 fail — output.json field has wrong type exits 1
# --------------------------------------------------------------------------
@test "gate 3: output.json field with wrong type exits 1 with schema violation" {
    make_plan t1 "$VALID_SW" "$VALID_ACC"
    _schema_file="$BATS_TEST_TMPDIR/outputs_schema_type.json"
    printf '{"type":"object","required":["result"],"properties":{"result":{"type":"string"}}}\n' \
        > "$_schema_file"
    make_skill false "$_schema_file"
    # output.json has "result" but as a number (wrong type)
    make_task_dir t1 "$VALID_ACCEPTANCE_MD" '{"result": 42}'
    run "$CHANTIER" validate-task t1 --plan "$TMPHOME/.planning/phases/test-phase/PLAN.md"
    assert_failure 1
    assert_output --partial "schema violation"
}

# --------------------------------------------------------------------------
# Test 7: Gate 4 fail — harness identifier in skill body when portable:true exits 1
# --------------------------------------------------------------------------
@test "gate 4: harness identifier in skill body with portable:true exits 1" {
    make_plan t1 "$VALID_SW" "$VALID_ACC"
    make_skill true
    # Inject a harness identifier into a skill body file (not SKILL.md itself)
    printf 'This body references claude-code which is a harness\n' > "$TMPHOME/skills/test-skill/skill-body.sh" # HARNESS_DENY_LIST_CHECK
    make_task_dir t1 "$VALID_ACCEPTANCE_MD" '{}'
    run "$CHANTIER" validate-task t1 --plan "$TMPHOME/.planning/phases/test-phase/PLAN.md"
    assert_failure 1
    assert_output --partial "harness identifier"
}

# --------------------------------------------------------------------------
# Test 8: Gate 4 happy — portable:false skips harness check even if body has identifier
# --------------------------------------------------------------------------
@test "gate 4: portable:false skips harness check even if body contains harness name" {
    make_plan t1 "$VALID_SW" "$VALID_ACC"
    make_skill false
    # Inject harness identifier into body file — should NOT trigger gate 4
    printf 'This body references cursor adapter\n' > "$TMPHOME/skills/test-skill/skill-body.sh" # HARNESS_DENY_LIST_CHECK
    make_task_dir t1 "$VALID_ACCEPTANCE_MD" '{}'
    run "$CHANTIER" validate-task t1 --plan "$TMPHOME/.planning/phases/test-phase/PLAN.md"
    # Gate 4 should NOT fire; other gates should pass
    refute_output --partial "harness identifier"
}

# --------------------------------------------------------------------------
# Test 9: Gate 5 fail — heading lowercase "## acceptance" rejected (case-sensitive regex)
# --------------------------------------------------------------------------
@test "gate 5: lowercase acceptance heading exits 1 (case-sensitive regex)" {
    make_plan t1 "$VALID_SW" "$VALID_ACC"
    make_skill false
    _bad_output='# Task t1 output

Task done.

## acceptance

- Output directory exists at the declared state_writes path
- Directory is empty except for a .gitkeep placeholder'
    make_task_dir t1 "$_bad_output" '{}'
    run "$CHANTIER" validate-task t1 --plan "$TMPHOME/.planning/phases/test-phase/PLAN.md"
    assert_failure 1
    assert_output --partial "Acceptance"
}

# --------------------------------------------------------------------------
# Test 10: Gate 5 fail — "## Acceptance criteria" (trailing words) rejected
# Uses fixture core/tests/fixtures/output.missing-acceptance.md
# --------------------------------------------------------------------------
@test "gate 5: heading with trailing words exits 1 (regex rejects trailing text)" {
    make_plan t1 "$VALID_SW" 'Output directory exists at the declared state_writes path'
    make_skill false
    mkdir -p "$TMPHOME/.planning/phases/test-phase/tasks/t1"
    cp "$FIXTURES/output.missing-acceptance.md" \
        "$TMPHOME/.planning/phases/test-phase/tasks/t1/output.md"
    printf '{}' > "$TMPHOME/.planning/phases/test-phase/tasks/t1/output.json"
    run "$CHANTIER" validate-task t1 --plan "$TMPHOME/.planning/phases/test-phase/PLAN.md"
    assert_failure 1
    assert_output --partial "Acceptance"
}

# --------------------------------------------------------------------------
# Test 11: Gate 5 fail — heading correct but one acceptance bullet missing exits 1
# --------------------------------------------------------------------------
@test "gate 5: missing acceptance item exits 1 with missing-acceptance message" {
    make_plan t1 "$VALID_SW" 'First criterion
Second criterion that is absent from output'
    make_skill false
    _partial_output='# Task t1 output

Done.

## Acceptance

- First criterion'
    make_task_dir t1 "$_partial_output" '{}'
    run "$CHANTIER" validate-task t1 --plan "$TMPHOME/.planning/phases/test-phase/PLAN.md"
    assert_failure 1
    assert_output --partial "missing acceptance"
}

# --------------------------------------------------------------------------
# Test 12: Happy path — all 5 gates pass exits 0
# Uses fixture PLAN.valid.md + output.valid.md + minimal SKILL.md
# --------------------------------------------------------------------------
@test "happy path: all 5 gates pass exits 0 with validated message" {
    # Set up using the canonical fixtures from plan 02-01
    mkdir -p "$TMPHOME/.planning/phases/fixture-phase/tasks/t1"
    cp "$FIXTURES/PLAN.valid.md" \
        "$TMPHOME/.planning/phases/fixture-phase/PLAN.md"
    cp "$FIXTURES/output.valid.md" \
        "$TMPHOME/.planning/phases/fixture-phase/tasks/t1/output.md"
    printf '{}' > "$TMPHOME/.planning/phases/fixture-phase/tasks/t1/output.json"
    # State_writes in fixture: .planning/STATE.md (inside repo)
    # Create minimal skill dir
    mkdir -p "$TMPHOME/skills/inline"
    cat > "$TMPHOME/skills/inline/SKILL.md" <<'SKILLEOF'
---
id: inline
version: 0.1.0
portable: false
inputs_schema: {}
state_reads: []
state_writes: []
outputs_schema: {}
harness_adapters: []
---
Inline skill for fixture testing.
SKILLEOF
    run "$CHANTIER" validate-task t1 --plan "$TMPHOME/.planning/phases/fixture-phase/PLAN.md"
    assert_success
    assert_output --partial "task t1 validated"
}

# --------------------------------------------------------------------------
# Test 13: Missing TASK_ID arg exits 3
# --------------------------------------------------------------------------
@test "missing TASK_ID arg exits 3 with usage message" {
    run "$CHANTIER" validate-task
    assert_failure 3
    assert_output --partial "requires a task id"
}

# --------------------------------------------------------------------------
# Test 14: Unknown task ID (not in PLAN.md) exits 3
# --------------------------------------------------------------------------
@test "unknown task ID exits 3 with not-found message" {
    make_plan t1 "$VALID_SW" "$VALID_ACC"
    make_skill false
    make_task_dir t1 "$VALID_ACCEPTANCE_MD" '{}'
    run "$CHANTIER" validate-task t99 --plan "$TMPHOME/.planning/phases/test-phase/PLAN.md"
    assert_failure 3
    assert_output --partial "t99"
}
