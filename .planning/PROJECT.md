---
project_id: chantier
created: 2026-05-29
license: MIT
copyright: Chantier Contributors
governance: org chantier-build (multi-Owner target)
primary_artifact: framework
current_milestone: v0.1.0
status: skill_library_complete
---

# Chantier — Project Charter

## Vision (one sentence)

A long-haul build framework for AI coding agents that synthesizes persistent macro state (GSD tradition) with disciplined micro skills (Superpowers tradition), portable across the major harnesses without depending on session-injected context.

## Why this project must exist

The 2025–2026 ecosystem of spec-driven / context-engineering frameworks split into two complementary-but-disjoint traditions: state-machine frameworks (GSD-style) hold long-term project context but ignore per-task discipline; skill-library frameworks (Superpowers-style) enforce per-task discipline but lose multi-day continuity. A serious developer working on a multi-week project today either picks one and patches the other half by hand, or runs both and reconciles them every morning. Chantier exists to close that gap with a single file-readable contract (ADR 0001) that binds the two halves.

The full thesis is in `docs/vision.md`.

## Target user

A developer working on a multi-day or multi-week project with an AI coding agent, who needs context to survive session boundaries **and** wants TDD / code-review discipline applied per task. Explicitly **not** for trivial single-session work.

## Out of scope (forever)

- Tokens, cryptocurrency, or any monetary primitive (the original GSD lesson).
- SaaS lock-in. Chantier runs locally.
- Replacing the underlying AI coding harness. Chantier sits above Claude Code / Cursor / Codex, not in their place.
- Trivial work (< one day). The macro layer is dead weight for one-off scripts.

## Success criteria — v0.1.0

Defined in detail in `.planning/REQUIREMENTS.md`. Summary:

1. [x] `core/bin/chantier` POSIX shell binary exists with `state append` and `validate-task` commands. (Phase 2)
2. [x] `chantier new <name>` scaffolds `.planning/`. (Phase 2)
3. [x] At least four reference skills shipped with PRESSURE.md. (Phase 3 — using-git-worktrees, test-driven-development, requesting-code-review, subagent-driven-development)
4. [ ] Claude Code harness adapter works end-to-end. (Phase 4)
5. [ ] Chantier's own development is managed by Chantier (`.planning/` populated and updated through phases). (Phase 5 dogfood)

## Long-term thesis

See `docs/vision.md`. The short version: macro continuity and micro discipline are not in tension — they are two halves of the same problem, unified by an explicit, file-readable contract.
