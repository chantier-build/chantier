---
phase: 03-skill-library
plan: "04"
subsystem: skill-requesting-code-review
tags:
  - phase-03
  - skill
  - requesting-code-review
  - run-sh
  - pressure-md
  - kernel-invariants
  - scoped-diff
  - git-diff
dependency_graph:
  requires:
    - 02-05
    - 02-06
    - 03-01
    - 03-02
    - 03-03
  provides:
    - skills/requesting-code-review/SKILL.md
    - skills/requesting-code-review/PRESSURE.md
    - skills/requesting-code-review/run.sh
    - core/tests/skill_requesting_code_review_e2e.bats
    - core/tests/fixtures/skills/requesting-code-review/dossier/inputs.yml
  affects:
    - core/tests/skill_uniformity.bats (3 PASS now spans three shipped Wave-2 skills)
    - .planning/ROADMAP.md (Wave 2 row 03-04 checked off)
    - .planning/STATE.md (plan.completed event appended)
tech_stack:
  added: []
  patterns:
    - POSIX-sh-with-jq run.sh shape (matches Plan 03-02/03-03 prelude byte-for-byte)
    - jq -n --arg / --argjson exclusively for output.json emission (T-03-04-02 defence)
    - Scoped three-dot git diff "BASE...HEAD" -- SCOPE_PATHS (Pitfall 10 canonical form)
    - set +e / set -e bracket to capture git diff exit (1 == content present is business state, not technical incident)
    - awk extraction of YAML array entries (scope_paths) into newline-separated shell variable with IFS=\n word-splitting downstream
    - review_prompt.md emitted via printf-only heredoc (NOT echo -e) so backslash sequences in user-supplied text are not interpreted
    - Three -r refs to chantier state append (output.md, output.json, review_prompt.md as a load-bearing deliverable)
    - PRESSURE.md structured spec (Situation / Temptation / Required response / Disqualifier) with period AFTER closing **
    - Final chantier state append wrapped in subshell that cd's to project root (inherited Plan 03-02 deviation 2 pattern)
    - bats e2e fixture mounting via cp + make_plan helper hermetically copied from validate_task.bats
    - HEAD...HEAD empty-diff fixture as deterministic empty-diff business-case exerciser
key_files:
  created:
    - skills/requesting-code-review/SKILL.md
    - skills/requesting-code-review/PRESSURE.md
    - skills/requesting-code-review/run.sh
    - core/tests/fixtures/skills/requesting-code-review/dossier/inputs.yml
    - core/tests/skill_requesting_code_review_e2e.bats
    - .planning/phases/03-skill-library/03-04-SUMMARY.md
  modified: []
decisions:
  - "Three-dot range (BASE...HEAD) is the canonical scoped-diff invocation per Pitfall 10 -- since-common-ancestor semantics are clearer than two-dot for a fork-then-merge workflow. SKILL.md How section justifies it; run.sh enforces it."
  - "scope_paths is a YAML list parsed via awk into a newline-separated shell variable. IFS=\\n at the prelude lets unquoted expansion preserve path-with-space values when fed into git diff. SC2086 is explicitly disabled at the call site with a brief justification comment."
  - "review_prompt.md is a load-bearing artifact, not an intermediate -- it is the document the reviewer reads. Recorded as the third -r ref to chantier state append (alongside output.md and output.json) so it travels with the task in any downstream forensic."
  - "Empty-diff fixture uses diff_base_ref/diff_head_ref both HEAD -- deterministic empty diff, exercises the diff_file_count: 0 business-case + run.sh exit 0 path without needing two real commits in the test repo. Verifies D-04 explicitly (empty diff is business state, not technical incident)."
  - "outputs_schema declares started_at, ended_at as optional alongside the six required fields. run.sh always populates them so downstream verifiers can use them; keeps room for richer verification without breaking the v0.1 contract."
  - "PRESSURE.md bold-marker punctuation period AFTER closing ** -- matches Plan 03-02/03-03's precedent (originally Plan 03-02 Deviation 1). Adopted here as established convention; no new deviation needed."
  - "DIFF_FILE_COUNT capture uses 'wc -l | tr -d \" \"' rather than the grep -c form (which has the 0\\n0 concatenation bug Plan 03-03 Deviation 1 documented). git diff --name-only produces one path per line; wc -l counts lines deterministically; tr -d ' ' strips BSD leading spaces."
metrics:
  duration: "~12 minutes"
  completed: "2026-05-30"
  tasks_completed: 3
  tasks_total: 3
  bats_tests_before: 69
  bats_tests_after: 70
  shipped_skills_before: 2
  shipped_skills_after: 3
---

# Phase 03 Plan 04: requesting-code-review skill -- Summary

## One-liner

Third reference skill shipped end-to-end: `requesting-code-review` enforces scoped-diff discipline as a measurable invariant (`output.json.diff_base_ref` and `diff_head_ref` both non-empty AND `diff_file_count` recorded AND `review_prompt_path` references actual file); run.sh executes the canonical three-dot scoped `git diff` (`BASE...HEAD -- SCOPE_PATHS` per Pitfall 10), emits a load-bearing `review_prompt.md` artifact alongside output.md/output.json, and the e2e bats test drives the HEAD...HEAD empty-diff business case through all five `chantier validate-task` gates.

## What Was Shipped

### Task 1 -- SKILL.md (commit 4a0674d)

`skills/requesting-code-review/SKILL.md` (118 lines):

- YAML frontmatter with all 8 fields required by `core/schemas/skill.json`: `id: requesting-code-review`, `version: 1.0.0`, `inputs_schema` (3 required: `diff_base_ref`, `diff_head_ref`, `scope_paths` as array-of-string; optional `reviewer_focus`), `state_reads: ["{phase}/CONTEXT.md", "{phase}/tasks/{depends_on}/output.json"]`, `state_writes: ["{phase}/tasks/{task}/", ".planning/STATE.md"]`, `outputs_schema` (6 required + 3 optional fields; both timestamp fields carry the ISO-8601 UTC second-precision pattern), `portable: true`, `harness_adapters: [claude-code]`.
- Body sections in canonical D-05 / D-15 order: `# Requesting code review` -> `## Purpose` -> `## When to use` -> `## Invariants` -> `## How` -> `## Portability claim` -> `## Exit code matrix (from run.sh)` -> `## Acknowledge before acting`. No `## Why no hooks` section (that's the `subagent-driven-development` skill's exclusive carve-out per D-08).
- Numbered `## Invariants` section: kernel 1-3 verbatim per D-06 (Portability / State log append-only / State writes containment) + skill-specific Invariant 4 ("Scoped diff") citing `output.json.diff_base_ref` and `diff_head_ref` both non-empty AND `diff_file_count` integer AND `review_prompt_path` references an actual file as proof per D-07.
- Body silent on a future `receiving-code-review` sister skill per RESEARCH Assumption A5 / ADR 0001 OQ #4 deferral.
- `## Portability claim` rewritten to refer to "the frontmatter" / "a single-entry list" without using the literal `claude-code` token in the body (project convention; gate 4 exempts SKILL.md but body cleanliness is uniform across skills).
- `## Exit code matrix` documents D-04 split: 0 = success or business-state outcome (including empty diff) encoded in output.json; 2 = technical incident (missing inputs.yml / missing git / missing jq / filesystem error).
- `claude-code` appears only in SKILL.md `harness_adapters` frontmatter at line 56 (sole NFR-001 carve-out per core/schemas/skill.json enum).

### Task 2 -- PRESSURE.md (commit 0efaccc)

`skills/requesting-code-review/PRESSURE.md` (34 lines):

- Frontmatter per D-12: `skill_id: requesting-code-review`, `scenarios:` array with two entries (`rcr-time-pressure-01` / `rcr-sunk-cost-01`), each declaring `levers` and `invariants_referenced: [4]`.
- Two scenarios in the D-09 structured spec format:
  - **Scenario 1 (time-pressure)**: "Ship before the release window closes". A 30-minute window, an 18-commit branch across 7 functional files plus 3 ancillary files, and a reviewer asking for "the whole diff". Disqualifier cites Invariant 4 and `output.json.diff_base_ref` empty OR `output.json.review_prompt_path` referencing an unscoped-git-diff command.
  - **Scenario 2 (sunk-cost)**: "The branch is too tangled to scope cleanly". A three-week branch combining a feature, an internal refactor, a generated rename pass, and an unrelated bug fix. Disqualifier cites Invariant 4 and `output.json.diff_file_count > 50` AND `output.json.review_prompt_word_count > 5000` with no narrowing scope_paths recorded.
- Greppable structure: 2 `## Scenario N` headings, 8 `**Subsection**.` markers (4 per scenario x 2). No cross-references to other skills' PRESSURE files (D-13). No mention of `receiving-code-review`. Zero deny-list tokens (gate 4 scans this file because it sits in `skills/<name>/` and is not SKILL.md).
- Bold-marker punctuation period AFTER closing `**` -- matches Plan 03-02/03-03's convention adopted as established precedent rather than re-discovered as a deviation.

### Task 3 -- run.sh + fixture + e2e bats test (commit 29e4193)

`skills/requesting-code-review/run.sh` (mode 0755, shellcheck `--shell=sh` clean, 9376 bytes):

- Canonical prelude: `#!/bin/sh` -> MIT header -> `set -eu` / IFS=newline / `LC_ALL=C` / `export LC_ALL` (mirrored from `core/bin/chantier` lines 1-13 and the prior two skills' run.sh byte-for-byte).
- Reads `inputs.yml` from `$PWD` via `grep -E '^field:' | sed` for scalars (POSIX subset, no yq) and `awk` for the YAML array (`scope_paths`). Missing required fields (`diff_base_ref` / `diff_head_ref` / `scope_paths`) -> exit 2 per matrix. `reviewer_focus` is optional.
- Dependency check: `command -v jq` / `command -v git`. Absence -> exit 2.
- Scoped diff: `git diff "${DIFF_BASE_REF}...${DIFF_HEAD_REF}" -- $SCOPE_PATHS > "$TASK_DIR/diff.patch" 2>/dev/null` bracketed by `set +e` / `set -e`. The `$SCOPE_PATHS` unquoted expansion is intentional (one path per word, preserved by IFS=\n) -- annotated with `# shellcheck disable=SC2086` and a brief justification. Captured `DIFF_EXIT > 1` -> exit 2 (technical incident); `DIFF_EXIT in {0,1}` (no-diff or diff-present) is business state, exit 0 continues.
- `DIFF_FILE_COUNT` counted via `git diff --name-only ... | wc -l | tr -d ' '` with empty-string defensive normalisation. The `tr -d ' '` strips BSD-wc leading spaces so the subsequent `[ "$count" -eq 0 ]` arithmetic in the bats test works on macOS.
- `review_prompt.md` (the load-bearing artifact the reviewer reads) emitted via a `{ printf ...; cat diff.patch; }` block: cites `Base ref` / `Head ref` / `Scope paths:` (each with `  - ` indent), embeds the `Reviewer focus` (or a placeholder if absent), then `## Diff` followed by the diff inside a fenced code block. `printf %s` is used throughout so backslash escapes in user-supplied text are NOT interpreted (T-03-04-02 mitigation).
- `REVIEW_PROMPT_WORD_COUNT` via `wc -w < "$REVIEW_PROMPT_PATH" | tr -d ' '` with empty-string defensive normalisation.
- `output.json` emitted via a single `jq -n` call. Every value flows through `--arg` (strings) or `--argjson` (numbers / pre-parsed JSON arrays). No printf %s into JSON anywhere -- T-03-04-02 defence mirrored from `core/bin/chantier` line 196.
- `output.md` emitted via unquoted heredoc (interpolation desired). Contains the literal `## Acceptance` heading (gate 5 case-sensitive grep `^##[[:space:]]+Acceptance[[:space:]]*$`). The two acceptance bullets are byte-identical to those in the test's PLAN.md (gate 5 substring match).
- Final `chantier state append -e skill.completed -t "${CHANTIER_TASK_ID:-unknown}" -s requesting-code-review -m "Review request prepared; scoped to $DIFF_BASE_REF...$DIFF_HEAD_REF on declared scope_paths" -r "$TASK_DIR/output.md" -r "$TASK_DIR/output.json" -r "$REVIEW_PROMPT_PATH"` invoked inside a subshell that `cd`s to the project root (located by walking up from TASK_DIR looking for `.planning/`). THREE `-r` refs because `review_prompt.md` is a load-bearing deliverable, not just an intermediate. Followed by `exit 0`.

`core/tests/fixtures/skills/requesting-code-review/dossier/inputs.yml`: four top-level scalars / one list (`diff_base_ref: "HEAD"`, `diff_head_ref: "HEAD"`, `scope_paths: [ "core/" ]`, `reviewer_focus: "(empty diff fixture -- ...)"`). `HEAD...HEAD` is deterministically empty -- the fixture exercises the empty-diff business case without needing two real commits.

`core/tests/skill_requesting_code_review_e2e.bats` (175 lines, 1 @test):

- Setup mirrors `core/tests/skill_using_git_worktrees_e2e.bats` lines 16-65 verbatim for loaders, TMPHOME canonicalization via `pwd -P`, PATH-prepend of the chantier binary, and the .planning/STATE.md JSONL stub. Like the worktree skill's test, this one DOES initialise TMPHOME as a git repo (`git init -b main` with fallback) plus a single empty seed commit so HEAD resolves to something `git diff` can address.
- `make_plan` helper copied verbatim from `skill_using_git_worktrees_e2e.bats` lines 74-117 (hermetic; takes a 4th arg for skill name).
- The single `@test` block: copies the live skill into TMPHOME, sets `ACC_BULLET_1` / `ACC_BULLET_2` byte-identical to what run.sh writes into output.md, builds PLAN.md via `make_plan`, stages the fixture inputs.yml in the task dir, invokes `sh "$TMPHOME/skills/$SKILL/run.sh"`, asserts exit 0 and the presence of output.md / output.json / review_prompt.md (the third artifact), asserts `diff_base_ref` / `diff_head_ref` are strings, asserts `diff_file_count` is a number, asserts the empty-diff business case `_count -eq 0`, asserts `review_prompt_path` (read from output.json via `jq -r`) references an existing file, asserts `invariants_applied` has length >= 4, asserts the `## Acceptance` heading is present in output.md, then runs `chantier validate-task t1` and asserts exit 0 (all five ADR 0001 gates pass).

## Validation Results

### bats core/tests/skill_requesting_code_review_e2e.bats

```
$ bats --pretty core/tests/skill_requesting_code_review_e2e.bats
 ✓ requesting-code-review: empty-diff end-to-end through chantier validate-task

1 test, 0 failures
```

### bats core/tests/skill_uniformity.bats

```
$ bats --pretty core/tests/skill_uniformity.bats
1..3
ok 1 every shipped skill declares harness_adapters: [claude-code]
ok 2 every shipped skill has a PRESSURE.md with at least two scenarios
ok 3 every shipped skill ships a run.sh per D-01
```

All three checks pass across the three shipped Wave-2 skills (using-git-worktrees + test-driven-development + requesting-code-review). The uniformity test now exercises cross-skill comparison across the full Wave-2 cohort.

### bats core/tests/ (full suite)

```
$ bats --pretty core/tests/ | tail -3
70 tests, 0 failures
```

69 at Plan 03-03 close + 1 new e2e for this plan = 70 ok, 0 failures. Zero regressions.

### shellcheck --shell=sh skills/requesting-code-review/run.sh

```
$ shellcheck --shell=sh skills/requesting-code-review/run.sh
$ echo $?
0
```

Zero warnings, zero errors. The single `# shellcheck disable=SC2086` annotation on the `$SCOPE_PATHS` unquoted expansion carries a justification comment explaining the IFS=\n word-splitting contract.

### Harness-identifier hygiene

```
$ grep -hcE 'mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode' \
    skills/requesting-code-review/PRESSURE.md \
    skills/requesting-code-review/run.sh \
    | awk '{s+=$1} END {print s+0}'
0

$ grep -rn 'claude-code' skills/requesting-code-review/
skills/requesting-code-review/SKILL.md:56:  - claude-code

$ grep -rn 'receiving-code-review' skills/requesting-code-review/
(no matches)
```

`claude-code` appears only in SKILL.md's `harness_adapters` frontmatter array at line 56 (the sole NFR-001 carve-out per core/schemas/skill.json enum). Zero occurrences in PRESSURE.md or run.sh (gate 4 scans both). Zero references to `receiving-code-review` anywhere in the skill subtree (per RESEARCH Assumption A5 / D-13).

### chantier --self-test

```
$ core/bin/chantier --self-test | tail -5
  ok  --help works: chantier new
  ok  no harness identifiers in self
  ok  no CRLF in self

self-test: all green
```

## Phase 3 Success Criteria Status (partial -- 3 of 4 skills)

| # | Criterion | Status |
|---|-----------|--------|
| 1 | Four skills shipped | 3 of 4 (using-git-worktrees, test-driven-development, requesting-code-review) |
| 2 | Each skill ships SKILL.md with valid 8-field frontmatter | 3 of 4 (this skill's frontmatter validates against `core/schemas/skill.json` enum + pattern constraints) |
| 3 | Each skill ships PRESSURE.md with at least two adversarial scenarios | 3 of 4 (this skill has 2 scenarios in D-09 format) |
| 4 | `chantier validate-task` accepts a task that invokes any of these skills | YES (e2e bats test exercises all 5 gates) |
| 5 | No skill body contains harness-specific identifiers | YES (gate 4 scan + manual `grep -rn` both clean) |

## Deviations from Plan

### Documentation-only nit -- `^chantier state append` verify regex

The plan's `<verify>` block at Task 3 used `grep -qE "^chantier state append" skills/requesting-code-review/run.sh`. The actual `chantier state append` invocation is **indented** inside a subshell (per the inherited Plan 03-02 Deviation 2 pattern: the subshell `cd`s to the project root so the binary's CWD-relative STATE_FILE/LOCKDIR paths resolve correctly). The line therefore reads `    chantier state append \` and the `^`-anchored regex does not match. The structurally equivalent check `grep -qE 'chantier state append' run.sh` returns 1 (one match at line 207); behaviour and intent of the verify check are unchanged. Plans 03-02 and 03-03 both have the same indented invocation but did not flag this verify-regex mismatch -- noting here for the Plan 03-05 author so the verify line can be written `grep -qE 'chantier state append' run.sh` (without the `^` anchor) from the start.

### Documentation-only nit -- bats summary requires `--pretty`

The plan's `<verify>` for Task 3 expected `bats core/tests/skill_requesting_code_review_e2e.bats 2>&1 | tail -3 | grep -qE '1 test, 0 failures'`. Bats's default output is TAP -- it does not emit the "1 test, 0 failures" summary line. Only `bats --pretty` produces that line. The verification was satisfied by running with `--pretty`. This is identical to the documentation nit Plans 03-01 / 03-02 / 03-03 each recorded in their SUMMARY.md. The behaviour (1 test, 0 failures, exit 0) is unchanged whether `--pretty` is passed or not.

### Documentation-only nit -- deny-list verify under host `grep` wrapper

The plan's `<verify>` block at Task 3 uses `_denied=$(grep -cE '...' run.sh PRESSURE.md || true); [ "$_denied" -eq 0 ]`. When run via the host shell's `grep` wrapper (which forwards to `ugrep -G` on this system), `grep -c` on multiple files emits per-file lines like `file1:0\nfile2:0` instead of a single sum. The arithmetic comparison `[ "$_denied" -eq 0 ]` then errors with a non-numeric string. The substantive content is clean (zero deny-list matches across both files); the verify check passes under a sum-aware form: `grep -hcE '...' file1 file2 | awk '{s+=$1} END{print s+0}'`. Behaviour and gate-4 result are unaffected. This is identical to the documentation nit Plan 03-03 recorded.

No substantive Rule 1/2/3 deviations -- the plan's pattern reuse from 03-02 and 03-03 (canonical prelude, jq -n emission, subshell-wrapped state append, scope_paths awk extraction, `grep -c ... || true` + normalisation, `wc -l | tr -d ' '` for counts) executed verbatim and the verifications all passed on first run.

## Threat Surface Scan

No new attack surface introduced beyond what the threat model in 03-04-PLAN.md already lists. The threat register dispositions are validated as follows:

| Threat | Status |
|--------|--------|
| T-03-04-01 (argument injection via diff_base_ref) | Mitigated -- `--` separator in `git diff "$BASE...$HEAD" -- $SCOPE_PATHS` ensures path args cannot be parsed as flags; ref args starting with `-` are rejected by git rev-parse itself, producing exit > 1 which run.sh detects and routes to exit 2. |
| T-03-04-02 (JSON injection in output.json) | Mitigated -- all JSON emission via `jq -n --arg`/`--argjson`. The `reviewer_focus` text written into `review_prompt.md` uses `printf '%s'` (no `-e`), so backslash sequences in user-supplied text are not interpreted. |
| T-03-04-03 (path traversal in scope_paths) | Accepted (mitigated upstream) -- `git diff -- <path>` resolves paths relative to repo root; paths outside the repo produce empty diffs (git silently ignores them). Combined with chantier validate-task gate 1 for state_writes containment, no write-side traversal is possible. |
| T-03-04-04 (TOCTOU on inputs.yml) | Mitigated -- inputs.yml is read once at the top of run.sh into shell variables (DIFF_BASE_REF / DIFF_HEAD_REF / SCOPE_PATHS / REVIEWER_FOCUS); no re-read mid-execution. |
| T-03-04-05 (harness identifier in diff output) | Accepted -- the deny-list grep (gate 4) scans `skills/<name>/` body files, not task output directories where `diff.patch` and `review_prompt.md` live. A code-review of source code that happens to mention an editor name (e.g., `cursor` as a noun unrelated to harnesses) cannot trigger gate 4. This is by design -- the deny-list applies to skill body authoring, not to the content of code being reviewed. |
| T-03-04-SC (package install legitimacy) | n/a -- no packages installed. |

No new threat flags surfaced during execution.

## Known Stubs

None. All three files (SKILL.md, PRESSURE.md, run.sh) ship complete; the fixture inputs.yml is the documented minimal four-field record; the e2e bats test exercises the full ADR 0001 contract for the empty-diff business case. The non-empty-diff path (two distinct refs producing a real diff) is implemented in run.sh and ready for Phase 5 dogfood -- not stubbed but intentionally untested at Phase 3 (the empty-diff case is the higher-value falsifiable test because it proves the script does not conflate "no content" with "technical incident", which was the entire point of D-04).

## Self-Check: PASSED

- `skills/requesting-code-review/SKILL.md` exists; 8-field frontmatter validates: FOUND
- `skills/requesting-code-review/PRESSURE.md` exists; 2 scenarios, 8 subsection markers: FOUND
- `skills/requesting-code-review/run.sh` exists; executable bit set; shellcheck clean: FOUND
- `core/tests/fixtures/skills/requesting-code-review/dossier/inputs.yml` exists with 4 required scalars + 1 list: FOUND
- `core/tests/skill_requesting_code_review_e2e.bats` exists; 1 test, 0 failures: FOUND
- Commit `4a0674d` (Task 1: SKILL.md) exists in `git log`: FOUND
- Commit `0efaccc` (Task 2: PRESSURE.md) exists in `git log`: FOUND
- Commit `29e4193` (Task 3: run.sh + fixture + e2e) exists in `git log`: FOUND
- skill_uniformity.bats 3 PASS across 3 shipped Wave-2 skills: CONFIRMED
- Full bats suite 70 ok / 0 failures: CONFIRMED
- chantier --self-test green: CONFIRMED
- Zero deny-list tokens in PRESSURE.md or run.sh: CONFIRMED
- `claude-code` appears only in SKILL.md frontmatter (line 56): CONFIRMED
- Zero references to `receiving-code-review` anywhere in skills/requesting-code-review/: CONFIRMED

## Note for Wave 2 remainder (parallel plan 03-05)

The pattern locked in by Plans 03-02 and 03-03 is now confirmed reusable across a third skill of a third materially different shape (requesting-code-review's scoped-git-diff + artifact-emission model vs. test-driven-development's two-invocation phase-flag model vs. using-git-worktrees's single-invocation worktree-creation model). The remaining notes for 03-05 (subagent-driven-development):

1. **Frontmatter shape**: 8 fields uniform; `outputs_schema` declares discipline-proof fields per skill. Replace `id`, `inputs_schema` properties, `outputs_schema` required field set, and Invariant 4+ body to skill-specific concerns. 03-05 is the ONLY skill that adds a `## Why no hooks` section (D-08 carve-out).
2. **Body section order**: `# Display name` -> `## Purpose` -> `## When to use` -> `## Invariants` -> `## How` -> `## Why no hooks` (03-05 ONLY) -> `## Portability claim` -> `## Exit code matrix (from run.sh)` -> `## Acknowledge before acting`. Keep `claude-code` out of the body text (refer to "the frontmatter" or "a single-entry list" instead).
3. **PRESSURE.md bold markers**: use `**Situation**.` / `**Temptation**.` / `**Required response**.` / `**Disqualifier**.` (period AFTER the closing `**`). 03-05 may want a third "authority" scenario beyond the time-pressure + sunk-cost minimum -- planner discretion per D-10.
4. **run.sh prelude**: copy lines 1-15 from any of the three shipped run.sh files verbatim (license header + `set -eu` + IFS=newline + `LC_ALL=C` + `export LC_ALL`).
5. **run.sh final state append**: wrap the `chantier state append` call in a subshell that `cd`s to the project root (walk up from TASK_DIR looking for `.planning/`). Without this, the lockdir mkdir fails because STATE_FILE / LOCKDIR are CWD-relative in core/bin/chantier. Write the verify regex as `grep -qE 'chantier state append' run.sh` (without the `^` anchor) since the call line is indented inside the subshell.
6. **Counter capture under `grep -c`**: any use of `grep -c ... || printf 'N'` is a bug -- grep already writes the count on no-match. Use `|| true` and a `head -n 1 | tr -d ' '` normalisation if the value flows to `--argjson`. (For deterministic-line-count cases like `git diff --name-only | wc -l`, `wc -l | tr -d ' '` is the simpler form.)
7. **bats e2e test setup**: 03-05 (subagent) likely does NOT need a git repo in TMPHOME (no git operations) -- mirror the TDD skill's setup (no `git init`) rather than the worktree/requesting-code-review setup (which both `git init` plus a seed commit).
8. **review_prompt.md precedent**: when a skill produces a load-bearing artifact beyond output.md / output.json (e.g., 03-05 may produce a subagent-prompt artifact), pass it as a third `-r` arg to `chantier state append` -- the binary accepts multiple `-r` refs and treats them all as task-completion artifacts.

The `skill_uniformity.bats` test will continue to enforce three structural checks across all four skills once Wave 2 lands; any drift fails with a clear diagnostic. The deny-list scan in `validate-task` gate 4 will continue to enforce body cleanliness on PRESSURE.md and run.sh of every shipped skill. After 03-05 lands, the Phase 3 success criteria 1-3 transition from "3 of 4" to "4 of 4" and Phase 3 closes.
