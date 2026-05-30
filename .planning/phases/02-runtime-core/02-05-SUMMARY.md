---
phase: 02-runtime-core
plan: "05"
subsystem: core/bin/chantier
tags: [validate-task, new-project, adr-0001-gates, schema-validator, scaffold, bats, posix-sh]
dependency_graph:
  requires: [02-02, 02-04]
  provides: [FR-002, FR-004]
  affects: [02-06]
tech_stack:
  added: []
  patterns:
    - jq subset-validator (type, required, properties, additionalProperties, pattern, enum, items)
    - awk frontmatter extractor (top-level scalars, frontmatter subset profile)
    - awk task-block parser using continue (not next) inside for-loops to avoid awk record-skip bug
    - temp-file pattern for propagating exit codes across pipeline subshells (verify_acceptance)
    - quoted vs unquoted heredoc idiom for scaffold generation (Pitfall 8)
    - cd && pwd -P path canonicalization for traversal rejection (Security Domain row 2)
key_files:
  modified:
    - core/bin/chantier
    - core/tests/validate_task.bats
    - core/tests/new.bats
decisions:
  - key: jq-not-postfix
    choice: "Use (expr | not) instead of not(expr) for jq 1.6 compatibility"
    rationale: "jq 1.6 does not have not/1; RESEARCH Pattern 5 used prefix not() which fails on the host machine. Postfix (expr | not) is correct POSIX jq."
  - key: verify_acceptance-tempfile
    choice: "Use a temp file to propagate missing-criterion flag from while loop"
    rationale: "RESEARCH Pattern 4 gate 5 uses 'missing=1' inside a while-in-pipe loop which runs in a subshell, losing the assignment. Temp file avoids the subshell exit-code loss."
  - key: awk-continue-not-next
    choice: "Use continue instead of next inside awk for-loops for task block parsing"
    rationale: "awk next inside a for-loop jumps to the next input record (not next loop iteration), breaking the loop prematurely. RESEARCH Pattern 4 awk idiom used next incorrectly inside for."
  - key: repo-root-three-levels-up
    choice: "Compute repo_root as dirname(plan)/../../.. (3 levels up)"
    rationale: "PLAN.md lives at <repo>/.planning/phases/<phase>/PLAN.md; dirname gives the phase dir; ../../.. gives <repo>. Two levels would give .planning."
  - key: setup-canonicalize-tmphome
    choice: "Canonicalize TMPHOME via pwd -P in bats setup()"
    rationale: "macOS resolves /var/folders/... to /private/var/folders/... via symlink. repo_root (computed via cd && pwd -P) uses the /private/ prefix; skill paths built from TMPHOME must match."
  - key: scaffold-heredoc-mixing
    choice: "Unquoted heredoc for PROJECT/REQUIREMENTS/ROADMAP (need $name/$(date)); quoted for STATE.md/config.json"
    rationale: "Pitfall 8 audit: STATE.md and config.json have no variables to interpolate and must not expand any $-expressions; PROJECT/REQUIREMENTS/ROADMAP interpolate only $name and $(date -u +%Y-%m-%d)."
metrics:
  duration: "~60 minutes"
  completed: "2026-05-30"
  tasks_completed: 2
  files_modified: 3
---

# Phase 02 Plan 05: validate-task + new project scaffold — Summary

**One-liner:** All 5 ADR 0001 gates enforced in `chantier validate-task` (path canonicalization, output.md existence, jq schema validation, harness deny-list, acceptance bullets); `chantier new` scaffolds 5 schema-valid files with TODO stubs; 64 bats tests green across all suites.

## What Was Built

### Helpers (committed in b71de8c)

**`validate_against_schema(target, schema)`** — jq subset-validator per RESEARCH Pattern 5. Implements: `type`, `required`, `properties`, `additionalProperties`, `pattern`, `enum`, `items`. Uses postfix `(expr | not)` instead of RESEARCH's prefix `not(expr)` which fails on jq 1.6. Violations go to stderr prefixed `schema violation: `. Returns 0 if none, 1 if any.

**`extract_frontmatter_as_json(file)`** — awk+jq frontmatter extractor per RESEARCH §"Code Examples". Handles top-level scalars only (frontmatter subset profile; ADR 0002 constraint).

**`extract_acceptance(plan, task)`** — awk task-block parser extracting acceptance bullet list. Uses `continue` (not `next`) inside for-loops to avoid awk record-skip.

**`extract_output_acceptance_body(output_md)`** — awk extractor for the Acceptance section body. Heading regex: `^##[[:space:]]+Acceptance[[:space:]]*$` (case-sensitive per D-Discretion #10).

**`verify_acceptance(plan, task, output_md)`** — Checks each criterion appears in Acceptance section. Uses a temp file (`mktemp`) to propagate the failure flag out of the pipeline subshell (avoiding RESEARCH Pattern 4's subshell exit-code loss bug).

### validate_task() (committed in d8f4a98)

- `--plan PATH` override; default lookup: `find .planning/phases -name '*PLAN.md'`
- Task block parsed from PLAN.md using awk with `continue` in for-loops
- **Gate 1**: path canonicalization via `cd $(dirname) && pwd -P`; repo root is 3 levels above PLAN.md; rejects `../../` traversal and absolute paths
- **Gate 2**: `[ -s "$TASK_DIR/output.md" ]`
- **Gate 3**: `validate_against_schema` against `$(dirname SKILL.md)/outputs_schema.json`
- **Gate 4**: grep deny-list on all files in skill dir except SKILL.md itself; only when `portable: true`
- **Gate 5**: `verify_acceptance` with temp-file pattern; `^##\s+Acceptance\s*$` heading required
- Missing TASK_ID → exit 3; unknown task → exit 3; all gates pass → exit 0 with "task N validated"

### new_project() (in core/bin/chantier, tested in 63e3a08)

- Refuses to overwrite existing dir: exit 1
- Missing name: exit 3
- Creates `NAME/.planning/phases/` + 5 files via heredocs
- PROJECT.md / REQUIREMENTS.md / ROADMAP.md: unquoted heredoc (interpolates `$name`, `$(date -u +%Y-%m-%d)`)
- STATE.md / config.json: quoted heredoc (no expansion; literal content only — Pitfall 8)
- STATE.md: frontmatter only, JSONL-empty body (D-13)
- All scaffold files: ASCII-only (D-12), TODO stubs (D-11), section headings, no Chantier leakage

### Test files

- `validate_task.bats`: 350 lines, 14 @test blocks (gates 1-5 isolated failures + happy path + usage errors)
- `new.bats`: 192 lines, 14 @test blocks (5-file scaffold, frontmatter fields, JSONL-empty, TODO stubs, no leakage, ASCII, integration)

## Verification Results

### shellcheck
```
shellcheck -s sh core/bin/chantier → exit 0 (zero errors, zero warnings)
```

### bats suites (64 total)
```
new.bats:           14/14 ok
self_test.bats:     11/11 ok
state_append.bats:  18/18 ok
state_show.bats:     7/7  ok
validate_task.bats: 14/14 ok
Total: 64/64 green
```

### chantier --self-test
```
self-test: all green (16 checks, all ok)
```

### Integration round-trip
```
chantier new demo && cd demo && chantier state append -e bootstrap.session.started -m "init"
→ exits 0; STATE.md contains valid JSONL line
```

### Binary stats
- Line count: 975 lines (expected ~700–900; slightly over due to thorough gate implementations)
- No `flock` keyword (grep confirms)
- HARNESS_DENY_LIST_CHECK gate clean (2 marked lines: _deny_pat assignments in self_test + gate 4)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] jq `not(expr)` not valid in jq 1.6**
- Found during: Task 1 gate 3 implementation
- Issue: RESEARCH Pattern 5 uses `and not ($expr)` — jq 1.6 does not have `not/1` (prefix form). The filter failed with `not/1 is not defined`. `validate_against_schema` silently returned 0 for all inputs.
- Fix: Changed to `and (($expr) | not)` — the correct POSIX jq postfix boolean negation
- Files modified: core/bin/chantier
- Commit: d8f4a98

**2. [Rule 1 - Bug] awk `next` inside for-loop broke task block parsing**
- Found during: Task 1 gate 1 implementation (state_writes extraction returned empty)
- Issue: RESEARCH Pattern 4 uses `next` inside a `for` loop inside an awk action. In awk, `next` moves to the next INPUT RECORD (not next loop iteration). This caused the for-loop to abort prematurely after the first match.
- Fix: Changed `next` to `continue` (POSIX awk for-loop iteration keyword) inside all for-loops in the task-block parser
- Files modified: core/bin/chantier
- Commit: d8f4a98

**3. [Rule 1 - Bug] verify_acceptance subshell exit-code loss**
- Found during: Task 1 gate 5 implementation
- Issue: RESEARCH Pattern 4 gate 5 `verify_acceptance` sets `missing=1` inside a `while` loop that reads from a pipeline (`extract_acceptance ... | while`). In POSIX sh, the `while` loop in a pipeline runs in a subshell; `missing=1` is lost when the subshell exits. Function always returned 0.
- Fix: Use `mktemp` temp file to communicate failure flag across the subshell boundary
- Files modified: core/bin/chantier
- Commit: d8f4a98

**4. [Rule 1 - Bug] repo_root computed 2 levels up (should be 3)**
- Found during: Task 1 gate 3 (skill lookup returned empty)
- Issue: PLAN.md is at `<repo>/.planning/phases/<phase>/PLAN.md`. Two `..` from the phase dir lands in `.planning/`, not `<repo>/`. Skill at `<repo>/skills/` was never found.
- Fix: Changed `cd "$(dirname "$PLAN")/../.."` to `cd "$(dirname "$PLAN")/../../.."`
- Files modified: core/bin/chantier
- Commit: d8f4a98

**5. [Rule 1 - Bug] macOS /var -> /private/var symlink mismatch in bats tests**
- Found during: Task 1 gate 3 tests (skill found on disk but not by binary)
- Issue: bats `$BATS_TEST_TMPDIR` is under `/var/folders/...`. The binary resolves `repo_root` via `cd && pwd -P` which gives `/private/var/folders/...`. File existence checks on the `/private/` prefixed path failed when the file was written to the `/var/` path.
- Fix: Added `TMPHOME=$(pwd -P)` canonicalization in bats `setup()` so skill paths match the resolved repo_root
- Files modified: core/tests/validate_task.bats (also core/tests/new.bats as precaution)
- Commit: d8f4a98

## Known Stubs

None. All plan 02-03 stubs (`validate_task`, `new_project`, `validate_against_schema`, `extract_frontmatter_as_json`) are now fully implemented.

## Threat Flags

None. No new network endpoints, auth paths, or trust boundary changes beyond what the plan's threat model covers. All T-02-05-* threats mitigated as specified:
- T-02-05-PATH: gate 1 uses cd && pwd -P; test 1 enforces
- T-02-05-NFR: gate 4 scans skill body files (not binary); test 7 enforces
- T-02-05-OVERWRITE: `[ ! -d "$name" ] || exit 1` before any write; test 3 enforces
- T-02-05-LANG: ASCII-only scaffold; test 13 enforces

## Self-Check: PASSED

- core/bin/chantier exists and is 975 lines: FOUND
- core/tests/validate_task.bats exists (350 lines, 14 tests): FOUND
- core/tests/new.bats exists (192 lines, 14 tests): FOUND
- Commit b71de8c (helpers): FOUND
- Commit d8f4a98 (validate-task): FOUND
- Commit 63e3a08 (new.bats): FOUND
- 64/64 bats tests pass: CONFIRMED
- shellcheck exit 0: CONFIRMED
- --self-test all green: CONFIRMED
- FR-002 -> FR-003 integration round-trip: CONFIRMED
