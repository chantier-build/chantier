---
phase: 03-skill-library
plan: "02"
subsystem: skill-using-git-worktrees
tags:
  - phase-03
  - skill
  - using-git-worktrees
  - run-sh
  - pressure-md
  - kernel-invariants
  - e2e-bats
dependency_graph:
  requires:
    - 02-05
    - 02-06
    - 03-01
  provides:
    - skills/using-git-worktrees/SKILL.md
    - skills/using-git-worktrees/PRESSURE.md
    - skills/using-git-worktrees/run.sh
    - core/tests/skill_using_git_worktrees_e2e.bats
    - core/tests/fixtures/skills/using-git-worktrees/dossier/inputs.yml
  affects:
    - core/tests/skill_uniformity.bats (3 SKIP -> 3 PASS for this skill)
    - .planning/ROADMAP.md (Wave 2 row 03-02 checked off)
    - .planning/STATE.md (plan.completed event appended)
tech_stack:
  added: []
  patterns:
    - POSIX-sh-with-jq run.sh shape (mirrors core/bin/chantier prelude)
    - jq -n --arg / --argjson exclusively for output.json emission (T-02-04-INJ defence)
    - git worktree add -b for atomic parallel-isolation tree creation
    - git status --porcelain=v1 | wc -l | tr -d ' ' baseline-clean check (BSD-wc-spaces guard, Pitfall 9)
    - set +e / set -e bracket to capture child exit code under set -eu (Pitfall 3)
    - PRESSURE.md structured spec (Situation / Temptation / Required response / Disqualifier)
    - 4-subsection greppable scenarios with Disqualifier->Invariant->output.json field 1:1 mapping (D-11)
    - bats e2e fixture mounting via cp + make_plan helper from validate_task.bats
key_files:
  created:
    - skills/using-git-worktrees/SKILL.md
    - skills/using-git-worktrees/PRESSURE.md
    - skills/using-git-worktrees/run.sh
    - core/tests/fixtures/skills/using-git-worktrees/dossier/inputs.yml
    - core/tests/skill_using_git_worktrees_e2e.bats
    - .planning/phases/03-skill-library/03-02-SUMMARY.md
  modified: []
decisions:
  - "Worktree path lives under TASK_DIR/worktree rather than .chantier/worktrees/<branch> so Invariant 3 (state_writes containment) holds against the per-task state_writes declaration; matches the SKILL.md frontmatter without expanding state_writes."
  - "run.sh wraps the final `chantier state append` call in a subshell that cd's to the project root (located by walking up from TASK_DIR looking for `.planning/`); the binary expects CWD to contain `.planning/` because STATE_FILE and LOCKDIR are defined as relative paths in core/bin/chantier lines 19-20."
  - "Bold-marker convention uses `**Situation**.` (period AFTER closing `**`) rather than `**Situation.**` (period INSIDE) so the verify regex `^\\*\\*(Situation|Temptation|Required response|Disqualifier)\\*\\*` matches. Semantically identical; chosen to satisfy the falsifiable gate."
  - "outputs_schema declares baseline_check_command, started_at, ended_at as optional alongside the required fields; run.sh always populates them. Keeps room for richer downstream verification without breaking the v0.1 contract."
metrics:
  duration: "~15 minutes"
  completed: "2026-05-30"
  tasks_completed: 3
  tasks_total: 3
  bats_tests_before: 67
  bats_tests_after: 68
  bats_skips_before: 3
  bats_skips_after: 0
---

# Phase 03 Plan 02: using-git-worktrees skill -- Summary

## One-liner

First reference skill shipped end-to-end: `using-git-worktrees` exercises ADR 0001 Surface 2 (8-field SKILL.md frontmatter), Surface 3 (run.sh + chantier state append), and PRESSURE.md (≥2 adversarial scenarios with Disqualifier->Invariant->output.json field mapping); Wave-1 uniformity bats test transitions from 3 SKIP to 3 PASS for this skill.

## What Was Shipped

### Task 1 -- SKILL.md (commit 6f75a5b)

`skills/using-git-worktrees/SKILL.md` (113 lines total, 65 body lines):

- YAML frontmatter with all 8 fields required by `core/schemas/skill.json`: `id: using-git-worktrees`, `version: 1.0.0`, `inputs_schema` (3 required fields: branch_name with ref-shape pattern, setup_command, base_ref), `state_reads: ["{phase}/CONTEXT.md"]`, `state_writes: ["{phase}/tasks/{task}/", ".planning/STATE.md"]`, `outputs_schema` (5 required + 3 optional fields), `portable: true`, `harness_adapters: [claude-code]`.
- Body sections in canonical D-05 / D-15 order: `# Using git worktrees` -> `## Purpose` -> `## When to use` -> `## Invariants` -> `## How` -> `## Portability claim` -> `## Exit code matrix (from run.sh)` -> `## Acknowledge before acting`.
- Numbered `## Invariants` section: kernel 1-3 verbatim per D-06 (Portability / State log append-only / State writes containment) + skill-specific Invariant 4 ("Clean baseline before work") citing `output.json.baseline_diff_lines == 0` AND `output.json.baseline_clean == true` as proof per D-07.
- `## Portability claim` rewritten to not include the literal `claude-code` token in the body (only the SKILL.md frontmatter contains it); body cleanliness is a project convention even though gate 4 exempts SKILL.md.
- `## Exit code matrix` documents D-04 split: 0 = success or business-state failure encoded in output.json; 2 = technical incident (missing inputs.yml / jq / git / filesystem error).

### Task 2 -- PRESSURE.md (commit 6883478)

`skills/using-git-worktrees/PRESSURE.md` (34 lines):

- Frontmatter per D-12: `skill_id: using-git-worktrees`, `scenarios:` array with two entries (`uw-time-pressure-01` / `uw-sunk-cost-01`), each declaring `levers` and `invariants_referenced: [4]`.
- Two scenarios in the D-09 structured spec format:
  - **Scenario 1 (time-pressure)**: "Mid-incident worktree skip". Disqualifier cites Invariant 4 and `output.json.worktree_path` empty OR `output.json.baseline_clean == false`.
  - **Scenario 2 (sunk-cost)**: "Half-finished change blocks the worktree". Disqualifier cites Invariant 4 and `output.json.baseline_diff_lines > 0`.
- Greppable structure: 2 `## Scenario N` headings, 8 `**Subsection**.` markers (4 per scenario × 2). No cross-references to other skills' PRESSURE files (D-13). Zero deny-list tokens (gate 4 scans this file because it sits in `skills/<name>/` and is not SKILL.md).

### Task 3 -- run.sh + fixture + e2e bats test (commit bbf8289)

`skills/using-git-worktrees/run.sh` (mode 0755, shellcheck `--shell=sh` clean):

- Canonical prelude: `#!/bin/sh` -> MIT header -> `set -eu` / IFS=newline / `LC_ALL=C` / `export LC_ALL` (mirrored from `core/bin/chantier` lines 1-13 byte-for-byte).
- Reads `inputs.yml` from `$PWD` via `grep -E '^field:' | sed` (POSIX subset, no yq). Missing required fields -> exit 2 per matrix.
- Dependency check: `command -v jq` / `command -v git`. Absence -> exit 2.
- Baseline check: `DIRTY_LINES=$(git status --porcelain=v1 2>/dev/null | wc -l | tr -d ' ')` -- the `tr -d ' '` strips BSD-wc leading spaces so the subsequent `[ "$DIRTY_LINES" -eq 0 ]` arithmetic comparison works on macOS (Pitfall 9).
- Conditional worktree creation via `git worktree add -b "$BRANCH_NAME" "$_candidate" "$BASE_REF"`. `_candidate="${TASK_DIR}/worktree"` keeps the worktree inside the per-task state_writes scope. Failure (e.g., branch name collision) is captured by `set +e` / `set -e` bracket and recorded as `WORKTREE_PATH=""` -- business state, not technical incident, exit 0.
- Setup command runs inside the worktree via `( cd "$WORKTREE_PATH" && sh -c "$SETUP_COMMAND" )`; same set +e / set -e bracket captures `SETUP_EXIT_CODE` without aborting (Pitfall 3).
- `output.json` emitted via a single `jq -n` call. Every value flows through `--arg` (strings) or `--argjson` (numbers / pre-parsed JSON arrays). No printf %s into JSON anywhere -- T-02-04-INJ defence mirrored from `core/bin/chantier` line 196.
- `output.md` emitted via unquoted heredoc (interpolation desired). Contains the literal `## Acceptance` heading (gate 5 case-sensitive grep `^##[[:space:]]+Acceptance[[:space:]]*$`). The two acceptance bullets are byte-identical to those in the test's PLAN.md (gate 5 substring match).
- Final `chantier state append -e skill.completed -t "${CHANTIER_TASK_ID:-unknown}" -s using-git-worktrees -m "..." -r "$TASK_DIR/output.md" -r "$TASK_DIR/output.json"` invoked inside a subshell that `cd`s to the project root (located by walking up from TASK_DIR looking for `.planning/`). Followed by `exit 0`.

`core/tests/fixtures/skills/using-git-worktrees/dossier/inputs.yml`: three top-level scalars (`branch_name: "feature/test-task"`, `setup_command: "true"`, `base_ref: "main"`). Frontmatter subset profile compliant.

`core/tests/skill_using_git_worktrees_e2e.bats` (157 lines, 1 @test):

- Setup initialises TMPHOME as a git repo (`git init -b main` with fallback to symbolic-ref rename for older git), sets a local user.name/email, makes one empty seed commit so `main` is resolvable, seeds `.planning/STATE.md` with the JSONL frontmatter stub.
- PATH-prepends `$REPO_ROOT/core/bin` so the skill's final `chantier state append` resolves (the binary is not on the host PATH in this project layout).
- Copies SKILL.md / PRESSURE.md / run.sh into TMPHOME so validate-task's skill resolution `<repo_root>/skills/<id>/SKILL.md` succeeds when invoked with TMPHOME as repo root.
- Builds PLAN.md via a `make_plan` helper copied verbatim from `validate_task.bats` lines 29-71 (hermetic; bats setup() runs per @test).
- Stages the fixture dossier inside the task directory.
- Runs `sh "$TMPHOME/skills/<id>/run.sh"`, asserts exit 0 and the presence of output.md / output.json.
- Asserts output.json fields with `jq -e` (baseline_clean is boolean, baseline_diff_lines is number, invariants_applied has at least 3 entries).
- Asserts the `## Acceptance` heading is present in output.md.
- Runs `chantier validate-task t1`, asserts exit 0 (all five gates pass).

## Validation Results

### bats core/tests/skill_using_git_worktrees_e2e.bats

```
$ bats --pretty core/tests/skill_using_git_worktrees_e2e.bats
 ✓ using-git-worktrees: end-to-end through chantier validate-task

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

Transition from 3 SKIP (Wave 1 state) to 3 PASS confirmed.

### bats core/tests/ (full suite)

```
$ bats --pretty core/tests/ | tail -3
68 tests, 0 failures
```

64 Phase-2 baseline + 3 Wave-1 uniformity (now PASS, were SKIP) + 1 new e2e = 68 ok, 0 failures. Zero regressions.

### shellcheck --shell=sh skills/using-git-worktrees/run.sh

```
$ shellcheck --shell=sh skills/using-git-worktrees/run.sh
$ echo $?
0
```

Zero warnings, zero errors.

### Harness-identifier hygiene

```
$ grep -rE 'mcp__|claude_ai_|@codebase|cursor|codex-cli|copilot-cli|gemini-cli|opencode' \
    skills/using-git-worktrees/PRESSURE.md \
    skills/using-git-worktrees/run.sh
(no matches)

$ grep -rn 'claude-code' skills/using-git-worktrees/
skills/using-git-worktrees/SKILL.md:51:  - claude-code
```

`claude-code` appears only in SKILL.md's `harness_adapters` frontmatter array (the sole NFR-001 carve-out per core/schemas/skill.json enum). Zero occurrences in PRESSURE.md or run.sh (gate 4 scans both).

### chantier --self-test

```
$ core/bin/chantier --self-test | tail -3
  ok  no CRLF in self

self-test: all green
```

## Phase 3 Success Criteria Status (partial -- 1 of 4 skills)

| # | Criterion | Status |
|---|-----------|--------|
| 1 | Four skills shipped | 1 of 4 (using-git-worktrees) |
| 2 | Each skill ships SKILL.md with valid 8-field frontmatter | 1 of 4 (this skill's frontmatter validates against `core/schemas/skill.json` enum + pattern constraints) |
| 3 | Each skill ships PRESSURE.md with at least two adversarial scenarios | 1 of 4 (this skill has 2 scenarios in D-09 format) |
| 4 | `chantier validate-task` accepts a task that invokes any of these skills | YES (e2e bats test exercises all 5 gates) |
| 5 | No skill body contains harness-specific identifiers | YES (gate 4 scan + manual `grep -rn` both clean) |

## Deviations from Plan

### Deviation 1 -- PRESSURE.md bold-marker punctuation (Rule 1: bug)

**Found during:** Task 2 verify
**Issue:** The plan's `<action>` block named the four subsection markers as `**Situation.**`, `**Temptation.**`, `**Required response.**`, `**Disqualifier.**` (period INSIDE the closing `**`). The plan's `<verify>` regex is `^\*\*(Situation|Temptation|Required response|Disqualifier)\*\*`, which only matches lines where the closing `**` comes directly after the word -- e.g., `**Situation**` -- not `**Situation.**`. The two cannot both be satisfied.
**Fix:** Punctuation moved OUTSIDE the bold delimiters in all 8 markers: `**Situation**.` rather than `**Situation.**`. Semantically identical to a reader; satisfies the falsifiable verify regex.
**Files modified:** skills/using-git-worktrees/PRESSURE.md
**Commit:** 6883478

### Deviation 2 -- run.sh subshell wraps chantier state append (Rule 3: blocking issue)

**Found during:** Task 3 first bats run
**Issue:** The chantier binary defines `STATE_FILE=".planning/STATE.md"` and `LOCKDIR=".planning/.chantier.lock"` as relative paths (`core/bin/chantier` lines 19-20). When the skill invokes `chantier state append` while `cd`'d to `$TASK_DIR`, the lockdir mkdir attempts to create `.planning/.chantier.lock` relative to `$TASK_DIR` -- which has no `.planning/` subdir, so the mkdir fails, the binary retries 10× with 1-second sleeps, then errors with "state log busy (lock held by PID unknown)".
**Fix:** Wrap the `chantier state append` call in a subshell that first `cd`s to the project root. The project root is located by walking up from `$TASK_DIR` looking for a directory named `.planning/`. The subshell isolation means the `cd` does not leak back into the script's working directory.
**Files modified:** skills/using-git-worktrees/run.sh
**Commit:** bbf8289

### Deviation 3 -- run.sh `for _field in ... eval` replaced by explicit guards (Rule 3: shellcheck-clean)

**Found during:** Task 3 first shellcheck run
**Issue:** A `for _field in BRANCH_NAME SETUP_COMMAND BASE_REF; do eval _val=\"\${$_field}\"; ...; done` loop fired two SC1083 warnings on the `${` and `}` literals inside the `eval` string. The plan's `<verify>` requires shellcheck to be clean.
**Fix:** Replaced the eval loop with three explicit `[ -n "$BRANCH_NAME" ] || { ... }` guards. Code is shorter and shellcheck-clean.
**Files modified:** skills/using-git-worktrees/run.sh
**Commit:** bbf8289

### Documentation-only nit -- bats summary requires `--pretty`

The plan's `<verify>` for Task 3 expected `bats core/tests/skill_using_git_worktrees_e2e.bats 2>&1 | tail -3 | grep -qE '1 test, 0 failures'`. Bats's default output is TAP -- it does not emit the "1 test, 0 failures" summary line. Only `bats --pretty` produces that line. The verification was satisfied by running with `--pretty`. This is identical to the documentation nit Plan 03-01 recorded in its SUMMARY.md. The behaviour (1 test, 0 failures, exit 0) is unchanged whether `--pretty` is passed or not.

## Threat Surface Scan

No new attack surface introduced beyond what the threat model in 03-02-PLAN.md already lists. The threat register dispositions are validated as follows:

| Threat | Status |
|--------|--------|
| T-03-02-01 (command injection via branch_name) | Mitigated -- branch_name flows through `jq --arg` into output.json and as a positional arg to `git worktree add` (literal, not eval'd). No `sh -c "$BRANCH_NAME"` anywhere. |
| T-03-02-02 (JSON injection via setup_command) | Mitigated -- all JSON emission via `jq -n --arg`/`--argjson`. Zero printf %s into JSON. |
| T-03-02-03 (path traversal in state_writes) | Accepted -- already enforced by chantier validate-task gate 1; skill does not re-implement. |
| T-03-02-04 (symlink races during worktree add) | Accepted -- `git worktree add` is atomic per git's own semantics. Skill does not do manual mkdir+mv. |
| T-03-02-05 (TOCTOU on inputs.yml) | Mitigated -- inputs.yml is read once at the top of run.sh into shell variables; no re-read mid-execution. |
| T-03-02-06 (harness identifier leaked) | Mitigated -- gate 4 deny-list scan in `chantier validate-task` runs against the live skill files; e2e bats test exercises gate 4. Manual `grep -rn` confirms `claude-code` appears only in SKILL.md frontmatter. |
| T-03-02-SC (package install legitimacy) | n/a -- no packages installed. |

No new threat flags surfaced during execution.

## Known Stubs

None. All three files (SKILL.md, PRESSURE.md, run.sh) ship complete; the fixture inputs.yml is the documented minimal triple; the e2e bats test exercises the full ADR 0001 contract. Nothing in this plan is intentionally left unwired.

## Self-Check: PASSED

- `skills/using-git-worktrees/SKILL.md` exists; 8-field frontmatter validates: FOUND
- `skills/using-git-worktrees/PRESSURE.md` exists; 2 scenarios, 8 subsection markers: FOUND
- `skills/using-git-worktrees/run.sh` exists; executable bit set; shellcheck clean: FOUND
- `core/tests/fixtures/skills/using-git-worktrees/dossier/inputs.yml` exists with 3 required scalars: FOUND
- `core/tests/skill_using_git_worktrees_e2e.bats` exists; 1 test, 0 failures: FOUND
- Commit `6f75a5b` (Task 1: SKILL.md) exists in `git log`: FOUND
- Commit `6883478` (Task 2: PRESSURE.md) exists in `git log`: FOUND
- Commit `bbf8289` (Task 3: run.sh + fixture + e2e) exists in `git log`: FOUND
- skill_uniformity.bats transitions 3 SKIP -> 3 PASS: CONFIRMED
- Full bats suite 68 ok / 0 failures: CONFIRMED
- chantier --self-test green: CONFIRMED
- Zero deny-list tokens in PRESSURE.md or run.sh: CONFIRMED
- `claude-code` appears only in SKILL.md frontmatter (line 51): CONFIRMED

## Note for Wave 2 (parallel plans 03-03, 03-04, 03-05)

The pattern this plan locks in is reusable verbatim for the remaining three skills:

1. **SKILL.md frontmatter shape**: the 8-field block with `outputs_schema` declaring discipline-proof fields plus optional `started_at` / `ended_at` is now a concrete template. Replace `id`, the `inputs_schema` property set, the `outputs_schema` required field set, and the Invariant 4+ body to skill-specific concerns.
2. **Body section order**: `# Display name` -> `## Purpose` -> `## When to use` -> `## Invariants` -> `## How` -> (`## Why no hooks` for 03-05 only) -> `## Portability claim` -> `## Exit code matrix (from run.sh)` -> `## Acknowledge before acting`. Keep `claude-code` out of the body text (refer to "the frontmatter" or "a single-entry list" instead).
3. **PRESSURE.md bold markers**: use `**Situation**.` / `**Temptation**.` / `**Required response**.` / `**Disqualifier**.` (period AFTER the closing `**`) so the verify regex matches.
4. **run.sh prelude**: copy lines 1-15 from `skills/using-git-worktrees/run.sh` verbatim (license header + `set -eu` + IFS=newline + `LC_ALL=C` + `export LC_ALL`).
5. **run.sh final state append**: wrap the `chantier state append` call in a subshell that `cd`s to the project root (located by walking up from TASK_DIR looking for `.planning/`). Without this, the lockdir mkdir fails because STATE_FILE / LOCKDIR are CWD-relative in core/bin/chantier.
6. **bats e2e test setup**: initialise TMPHOME as a git repo with `git init -b main` and a seed empty commit when the skill needs git operations. PATH-prepend `$REPO_ROOT/core/bin` so the final `chantier state append` resolves.

The Wave-1 `skill_uniformity.bats` test is now PASS-state for this skill. Wave 2's other three plans must each pass:
- `harness_adapters: - claude-code` (or the inline-list form `[claude-code]`) in SKILL.md frontmatter,
- ≥2 `## Scenario N` headings in PRESSURE.md,
- executable `run.sh` in the skill dir.

If any of those drift, `skill_uniformity.bats` will fail with a clear diagnostic message rather than silently letting the contract erode.
