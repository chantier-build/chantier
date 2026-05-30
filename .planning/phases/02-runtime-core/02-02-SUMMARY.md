---
phase: 02-runtime-core
plan: "02"
subsystem: schemas
tags: [json-schema, draft-07, validation, d-05, d-06, d-07]
dependency_graph:
  requires: [02-01]
  provides: [core/schemas/project.json, core/schemas/requirements.json, core/schemas/roadmap.json, core/schemas/plan.json, core/schemas/skill.json]
  affects: [02-05-validate-task, 02-06-adr-0002]
tech_stack:
  added: [json-schema-draft-07]
  patterns: [hybrid-strict-permissive-D05, keyword-subset-jq-validator]
key_files:
  created:
    - core/schemas/project.json
    - core/schemas/requirements.json
    - core/schemas/roadmap.json
    - core/schemas/plan.json
    - core/schemas/skill.json
  modified: []
decisions:
  - "roadmap.json required fields decided fresh (project_id, created, milestone, status) — current ROADMAP.md has no frontmatter; schema targets the chantier new scaffold (plan 02-05)"
  - "plan.json validates frontmatter only; task-block YAML validation lives in the chantier validate-task binary per ADR 0002 §Plan schema rationale"
  - "skill.json harness_adapters enum is the sole NFR-001 carve-out; documented in description field so plan 02-03 self-test grep can exclude this file"
metrics:
  duration: "< 15 minutes"
  completed: "2026-05-29"
  tasks_completed: 3
  tasks_total: 3
---

# Phase 02 Plan 02: JSON Schema files (draft-07) — Summary

## One-liner

Five JSON Schema draft-07 files authored under `core/schemas/` covering all canonical Chantier document types, using only the jq-validator keyword subset and additionalProperties: true (D-05 hybrid mode).

## What was built

### core/schemas/project.json

Validates `PROJECT.md` frontmatter per D-07. Required fields derived directly from `.planning/PROJECT.md` lines 1-10:

- `required`: `["project_id", "created", "license", "copyright", "status"]`
- `project_id`: slug pattern `^[a-z][a-z0-9-]*$`
- `created`: ISO-date pattern `^[0-9]{4}-[0-9]{2}-[0-9]{2}$`
- `license`: enum `["MIT"]` (NFR-006)
- `status`: enum `["draft", "active", "foundation_complete", "shipped", "archived"]` — `foundation_complete` included so existing PROJECT.md validates
- Optional declared properties (no required): `governance`, `primary_artifact`, `current_milestone`
- `additionalProperties: true` (D-05 hybrid)

### core/schemas/requirements.json

Validates `REQUIREMENTS.md` frontmatter per D-07. Required fields derived from `.planning/REQUIREMENTS.md` lines 1-6:

- `required`: `["project_id", "milestone", "created", "status"]`
- `status`: enum `["draft", "locked", "shipped"]` — `locked` is the current state
- `additionalProperties: true` (D-05 hybrid)

### core/schemas/roadmap.json

Schema decided fresh (current `.planning/ROADMAP.md` has no frontmatter — verified). Mirrors PROJECT.md shape for consistency; targets the `chantier new` scaffold in plan 02-05:

- `required`: `["project_id", "created", "milestone", "status"]`
- `milestone`: semver pattern `^v[0-9]+\.[0-9]+\.[0-9]+$`
- `status`: enum `["draft", "active", "completed", "archived"]`
- `additionalProperties: true` (D-05 hybrid)

### core/schemas/plan.json

Validates `PLAN.md` frontmatter per D-07. Required fields derived from `.planning/phases/01-foundation/PLAN.md` lines 1-12 and ADR 0001 Surface 1:

- `required`: `["plan_id", "phase", "created", "declared_skills"]`
- `plan_id`: pattern `^[0-9]{2}-[a-z][a-z0-9-]*$` (matches `01-foundation-bootstrap`)
- `phase`: pattern `^[0-9]{2}(\.[0-9]+)?-[a-z][a-z0-9-]*$` (matches `01-foundation`, `02.1-hotfix`)
- `declared_skills`: `type: array, items: {type: string}` — empty array valid (Phase 1 inline plan)
- Optional: `status`, `date_started`, `date_completed`, `duration_estimated`, `duration_actual`, `note`
- Top-level `description` field documents that task-block YAML is validated by `chantier validate-task` via awk extraction, not by this schema
- `additionalProperties: true` (D-05 hybrid)

### core/schemas/skill.json

Validates `SKILL.md` frontmatter per ADR 0001 Surface 2. All 8 required fields enforced:

- `required`: `["id", "version", "inputs_schema", "state_reads", "state_writes", "outputs_schema", "portable", "harness_adapters"]`
- `id`: slug pattern `^[a-z][a-z0-9-]*$`
- `version`: semver pattern `^[0-9]+\.[0-9]+\.[0-9]+$`
- `inputs_schema`: `type: object` (forward-compat; strictness deferred per ADR 0001 open question 3)
- `state_reads`, `state_writes`: `type: array, items: {type: string}`
- `outputs_schema`: `type: object` (forward-compat)
- `portable`: `type: boolean`
- `harness_adapters`: array of strings with enum `["claude-code", "cursor", "codex-cli", "copilot-cli", "gemini-cli", "opencode"]` — exactly 6 known harnesses
- NFR-001 carve-out documented in `description` field: harness names appear here only to constrain skill metadata, not to invoke harness tooling
- `additionalProperties: true` (D-05 hybrid)

## Verification

All five schemas pass `jq empty`:

```
PASS: core/schemas/project.json
PASS: core/schemas/requirements.json
PASS: core/schemas/roadmap.json
PASS: core/schemas/plan.json
PASS: core/schemas/skill.json
```

No harness identifiers appear outside `skill.json`'s `harness_adapters.items.enum` array (confirmed by grep).

## Dogfood frontmatter validation (eyeball check — validate-task not yet wired)

| In-repo file | Schema | Would validate? | Notes |
|---|---|---|---|
| `.planning/PROJECT.md` | `project.json` | Yes | `status: foundation_complete` is in the enum; all 5 required fields present |
| `.planning/REQUIREMENTS.md` | `requirements.json` | Yes | `status: locked` is in the enum; all 4 required fields present |
| `.planning/phases/01-foundation/PLAN.md` | `plan.json` | Yes | `plan_id: 01-foundation-bootstrap` matches slug pattern; `phase: 01-foundation` matches; `created: 2026-05-29` matches ISO date; `declared_skills: []` matches empty array |

## Commits

| Task | Commit | Files |
|---|---|---|
| Task 1 | `167ca97` | core/schemas/project.json, core/schemas/requirements.json |
| Task 2 | `8479aac` | core/schemas/roadmap.json, core/schemas/plan.json |
| Task 3 | `f8ff672` | core/schemas/skill.json |

## Deviations from Plan

None — plan executed exactly as written.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries introduced by this plan. All files are static JSON under `core/schemas/` — author-controlled, version-controlled per T-02-02-DOS threat mitigation (no user-supplied regex; all patterns are linear-time anchored character classes).

## Self-Check: PASSED

- [x] `core/schemas/project.json` exists and passes `jq empty`
- [x] `core/schemas/requirements.json` exists and passes `jq empty`
- [x] `core/schemas/roadmap.json` exists and passes `jq empty`
- [x] `core/schemas/plan.json` exists and passes `jq empty`
- [x] `core/schemas/skill.json` exists and passes `jq empty`
- [x] Commits 167ca97, 8479aac, f8ff672 exist in git log
- [x] `additionalProperties: true` at top level in all 5 files
- [x] `skill.json` required array contains all 8 ADR 0001 Surface 2 fields
- [x] No harness identifiers outside `skill.json`'s `harness_adapters.items.enum`
- [x] No keyword outside the supported subset in any file
