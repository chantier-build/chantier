#!/bin/sh
# Copyright (c) 2026 Chantier Contributors
# SPDX-License-Identifier: MIT
#
# adapters/claude-code/run-task.sh -- Claude Code harness adapter (Phase 4 / FR-008)
# Source: ADR 0001 Surface 2 + ADR 0002 exit matrix + D-01..D-16

set -eu
IFS='
'
LC_ALL=C
export LC_ALL

# ---------------------------------------------------------------------------
# extract_task_field(field, mode, plan_path)
#   Awk grammar byte-identical shape to core/bin/chantier:530-572.
#   mode=scalar : emit single line (e.g. `skill:`)
#   mode=block-dash : emit `- value` items (e.g. `state_writes:`)
#   mode=block-indent : emit indented child lines (e.g. `inputs:`)
# ---------------------------------------------------------------------------
extract_task_field() {
    awk -v task="$1" -v field="$2" -v mode="$3" '
        /^```yaml/ { in_yaml=1; buf=""; next }
        /^```/ && in_yaml {
            in_yaml=0
            if (buf ~ "task: " task "(\n|$)") {
                collecting=0
                n = split(buf, lines, "\n")
                for (i=1; i<=n; i++) {
                    line = lines[i]
                    if (mode == "scalar") {
                        if (line ~ "^" field ":") {
                            gsub("^" field ":[[:space:]]*\"?|\"?[[:space:]]*$", "", line)
                            print line
                        }
                        continue
                    }
                    if (line ~ "^" field ":") { collecting=1; continue }
                    if (collecting && line ~ /^[a-z]/) { collecting=0 }
                    if (collecting && mode == "block-dash" && line ~ /^[[:space:]]+-/) {
                        sub(/^[[:space:]]+-[[:space:]]*"?/, "", line)
                        sub(/"?[[:space:]]*$/, "", line)
                        print line
                    } else if (collecting && mode == "block-indent" && line ~ /^[[:space:]]/) {
                        sub(/^[[:space:]]+/, "", line)
                        print line
                    }
                }
            }
            buf=""; next
        }
        in_yaml { buf = buf $0 "\n" }
    ' "$4"
}

# ---------------------------------------------------------------------------
# Section 1 -- Preflight
# ---------------------------------------------------------------------------

# D-16: single positional task-id, no flags in v0.1
TASK_ID="${1:-}"
if [ -z "$TASK_ID" ]; then
    printf 'run-task: usage: run-task.sh <task-id>\n' >&2; exit 3
fi

# Pitfall 6: shell-injection guard (mirrors core/bin/chantier:177-182).
case "$TASK_ID" in
    [a-z]*) ;;
    *) printf 'run-task: invalid task id: %s\n' "$TASK_ID" >&2; exit 3 ;;
esac
case "$TASK_ID" in
    *[!a-zA-Z0-9_-]*)
        printf 'run-task: task id contains invalid characters: %s\n' "$TASK_ID" >&2; exit 3 ;;
esac

# D-04 environment-error boundary (exit 3): claude binary OR D-15 override; jq; chantier.
if ! command -v claude >/dev/null 2>&1 && [ -z "${CHANTIER_CLAUDE_BIN:-}" ]; then
    printf 'run-task: claude binary not found and CHANTIER_CLAUDE_BIN unset (D-15)\n' >&2; exit 3
fi
command -v jq       >/dev/null 2>&1 || { printf 'run-task: jq required (NFR-002)\n' >&2; exit 3; }
command -v chantier >/dev/null 2>&1 || { printf 'run-task: chantier required on PATH\n' >&2; exit 3; }

# Pitfall 5 + D-05 lax (RESEARCH A5): --show-toplevel accepts both linked
# worktrees and the main checkout for v0.1 dev-loop ergonomics.
WORKTREE=$(git rev-parse --show-toplevel 2>/dev/null) || {
    printf 'run-task: not inside a git work tree (D-05)\n' >&2; exit 2
}
cd "$WORKTREE"

# D-16: inline PLAN.md lookup (RESEARCH A4: no new chantier task-lookup subcommand).
PLAN_PATH=""
for _p in $(find .planning/phases -name '*PLAN.md' -type f 2>/dev/null | sort); do
    if grep -q "task: $TASK_ID" "$_p" 2>/dev/null; then PLAN_PATH="$_p"; break; fi
done
if [ -z "$PLAN_PATH" ]; then
    printf 'run-task: task %s not found in any .planning/phases/*/PLAN.md\n' "$TASK_ID" >&2; exit 2
fi
PHASE=$(basename "$(dirname "$PLAN_PATH")")

SKILL_ID=$(extract_task_field "$TASK_ID" skill scalar "$PLAN_PATH")
if [ -z "$SKILL_ID" ]; then
    printf 'run-task: could not extract skill id for task %s\n' "$TASK_ID" >&2; exit 2
fi

SKILL_MD="$WORKTREE/skills/$SKILL_ID/SKILL.md"
if [ ! -f "$SKILL_MD" ]; then
    printf 'run-task: skill body not found at %s\n' "$SKILL_MD" >&2; exit 2
fi

INPUTS_BODY=$(extract_task_field "$TASK_ID" inputs       block-indent "$PLAN_PATH")
STATE_READS=$(extract_task_field "$TASK_ID" state_reads  block-dash   "$PLAN_PATH")

# ---------------------------------------------------------------------------
# Section 2 -- Dossier staging (ADR 0001 Surface 2 + D-06 + D-07)
# ---------------------------------------------------------------------------

DOSSIER="$WORKTREE/.chantier/dossiers/$TASK_ID"
mkdir -p "$DOSSIER/reads" "$DOSSIER/upstream" "$DOSSIER/skill"

printf '%s\n' "$INPUTS_BODY" > "$DOSSIER/inputs.yml"

# D-07 layer 1: env.sh in dossier. Unquoted heredoc safe -- all three values
# are grammar-validated (TASK_ID via Pitfall 6; WORKTREE via git; PHASE via basename).
cat > "$DOSSIER/env.sh" <<EOF
CHANTIER_TASK_ID="$TASK_ID"
CHANTIER_PHASE="$PHASE"
CHANTIER_WORKTREE="$WORKTREE"
export CHANTIER_TASK_ID CHANTIER_PHASE CHANTIER_WORKTREE
EOF

# D-02 + RESEARCH Pattern 2 self-contained dossier (path-stable subagent prompt).
cp "$WORKTREE/skills/$SKILL_ID/SKILL.md"    "$DOSSIER/skill/SKILL.md"
cp "$WORKTREE/skills/$SKILL_ID/PRESSURE.md" "$DOSSIER/skill/PRESSURE.md"
cp "$WORKTREE/skills/$SKILL_ID/run.sh"      "$DOSSIER/skill/run.sh"
chmod +x "$DOSSIER/skill/run.sh"

# state_reads symlinks (ADR 0001 Surface 2; RESEARCH A6 symlink-preferred).
# Phase 4 e2e: empty list, no-op. upstream/ on depends_on deferred to Phase 5.
printf '%s\n' "$STATE_READS" | while IFS= read -r _sr_path; do
    [ -n "$_sr_path" ] || continue
    [ -e "$WORKTREE/$_sr_path" ] || continue
    ln -s "$WORKTREE/$_sr_path" "$DOSSIER/reads/$(basename "$_sr_path")" 2>/dev/null || true
done

# ---------------------------------------------------------------------------
# Section 3 -- Dispatch (D-01 + D-02 + D-03 + D-04 + D-07 + D-15)
# ---------------------------------------------------------------------------

# D-03 task.started (refs include $WORKTREE per RESEARCH A2). Pitfall 7 subshell-cd.
(cd "$WORKTREE" && chantier state append \
    -e task.started \
    -t "$TASK_ID" \
    -s "$SKILL_ID" \
    -m "dispatch via claude-code adapter" \
    -r "$DOSSIER" \
    -r "$WORKTREE")

# D-07 layer 2: subprocess env inheritance.
export CHANTIER_TASK_ID="$TASK_ID"
export CHANTIER_PHASE="$PHASE"
export CHANTIER_WORKTREE="$WORKTREE"

# D-02 + Pitfall 1: quoted heredoc disables ALL expansion; explicit sed
# substitutes the single __DOSSIER__ token. ~13 prose lines (D-02 ~15 budget).
PROMPT=$(cat <<'PROMPT_EOF'
You are dispatched by the Chantier adapter to execute one skill task.

Your working directory is the task dossier: __DOSSIER__

Do this, in order:
  1. cd "__DOSSIER__"
  2. Source env.sh: . ./env.sh
  3. Read skill/SKILL.md end-to-end. Acknowledge (in your own words) which
     Invariants listed in `## Invariants` apply to this task and why.
  4. Execute the skill: sh ./skill/run.sh
  5. Report the exit code from run.sh as your final line: "EXIT $?"

Do not invent additional steps. The discipline is in skill/SKILL.md.
Do not edit any file outside the paths declared in skill/SKILL.md state_writes.
PROMPT_EOF
)
PROMPT=$(printf '%s' "$PROMPT" | sed "s|__DOSSIER__|$DOSSIER|g")

# Pitfall 2 + D-01 + D-15 bracketed dispatch. Transcript capture on real-claude
# path only (RESEARCH A1); the deterministic stub needs no extra logging.
set +e
if [ -z "${CHANTIER_CLAUDE_BIN:-}" ]; then
    claude -p "$PROMPT" > "$DOSSIER/subagent.transcript.log" 2>&1
else
    "$CHANTIER_CLAUDE_BIN" -p "$PROMPT"
fi
CLAUDE_EXIT=$?
set -e

if [ "$CLAUDE_EXIT" -ne 0 ]; then
    (cd "$WORKTREE" && chantier state append \
        -e task.failed -t "$TASK_ID" -s "$SKILL_ID" \
        -m "claude -p exited $CLAUDE_EXIT" -r "$DOSSIER")
    exit 2
fi

# Surface 3 propagation: the skill ran from $DOSSIER (cwd was set by the
# subagent / stub via `cd "$DOSSIER"`), so it wrote output.md, output.json,
# and any skill-specific artifacts at the dossier root. ADR 0001 Surface 3
# requires those outputs to land in state_writes -- i.e. under
# .planning/phases/<phase>/tasks/<task>/. Copy every plain file at the
# dossier root EXCEPT the inputs and adapter-owned artifacts (inputs.yml,
# env.sh, subagent.transcript.log) and the subdirectories (reads/, upstream/,
# skill/). D-08 dossier preservation is honored: this is a copy, not a move;
# the original files remain in the dossier for forensic inspection.
TASK_DIR="$WORKTREE/.planning/phases/$PHASE/tasks/$TASK_ID"
mkdir -p "$TASK_DIR"
for _out in "$DOSSIER"/*; do
    [ -f "$_out" ] || continue
    case "$(basename "$_out")" in
        inputs.yml|env.sh|subagent.transcript.log) continue ;;
    esac
    cp "$_out" "$TASK_DIR/"
done

# Pitfall 2 bracket for validate-task. CWD already $WORKTREE.
set +e
chantier validate-task "$TASK_ID"
VT_EXIT=$?
set -e

if [ "$VT_EXIT" -ne 0 ]; then
    # Pitfall 3 + RESEARCH A4: glob-and-max + %02d zero-pad. Preserve prior attempts.
    NEXT_N=1
    for _d in "$TASK_DIR"/attempts/[0-9]*; do
        [ -d "$_d" ] || continue
        _n=$(basename "$_d" | sed 's/^0*//')
        [ -z "$_n" ] && _n=0
        [ "$_n" -ge "$NEXT_N" ] && NEXT_N=$((_n + 1))
    done
    ATTEMPT_DIR=$(printf '%s/attempts/%02d' "$TASK_DIR" "$NEXT_N")
    mkdir -p "$ATTEMPT_DIR"
    [ -f "$TASK_DIR/output.md" ]   && mv "$TASK_DIR/output.md"   "$ATTEMPT_DIR/"
    [ -f "$TASK_DIR/output.json" ] && mv "$TASK_DIR/output.json" "$ATTEMPT_DIR/"

    (cd "$WORKTREE" && chantier state append \
        -e task.failed -t "$TASK_ID" -s "$SKILL_ID" \
        -m "validate-task red; outputs in attempts/$(printf '%02d' "$NEXT_N")" \
        -r "$ATTEMPT_DIR")
    exit 1
fi

# D-08: dossier preserved. D-04 green boundary.
(cd "$WORKTREE" && chantier state append \
    -e task.completed -t "$TASK_ID" -s "$SKILL_ID" \
    -m "claude-code adapter dispatch + validate-task green" \
    -r "$TASK_DIR")
exit 0
