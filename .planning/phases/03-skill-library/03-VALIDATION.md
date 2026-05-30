---
phase: 03
slug: skill-library
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-30
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bats-core 1.13.0 (vendored at `core/tests/test_helper/` per Phase 2) |
| **Config file** | `core/tests/test_helper/` (bats-support + bats-assert loaders) |
| **Quick run command** | `bats core/tests/skill_uniformity.bats` |
| **Full suite command** | `bats core/tests/` |
| **Estimated runtime** | ~5 seconds (64 existing + new Phase 3 tests) |

---

## Sampling Rate

- **After every task commit:** Run `bats core/tests/skill_uniformity.bats` AND `shellcheck` against any modified `run.sh`
- **After every plan wave:** Run `bats core/tests/` (full suite) AND `chantier --self-test`
- **Before `/gsd-verify-work`:** Full suite must be green; `chantier --self-test` green; `grep -rE 'mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode' skills/` returns nothing
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

> Populated by the planner — one row per task. Filled-in after PLAN.md authoring.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | FR-005/006/009/010, NFR-001 | — | See per-skill `## Invariants` | unit / integration | `bats core/tests/skill_uniformity.bats` or `bats core/tests/skill_<name>_e2e.bats` | ❌ W0/W1/W2 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `core/tests/skill_uniformity.bats` — uniformity test covering D-16 (identical `harness_adapters`), FR-009 (four skills present), FR-010 (≥2 PRESSURE scenarios), D-01 (every skill ships `run.sh`). Stub returns skip when `skills/*/SKILL.md` matches zero files; turns green as Wave 2 lands skills.
- [ ] (Per-skill e2e) `core/tests/skill_<name>_e2e.bats` × 4 — exercise a fixture task end-to-end via `chantier validate-task`. Authored alongside each skill in Wave 2.
- [ ] (Per-skill fixtures) `core/tests/fixtures/skills/<name>/dossier/inputs.yml` × 4 — minimal dossier per skill for the e2e tests.

*Framework already installed (Phase 2 vendored bats + helpers). No npm/pip install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Subjective prose quality of `SKILL.md` and `PRESSURE.md` bodies | FR-006, FR-010 | Greppable enforcement covers structure and forbidden tokens, but cannot judge whether invariants are well-worded, scenarios are convincing, or the acknowledge-block is actionable for a fresh subagent. | Human reviewer reads each `SKILL.md` and `PRESSURE.md` against CONTEXT.md D-05..D-13 and confirms invariants are stated clearly, disqualifier-to-invariant mapping is legible, and acknowledge-block placement is consistent across all four skills. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
