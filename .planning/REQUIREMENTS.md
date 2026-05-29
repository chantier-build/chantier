---
project_id: chantier
milestone: v0.1.0
created: 2026-05-29
status: locked
---

# Requirements — Chantier v0.1.0

## Functional requirements

| ID | Requirement |
|---|---|
| FR-001 | `core/bin/chantier` exists as POSIX shell + jq, no harness-specific dependencies. |
| FR-002 | `chantier new <name>` scaffolds `.planning/` with empty `PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md`, `config.json`. |
| FR-003 | `chantier state append --event X --task Y --skill Z --summary "…"` appends exactly one event row to `STATE.md`. |
| FR-004 | `chantier validate-task <task>` checks `state_writes` containment, output schema presence, and acceptance-section presence; non-zero exit on failure. |
| FR-005 | `skills/<name>/` containing `SKILL.md`, `PRESSURE.md`, optional `run.sh` is the canonical unit of skill distribution. |
| FR-006 | `SKILL.md` front-matter conforms to the schema in ADR 0001 (`id`, `version`, `inputs_schema`, `state_reads`, `state_writes`, `outputs_schema`, `portable`, `harness_adapters`). |
| FR-007 | `PLAN.md` follows the schema in ADR 0001 (front-matter + YAML task blocks). |
| FR-008 | `adapters/claude-code/` exists and can stage a dossier for a task. |
| FR-009 | Four reference skills shipped: `using-git-worktrees`, `test-driven-development`, `requesting-code-review`, `subagent-driven-development`. |
| FR-010 | Each shipped skill includes a `PRESSURE.md` with at least two adversarial scenarios. |

## Non-functional requirements

| ID | Requirement |
|---|---|
| NFR-001 | Skill bodies contain no harness-specific identifiers; enforced by `chantier validate-task` portability grep. |
| NFR-002 | The `chantier` binary depends only on POSIX shell + jq. |
| NFR-003 | `STATE.md` is append-only; in-skill direct edits are a contract violation. |
| NFR-004 | The framework runs without network access except where a skill explicitly requires it. |
| NFR-005 | All public artifacts (README, docs, code, skill bodies, commit messages) are in English. |
| NFR-006 | License is MIT, copyright is collective (`Chantier Contributors`). No token, no SaaS lock-in. |

## Acceptance — v0.1.0 ships when

- All `FR-001`–`FR-010` are implemented and tested.
- All `NFR-001`–`NFR-006` hold.
- A non-trivial end-to-end demo exists as an integration test in `tests/e2e/`: a user creates a new project, plans a phase, executes one task via one shipped skill, verifies, and STATE.md records the events.
- ADR record contains ADR 0001 (state/skill contract), ADR 0002 (STATE.md format + binary spec), and at least one ADR resolving one of the four deferred questions from ADR 0001.

## Out of scope for v0.1.0

- Second harness adapter (deferred to v0.2.0).
- `extract-skills-from-phase` self-improvement skill (deferred to v0.3.0).
- `chantier.lock` skill version pinning (deferred — needs more skills to feel the pain).
- `STATE.md` compaction (deferred — needs a real long-running project to learn the right compaction model).
- Hosted services, dashboards, telemetry. (Out forever, not deferred.)
