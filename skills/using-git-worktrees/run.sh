#!/bin/sh
# Copyright (c) 2026 Chantier Contributors
# SPDX-License-Identifier: MIT
#
# Source: ADR 0001 Surface 3 + ADR 0002 Exit-code matrix + skills/using-git-worktrees/SKILL.md
# Entry point for the using-git-worktrees skill. Performs the
# clean-baseline check, conditionally creates a worktree, runs the
# setup command inside it, emits output.md and output.json, and appends
# a skill.completed event to STATE.md via the chantier binary.

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
    printf 'using-git-worktrees: missing or unreadable inputs.yml at %s\n' \
        "$INPUTS_YML" >&2
    exit 2
}

# Parse the three required scalars via grep+sed (POSIX subset only; no yq).
# Pattern: ^field:[ \t]*"?value"?  -- strip leading "field:" and any quotes.
BRANCH_NAME=$(grep -E '^branch_name:'   "$INPUTS_YML" | sed 's/^branch_name:[[:space:]]*//;   s/^"//; s/"$//')
SETUP_COMMAND=$(grep -E '^setup_command:' "$INPUTS_YML" | sed 's/^setup_command:[[:space:]]*//; s/^"//; s/"$//')
BASE_REF=$(grep -E '^base_ref:'         "$INPUTS_YML" | sed 's/^base_ref:[[:space:]]*//;     s/^"//; s/"$//')

[ -n "$BRANCH_NAME" ]   || { printf 'using-git-worktrees: required input missing: branch_name\n'   >&2; exit 2; }
[ -n "$SETUP_COMMAND" ] || { printf 'using-git-worktrees: required input missing: setup_command\n' >&2; exit 2; }
[ -n "$BASE_REF" ]      || { printf 'using-git-worktrees: required input missing: base_ref\n'      >&2; exit 2; }

# Dependency presence: jq and git are required. Absence is a technical
# incident, exit 2 per the matrix in SKILL.md.
command -v jq  >/dev/null 2>&1 || { printf 'using-git-worktrees: jq not found\n'  >&2; exit 2; }
command -v git >/dev/null 2>&1 || { printf 'using-git-worktrees: git not found\n' >&2; exit 2; }

# ---------------------------------------------------------------------------
# 2. Clean-baseline check.
# git status --porcelain=v1 prints one line per change (modified, staged,
# or untracked); v1 is stable. BSD wc emits leading spaces, so strip them
# before any arithmetic comparison.
# ---------------------------------------------------------------------------
STARTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
BASELINE_CHECK_CMD="git status --porcelain=v1"
DIRTY_LINES=$(git status --porcelain=v1 2>/dev/null | wc -l | tr -d ' ')
# Defensive: if the previous command produced empty output, normalise to 0.
[ -n "$DIRTY_LINES" ] || DIRTY_LINES=0

if [ "$DIRTY_LINES" -eq 0 ]; then
    BASELINE_CLEAN="true"
else
    BASELINE_CLEAN="false"
fi

# ---------------------------------------------------------------------------
# 3. Conditional worktree creation.
# Worktree lives under the per-task state_writes scope so Invariant 3
# (state_writes containment) holds. A new branch is created from base_ref
# so we never disturb the caller's existing branches.
# ---------------------------------------------------------------------------
WORKTREE_PATH=""
SETUP_EXIT_CODE=-1

if [ "$BASELINE_CLEAN" = "true" ]; then
    # Candidate path inside the task directory (state_writes-contained).
    _candidate="${TASK_DIR}/worktree"

    # `git worktree add -b NAME PATH BASE_REF` is atomic per git's own
    # semantics (no manual mkdir+mv race). Failure here is a business
    # outcome (e.g., branch name collision), not a technical incident:
    # capture and continue with WORKTREE_PATH="" so output.json records it.
    set +e
    git worktree add -b "$BRANCH_NAME" "$_candidate" "$BASE_REF" >/dev/null 2>&1
    _wt_exit=$?
    set -e

    if [ "$_wt_exit" -eq 0 ]; then
        WORKTREE_PATH="$_candidate"
        # Run setup_command inside the worktree. set +e/-e bracket (Pitfall 3)
        # captures the exit code without aborting the script under set -e.
        set +e
        ( cd "$WORKTREE_PATH" && sh -c "$SETUP_COMMAND" ) >/dev/null 2>&1
        SETUP_EXIT_CODE=$?
        set -e
    fi
fi

ENDED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ---------------------------------------------------------------------------
# 4. Emit output.json via a single jq -n call.
# Every value flows through --arg (strings) or --argjson (numbers / JSON).
# No printf %s into JSON anywhere (T-02-04-INJ defence, mirrored from
# core/bin/chantier line 196).
# ---------------------------------------------------------------------------
jq -n \
    --arg     started "$STARTED_AT" \
    --arg     ended   "$ENDED_AT" \
    --arg     cmd     "$BASELINE_CHECK_CMD" \
    --arg     path    "$WORKTREE_PATH" \
    --arg     clean   "$BASELINE_CLEAN" \
    --argjson dirty   "$DIRTY_LINES" \
    --argjson setup   "$SETUP_EXIT_CODE" \
    --argjson inv     '[1,2,3,4]' \
    '{
        baseline_clean:         ($clean == "true"),
        baseline_diff_lines:    $dirty,
        baseline_check_command: $cmd,
        worktree_path:          $path,
        setup_exit_code:        $setup,
        started_at:             $started,
        ended_at:               $ended,
        invariants_applied:     $inv
    }' > "$TASK_DIR/output.json"

# ---------------------------------------------------------------------------
# 5. Emit output.md.
# Unquoted heredoc so $STARTED_AT, $WORKTREE_PATH etc. interpolate. The
# `## Acceptance` heading is load-bearing -- gate 5 of chantier
# validate-task does case-sensitive grep on `^## Acceptance$`. The two
# acceptance bullets are byte-identical to those declared in PLAN.md so
# gate 5's substring match passes.
# ---------------------------------------------------------------------------
if [ -n "$WORKTREE_PATH" ]; then
    _wt_display="$WORKTREE_PATH"
else
    _wt_display="(skipped -- baseline not clean)"
fi

cat > "$TASK_DIR/output.md" <<EOF
# Skill: using-git-worktrees

Started at $STARTED_AT (UTC); completed at $ENDED_AT.
Baseline check: \`$BASELINE_CHECK_CMD\` reported $DIRTY_LINES dirty lines.
Worktree path: $_wt_display.

## Invariants applied

- Kernel #1 (NFR-001 portability)
- Kernel #2 (STATE.md append-only)
- Kernel #3 (state_writes containment)
- Skill #4 (clean baseline before work)

## Acceptance

- Baseline was checked via \`git status --porcelain=v1\` before any worktree creation.
- A worktree was created at the recorded path, or the operation was skipped with the dirty baseline recorded in output.json.
EOF

# ---------------------------------------------------------------------------
# 6. Resolve the project root and append skill.completed event to STATE.md
# via the chantier binary. The binary expects to run from a directory
# containing `.planning/` (STATE_FILE and LOCKDIR are CWD-relative inside
# the binary). Walk up from TASK_DIR looking for `.planning/`. output.md
# and output.json are already written -- never invoke state append before
# the outputs exist (Pitfall 4: log lies about completion if the script
# crashes mid-flow). The binary holds the mkdir-mutex; this skill does
# not lock STATE.md itself.
# ---------------------------------------------------------------------------
_root="$TASK_DIR"
while [ "$_root" != "/" ] && [ ! -d "$_root/.planning" ]; do
    _root=$(dirname "$_root")
done
[ -d "$_root/.planning" ] || {
    printf 'using-git-worktrees: could not locate .planning/ above %s\n' \
        "$TASK_DIR" >&2
    exit 2
}

(
    cd "$_root"
    chantier state append \
        -e skill.completed \
        -t "${CHANTIER_TASK_ID:-unknown}" \
        -s using-git-worktrees \
        -m "Skill using-git-worktrees completed; see output.json for measured invariants" \
        -r "$TASK_DIR/output.md" \
        -r "$TASK_DIR/output.json"
)

exit 0
