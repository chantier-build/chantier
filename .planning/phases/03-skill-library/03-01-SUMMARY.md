---
phase: 03-skill-library
plan: "01"
subsystem: cross-skill-uniformity
tags: [phase-03, infra, bats, uniformity, harness-adapters, kernel-invariants]
dependency_graph:
  requires: [02-03, 02-05]
  provides: [core/tests/skill_uniformity.bats, core/tests/fixtures/skills/]
  affects: [03-02, 03-03, 03-04, 03-05]
tech_stack:
  added: []
  patterns: [bats-skip-until-populated, awk-frontmatter-subset-extractor, fail-with-diagnostic]
key_files:
  created:
    - core/tests/skill_uniformity.bats
    - core/tests/fixtures/skills/.gitkeep
  modified: []
decisions:
  - "Co-locate the three structural checks (D-16 harness_adapters uniformity, FR-010 PRESSURE.md scenario count, D-01 run.sh presence + executable bit) inside one bats file rather than splitting into three files; the surface is small and keeping it together centralizes the skill-structural-compliance story per RESEARCH Pattern 5."
  - "Use awk frontmatter subset profile (top-level scalars + simple `- value` lists) per ADR 0002; nested maps would fail cleanly via the `in_fm && /^[a-z_]+:/` exit condition rather than silently extracting wrong values (T-03-01 mitigation)."
  - "Skip-when-empty pattern lets Wave 1 land the test green (3 SKIPs) before any skill is authored; Wave 2 plans drop their skill directories and the same three blocks flip to strict assertions with no edits to skill_uniformity.bats."
  - "Place the fixtures parent at core/tests/fixtures/skills/.gitkeep (mirroring the existing core/tests/fixtures/ layout) so Wave-2 plans can declare core/tests/fixtures/skills/<name>/dossier/inputs.yml as new files without mkdir -p ceremony."
metrics:
  duration: "< 10 minutes"
  completed: "2026-05-30"
  tasks_completed: 1
  tasks_total: 1
---

# Phase 03 Plan 01: skill_uniformity.bats Wave-1 infra — Summary

## One-liner

Single bats file (`core/tests/skill_uniformity.bats`) with three @test blocks encoding D-16 (uniform `harness_adapters: [claude-code]` across all skills), FR-010 (PRESSURE.md >= 2 scenarios), and D-01 (executable `run.sh` mandate); SKIP-when-empty pattern flips to strict-green automatically as Wave 2 lands the four skill directories.

## What was shipped

### core/tests/skill_uniformity.bats (84 lines)

POSIX-shell bats file, no bashisms, no external tooling beyond `find`, `awk`, `grep`, `sed`, `sort`, `tr`. Single `setup()` that loads bats-support + bats-assert (identical to `validate_task.bats` lines 8–9) and `cd`s to repo root. Three @test blocks:

| # | Title | Implements | Discovery | Assertion shape |
|---|-------|------------|-----------|-----------------|
| 1 | `every shipped skill declares harness_adapters: [claude-code]` | D-16 | `find skills -mindepth 1 -maxdepth 1 -type d` | awk-extract `harness_adapters` array, sort, join with commas, compare each per-skill value to reference `claude-code` |
| 2 | `every shipped skill has a PRESSURE.md with at least two scenarios` | FR-010 | same | `grep -cE '^## Scenario [0-9]'` with `\|\| true` so zero-match doesn't abort under bats `set -e` |
| 3 | `every shipped skill ships a run.sh per D-01` | D-01 | same | `[ -f "$_d/run.sh" ]` + `[ -x "$_d/run.sh" ]` with distinct diagnostics |

All three skip with `"no skills shipped yet"` when discovery returns empty. Closing comment `# Decisions implemented: D-01 / D-16 / FR-010` keeps traceability inline.

### core/tests/fixtures/skills/.gitkeep (0 bytes)

Zero-byte placeholder establishing the parent directory so Wave-2 plans can write `core/tests/fixtures/skills/<name>/dossier/inputs.yml` without `mkdir -p` ceremony in their own task actions.

## Validation results

### bats core/tests/skill_uniformity.bats

```
$ bats --pretty core/tests/skill_uniformity.bats
skill_uniformity.bats
 - every shipped skill declares harness_adapters: [claude-code] (skipped: no skills shipped yet)
 - every shipped skill has a PRESSURE.md with at least two scenarios (skipped: no skills shipped yet)
 - every shipped skill ships a run.sh per D-01 (skipped: no skills shipped yet)

3 tests, 0 failures, 3 skipped
```

Exit 0 confirmed.

### bats core/tests/ (full Phase 2 suite + Wave 1 addition)

```
$ bats core/tests/ 2>&1 | tail -5
ok 63 gate 5: heading with trailing words exits 1 (regex rejects trailing text)
ok 64 gate 5: missing acceptance item exits 1 with missing-acceptance message
ok 65 happy path: all 5 gates pass exits 0 with validated message
ok 66 missing TASK_ID arg exits 3 with usage message
ok 67 unknown task ID exits 3 with not-found message
```

67 tests (64 Phase-2 baseline + 3 new SKIPs). Zero failures. Phase 2 baseline preserved.

### chantier --self-test

```
$ core/bin/chantier --self-test 2>&1 | tail -3
  ok  no CRLF in self

self-test: all green
```

### shellcheck

```
$ shellcheck --shell=sh core/tests/skill_uniformity.bats
core/tests/skill_uniformity.bats line 19: cd "$BATS_TEST_DIRNAME/../.."
SC2164 (warning): Use 'cd ... || exit' or 'cd ... || return' in case cd fails.
```

Single SC2164 warning on `cd "$BATS_TEST_DIRNAME/../.."`. Identical to the warning Phase 2 accepted for `core/tests/validate_task.bats` — bats does not propagate `cd` failure cleanly through `setup()` and the canonical Phase 2 pattern is to leave the warning. Per the plan verify clause: "warnings about bats DSL constructs or canonical setup patterns are expected and acceptable."

### Harness identifier hygiene

```
$ grep -nE 'mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode' \
    core/tests/skill_uniformity.bats
22:@test "every shipped skill declares harness_adapters: [claude-code]" {
28:    _reference="claude-code"
```

Only the policy reference value (`claude-code` appearing inside the assertion's expected-value and the @test title), exactly matching the plan's allowed surface. The test file lives in `core/tests/` which gate 4 does not scan (gate 4 scans `skills/<name>/`); the literal is the assertion target, not a body identifier.

## Commits

| Task | Commit | Files |
|------|--------|-------|
| Task 1: skill_uniformity.bats + fixtures parent | `4ffe945` | core/tests/skill_uniformity.bats (created, 84 lines), core/tests/fixtures/skills/.gitkeep (created, 0 bytes) |

## Deviations from plan

None — plan executed exactly as written.

The plan's `<verify>` block expects `grep -q "3 tests, 0 failures"` against bats output. Default `bats` output (TAP) does not include that summary line; only `bats --pretty` (or `bats --formatter pretty`) emits it. The verification was satisfied by running `bats --pretty core/tests/skill_uniformity.bats`, which produced the exact `3 tests, 0 failures, 3 skipped` summary line the plan grepped for. This is a documentation nit in the plan's verify clause, not a behavior deviation — both invocations exit 0 with the same three SKIPs. Recording here for transparency rather than as an auto-fix.

## Threat surface scan

No new attack surface introduced. The threat model items are validated as follows:

| Threat | Status |
|--------|--------|
| T-03-01 (awk extractor tampering) | Mitigated by frontmatter subset profile — nested maps trigger the `in_fm && /^[a-z_]+:/` exit branch and produce an empty `_arr`, which fails the assertion against the reference value cleanly. |
| T-03-02 (`find` surfacing unexpected dirs) | Accepted as designed — Wave 1 finds zero dirs (only `.gitkeep` which is a file). Wave 2 lands four well-known directories. |
| T-03-03 (pathological PRESSURE.md content) | Accepted — bats 30s default timeout bounds the worst case. |
| T-03-SC (package install legitimacy) | n/a — no packages installed. |

No new threat flags surfaced during execution.

## Known stubs

None. The Wave-1 file is complete as authored; Wave 2 does not modify it. The three SKIPs are the intended Wave-1 state, not stubs — they are part of the design (RESEARCH Pattern 5 lines 533–536).

## Self-Check: PASSED

- [x] `core/tests/skill_uniformity.bats` exists, contains three `@test` blocks with the exact titles named in the plan's `<action>`
- [x] `core/tests/fixtures/skills/.gitkeep` exists and is zero bytes
- [x] `bats core/tests/skill_uniformity.bats` exits 0 with 3 tests / 0 failures / 3 skipped
- [x] `bats core/tests/` (full suite) exits 0 with 67 ok lines (64 Phase-2 baseline preserved + 3 new SKIPs)
- [x] `core/bin/chantier --self-test` exits 0 with "all green"
- [x] No POSIX violations (no `[[ ]]`, no arrays, no `<<<`, no `mapfile`); shellcheck reports only the canonical SC2164 warning matching `validate_task.bats`
- [x] Harness identifier hygiene: only `claude-code` appears, and only as the assertion's expected-value reference plus the matching @test title (RESEARCH §"Anti-Patterns" exempts test files in `core/tests/` from gate 4)
- [x] Commit `4ffe945` exists in `git log --oneline`

## Note for Wave 2

Wave-2 plans (03-02 through 03-05) need not modify `skill_uniformity.bats`. As each plan lands its `skills/<name>/{SKILL.md,PRESSURE.md,run.sh}`, the matching @test block will transition from SKIP to PASS automatically — provided:

- `SKILL.md` frontmatter declares exactly `harness_adapters:\n  - claude-code` (or `[claude-code]` single-line list — the awk extractor handles both; the simpler dash-list form is recommended for consistency)
- `PRESSURE.md` contains at least two headings matching `^## Scenario [0-9]` (the D-09 structured spec template emits `## Scenario N — <title>` which matches)
- `run.sh` exists in the skill directory and has the executable bit set (`chmod +x`)

If a Wave-2 plan accidentally ships a divergent `harness_adapters` array (e.g., adding `cursor` aspirationally), this test will fail with `harness_adapters drift detected: got '...', expected 'claude-code'`. That diagnostic is the D-17 mechanical extension gate: a harness joins the list only after an E2E test passes on that harness, not by aspirational claim.
