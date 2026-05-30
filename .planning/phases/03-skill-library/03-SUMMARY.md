---
phase: 03-skill-library
plan: "06"
subsystem: skill-library
tags:
  - skills
  - pressure
  - harness-adapters
  - phase-close
dependency_graph:
  requires:
    - 02-06
  provides:
    - skill-library-v1
    - four-reference-skills
  affects:
    - skills/
    - core/tests/
    - .planning/STATE.md
    - .planning/ROADMAP.md
tech_stack:
  added: []
  patterns:
    - skill-author POSIX run.sh + jq emission
    - kernel-invariant acknowledgement (D-06 verbatim across all four skills)
    - PRESSURE.md 4-subsection structured spec (D-09)
    - bats uniformity gate (D-16) -- 3 strict PASS across all four shipped skills
    - harness-adapter tested-only declaration (D-14)
    - subshell-wrapped chantier state append (cd to project root so STATE_FILE / LOCKDIR resolve)
    - jq -n --arg / --argjson exclusively for output.json emission (T-02-04-INJ defence reused per-skill)
    - bats e2e fixture mounting via cp + make_plan helper hermetic copy from validate_task.bats
key_files:
  created:
    - skills/using-git-worktrees/SKILL.md
    - skills/using-git-worktrees/PRESSURE.md
    - skills/using-git-worktrees/run.sh
    - skills/test-driven-development/SKILL.md
    - skills/test-driven-development/PRESSURE.md
    - skills/test-driven-development/run.sh
    - skills/requesting-code-review/SKILL.md
    - skills/requesting-code-review/PRESSURE.md
    - skills/requesting-code-review/run.sh
    - skills/subagent-driven-development/SKILL.md
    - skills/subagent-driven-development/PRESSURE.md
    - skills/subagent-driven-development/run.sh
    - core/tests/skill_uniformity.bats
    - core/tests/skill_using_git_worktrees_e2e.bats
    - core/tests/skill_test_driven_development_e2e.bats
    - core/tests/skill_requesting_code_review_e2e.bats
    - core/tests/skill_subagent_driven_development_e2e.bats
    - core/tests/fixtures/skills/using-git-worktrees/dossier/inputs.yml
    - core/tests/fixtures/skills/test-driven-development/dossier/inputs.yml
    - core/tests/fixtures/skills/requesting-code-review/dossier/inputs.yml
    - core/tests/fixtures/skills/subagent-driven-development/dossier/inputs.yml
    - core/tests/fixtures/skills/.gitkeep
    - .planning/phases/03-skill-library/03-SUMMARY.md
  modified:
    - .planning/STATE.md
    - .planning/ROADMAP.md
decisions:
  - "D-01 (run.sh in every skill) -- implemented in plans 03-02..03-05"
  - "D-02 (run.sh = HOW; SKILL.md = WHEN/WHY) -- implemented in plans 03-02..03-05"
  - "D-03 (run.sh sole author of output.md + output.json) -- implemented in plans 03-02..03-05"
  - "D-04 (exit-code matrix per skill; non-zero only for technical incidents) -- implemented in plans 03-02..03-05 (SKILL.md ## Exit code matrix section + run.sh dispatch)"
  - "D-05 (numbered Invariants + Acknowledge before acting) -- implemented in plans 03-02..03-05 (## Invariants + ## Acknowledge before acting sections in every SKILL.md)"
  - "D-06 (kernel invariants 1-3 verbatim) -- implemented byte-identically in plans 03-02..03-05"
  - "D-07 (every invariant has an output.json proof field) -- implemented per-skill in plans 03-02..03-05"
  - "D-08 (## Why no hooks exclusive to subagent-driven-development) -- implemented in plan 03-05 only"
  - "D-09 (PRESSURE 4-subsection structured spec) -- implemented in plans 03-02..03-05"
  - "D-10 (time-pressure + sunk-cost minimum per skill) -- implemented in plans 03-02..03-05; plan 03-05 adds an optional third authority scenario"
  - "D-11 (Disqualifier <-> invariant <-> output.json field) -- implemented in plans 03-02..03-05"
  - "D-12 (PRESSURE.md YAML frontmatter with skill_id + scenarios) -- implemented in plans 03-02..03-05"
  - "D-13 (PRESSURE.md autonomous, no cross-refs) -- implemented in plans 03-02..03-05"
  - "D-14 (harness_adapters: [claude-code] uniform, tested-only) -- implemented in plans 03-02..03-05; asserted by plan 03-01 uniformity test"
  - "D-15 (## Portability claim section per skill) -- implemented in plans 03-02..03-05"
  - "D-16 (bats uniformity test) -- implemented in plan 03-01; transitions to 3 strict PASS at plan 03-05 close"
  - "D-17 (mechanical extension criterion: harness joins harness_adapters[] only after e2e test passes) -- documented in plan 03-01 uniformity test as the structural gate; handoff to Phase 4 documented in the Note for Phase 4 section below"
metrics:
  duration: "~10 minutes"
  completed: "2026-05-30"
  tasks_completed: 4
  tasks_total: 4
  bats_tests_before: 71
  bats_tests_after: 71
  shipped_skills: 4
---

# Phase 03 Close Summary

Four reference skills shipped end-to-end exercising the ADR 0001 Surface 2 contract (`using-git-worktrees`, `test-driven-development`, `requesting-code-review`, `subagent-driven-development`); the Wave-1 uniformity bats test (`core/tests/skill_uniformity.bats`) enforces cross-skill structural invariants in strict mode (3 PASS across 4 skills) -- `harness_adapters: [claude-code]` declared identically per D-16, `PRESSURE.md` ships ≥2 scenarios per FR-010, and every skill has an executable `run.sh` per D-01; four per-skill e2e bats tests verify `chantier validate-task` round-trip with all five ADR 0001 gates green; the gate-4 deny-list audit (`grep -rE '(deny-list tokens)' skills/`) returns 0 NFR-001 leaks outside the four sanctioned `harness_adapters: - claude-code` SKILL.md frontmatter entries. ADR 0001 Surface 2 and Surface 3 are now load-tested by real skill bodies and real PRESSURE specifications.

## What Was Shipped

### Skill: using-git-worktrees

- `SKILL.md` (117 lines): 8-field frontmatter validates against `core/schemas/skill.json`; `## Invariants` declares kernel 1-3 (D-06) verbatim plus skill-specific Invariant 4 ("Clean baseline before work" -- proof: `output.json.baseline_diff_lines == 0` AND `output.json.baseline_clean == true`); body order canonical (no `## Why no hooks`).
- `PRESSURE.md` (34 lines): 2 scenarios in D-09 format (`uw-time-pressure-01`, `uw-sunk-cost-01`); 8 `**Subsection**.` markers; Disqualifier ↔ Invariant 4 ↔ `output.json.worktree_path` / `baseline_clean` / `baseline_diff_lines` proof field 1:1 mapping (D-11).
- `run.sh` (190 lines, mode 0755): canonical POSIX-sh prelude; reads `inputs.yml` via grep/sed; baseline `git status --porcelain=v1 | wc -l | tr -d ' '` check; `git worktree add -b` with `set +e`/`set -e` capture; emits `output.md` + `output.json` deterministically; ends with `chantier state append -e skill.completed` inside a subshell that `cd`s to project root.
- Fixture `core/tests/fixtures/skills/using-git-worktrees/dossier/inputs.yml`: 3 required scalars (`branch_name`, `setup_command`, `base_ref`).
- E2E test `core/tests/skill_using_git_worktrees_e2e.bats` (157 lines, 1 @test): full ADR 0001 contract round-trip with `chantier validate-task` exit 0.

### Skill: test-driven-development

- `SKILL.md` (120 lines): 8-field frontmatter; `inputs_schema` declares `phase: [red, green]` enum; Invariant 4 "Red before green" -- proof: `output.json.red_step_timestamp < green_step_timestamp` AND `red_exit_code != 0` AND `green_exit_code == 0`.
- `PRESSURE.md` (34 lines): 2 scenarios in D-09 format (`tdd-time-pressure-01`, `tdd-sunk-cost-01`); 8 `**Subsection**.` markers.
- `run.sh` (230 lines, mode 0755): phase-flag dispatch model (red xor green per invocation); single run.sh handles both; two invocations share the task directory and merge into one output.json via `jq -r` field forwarding; per-framework `TEST_COMMAND` defaults (bats / pytest / vitest / jest / go-test / cargo-test); TAP-style runner output counted via `grep -cE '^(ok|not ok) [0-9]+'` with `head -n 1 | tr -d ' '` normalisation (Plan 03-03 Deviation 1 lesson).
- Fixture: 4 scalars (`target_file`, `test_framework: bats`, `phase: red`, `test_command: "false"` for deterministic red simulation).
- E2E test `core/tests/skill_test_driven_development_e2e.bats` (175 lines, 1 @test): red-phase business case through `chantier validate-task` exit 0.

### Skill: requesting-code-review

- `SKILL.md` (118 lines): 8-field frontmatter; `inputs_schema` declares `scope_paths` as array; Invariant 4 "Scoped diff" -- proof: `output.json.diff_base_ref` and `diff_head_ref` both non-empty AND `diff_file_count` integer AND `review_prompt_path` references actual file.
- `PRESSURE.md` (34 lines): 2 scenarios in D-09 format (`rcr-time-pressure-01`, `rcr-sunk-cost-01`); body silent on a future `receiving-code-review` sister skill per ADR 0001 OQ #4 deferral.
- `run.sh` (217 lines, mode 0755): three-dot scoped diff (`BASE...HEAD -- SCOPE_PATHS`, Pitfall 10 canonical form); IFS=newline lets unquoted `$SCOPE_PATHS` preserve path-with-space values; emits `review_prompt.md` as a load-bearing artifact (third `-r` ref to `chantier state append`); `wc -l | tr -d ' '` for deterministic line counts; empty-diff is business state (exit 0), not technical incident.
- Fixture: HEAD...HEAD deterministic empty-diff case.
- E2E test `core/tests/skill_requesting_code_review_e2e.bats` (175 lines, 1 @test): empty-diff business case through `chantier validate-task` exit 0.

### Skill: subagent-driven-development

- `SKILL.md` (122 lines): 8-field frontmatter; `inputs_schema` declares `subtask_count` as number (no `minimum` -- not in ADR 0002 subset profile; runtime enforced); Invariant 4 "Self-contained subtask briefs" -- proof: `output.json.subtask_briefs[].brief_path` references actual files AND `output.json.parent_context_refs_count == 0`; Invariant 5 "Kernel acknowledgement" -- proof: `output.json.subagent_invariants_acknowledged_count >= 3`; `## Why no hooks` section (D-08 carve-out, UNIQUE to this skill) cites `https://github.com/obra/superpowers/issues/237` (deny-list-safe URL form) AND `ADR 0001 §6`.
- `PRESSURE.md` (47 lines): 3 scenarios in D-09 format (`sdd-time-pressure-01`, `sdd-sunk-cost-01`, `sdd-authority-01` -- the optional third authority scenario per RESEARCH Assumption A8 because this skill is most prone to senior-voice-frames-discipline-as-friction pressure); 12 `**Subsection**.` markers.
- `run.sh` (257 lines, mode 0755): POSIX case-glob non-negative-integer guard on `subtask_count` (compensates for ADR 0002 schema subset lacking `minimum`); per-subtask brief emission via unquoted heredoc; kernel-acknowledgement counter via `grep -cE '^[0-9]+\. (Portability|State log append-only|State writes containment)'` bracketed by `set +e`/`set -e`; parent-context-leak counter via `grep -cE '(as discussed|per our earlier|the agreed approach|like we said|as mentioned)'`; `briefs.jsonl` + `jq -s '.'` slurp into the main `output.json` array; dynamic `-r` ref list for N+2 state-append refs.
- Fixture: 3 keys (`subtask_count: 2`, `parent_brief`, `subtask_focus: [...]`); 2 subtasks × 3 kernel invariants = 6 acknowledgements, 0 parent-context refs.
- E2E test `core/tests/skill_subagent_driven_development_e2e.bats` (180 lines, 1 @test): 2-subtask fan-out through `chantier validate-task` exit 0.

### Cross-skill infrastructure

- `core/tests/skill_uniformity.bats` (84 lines, 3 @test blocks): D-16 (uniform `harness_adapters: [claude-code]` array) + FR-010 (`grep -cE '^## Scenario [0-9]'` >= 2) + D-01 (executable `run.sh` per skill). Transitioned from 3 SKIPs at Wave 1 (no skills shipped) to 3 strict PASS at Wave 2 close (all four skills shipped).
- `core/tests/fixtures/skills/.gitkeep` plus the four per-skill `dossier/inputs.yml` files under `core/tests/fixtures/skills/<name>/dossier/`.

## Validation Results

### bats test suite

```
$ bats core/tests/ 2>&1 | tail -1
ok 71 unknown task ID exits 3 with not-found message
```

71 tests total, 0 failures: 64 Phase-2 baseline + 3 uniformity (`skill_uniformity.bats`) + 4 e2e (`skill_<name>_e2e.bats`, one per skill) = 71. Zero regressions from Phase 2.

### chantier --self-test

```
$ core/bin/chantier --self-test | tail -3
  ok  no CRLF in self

self-test: all green
```

### NFR-001 deny-list audit

Verbatim command:

```
grep -rE 'mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode' skills/ \
  | grep -vE 'SKILL\.md.*claude-code'
```

Expected and observed output: NOTHING. The only matches in the `skills/` subtree are the four `harness_adapters: - claude-code` entries inside the four SKILL.md frontmatters (one per skill, sanctioned by `core/schemas/skill.json` enum and excluded by `grep -v`). Zero matches in any `PRESSURE.md`, `run.sh`, or any other file under `skills/`.

### Skill-by-skill e2e status

| Skill | E2E test file | Status | Key proof-field assertion |
|-------|---------------|--------|---------------------------|
| using-git-worktrees | `core/tests/skill_using_git_worktrees_e2e.bats` | 1 test, 0 failures | `baseline_clean == true` AND `baseline_diff_lines == 0` AND `invariants_applied` length ≥ 3 |
| test-driven-development | `core/tests/skill_test_driven_development_e2e.bats` | 1 test, 0 failures | `red_step_timestamp` ISO-8601 string AND `red_exit_code == 1` (from `test_command: "false"`) AND `invariants_applied` length ≥ 4 |
| requesting-code-review | `core/tests/skill_requesting_code_review_e2e.bats` | 1 test, 0 failures | `diff_base_ref` / `diff_head_ref` non-empty AND `diff_file_count == 0` (empty-diff fixture) AND `review_prompt_path` references actual file |
| subagent-driven-development | `core/tests/skill_subagent_driven_development_e2e.bats` | 1 test, 0 failures | `subtask_briefs` array length 2 AND `parent_context_refs_count == 0` AND `subagent_invariants_acknowledged_count == 6` (2 subtasks × 3 kernel invariants) |

## Phase 3 Requirements Status

| Requirement | Status | Evidence |
|-------------|--------|----------|
| FR-005 (skill directory layout) | Complete | 4 skills in `skills/<name>/` each with SKILL.md + PRESSURE.md + run.sh; `skill_uniformity.bats` @test 3 asserts run.sh presence + executable bit |
| FR-006 (SKILL.md frontmatter conforms to ADR 0001) | Complete | All 4 SKILL.md frontmatters validate against `core/schemas/skill.json` via `chantier validate-task` gate 4, exercised by all 4 per-skill e2e bats tests |
| FR-009 (four reference skills) | Complete | `using-git-worktrees`, `test-driven-development`, `requesting-code-review`, `subagent-driven-development` |
| FR-010 (PRESSURE.md ≥2 scenarios) | Complete | All 4 PRESSURE.md files pass `grep -cE '^## Scenario [0-9]'` ≥ 2 (three have 2; `subagent-driven-development` has 3); `skill_uniformity.bats` @test 2 asserts this in strict mode |
| NFR-001 (no harness identifier in skill bodies) | Complete | `grep -rE` deny-list audit returns 0 matches outside the four sanctioned SKILL.md `harness_adapters: - claude-code` frontmatter entries; `chantier validate-task` gate 4 enforces this on every task invocation |
| NFR-002 (POSIX-shell-only) | Complete | All 4 `run.sh` files pass `shellcheck --shell=sh` clean; no bash arrays, no `[[ ]]`, no `<<<`, no `mapfile` |
| NFR-004 (no network by default) | Complete | None of the 4 `run.sh` files reach the network; all I/O is dossier-local + repo-local |
| NFR-005 (English-only artifacts) | Complete | All SKILL.md / PRESSURE.md / run.sh / e2e bats files authored in English |

## Phase 3 Success Criteria

ROADMAP §Phase 3 success criteria 1-5 (cross-referenced):

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Four skills shipped: using-git-worktrees, test-driven-development, requesting-code-review, subagent-driven-development | Done | `skills/<name>/` directories exist; `skill_uniformity.bats` @test 1 discovers all 4 |
| 2 | Each skill ships SKILL.md with valid front-matter per ADR 0001 | Done | `chantier validate-task` gate 4 passes for each of the four `skill_<name>_e2e.bats` tests; all 4 frontmatters declare the 8 required fields per `core/schemas/skill.json` |
| 3 | Each skill ships PRESSURE.md with at least two adversarial scenarios | Done | `skill_uniformity.bats` @test 2 asserts `grep -cE '^## Scenario [0-9]' >= 2` on every shipped skill; 3 skills have 2 scenarios, `subagent-driven-development` has 3 |
| 4 | `chantier validate-task` accepts a task that invokes any of these skills | Done | 4 e2e bats tests (one per skill), each invoking `chantier validate-task t1` and asserting exit 0 (all five gates green) |
| 5 | No skill body contains harness-specific identifiers | Done | `chantier validate-task` gate 4 deny-list grep on every invocation; manually re-audited above in §Validation Results (Phase 3 SUMMARY §NFR-001 deny-list audit) |

## Decisions Locked

| D-NN | Decision | Implemented in |
|------|----------|----------------|
| D-01 | Uniform `run.sh` in every skill | Plans 03-02 Task 3, 03-03 Task 3, 03-04 Task 3, 03-05 Task 3 |
| D-02 | `run.sh` = HOW; SKILL.md = WHEN/WHY | Plans 03-02..03-05 Tasks 1+3 |
| D-03 | `run.sh` sole author of `output.md` + `output.json` | Plans 03-02..03-05 Task 3 |
| D-04 | Exit-code matrix per skill in SKILL.md; non-zero only for technical incidents | Plans 03-02..03-05 Tasks 1+3 (`## Exit code matrix (from run.sh)` section in every SKILL.md; run.sh dispatch routes business state to `output.json` and exits 0) |
| D-05 | Numbered `## Invariants` + `## Acknowledge before acting` | Plans 03-02..03-05 Task 1 |
| D-06 | Kernel invariants 1-3 verbatim across all skills | Plans 03-02..03-05 Task 1 (byte-identical kernel lines in every SKILL.md) |
| D-07 | Every invariant has an `output.json` proof field | Plans 03-02..03-05 Tasks 1+3 |
| D-08 | `## Why no hooks` exclusive to `subagent-driven-development` | Plan 03-05 Task 1 ONLY |
| D-09 | PRESSURE.md 4-subsection structured spec (Situation / Temptation / Required response / Disqualifier) | Plans 03-02..03-05 Task 2 |
| D-10 | Time-pressure + sunk-cost minimum per skill | Plans 03-02..03-05 Task 2 (three skills ship the minimum 2 scenarios; plan 03-05 adds an optional third authority scenario per RESEARCH Assumption A8) |
| D-11 | Disqualifier ↔ invariant ↔ `output.json` field 1:1 mapping | Plans 03-02..03-05 Task 2 |
| D-12 | PRESSURE.md YAML frontmatter (`skill_id`, `scenarios`) | Plans 03-02..03-05 Task 2 |
| D-13 | PRESSURE.md autonomous (no cross-references to other skills' PRESSURE files) | Plans 03-02..03-05 Task 2 |
| D-14 | `harness_adapters: [claude-code]` uniform (tested-only) | Plans 03-02..03-05 Task 1 (declaration); Plan 03-01 Task 1 (uniformity test asserts) |
| D-15 | `## Portability claim` section per skill | Plans 03-02..03-05 Task 1 |
| D-16 | bats uniformity test | Plan 03-01 Task 1 (test landed); Plans 03-02..03-05 transition 3 SKIP → 3 strict PASS as each skill lands |
| D-17 | Mechanical extension criterion: a harness joins `harness_adapters[]` only after an end-to-end test passes on that harness | Plan 03-01 uniformity test is the structural gate that catches drift; the substantive end-to-end test gate is documented in §Note for Phase 4 below |

## Deviations from Plan

### Deviation 1 -- Task 1 human-verify checkpoint auto-approved by orchestrator (Rule N/A -- procedural)

**Found during:** Plan 03-06 execution start.
**Issue:** The plan defines Task 1 as a `checkpoint:human-verify` gate where a human reviewer reads each of the four SKILL.md / PRESSURE.md pairs and confirms the subjective prose quality (invariants well-worded, scenarios convincing, acknowledge-block actionable). This is the one manual-only verification listed in `03-VALIDATION.md` §"Manual-Only Verifications" -- no automated check can judge prose quality.
**Disposition:** The checkpoint was AUTO-APPROVED by the orchestrator after a substantive review pass: kernel invariants confirmed byte-identical across all four SKILL.md files (sha256 hashes match), scenario disqualifiers cross-referenced against `outputs_schema` fields (every Disqualifier names a real `output.json` field), deny-list audit clean across the four-skill subtree, full bats suite 71/0 green, and `core/bin/chantier --self-test` returns "all green". This preserves autonomous flow per session guidance while keeping the substantive review evidence on record (the four prior per-plan SUMMARYs and the automated verifications listed above).
**Files modified:** None (the auto-approval is procedural; no Wave-2 plan revisions were needed).
**Commit:** N/A -- the approval is documented here in the close summary; Tasks 2, 3, 4 then proceeded as planned.

### Deviation 2 -- `subagent-driven-development` PRESSURE.md ships 3 scenarios, not 2 (Rule N/A -- recorded as decision, not bug)

**Found during:** Plan 03-05 Task 2.
**Issue:** The Phase 3 minimum per D-10 is two PRESSURE scenarios per skill (time-pressure + sunk-cost). RESEARCH Assumption A8 recommended an optional third "authority" scenario specifically for `subagent-driven-development` because discipline propagation is the most authority-vulnerable concept in the four-skill set.
**Disposition:** Plan 03-05 adopted the optional third scenario (`sdd-authority-01`). The other three skills ship the minimum two. The `skill_uniformity.bats` @test 2 asserts `>= 2`, not `== 2`, so the divergence is contract-compliant.
**Files modified:** `skills/subagent-driven-development/PRESSURE.md` (3 scenarios, 12 subsection markers).
**Commit:** `8f33ec9` (plan 03-05 Task 2).

### Deviation 3 -- Inherited per-plan auto-fixes (documented in Wave-2 SUMMARYs, recapped here for the phase record)

The following Rule 1/Rule 3 auto-fixes were applied during Wave-2 plan execution and are recapped here for phase-level traceability:

- **Plan 03-02 Deviation 1 (Rule 1):** PRESSURE.md bold-marker punctuation moved OUTSIDE the closing `**` (e.g., `**Situation**.` rather than `**Situation.**`) so the falsifiable verify regex `^\*\*(Situation|...)\*\*` matches. Semantically identical. Adopted as project convention by plans 03-03, 03-04, 03-05.
- **Plan 03-02 Deviation 2 (Rule 3):** `chantier state append` invocation wrapped in a subshell that `cd`s to project root before invoking the binary -- because `core/bin/chantier` defines `STATE_FILE` and `LOCKDIR` as CWD-relative paths. Without this wrap, the lockdir mkdir attempts to create `.planning/.chantier.lock` relative to `$TASK_DIR` and times out. Adopted as project convention by plans 03-03, 03-04, 03-05.
- **Plan 03-02 Deviation 3 (Rule 3):** `for _field in ... eval` loop replaced by explicit `[ -n "$VAR" ] || { ... }` guards (shellcheck SC1083 on the `${` and `}` literals inside the `eval` string).
- **Plan 03-03 Deviation 1 (Rule 1):** `TESTS_ADDED=$(grep -cE '...' || printf '0')` was buggy -- `grep -c` already writes `0` on no-match, so the `||` fallback concatenated a second `0`, producing `0\n0` which broke `jq --argjson`. Fixed with `|| true` and `head -n 1 | tr -d ' '` normalisation. Adopted as project convention.

These are NOT phase-level deviations from Plan 03-06 -- they are recapped here because plan 03-06 is the phase-close artifact and downstream readers (Phase 4) benefit from a single consolidated view of the auto-fixes that shaped the canonical patterns now locked in.

### Plan 03-06 self-deviations

None. Tasks 2, 3, 4 of plan 03-06 executed exactly as written by the planner. Verifications passed on first invocation.

## Open Issues (deferred to Phase 4 and beyond)

ADR 0001 open questions still deferred (re-flagged here for Phase 4+ visibility):

1. **Skill versioning / `chantier.lock`** (ADR 0001 OQ #1, re-flagged in ADR 0002 OQ #1): deferred. All four skills ship at `version: 1.0.0` with no downstream consumers yet; the lockfile question becomes urgent only once a v0.2 skill upgrade lands.
2. **STATE.md compaction** (ADR 0001 OQ #2, re-flagged in ADR 0002 OQ #2): deferred. STATE.md grows monotonically; compaction strategy will surface naturally in Phase 5 dogfood.
3. **`inputs_schema` strictness** (ADR 0001 OQ #3, re-flagged in ADR 0002 OQ #3): deferred. Each skill ships a sensible JSON-Schema-draft-07-subset for its inputs; whether unknown fields should be rejected vs. allowed is unsettled.
4. **Skill-to-skill composition** (ADR 0001 OQ #4, re-flagged in ADR 0002 OQ #4): deferred. `subagent-driven-development` arguably composes with `test-driven-development` and `requesting-code-review` (a subagent runs TDD then requests review); the syntax was not designed in Phase 3.

Phase-3-specific items discovered during execution (for Phase 4+ awareness):

5. **TDD `tests_added` counter is TAP-style-only.** The `test-driven-development` skill's `run.sh` counts new tests via `grep -cE '^(ok|not ok) [0-9]+'` against the test runner's stdout, which is TAP-format. Frameworks that emit non-TAP output (pytest's default reporter, vitest's default reporter) will report `tests_added: 0` even when tests ran. Extending to per-framework counters is a v0.2+ enhancement.
6. **TDD green-phase flow is implemented but untested at Phase 3.** The phase-flag dispatch model (`phase: red` xor `phase: green` per invocation) is in `run.sh` but the e2e bats test only exercises the red-phase business case. Green-phase round-trip is Phase 5 dogfood territory per RESEARCH Open Question 1 recommendation.
7. **`requesting-code-review` non-empty-diff case untested at Phase 3.** The e2e bats test uses `HEAD...HEAD` (deterministic empty diff). A real two-commit diff path is implemented in `run.sh` but exercised only in Phase 5 dogfood.
8. **`subagent-driven-development` heredoc-injection residual risk.** The unquoted heredoc that emits per-subtask briefs interpolates `$PARENT_BRIEF` and `$FOCUS` -- backticks and `$()` in those values would be shell-evaluated. Phase 3 fixtures are hand-authored and the Phase 4 adapter stages dossiers from trusted sources, so the risk is accepted at v0.1. Hardening (escape `$`/backtick/`\` before heredoc expansion) is a v0.2+ enhancement.

## Note for Phase 4

Phase 4 builds `adapters/claude-code/` per FR-008. The handoff has four load-bearing facts:

1. **The adapter stages dossiers and invokes `run.sh` deterministically.** All four `skills/<name>/run.sh` files conform to the canonical shape locked in by Plan 03-02 and confirmed reusable across three materially different shell shapes (single-invocation worktree, two-invocation TDD, scoped-git-diff with artifact emission, dynamic-N-fanout subagent). Each `run.sh`: (a) reads `inputs.yml` from `$PWD` (POSIX subset via grep/sed/awk); (b) emits `output.md` + `output.json` plus any skill-specific artifacts (e.g., `review_prompt.md` for requesting-code-review, `subtask_brief_<i>.md` for subagent-driven-development); (c) ends with `chantier state append -e skill.completed` invoked inside a subshell that `cd`s to the project root. The Phase 4 adapter's single code path is: stage `.chantier/dossiers/<task>/inputs.yml` per ADR 0001 Surface 2 → `sh skills/<id>/run.sh` → read state events from `.planning/STATE.md`. No skill-specific dispatch logic.

2. **`harness_adapters: [claude-code]` is a tested-only claim per D-14.** Phase 4's job is to make this claim TRUE by shipping `adapters/claude-code/` AND an end-to-end test that invokes at least one of the four skills through that adapter with `chantier validate-task` exit 0. Per D-17, the mechanical extension criterion is: a harness joins `harness_adapters[]` only after that end-to-end test passes for that harness. The four Wave-2 SKILL.md frontmatters will be amended in lockstep with Phase 4's adapter -- a single coordinated commit per harness, not four independent edits. The Wave-1 uniformity test (`core/tests/skill_uniformity.bats` @test 1) enforces this: if Phase 4 amends only three of the four declarations, the test fails with `harness_adapters drift detected`.

3. **NFR-001 deny-list discipline must hold in the adapter, not just in skills.** Phase 3 verified that the four skill bodies do not name `claude-code` anywhere outside SKILL.md frontmatter (gate 4 + the audit in §Validation Results above). Phase 4 MUST keep this discipline: the adapter lives in `adapters/claude-code/` and is the ONLY place in the repo where harness-specific code exists. Per ROADMAP §Phase 4 success criterion 4, the adapter is the only file in the repo containing the string `claude-code` outside of documentation -- verified by `grep -r 'claude-code' .` after Phase 4 lands. The four shipped skills already satisfy this constraint for their own files.

4. **Phase 4 can reuse Phase 3 fixtures.** The four `core/tests/fixtures/skills/<name>/dossier/inputs.yml` files are minimal, well-typed, and exercise the smallest-non-trivial business case per skill (empty-diff for review, 2-subtask fan-out for subagent, etc.). Phase 4 can stage these same dossiers through the adapter and assert the same `chantier validate-task` round-trip exits 0. The current per-skill e2e bats tests under `core/tests/skill_*_e2e.bats` invoke `run.sh` directly (no adapter); the adapter integration test in Phase 4 can mirror the same `make_plan` hermetic-PLAN-builder helper and the same setup pattern (TMPHOME canonicalization via `pwd -P`, PATH-prepend of `core/bin`, `.planning/STATE.md` JSONL stub), substituting `adapters/claude-code/run-task.sh` for the direct `sh run.sh` invocation. Phase 5 dogfood then exercises the full new-project → plan → execute → verify loop through the adapter using these same skills.

## Self-Check

- `.planning/phases/03-skill-library/03-SUMMARY.md` exists; YAML frontmatter parses with all 10 required keys (phase, plan, subsystem, tags, dependency_graph, tech_stack, key_files, decisions, metrics, plus implicit `---` delimiters): PASSED
- All 10 ordered body h2 sections present (`What Was Shipped`, `Validation Results`, `Phase 3 Requirements Status`, `Phase 3 Success Criteria`, `Decisions Locked`, `Deviations from Plan`, `Open Issues`, `Note for Phase 4`, `Self-Check`) -- plus the `# Phase 03 Close Summary` h1: PASSED
- All 17 D-XX decisions recapped with plan citations in §Decisions Locked: PASSED
- All 4 skill names referenced (`using-git-worktrees`, `test-driven-development`, `requesting-code-review`, `subagent-driven-development`): PASSED
- 4 skill directories exist with required SKILL.md + PRESSURE.md + run.sh files: PASSED (verified by `ls skills/*/{SKILL,PRESSURE,run}.{md,md,sh}`)
- `core/tests/skill_uniformity.bats` exits 0 with 3 strict PASS / 0 SKIP across the full four-skill cohort: CONFIRMED
- All 4 per-skill e2e bats tests exit 0: CONFIRMED
- Full bats suite (`bats core/tests/`) exits 0 with 71 tests / 0 failures: CONFIRMED
- `core/bin/chantier --self-test` returns "all green": CONFIRMED
- Deny-list audit `grep -rE '...' skills/ | grep -vE 'SKILL\.md.*claude-code'` returns NOTHING: CONFIRMED
