---
phase: 02-runtime-core
plan: "03"
subsystem: binary-skeleton
tags: [posix-sh, chantier-binary, self-test, bats, nfr-001, fr-001]
dependency_graph:
  requires: [02-01, 02-02]
  provides: [core/bin/chantier, core/tests/self_test.bats]
  affects: [02-04-state-append, 02-05-validate-task, 02-06-adr-0002]
tech_stack:
  added: [posix-sh-single-file-binary, bats-assert, mkdir-lock-pattern]
  patterns: [case-dispatch, harness-deny-list-marker, exit-code-matrix-0-1-2-3]
key_files:
  created:
    - core/bin/chantier
  modified:
    - core/tests/self_test.bats
decisions:
  - "Harness deny-list uses HARNESS_DENY_LIST_CHECK marker on variable assignment line so the pattern appears exactly once and can be excluded by grep -v"
  - "self_test() uses check() helper function (name + cmd) that prints ok/FAIL and increments fails counter"
  - "Forbidden words (flock, eval, local) removed even from comments to satisfy plan verification grep"
  - "Test 7 split into 4 separate @test blocks (one per subcommand) for granular failure reporting"
metrics:
  duration: "< 30 minutes"
  completed: "2026-05-30"
  tasks_completed: 2
  tasks_total: 2
---

# Phase 02 Plan 03: core/bin/chantier skeleton — Summary

## One-liner

POSIX sh single-file binary skeleton with case-dispatch, --self-test (9 checks, all green), harness-deny-list marker, exit-code matrix 0/1/2/3, and 11 bats assertions all passing.

## What was built

### core/bin/chantier (333 lines, chmod +x)

Single-file POSIX sh binary with:

- **Shebang**: `#!/bin/sh` (not bash); `set -eu`; explicit IFS; `LC_ALL=C`
- **Global constants**: CHANTIER_VERSION, STATE_FILE, LOCKDIR, PIDFILE, SCHEMAS_DIR, JSON_ERRORS, NL
- **`usage()`**: quoted heredoc listing all subcommands and flags
- **Stub functions**: `state_append`, `state_show`, `validate_task`, `new_project` — each accepts `--help` (exit 0) or any other arg (exit 2, "not yet implemented")
- **Helper stubs**: `mkdir_lock_acquire`, `mkdir_lock_release`, `validate_against_schema`, `extract_frontmatter_as_json` (exit 2)
- **`self_test()`**: real implementation with 9 checks:
  1. jq present
  2. jq version >= 1.6
  3. mkdir-lock works (NOT flock — portable mkdir round-trip)
  4. awk present
  5. date -u present
  6. All 5 schemas parse with `jq empty`
  7. All subcommand stubs answer `--help` with exit 0
  8. No harness identifiers in own source (HARNESS_DENY_LIST_CHECK marker pattern)
  9. No CRLF line endings
- **`--json-errors`**: top-level flag parsed before dispatch; toggles JSON error output
- **Subcommand dispatch**: `case "${1:-}" in state|validate-task|new|--self-test|--version|--help|-h|""|*`
- **Exit code matrix**: 0 success, 1 contract violation, 2 runtime error, 3 usage error

### core/tests/self_test.bats (95 lines, 11 @test blocks)

Replaced empty scaffold with real assertions:

| Test | Coverage |
|------|----------|
| 1 | `--self-test` exits 0, output contains "self-test: all green" |
| 2 | `--version` prints exactly `0.1.0` |
| 3 | `--help` exits 0, output contains state append, state show, validate-task, new, --self-test |
| 4 | Unknown subcommand exits 3, stderr contains "unknown subcommand:" |
| 5 | Harness deny-list: grep -v HARNESS_DENY_LIST_CHECK count == 0 (NFR-001) |
| 6 | No CRLF: `file "$CHANTIER" \| grep -q CRLF` returns "clean" |
| 7 | `state append --help` exits 0 |
| 8 | `state show --help` exits 0 |
| 9 | `validate-task --help` exits 0 |
| 10 | `new --help` exits 0 |
| 11 | `shellcheck -s sh "$CHANTIER"` exits 0 |

## Verification

### shellcheck output

```
shellcheck -s sh core/bin/chantier
(exit 0, zero warnings/errors)
```

### chantier --self-test output

```
chantier --self-test
/usr/bin/jq
  ok  jq present
  ok  jq version >= 1.6
  ok  mkdir-lock works
/usr/bin/awk
  ok  awk present
2026-05-30T04:43:41Z
  ok  date -u present
  ok  schema parses: plan.json
  ok  schema parses: project.json
  ok  schema parses: requirements.json
  ok  schema parses: roadmap.json
  ok  schema parses: skill.json
  ok  --help works: chantier state append
  ok  --help works: chantier state show
  ok  --help works: chantier validate-task
  ok  --help works: chantier new
  ok  no harness identifiers in self
  ok  no CRLF in self

self-test: all green
```

### bats results

```
bats core/tests/self_test.bats
1..11
ok 1 chantier --self-test exits 0 on a clean host
ok 2 chantier --version prints exactly 0.1.0
ok 3 chantier --help exits 0 and lists all subcommands
ok 4 unknown subcommand exits 3 with stderr message
ok 5 binary contains no harness identifiers outside deny-list marker
ok 6 binary has LF line endings (no CRLF)
ok 7 state append --help exits 0
ok 8 state show --help exits 0
ok 9 validate-task --help exits 0
ok 10 new --help exits 0
ok 11 shellcheck -s sh on binary exits 0
```

11 tests, 11 passing.

## Commits

| Task | Commit | Files |
|------|--------|-------|
| Task 1: binary skeleton | `abbc9c5` | core/bin/chantier (created, 333 lines, chmod +x) |
| Task 2: bats tests | `7016ce1` | core/tests/self_test.bats (79 lines added, 1 deleted) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Harness identifier appeared twice in binary (self-test false-positive)**

- **Found during:** Task 1 verification
- **Issue:** The initial implementation had the harness deny-list pattern in a `sh -c "grep ..."` string inside `check()`, making the pattern appear on a non-excluded line alongside the actual deny-list grep. The external verification grep found the pattern on that `sh -c` string.
- **Fix:** Replaced the sh-c approach with a dedicated variable `_deny_pat='...'` assigned on a line marked with `# HARNESS_DENY_LIST_CHECK`, followed by a plain `if grep -v 'HARNESS_DENY_LIST_CHECK' "$0" | grep -qE "$_deny_pat"` block. This ensures all harness identifiers appear exactly once — on the marker line — and can be excluded cleanly.
- **Files modified:** core/bin/chantier
- **Commit:** abbc9c5 (part of Task 1 commit after iterative fix)

**2. [Rule 1 - Bug] Forbidden words in comments triggered verification grep**

- **Found during:** Task 1 verification
- **Issue:** Plan verification uses `grep -qE '\bflock\b'` which matched comment lines explaining why flock was NOT used. Same for `eval` and `local` in the prelude comment.
- **Fix:** Reworded the three comment lines to not contain the forbidden words. The functionality was never affected — they were documentation comments only.
- **Files modified:** core/bin/chantier
- **Commit:** abbc9c5 (part of Task 1 commit after iterative fix)

**3. [Rule 2 - Enhancement] 11 @test blocks instead of the minimum 8**

- **Found during:** Task 2 implementation
- **Issue:** The plan requires ≥8 @test blocks. Test 7 (subcommand stubs) covered 4 subcommands; splitting into 4 separate @test blocks gives more granular failure reporting without adding verbosity.
- **Fix:** Wrote 4 separate `@test "X --help exits 0"` blocks instead of one combined test.
- **Files modified:** core/tests/self_test.bats
- **Commit:** 7016ce1

## Threat Surface Scan

No new network endpoints, auth paths, or file access patterns introduced beyond what the threat model describes:

- `core/bin/chantier` reads `$0` (own source) and `SCHEMAS_DIR/*.json` (read-only)
- No outbound connections
- `--json-errors` output is a literal format flag, not eval'd
- Harness deny-list grep is a read-only introspection of `$0`

All STRIDE threats in the plan (T-02-03-NFR, T-02-03-CRLF, T-02-03-INJ, T-02-03-PORT, T-02-03-SC, T-02-03-LOCK, T-02-03-EXEC) are mitigated as designed.

## Known Stubs

The following functions are intentional stubs pending future plans:

| Stub | File | Reason |
|------|------|--------|
| `state_append()` real body | core/bin/chantier | Plan 02-04 fills this |
| `state_show()` real body | core/bin/chantier | Plan 02-04 fills this |
| `validate_task()` real body | core/bin/chantier | Plan 02-05 fills this |
| `new_project()` real body | core/bin/chantier | Plan 02-05 fills this |
| `mkdir_lock_acquire()` | core/bin/chantier | Plan 02-04 fills this |
| `mkdir_lock_release()` | core/bin/chantier | Plan 02-04 fills this |
| `validate_against_schema()` | core/bin/chantier | Plan 02-05 fills this |
| `extract_frontmatter_as_json()` | core/bin/chantier | Plan 02-05 fills this |

These stubs do not prevent this plan's goal (FR-001 binary skeleton with self-test) from being achieved.

## Self-Check: PASSED

- [x] `core/bin/chantier` exists and is executable (`-x`)
- [x] First line is exactly `#!/bin/sh`
- [x] `shellcheck -s sh core/bin/chantier` exits 0 (zero errors/warnings)
- [x] `core/bin/chantier --version` prints exactly `0.1.0`
- [x] `core/bin/chantier --help` exits 0
- [x] `core/bin/chantier --self-test` exits 0 (all green, 16 checks)
- [x] `state append --help`, `state show --help`, `validate-task --help`, `new --help` all exit 0
- [x] No harness identifier outside HARNESS_DENY_LIST_CHECK marker line
- [x] No forbidden constructs: no bash shebang, no pipefail, no flock, no eval, no local, no [[ ]]
- [x] LF line endings (no CRLF)
- [x] Unknown subcommand exits 3
- [x] `core/bin/chantier` is 333 lines (≥200)
- [x] `core/tests/self_test.bats` has 11 @test blocks (≥8) and 95 lines (≥40)
- [x] `bats core/tests/self_test.bats` — all 11 tests pass
- [x] Commits abbc9c5 and 7016ce1 exist in git log
