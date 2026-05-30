---
phase: 05-dogfood-e2e
plan: 02
subsystem: adr-and-nfr-audits
tags: [adr, nfr-audits, bats, static-audit, surface-3, codification, phase-05]
requires:
  - docs/adr/0001-state-skill-contract.md (Surface 2 + Surface 3 -- the parent contract ADR 0004 codifies the mechanism of)
  - docs/adr/0002-runtime-binary-and-state-format.md (exit-code matrix referenced by ADR 0004 Decision)
  - docs/adr/0003-workflow-skill-design-principles.md (section-structure template ADR 0004 mirrors)
  - adapters/claude-code/run-task.sh (Section 5 propagation block -- the in-tree implementation ADR 0004 codifies)
  - core/tests/adapter_isolation.bats (NFR-001 deny-list pattern + HARNESS_DENY_LIST_CHECK marker convention)
  - core/bin/chantier:687 and :912 (the byte-identical _full literal source)
  - core/tests/skill_uniformity.bats (multi-@test bats file analog)
provides:
  - docs/adr/0004-surface-3-propagation.md (Proposed-status codification of the Surface 3 propagation contract per D-09)
  - core/tests/nfr_audits.bats (six-@test consolidated NFR-001..NFR-006 audit per D-05, D-06)
  - SC#4 promotion from claim to enforcement: every NFR has a dedicated @test block
  - Closes Phase 4 SUMMARY F1 finding (ADR 0004 codification reflex)
affects:
  - docs/adr/ (new file 0004-surface-3-propagation.md)
  - core/tests/ (new file nfr_audits.bats)
  - bats suite delta: 74/0 -> 80/0 (six new @tests, exactly one new file)
  - .planning/STATE.md (task.completed events for 05-02-01, 05-02-02; plan.completed for 05-02)
  - .planning/ROADMAP.md (Phase 5 progress row 1/4 -> 2/4)
tech-stack:
  added: []
  patterns:
    - ADR template section-mirroring (ADR 0003 -> ADR 0004 verbatim section structure; only prose changes)
    - Consolidated multi-@test bats file with self-contained per-test logic (no shared helpers)
    - Byte-identical deny-list literal across three sources (core/bin/chantier:687/:912, adapter_isolation.bats:46, nfr_audits.bats:32)
    - HARNESS_DENY_LIST_CHECK marker convention extended to NFR-004 and NFR-005 self-references
    - Density-based French stop-word detection (>= 5 hits per file) to avoid loanword false positives (naive, cafe, resume)
    - Per-file shellcheck loop (NFR-002) with `command -v shellcheck` skip-not-fail precondition
    - Static deny-list grep complementing runtime mkdir-mutex (NFR-003 static + Phase 2 D-09 dynamic)
    - case-arm self-exemption double-belt (audit file exempts itself in addition to marker filtering)
key-files:
  created:
    - docs/adr/0004-surface-3-propagation.md (151 lines, Status Proposed, 8 canonical sections)
    - core/tests/nfr_audits.bats (289 lines, 6 @test blocks, byte-identical _full to chantier:687/:912)
    - .planning/phases/05-dogfood-e2e/05-02-SUMMARY.md (this file)
  modified: []
decisions:
  - ADR 0004 mirrors ADR 0003 section structure exactly (Provenance/Context/Decision/Consequences/Alternatives/Open-questions/Ratification path/References)
  - ADR 0004 ships in Proposed status; ratification requires a second harness adapter to validate cross-harness (D-09)
  - NFR-001 _full deny-list literal duplicated inline (not sourced from a shared helper); RESEARCH OQ4 recommendation
  - NFR-002 uses per-file `shellcheck --shell=sh` loop (Discretion #5) for better bats failure legibility; skips when shellcheck absent
  - NFR-003 scope limited to production .sh sources in core/bin, adapters, skills; bats test files exempt (they scaffold isolated STATE.md fixtures inside $BATS_TEST_TMPDIR, not runtime)
  - NFR-005 uses density-based French stop-word approach (>= 5 hits/file) per RESEARCH Pitfall 5 to avoid loanword false positives
  - NFR-006 SPDX header check excludes `test_helper/` vendored submodule directory (outside Chantier authorship)
  - HARNESS_DENY_LIST_CHECK markers placed on 24 lines; case-arm self-exemption for the audit file itself is the double-belt
metrics:
  duration: ~30 minutes
  completed: 2026-05-30
  tasks: 2
  commits: 2 (docs + test)
  bats_delta: 74/0 -> 80/0 (+6 tests in one new file)
  files_touched: 2 (both new; zero modified)
  adr_count: 3 -> 4 (one new ADR; status Proposed)
  rule_4_checkpoints: 0
  rule_1_3_autofixes: 1 (NFR-003 scope narrowed from `.sh + .bats` to `.sh` only -- bats files write isolated STATE.md scaffolds inside $BATS_TEST_TMPDIR, not the runtime path; the plan's BEHAVIOR claim that bats tests use `chantier state append` was inaccurate per probe of seven bats files)
---

# Phase 5 Plan 02: ADR 0004 + NFR audits - Summary

One-liner: Codifies the Phase 4 plan 03 Surface 3 propagation discovery in ADR 0004 (Proposed) and lands six independent NFR @test blocks in `core/tests/nfr_audits.bats`, promoting SC#4 from claim to enforcement and growing the bats suite 74 -> 80 with zero pre-existing-test regressions.

## What shipped

### Task 1 - ADR 0004 (commit `b54a53d`)

Authored `docs/adr/0004-surface-3-propagation.md` -- 151 lines, status **Proposed**, eight canonical sections mirroring ADR 0003 verbatim (Provenance/Context/Decision/Consequences/Alternatives/Open-questions/Ratification path/References). The ADR codifies the Phase 4 plan 03 discovery: the adapter SHALL, after the wrapped subagent exits 0 and before invoking `chantier validate-task`, copy every plain file from `$DOSSIER/` to `$TASK_DIR/`, EXCLUDING the adapter-owned artifacts (`inputs.yml`, `env.sh`, `subagent.transcript.log`) and all subdirectories (`reads/`, `upstream/`, `skill/`).

Key sections:

- **Provenance** cites `.planning/phases/04-claude-code-adapter/04-03-SUMMARY.md` (the discovery moment) and the implementation locus in `adapters/claude-code/run-task.sh`.
- **Context** names three forces: ADR 0001 §Surface 3 specifies destination only; Phase 3 D-04 + Phase 4 D-06 create the dossier-vs-task-dir gap; the adapter is the only component aware of both.
- **Decision** states the contract precisely, including a 9-line illustrative shell snippet showing the `for _out in "$DOSSIER"/*; do ... case ... cp` pattern (the only fenced code block of substantive length in the ADR).
- **Consequences** breaks Positive (4 bullets), Negative (3 bullets), Mitigations (3 bullets).
- **Alternatives considered** rejects three alternatives with explicit rationale: skill writes directly to TASK_DIR (couples skill to adapter env), symlink dossier-to-TASK_DIR pre-dispatch (couples two namespaces, complicates failure path), and manifest-driven propagation (new contract surface for negligible benefit).
- **Open questions (deferred)** lists three: subdirectory propagation, atomic propagation, exclusion-list canonicalization across adapters.
- **Ratification path** lists three numbered observable conditions modeled on ADR 0003 lines 196-206.
- **References** cites ADR 0001 (§Surface 2 + §Surface 3 separately), ADR 0002 (exit matrix), ADR 0003 (Principle 4), the Phase 4 plan 03 SUMMARY, the adapter implementation locus, the Phase 5 CONTEXT.md D-09, and REQUIREMENTS.md acceptance.

English-only verified: `grep -c '[À-ÿ]' docs/adr/0004-surface-3-propagation.md` returns 0.

### Task 2 - core/tests/nfr_audits.bats (commit `2962c24`)

Authored `core/tests/nfr_audits.bats` -- 289 lines, one `setup()` block, six `@test` blocks. Each @test reads files from disk only, never executes them, asserts pass/fail with explicit `false` on violation, and runs in isolation via `bats -f 'NFR-NNN'`.

| @test | Pattern | Scope | Self-exemption shape |
|-------|---------|-------|----------------------|
| NFR-001 | `_full` byte-identical to `chantier:687`/`:912`; `_narrow` for adapter dir | `core/`, `skills/`, `adapters/` (excluding `test_helper/`) | case-arm exempts the four sanctioned-deny-list-carrier files; per-file `grep -v 'HARNESS_DENY_LIST_CHECK'` filter |
| NFR-002 | `shellcheck --shell=sh` per-file loop + bash-ism grep (`[[ `, `<<<`, `mapfile`, `declare -a`, `local -a`) | `core/bin/`, `core/tests/`, `adapters/`, `skills/`, `tests/` (.sh + chantier binary) | `command -v shellcheck` skip-not-fail |
| NFR-003 | `>[[:space:]]*[^&].*STATE\.md` single-redirect deny | `core/bin/`, `adapters/`, `skills/` (.sh production sources only) | case-arm exempts `core/bin/chantier` (where `state_append()` is the sanctioned writer) |
| NFR-004 | `curl |wget |http[s]?://|nc -|telnet ` network primitives | `core/bin/`, `adapters/`, `skills/` (.sh + chantier binary) | per-file `grep -v 'HARNESS_DENY_LIST_CHECK'`, then `grep -v '^[[:space:]]*#.*http'` (strips comment URLs), case-arm self-exempt |
| NFR-005 | `\bavec\b|\bdonc\b|\bainsi\b|\bpour\b|\bdans\b|\bc.est\b|\bn.est\b|\bcette\b|\bnous\b` density (>=5/file) | `README.md`, `LICENSE`, `LICENSE-CREDITS`, `CONTRIBUTING.md`, `docs/adr/`, `docs/vision.md`, `docs/research/`, `core/`, `skills/`, `adapters/`, `tests/` | `.planning/` and `docs/strategy/` NOT walked; case-arm self-exempt |
| NFR-006 | Five assertions: `head -1 LICENSE` == `MIT License`; `LICENSE-CREDITS` exists; SPDX in every `.sh`; `Chantier Contributors` in LICENSE; no `(c) FirstName LastName` regex | LICENSE + every `.sh` under `core/bin/`, `core/tests/`, `adapters/`, `skills/`, `tests/` (excluding `test_helper/`) | n/a |

Bats output (six green ok lines):

```
1..6
ok 1 nfr_audits: NFR-001 -- no harness identifiers in skill bodies or core (cross-tree deny-list)
ok 2 nfr_audits: NFR-002 -- POSIX sh + jq only (shellcheck + bash-ism grep)
ok 3 nfr_audits: NFR-003 -- STATE.md append-only (no single-> redirect outside state_append)
ok 4 nfr_audits: NFR-004 -- no network primitives in executable code
ok 5 nfr_audits: NFR-005 -- English-only public artifacts (French stop-word density)
ok 6 nfr_audits: NFR-006 -- MIT license, collective copyright, SPDX headers
```

## Verification result matrix

| Criterion | Evidence | Status |
|-----------|----------|--------|
| **D-05 implemented** | Single file `core/tests/nfr_audits.bats` with 6 @test blocks; `bats --tap core/tests/nfr_audits.bats \| grep -c '^ok'` returns 6. | ✓ |
| **D-06 implemented** | Each @test matches the locked per-NFR shape from CONTEXT.md lines 33-39; verified in the table above. | ✓ |
| **D-09 implemented** | ADR 0004 ships in Proposed status with eight canonical sections; Ratification path lists three observable conditions; References cite ADR 0001 §Surface 2/3, Phase 4 plan 03 SUMMARY, and the adapter implementation locus. | ✓ |
| **bats core/tests/ 80/0** | `bats core/tests/` reports `ok 80` on the final line (was `ok 74` at Phase 5 plan 01 close); zero `not ok` lines. | ✓ |
| **6/6 from nfr_audits.bats** | `bats core/tests/nfr_audits.bats` reports `1..6` followed by six `ok` lines; exit 0. | ✓ |
| **Per-NFR independence** | `bats core/tests/nfr_audits.bats -f 'NFR-00N'` for N in 1..6 each exits 0 and reports `1..1 ok 1`. | ✓ |
| **adapter_isolation still green** | `bats core/tests/adapter_isolation.bats` reports `1..1 ok 1` with the new bats file present; the `HARNESS_DENY_LIST_CHECK` markers (24 in the new file) and the `core/tests/nfr_audits.bats) continue ;;` case-arm exemption are the double-belt that keeps it green. | ✓ |
| **chantier --self-test still green** | `./core/bin/chantier --self-test` exits 0 with "self-test: all green" on the final line; the new bats file does not introduce any harness identifier into the binary's source. | ✓ |
| **Byte-identical _full literal** | Triple `diff`: `core/bin/chantier:687` == `core/bin/chantier:912` == `core/tests/nfr_audits.bats:32` (the line `_full='mcp__\|...\|opencode'`). All three produce the same `mcp__\|claude_ai_\|@codebase\|claude-code\|cursor\|codex-cli\|copilot-cli\|gemini-cli\|opencode` literal under `grep -oE "mcp__[^']*opencode"`. | ✓ |
| **HARNESS_DENY_LIST_CHECK density** | `grep -c HARNESS_DENY_LIST_CHECK core/tests/nfr_audits.bats` returns 24 (well above the >= 6 threshold). | ✓ |
| **Self-leak check** | `grep -v '^#' core/tests/nfr_audits.bats \| grep -v 'HARNESS_DENY_LIST_CHECK' \| grep -cE 'mcp__\|...\|opencode'` returns 0; the marker convention fully exempts the audit from self-triggering. | ✓ |
| **NFR-005 English-only on both new files** | `grep -c '[À-ÿ]' docs/adr/0004-surface-3-propagation.md` returns 0; `grep -c '[À-ÿ]' core/tests/nfr_audits.bats` returns 0. | ✓ |
| **ADR 0004 length bounds** | `wc -l docs/adr/0004-surface-3-propagation.md` returns 151 -- within the 110-250 plan-specified window. | ✓ |
| **ADR 0004 canonical sections** | `grep -c '^## ' docs/adr/0004-surface-3-propagation.md` returns 8 (Provenance, Context, Decision, Consequences, Alternatives considered, Open questions, Ratification path, References). | ✓ |
| **ADR 0004 numbered Ratification path** | `awk '/^## Ratification path/{f=1;next}/^## /{f=0}f' docs/adr/0004-surface-3-propagation.md \| grep -cE '^[0-9]+\.'` returns 3 (cross-harness, bats proof, maintainer review). | ✓ |
| **Falsifiability of NFR-001** | Manual probe (not committed): `printf '\n# probe: cursor\n' >> skills/test-driven-development/run.sh; bats core/tests/nfr_audits.bats -f 'NFR-001'` produces `not ok 1` with `skills/test-driven-development/run.sh` in the violation list; `git checkout -- skills/test-driven-development/run.sh` then `bats ...` returns `ok 1`. The audit reacts to deny-list injection and recovers on revert. | ✓ |

## Byte-identical proof (NFR-001 _full)

```
$ grep -oE "mcp__[^']*opencode" core/bin/chantier | head -1
mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode

$ grep -oE "mcp__[^']*opencode" core/tests/nfr_audits.bats | head -1
mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode

$ grep -oE "mcp__[^']*opencode" core/tests/adapter_isolation.bats | head -1
mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode

$ diff <(grep -oE "mcp__[^']*opencode" core/bin/chantier | head -1) \
        <(grep -oE "mcp__[^']*opencode" core/tests/nfr_audits.bats | head -1)
$ echo $?
0
```

All three sources carry the byte-identical literal; the marker convention keeps every source from self-triggering its own audit (and the audit auditing the other two sources).

## Per-NFR independence proof matrix

```
$ for n in 1 2 3 4 5 6; do bats core/tests/nfr_audits.bats -f "NFR-00$n" 2>&1 | tail -1; done
ok 1 nfr_audits: NFR-001 -- no harness identifiers in skill bodies or core (cross-tree deny-list)
ok 1 nfr_audits: NFR-002 -- POSIX sh + jq only (shellcheck + bash-ism grep)
ok 1 nfr_audits: NFR-003 -- STATE.md append-only (no single-> redirect outside state_append)
ok 1 nfr_audits: NFR-004 -- no network primitives in executable code
ok 1 nfr_audits: NFR-005 -- English-only public artifacts (French stop-word density)
ok 1 nfr_audits: NFR-006 -- MIT license, collective copyright, SPDX headers
```

Each @test runs in isolation; no shared mutable state between them; no test-ordering dependency. Running them individually or together produces the same result.

## Section-count proof for ADR 0004

```
$ grep -c '^## ' docs/adr/0004-surface-3-propagation.md
8
$ grep '^## ' docs/adr/0004-surface-3-propagation.md
## Provenance
## Context
## Decision
## Consequences
## Alternatives considered
## Open questions (deferred)
## Ratification path
## References
```

All eight canonical sections present, in canonical order, matching ADR 0003 verbatim.

## Citation - what was closed

Phase 4 `.planning/phases/04-claude-code-adapter/04-SUMMARY.md` §Handoff Notes line:

> **F1** -- ADR 0004 (Surface 3 propagation) discovered as a gap during plan 03 e2e; the patch lives in `run-task.sh` but the cross-adapter contract has not been written down. Author ADR 0004 in Proposed status in Phase 5 per D-09.

Resolved by commit `b54a53d` (ADR 0004 authored, Status Proposed).

## Deviations from plan

**Auto-fixed Issues**

1. **[Rule 1 - Bug] NFR-003 scope narrowed from `.sh + .bats` to `.sh` only**
   - **Found during:** Task 05-02-02 pre-write probe of existing `*.bats` files for STATE.md write patterns.
   - **Issue:** The plan's NFR-003 BEHAVIOR section claimed "All bats tests that write STATE.md inside `$BATS_TEST_TMPDIR` invoke `chantier state append` via subprocess (Phase 4 idiom); none use direct `>` redirect." A probe (`grep -nE '>[[:space:]]*[^&].*STATE\.md' core/tests/*.bats`) showed at least seven bats files use `cat > "$TMPHOME/.planning/STATE.md"` or `cat > .planning/STATE.md` in their `setup()` blocks to scaffold test-fixture STATE.md files inside `$BATS_TEST_TMPDIR`. If NFR-003 walked `*.bats` files too, those legitimate test-scaffold patterns would be flagged as violations.
   - **Fix:** Narrowed NFR-003's `find` walk to `-name '*.sh'` only (excluding `*.bats`). The static guard now scopes to production runtime sources (`core/bin/*.sh`-equivalent + adapter `.sh` + skill `.sh`), which is the correct scope: bats tests scaffold inside isolated tempdirs and never touch the real `.planning/STATE.md` outside of `state_append()`. The runtime mkdir-mutex inside `state_append()` (Phase 2 D-09) is the dynamic guard for actual STATE.md writes; NFR-003's static guard correctly complements it on production sources.
   - **Files modified:** `core/tests/nfr_audits.bats` (the `find` pattern in the NFR-003 @test).
   - **Commit:** 2962c24 (the scope narrowing was applied pre-commit; the file landed already passing).

No Rule-2 (missing critical functionality), Rule-3 (blocking issues), or Rule-4 (architectural) deviations. Both tasks executed end-to-end exactly as specified except for the NFR-003 scope correction above.

## Threat Flags

None. The two new artifacts introduce no new threat surface beyond what the plan's `<threat_model>` modeled (T-NFR-001 through T-NFR-006 mitigations + T-05-02-ADR-DRIFT accept + T-05-02-SC accept). All mitigations from the threat register are honored:

- T-NFR-001: byte-identical `_full` literal verified via triple `diff`; D-10 path-only carve-out implemented; HARNESS_DENY_LIST_CHECK marker on 24 lines plus case-arm self-exemption.
- T-NFR-002: `shellcheck --shell=sh` per-file loop runs; bash-ism grep covers `[[`, `<<<`, `mapfile`, `declare -a`, `local -a`; `command -v shellcheck` skip-not-fail when absent.
- T-NFR-003: static grep complements the Phase 2 D-09 dynamic mkdir-mutex; scope narrowed to production sources per the Rule-1 auto-fix above.
- T-NFR-004: deny-list pattern in executable code only; `.md` docs exempt by file-extension scope; comment-line URL stripping prevents false positives; HARNESS_DENY_LIST_CHECK marker filter removes the audit's own deny-list lines.
- T-NFR-005: density threshold (>= 5 hits/file) per RESEARCH Pitfall 5; `.planning/` and `docs/strategy/` NOT walked.
- T-NFR-006: five independent assertions, each with a clear stderr message on failure.

## Known Stubs

None. Both artifacts are substantively complete: ADR 0004 ships the full contract (status Proposed is not a stub but a deliberate lifecycle state per D-09), and the bats audit ships six green @tests that exercise real measurable invariants.

## Self-Check: PASSED

- File `docs/adr/0004-surface-3-propagation.md`: FOUND (151 lines, status Proposed, 8 canonical sections).
- File `core/tests/nfr_audits.bats`: FOUND (289 lines, 6 @test blocks).
- File `.planning/phases/05-dogfood-e2e/05-02-SUMMARY.md`: FOUND (this file).
- Commit `b54a53d`: FOUND in `git log --oneline -5` (ADR 0004).
- Commit `2962c24`: FOUND in `git log --oneline -5` (nfr_audits.bats).
- bats core/tests/ 80/0: confirmed via `bats core/tests/ | tail -1` showing `ok 80`.
- bats core/tests/nfr_audits.bats 6/6: confirmed via `bats core/tests/nfr_audits.bats | tail -1` showing `ok 6`.
- adapter_isolation green with new file present: confirmed via `bats core/tests/adapter_isolation.bats` exit 0.
- chantier --self-test green with new file present: confirmed via `./core/bin/chantier --self-test` exit 0.
- NFR-005 English-only on both new files: confirmed via `grep -c '[À-ÿ]' docs/adr/0004-surface-3-propagation.md core/tests/nfr_audits.bats` returning 0 for each.
- Byte-identical `_full` literal: confirmed via triple `diff` (chantier:687 == chantier:912 == nfr_audits.bats:32 == adapter_isolation.bats:46).
