#!/bin/sh
# Copyright (c) 2026 Chantier Contributors
# SPDX-License-Identifier: MIT
#
# Source: ADR 0001 Surface 3 + ADR 0002 Exit-code matrix + skills/subagent-driven-development/SKILL.md
# Entry point for the subagent-driven-development skill. Reads
# subtask_count and parent_brief from inputs.yml, emits N self-contained
# subtask_brief_<id>.md files (each starting with the three kernel
# invariants acknowledged verbatim), writes output.md + output.json with
# discipline metrics, and appends a skill.completed event to STATE.md
# via the chantier binary.

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
    printf 'subagent-driven-development: missing or unreadable inputs.yml at %s\n' \
        "$INPUTS_YML" >&2
    exit 2
}

# Parse scalar inputs via grep+sed (POSIX subset only; no yq).
SUBTASK_COUNT=$(grep -E '^subtask_count:' "$INPUTS_YML" | sed 's/^subtask_count:[[:space:]]*//; s/^"//; s/"$//')
PARENT_BRIEF=$(grep -E '^parent_brief:' "$INPUTS_YML" | sed 's/^parent_brief:[[:space:]]*//; s/^"//; s/"$//')

[ -n "$SUBTASK_COUNT" ] || { printf 'subagent-driven-development: required input missing: subtask_count\n' >&2; exit 2; }
[ -n "$PARENT_BRIEF" ]  || { printf 'subagent-driven-development: required input missing: parent_brief\n'  >&2; exit 2; }

# Validate subtask_count is a positive integer (>= 1). The inputs_schema
# does not encode `minimum` because the ADR 0002 JSON Schema subset
# profile does not list it; runtime validation here is the falsifiability
# point. Reject non-numeric or zero/negative values.
case "$SUBTASK_COUNT" in
    ''|*[!0-9]*)
        printf 'subagent-driven-development: subtask_count must be a non-negative integer (got %s)\n' \
            "$SUBTASK_COUNT" >&2
        exit 2
        ;;
esac
[ "$SUBTASK_COUNT" -ge 1 ] || {
    printf 'subagent-driven-development: subtask_count must be >= 1 (got %s)\n' \
        "$SUBTASK_COUNT" >&2
    exit 2
}

# Dependency presence: jq is required. Absence is a technical incident,
# exit 2 per the matrix in SKILL.md.
command -v jq >/dev/null 2>&1 || { printf 'subagent-driven-development: jq not found\n' >&2; exit 2; }

STARTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ---------------------------------------------------------------------------
# 2. Emit one subtask_brief_<id>.md per subtask.
# Each brief begins with the three kernel invariants read aloud verbatim
# (Invariant 5 proof contributor) and contains the parent_brief plus the
# per-subtask focus. The brief is the only thing that crosses the
# context boundary; everything the fresh invocation needs is in the
# file.
# ---------------------------------------------------------------------------
PARENT_REFS_TOTAL=0
ACK_TOTAL=0
: > "$TASK_DIR/briefs.jsonl"

i=1
while [ "$i" -le "$SUBTASK_COUNT" ]; do
    BRIEF_FILE="$TASK_DIR/subtask_brief_${i}.md"

    # Extract per-subtask focus if provided (i-th entry of the
    # subtask_focus list). Empty when absent or out of range.
    FOCUS=$(awk -v n="$i" '
        /^subtask_focus:/ { in_sf=1; idx=0; next }
        in_sf && /^[a-z_]+:/ { in_sf=0 }
        in_sf && /^[[:space:]]+-/ {
            idx++
            if (idx==n) {
                sub(/^[[:space:]]+-[[:space:]]*/, "")
                gsub(/"/, "")
                print
                exit
            }
        }
    ' "$INPUTS_YML")

    # Emit the brief: kernel acknowledgement preamble + subtask body.
    # Unquoted heredoc so $PARENT_BRIEF and $FOCUS interpolate. The
    # three kernel-invariant lines below must match the SKILL.md
    # Invariants section wording for the run.sh grep counter to
    # detect them (the prefix regex matches "N. Portability" /
    # "N. State log append-only" / "N. State writes containment").
    cat > "$BRIEF_FILE" <<EOF
# Subtask ${i}

## Kernel invariants (acknowledge before acting)

1. Portability. No file written by this subtask contains a harness identifier.
2. State log append-only. This subtask mutates STATE.md only via the chantier state-append entry point.
3. State writes containment. This subtask writes only inside paths declared in its task state_writes.

## Subtask brief

Parent brief: ${PARENT_BRIEF}

Subtask focus: ${FOCUS:-(no specific focus provided)}

This brief is a file on disk. It is the only context the fresh invocation needs.
EOF

    # Count kernel acknowledgements in this brief (expected per brief: 3).
    # Use wc -l on the matched lines for a deterministic single integer;
    # tr -d ' ' strips BSD-wc leading spaces (Pitfall 9). Defensive
    # empty-string normalisation. Bracketed by set +e / set -e because
    # grep exits 1 on no-match (Pitfall 3), which would abort the
    # script under set -eu.
    set +e
    _ack=$(grep -cE '^[0-9]+\. (Portability|State log append-only|State writes containment)' "$BRIEF_FILE")
    set -e
    [ -n "$_ack" ] || _ack=0
    ACK_TOTAL=$((ACK_TOTAL + _ack))

    # Count parent-context references (must be 0 for Invariant 4 to hold).
    # Same set +e / set -e bracketing + defensive normalisation.
    set +e
    _refs=$(grep -cE '(as discussed|per our earlier|the agreed approach|like we said|as mentioned)' "$BRIEF_FILE")
    set -e
    [ -n "$_refs" ] || _refs=0
    PARENT_REFS_TOTAL=$((PARENT_REFS_TOTAL + _refs))

    # Build per-brief JSON object and append to briefs.jsonl. All values
    # flow through jq --arg / --argjson; no printf %s into JSON.
    _words=$(wc -w < "$BRIEF_FILE" | tr -d ' ')
    [ -n "$_words" ] || _words=0
    jq -n \
        --arg     id    "$i" \
        --arg     path  "$BRIEF_FILE" \
        --argjson words "$_words" \
        '{id: $id, brief_path: $path, brief_word_count: $words}' \
        >> "$TASK_DIR/briefs.jsonl"

    i=$((i + 1))
done

# Slurp briefs.jsonl into a single JSON array for the main output.json.
BRIEFS_JSON=$(jq -s '.' "$TASK_DIR/briefs.jsonl")

ENDED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ---------------------------------------------------------------------------
# 3. Emit output.json via a single jq -n call.
# Every value flows through --arg (strings) or --argjson (numbers / JSON).
# No printf %s into JSON anywhere -- T-03-05-02 defence mirrored from
# core/bin/chantier line 196.
# ---------------------------------------------------------------------------
jq -n \
    --argjson count   "$SUBTASK_COUNT" \
    --argjson briefs  "$BRIEFS_JSON" \
    --argjson refs    "$PARENT_REFS_TOTAL" \
    --argjson ack     "$ACK_TOTAL" \
    --arg     started "$STARTED_AT" \
    --arg     ended   "$ENDED_AT" \
    --argjson inv     '[1,2,3,4,5]' \
    '{
        subtask_count:                          $count,
        subtask_briefs:                         $briefs,
        parent_context_refs_count:              $refs,
        subagent_invariants_acknowledged_count: $ack,
        started_at:                             $started,
        ended_at:                               $ended,
        invariants_applied:                     $inv
    }' > "$TASK_DIR/output.json"

# ---------------------------------------------------------------------------
# 4. Emit output.md.
# Unquoted heredoc so variables interpolate. The `## Acceptance` heading
# is load-bearing -- gate 5 of chantier validate-task does
# case-sensitive grep on `^## Acceptance$`. The two acceptance bullets
# are byte-identical to those declared in PLAN.md so gate 5's substring
# match passes.
# ---------------------------------------------------------------------------
cat > "$TASK_DIR/output.md" <<EOF
# Skill: subagent-driven-development

Started at $STARTED_AT (UTC); completed at $ENDED_AT.
Subtasks fanned out: $SUBTASK_COUNT.
Kernel acknowledgements across all briefs: $ACK_TOTAL.
Parent-context references across all briefs: $PARENT_REFS_TOTAL.

## Invariants applied

- Kernel #1 (NFR-001 portability)
- Kernel #2 (STATE.md append-only)
- Kernel #3 (state_writes containment)
- Skill #4 (self-contained subtask briefs)
- Skill #5 (kernel acknowledgement in every brief)

## Acceptance

- Every subtask brief is a self-contained file with the three kernel invariants acknowledged verbatim.
- No subtask brief references parent conversation context (parent_context_refs_count == 0).
EOF

# ---------------------------------------------------------------------------
# 5. Resolve the project root and append skill.completed event to STATE.md
# via the chantier binary. The binary expects to run from a directory
# containing `.planning/` (STATE_FILE and LOCKDIR are CWD-relative inside
# the binary). Walk up from TASK_DIR looking for `.planning/`. output.md,
# output.json, and every subtask_brief_<id>.md are already written -- never
# invoke state append before the outputs exist (Pitfall 4: log lies about
# completion if the script crashes mid-flow). The binary holds the
# mkdir-mutex; this skill does not lock STATE.md itself.
# Build the -r ref list dynamically so each brief travels with the
# task-completion event.
# ---------------------------------------------------------------------------
_root="$TASK_DIR"
while [ "$_root" != "/" ] && [ ! -d "$_root/.planning" ]; do
    _root=$(dirname "$_root")
done
[ -d "$_root/.planning" ] || {
    printf 'subagent-driven-development: could not locate .planning/ above %s\n' \
        "$TASK_DIR" >&2
    exit 2
}

STATE_APPEND_REFS=""
j=1
while [ "$j" -le "$SUBTASK_COUNT" ]; do
    STATE_APPEND_REFS="${STATE_APPEND_REFS} -r ${TASK_DIR}/subtask_brief_${j}.md"
    j=$((j + 1))
done

(
    cd "$_root"
    # shellcheck disable=SC2086
    # Word-splitting of $STATE_APPEND_REFS is intentional: IFS=\n means
    # each `-r path` pair is split into two positional args. Quoting
    # the variable would pass the whole string as one literal arg.
    chantier state append \
        -e skill.completed \
        -t "${CHANTIER_TASK_ID:-unknown}" \
        -s subagent-driven-development \
        -m "Subagent fan-out completed: ${SUBTASK_COUNT} briefs, ${ACK_TOTAL} kernel acknowledgements, ${PARENT_REFS_TOTAL} parent-context references" \
        -r "$TASK_DIR/output.md" \
        -r "$TASK_DIR/output.json" \
        $STATE_APPEND_REFS
)

exit 0
