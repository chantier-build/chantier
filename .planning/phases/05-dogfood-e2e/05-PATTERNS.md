# Phase 5: Dogfood E2E - Pattern Map

**Mapped:** 2026-05-30
**Files analyzed:** 8 (5 NEW, 3 MODIFIED)
**Analogs found:** 8 / 8 (100%)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `adapters/claude-code/run-task.sh` (MODIFY @~line 118) | adapter (POSIX-sh) | file-I/O (symlink staging) | `adapters/claude-code/run-task.sh:137-143` (existing state_reads loop) | exact (extend in-place) |
| `core/tests/adapter_upstream_e2e.bats` (NEW) | bats regression test | event-driven (adapter dispatch) | `core/tests/adapter_claude_code_e2e.bats` | exact |
| `core/tests/nfr_audits.bats` (NEW) | bats static audit (6 @tests) | batch (tree-walk grep) | `core/tests/adapter_isolation.bats` (NFR-001 @test) + `core/tests/skill_uniformity.bats` (multi-@test layout) | exact (audit shape) + role-match (multi-@test layout) |
| `tests/e2e/full_loop.bats` (NEW) | bats top-level integration test | event-driven (full loop: new → plan → dispatch → validate) | `core/tests/adapter_claude_code_e2e.bats` (setup/stub/dispatch/assertions) | exact (composes at full-loop scale) |
| `docs/adr/0004-surface-3-propagation.md` (NEW) | ADR (documentation) | static (Markdown contract) | `docs/adr/0003-workflow-skill-design-principles.md` | exact |
| `.planning/ROADMAP.md` (MODIFY) | planning doc (in-place edit) | static (strip GSD callout) | `.planning/ROADMAP.md:3` (the callout block to remove) | exact (self) |
| `.planning/STATE.md` (APPEND) | JSONL event log | event-driven (append-only) | `chantier state append` invocation pattern (binary call, no source edit) | exact (binary-only writer) |
| `.planning/phases/05-dogfood-e2e/05-SUMMARY.md` (NEW) | phase-close summary | static (Markdown report) | `.planning/phases/04-claude-code-adapter/04-SUMMARY.md` | exact |

---

## Pattern Assignments

### `adapters/claude-code/run-task.sh` (adapter, file-I/O — F3 fix at ~line 118)

**Analog:** `adapters/claude-code/run-task.sh` itself, lines 137-143 (the existing state_reads symlink loop).

**Locus:** Insert the new loop AFTER the `mkdir -p "$DOSSIER/reads" "$DOSSIER/upstream" "$DOSSIER/skill"` at line 118, near the existing `state_reads` loop at lines 137-143. The new loop is the byte-twin shape of the state_reads loop but parses `depends_on` instead.

**`extract_task_field` helper to reuse** (lines 21-54):

```sh
# Three modes: scalar, block-dash (used by state_reads, state_writes,
# depends_on), block-indent (used by inputs).
# block-dash mode prints one value per `- item` YAML line.
# Already POSIX-sh, already shellcheck-clean, already exercised by Phase 4 e2e.
extract_task_field() {
    awk -v task="$1" -v field="$2" -v mode="$3" '
        /^```yaml/ { in_yaml=1; buf=""; next }
        ...
        in_yaml { buf = buf $0 "\n" }
    ' "$4"
}
```

**Existing analog pattern — state_reads symlink loop** (lines 139-143):

```sh
# Byte-template for the F3 fix. Empty input is handled by `[ -n ... ] || continue`.
printf '%s\n' "$STATE_READS" | while IFS= read -r _sr_path; do
    [ -n "$_sr_path" ] || continue
    [ -e "$WORKTREE/$_sr_path" ] || continue
    ln -s "$WORKTREE/$_sr_path" "$DOSSIER/reads/$(basename "$_sr_path")" 2>/dev/null || true
done
```

**Target shape — F3 fix loop** (insert after line 143, before Section 3):

```sh
# F3 fix: stage upstream/<tN>/output.json for every tN in depends_on.
# Per-file symlink shape (ADR 0001 Surface 2 example uses upstream/t0/output.json).
# Symlink chosen over copy: tighter least-privilege; downstream reads only.
# If upstream output is missing, exit 2 (invocation error — operator must dispatch tN first).
DEPENDS_ON=$(extract_task_field "$TASK_ID" depends_on block-dash "$PLAN_PATH")
printf '%s\n' "$DEPENDS_ON" | while IFS= read -r _up_task; do
    [ -n "$_up_task" ] || continue
    _up_out="$WORKTREE/.planning/phases/$PHASE/tasks/$_up_task/output.json"
    if [ ! -f "$_up_out" ]; then
        printf 'run-task: depends_on=%s but %s not found; dispatch %s first\n' \
            "$_up_task" "$_up_out" "$_up_task" >&2
        exit 2
    fi
    mkdir -p "$DOSSIER/upstream/$_up_task"
    ln -s "$_up_out" "$DOSSIER/upstream/$_up_task/output.json" 2>/dev/null || \
        cp "$_up_out" "$DOSSIER/upstream/$_up_task/output.json"
done
```

**SPDX/copyright header** — already present at lines 1-3, preserved across the edit.

---

### `core/tests/adapter_upstream_e2e.bats` (bats regression test, NEW)

**Analog:** `core/tests/adapter_claude_code_e2e.bats` (293 lines, 1 @test).

**Imports & loaders** (lines 29-31):

```sh
setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
```

**REPO_ROOT canonicalization** (lines 33-42):

```sh
# Repo-relative paths -- BATS_TEST_DIRNAME is core/tests/
export CHANTIER="$BATS_TEST_DIRNAME/../bin/chantier"
export REPO_ROOT
REPO_ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)
export ADAPTER="$REPO_ROOT/adapters/claude-code/run-task.sh" # HARNESS_DENY_LIST_CHECK
# Expose chantier on PATH so the skill's final `chantier state append`
# call resolves inside the adapter subprocess.
export PATH="$REPO_ROOT/core/bin:$PATH"
```

**Worktree setup pattern** (lines 47-71):

```sh
mkdir -p "$BATS_TEST_TMPDIR/home"
cd "$BATS_TEST_TMPDIR/home"
export TMPHOME
TMPHOME=$(pwd -P)  # pwd -P canonicalizes macOS /var → /private/var symlink

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
```

**CHANTIER_CLAUDE_BIN stub** (lines 83-102) — verbatim reuse, single-quoted heredoc disables expansion:

```sh
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
```

**Two-task PLAN.md authoring** (extends analog's `make_plan` helper at lines 116-170 to TWO task blocks):

The analog's `make_plan` writes ONE task with `depends_on: []` — the F3 regression test writes the analog's t1 (depends_on:[]) AND a t2 (depends_on:[t1]) in the same PLAN.md so the test can dispatch sequentially and assert `upstream/t1/output.json` exists in t2's dossier.

**Assertion pattern — three-event signal** (lines 274-279, multiplied by 2 tasks):

```sh
_started=$(grep -cE '"event":"task\.started"' "$WORKTREE/.planning/STATE.md")
[ "$_started" -eq 2 ]
_skill=$(grep -cE '"event":"skill\.completed"' "$WORKTREE/.planning/STATE.md")
[ "$_skill" -eq 2 ]
_completed=$(grep -cE '"event":"task\.completed"' "$WORKTREE/.planning/STATE.md")
[ "$_completed" -eq 2 ]
```

**F3-specific assertion** (NEW for this file):

```sh
# F3 fix proof: t2's dossier has upstream/t1/output.json staged via symlink.
DOSSIER_T2="$WORKTREE/.chantier/dossiers/t2"
[ -e "$DOSSIER_T2/upstream/t1/output.json" ]
# (-e covers both regular files and symlinks; -L would assert symlink-strictly.)
```

**Error-surface pattern on adapter failure** (lines 213-219):

```sh
if [ "$status" -ne 0 ]; then
    printf 'adapter exit: %s\n' "$status" >&2
    printf 'adapter output: %s\n' "$output" >&2
    printf 'state log:\n' >&2
    cat "$WORKTREE/.planning/STATE.md" >&2 || true
fi
[ "$status" -eq 0 ]
```

---

### `core/tests/nfr_audits.bats` (bats static audit, six @tests, NEW)

**Analogs (composite):**
- **Audit shape:** `core/tests/adapter_isolation.bats` (124 lines, 1 @test, `find` + `case`-arm dispatch + `grep -v HARNESS_DENY_LIST_CHECK` filter).
- **Multi-@test layout:** `core/tests/skill_uniformity.bats` (82 lines, 3 @tests, each independent, shared `setup()` cd-to-repo-root).

**Imports & loaders** (skill_uniformity.bats:16-20):

```sh
setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    cd "$BATS_TEST_DIRNAME/../.."  # cd to repo root for relative tree walks
}
```

**NFR-001 audit @test — deny-list reuse pattern** (adapter_isolation.bats:42-122 — copy/delegate):

```sh
@test "nfr_audits: NFR-001 — no harness identifiers outside adapters/claude-code/" { # HARNESS_DENY_LIST_CHECK
    # Byte-identical deny-list to core/bin/chantier:687/:912 + adapter_isolation.bats:46.
    _full='mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode' # HARNESS_DENY_LIST_CHECK
    _narrow='@codebase|cursor|codex-cli|copilot-cli|gemini-cli|opencode' # HARNESS_DENY_LIST_CHECK

    _violations=""
    while IFS= read -r _file; do
        [ -n "$_file" ] || continue
        case "$_file" in
            core/bin/chantier|core/schemas/skill.json|core/tests/adapter_isolation.bats|core/tests/nfr_audits.bats)
                continue ;;
            skills/*/SKILL.md)
                _filter_claude='^[[:space:]]*-[[:space:]]*claude-code$' # HARNESS_DENY_LIST_CHECK
                if grep -v 'HARNESS_DENY_LIST_CHECK' "$_file" \
                   | grep -vE "$_filter_claude" \
                   | grep -qE "$_full"; then
                    _violations="${_violations}${_file}\n"
                fi ;;
            adapters/claude-code/*) # HARNESS_DENY_LIST_CHECK
                if grep -v 'HARNESS_DENY_LIST_CHECK' "$_file" \
                   | grep -qE "$_narrow"; then
                    _violations="${_violations}${_file}\n"
                fi ;;
            *)
                if grep -v 'HARNESS_DENY_LIST_CHECK' "$_file" \
                   | grep -qE "$_full"; then # HARNESS_DENY_LIST_CHECK
                    _violations="${_violations}${_file}\n"
                fi ;;
        esac
    done <<EOF
$(find core skills adapters -type f 2>/dev/null | grep -v 'test_helper/' | sort)
EOF
    [ -z "$_violations" ] || { printf '%b' "$_violations" >&2; false; }
}
```

**NFR-002 audit @test — shellcheck driver** (RESEARCH Discretion #5: per-file loop preferred for legibility):

```sh
@test "nfr_audits: NFR-002 — POSIX sh + jq only (shellcheck + bash-isms grep)" {
    command -v shellcheck >/dev/null 2>&1 || skip "shellcheck not installed"
    _sh_files=$(find core/bin core/tests adapters skills -type f \
        \( -name '*.sh' -o -name 'chantier' \) 2>/dev/null | sort)
    _violations=""
    for _f in $_sh_files; do
        shellcheck --shell=sh "$_f" >/dev/null 2>&1 || _violations="${_violations}${_f}\n"
    done
    [ -z "$_violations" ] || { printf 'shellcheck:\n%b' "$_violations" >&2; false; }

    # Grep for bash-only constructs (literal regex, byte-stable BSD/GNU).
    _bash_pat='\[\[ |<<<|mapfile|declare -a|local -a'
    for _f in $_sh_files; do
        if grep -E "$_bash_pat" "$_f" >/dev/null 2>&1; then
            printf 'bash-only construct in %s\n' "$_f" >&2; false
        fi
    done
}
```

**NFR-003 audit @test — STATE.md append-only static guard**:

```sh
@test "nfr_audits: NFR-003 — STATE.md append-only (no `>` redirect outside state_append)" {
    # Allowed: core/bin/chantier's state_append() function (the runtime guard).
    # Forbidden: any other source code redirecting to STATE.md (single `>`).
    _pat='>[[:space:]]*[^&].*STATE\.md'
    _violations=""
    while IFS= read -r _file; do
        [ -n "$_file" ] || continue
        case "$_file" in
            core/bin/chantier) continue ;;  # state_append() is the sanctioned writer
            *) if grep -qE "$_pat" "$_file"; then
                   _violations="${_violations}${_file}\n"
               fi ;;
        esac
    done <<EOF
$(find core skills adapters tests -type f \( -name '*.sh' -o -name '*.bats' \) 2>/dev/null | sort)
EOF
    [ -z "$_violations" ] || { printf '%b' "$_violations" >&2; false; }
}
```

**NFR-004 audit @test** — see RESEARCH.md §"Pattern 2" lines 516-544 for the skeleton (network primitives grep + URL-in-comment exemption + HARNESS_DENY_LIST_CHECK filter). Copy the skeleton verbatim.

**NFR-005 audit @test — non-English glyph regex** (RESEARCH Discretion #6 + Pitfall 5):

```sh
@test "nfr_audits: NFR-005 — English-only public artifacts (French stop-word density)" {
    # Recommended per Pitfall 5: grep for 5+ French stop-words OR > 10% lines
    # with [À-ÿ] accented chars. Catches accidental French leakage; does NOT
    # flag isolated loanwords (naïve, café, résumé).
    _stop_words='\bavec\b|\bdonc\b|\bainsi\b|\bpour\b|\bdans\b|\bc.est\b|\bn.est\b|\bcette\b|\bnous\b'
    _scan_paths='README.md LICENSE LICENSE-CREDITS CONTRIBUTING.md'
    _scan_dirs='docs/adr docs/vision.md docs/research core skills adapters tests'
    # Exempt: .planning/ (French session prose) and docs/strategy/ (sketches quote conversation)
    _violations=""
    while IFS= read -r _file; do
        [ -n "$_file" ] || continue
        _hits=$(grep -cE "$_stop_words" "$_file" 2>/dev/null || true)
        [ "$_hits" -ge 5 ] && _violations="${_violations}${_file}: $_hits French stop-words\n"
    done <<EOF
$(find $_scan_paths $_scan_dirs -type f 2>/dev/null | sort)
EOF
    [ -z "$_violations" ] || { printf '%b' "$_violations" >&2; false; }
}
```

**NFR-006 audit @test — MIT + collective copyright**:

```sh
@test "nfr_audits: NFR-006 — MIT + collective copyright + SPDX headers" {
    # Assert LICENSE starts with `MIT License`.
    head -1 LICENSE | grep -qx 'MIT License' || fail "LICENSE first line is not 'MIT License'"
    # Assert LICENSE-CREDITS exists.
    [ -f LICENSE-CREDITS ] || fail "LICENSE-CREDITS missing (NFR-006 collective copyright)"
    # Assert `Chantier Contributors` appears in LICENSE.
    grep -q 'Chantier Contributors' LICENSE || fail "LICENSE missing 'Chantier Contributors'"
    # Grep every *.sh for SPDX header (Phase 4 D-NFR-006 convention).
    _missing=""
    for _f in $(find core/bin core/tests adapters skills tests -type f -name '*.sh' 2>/dev/null | sort); do
        grep -q 'SPDX-License-Identifier: MIT' "$_f" || _missing="${_missing}${_f}\n"
    done
    [ -z "$_missing" ] || { printf 'missing SPDX header:\n%b' "$_missing" >&2; false; }
    # No per-person `(c) <name>` in LICENSE.
    grep -qE '\(c\)[[:space:]]+[A-Z][a-z]+[[:space:]]+[A-Z][a-z]+' LICENSE && \
        fail "LICENSE contains per-person attribution; collective copyright required"
}
```

**HARNESS_DENY_LIST_CHECK self-exemption case-arm** (adapter_isolation.bats:69-76, MUST be present for the NFR-001 audit's deny-list literals).

---

### `tests/e2e/full_loop.bats` (bats integration test, NEW)

**Analog:** `core/tests/adapter_claude_code_e2e.bats` (the shape mirror at full-loop scale).

**Path-relative loader (relative to `tests/e2e/`)** — RESEARCH §"Pattern 1" lines 348-391:

```sh
setup() {
    load '../../core/tests/test_helper/bats-support/load'
    load '../../core/tests/test_helper/bats-assert/load'
    export REPO_ROOT
    REPO_ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)
    export CHANTIER="$REPO_ROOT/core/bin/chantier"
    export ADAPTER="$REPO_ROOT/adapters/claude-code/run-task.sh"  # HARNESS_DENY_LIST_CHECK
    export PATH="$REPO_ROOT/core/bin:$PATH"
    mkdir -p "$BATS_TEST_TMPDIR/home"
    cd "$BATS_TEST_TMPDIR/home"
    export TMPHOME
    TMPHOME=$(pwd -P)
```

**CHANTIER_CLAUDE_BIN stub** — verbatim from `adapter_claude_code_e2e.bats:83-101` (Discretion #8: duplicate inline since the e2e variant has the same shape).

**Opt-in real-claude env gate** — D-04:

```sh
# D-04 opt-in: if the operator sets CHANTIER_E2E_REAL_CLAUDE=1, do NOT set
# CHANTIER_CLAUDE_BIN — the adapter then falls back to the real `claude`
# binary on PATH. CI never sets this flag; NFR-004 default offline holds.
if [ "${CHANTIER_E2E_REAL_CLAUDE:-}" != "1" ]; then
    export CHANTIER_CLAUDE_BIN="$BATS_TEST_TMPDIR/stub/claude"
fi
```

**`chantier new` invocation pattern** (NEW — no analog in core/tests/; the e2e test is the first caller in a test):

```sh
cd "$TMPHOME"
run "$CHANTIER" new chantier-e2e-dogfood
[ "$status" -eq 0 ]
cd "$TMPHOME/chantier-e2e-dogfood"
git init -q
git config user.email "test@chantier"
git config user.name "test"
git add -A
git commit -q -m "scaffold"
```

**Two-task PLAN.md authoring pattern** — RESEARCH lines 420-464 (heredoc with `<<'PLAN_EOF'` to disable expansion). Mirrors the analog's `make_plan` helper (lines 116-170) but written inline for the two-task case.

**Sequential dispatch + assertion** — RESEARCH lines 466-503:

```sh
# Dispatch t1 (no upstream).
run "$ADAPTER" t1
[ "$status" -eq 0 ]
[ -f ".planning/phases/dogfood-phase/tasks/t1/output.json" ]
# Dispatch t2 (depends_on: [t1] — F3 fix exercises upstream/ staging).
run "$ADAPTER" t2
[ "$status" -eq 0 ]
[ -f ".planning/phases/dogfood-phase/tasks/t2/output.json" ]
# validate-task green idempotence on both.
run "$CHANTIER" validate-task t1
[ "$status" -eq 0 ]
run "$CHANTIER" validate-task t2
[ "$status" -eq 0 ]
# F3 fix proof.
[ -e ".chantier/dossiers/t2/upstream/t1/output.json" ]
```

**Skill body copy pattern** (analog:178-183): cp SKILL.md + PRESSURE.md + run.sh from `$REPO_ROOT/skills/$SKILL/` into the synthetic project's `skills/$SKILL/`.

---

### `docs/adr/0004-surface-3-propagation.md` (ADR, NEW, Proposed status)

**Analog:** `docs/adr/0003-workflow-skill-design-principles.md` (216 lines, status Proposed, full ratification-path section).

**Section structure** (copy 1:1 from 0003):

```
# ADR 0004 — Surface 3 propagation

- **Status:** Proposed
- **Date proposed:** 2026-05-30
- **Date accepted:** —
- **Deciders:** Chantier founding contributors
- **Supersedes:** —
- **Superseded by:** —

> [blockquote: 3-paragraph synopsis]

---

## Provenance
## Context
## Decision
## Consequences
### Positive
### Negative
### Mitigations  (optional — 0003 has it; 0004 may omit if no mitigations)
## Alternatives considered
### Alternative A — [name]
### Alternative B — [name]
### Alternative C — [name]
## Open questions (deferred)
## Ratification path
## References
```

**Ratification-path block shape** (0003 lines 196-206 — adapt the conditions for ADR 0004):

```markdown
## Ratification path

This ADR remains in **Proposed** status until:

1. A second harness adapter (e.g., `adapters/cursor/`) ships and exercises
   the Surface 3 propagation contract.
2. A bats test under `tests/e2e/` proves the contract works on both adapters
   (output.md + output.json land in TASK_DIR; excluded artifacts remain
   only in the dossier).
3. A maintainer reviews this ADR with cross-harness evidence and either
   updates the contract or moves status to **Accepted**.

Until ratification, this ADR is advisory. The first cross-harness propagation
PR should reference this ADR explicitly.
```

**References section shape** (0003 lines 210-216) — list ADR 0001, ADR 0002, and the specific source-of-truth file path (`adapters/claude-code/run-task.sh:202-219` for the propagation block).

**Body content** — RESEARCH.md §"Code Examples — Example 1" (lines 739-844) provides a complete skeleton. Planner picks the exact prose; the section skeleton and Ratification-path shape are fixed by ADR 0003 precedent.

---

### `.planning/ROADMAP.md` (MODIFY — minimalist migration)

**Analog:** the file itself, the callout block at line 3.

**Locus** (the only required edit per D-07):

```diff
 # Roadmap: Chantier

-> **Format note (temporary):** This roadmap follows GSD's `gsd-tools` parser format because Chantier uses GSD as its bootstrap planning harness until its own runtime exists (Phase 2). The arc is documented in [STATE.md](STATE.md) under the `bootstrap.harness.chosen` event. Once Phase 5 (dogfood-e2e) ships, this file will be migrated back to Chantier's native format per ADR 0001 — at which point GSD will no longer be invoked in Chantier's own workflows.
-
 ## Overview
```

**Optional further cleanup** (RESEARCH §"State of the Art" + Example 2):
- Phase 5's `- [ ] Plans: TBD` line → `- [x] Plans: 4 plans (complete)` after Phase 5 close (normal phase-close housekeeping; not GSD-format migration).
- Phase 5 row in `## Progress` table → `Complete | 2026-05-30`.

**Frontmatter** — unchanged (already validates against `core/schemas/roadmap.json` per Phase 2 D-06 permissive `additionalProperties`).

**No schema change, no YAML-first rewrite, no `chantier validate-roadmap` subcommand** — per D-07 minimalist intent.

---

### `.planning/STATE.md` (APPEND — `cutover.completed` event via binary)

**Analog:** any prior `chantier state append` invocation in the project's git history. The pattern is **invoke the binary, do not edit the source**.

**Locus:** Run from project root in the final commit of Phase 5 (D-08).

**Invocation** (RESEARCH §"Code Examples — Example 3" lines 866-873):

```sh
chantier state append \
    --event cutover.completed \
    --summary "ROADMAP migrated to ADR 0001 native format. GSD ceases to be invoked in Chantier's own workflows." \
    --ref ".planning/ROADMAP.md" \
    --ref ".planning/STATE.md" \
    --ref "bootstrap.harness.chosen@2026-05-29T18:30:00Z"
```

**Event-name regex compliance** — ADR 0002 D-09 enforces `^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$`. `cutover.completed` matches. NFR-003 holds: the binary's `state_append()` mkdir-mutex is the only writer.

**NO SOURCE EDIT** — STATE.md is JSONL; only `chantier state append` writes. NFR-003 audit (this phase's `nfr_audits.bats` @test #3) is the static guard against any other source edits attempting to redirect to STATE.md.

---

### `.planning/phases/05-dogfood-e2e/05-SUMMARY.md` (NEW, phase close)

**Analog:** `.planning/phases/04-claude-code-adapter/04-SUMMARY.md` (215 lines, comprehensive phase-close report).

**Frontmatter** (lines 1-20):

```yaml
---
phase: 05-dogfood-e2e
status: complete
completed: 2026-05-30
plans:
  - 05-01
  - 05-02
  - 05-03
  - 05-04
requirements_completed:
  - NFR-001
  - NFR-002
  - NFR-003
  - NFR-004
  - NFR-005
  - NFR-006
bats_suite_before: 73/0   # going into Phase 5 (Phase 4 close)
bats_suite_after: 75/0    # after Phase 5 (plans 05-01..05-04)
shipped_artifacts:
  - core/tests/adapter_upstream_e2e.bats
  - core/tests/nfr_audits.bats
  - tests/e2e/full_loop.bats
  - docs/adr/0004-surface-3-propagation.md
satisfies_project_criterion:
  - "PROJECT.md v0.1.0 success criterion 5 (Chantier's own development is managed by Chantier)"
---
```

**Section structure** (mirror 04-SUMMARY.md):

```
# Phase 05: Dogfood E2E — Close Summary

[1-paragraph synopsis]

## Goal (quoted from ROADMAP.md §Phase 5)
## Plans Executed         (table: Plan | Subsystem | Outcome | SUMMARY)
## Verification Results
### ROADMAP Phase 5 Success Criteria   (table: # | Criterion | Status | Evidence | Command)
### NFR Verification                    (table: NFR | Status | Evidence | Command)
### Bats suite totals                   (table: boundary | Tests | Notes)
## Resolved Discretion Items            (table: Item | Resolution | Location)
## Surface 3 propagation codification   (or similar — points to ADR 0004)
## Handoff Notes for v0.2.0             (mirror Phase 4's "Handoff Notes for Phase 5")
### Deferred items (carried into v0.2.0 backlog)
## Self-Check: PASSED
```

**Self-Check footer pattern** (04-SUMMARY.md:144-154):

```markdown
## Self-Check: PASSED

- `.planning/phases/05-dogfood-e2e/05-SUMMARY.md` exists, ≥ 60 lines ✓
- `.planning/phases/05-dogfood-e2e/05-01-SUMMARY.md` exists ✓
- `.planning/phases/05-dogfood-e2e/05-02-SUMMARY.md` exists ✓
- `.planning/phases/05-dogfood-e2e/05-03-SUMMARY.md` exists ✓
- `.planning/phases/05-dogfood-e2e/05-04-SUMMARY.md` exists ✓
- ROADMAP.md Phase 5 entry marked complete ✓
- STATE.md cutover.completed + phase.completed events appended ✓
- bats core/tests/ tests/e2e/ 75/0 confirmed ✓
- shellcheck --shell=sh adapters/claude-code/run-task.sh clean ✓
- D-NN coverage check: 10 D-NN cited in §Decisions Locked ✓
```

---

## Shared Patterns

### Pattern A: `setup()` block for bats files (loaders + cd to repo root or REPO_ROOT canonicalization)

**Source:** `core/tests/skill_uniformity.bats:16-20` (simple) OR `core/tests/adapter_claude_code_e2e.bats:29-50` (full canonicalization with TMPHOME pwd -P).

**Apply to:** `core/tests/adapter_upstream_e2e.bats` (full canonicalization), `core/tests/nfr_audits.bats` (simple cd-to-repo-root), `tests/e2e/full_loop.bats` (full canonicalization with `../../core/tests/` relative load path).

```sh
setup() {
    load 'test_helper/bats-support/load'    # or '../../core/tests/test_helper/bats-support/load' for tests/e2e/
    load 'test_helper/bats-assert/load'
    cd "$BATS_TEST_DIRNAME/../.."           # for static audits OR full TMPHOME setup for e2e
}
```

### Pattern B: HARNESS_DENY_LIST_CHECK marker convention

**Source:** `core/bin/chantier:687,912` + every bats file in `core/tests/` that names a harness identifier.

**Apply to:** Every line in `core/tests/nfr_audits.bats`, `core/tests/adapter_upstream_e2e.bats`, `tests/e2e/full_loop.bats` that contains `claude-code`, `mcp__`, `claude_ai_`, `@codebase`, or any harness identifier — trailing `# HARNESS_DENY_LIST_CHECK` comment.

```sh
# Example from adapter_isolation.bats:46:
_full='mcp__|claude_ai_|@codebase|claude-code|cursor|...' # HARNESS_DENY_LIST_CHECK
```

The audit's per-file `grep -v 'HARNESS_DENY_LIST_CHECK'` step strips marker-tagged lines before applying the deny-list pattern.

### Pattern C: SPDX header on POSIX-sh files

**Source:** `adapters/claude-code/run-task.sh:1-3`.

**Apply to:** Any new `.sh` file (the F3 fix is in-place edit; no new .sh files in Phase 5 except the `CHANTIER_CLAUDE_BIN` stub inside `$BATS_TEST_TMPDIR/`, which is NOT in the audit scope per D-11). Bats files do NOT carry per-file SPDX (Phase 4 D-NFR-006 convention; project-level LICENSE governs).

```sh
#!/bin/sh
# Copyright (c) 2026 Chantier Contributors
# SPDX-License-Identifier: MIT
```

### Pattern D: Error-surface on bats assertion failure

**Source:** `core/tests/adapter_claude_code_e2e.bats:213-219` + `286-289`.

**Apply to:** All adapter-dispatch assertions in `tests/e2e/full_loop.bats` and `core/tests/adapter_upstream_e2e.bats`.

```sh
if [ "$status" -ne 0 ]; then
    printf 'adapter exit: %s\n' "$status" >&2
    printf 'adapter output: %s\n' "$output" >&2
    printf 'state log:\n' >&2
    cat "$WORKTREE/.planning/STATE.md" >&2 || true
fi
[ "$status" -eq 0 ]
```

### Pattern E: JSONL row counting via `grep -cE '"event":"<name>"'`

**Source:** `adapter_claude_code_e2e.bats:274-279`.

**Apply to:** All STATE.md event-count assertions in `tests/e2e/full_loop.bats` and `core/tests/adapter_upstream_e2e.bats`. Two-task chains: `-eq 2` instead of `-eq 1`.

### Pattern F: POSIX-portable find walk (no GNU-only flags)

**Source:** `adapter_isolation.bats:113-115`.

**Apply to:** All tree-walks in `nfr_audits.bats`. NO `-regextype`, NO `-print0` (use `<<EOF` with `find ... | sort`).

```sh
while IFS= read -r _file; do
    [ -n "$_file" ] || continue
    ...
done <<EOF
$(find core skills adapters -type f 2>/dev/null | grep -v 'test_helper/' | sort)
EOF
```

### Pattern G: `case`-arm path-specific exemption

**Source:** `adapter_isolation.bats:57-111`.

**Apply to:** `nfr_audits.bats` NFR-001 audit (deny-list with `core/bin/chantier`, `core/schemas/skill.json`, `skills/*/SKILL.md`, `adapters/claude-code/*`, default arms), NFR-003 audit (`core/bin/chantier` carve-out), NFR-005 audit (`.planning/` and `docs/strategy/` exclusion by walk-scope, not by case).

### Pattern H: Quoted heredoc for stub or PLAN.md authoring (disables shell expansion)

**Source:** `adapter_claude_code_e2e.bats:84` (`<<'STUB_EOF'`), RESEARCH lines 420-464 (`<<'PLAN_EOF'`).

**Apply to:** All inline file authoring in bats tests where `$VAR` in the body should NOT be expanded at test-run time. Use `<<'TAG'` (single-quoted tag). Use plain `<<TAG` only when expansion of `$WORKTREE`, `$TASK_ID`, etc. into the file is desired (e.g., env.sh from adapter line 124).

### Pattern I: Three-mode `extract_task_field` helper

**Source:** `adapters/claude-code/run-task.sh:21-54`.

**Apply to:** F3 fix loop (block-dash mode for `depends_on`). NOT to be hand-rolled — reuse the existing awk grammar.

### Pattern J: Symlink-with-cp-fallback for least-privilege file staging

**Source:** `adapters/claude-code/run-task.sh:142` (existing state_reads loop): `ln -s ... 2>/dev/null || true`.

**Apply to:** F3 fix loop. Variant: `ln -s ... 2>/dev/null || cp ...` (cp fallback if symlinks unsupported, e.g., on filesystems without symlink permission).

---

## No Analog Found

(empty — all 8 files have at least one strong analog in the codebase)

---

## Metadata

**Analog search scope:**
- `core/tests/` (10 bats files inspected; 3 selected as primary analogs)
- `adapters/claude-code/` (1 file: `run-task.sh`)
- `docs/adr/` (3 ADRs; 0003 selected for 0004)
- `.planning/phases/02-runtime-core/`, `.planning/phases/03-skill-library/`, `.planning/phases/04-claude-code-adapter/` (SUMMARY.md analogs; 04-SUMMARY.md selected)
- `.planning/ROADMAP.md` (self-analog for the in-place migration)

**Files scanned:** ~15 (full read of `adapter_claude_code_e2e.bats`, `adapter_isolation.bats`, `skill_uniformity.bats`, `run-task.sh`, `0003-...md` partial, `04-SUMMARY.md` partial, `ROADMAP.md` partial, `05-CONTEXT.md`, `05-RESEARCH.md`).

**Pattern extraction date:** 2026-05-30

## PATTERN MAPPING COMPLETE
