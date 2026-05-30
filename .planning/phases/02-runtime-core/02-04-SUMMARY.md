---
phase: 02-runtime-core
plan: "04"
subsystem: core/bin/chantier
tags: [state-append, state-show, mkdir-lock, jsonl, bats, posix-sh]
dependency_graph:
  requires: [02-03]
  provides: [FR-003, D-03]
  affects: [02-05, 02-06]
tech_stack:
  added: []
  patterns:
    - mkdir-as-mutex with stale-PID detection and bounded retry (RESEARCH Pattern 2)
    - JSONL compact output via jq -c (not | tostring — avoids double-encoding)
    - BSD column collapse mitigation: null/empty array -> "-" before column -t (RESEARCH Pattern 6)
    - Two-pass event regex: case-glob cheap reject + jq test() authoritative (RESEARCH Pattern 3)
    - Newline-joined string accumulation for repeated -r flags (Pitfall 7 prevention)
key_files:
  modified:
    - core/bin/chantier
    - core/tests/state_append.bats
    - core/tests/state_show.bats
decisions:
  - key: acquire_lock-trap-cleanup
    choice: "rm -f PIDFILE before rmdir in EXIT trap"
    rationale: "rmdir fails on non-empty directory; the PIDFILE inside LOCKDIR must be removed first"
  - key: jq-compact-not-tostring
    choice: "jq -c flag instead of | tostring"
    rationale: "tostring double-encodes the JSON object as a string literal; -c produces correct JSONL object"
  - key: acquire_lock-retry-loop
    choice: "LOCK_RETRIES=10, LOCK_SLEEP=1 bounded spin before returning exit 2"
    rationale: "Without retry, concurrent callers fail immediately and produce fewer than N lines; 10 retries at 1s covers realistic concurrent-subagent load"
  - key: refs-empty-array-dash
    choice: "empty refs array [] renders as '-' in state show"
    rationale: "BSD column collapses empty fields; join([]) produces empty string which collapses; must substitute '-'"
metrics:
  duration: "~20 minutes"
  completed: "2026-05-30"
  tasks_completed: 2
  files_modified: 3
---

# Phase 02 Plan 04: state append + state show — Summary

**One-liner:** POSIX sh `state append` with mkdir-as-mutex (bounded retry, stale-PID recovery) and `state show` with BSD-column-collapse-safe jq rendering; 36 bats tests green.

## What Was Built

### Task 1: state_append() + acquire_lock()

`acquire_lock()` (RESEARCH Pattern 2):
- Bounded retry loop (LOCK_RETRIES=10 × LOCK_SLEEP=1s) so parallel callers serialize
- Stale-PID detection: `kill -0 $OTHERPID` — if holder is dead, `rm -rf` + retry mkdir
- EXIT/INT/TERM/HUP trap: `rm -f "$PIDFILE"; rmdir "$LOCKDIR" 2>/dev/null`
- Never called in a pipeline (Pitfall 6 enforced; grep returns no matches for `acquire_lock |`)

`state_append()`:
- `getopts ":e:t:s:m:r:"` loop; REFS accumulated via `REFS="${REFS}${REFS:+$NL}${OPTARG}"` (Pitfall 7)
- Two-pass D-09 event regex: `case "$EVENT" in *[!a-z0-9.]*|...` cheap reject → `jq -R -e 'test()'` authoritative
- Bad event: exit 1 (contract violation); missing -e/-m: exit 3 (usage error)
- `ACTOR=$(git config user.name 2>/dev/null || printf 'unknown')` (Pitfall 9)
- `acquire_lock || exit $?` in current shell (never in pipeline)
- `jq -R -s -c` produces compact single-line JSON (JSONL); `-c` avoids `tostring` double-encoding
- `task`/`skill` fields: `(if $ta=="" then null else $ta end)` per D-02 nullability

### Task 2: state_show()

- `awk 'BEGIN{infm=0} /^---$/ && NR==1 {infm=1; next} /^---$/ && infm {infm=0; next} !infm'` — strips first two `---` sentinels only
- jq `or_dash` def: `if . == null or . == "" then "-" else tostring end` (Pitfall 2 mitigation)
- Empty refs array `[]` explicitly handled: `if . == null or length == 0 then "-" else join(",") end`
- Header prepended via `(printf 'TS\tEVENT\tACTOR\tTASK\tSKILL\tSUMMARY\tREFS\n'; cat)`
- `column -t -s "$(printf '\t')"` — POSIX-portable tab delimiter (no bash `$'\t'`)
- Read-only: never calls acquire_lock

## Verification Results

### shellcheck
```
shellcheck -s sh core/bin/chantier → exit 0 (zero errors, zero warnings)
```

### bats suites (36 total)
```
state_append.bats: 18/18 ok
state_show.bats:    7/7  ok
self_test.bats:    11/11 ok
Total: 36/36 green
```

### Concurrent stress test (Test 12)
Five concurrent `state append &` invocations produced exactly 5 valid JSONL lines. Every line parsed with `jq empty` (no corruption, no interleaving). The mutex retry loop serialized writers within ~5 seconds.

### Binary stats
- Line count: 440 lines (within the expected 400–500 range)
- No `flock` keyword (grep confirms)
- No `acquire_lock |` pattern (Pitfall 6 verified by grep)
- HARNESS_DENY_LIST_CHECK gate still clean (self-test test 5 passes)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] PIDFILE inside LOCKDIR caused rmdir to fail**
- Found during: Task 1 validation
- Issue: `rmdir "$LOCKDIR" 2>/dev/null` in EXIT trap failed silently because LOCKDIR contained PIDFILE; `rmdir` only removes empty directories. The script exited 1 (rmdir's failure code propagated via set -eu) even though the JSONL line was successfully written.
- Fix: Changed trap to `rm -f "$PIDFILE"; rmdir "$LOCKDIR" 2>/dev/null`
- Files modified: core/bin/chantier
- Commit: 61f1ae6

**2. [Rule 1 - Bug] jq `| tostring` double-encoded JSONL lines**
- Found during: Task 1 validation
- Issue: RESEARCH Pattern 3 shows `| tostring` at end of jq filter. `tostring` on a jq object converts it to a JSON string (wrapped in quotes with internal escaping). The resulting line in STATE.md was a JSON string `"{ ... }"`, not a JSON object `{ ... }`. `state show` then failed with `Cannot index string with string "ts"`.
- Fix: Changed `jq -R -s ... | tostring` to `jq -R -s -c ...` (compact output, no tostring)
- Files modified: core/bin/chantier
- Commit: 61f1ae6

**3. [Rule 1 - Bug] acquire_lock returned exit 2 immediately under concurrency**
- Found during: Test 12 (concurrent stress test)
- Issue: RESEARCH Pattern 2 does not include a retry loop; one invocation gets the lock and the others fail immediately with exit 2, writing 0-1 lines instead of N.
- Fix: Added `LOCK_RETRIES=10 / LOCK_SLEEP=1` bounded spin loop so concurrent callers wait their turn
- Files modified: core/bin/chantier
- Commit: 61f1ae6

**4. [Rule 1 - Bug] Empty refs array rendered as empty string not dash**
- Found during: Task 2 validation
- Issue: `.refs | join(",")` on `[]` produces `""` (empty), which BSD column collapses. The REFS column was missing for rows with no refs.
- Fix: Added `if . == null or length == 0 then "-"` guard before `join(",")` in state_show jq filter
- Files modified: core/bin/chantier
- Commit: 61f1ae6

## Known Stubs

None introduced in this plan. `validate_against_schema` and `extract_frontmatter_as_json` remain as 02-05 stubs (inherited from 02-03).

## Threat Flags

None. No new network endpoints, auth paths, or trust boundary changes beyond what the plan's threat model covers (T-02-04-INJ, T-02-04-REGEX, T-02-04-CONCUR all mitigated).

## Self-Check: PASSED

- core/bin/chantier exists: FOUND
- core/tests/state_append.bats exists: FOUND
- core/tests/state_show.bats exists: FOUND
- Commit 7090a1c exists: FOUND
- Commit 61f1ae6 exists: FOUND
- Commit 560accd exists: FOUND
- 36/36 bats tests pass: CONFIRMED
- shellcheck exit 0: CONFIRMED
