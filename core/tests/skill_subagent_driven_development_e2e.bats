#!/usr/bin/env bats

# End-to-end test for skills/subagent-driven-development.
#
# Stages a fixture dossier (subtask_count: 2, parent_brief, subtask_focus)
# and invokes the skill's run.sh. Verifies that:
#   - run.sh exits 0;
#   - output.md, output.json, and BOTH subtask_brief_<id>.md files exist;
#   - output.json.parent_context_refs_count == 0 (Invariant 4 proof);
#   - output.json.subagent_invariants_acknowledged_count >= 3 (Invariant 5
#     proof; with 2 subtasks x 3 kernel invariants the expected value is 6);
#   - chantier validate-task exits 0 (all five ADR 0001 gates pass).
#
# Setup mirrors core/tests/skill_requesting_code_review_e2e.bats for the
# loaders, TMPHOME canonicalization, PATH-prepend of the chantier binary,
# and the make_plan helper. Unlike that test, this one does NOT initialise
# TMPHOME as a git repo -- the subagent-driven-development skill performs
# no git operations.

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'

    # Repo-relative paths -- BATS_TEST_DIRNAME is core/tests/
    export CHANTIER="$BATS_TEST_DIRNAME/../bin/chantier"
    export FIXTURES="$BATS_TEST_DIRNAME/fixtures"
    export REPO_ROOT
    REPO_ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)

    # Expose chantier on PATH so the skill's final `chantier state append`
    # call resolves. The binary lives at $REPO_ROOT/core/bin/chantier;
    # PATH-prepend that directory.
    export PATH="$REPO_ROOT/core/bin:$PATH"

    # TMPHOME setup: per-@test isolated working tree, canonicalized via
    # pwd -P to avoid the macOS /var -> /private/var symlink mismatch.
    mkdir -p "$BATS_TEST_TMPDIR/home"
    cd "$BATS_TEST_TMPDIR/home"
    export TMPHOME
    TMPHOME=$(pwd -P)

    # Seed .planning/STATE.md with a frontmatter-only JSONL stub
    # (matches what `chantier new` would produce).
    mkdir -p "$TMPHOME/.planning"
    cat > "$TMPHOME/.planning/STATE.md" <<'EOF'
---
format_version: 0.1.0
---
EOF
}

# make_plan: build a minimal PLAN.md at
# $TMPHOME/.planning/phases/test-phase/PLAN.md with one task block whose
# skill: field names the skill under test, state_writes: lists the per-task
# write paths, and acceptance: bullets match what run.sh writes verbatim
# into output.md (gate 5 does substring match).
# Args: $1 task id, $2 newline-separated state_writes paths,
#       $3 newline-separated acceptance bullets, $4 skill id.
make_plan() {
    _mp_task="$1"
    _mp_sw="$2"
    _mp_acceptance="$3"
    _mp_skill="$4"
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
created: 2026-05-30
status: draft
declared_skills: ["$_mp_skill"]
---

## Task \`$_mp_task\` -- e2e fixture task

\`\`\`yaml
task: $_mp_task
skill: $_mp_skill
state_writes:
$_mp_sw_yaml
depends_on: []
acceptance:
$_mp_acc_yaml
\`\`\`
EOF
}

@test "subagent-driven-development: 2-subtask fan-out end-to-end through chantier validate-task" {
    TASK="t1"
    SKILL="subagent-driven-development"

    # Copy the live skill into TMPHOME so SKILL.md / outputs_schema lookup
    # works from $REPO_ROOT/skills/<id>/ relative to PLAN.md. Validate-task
    # resolves the skill dir as $repo_root/skills/$skill_id; with the cwd
    # at TMPHOME the resolution will look in $TMPHOME/skills/$SKILL.
    mkdir -p "$TMPHOME/skills/$SKILL"
    cp "$REPO_ROOT/skills/$SKILL/SKILL.md"    "$TMPHOME/skills/$SKILL/SKILL.md"
    cp "$REPO_ROOT/skills/$SKILL/PRESSURE.md" "$TMPHOME/skills/$SKILL/PRESSURE.md"
    cp "$REPO_ROOT/skills/$SKILL/run.sh"      "$TMPHOME/skills/$SKILL/run.sh"
    chmod +x "$TMPHOME/skills/$SKILL/run.sh"

    # Acceptance bullets MUST be byte-identical to the ones run.sh writes
    # into output.md (gate 5 does substring match on each one in turn).
    ACC_BULLET_1="Every subtask brief is a self-contained file with the three kernel invariants acknowledged verbatim."
    ACC_BULLET_2="No subtask brief references parent conversation context (parent_context_refs_count == 0)."

    make_plan "$TASK" \
        ".planning/phases/test-phase/tasks/$TASK/" \
        "$(printf '%s\n%s' "$ACC_BULLET_1" "$ACC_BULLET_2")" \
        "$SKILL"

    # Stage the fixture dossier inside the task dir.
    TASK_DIR="$TMPHOME/.planning/phases/test-phase/tasks/$TASK"
    mkdir -p "$TASK_DIR"
    cp "$FIXTURES/skills/$SKILL/dossier/inputs.yml" "$TASK_DIR/inputs.yml"

    # Invoke the skill from inside the task dir.
    cd "$TASK_DIR"
    export CHANTIER_TASK_ID="$TASK"
    run sh "$TMPHOME/skills/$SKILL/run.sh"
    if [ "$status" -ne 0 ]; then
        printf 'run.sh output: %s\n' "$output" >&2
    fi
    [ "$status" -eq 0 ]
    [ -f "$TASK_DIR/output.md" ]
    [ -f "$TASK_DIR/output.json" ]
    [ -f "$TASK_DIR/subtask_brief_1.md" ]
    [ -f "$TASK_DIR/subtask_brief_2.md" ]

    # output.json must be parseable JSON with all required fields.
    run jq -e '.subtask_count | type == "number"' "$TASK_DIR/output.json"
    [ "$status" -eq 0 ]
    run jq -e '.subtask_briefs | type == "array"' "$TASK_DIR/output.json"
    [ "$status" -eq 0 ]
    run jq -e '.subtask_briefs | length == 2' "$TASK_DIR/output.json"
    [ "$status" -eq 0 ]

    # Invariant 4 proof: parent_context_refs_count must be 0.
    _refs=$(jq -r '.parent_context_refs_count' "$TASK_DIR/output.json")
    [ "$_refs" -eq 0 ]

    # Invariant 5 proof: subagent_invariants_acknowledged_count must be
    # >= 3 (the kernel count). With 2 subtasks x 3 kernel invariants the
    # expected value is 6.
    _ack=$(jq -r '.subagent_invariants_acknowledged_count' "$TASK_DIR/output.json")
    [ "$_ack" -ge 3 ]

    # invariants_applied must contain all five canonical entries.
    run jq -e '.invariants_applied | length >= 5' "$TASK_DIR/output.json"
    [ "$status" -eq 0 ]

    # Each subtask_briefs[].brief_path must reference an actual file.
    _path1=$(jq -r '.subtask_briefs[0].brief_path' "$TASK_DIR/output.json")
    [ -f "$_path1" ]
    _path2=$(jq -r '.subtask_briefs[1].brief_path' "$TASK_DIR/output.json")
    [ -f "$_path2" ]

    # output.md must carry the literal Acceptance heading.
    run grep -qE '^##[[:space:]]+Acceptance[[:space:]]*$' "$TASK_DIR/output.md"
    [ "$status" -eq 0 ]

    # All five chantier validate-task gates must pass.
    cd "$TMPHOME"
    run "$CHANTIER" validate-task "$TASK"
    if [ "$status" -ne 0 ]; then
        printf 'validate-task output: %s\n' "$output" >&2
    fi
    [ "$status" -eq 0 ]
}
