---
phase: 02
slug: runtime-core
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-29
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `02-RESEARCH.md` § Validation Architecture (lines 920–955).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `bats-core` 1.13.0 (POSIX-portable bash test framework — does not violate FR-001; tests are not shipped runtime code) |
| **Config file** | None native to bats; test discovery is by `core/tests/*.bats` filename glob |
| **Quick run command** | `bats core/tests/<file>.bats` (single suite, ≤ 5 s) |
| **Full suite command** | `bats core/tests/` (all suites, expected < 30 s for Phase 2 scope) |
| **Static lint command** | `shellcheck -s sh core/bin/chantier` (POSIX dialect enforced) |
| **Estimated runtime** | ~30 seconds full suite + ~2 seconds shellcheck |

---

## Sampling Rate

- **After every task commit:** Run `bats core/tests/<file>.bats` for the file the task touched.
- **After every plan wave:** Run `bats core/tests/` (full suite) + `shellcheck -s sh core/bin/chantier`.
- **Before `/gsd-verify-work`:** Full suite green AND `chantier --self-test` green AND `shellcheck -S error -s sh core/bin/chantier` returns zero errors.
- **Max feedback latency:** 30 seconds (full suite).

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-XX-01 | TBD | 0 | (infrastructure) | — | Bats + shellcheck installed; helpers vendored | manual | `command -v bats && command -v shellcheck` | ✅ on commit | ⬜ pending |
| 02-XX-02 | TBD | 1 | FR-001 | — | `core/bin/chantier` exists, is executable, depends only on `sh`+`jq` | smoke + static-grep | `bats core/tests/self_test.bats` + `shellcheck -s sh core/bin/chantier` | ❌ W0 | ⬜ pending |
| 02-XX-03 | TBD | 1 | FR-003 | T-V12-lock | `chantier state append` writes exactly one JSONL line, validates event regex, locks via mkdir-mutex with stale-PID detection, accepts repeated `-r` | unit + concurrency | `bats core/tests/state_append.bats` | ❌ W0 | ⬜ pending |
| 02-XX-04 | TBD | 1 | (D-03) | — | `chantier state show` renders the JSONL stream, substitutes null/empty → `-` before `column -t` (BSD column collapse pitfall) | integration | `bats core/tests/state_show.bats` | ❌ W0 | ⬜ pending |
| 02-XX-05 | TBD | 2 | FR-002 | — | `chantier new <name>` produces 5 scaffold files with correct frontmatter (PROJECT/REQUIREMENTS/ROADMAP/STATE/config) | integration | `bats core/tests/new.bats` | ❌ W0 | ⬜ pending |
| 02-XX-06 | TBD | 2 | FR-004 | T-V5-inj, T-V12-traversal | `chantier validate-task` enforces all 5 ADR-0001 gates with exit codes 0/1/2/3 (1 case per gate) | unit per gate (5 cases) | `bats core/tests/validate_task.bats` | ❌ W0 | ⬜ pending |
| 02-XX-07 | TBD | 2 | (ADR 0002) | — | Each `core/schemas/*.json` parses as valid JSON Schema draft-07 subset; every subcommand answers `--help` with exit 0; no harness identifiers grep-hit on `core/bin/chantier`; no CRLF line endings | smoke | `bats core/tests/self_test.bats` | ❌ W0 | ⬜ pending |
| 02-XX-08 | TBD | 3 | (D-04) | — | Migration commit produces exactly 10 JSONL lines from the existing 10 Markdown rows; `format_version` bumped to `0.1.0` | one-shot verify | manual: `awk '/^---$/{c++;next} c>=2' .planning/STATE.md \| wc -l` returns 10 | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Task IDs are placeholders (`02-XX-NN`) until `gsd-planner` finalizes plan numbering. The planner must map each task to one of these verification rows.*

---

## Wave 0 Requirements

- [ ] Install `bats-core` and `shellcheck` on host: `brew install bats-core shellcheck` (or distro equivalent).
- [ ] Add `bats-support` and `bats-assert` as git submodules under `core/tests/test_helper/` (vendoring choice over package manager — keeps NFR-002 trust surface auditable for contributors).
- [ ] Create empty test files: `core/tests/state_append.bats`, `state_show.bats`, `validate_task.bats`, `new.bats`, `self_test.bats`.
- [ ] Create `core/tests/fixtures/` with at minimum: `PLAN.valid.md`, `PLAN.invalid-missing-required.md`, `output.valid.md`, `output.missing-acceptance.md`.
- [ ] Add `.gitattributes` rule `core/bin/chantier text eol=lf` to prevent CRLF corruption (RESEARCH.md Pitfall 3).
- [ ] (Optional, deferrable to Phase 5) CI workflow: run full bats suite on push, matrix `ubuntu-latest` (dash-strict POSIX) + `macos-latest` (BSD coreutils).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| STATE.md migration produces semantically-equivalent JSONL | D-04 | Migration is a one-shot operation on real data; automating its inverse would just be re-implementing the migration. Verified by code review of the diff. | After running migration script: `git diff .planning/STATE.md` and confirm each Markdown-table row maps to one JSONL line preserving `ts/event/actor/task/skill/summary/refs`. |
| ADR 0002 inline schemas match `core/schemas/*.json` files | D-06 | ADR text is for humans; file content is for runtime. Tools can't catch a subtle prose drift. | Reviewer reads ADR 0002 §Schemas alongside `core/schemas/*.json` and confirms each declared `required` array matches. |
| `chantier new` scaffold output reads as helpful to a first-time user | D-11 | "Helpful comment stubs" is subjective; no automated check substitutes. | After running `chantier new demo-project`, reviewer opens each generated file and confirms `<!-- TODO: ... -->` comments are present, sections match the established `.planning/` patterns, no example content leaks in. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies declared
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (bats install, helper vendoring, test scaffolding, .gitattributes)
- [ ] No watch-mode flags (bats has no watch mode by default — safe)
- [ ] Feedback latency < 30 s (target ≤ 30s full suite)
- [ ] `nyquist_compliant: true` set in frontmatter once planner has filled real task IDs

**Approval:** pending (set to `approved YYYY-MM-DD` by planner after task-ID mapping is final)
