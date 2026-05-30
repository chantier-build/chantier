---
phase: 03-skill-library
plan: "03"
subsystem: skill-test-driven-development
tags:
  - phase-03
  - skill
  - test-driven-development
  - run-sh
  - pressure-md
  - kernel-invariants
  - tdd
  - red-before-green
dependency_graph:
  requires:
    - 02-05
    - 02-06
    - 03-01
    - 03-02
  provides:
    - skills/test-driven-development/SKILL.md
    - skills/test-driven-development/PRESSURE.md
    - skills/test-driven-development/run.sh
    - core/tests/skill_test_driven_development_e2e.bats
    - core/tests/fixtures/skills/test-driven-development/dossier/inputs.yml
  affects:
    - core/tests/skill_uniformity.bats (3 PASS now spans two shipped skills instead of one)
    - .planning/ROADMAP.md (Wave 2 row 03-03 checked off)
    - .planning/STATE.md (plan.completed event appended)
tech_stack:
  added: []
  patterns:
    - POSIX-sh-with-jq run.sh shape (matches Plan 03-02 prelude byte-for-byte)
    - jq -n --arg / --argjson exclusively for output.json emission (T-02-04-INJ defence)
    - set +e / set -e bracket around sh -c "$TEST_COMMAND" to capture child exit code under set -eu (Pitfall 3)
    - Phase-flag dispatch (red xor green per RESEARCH Open Question 1) with single run.sh handling both invocations
    - Two-invocation merge: green invocation reads prior red output.json fields via jq -r and rewrites the unified record
    - Per-framework test_command defaults via case statement (bats / pytest / vitest / jest / go-test / cargo-test)
    - Final chantier state append wrapped in subshell that cd's to project root located by walking up for .planning/ (inherited from Plan 03-02 deviation 2)
    - PRESSURE.md structured spec (Situation / Temptation / Required response / Disqualifier) with period AFTER closing **
    - bats e2e fixture mounting via cp + make_plan helper hermetically copied from validate_task.bats
    - TAP-style runner output parsing for tests_added counter (grep -cE '^(ok|not ok) [0-9]+')
key_files:
  created:
    - skills/test-driven-development/SKILL.md
    - skills/test-driven-development/PRESSURE.md
    - skills/test-driven-development/run.sh
    - core/tests/fixtures/skills/test-driven-development/dossier/inputs.yml
    - core/tests/skill_test_driven_development_e2e.bats
    - .planning/phases/03-skill-library/03-03-SUMMARY.md
  modified: []
decisions:
  - "Single-invocation-per-phase model (RESEARCH Open Question 1 recommendation): inputs.yml declares phase: red OR phase: green; the same run.sh handles both. Two invocations share the task directory and merge into one output.json. Phase 3 e2e test exercises only the red invocation -- the green-phase flow is dogfooded at Phase 5 once a real implementation cycle drives it."
  - "Fixture test_command is the POSIX 'false' builtin (exits 1 deterministically) rather than a real failing test suite. This makes the e2e test exercise the set +e / set -e bracketing and RED_EXIT capture machinery without depending on any framework's output being stably-failing. A real TDD run uses a real bats/pytest/vitest command -- that's Phase 5 territory."
  - "outputs_schema declares red_test_command / green_test_command / coverage_delta as optional alongside the six required fields (tests_added, red/green timestamps, red/green exit codes, invariants_applied). Keeps room for richer downstream verification without breaking the v0.1 contract."
  - "TESTS_ADDED capture normalised via 'head -n 1 | tr -d \" \"' after grep -c. The straightforward '|| printf 0' fallback concatenates '0\\n0' (grep already writes 0 to stdout even on no-match), which breaks --argjson. The normalisation strips to a single decimal integer regardless of grep version."
  - "PRESSURE.md bold-marker punctuation period AFTER closing ** (e.g., '**Situation**.') -- matches Plan 03-02's convention and the falsifiable verify regex. Plan 03-02 documented this as a deviation; Plan 03-03 adopts it as a precedent rather than re-discovering it."
metrics:
  duration: "~25 minutes"
  completed: "2026-05-30"
  tasks_completed: 3
  tasks_total: 3
  bats_tests_before: 68
  bats_tests_after: 69
  shipped_skills_before: 1
  shipped_skills_after: 2
---

# Phase 03 Plan 03: test-driven-development skill -- Summary

## One-liner

Second reference skill shipped end-to-end: `test-driven-development` enforces red-before-green ordering as a measurable invariant (`output.json.red_step_timestamp < green_step_timestamp` AND `red_exit_code != 0` AND `green_exit_code == 0`) via a phase-flagged single-invocation model; the same `run.sh` handles both red and green invocations, and the e2e bats test drives the red phase against `chantier validate-task` with all five ADR 0001 gates green.

## What Was Shipped

### Task 1 -- SKILL.md (commit 058f5b7)

`skills/test-driven-development/SKILL.md` (120 lines):

- YAML frontmatter with all 8 fields required by `core/schemas/skill.json`: `id: test-driven-development`, `version: 1.0.0`, `inputs_schema` (3 required: `target_file`, `test_framework` with enum of 6 frameworks, `phase` with enum `[red, green]`), `state_reads: ["{phase}/CONTEXT.md", "{phase}/tasks/{depends_on}/output.json"]`, `state_writes: ["{phase}/tasks/{task}/", ".planning/STATE.md"]`, `outputs_schema` (6 required + 3 optional fields; both timestamp fields carry the ISO-8601 UTC second-precision pattern), `portable: true`, `harness_adapters: [claude-code]`.
- Body sections in canonical D-05 / D-15 order: `# Test-driven development` -> `## Purpose` -> `## When to use` -> `## Invariants` -> `## How` -> `## Portability claim` -> `## Exit code matrix (from run.sh)` -> `## Acknowledge before acting`. No `## Why no hooks` section (that's the `subagent-driven-development` skill's exclusive carve-out per D-08).
- Numbered `## Invariants` section: kernel 1-3 verbatim per D-06 (Portability / State log append-only / State writes containment) + skill-specific Invariant 4 ("Red before green") citing `output.json.red_step_timestamp < green_step_timestamp` AND `red_exit_code != 0` AND `green_exit_code == 0` as proof per D-07.
- `## Portability claim` rewritten to refer to "the frontmatter" / "a single-entry list" without using the literal `claude-code` token in the body (project convention; gate 4 exempts SKILL.md but body cleanliness is uniform across skills).
- `## Exit code matrix` documents D-04 split: 0 = success or business-state failure (including the legitimate red-step failure) encoded in output.json; 2 = technical incident (missing inputs.yml / unknown test_framework / missing jq / filesystem error).

### Task 2 -- PRESSURE.md (commit aa85a55)

`skills/test-driven-development/PRESSURE.md` (34 lines):

- Frontmatter per D-12: `skill_id: test-driven-development`, `scenarios:` array with two entries (`tdd-time-pressure-01` / `tdd-sunk-cost-01`), each declaring `levers` and `invariants_referenced: [4]`.
- Two scenarios in the D-09 structured spec format:
  - **Scenario 1 (time-pressure)**: "Production incident, ship the fix" -- the on-call hotfix temptation against a one-line off-by-one in a billing calculation. Disqualifier cites Invariant 4 and `output.json.red_step_timestamp >= green_step_timestamp` OR `red_exit_code == 0`.
  - **Scenario 2 (sunk-cost)**: "I have already written the code; it works" -- the 45-minute already-built feature for which tests are now an afterthought. Disqualifier cites Invariant 4 and `output.json.tests_added > 0` while `red_exit_code` was never observed non-zero (absence OR `red_exit_code == 0`).
- Greppable structure: 2 `## Scenario N` headings, 8 `**Subsection**.` markers (4 per scenario x 2). No cross-references to other skills' PRESSURE files (D-13). Zero deny-list tokens (gate 4 scans this file because it sits in `skills/<name>/` and is not SKILL.md).
- Bold-marker punctuation period AFTER closing `**` -- matches Plan 03-02's convention recorded as Deviation 1 in 03-02-SUMMARY and inherited here as a precedent.

### Task 3 -- run.sh + fixture + e2e bats test (commit eee724e)

`skills/test-driven-development/run.sh` (mode 0755, shellcheck `--shell=sh` clean):

- Canonical prelude: `#!/bin/sh` -> MIT header -> `set -eu` / IFS=newline / `LC_ALL=C` / `export LC_ALL` (mirrored from `core/bin/chantier` lines 1-13 and `skills/using-git-worktrees/run.sh` lines 1-15 byte-for-byte).
- Reads `inputs.yml` from `$PWD` via `grep -E '^field:' | sed` (POSIX subset, no yq). Missing required fields -> exit 2 per matrix.
- Dependency check: `command -v jq`. Absence -> exit 2.
- Per-framework `TEST_COMMAND` default via case statement when `test_command` is absent from inputs.yml: `bats core/tests/` / `pytest -x` / `npx vitest run` / `npx jest` / `go test ./...` / `cargo test`. Unknown framework -> exit 2.
- Phase-flag dispatch: `case $PHASE_FLAG` populates `RED_TS` / `RED_CMD` and runs the test command bracketed by `set +e` / `set -e` to capture `RED_EXIT` when `phase: red`; populates `GREEN_TS` / `GREEN_CMD` / `GREEN_EXIT` when `phase: green`. Either invocation reads any pre-existing `output.json` in the task dir via `jq -r '.field // default'` to merge the opposite-phase fields forward (two invocations build one record).
- `TESTS_ADDED` counted from runner output: `grep -cE '^(ok|not ok) [0-9]+' "$TASK_DIR/${PHASE_FLAG}.out" 2>/dev/null || true`, then normalised via `head -n 1 | tr -d ' '` (the straightforward `|| printf '0'` fallback concatenates `0\n0` because grep already writes `0` on no-match -- documented as Deviation 1 below).
- `output.json` emitted via a single `jq -n` call. Every value flows through `--arg` (strings) or `--argjson` (numbers / pre-parsed JSON arrays). No printf %s into JSON anywhere -- T-02-04-INJ defence mirrored from `core/bin/chantier` line 196.
- `output.md` emitted via unquoted heredoc (interpolation desired). Contains the literal `## Acceptance` heading (gate 5 case-sensitive grep `^##[[:space:]]+Acceptance[[:space:]]*$`). The two acceptance bullets are byte-identical to those in the test's PLAN.md (gate 5 substring match).
- Final `chantier state append -e skill.completed -t "${CHANTIER_TASK_ID:-unknown}" -s test-driven-development -m "TDD <phase> step completed; see output.json for measured invariants" -r "$TASK_DIR/output.md" -r "$TASK_DIR/output.json"` invoked inside a subshell that `cd`s to the project root (located by walking up from TASK_DIR looking for `.planning/`). Followed by `exit 0`.

`core/tests/fixtures/skills/test-driven-development/dossier/inputs.yml`: four top-level scalars (`target_file: "core/bin/chantier"`, `test_framework: "bats"`, `phase: "red"`, `test_command: "false"`). The `test_command: "false"` is the POSIX `false` builtin -- exits 1 deterministically -- making the fixture a stable red-step simulator without depending on a real failing test suite.

`core/tests/skill_test_driven_development_e2e.bats` (175 lines, 1 @test):

- Setup mirrors `core/tests/skill_using_git_worktrees_e2e.bats` lines 16-65 for the loaders, TMPHOME canonicalization via `pwd -P`, PATH-prepend of the chantier binary, and the .planning/STATE.md JSONL stub. Unlike the worktree skill's setup, this one does NOT initialise TMPHOME as a git repo (TDD's run.sh doesn't call `git`).
- `make_plan` helper copied verbatim from `skill_using_git_worktrees_e2e.bats` lines 74-117 (hermetic; takes a 4th arg for skill name).
- The single `@test` block: copies the live skill into TMPHOME, sets `ACC_BULLET_1` / `ACC_BULLET_2` byte-identical to what run.sh writes into output.md, builds PLAN.md via `make_plan`, stages the fixture inputs.yml in the task dir, invokes `sh "$TMPHOME/skills/$SKILL/run.sh"`, asserts exit 0 and the presence of output.md / output.json, asserts `red_step_timestamp` is a string matching the ISO-8601 regex, asserts `red_exit_code` is a number equal to 1 (from the fixture's `test_command: "false"`), asserts `invariants_applied` has length >= 4, asserts the `## Acceptance` heading is present in output.md, then runs `chantier validate-task t1` and asserts exit 0 (all five ADR 0001 gates pass).

## Validation Results

### bats core/tests/skill_test_driven_development_e2e.bats

```
$ bats --pretty core/tests/skill_test_driven_development_e2e.bats
 ✓ test-driven-development: red phase end-to-end through chantier validate-task

1 test, 0 failures
```

### bats core/tests/skill_uniformity.bats

```
$ bats core/tests/skill_uniformity.bats
1..3
ok 1 every shipped skill declares harness_adapters: [claude-code]
ok 2 every shipped skill has a PRESSURE.md with at least two scenarios
ok 3 every shipped skill ships a run.sh per D-01
```

All three checks pass across both shipped Wave-2 skills (using-git-worktrees + test-driven-development). The uniformity test now exercises real cross-skill comparison rather than the single-skill case Plan 03-02 closed against.

### bats core/tests/ (full suite)

```
$ bats --pretty core/tests/ | tail -3
69 tests, 0 failures
```

68 at Plan 03-02 close + 1 new e2e for this plan = 69 ok, 0 failures. Zero regressions.

### shellcheck --shell=sh skills/test-driven-development/run.sh

```
$ shellcheck --shell=sh skills/test-driven-development/run.sh
$ echo $?
0
```

Zero warnings, zero errors.

### Harness-identifier hygiene

```
$ grep -hcE 'mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode' \
    skills/test-driven-development/PRESSURE.md \
    skills/test-driven-development/run.sh \
    | awk '{s+=$1} END {print s+0}'
0

$ grep -n 'claude-code' skills/test-driven-development/SKILL.md
58:  - claude-code
```

`claude-code` appears only in SKILL.md's `harness_adapters` frontmatter array at line 58 (the sole NFR-001 carve-out per core/schemas/skill.json enum). Zero occurrences in PRESSURE.md or run.sh (gate 4 scans both).

### chantier --self-test

```
$ core/bin/chantier --self-test | tail -3
  ok  no harness identifiers in self
  ok  no CRLF in self

self-test: all green
```

## Phase 3 Success Criteria Status (partial -- 2 of 4 skills)

| # | Criterion | Status |
|---|-----------|--------|
| 1 | Four skills shipped | 2 of 4 (using-git-worktrees, test-driven-development) |
| 2 | Each skill ships SKILL.md with valid 8-field frontmatter | 2 of 4 (this skill's frontmatter validates against `core/schemas/skill.json` enum + pattern constraints) |
| 3 | Each skill ships PRESSURE.md with at least two adversarial scenarios | 2 of 4 (this skill has 2 scenarios in D-09 format) |
| 4 | `chantier validate-task` accepts a task that invokes any of these skills | YES (e2e bats test exercises all 5 gates) |
| 5 | No skill body contains harness-specific identifiers | YES (gate 4 scan + manual `grep -n` both clean) |

## Deviations from Plan

### Deviation 1 -- TESTS_ADDED concatenation bug (Rule 1: bug)

**Found during:** Task 3 first manual run.sh invocation
**Issue:** The plan's `<action>` block specified `TESTS_ADDED=$(grep -cE '^(ok|not ok) [0-9]+' "$TASK_DIR/${PHASE_FLAG}.out" 2>/dev/null || printf '0')`. When the `.out` file contains no TAP-style lines, `grep -c` writes `0` to stdout AND exits 1, so the `|| printf '0'` fallback runs and appends a second `0`. The command-substitution result is `0\n0`, which is not a valid JSON number and causes `jq --argjson tests "$TESTS_ADDED"` to abort with "invalid JSON text passed to --argjson", leaving output.json empty and run.sh exiting 2 instead of 0.
**Fix:** Replaced the fallback with `|| true` (grep's own `0` is sufficient) and added a normalisation pass: `TESTS_ADDED=$(printf '%s' "$TESTS_ADDED" | head -n 1 | tr -d ' ')` to handle any leading/trailing whitespace BSD `wc`-style. The literal `0` from grep -c, the literal `0` from a single-line `head`, and the empty-string defensive `[ -n "$TESTS_ADDED" ] || TESTS_ADDED=0` together guarantee `$TESTS_ADDED` is a single decimal integer.
**Files modified:** skills/test-driven-development/run.sh
**Commit:** eee724e

### Documentation-only nit -- deny-list verify under host `grep` wrapper

The plan's `<verify>` block at Task 3 uses `_denied=$(grep -cE '...' run.sh PRESSURE.md || true); [ "$_denied" -eq 0 ]`. When run via the host shell's `grep` wrapper (which forwards to `ugrep -G` on this system), `grep -c` on multiple files emits per-file lines like `file1:0\nfile2:0` instead of a single sum. The arithmetic comparison `[ "$_denied" -eq 0 ]` then errors with a non-numeric string. The substantive content is clean (zero deny-list matches across both files); the verify check passes under a sum-aware form:
```
grep -hcE '...' file1 file2 | awk '{s+=$1} END{print s+0}'
```
Behaviour and gate-4 result are unaffected.

## Threat Surface Scan

No new attack surface introduced beyond what the threat model in 03-03-PLAN.md already lists. The threat register dispositions are validated as follows:

| Threat | Status |
|--------|--------|
| T-03-03-01 (command injection via test_command) | Mitigate-with-residual-risk -- `test_command` IS executed by `sh -c` because that is the skill's purpose (run an arbitrary test command). The dossier `inputs.yml` is staged by a trusted process (Phase 4 adapter); skills are not invoked with untrusted dossiers. Defaults are framework-canonical safe strings. |
| T-03-03-02 (JSON injection in output.json) | Mitigated -- all JSON emission via `jq -n --arg`/`--argjson`. Zero printf %s into JSON. |
| T-03-03-03 (path traversal in state_writes) | Accepted -- already enforced by chantier validate-task gate 1; skill does not re-implement. |
| T-03-03-04 (TOCTOU on inputs.yml) | Mitigated -- inputs.yml is read once at the top of run.sh into shell variables (TARGET_FILE / TEST_FRAMEWORK / PHASE_FLAG / TEST_COMMAND); no re-read mid-execution. |
| T-03-03-05 (harness identifier leaked into outputs) | Mitigated -- gate 4 deny-list scan runs against the live skill files; e2e bats test exercises gate 4. Manual `grep -n` confirms `claude-code` appears only in SKILL.md frontmatter. |
| T-03-03-06 (runaway test command DoS) | Accepted -- bats has a 30s default per-test timeout in the e2e harness; production resource limits are the Phase 4 adapter's concern. |
| T-03-03-SC (package install legitimacy) | n/a -- no packages installed. |

No new threat flags surfaced during execution.

## Known Stubs

None. All three files (SKILL.md, PRESSURE.md, run.sh) ship complete; the fixture inputs.yml is the documented minimal quadruple; the e2e bats test exercises the full ADR 0001 contract for the red invocation. The green-invocation flow is implemented in run.sh and ready for Phase 5 dogfood -- not stubbed but intentionally untested at Phase 3 per RESEARCH Open Question 1 recommendation.

## Self-Check: PASSED

- `skills/test-driven-development/SKILL.md` exists; 8-field frontmatter validates: FOUND
- `skills/test-driven-development/PRESSURE.md` exists; 2 scenarios, 8 subsection markers: FOUND
- `skills/test-driven-development/run.sh` exists; executable bit set; shellcheck clean: FOUND
- `core/tests/fixtures/skills/test-driven-development/dossier/inputs.yml` exists with 4 required scalars: FOUND
- `core/tests/skill_test_driven_development_e2e.bats` exists; 1 test, 0 failures: FOUND
- Commit `058f5b7` (Task 1: SKILL.md) exists in `git log`: FOUND
- Commit `aa85a55` (Task 2: PRESSURE.md) exists in `git log`: FOUND
- Commit `eee724e` (Task 3: run.sh + fixture + e2e) exists in `git log`: FOUND
- skill_uniformity.bats still 3 PASS spanning both shipped Wave-2 skills: CONFIRMED
- Full bats suite 69 ok / 0 failures: CONFIRMED
- chantier --self-test green: CONFIRMED
- Zero deny-list tokens in PRESSURE.md or run.sh: CONFIRMED
- `claude-code` appears only in SKILL.md frontmatter (line 58): CONFIRMED

## Note for Wave 2 remainder (parallel plans 03-04, 03-05)

The pattern locked in by Plan 03-02 is now confirmed reusable across a second skill of materially different shape (TDD's two-invocation phase-flag model vs. worktree's single-invocation model). The remaining notes for 03-04 (requesting-code-review) and 03-05 (subagent-driven-development):

1. **Frontmatter shape**: 8 fields uniform; `outputs_schema` declares discipline-proof fields per skill. Replace `id`, `inputs_schema` properties, `outputs_schema` required field set, and Invariant 4+ body to skill-specific concerns.
2. **Body section order**: `# Display name` -> `## Purpose` -> `## When to use` -> `## Invariants` -> `## How` -> (`## Why no hooks` for 03-05 ONLY) -> `## Portability claim` -> `## Exit code matrix (from run.sh)` -> `## Acknowledge before acting`. Keep `claude-code` out of the body text (refer to "the frontmatter" or "a single-entry list" instead).
3. **PRESSURE.md bold markers**: use `**Situation**.` / `**Temptation**.` / `**Required response**.` / `**Disqualifier**.` (period AFTER the closing `**`).
4. **run.sh prelude**: copy lines 1-15 from `skills/using-git-worktrees/run.sh` OR `skills/test-driven-development/run.sh` verbatim (license header + `set -eu` + IFS=newline + `LC_ALL=C` + `export LC_ALL`).
5. **run.sh final state append**: wrap the `chantier state append` call in a subshell that `cd`s to the project root (walk up from TASK_DIR looking for `.planning/`). Without this, the lockdir mkdir fails because STATE_FILE / LOCKDIR are CWD-relative in core/bin/chantier.
6. **Counter capture under `grep -c`**: any use of `grep -c ... || printf 'N'` is a bug -- grep already writes the count on no-match. Use `|| true` and a `head -n 1 | tr -d ' '` normalisation if the value flows to `--argjson`.
7. **bats e2e test setup**: 03-05 (subagent) likely does NOT need a git repo in TMPHOME (no git operations). 03-04 (requesting-code-review) WILL need a git repo with at least two commits (for `git diff` to have something to diff). Mirror the worktree skill's `git init -b main` + empty seed-commit setup for 03-04.

The `skill_uniformity.bats` test will continue to enforce three structural checks across all four skills once Wave 2 lands; any drift fails with a clear diagnostic. The deny-list scan in `validate-task` gate 4 will continue to enforce body cleanliness on PRESSURE.md and run.sh of every shipped skill.
