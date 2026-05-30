---
phase: 4
slug: claude-code-adapter
status: ready-to-execute
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-30
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bats-core 1.13.0 + bats-support + bats-assert (POSIX shell test harness, vendored under `core/tests/test_helper/`) |
| **Config file** | none — discovery is `core/tests/*.bats`, helpers under `core/tests/test_helper/` |
| **Quick run command** | `bats core/tests/adapter_isolation.bats core/tests/adapter_claude_code_e2e.bats` |
| **Full suite command** | `bats core/tests/` |
| **Estimated runtime** | ~30 seconds (suite-wide, 71 tests at Phase 3 close; +2 files in Phase 4) |

---

## Sampling Rate

- **After every task commit:** Run quick command for the files this task touched (per-task bats file scope).
- **After every plan wave:** Run `bats core/tests/` (full suite) — Phase 4 adds at most 2 files; whole-suite cost stays ~30 s.
- **Before `/gsd-verify-work`:** Full suite must be green (target: 73/0 at Phase 4 close).
- **Max feedback latency:** 30 seconds.

---

## Per-Task Verification Map

Aligned with the four tasks the planner finalized across `04-01-PLAN.md`, `04-02-PLAN.md`, `04-03-PLAN.md`. Each row's *Automated Command* mirrors the task's `<automated>` block verbatim so the gate executed during execution and the gate listed here cannot drift.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | FR-008 | T-04-01-01 (NFR-001 audit) | `adapter_isolation.bats` goes red on any cross-harness deny-list token outside `adapters/claude-code/` (D-09–D-12) | bats audit | `cd "$(git rev-parse --show-toplevel)" && bats core/tests/adapter_isolation.bats` | ❌ W0 | ⬜ pending |
| 04-02-01 | 02 | 1 | FR-008 | T-04-02-01..10 (shell/heredoc injection, set-e mask, subshell-cd, attempts collision, D-05 worktree, NFR-001 carve-out) | `adapters/claude-code/run-task.sh` is POSIX-sh shellcheck-clean, executable, `#!/bin/sh`, accepted by the cross-tree audit under the D-10 carve-out | unit (shellcheck + bats audit) | `shellcheck --shell=sh adapters/claude-code/run-task.sh && test -x adapters/claude-code/run-task.sh && head -1 adapters/claude-code/run-task.sh \| grep -qE '^#!/bin/sh$' && bats core/tests/adapter_isolation.bats` | ❌ W0 | ⬜ pending |
| 04-03-01 | 03 | 2 | FR-008 | T-04-03-01..07 (stub isolation, quoted heredoc, append-only state, CWD-relative state append) | end-to-end run through stub: dossier staged at `$WORKTREE/.chantier/dossiers/<task>/`, three D-03 events (`task.started`/`skill.completed`/`task.completed`) in STATE.md, validate-task gates 1–5 green (D-13/D-14/D-15) | e2e (bats) | `bats core/tests/adapter_claude_code_e2e.bats && bats core/tests/adapter_isolation.bats && bats core/tests/` | ❌ W0 | ⬜ pending |
| 04-03-02 | 03 | 2 | FR-008 | T-04-03-06 (ROADMAP edit hygiene), T-04-03-05 (append-only via binary) | Phase close: `04-SUMMARY.md` exists, ROADMAP shows `[x] **Phase 4`, STATE.md contains `phase.completed` event for Phase 4, full bats suite still 73/0 | post-condition (grep + bats) | `test -f .planning/phases/04-claude-code-adapter/04-SUMMARY.md && grep -q '\[x\] \*\*Phase 4' .planning/ROADMAP.md && grep -qE '"event":"phase\.completed".*"04-claude-code-adapter\|adapters/claude-code' .planning/STATE.md && bats core/tests/` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `core/tests/adapter_isolation.bats` — new file, NFR-001 audit harness (D-09–D-12)
- [ ] `core/tests/adapter_claude_code_e2e.bats` — new file, end-to-end proof using `CHANTIER_CLAUDE_BIN` stub (D-13–D-15)
- [ ] No new framework install required — bats-core 1.13.0, bats-support, bats-assert already vendored at `core/tests/test_helper/` per RESEARCH.md §Standard Stack.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real `claude -p` dispatch (no stub) | FR-008 sanity | NFR-004 forbids network in CI; real-claude run is a release-time concern. | Local dev: `cd $(git worktree add ...)`, run `adapters/claude-code/run-task.sh <task-id>` with `CHANTIER_CLAUDE_BIN` unset and a valid `claude` on PATH. Expect: validate-task green, three STATE.md events, dossier preserved under `.chantier/dossiers/<task>/`. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (both bats files)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30 s
- [x] `nyquist_compliant: true` set in frontmatter (per-task rows match `04-0{1,2,3}-PLAN.md` task IDs and `<automated>` commands verbatim)

**Approval:** approved 2026-05-30 (orchestrator, post-plan-checker `## ISSUES FOUND` 0 blockers / 2 warnings, both housekeeping warnings resolved before approval)
