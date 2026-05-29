---
project_id: chantier
milestone: v0.1.0
created: 2026-05-29
---

# Roadmap — v0.1.0

## In milestone v0.1.0

| # | Phase | Status | One-sentence summary |
|---|---|---|---|
| 1 | `01-foundation` | ✅ DONE | Architecture proposed and ratified, repo skeleton shipped, GitHub org created, ADR 0001 accepted. |
| 2 | `02-runtime-core` | 🚧 NEXT | Implement `core/bin/chantier` POSIX-shell binary with `state append` and `validate-task`; write ADR 0002 specifying STATE.md format and CLI surface. |
| 3 | `03-skill-library` | ⏳ PLANNED | Author four reference skills (`using-git-worktrees`, `test-driven-development`, `requesting-code-review`, `subagent-driven-development`) with PRESSURE.md each. |
| 4 | `04-claude-code-adapter` | ⏳ PLANNED | Build `adapters/claude-code/` that stages dossiers and dispatches subagents per ADR 0001. |
| 5 | `05-dogfood-e2e` | ⏳ PLANNED | Use Chantier-on-Chantier to plan one small feature, execute it end-to-end with one shipped skill, surface gaps, record as integration test. |

## Post-v0.1.0 visibility (not commitment)

| Phase | Target milestone | Why later |
|---|---|---|
| Second harness adapter (Codex CLI or Cursor) | v0.2.0 | Proves portability claim; not blocking for v0.1.0's utility. |
| `extract-skills-from-phase` self-improvement | v0.3.0 | Adds complexity v0.1.0 should not gate on. |
| `chantier.lock` skill version pinning | TBD | Deferred per ADR 0001; needs more skills to surface real pain. |
| `STATE.md` compaction | TBD | Premature; needs a real long-running project to learn the model. |

## Coverage check (every requirement maps to at least one phase)

- `FR-001`, `FR-003`, `FR-004` → Phase 2 (binary commands).
- `FR-002` → Phase 2 (the `new` command scaffolds `.planning/`).
- `FR-005`, `FR-006`, `FR-009`, `FR-010` → Phase 3.
- `FR-007` → already specified in ADR 0001 (Phase 1).
- `FR-008` → Phase 4.
- `NFR-001`–`NFR-006` → enforced throughout; verified in Phase 5 (dogfood E2E).
