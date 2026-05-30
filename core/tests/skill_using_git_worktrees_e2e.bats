#!/usr/bin/env bats

# End-to-end test for skills/using-git-worktrees.
#
# Stages a fixture dossier, invokes the skill's run.sh, and runs
# chantier validate-task against the resulting task. All five ADR 0001
# validation gates must pass. The chantier binary is exposed on PATH so
# the skill's final `chantier state append` call resolves.
#
# Source patterns mirrored from core/tests/validate_task.bats lines 7-24
# (setup) and lines 29-71 (make_plan helper). The make_plan helper is
# copied verbatim into this file for hermeticity (bats setup() runs per
# @test, and the helper is small enough that re-importing it would
# couple the two test files unnecessarily).

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
    # pwd -P to avoid the macOS /var -> /private/var symlink mismatch
    # (validate_task.bats lines 14-17).
    mkdir -p "$BATS_TEST_TMPDIR/home"
    cd "$BATS_TEST_TMPDIR/home"
    export TMPHOME
    TMPHOME=$(pwd -P)

    # The skill's run.sh calls `git status --porcelain=v1` and
    # `git worktree add`, which require TMPHOME to be a git repo. Initialise
    # one with a single empty commit on the `main` branch (matches the
    # fixture's base_ref: "main").
    git init -b main -q "$TMPHOME" >/dev/null 2>&1 || {
        # Fallback for git < 2.28: init then rename.
        git init -q "$TMPHOME" >/dev/null 2>&1
        ( cd "$TMPHOME" && git symbolic-ref HEAD refs/heads/main )
    }
    (
        cd "$TMPHOME"
        # Local identity so commit works even when host git config is absent.
        git config user.email "test@chantier.invalid"
        git config user.name  "chantier-test"
        # Empty seed commit -- base_ref needs a resolvable target.
        git commit --allow-empty -q -m "seed"
    )

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

@test "using-git-worktrees: end-to-end through chantier validate-task" {
    TASK="t1"
    SKILL="using-git-worktrees"

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
    ACC_BULLET_1="Baseline was checked via \`git status --porcelain=v1\` before any worktree creation."
    ACC_BULLET_2="A worktree was created at the recorded path, or the operation was skipped with the dirty baseline recorded in output.json."

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
    [ "$status" -eq 0 ]
    [ -f "$TASK_DIR/output.md" ]
    [ -f "$TASK_DIR/output.json" ]

    # output.json must be parseable JSON with all required fields.
    run jq -e '.baseline_clean | type == "boolean"' "$TASK_DIR/output.json"
    [ "$status" -eq 0 ]
    run jq -e '.baseline_diff_lines | type == "number"' "$TASK_DIR/output.json"
    [ "$status" -eq 0 ]
    run jq -e '.invariants_applied | length >= 3' "$TASK_DIR/output.json"
    [ "$status" -eq 0 ]

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
