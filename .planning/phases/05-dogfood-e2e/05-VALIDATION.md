---
phase: 5
slug: dogfood-e2e
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-30
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Derived from `05-RESEARCH.md` §"Validation Architecture".

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bats-core 1.13.0 + bats-support 0.3.0 + bats-assert 2.2.4 |
| **Config file** | none — bats discovers `.bats` files by path |
| **Quick run command** | `bats core/tests/<single-file>.bats` (per-plan) |
| **Full suite command** | `bats core/tests/ tests/e2e/` |
| **Estimated runtime** | ~15 seconds for full suite (current 73/0 ~10s + 8 new @tests) |
| **Target count at phase close** | 81/0 (73 baseline + 1 F3 regression + 6 NFR audits + 1 e2e full loop) |

---

## Sampling Rate

- **After every task commit:** Run `bats <single new/modified .bats file>` for that task
- **After every plan wave:** Run `bats core/tests/ tests/e2e/`
- **Before `/gsd-verify-work`:** Full suite must be green (81/0)
- **Max feedback latency:** ~15 seconds (full suite)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-t1 | 01 | 1 | D-01, D-02 | — | t1 writes failing bats test asserting `upstream/t1/output.json` exists in t2's dossier | regression (RED) | `bats core/tests/adapter_upstream_e2e.bats` (must FAIL at end of t1) | ❌ W0 | ⬜ pending |
| 05-01-t2 | 01 | 1 | D-01, D-02 | T-05-SYMLINK | F3 fix in `adapters/claude-code/run-task.sh` makes t1's test green; staging is path-validated | regression (GREEN) | `bats core/tests/adapter_upstream_e2e.bats` exits 0 | ❌ W0 | ⬜ pending |
| 05-02-t1 | 02 | 1 | D-09 | — | `docs/adr/0004-surface-3-propagation.md` exists, status Proposed, mirrors ADR 0003 template | manual gate | `head -10 docs/adr/0004-surface-3-propagation.md \| grep -E 'status: Proposed'` | ❌ W0 | ⬜ pending |
| 05-02-t2 | 02 | 1 | NFR-001 | T-NFR-001 | NFR-001 audit @test: deny-list grep across tree, path-only carve-out for `adapters/claude-code/` | unit / static audit | `bats core/tests/nfr_audits.bats -f 'NFR-001'` | ❌ W0 | ⬜ pending |
| 05-02-t3 | 02 | 1 | NFR-002 | — | NFR-002 audit @test: `shellcheck --shell=sh` over every `.sh`; grep bash-only constructs | unit / static audit | `bats core/tests/nfr_audits.bats -f 'NFR-002'` | ❌ W0 | ⬜ pending |
| 05-02-t4 | 02 | 1 | NFR-003 | T-NFR-003 | NFR-003 audit @test: grep for STATE.md writes outside `state_append()` in `core/bin/chantier` | unit / static audit | `bats core/tests/nfr_audits.bats -f 'NFR-003'` | ❌ W0 | ⬜ pending |
| 05-02-t5 | 02 | 1 | NFR-004 | T-NFR-004 | NFR-004 audit @test: grep `curl/wget/http(s)://` in executable code; doc `.md` exempt | unit / static audit | `bats core/tests/nfr_audits.bats -f 'NFR-004'` | ❌ W0 | ⬜ pending |
| 05-02-t6 | 02 | 1 | NFR-005 | — | NFR-005 audit @test: non-English glyph regex over public artifacts; `.planning/` + `docs/strategy/` exempt | unit / static audit | `bats core/tests/nfr_audits.bats -f 'NFR-005'` | ❌ W0 | ⬜ pending |
| 05-02-t7 | 02 | 1 | NFR-006 | — | NFR-006 audit @test: MIT + `Chantier Contributors` + SPDX header on every `.sh` | unit / static audit | `bats core/tests/nfr_audits.bats -f 'NFR-006'` | ❌ W0 | ⬜ pending |
| 05-03-t1 | 03 | 2 | SC#1, SC#2, SC#3 | — | `tests/e2e/full_loop.bats` orchestrates new-project → plan → execute → verify with stub adapter; CHANTIER_E2E_REAL_CLAUDE opt-in unsets stub | integration | `bats tests/e2e/full_loop.bats` | ❌ W0 | ⬜ pending |
| 05-04-t1 | 04 | 3 | SC#5, D-07 | — | ROADMAP migrated to ADR 0001 native (Format note callout stripped); no other narrative loss | manual gate | `head -5 .planning/ROADMAP.md \| ! grep -q 'Format note (temporary)'` | ❌ W0 | ⬜ pending |
| 05-04-t2 | 04 | 3 | D-08 | — | `cutover.completed` event appended via `chantier state append`; ROADMAP migration commit-bundled | manual gate | `grep '"event":"cutover.completed"' .planning/STATE.md \| wc -l` returns 1 | ❌ W0 | ⬜ pending |
| 05-04-t3 | 04 | 3 | SC#1..SC#5 | — | Phase 5 SUMMARY.md authored; full suite 81/0; `phase.completed` event | manual gate | `bats core/tests/ tests/e2e/` exits 0 with 81 passed | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `core/tests/adapter_upstream_e2e.bats` — F3 regression test (Plan 05-01)
- [ ] `core/tests/nfr_audits.bats` — six NFR audits (Plan 05-02)
- [ ] `tests/e2e/` — new top-level test directory (Plan 05-03)
- [ ] `tests/e2e/full_loop.bats` — full integration test (Plan 05-03)
- [ ] `docs/adr/0004-surface-3-propagation.md` — ADR 0004 Proposed status (Plan 05-02)

*Framework install: none. bats-core 1.13.0, shellcheck 0.11.0, jq, git 2.50.1 already on host.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| ROADMAP narrative quality post-migration | SC#5, D-07 | Diff is interpretive — verify only the Format note callout is stripped, no other content drift | `git log -p -1 .planning/ROADMAP.md` reviewed by operator before final commit |
| `cutover.completed` event payload semantics | D-08 | Event refs list `[".planning/ROADMAP.md", "<commit-sha>"]` — sha is post-commit | Operator inspects final commit and confirms refs payload matches D-08 description |
| ADR 0004 prose completeness | D-09, Discretion #4 | Context/Decision/Consequences/Alternatives/Open Questions sections are author-judgment | Operator reads `docs/adr/0004-surface-3-propagation.md` end-to-end before merge |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (target ~15s)
- [ ] `nyquist_compliant: true` set in frontmatter once planner has authored PLAN.md task IDs

**Approval:** pending (planner fills final task IDs and flips frontmatter to nyquist_compliant: true)
