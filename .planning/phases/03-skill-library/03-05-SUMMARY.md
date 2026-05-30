---
phase: 03-skill-library
plan: "05"
subsystem: skill-subagent-driven-development
tags:
  - phase-03
  - skill
  - subagent-driven-development
  - run-sh
  - pressure-md
  - kernel-invariants
  - why-no-hooks
  - issue-237
  - adr-0003-keystone
dependency_graph:
  requires:
    - 02-05
    - 02-06
    - 03-01
    - 03-02
    - 03-03
    - 03-04
  provides:
    - skills/subagent-driven-development/SKILL.md
    - skills/subagent-driven-development/PRESSURE.md
    - skills/subagent-driven-development/run.sh
    - core/tests/skill_subagent_driven_development_e2e.bats
    - core/tests/fixtures/skills/subagent-driven-development/dossier/inputs.yml
  affects:
    - core/tests/skill_uniformity.bats (3 PASS now spans all four shipped Wave-2 skills)
    - .planning/ROADMAP.md (Wave 2 row 03-05 checked off; Phase 3 plan count 5/6)
    - .planning/STATE.md (plan.completed event appended)
tech_stack:
  added: []
  patterns:
    - POSIX-sh-with-jq run.sh shape (matches Plans 03-02/03-03/03-04 prelude byte-for-byte)
    - jq -n --arg / --argjson exclusively for output.json emission (T-03-05-02 defence)
    - briefs.jsonl + jq -s '.' slurp pattern for the dynamic subtask_briefs JSON array
    - set +e / set -e bracket around `grep -cE` to capture counter under set -eu (Pitfall 3); `|| true` is NOT enough on its own when the value flows to --argjson, hence the defensive empty-string normalisation [ -n "$x" ] || x=0
    - case "$VAR" in ''|*[!0-9]*) ... esac POSIX non-negative-integer guard for subtask_count (the inputs_schema does not carry `minimum` because the ADR 0002 JSON Schema subset profile does not list it)
    - per-subtask brief emitted via unquoted heredoc with three kernel-invariant preamble lines that match the run.sh grep counter regex (Invariant 5 measurability contract)
    - per-brief parent-context-reference scan via `grep -cE '(as discussed|per our earlier|the agreed approach|like we said|as mentioned)'` (Invariant 4 measurability contract)
    - Dynamic -r ref list built by `while` loop so N+2 refs (output.md / output.json / N briefs) travel with the final `chantier state append` event
    - Final chantier state append wrapped in subshell that cd's to project root located by walking up for .planning/ (inherited from Plan 03-02 deviation 2)
    - PRESSURE.md structured spec (Situation / Temptation / Required response / Disqualifier) with period AFTER closing **
    - Optional third "authority" scenario per RESEARCH Assumption A8 -- adopted because this skill is the most prone to senior-user-frames-discipline-as-friction pressure
    - bats e2e fixture mounting via cp + make_plan helper hermetically copied from skill_using_git_worktrees_e2e.bats
    - NO git init in TMPHOME (subagent skill performs no git operations) per the 03-03 SUMMARY note for Wave 2 remainder
key_files:
  created:
    - skills/subagent-driven-development/SKILL.md
    - skills/subagent-driven-development/PRESSURE.md
    - skills/subagent-driven-development/run.sh
    - core/tests/fixtures/skills/subagent-driven-development/dossier/inputs.yml
    - core/tests/skill_subagent_driven_development_e2e.bats
    - .planning/phases/03-skill-library/03-05-SUMMARY.md
  modified: []
decisions:
  - "## Why no hooks section is the load-bearing distinction of this skill from the other three. The body cites the safe URL https://github.com/obra/superpowers/issues/237 (RESEARCH Example 4: no deny-list token) AND ADR 0001 §6. This is the only skill in the project that contains this section -- D-08 is exclusive to subagent-driven-development."
  - "Invariant 4 (self-contained-subtask-briefs) and Invariant 5 (kernel-acknowledgement) are the mechanical embodiment of the ## Why no hooks rationale: every subtask brief is a file on disk, and every brief acknowledges the kernel invariants verbatim. The briefs are the only thing that crosses the parent->subagent context boundary."
  - "Three PRESSURE scenarios shipped (not two): the minimum is time-pressure + sunk-cost per D-10, but RESEARCH Assumption A8 recommends a third authority scenario for this skill specifically -- it is the skill most prone to senior-voice override because discipline propagation is exactly the kind of thing a user can frame as boilerplate friction."
  - "inputs_schema for subtask_count declares `type: number` ONLY -- no `minimum` keyword, because the ADR 0002 JSON Schema subset profile does not include `minimum` (only type, required, properties, additionalProperties, pattern, enum, items). The >= 1 validation is enforced at runtime by a POSIX case-glob non-negative-integer guard plus an arithmetic test in run.sh; failure -> exit 2 per the matrix in SKILL.md."
  - "Counter capture for ACK_TOTAL and PARENT_REFS_TOTAL: bracketed by set +e / set -e because `grep -c` exits 1 on no-match (Pitfall 3) which would abort under `set -eu`. Defensive `[ -n \"$x\" ] || x=0` normalisation handles BSD-wc edge cases. Pattern locked in by Plan 03-03 Deviation 1; reused here verbatim."
  - "outputs_schema declares started_at, ended_at as optional alongside the five required fields. run.sh always populates them so downstream verifiers can use them; keeps room for richer downstream verification without breaking the v0.1 contract."
  - "Body length 122 lines (within the 120-200 target -- slightly above the 100-180 budget of the other three skills because of the extra `## Why no hooks` section)."
  - "PRESSURE.md bold-marker punctuation period AFTER closing ** -- matches Plans 03-02/03-03/03-04's convention adopted as established precedent."
  - "ADR 0003 (Proposed) keystone: this skill demonstrates the explicit-chaining principle. The skill body and dossier are the only things that cross the context boundary; there are no implicit hooks or session-injected disciplines, by design."
metrics:
  duration: "~12 minutes"
  completed: "2026-05-30"
  tasks_completed: 3
  tasks_total: 3
  bats_tests_before: 70
  bats_tests_after: 71
  shipped_skills_before: 3
  shipped_skills_after: 4
---

# Phase 03 Plan 05: subagent-driven-development skill -- Summary

## One-liner

Fourth (and final Wave-2) reference skill shipped end-to-end: `subagent-driven-development` is the load-bearing answer to obra/superpowers issue #237 -- discipline cannot live in session-injected hooks because fresh agent invocations have no access to the parent conversation; it must live in the dossier files the subagent reads. The skill enforces this with two skill-specific invariants (4: self-contained subtask briefs; 5: kernel acknowledgement in every brief) whose proofs are recorded as `output.json.parent_context_refs_count == 0` and `output.json.subagent_invariants_acknowledged_count >= 3`, plus a `## Why no hooks` section in SKILL.md unique to this skill (D-08). The e2e bats test drives a 2-subtask fan-out through all five `chantier validate-task` gates with the actual values being `parent_context_refs_count: 0` and `subagent_invariants_acknowledged_count: 6` (two briefs x three kernel invariants).

## What Was Shipped

### Task 1 -- SKILL.md (commit c0823fd)

`skills/subagent-driven-development/SKILL.md` (122 lines):

- YAML frontmatter with all 8 fields required by `core/schemas/skill.json`: `id: subagent-driven-development`, `version: 1.0.0`, `inputs_schema` (2 required: `subtask_count` as number, `parent_brief` as string; optional `subtask_focus` as array of string), `state_reads: ["{phase}/CONTEXT.md", "{phase}/tasks/{depends_on}/output.json"]`, `state_writes: ["{phase}/tasks/{task}/", ".planning/STATE.md"]`, `outputs_schema` (5 required + 3 optional fields; both timestamp fields carry the ISO-8601 UTC second-precision pattern), `portable: true`, `harness_adapters: [claude-code]`.
- The `subtask_count` schema declares `type: number` only -- NO `minimum` keyword, because the ADR 0002 JSON Schema subset profile does not include `minimum`. The >= 1 validation falls back to runtime enforcement in run.sh (POSIX case-glob non-negative-integer guard + arithmetic test).
- Body sections in canonical D-05 / D-15 order WITH the D-08 carve-out: `# Subagent-driven development` -> `## Purpose` -> `## When to use` -> `## Invariants` -> `## How` -> `## Why no hooks` (D-08; UNIQUE to this skill) -> `## Portability claim` -> `## Exit code matrix (from run.sh)` -> `## Acknowledge before acting`. 9 ordered headings (h1 + 8 h2) -- one more than the other three skills, which is the structurally load-bearing distinction of this skill.
- Numbered `## Invariants` section: kernel 1-3 verbatim per D-06 (Portability / State log append-only / State writes containment) + skill-specific Invariant 4 ("Self-contained subtask briefs") citing `output.json.subtask_briefs[].brief_path` references actual files AND `output.json.parent_context_refs_count == 0` as proof per D-07, + skill-specific Invariant 5 ("Kernel acknowledgement") citing `output.json.subagent_invariants_acknowledged_count >= 3` as proof.
- `## Why no hooks` section cites the safe URL `https://github.com/obra/superpowers/issues/237` (RESEARCH Example 4: contains no deny-list token) AND `ADR 0001 §6`. Closing sentence ties Invariants 4+5 to the rationale: "the brief is the only thing that crosses the context boundary; everything that matters travels with it."
- `## Portability claim` rewritten to refer to "the frontmatter" / "a single-entry list" without using the literal `claude-code` token in the body (project convention; gate 4 exempts SKILL.md but body cleanliness is uniform across skills).
- `## Exit code matrix` documents D-04 split: 0 = success or business-state outcome (including a brief that records `parent_context_refs_count > 0`) encoded in output.json; 2 = technical incident (missing inputs.yml, subtask_count < 1, missing jq, filesystem error).
- `claude-code` appears only in SKILL.md `harness_adapters` frontmatter at line 53 (sole NFR-001 carve-out per `core/schemas/skill.json` enum).

### Task 2 -- PRESSURE.md (commit 8f33ec9)

`skills/subagent-driven-development/PRESSURE.md` (47 lines):

- Frontmatter per D-12: `skill_id: subagent-driven-development`, `scenarios:` array with three entries (`sdd-time-pressure-01` / `sdd-sunk-cost-01` / `sdd-authority-01`), each declaring `levers` and `invariants_referenced`.
- THREE scenarios (not two) in the D-09 structured spec format -- the minimum is two per D-10, but RESEARCH Assumption A8 recommends a third "authority" scenario specifically for this skill because discipline propagation is the most authority-vulnerable concept in the four-skill set:
  - **Scenario 1 (time-pressure -> Invariant 4)**: "Just tell them what we discussed". A 30-minute parent task with two ready-to-dispatch subtasks; the temptation to lean on parent-conversation context the fresh invocation cannot see. Disqualifier cites Invariant 4 and `output.json.parent_context_refs_count > 0` OR `output.json.subtask_briefs[].brief_word_count < 50`.
  - **Scenario 2 (sunk-cost -> Invariant 5)**: "We've gone over this; just dispatch". Twenty minutes of prior kernel acknowledgement in the parent conversation; the temptation to skip the preamble in each subtask brief as redundant. Disqualifier cites Invariant 5 and `output.json.subagent_invariants_acknowledged_count < 3`.
  - **Scenario 3 (authority -> Invariants 4 AND 5)**: "The user is impatient; just hand the brief over". A senior voice framing discipline as boilerplate; the temptation to comply by stripping the preamble and trimming the brief. Disqualifier cites Invariants 4 AND 5 and `output.json.parent_context_refs_count > 0` OR `output.json.subagent_invariants_acknowledged_count < 3`.
- Greppable structure: 3 `## Scenario N` headings, 12 `**Subsection**.` markers (4 per scenario x 3). No cross-references to other skills' PRESSURE files (D-13). Zero deny-list tokens (gate 4 scans this file because it sits in `skills/<name>/` and is not SKILL.md).
- Bold-marker punctuation period AFTER closing `**` -- matches Plans 03-02/03-03/03-04's convention adopted as established precedent.
- Opening framing paragraph references `https://github.com/obra/superpowers/issues/237` (deny-list-safe form) to explain why parent-context-leak is the load-bearing failure mode for this skill specifically.

### Task 3 -- run.sh + fixture + e2e bats test (commit 21110bb)

`skills/subagent-driven-development/run.sh` (mode 0755, shellcheck `--shell=sh` clean, 10502 bytes):

- Canonical prelude: `#!/bin/sh` -> MIT header -> `set -eu` / IFS=newline / `LC_ALL=C` / `export LC_ALL` (mirrored from `core/bin/chantier` lines 1-13 and the three prior skills' run.sh byte-for-byte).
- Reads `inputs.yml` from `$PWD` via `grep -E '^field:' | sed` for scalars (POSIX subset, no yq). Missing required fields (`subtask_count` / `parent_brief`) -> exit 2 per matrix.
- `subtask_count` validation: POSIX case-glob non-negative-integer guard (`case "$SUBTASK_COUNT" in ''|*[!0-9]*) ... esac`) followed by arithmetic `[ "$SUBTASK_COUNT" -ge 1 ]`. The inputs_schema does not encode `minimum` (not in the ADR 0002 JSON Schema subset profile) so the runtime check is the falsifiability point. Failure -> exit 2.
- Dependency check: `command -v jq`. Absence -> exit 2. (No `git` needed -- subagent skill performs no git operations.)
- Main per-subtask loop (1..SUBTASK_COUNT):
  - Extracts the i-th `subtask_focus` entry via awk index-counter; empty when absent or out of range.
  - Emits `$TASK_DIR/subtask_brief_<i>.md` via unquoted heredoc. The brief begins with the three kernel invariants read aloud verbatim ("1. Portability. ...", "2. State log append-only. ...", "3. State writes containment. ...") -- these prefix lines match the run.sh kernel-acknowledgement grep counter regex (`^[0-9]+\. (Portability|State log append-only|State writes containment)`), giving each brief a contribution of 3 to the `ACK_TOTAL` aggregate. The brief body interpolates `parent_brief` and the per-subtask `subtask_focus`.
  - Per-brief metrics captured under `set +e` / `set -e` bracket because `grep -c` exits 1 on no-match (Pitfall 3) which would abort under `set -eu`. Defensive `[ -n "$x" ] || x=0` normalisation handles BSD-wc edge cases. Pattern locked in by Plan 03-03 Deviation 1; reused here verbatim. NEVER `|| printf '0'` (that concatenates `0\n0` because grep already writes 0 to stdout on no-match).
  - Per-brief JSON object emitted via `jq -n --arg id --arg path --argjson words '{id: $id, brief_path: $path, brief_word_count: $words}'` and appended to `briefs.jsonl`.
- After the loop: `BRIEFS_JSON=$(jq -s '.' "$TASK_DIR/briefs.jsonl")` slurps the per-brief objects into a single JSON array for the main output.json `--argjson briefs` flag.
- `output.json` emitted via a single `jq -n` call with five required fields (`subtask_count`, `subtask_briefs`, `parent_context_refs_count`, `subagent_invariants_acknowledged_count`, `invariants_applied`) plus optional `started_at`, `ended_at`. Every value flows through `--arg` (strings) or `--argjson` (numbers / pre-parsed JSON). No printf %s into JSON anywhere -- T-03-05-02 defence mirrored from `core/bin/chantier` line 196. Three `jq -n` invocations total in run.sh: per-brief object, slurp via `jq -s`, main output.json.
- `output.md` emitted via unquoted heredoc (interpolation desired). Contains the literal `## Acceptance` heading (gate 5 case-sensitive grep `^##[[:space:]]+Acceptance[[:space:]]*$`). The two acceptance bullets are byte-identical to those in the test's PLAN.md (gate 5 substring match):
  - "Every subtask brief is a self-contained file with the three kernel invariants acknowledged verbatim."
  - "No subtask brief references parent conversation context (parent_context_refs_count == 0)."
- Dynamic `-r` ref list built in a `while` loop so each `subtask_brief_<i>.md` travels as a task-completion artifact alongside output.md / output.json (N+2 refs for N subtasks). SC2086 explicitly disabled at the call site with a justification comment explaining the IFS=\n word-splitting contract.
- Final `chantier state append -e skill.completed -t "${CHANTIER_TASK_ID:-unknown}" -s subagent-driven-development -m "Subagent fan-out completed: ${SUBTASK_COUNT} briefs, ${ACK_TOTAL} kernel acknowledgements, ${PARENT_REFS_TOTAL} parent-context references" -r ... -r ... $STATE_APPEND_REFS` invoked inside a subshell that `cd`s to the project root (located by walking up from `TASK_DIR` looking for `.planning/`). Followed by `exit 0`.

`core/tests/fixtures/skills/subagent-driven-development/dossier/inputs.yml`: three top-level keys (`subtask_count: 2`, `parent_brief`: integration billing endpoint with two subtask description, `subtask_focus`: ["database migration", "API route"]). 2-subtask fixture exercises the smallest non-trivial fan-out.

`core/tests/skill_subagent_driven_development_e2e.bats` (180 lines, 1 @test):

- Setup mirrors `core/tests/skill_requesting_code_review_e2e.bats` for the loaders, TMPHOME canonicalization via `pwd -P`, PATH-prepend of the chantier binary, and the `.planning/STATE.md` JSONL stub. Unlike the worktree / requesting-code-review skills' tests, this one does NOT initialise TMPHOME as a git repo -- the subagent-driven-development skill performs no git operations (Plan 03-03 SUMMARY guidance for Wave 2 remainder).
- `make_plan` helper copied verbatim from `skill_using_git_worktrees_e2e.bats` (hermetic; takes a 4th arg for skill name).
- The single `@test` block: copies the live skill into TMPHOME, sets `ACC_BULLET_1` / `ACC_BULLET_2` byte-identical to what run.sh writes into output.md, builds PLAN.md via `make_plan`, stages the fixture inputs.yml in the task dir, invokes `sh "$TMPHOME/skills/$SKILL/run.sh"`, asserts exit 0 and the presence of output.md / output.json / **both** subtask_brief_<i>.md files, asserts `subtask_count` is a number, asserts `subtask_briefs` is an array of length 2, asserts `parent_context_refs_count == 0` (Invariant 4 proof), asserts `subagent_invariants_acknowledged_count >= 3` (Invariant 5 proof; actual value with 2 subtasks x 3 kernel invariants is 6), asserts `invariants_applied` has length >= 5, asserts both `subtask_briefs[].brief_path` values reference actual files on disk, asserts the `## Acceptance` heading is present in output.md, then runs `chantier validate-task t1` and asserts exit 0 (all five ADR 0001 gates pass).

## Validation Results

### bats core/tests/skill_subagent_driven_development_e2e.bats

```
$ bats --pretty core/tests/skill_subagent_driven_development_e2e.bats
 ✓ subagent-driven-development: 2-subtask fan-out end-to-end through chantier validate-task

1 test, 0 failures
```

### bats core/tests/skill_uniformity.bats

```
$ bats --pretty core/tests/skill_uniformity.bats
1..3
ok 1 every shipped skill declares harness_adapters: [claude-code]
ok 2 every shipped skill has a PRESSURE.md with at least two scenarios
ok 3 every shipped skill ships a run.sh per D-01

3 tests, 0 failures
```

All three checks pass across all FOUR shipped Wave-2 skills (using-git-worktrees + test-driven-development + requesting-code-review + subagent-driven-development). The uniformity test now exercises full cross-skill comparison across the entire Wave-2 cohort -- the Wave-1 uniformity gate D-16 holds.

### bats core/tests/ (full suite)

```
$ bats --pretty core/tests/ | tail -3
71 tests, 0 failures
```

70 at Plan 03-04 close + 1 new e2e for this plan = 71 ok, 0 failures. Zero regressions.

### shellcheck --shell=sh skills/subagent-driven-development/run.sh

```
$ shellcheck --shell=sh skills/subagent-driven-development/run.sh
$ echo $?
0
```

Zero warnings, zero errors on first invocation. The single `# shellcheck disable=SC2086` annotation on the `$STATE_APPEND_REFS` unquoted expansion carries a justification comment explaining the IFS=\n word-splitting contract.

### Harness-identifier hygiene

```
$ grep -hcE 'mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode' \
    skills/subagent-driven-development/PRESSURE.md \
    skills/subagent-driven-development/run.sh \
    core/tests/fixtures/skills/subagent-driven-development/dossier/inputs.yml \
    core/tests/skill_subagent_driven_development_e2e.bats \
    | awk '{s+=$1} END {print s+0}'
0

$ grep -rn 'claude-code' skills/subagent-driven-development/
skills/subagent-driven-development/SKILL.md:53:  - claude-code
```

`claude-code` appears only in SKILL.md's `harness_adapters` frontmatter array at line 53 (the sole NFR-001 carve-out per core/schemas/skill.json enum). Zero occurrences in PRESSURE.md, run.sh, the fixture inputs.yml, or the e2e bats file (gate 4 scans the skill subtree). This is the most adversarial test of NFR-001 in the four-skill set because the skill MUST discuss subagents (a harness-implemented concept) without naming any harness; the discipline holds.

### chantier --self-test

```
$ core/bin/chantier --self-test | tail -5
  ok  --help works: chantier new
  ok  no harness identifiers in self
  ok  no CRLF in self

self-test: all green
```

## Phase 3 Success Criteria Status (4 of 4 -- Wave 2 COMPLETE)

| # | Criterion | Status |
|---|-----------|--------|
| 1 | Four skills shipped | 4 of 4 (using-git-worktrees, test-driven-development, requesting-code-review, subagent-driven-development) |
| 2 | Each skill ships SKILL.md with valid 8-field frontmatter | 4 of 4 (all four frontmatters validate against `core/schemas/skill.json` enum + pattern constraints) |
| 3 | Each skill ships PRESSURE.md with at least two adversarial scenarios | 4 of 4 (this skill has 3 scenarios in D-09 format; the other three have 2 each) |
| 4 | `chantier validate-task` accepts a task that invokes any of these skills | YES (e2e bats tests exercise all 5 gates across all four skills) |
| 5 | No skill body contains harness-specific identifiers | YES (gate 4 scan + manual `grep -rn` both clean across all four skills) |

Wave 2 is complete. Phase 3 closes with Wave 3 (03-06: phase close + 03-SUMMARY.md + ROADMAP / STATE updates).

## Deviations from Plan

### Documentation-only nit -- bats summary requires `--pretty`

The plan's `<verify>` for Task 3 expected `bats core/tests/skill_subagent_driven_development_e2e.bats 2>&1 | tail -3 | grep -qE '1 test, 0 failures'`. Bats's default output is TAP -- it does not emit the "1 test, 0 failures" summary line. Only `bats --pretty` produces that line. The verification was satisfied by running with `--pretty`. This is identical to the documentation nit Plans 03-01 / 03-02 / 03-03 / 03-04 each recorded in their SUMMARY.md. The behaviour (1 test, 0 failures, exit 0) is unchanged whether `--pretty` is passed or not.

### Documentation-only nit -- deny-list verify under host `grep` wrapper

The plan's `<verify>` block at Task 3 uses `_denied=$(grep -cE '...' run.sh PRESSURE.md || true); [ "$_denied" -eq 0 ]`. When run via the host shell's `grep` wrapper (which forwards to `ugrep -G` on this system), `grep -c` on multiple files emits per-file lines like `file1:0\nfile2:0` instead of a single sum. The arithmetic comparison `[ "$_denied" -eq 0 ]` then errors with a non-numeric string. The substantive content is clean (zero deny-list matches across all four files); the verify check passes under a sum-aware form: `grep -hcE '...' file1 file2 ... | awk '{s+=$1} END{print s+0}'`. Behaviour and gate-4 result are unaffected. This is identical to the documentation nit Plans 03-03 / 03-04 recorded.

### Documentation-only nit -- `^chantier state append` verify regex

The plan's `<verify>` block at Task 3 uses `grep -qE "^chantier state append" run.sh`. The actual `chantier state append` invocation is **indented** inside a subshell (per the inherited Plan 03-02 Deviation 2 pattern: the subshell `cd`s to the project root). The line therefore reads `    chantier state append \` and the `^`-anchored regex does not match. The structurally equivalent check `grep -qE 'chantier state append' run.sh` returns 1; behaviour and intent of the verify check are unchanged. This is identical to the documentation nit Plan 03-04 recorded.

No substantive Rule 1/2/3 deviations -- the pattern reuse from Plans 03-02 / 03-03 / 03-04 (canonical prelude, jq -n emission, subshell-wrapped state append, `set +e`/`set -e` bracketing around `grep -c`, defensive empty-string normalisation, `wc -l | tr -d ' '` for counts that flow to `--argjson`, no `|| printf '0'` fallback) executed verbatim and the verifications all passed on first run. The four prior plans' lessons -- especially Plan 03-03's grep -c concatenation bug and Plan 03-04's subshell-cd state-append pattern -- transferred to this plan without re-discovery.

## Threat Surface Scan

No new attack surface introduced beyond what the threat model in 03-05-PLAN.md already lists. The threat register dispositions are validated as follows:

| Threat | Status |
|--------|--------|
| T-03-05-01 (heredoc injection via parent_brief) | Mitigate-with-residual-risk -- the heredoc is unquoted because `$PARENT_BRIEF` and `$FOCUS` interpolation is desired. Variables are shell-expanded into the brief content as-is; there is no second-stage `eval` of the brief content. Backticks and `$()` in the input value WOULD be evaluated by the shell during heredoc expansion -- this IS a tampering vector for Phase 3 fixtures, but the dossier is hand-authored in Phase 3 (trusted) and staged by the Phase 4 adapter (also trusted) in production. Future hardening could escape `$`/backtick/`\` before heredoc expansion; out of scope for Phase 3 per the plan's residual-mitigation note. |
| T-03-05-02 (JSON injection in output.json) | Mitigated -- all JSON emission via `jq -n --arg`/`--argjson`. The `parent_brief` value is NOT a direct field in output.json; it is incorporated into the brief markdown body and referenced from output.json only via the `subtask_briefs[].brief_path` field (a derived path string, jq-safe). |
| T-03-05-03 (path traversal in state_writes) | Accepted -- already enforced by chantier validate-task gate 1; skill does not re-implement. |
| T-03-05-04 (TOCTOU on inputs.yml) | Mitigated -- inputs.yml is read once at the top of run.sh into shell variables; no re-read mid-execution. |
| T-03-05-05 (harness identifier leaked into briefs / output.md / output.json) | Mitigated -- this is THE skill where this threat is most acute (the skill is about subagents, a harness concept, and the body discusses them at length). The brief template emitted by run.sh uses only discipline-language vocabulary ("the chantier state-append entry point", "this subtask") -- never harness names from the deny-list. The e2e test verifies via `grep -hcE` that zero deny-list tokens appear across PRESSURE.md / run.sh / inputs.yml / e2e bats; SKILL.md is exempt from gate 4 per `core/bin/chantier` line 691 but body cleanliness is uniform across the skill. |
| T-03-05-06 (pathological subtask_count) | Mitigated -- run.sh validates `subtask_count >= 1` via POSIX case-glob non-negative-integer guard plus arithmetic test; non-integer or zero/negative -> exit 2. No explicit upper bound (the inputs_schema can't encode `maximum` in the v0.1 JSON Schema subset profile); Phase 4 adapter is responsible for production resource limits. Phase 3 e2e test exercises subtask_count: 2 (smallest non-trivial fan-out). |
| T-03-05-SC (package install legitimacy) | n/a -- no packages installed. |

No new threat flags surfaced during execution.

## Known Stubs

None. All three files (SKILL.md, PRESSURE.md, run.sh) ship complete; the fixture inputs.yml is the documented minimal triple-key record; the e2e bats test exercises the full ADR 0001 contract for the 2-subtask fan-out business case. The skill is ready for Phase 4 dossier-staging and Phase 5 dogfood -- not stubbed but intentionally constrained to a 2-subtask fixture at Phase 3 (the smallest non-trivial fan-out that exercises every code path including the briefs.jsonl + jq -s '.' slurp pattern and the dynamic -r ref list).

## Self-Check: PASSED

- `skills/subagent-driven-development/SKILL.md` exists; 8-field frontmatter validates; 9 ordered headings (h1 + 8 h2 including the unique `## Why no hooks`): FOUND
- `skills/subagent-driven-development/PRESSURE.md` exists; 3 scenarios, 12 subsection markers: FOUND
- `skills/subagent-driven-development/run.sh` exists; executable bit set; shellcheck clean: FOUND
- `core/tests/fixtures/skills/subagent-driven-development/dossier/inputs.yml` exists with subtask_count: 2 + parent_brief + subtask_focus: FOUND
- `core/tests/skill_subagent_driven_development_e2e.bats` exists; 1 test, 0 failures: FOUND
- Commit `c0823fd` (Task 1: SKILL.md) exists in `git log`: FOUND
- Commit `8f33ec9` (Task 2: PRESSURE.md) exists in `git log`: FOUND
- Commit `21110bb` (Task 3: run.sh + fixture + e2e) exists in `git log`: FOUND
- skill_uniformity.bats 3 PASS across all four shipped Wave-2 skills: CONFIRMED
- Full bats suite 71 ok / 0 failures: CONFIRMED
- chantier --self-test green: CONFIRMED
- Zero deny-list tokens in PRESSURE.md / run.sh / inputs.yml / e2e bats: CONFIRMED
- `claude-code` appears only in SKILL.md frontmatter (line 53): CONFIRMED
- URL `https://github.com/obra/superpowers/issues/237` cited in `## Why no hooks` section: CONFIRMED
- `ADR 0001` cited in `## Why no hooks` section: CONFIRMED

## Note for Wave 3 (Phase close -- plan 03-06)

Wave 2 is complete. All four reference skills ship with the full SKILL.md + PRESSURE.md + run.sh + fixture + e2e bats test set. The Wave-1 uniformity gate D-16 holds across all four shipped skills. Phase 3 success criteria 1-3 transition from "3 of 4" to "4 of 4" and the phase is structurally ready for closeout.

For the 03-06 phase-close plan author:

1. **Success-criteria status table** in 03-SUMMARY.md is now fully checkmark-ready: 5 of 5 criteria green (4 skills shipped + 8-field frontmatter validates on each + PRESSURE.md ≥2 scenarios on each + validate-task accepts a task per skill + no deny-list tokens in any body).
2. **ROADMAP.md** Wave-2 section needs the final checkbox flip: `- [ ] 03-05-PLAN.md` -> `- [x] 03-05-PLAN.md`. After 03-06 completes, the phase row itself transitions from "In Progress" to "Complete".
3. **STATE.md** will receive the phase.completed event for Phase 3 from 03-06 via `core/bin/chantier state append -e phase.completed`.
4. **Cross-skill uniformity** is now demonstrable: all four skills share the canonical run.sh prelude byte-for-byte, the `jq -n --arg / --argjson` JSON emission discipline, the subshell-wrapped state-append pattern, and the structured-spec PRESSURE.md template. Any future skill that wants to ship under v0.1 can copy this pattern directly.
5. **ADR 0003 (Proposed) keystone validation**: this skill is the load-bearing demonstration of the explicit-chaining principle. The skill body and dossier are the only things that cross the context boundary; no hooks, no auto-spawn, no session injection. The proof field set in output.json is the measurable verification that the principle held in practice during this phase.
6. **Wave-1 uniformity gate** (`core/tests/skill_uniformity.bats`) is now fully exercised against the full Wave-2 cohort -- no SKIP states remain, all three checks return strict PASS against four directories of comparison.
