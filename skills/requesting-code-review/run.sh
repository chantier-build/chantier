#!/bin/sh
# Copyright (c) 2026 Chantier Contributors
# SPDX-License-Identifier: MIT
#
# Source: ADR 0001 Surface 3 + ADR 0002 Exit-code matrix + skills/requesting-code-review/SKILL.md
# Entry point for the requesting-code-review skill. Reads a scoped
# base...head ref range and a list of scope paths from inputs.yml,
# computes the diff with a path filter (Pitfall 10), emits a
# review_prompt.md artifact, writes output.md + output.json, and appends
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
    printf 'requesting-code-review: missing or unreadable inputs.yml at %s\n' \
        "$INPUTS_YML" >&2
    exit 2
}

# Parse scalar inputs via grep+sed (POSIX subset only; no yq).
DIFF_BASE_REF=$(grep -E '^diff_base_ref:' "$INPUTS_YML" | sed 's/^diff_base_ref:[[:space:]]*//; s/^"//; s/"$//')
DIFF_HEAD_REF=$(grep -E '^diff_head_ref:' "$INPUTS_YML" | sed 's/^diff_head_ref:[[:space:]]*//; s/^"//; s/"$//')

# Parse scope_paths (YAML list) into a newline-separated shell variable.
# IFS is literal newline (set above), so unquoted expansion into the
# `git diff` command line preserves path-with-space values correctly.
SCOPE_PATHS=$(awk '
    /^scope_paths:/ { in_sp=1; next }
    in_sp && /^[a-z_]+:/ { in_sp=0 }
    in_sp && /^[[:space:]]+-/ {
        sub(/^[[:space:]]+-[[:space:]]*/, "")
        gsub(/"/, "")
        print
    }
' "$INPUTS_YML")

# reviewer_focus is optional; absence -> empty string flows into
# review_prompt.md as "(no specific focus declared in inputs.yml)".
REVIEWER_FOCUS=$(grep -E '^reviewer_focus:' "$INPUTS_YML" 2>/dev/null | sed 's/^reviewer_focus:[[:space:]]*//; s/^"//; s/"$//' || true)

[ -n "$DIFF_BASE_REF" ] || { printf 'requesting-code-review: required input missing: diff_base_ref\n' >&2; exit 2; }
[ -n "$DIFF_HEAD_REF" ] || { printf 'requesting-code-review: required input missing: diff_head_ref\n' >&2; exit 2; }
[ -n "$SCOPE_PATHS" ]   || { printf 'requesting-code-review: required input missing: scope_paths\n'   >&2; exit 2; }

# Dependency presence: jq and git are required. Absence is a technical
# incident, exit 2 per the matrix in SKILL.md.
command -v jq  >/dev/null 2>&1 || { printf 'requesting-code-review: jq not found\n'  >&2; exit 2; }
command -v git >/dev/null 2>&1 || { printf 'requesting-code-review: git not found\n' >&2; exit 2; }

# ---------------------------------------------------------------------------
# 2. Compute the scoped diff.
# `git diff "$BASE...$HEAD" -- $SCOPE_PATHS` is the canonical invocation
# per Pitfall 10. Three-dot range computes against the common ancestor;
# `--` separates ref args from path filters so a path starting with `-`
# cannot be parsed as a flag (threat T-03-04-01 mitigation).
#
# git diff exits 0 on no-diff, 1 on diff-present, >1 on error. Only >1 is
# a technical incident here -- 1 ("diff has content") is a business state
# and MUST NOT abort the script under set -e (Pitfall 3, Pitfall 10).
# ---------------------------------------------------------------------------
STARTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

set +e
# shellcheck disable=SC2086
# Word-splitting of $SCOPE_PATHS is intentional: with IFS=\n, each path
# becomes one positional arg, preserving paths that contain spaces.
git diff "${DIFF_BASE_REF}...${DIFF_HEAD_REF}" -- $SCOPE_PATHS > "$TASK_DIR/diff.patch" 2>/dev/null
DIFF_EXIT=$?
set -e

if [ "$DIFF_EXIT" -gt 1 ]; then
    printf 'requesting-code-review: git diff failed (exit %s) for %s...%s\n' \
        "$DIFF_EXIT" "$DIFF_BASE_REF" "$DIFF_HEAD_REF" >&2
    exit 2
fi

# Count files in the scoped diff via --name-only. The same set +e bracket
# applies (exit 1 with content is fine; >1 is a technical incident, but
# the previous diff call already established we are past that bar).
set +e
# shellcheck disable=SC2086
DIFF_FILE_COUNT=$(git diff --name-only "${DIFF_BASE_REF}...${DIFF_HEAD_REF}" -- $SCOPE_PATHS 2>/dev/null | wc -l | tr -d ' ')
set -e
# Defensive normalisation: BSD wc may emit empty under odd conditions.
[ -n "$DIFF_FILE_COUNT" ] || DIFF_FILE_COUNT=0

# ---------------------------------------------------------------------------
# 3. Emit review_prompt.md (the artifact the reviewer reads).
# The prompt cites the base/head refs and scope paths verbatim from
# inputs, embeds the reviewer_focus hint (or a placeholder), and appends
# the diff inside a fenced code block. printf %s is used throughout so
# backslash-escapes in user-supplied text are NOT interpreted.
# ---------------------------------------------------------------------------
REVIEW_PROMPT_PATH="$TASK_DIR/review_prompt.md"
{
    printf '# Review request\n\n'
    printf 'Base ref: %s\n' "$DIFF_BASE_REF"
    printf 'Head ref: %s\n' "$DIFF_HEAD_REF"
    printf 'Scope paths:\n'
    printf '%s\n' "$SCOPE_PATHS" | sed 's/^/  - /'
    printf '\n'
    if [ -n "$REVIEWER_FOCUS" ]; then
        printf '## Reviewer focus\n\n%s\n\n' "$REVIEWER_FOCUS"
    else
        printf '## Reviewer focus\n\n(no specific focus declared in inputs.yml)\n\n'
    fi
    printf '## Diff\n\n'
    printf '```diff\n'
    cat "$TASK_DIR/diff.patch"
    printf '```\n'
} > "$REVIEW_PROMPT_PATH"

REVIEW_PROMPT_WORD_COUNT=$(wc -w < "$REVIEW_PROMPT_PATH" | tr -d ' ')
[ -n "$REVIEW_PROMPT_WORD_COUNT" ] || REVIEW_PROMPT_WORD_COUNT=0

ENDED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ---------------------------------------------------------------------------
# 4. Emit output.json via a single jq -n call.
# Every value flows through --arg (strings) or --argjson (numbers / JSON).
# No printf %s into JSON anywhere -- T-03-04-02 defence mirrored from
# core/bin/chantier line 196.
# ---------------------------------------------------------------------------
jq -n \
    --arg     base    "$DIFF_BASE_REF" \
    --arg     head    "$DIFF_HEAD_REF" \
    --argjson count   "$DIFF_FILE_COUNT" \
    --arg     path    "$REVIEW_PROMPT_PATH" \
    --argjson words   "$REVIEW_PROMPT_WORD_COUNT" \
    --arg     started "$STARTED_AT" \
    --arg     ended   "$ENDED_AT" \
    --argjson inv     '[1,2,3,4]' \
    '{
        diff_base_ref:            $base,
        diff_head_ref:            $head,
        diff_file_count:          $count,
        review_prompt_path:       $path,
        review_prompt_word_count: $words,
        started_at:               $started,
        ended_at:                 $ended,
        invariants_applied:       $inv
    }' > "$TASK_DIR/output.json"

# ---------------------------------------------------------------------------
# 5. Emit output.md.
# Unquoted heredoc so $STARTED_AT, $DIFF_BASE_REF etc. interpolate. The
# `## Acceptance` heading is load-bearing -- gate 5 of chantier
# validate-task does case-sensitive grep on `^## Acceptance$`. The two
# acceptance bullets are byte-identical to those declared in PLAN.md so
# gate 5's substring match passes.
# ---------------------------------------------------------------------------
cat > "$TASK_DIR/output.md" <<EOF
# Skill: requesting-code-review

Started at $STARTED_AT (UTC); completed at $ENDED_AT.
Scoped diff: \`$DIFF_BASE_REF...$DIFF_HEAD_REF\` over declared scope_paths.
Diff file count: $DIFF_FILE_COUNT.
Review prompt: $REVIEW_PROMPT_PATH ($REVIEW_PROMPT_WORD_COUNT words).

## Invariants applied

- Kernel #1 (NFR-001 portability)
- Kernel #2 (STATE.md append-only)
- Kernel #3 (state_writes containment)
- Skill #4 (scoped-diff discipline)

## Acceptance

- The review request cited an explicit base...head ref range and at least one path filter.
- A review_prompt.md artifact was emitted at the recorded path.
EOF

# ---------------------------------------------------------------------------
# 6. Resolve the project root and append skill.completed event to STATE.md
# via the chantier binary. The binary expects to run from a directory
# containing `.planning/` (STATE_FILE and LOCKDIR are CWD-relative inside
# the binary). Walk up from TASK_DIR looking for `.planning/`. output.md,
# output.json, and review_prompt.md are already written -- never invoke
# state append before the outputs exist (Pitfall 4: log lies about
# completion if the script crashes mid-flow). The binary holds the
# mkdir-mutex; this skill does not lock STATE.md itself.
# ---------------------------------------------------------------------------
_root="$TASK_DIR"
while [ "$_root" != "/" ] && [ ! -d "$_root/.planning" ]; do
    _root=$(dirname "$_root")
done
[ -d "$_root/.planning" ] || {
    printf 'requesting-code-review: could not locate .planning/ above %s\n' \
        "$TASK_DIR" >&2
    exit 2
}

(
    cd "$_root"
    chantier state append \
        -e skill.completed \
        -t "${CHANTIER_TASK_ID:-unknown}" \
        -s requesting-code-review \
        -m "Review request prepared; scoped to $DIFF_BASE_REF...$DIFF_HEAD_REF on declared scope_paths" \
        -r "$TASK_DIR/output.md" \
        -r "$TASK_DIR/output.json" \
        -r "$REVIEW_PROMPT_PATH"
)

exit 0
