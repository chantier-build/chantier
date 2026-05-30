# Phase 4: Claude Code adapter - Pattern Map

**Mapped:** 2026-05-30
**Files analyzed:** 5 new files (1 adapter, 1 stub-fixture if extracted, 1 isolation bats, 1 e2e bats, 1 README)
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `adapters/claude-code/run-task.sh` | adapter (harness-glue shell entry point) | request-response (CLI in -> dossier-stage -> subprocess -> validation -> exit code) | `core/bin/chantier` (POSIX shell binary, same dispatch + state-append + validate-task surface) + `skills/test-driven-development/run.sh` (POSIX shell, dossier-aware, set +e bracketing) | exact (role-match: shell adapter; data flow: identical request-response pattern with bracketing) |
| `core/tests/adapter_isolation.bats` | test (static audit; greppable enforcement) | batch (walk file tree, grep, assert) | `core/tests/skill_uniformity.bats` (cross-tree audit, POSIX find, fail-on-violation) + `core/bin/chantier` lines 907-918 (`HARNESS_DENY_LIST_CHECK` self-scan marker) | exact (role-match: bats audit; data flow: identical fail-on-greppable-violation pattern) |
| `core/tests/adapter_claude_code_e2e.bats` | test (end-to-end skill execution through adapter) | request-response (setup TMPHOME -> make_plan -> dispatch -> assert outputs + STATE.md events) | `core/tests/skill_test_driven_development_e2e.bats` (TMPHOME, make_plan helper, fixture-driven, validate-task gate assertion) | exact (named mirror per D-13/D-14) |
| `adapters/claude-code/README.md` (planner discretion) | docs (operator-facing usage) | n/a | `skills/test-driven-development/SKILL.md` (frontmatter + Markdown body; English; NFR-005) | partial (different role: free-form English doc vs SKILL.md contract) — see "No Analog" notes |
| `adapters/claude-code/fixtures/claude-stub.sh` (planner discretion; may be inlined in bats setup instead) | fixture (deterministic CHANTIER_CLAUDE_BIN stub) | request-response (parse argv, exec ./skill/run.sh) | `skills/test-driven-development/run.sh` (POSIX `set -eu`, dossier-cd, sh ./run.sh, exit $?) | partial (the stub IS a simpler dossier-cd-and-exec wrapper; RESEARCH Pattern 5 recommends inlining in bats setup) |

## Pattern Assignments

### `adapters/claude-code/run-task.sh` (adapter, request-response)

**Primary analog:** `core/bin/chantier`
**Secondary analog:** `skills/test-driven-development/run.sh` (for the `set +e` bracketing of a subprocess that may exit non-zero)

**File header + shell prelude pattern** (copy verbatim from `core/bin/chantier:1-12`):
```sh
#!/bin/sh
# Copyright (c) 2026 Chantier Contributors
# SPDX-License-Identifier: MIT
#
# adapters/claude-code/run-task.sh -- Claude Code harness adapter (Phase 4 / FR-008)
# Source: ADR 0001 Surface 2 dossier + ADR 0002 exit-code matrix + D-01..D-16

set -eu
IFS='
'
LC_ALL=C
export LC_ALL
```
- `#!/bin/sh` (not `bash`) per NFR-002; D-01 extends substrate to the adapter.
- The literal `IFS=$'\n'` is written as a two-line single-quoted string (POSIX has no `$'...'`). Copy the exact bytes from `core/bin/chantier:9-10`.
- Header has no `claude-code` substring outside the path comment; the file path itself contains `claude-code` (D-10 carve-out).

**PLAN.md task lookup awk pattern** (copy verbatim shape from `core/bin/chantier:530-572`):
```sh
# Source: core/bin/chantier lines 530-572 (validate-task gate 1 extraction)
# RESEARCH Pattern 3: inline awk (do not add `chantier task-lookup` subcommand)

# Find PLAN.md whose YAML body contains `task: <id>`
_vt_plan_path=$(find .planning/phases -name '*PLAN.md' -type f 2>/dev/null \
    | sort | tail -1)
[ -n "$_vt_plan_path" ] || { printf 'run-task: PLAN.md not found\n' >&2; exit 2; }

if ! grep -q "task: $TASK_ID" "$_vt_plan_path" 2>/dev/null; then
    printf 'run-task: task %s not found in %s\n' "$TASK_ID" "$_vt_plan_path" >&2
    exit 2
fi

# Extract skill id from the matching task block (verbatim awk shape from chantier:555-572)
SKILL_ID=$(awk -v task="$TASK_ID" '
    /^```yaml/ { in_yaml=1; buf=""; next }
    /^```/ && in_yaml {
        in_yaml=0
        if (buf ~ "task: " task "(\n|$)") {
            n = split(buf, lines, "\n")
            for (i=1; i<=n; i++) {
                if (lines[i] ~ /^skill:/) {
                    gsub(/^skill:[[:space:]]*"?|"?[[:space:]]*$/, "", lines[i])
                    print lines[i]
                }
            }
        }
        buf=""
        next
    }
    in_yaml { buf = buf $0 "\n" }
' "$_vt_plan_path")
```
- Reuse the **identical** awk grammar from `chantier:530-572`. Drift between binary and adapter is a Phase 4 defect.
- The adapter needs at minimum: `skill`, `inputs:` block (verbatim copy for `inputs.yml`), `state_writes` (for `reads/` symlinks). Extract each with the same awk shape per field.

**Worktree validation pattern** (synthesizes Pitfall 5 + D-05):
```sh
# Source: RESEARCH Pitfall 5 (use --show-toplevel, not --is-inside-work-tree)
WORKTREE=$(git rev-parse --show-toplevel 2>/dev/null) || {
    printf 'run-task: not inside a git work tree (D-05)\n' >&2
    exit 2
}
cd "$WORKTREE"
```
- `--show-toplevel` sidesteps the `.git/`-subdirectory edge case AND the "strict-vs-lax" Open Question (RESEARCH recommends lax for v0.1).

**TASK_ID grammar validation pattern** (synthesizes Pitfall 6):
```sh
# Source: RESEARCH Pitfall 6 — shell injection via TASK_ID
case "$TASK_ID" in
    [a-z]*) ;;
    *) printf 'run-task: invalid task id: %s\n' "$TASK_ID" >&2; exit 3 ;;
esac
case "$TASK_ID" in
    *[!a-zA-Z0-9_-]*) printf 'run-task: task id contains invalid characters\n' >&2; exit 3 ;;
esac
```
- Matches the ADR 0002 event-name shape spirit (`core/bin/chantier:177-182` uses the same `case` pre-check pattern for event names).

**Dossier env.sh emission pattern** (D-07 triple safety; ADR 0001 Surface 2):
```sh
# Source: ADR 0001 Surface 2 lines 124-136 + D-07 belt-and-suspenders
mkdir -p "$DOSSIER/reads" "$DOSSIER/upstream" "$DOSSIER/skill"

cat > "$DOSSIER/env.sh" <<EOF
CHANTIER_TASK_ID="$TASK_ID"
CHANTIER_PHASE="$PHASE"
CHANTIER_WORKTREE="$WORKTREE"
export CHANTIER_TASK_ID CHANTIER_PHASE CHANTIER_WORKTREE
EOF
```
- Three exact env vars per ADR 0001:135 (`CHANTIER_TASK_ID`, `CHANTIER_PHASE`, `CHANTIER_WORKTREE`).
- Unquoted heredoc `<<EOF` is safe here because the three values are grammar-validated upstream (TASK_ID via Pitfall 6; WORKTREE via `git rev-parse`; PHASE via awk extraction of the YAML field).

**Skill body copy pattern** (D-02 + RESEARCH Pattern 2 `skill/` subdir):
```sh
# Source: RESEARCH Pattern 2 — self-contained dossier so subagent prompt is path-stable
cp "$WORKTREE/skills/$SKILL_ID/SKILL.md"    "$DOSSIER/skill/SKILL.md"
cp "$WORKTREE/skills/$SKILL_ID/PRESSURE.md" "$DOSSIER/skill/PRESSURE.md"
cp "$WORKTREE/skills/$SKILL_ID/run.sh"      "$DOSSIER/skill/run.sh"
chmod +x "$DOSSIER/skill/run.sh"
```
- Three files match the canonical `skills/<name>/` minimum per ADR 0001:84-91.

**`chantier state append` invocation pattern** (Pitfall 7 + Phase 3 subshell-cd):
```sh
# Source: RESEARCH Pitfall 7 — STATE_FILE / LOCKDIR are CWD-relative (core/bin/chantier:19-20)
# Phase 3 plan 03-02 established the subshell-cd pattern; reuse verbatim.
(cd "$WORKTREE" && chantier state append \
    -e task.started \
    -t "$TASK_ID" \
    -s "$SKILL_ID" \
    -m "dispatch via claude-code adapter" \
    -r "$DOSSIER")
```
- `state append` flags `-e EVENT -t TASK -s SKILL -m SUMMARY [-r REF]+` match `core/bin/chantier:159-169` (`getopts ":e:t:s:m:r:"`).
- Event names `task.started` / `task.completed` / `task.failed` satisfy the shape regex `^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$` (D-03; ADR 0002 §Event taxonomy).
- Open Question 2 recommendation: include `-r "$WORKTREE"` on `task.started` for parallel-worktree forensic correlation.

**Quoted heredoc + sed substitution for the dispatch prompt** (D-02 + Pitfall 1):
```sh
# Source: RESEARCH Pattern 4 + Pitfall 1 (heredoc injection via $() in operator data)
# Quoted heredoc disables ALL expansion; explicit sed substitution for the single var.

PROMPT=$(cat <<'PROMPT_EOF'
You are dispatched by the Chantier Claude Code adapter to execute one skill task.

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
```
- **Token choice:** `__DOSSIER__` (not `$DOSSIER` literal) because the quoted heredoc would otherwise emit the literal characters `$DOSSIER` which could be misread by some `sed` regex grammars. Underscored sentinel is unambiguous.
- The prompt has 13 prose lines (D-02 budget: ~15, max 30 before template promotion).
- The prompt body has no `claude-code` substring (path-only; harness name lives only in the directory path per D-10).
- Sed delimiter `|` chosen because `$DOSSIER` cannot contain `|` (validated upstream: it is `$WORKTREE/.chantier/dossiers/<TASK_ID>/` and TASK_ID matches `[a-z][a-zA-Z0-9_-]*`).

**Subprocess dispatch + exit-code bracketing pattern** (D-04 + Pitfall 2):
```sh
# Source: skills/test-driven-development/run.sh red-step bracketing pattern (Phase 3 plan 03-03)
# + RESEARCH Pitfall 2 (set -e aborts before task.failed state append)

# Export env for subprocess inheritance (D-07 layer 2 of triple)
export CHANTIER_TASK_ID="$TASK_ID"
export CHANTIER_PHASE="$PHASE"
export CHANTIER_WORKTREE="$WORKTREE"

set +e
"${CHANTIER_CLAUDE_BIN:-claude}" -p "$PROMPT"
CLAUDE_EXIT=$?
set -e

if [ "$CLAUDE_EXIT" -ne 0 ]; then
    (cd "$WORKTREE" && chantier state append \
        -e task.failed -t "$TASK_ID" -s "$SKILL_ID" \
        -m "claude -p exited $CLAUDE_EXIT" -r "$DOSSIER")
    exit 2  # D-04: invocation error
fi
```
- The `${CHANTIER_CLAUDE_BIN:-claude}` indirection is **mandatory** (D-15, NFR-004); hardcoding `claude` makes the e2e require network.
- `set +e` / `$? capture` / `set -e` bracket is the identical pattern in `skills/test-driven-development/run.sh` for the red-step exit capture (Phase 3 plan 03-03 precedent).

**`attempts/<n>/` quarantine pattern** (D-04 + Pitfall 3):
```sh
# Source: RESEARCH Pitfall 3 — glob-and-max idiom; %02d zero-pad (RESEARCH A4 recommendation)
TASK_DIR="$WORKTREE/.planning/phases/$PHASE/tasks/$TASK_ID"

NEXT_N=1
for d in "$TASK_DIR"/attempts/[0-9]*; do
    [ -d "$d" ] || continue
    n=$(basename "$d" | sed 's/^0*//')
    [ -z "$n" ] && n=0  # all-zeros directory name edge case
    [ "$n" -ge "$NEXT_N" ] && NEXT_N=$((n + 1))
done
ATTEMPT_DIR=$(printf '%s/attempts/%02d' "$TASK_DIR" "$NEXT_N")
mkdir -p "$ATTEMPT_DIR"
[ -f "$TASK_DIR/output.md" ]   && mv "$TASK_DIR/output.md"   "$ATTEMPT_DIR/"
[ -f "$TASK_DIR/output.json" ] && mv "$TASK_DIR/output.json" "$ATTEMPT_DIR/"
```

**Final dispatch + validate-task + completion** (full D-04 exit matrix wiring):
```sh
# Source: RESEARCH Code Example 1 lines 835-864 + D-04

set +e
chantier validate-task "$TASK_ID"
VT_EXIT=$?
set -e

if [ "$VT_EXIT" -ne 0 ]; then
    # Quarantine + task.failed + exit 1 (see attempts/<n>/ pattern above)
    # ...
    (cd "$WORKTREE" && chantier state append \
        -e task.failed -t "$TASK_ID" -s "$SKILL_ID" \
        -m "validate-task red; outputs in attempts/$NEXT_N" -r "$ATTEMPT_DIR")
    exit 1
fi

(cd "$WORKTREE" && chantier state append \
    -e task.completed -t "$TASK_ID" -s "$SKILL_ID" \
    -m "claude-code adapter dispatch + validate-task green" -r "$TASK_DIR")
exit 0
```

**Error message style** (copied from `core/bin/chantier` throughout):
```sh
# Source: core/bin/chantier — every error printf uses tool-name prefix + stderr
printf 'run-task: <human message>\n' >&2
exit <0|1|2|3>
```
- Pattern: `printf '<tool>: <message>\n' >&2; exit N`. Never `echo`. The prefix is the binary name (`chantier:` for the binary; `run-task:` for the adapter).

---

### `core/tests/adapter_isolation.bats` (test, batch greppable-enforcement)

**Primary analog:** `core/tests/skill_uniformity.bats` (cross-tree audit, POSIX find, fail-on-violation)
**Secondary analog:** `core/bin/chantier:907-918` (`HARNESS_DENY_LIST_CHECK` self-scan with marker pattern)

**Loaders + setup pattern** (copy verbatim from `skill_uniformity.bats:16-20`):
```bash
setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    cd "$BATS_TEST_DIRNAME/../.."
}
```
- `BATS_TEST_DIRNAME` is `core/tests/`; `../../` lands at repo root. Audit runs against the live repo tree (NOT TMPHOME — this is a static-source check).

**Deny-list literal pattern** (copy verbatim from `core/bin/chantier:687` and `:912`):
```bash
# Full deny-list (matches core/bin/chantier:687 and :912 byte-for-byte).
# Marker `HARNESS_DENY_LIST_CHECK` on each line containing the literal
# prevents the audit from triggering on its own source.
_full='mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode' # HARNESS_DENY_LIST_CHECK

# Narrower list applied INSIDE adapters/claude-code/ (D-10 carve-out:
# drops `claude-code` and `mcp__claude_ai_` from the forbidden set).
_narrow='@codebase|cursor|codex-cli|copilot-cli|gemini-cli|opencode' # HARNESS_DENY_LIST_CHECK
```
- **MUST** be byte-identical to `core/bin/chantier:687` and `:912`. RESEARCH §"Code Examples > Example 3" key invariant.
- **MUST** carry the `HARNESS_DENY_LIST_CHECK` marker (RESEARCH A3 recommendation: marker over skip-self, consistency with binary self-test).

**POSIX find + per-file deny-list grep pattern** (synthesizes `skill_uniformity.bats:24-30` + RESEARCH Pattern 6):
```bash
# Source: skill_uniformity.bats (POSIX find walk) + RESEARCH Pattern 6 (carve-out by path)

_violations=""
while IFS= read -r _file; do
    [ -n "$_file" ] || continue
    case "$_file" in
        core/bin/chantier) continue ;;  # has its own HARNESS_DENY_LIST_CHECK markers (D-11)
        core/tests/adapter_isolation.bats) continue ;;  # self — but markers also exempt; double-belt
        skills/*/SKILL.md)
            # `harness_adapters: - claude-code` is sanctioned in SKILL.md frontmatter;
            # filter that line out, then apply the full deny-list.
            if grep -vE '^[[:space:]]*-[[:space:]]*claude-code$' "$_file" \
               | grep -qE "$_full"; then  # HARNESS_DENY_LIST_CHECK
                _violations="${_violations}${_file}
"
            fi
            ;;
        adapters/claude-code/*)
            # D-10 carve-out: only the narrow list applies inside the adapter's own directory.
            if grep -qE "$_narrow" "$_file"; then  # HARNESS_DENY_LIST_CHECK
                _violations="${_violations}${_file}
"
            fi
            ;;
        *)
            if grep -qE "$_full" "$_file"; then  # HARNESS_DENY_LIST_CHECK
                _violations="${_violations}${_file}
"
            fi
            ;;
    esac
done <<EOF
$(find core skills adapters -type f 2>/dev/null \
    | grep -v 'HARNESS_DENY_LIST_CHECK\|test_helper/' \
    | sort)
EOF

if [ -n "$_violations" ]; then
    printf 'adapter_isolation: deny-list violations:\n%b' "$_violations" >&2
    false
fi
```
- POSIX `find ... -type f` only (no GNU `--include`); Pitfall 4.
- Audit scope is `core/`, `skills/`, `adapters/` per D-11. `docs/`, `.planning/` exempt by NOT being walked.
- `core/bin/chantier` exempt by `case` skip (D-11 explicit exemption).
- The `test_helper/` submodule paths are skipped via the outer `grep -v` to avoid noise from vendored bats-support / bats-assert internals.

**Test header + naming** (copy from `skill_uniformity.bats:1-15`):
```bash
#!/usr/bin/env bats

# Cross-tree NFR-001 carve-out audit (Phase 4 D-09, D-10, D-11, D-12).
#
# Audits the source tree for harness identifier leaks. The deny-list pattern
# is the same as core/bin/chantier --self-test (HARNESS_DENY_LIST_CHECK marker
# convention). Path-only carve-out: `adapters/claude-code/` may contain
# `claude-code` and `mcp__claude_ai_`; everywhere else those tokens are
# forbidden alongside the other harness names.
#
# Setup mirrors core/tests/skill_uniformity.bats for the cd-to-repo-root
# pattern and POSIX find walk.
```

---

### `core/tests/adapter_claude_code_e2e.bats` (test, end-to-end request-response)

**Primary analog:** `core/tests/skill_test_driven_development_e2e.bats` (named mirror per D-13; same fixture, same skill, adapter in the middle).

**Setup loaders + TMPHOME pattern** (copy verbatim from `skill_test_driven_development_e2e.bats:19-52`):
```bash
setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'

    export CHANTIER="$BATS_TEST_DIRNAME/../bin/chantier"
    export FIXTURES="$BATS_TEST_DIRNAME/fixtures"
    export REPO_ROOT
    REPO_ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)
    export ADAPTER="$REPO_ROOT/adapters/claude-code/run-task.sh"

    export PATH="$REPO_ROOT/core/bin:$PATH"

    mkdir -p "$BATS_TEST_TMPDIR/home"
    cd "$BATS_TEST_TMPDIR/home"
    export TMPHOME
    TMPHOME=$(pwd -P)
}
```
- **MUST** use `pwd -P` for macOS `/var` -> `/private/var` canonicalization (analog file line 40 explicit comment).
- **MUST** PATH-prepend `$REPO_ROOT/core/bin/` so `chantier state append` resolves inside the adapter subprocess.

**Worktree creation pattern** (Phase 4 ADDITION; D-05 requires it):
```bash
# Phase 4 setup ADDS: create a real git worktree per D-05
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
git add -A && git commit -q -m "initial"

WORKTREE_DIR="$BATS_TEST_TMPDIR/wt"
git worktree add -q "$WORKTREE_DIR" -b test-branch
export WORKTREE="$WORKTREE_DIR"
```
- D-05 explicitly: operator pre-creates the worktree; test acts as operator.
- The seed STATE.md frontmatter (`format_version: 0.1.0`) is required by `chantier state append` (Phase 2 contract).

**`CHANTIER_CLAUDE_BIN` stub pattern** (D-15 + RESEARCH Pattern 5; inline in bats setup):
```bash
# Source: RESEARCH Pattern 5 + Code Example 2 lines 907-927
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
DOSSIER=$(printf '%s\n' "$PROMPT" | sed -n 's|.*\(/.*\.chantier/dossiers/[^ "]*\).*|\1|p' | head -1)
[ -n "$DOSSIER" ] || { printf 'stub: no dossier in prompt\n' >&2; exit 1; }
printf 'subagent (stub): cd %s\n' "$DOSSIER"
cd "$DOSSIER" && . ./env.sh && sh ./skill/run.sh
exit $?
STUB_EOF
chmod +x "$BATS_TEST_TMPDIR/stub/claude"
export CHANTIER_CLAUDE_BIN="$BATS_TEST_TMPDIR/stub/claude"
```
- The stub is **inline in setup()**, not extracted to a separate fixture file (RESEARCH Wave 0 Gaps line 1157 explicit recommendation).
- Stub name is `claude` (literal binary name); lives under `$BATS_TEST_TMPDIR/stub/` so it is **outside** the audit scope (D-11) and contains the `claude` substring legitimately.
- Stub accepts `-p|--print` flag with the prompt as the next positional; ignores all other flags ("planner's call on exact ignored-flag handling" — minimal contract per Claude's Discretion).
- Stub parses `$DOSSIER` from the prompt by matching `/.chantier/dossiers/...` substring. Token `__DOSSIER__` is post-sed-substituted in the adapter, so the prompt the stub sees has the absolute path inline.

**make_plan helper pattern** (copy verbatim from `skill_test_driven_development_e2e.bats:61-104`):
- Helper builds a minimal PLAN.md at `$WORKTREE/.planning/phases/test-phase/PLAN.md` with one YAML task block.
- Args: `$1 task id, $2 state_writes newline-list, $3 acceptance newline-list, $4 skill id`.
- The helper uses `EOF_SW` / `EOF_ACC` distinct heredoc tokens to avoid collision with `EOF` in nested test setup.
- **Phase 4 variation:** the test also needs to embed an `inputs:` block in the PLAN.md task. The Phase 3 fixture (`core/tests/fixtures/skills/test-driven-development/dossier/inputs.yml`) maps to:
  ```yaml
  inputs:
    target_file: "core/bin/chantier"
    test_framework: "bats"
    phase: "red"
    test_command: "false"
  ```
  The adapter MUST extract this block from PLAN.md via awk (analog: `chantier:530-572` state_writes extraction) and write it as `$DOSSIER/inputs.yml`.

**Skill body copy pattern in test** (mirror of analog file lines 114-118):
```bash
mkdir -p "$WORKTREE/skills/$SKILL"
cp "$REPO_ROOT/skills/$SKILL/SKILL.md"    "$WORKTREE/skills/$SKILL/SKILL.md"
cp "$REPO_ROOT/skills/$SKILL/PRESSURE.md" "$WORKTREE/skills/$SKILL/PRESSURE.md"
cp "$REPO_ROOT/skills/$SKILL/run.sh"      "$WORKTREE/skills/$SKILL/run.sh"
chmod +x "$WORKTREE/skills/$SKILL/run.sh"
```
- The adapter looks up the skill in `$WORKTREE/skills/$SKILL_ID/`, NOT `$REPO_ROOT/skills/...`. The test must place the live skill body inside the worktree.

**D-13 jq-based output assertion pattern** (copy verbatim from analog lines 144-157):
```bash
# output.json must be parseable JSON with the discipline-proof fields.
run jq -e '.red_step_timestamp | type == "string"' "$TASK_DIR/output.json"
[ "$status" -eq 0 ]
run jq -e '.red_exit_code | type == "number"' "$TASK_DIR/output.json"
[ "$status" -eq 0 ]
_red_exit=$(jq -r '.red_exit_code' "$TASK_DIR/output.json")
[ "$_red_exit" -eq 1 ]
run jq -e '.red_step_timestamp | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")' "$TASK_DIR/output.json"
[ "$status" -eq 0 ]
run jq -e '.invariants_applied | length >= 4' "$TASK_DIR/output.json"
[ "$status" -eq 0 ]
```
- These five jq assertions are the **D-13 measurable signal**: `red_exit_code = 1`, `red_step_timestamp` matches ISO-8601 regex, `invariants_applied` length >= 4.
- ISO-8601 regex anchors with `^...Z$` second-precision UTC — matches `core/bin/chantier:188` `date -u +%Y-%m-%dT%H:%M:%SZ`.

**D-03 three-event STATE.md grep assertion** (NEW pattern; Phase 4 adds three event names):
```bash
# D-03 three-event signal: task.started + skill.completed + task.completed
_events=$(grep -cE '"event":"task\.started"|"event":"skill\.completed"|"event":"task\.completed"' \
    "$WORKTREE/.planning/STATE.md")
[ "$_events" -eq 3 ]
```
- **Three grep assertions, not one combined:** the planner may split this into three separate `[ ... -eq 1 ]` checks to surface which event is missing on failure.
- `task.started` and `task.completed` are the adapter's events (D-03); `skill.completed` is the skill's event (Phase 3 D-04).
- On failure path, the test expects `task.started` + `task.failed` (skill.completed may or may not appear).

**validate-task gate assertion pattern** (copy verbatim from analog lines 163-169):
```bash
cd "$TMPHOME"
run "$CHANTIER" validate-task "$TASK"
if [ "$status" -ne 0 ]; then
    printf 'validate-task output: %s\n' "$output" >&2
fi
[ "$status" -eq 0 ]
```
- **Phase 4 variation:** validate-task is invoked by the **adapter** as part of dispatch, not by the test directly. The test asserts the **adapter's** exit code is 0 (which guarantees validate-task was green by D-04). Optionally re-run validate-task directly to defend against an adapter bug that masks a red gate.

---

### `adapters/claude-code/README.md` (docs, planner discretion)

**Closest analog:** `skills/test-driven-development/SKILL.md` (English Markdown, NFR-005)
**Match quality:** partial — SKILL.md has YAML frontmatter; README does not.

**Recommendation:** Skip frontmatter (this is an operator-facing usage doc, not a contract artifact). Minimum content:
1. One-paragraph "what this adapter does" pointer to ADR 0001 Surface 2.
2. `adapters/claude-code/run-task.sh <task-id>` usage line.
3. Three env vars (`CHANTIER_TASK_ID`, `CHANTIER_PHASE`, `CHANTIER_WORKTREE`) operator should be aware of.
4. Exit-code table mirroring D-04.
5. `CHANTIER_CLAUDE_BIN` override for offline / stub use (cross-link to D-15).

**English only per NFR-005.** No emoji. No `claude-code` substring outside path references (carve-out tolerated but minimal use is hygiene).

---

### `adapters/claude-code/fixtures/claude-stub.sh` (fixture, planner discretion — RECOMMENDED INLINE)

**Closest analog:** `skills/test-driven-development/run.sh` (POSIX `set -eu`; argv parse; dossier-cd; exec sh ./run.sh; exit $?)
**Match quality:** partial — the stub is dramatically simpler (no jq, no output.json, no STATE.md).

**Recommendation per RESEARCH §"Wave 0 Gaps"** (line 1157): **DO NOT extract to a fixture file.** Inline the stub in `setup()` of `adapter_claude_code_e2e.bats` (RESEARCH Code Example 2 lines 907-927). Reasons:
1. The stub is ~12 lines; extraction costs more in cross-reference complexity than it saves.
2. Inline keeps the stub's contract co-located with the test's expectations.
3. Phase 3 e2e tests inline their fixtures the same way (no separate fixture script files; only data files under `core/tests/fixtures/skills/<id>/dossier/`).

If the planner overrides this recommendation and extracts the stub, the file MUST be made executable (`chmod +x`), MUST be located under `core/tests/fixtures/` or `adapters/claude-code/fixtures/`, and MUST be the **only** file with `claude` substring outside the audit's `adapters/claude-code/` carve-out — which would require updating the `adapter_isolation.bats` exemption list (additional surface area).

---

## Shared Patterns

### POSIX shell prelude (apply to: `adapters/claude-code/run-task.sh`; the inline bats stub)
**Source:** `core/bin/chantier:1-12`, `skills/test-driven-development/run.sh:1-16`
```sh
#!/bin/sh
# Copyright (c) 2026 Chantier Contributors
# SPDX-License-Identifier: MIT
set -eu
IFS='
'
LC_ALL=C
export LC_ALL
```
- `#!/bin/sh` (NFR-002 substrate; D-01 extends to adapter).
- Two-line literal newline `IFS=$'\n'`-equivalent (POSIX sh has no `$'...'` so the assignment spans two source lines, as in `core/bin/chantier:9-10`).
- `LC_ALL=C` for deterministic sort/grep (the binary uses this; the adapter should too).

### Error message style (apply to: all shell artifacts)
**Source:** `core/bin/chantier` throughout
```sh
printf '<tool>: <human message>\n' >&2
exit <0|1|2|3>
```
- Never `echo` (POSIX `echo` has portability traps).
- Prefix is the tool name (`chantier:` for the binary, `run-task:` for the adapter, `stub:` for the e2e stub).
- Exit codes follow D-04 / ADR 0002 matrix: 0 ok, 1 contract violation, 2 runtime/invocation error, 3 usage/environment error.

### `chantier state append` invocation (apply to: adapter only; skills already do this themselves per Phase 3 D-04)
**Source:** `core/bin/chantier:159-169` (getopts contract) + Phase 3 plan 03-02 subshell-cd fix
```sh
(cd "$WORKTREE" && chantier state append \
    -e <event.name> \
    -t "$TASK_ID" \
    -s "$SKILL_ID" \
    -m "<one-line summary>" \
    -r "$REF1" -r "$REF2")
```
- Always wrap in `(cd "$WORKTREE" && ...)` subshell — Pitfall 7.
- Event names: only `task.started`, `task.completed`, `task.failed` from the adapter (D-03). `skill.completed` is forbidden (Phase 3 D-04 boundary; skills own it).

### Bats test header convention (apply to: both new bats files)
**Source:** `core/tests/skill_uniformity.bats:1-15`, `core/tests/skill_test_driven_development_e2e.bats:1-17`
- Shebang `#!/usr/bin/env bats` on line 1.
- Block comment immediately after explaining scope, decisions referenced (D-XX), and analog file (which test this mirrors or extends).
- `setup()` loads `test_helper/bats-support/load` then `test_helper/bats-assert/load` (in that order; bats-assert depends on bats-support).
- `@test "<descriptive sentence with prefix>:"` naming (e.g., `"test-driven-development: red phase end-to-end..."`).

### `HARNESS_DENY_LIST_CHECK` marker convention (apply to: any file that legitimately contains deny-list literals)
**Source:** `core/bin/chantier:687` and `:912`
```sh
_deny_pat='mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode' # HARNESS_DENY_LIST_CHECK
```
- The marker is a literal trailing comment.
- Any line containing the marker is excluded from a self-scan via `grep -v 'HARNESS_DENY_LIST_CHECK'`.
- Adopted in: `core/bin/chantier --self-test` self-scan (`:907-918`), proposed for `adapter_isolation.bats` self-exclusion.
- The bats audit MUST filter its own walk output with `grep -v 'HARNESS_DENY_LIST_CHECK'` before applying the deny-list grep (RESEARCH A3 recommendation; Pattern 6 Option 2).

### Quoted heredoc + sed substitution (apply to: any heredoc that embeds operator-controlled data)
**Source:** RESEARCH Pattern 4 + Pitfall 1 (Phase 3 plan 03-05 open issue #8 precedent)
```sh
PROMPT=$(cat <<'PROMPT_EOF'
...literal text with __TOKEN__ placeholders...
PROMPT_EOF
)
PROMPT=$(printf '%s' "$PROMPT" | sed "s|__TOKEN__|$value|g")
```
- Quoted delimiter `<<'EOF'` disables `$(...)`, backticks, and `$VAR` expansion entirely (POSIX rule).
- Underscored sentinel tokens (`__DOSSIER__`) avoid `$VAR` collision in some `sed` grammars.
- Sed delimiter `|` chosen because path values cannot contain `|` (Chantier path grammar).

### `set +e` / `$? capture` / `set -e` bracketing (apply to: any subprocess that may exit non-zero)
**Source:** `skills/test-driven-development/run.sh` red-step pattern (Phase 3 plan 03-03) + RESEARCH Pitfall 2
```sh
set +e
"${SUBPROCESS}" -p "$ARG"
EXIT=$?
set -e

if [ "$EXIT" -ne 0 ]; then
    # emit failure event + exit with mapped code
fi
```
- Without the brackets, `set -eu` aborts before the failure-event emission, leaving STATE.md with a dangling `task.started`.
- Apply to: the `claude -p` call AND the `chantier validate-task` call in `run-task.sh`.

### POSIX find walk (apply to: `adapter_isolation.bats`; any future cross-tree audit)
**Source:** `core/tests/skill_uniformity.bats:23-30,55-67,70-79`
```sh
find <root> -mindepth 1 -maxdepth 1 -type d   # for directory enumeration
find <root> -type f 2>/dev/null               # for file walk
```
- POSIX flags only: `-type`, `-name`, `-print`, `-mindepth`, `-maxdepth` (latter two BSD extensions but macOS-compatible and used by skill_uniformity.bats).
- NEVER `--include`, NEVER `-regextype` (Pitfall 4).
- Stream results via `<<EOF` heredoc (analog: `core/bin/chantier:696-698` gate 4 walk; `skill_uniformity.bats` does it via direct `for _d in $_skill_dirs`).

---

## No Analog Found

Files where the closest match is partial; planner should rely on RESEARCH patterns and ADR contracts more than on a single analog file:

| File | Role | Data Flow | Reason | Fallback |
|------|------|-----------|--------|----------|
| `adapters/claude-code/README.md` | docs (operator-facing) | n/a | No comparable operator-facing usage doc exists yet in the repo (`.planning/`, `docs/adr/`, `docs/strategy/` are all internal/contract docs). | Follow English-prose Markdown style; NFR-005; no frontmatter; mirror the structure suggested in this PATTERNS.md README section. |
| `adapters/claude-code/fixtures/claude-stub.sh` IF extracted | fixture (CHANTIER_CLAUDE_BIN stub) | request-response | RESEARCH recommends inlining in bats setup, not extracting. If extracted anyway, simpler than any Phase 3 skill `run.sh`; closer to a test helper than a skill. | Use RESEARCH §"Code Examples > Example 2" lines 907-927 verbatim. Adjust paths if relocated. |

## Metadata

**Analog search scope:** `core/bin/chantier`, `core/tests/*.bats`, `core/tests/fixtures/skills/`, `skills/*/run.sh`, `docs/adr/0001`, `docs/adr/0002`, `.planning/phases/04-claude-code-adapter/04-CONTEXT.md`, `.planning/phases/04-claude-code-adapter/04-RESEARCH.md`.

**Files scanned:** 9 (listed above) + ~12 brief greps for cross-cutting patterns.

**Pattern extraction date:** 2026-05-30

**Key analog files the planner's `<read_first>` should point to:**

1. `core/bin/chantier` (lines 1-12, 159-209, 530-572, 666-702, 905-918) — adapter prelude, state_append contract, PLAN.md awk lookup, gate 4 deny-list grep, HARNESS_DENY_LIST_CHECK self-scan.
2. `core/tests/skill_test_driven_development_e2e.bats` (full file) — exact e2e mirror target per D-13/D-14.
3. `core/tests/skill_uniformity.bats` (full file, 82 lines) — POSIX find + cross-tree audit precedent for `adapter_isolation.bats`.
4. `skills/test-driven-development/run.sh` (lines 1-50) — POSIX `set -eu`, dossier-aware, exit-code matrix, `set +e` bracketing precedent.
5. `core/tests/fixtures/skills/test-driven-development/dossier/inputs.yml` (4 lines) — the deterministic red-phase fixture D-13 reuses verbatim (transcribed into PLAN.md `inputs:` block by the e2e).
6. `docs/adr/0001-state-skill-contract.md` lines 82-140 — Surface 2 canonical dossier shape (must match).
7. `docs/adr/0002-runtime-binary-and-state-format.md` lines 75-90 (event regex), 363-376 (mkdir-mutex), 378-389 (exit-code matrix), 391-403 (self-test gates) — contract anchors.
