# ADR 0002 — Runtime binary and state format

- **Status:** Accepted
- **Date proposed:** 2026-05-30
- **Date accepted:** 2026-05-30
- **Deciders:** Chantier founding contributors
- **Supersedes:** —
- **Superseded by:** —

> This ADR codifies the runtime format and binary contract established by plans 02-01 through 02-05. Once accepted, downstream tooling can depend on these schemas at version 0.1.0. Every decision locked in CONTEXT.md (D-01 through D-13) is formally ratified here; two Claude's Discretion items are revised; and two new sub-profiles (frontmatter subset, JSON Schema subset) are formally introduced.

---

## Context

Three findings force this ADR:

1. **NFR-002 caps the trust surface at `sh` + `jq`.** No external runtime may be added as a dependency for the core binary. This rules out `ajv` (Node.js), `check-jsonschema` (Python), `yq` (Go), and any other binary not already present in a POSIX base system.

2. **`flock(1)` is absent on macOS Darwin.** Direct environment probe on 2026-05-29 confirms: the `flock` command is not available on the host macOS system. The original Claude's Discretion item #4 in CONTEXT.md ("flock with macOS BSD / Linux util-linux compat wrapper") is not implementable — there is no portable compat wrapper because the command does not exist. This ADR supersedes that item with the mkdir-mutex pattern.

3. **No pure-jq JSON Schema draft-07 validator exists.** jqlang/jq issue #3437 confirms this gap. Draft-07 full compliance inside jq is not achievable; Chantier must define and document a constrained keyword subset that the binary actually enforces.

Three findings from Phase 1 that Phase 2 was tasked to close (per `.planning/phases/01-foundation/SUMMARY.md` §"Validation of ADR 0001 schema"):

4. **STATE.md format was unspecified.** The foundation phase used a Markdown table with format_version 0.1.0-interim, explicitly pending finalization in ADR 0002.

5. **Frontmatter JSON Schemas were absent.** Phase 1 shipped the planning documents but no machine-readable schemas for their frontmatter. Phase 2 defines all five.

6. **Event vocabulary was oral history.** The dotted-namespace convention was described in ADR 0001 and STATE.md rows but never formally specified with a shape regex. This ADR codifies the regex.

---

## Decision

### STATE.md JSONL format

Per D-01 and D-02: `STATE.md` body is JSON Lines (one JSON object per line, append-only, no row deletion or in-place mutation). Each line has exactly this shape:

```
{"ts":"<ISO-8601 UTC>","event":"<dotted-name>","actor":"<string>","task":<string|null>,"skill":<string|null>,"summary":"<string>","refs":[<string>,...]}
```

Field definitions:

| Field | Type | Description |
|-------|------|-------------|
| `ts` | string (ISO-8601 UTC) | Timestamp of the event. |
| `event` | string (dotted-namespace) | Machine-readable event name. Shape enforced by regex (see §Event taxonomy). |
| `actor` | string | The git `user.name` of the agent or human who produced the event. Falls back to `"unknown"` when `git config user.name` returns empty (see §Actor fallback). |
| `task` | string or null | The canonical task identifier within the current plan, if applicable. Null for events not tied to a specific task. |
| `skill` | string or null | The skill invoked for this task, if applicable. Null for infrastructure events. |
| `summary` | string | Human-readable description of what happened. |
| `refs` | array of strings | File paths, commit hashes, URLs, or other references. Empty array when no refs apply. |

The frontmatter block that precedes the JSONL body:

```yaml
---
project_id: chantier
created: 2026-05-29
format_version: 0.1.0
format_note: |
  STATE.md body is JSON Lines, append-only, one event per line.
  Mutation is allowed only via `chantier state append`.
---
```

The `format_version` field is `0.1.0` (migrated from `0.1.0-interim` in a dedicated commit per D-04).

### Actor field fallback

Per RESEARCH Pitfall 9 and Assumption A6: when `git config user.name` returns an empty string (CI, fresh worktree, or detached HEAD scenarios), the `actor` field is set to the literal string `"unknown"`. This is the v0.1 convention. A future version may distinguish `"unknown"` (no git config) from `"ci"` (CI environment detected) from `"system"` (automated system event); that distinction is deferred to a v0.2 revisit (see §Open questions, item 6).

### Event taxonomy and shape regex

Per D-08, D-09, D-10: event names are dotted-namespace strings validated against the shape regex:

```
^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$
```

This regex is enforced **twice** by the binary: once with a shell `case` glob (cheap, early rejection) and once with jq `test()` (authoritative). The binary rejects any event that fails either check with exit code 1 (contract violation).

The binary enforces **shape only** — not vocabulary. The following event namespaces are indicative; new namespaces may be added by any authorized producer without requiring an ADR revision:

| Namespace | Indicative events |
|-----------|------------------|
| `bootstrap` | `bootstrap.session.started`, `bootstrap.harness.chosen` |
| `adr` | `adr.accepted`, `adr.status.updated` |
| `phase` | `phase.completed`, `phase.next.declared`, `phase.context.gathered` |
| `task` | `task.started`, `task.completed`, `task.blocked` |
| `skill` | `skill.invoked`, `skill.completed`, `skill.failed` |
| `scaffold` | `scaffold.committed` |
| `repo` | `repo.published` |
| `github` | `github.org.created` |
| `research` | `research.completed` |
| `plan` | `plan.completed`, `plan.started` |

### Frontmatter subset profile

Chantier validates a YAML **subset**, not arbitrary YAML. The awk-based frontmatter extractor (`extract_frontmatter_as_json()` in `core/bin/chantier`) implements this constraint; the constraint must be stated explicitly so skill authors know what shapes are safe.

**Allowed** in Chantier frontmatter:
- Top-level scalar values: strings, numbers, booleans.
- Simple lists: arrays where every item is a scalar.

**Not allowed** in Chantier frontmatter:
- Nested maps (objects as values of top-level keys).
- Multi-line block scalars beyond the `format_note` pattern already established.
- YAML anchors and references (`&anchor`, `*alias`).

This constraint is justified by NFR-002: a portable awk+jq extractor that handles this subset is implementable in ~20 lines of POSIX awk. Full YAML parsing (supporting nested maps, anchors, merge keys) would require `yq` or a comparable binary, which is forbidden.

Skill authors who need structured metadata beyond this subset should serialize it as a JSON string value within the frontmatter scalar, or split it into a companion JSON file.

### JSON Schema subset profile

Chantier validates a JSON Schema draft-07 **profile**, not the full draft-07 specification. The inline jq validator (`validate_against_schema()` in `core/bin/chantier`) implements this profile; the profile is documented here to prevent user confusion.

**Supported keywords** (enforced by the validator):
- `type` — enforces the JSON type of the value.
- `required` — enforces presence of listed keys (strict; missing required key → exit 1).
- `properties` — maps key names to sub-schemas (recursive, within the supported keywords).
- `additionalProperties` — when `false`, rejects keys not in `properties`; when `true` (or omitted), permits them with a warning.
- `pattern` — validates string values against a regex.
- `enum` — validates that a value appears in the allowed list.
- `items` — validates each element of an array against a sub-schema.

**NOT supported** (silently ignored by the validator):
- `$ref`, `$defs`, `definitions` — no reference resolution.
- `oneOf`, `anyOf`, `allOf`, `not` — no combinatorial logic.
- `if` / `then` / `else` — no conditional schemas.
- `format` — no semantic format validation (e.g., `"format": "email"` is ignored).
- `minimum`, `maximum`, `multipleOf` — no numeric range validation.
- `minLength`, `maxLength`, `minItems`, `maxItems` — no length constraints.

The trade-off is intentional and justified by NFR-002: implementing the supported subset in jq takes ~60 lines; implementing the full draft-07 spec would take thousands of lines and cannot fit in a single-file binary without external dependencies.

ADR 0002 explicitly designates all five shipped schemas as conforming to this profile — they use only the supported keywords. Any schema that uses unsupported keywords will silently ignore those constraints at runtime; authors must verify their schemas stay within the profile.

### Schemas (inline)

The following five schemas are the canonical versions as of v0.1.0. They are quoted byte-for-byte from `core/schemas/*.json` at ship time. Any drift between these blocks and the on-disk files is a defect tracked as T-02-06-DRIFT; Open Question 5 in §Open questions proposes automating this drift check via `--self-test`.

#### project.json — PROJECT.md frontmatter

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://chantier.build/schemas/v0.1.0/project.json",
  "title": "Chantier PROJECT.md frontmatter (v0.1.0 profile)",
  "type": "object",
  "required": ["project_id", "created", "license", "copyright", "status"],
  "properties": {
    "project_id": {
      "type": "string",
      "pattern": "^[a-z][a-z0-9-]*$"
    },
    "created": {
      "type": "string",
      "pattern": "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
    },
    "license": {
      "type": "string",
      "enum": ["MIT"]
    },
    "copyright": {
      "type": "string"
    },
    "status": {
      "type": "string",
      "enum": ["draft", "active", "foundation_complete", "shipped", "archived"]
    },
    "governance": {
      "type": "string"
    },
    "primary_artifact": {
      "type": "string"
    },
    "current_milestone": {
      "type": "string"
    }
  },
  "additionalProperties": true
}
```

#### requirements.json — REQUIREMENTS.md frontmatter

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://chantier.build/schemas/v0.1.0/requirements.json",
  "title": "Chantier REQUIREMENTS.md frontmatter (v0.1.0 profile)",
  "type": "object",
  "required": ["project_id", "milestone", "created", "status"],
  "properties": {
    "project_id": {
      "type": "string",
      "pattern": "^[a-z][a-z0-9-]*$"
    },
    "milestone": {
      "type": "string"
    },
    "created": {
      "type": "string",
      "pattern": "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
    },
    "status": {
      "type": "string",
      "enum": ["draft", "locked", "shipped"]
    }
  },
  "additionalProperties": true
}
```

#### roadmap.json — ROADMAP.md frontmatter

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://chantier.build/schemas/v0.1.0/roadmap.json",
  "title": "Chantier ROADMAP.md frontmatter (v0.1.0 profile)",
  "type": "object",
  "required": ["project_id", "created", "milestone", "status"],
  "properties": {
    "project_id": {
      "type": "string",
      "pattern": "^[a-z][a-z0-9-]*$"
    },
    "created": {
      "type": "string",
      "pattern": "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
    },
    "milestone": {
      "type": "string",
      "pattern": "^v[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "status": {
      "type": "string",
      "enum": ["draft", "active", "completed", "archived"]
    }
  },
  "additionalProperties": true
}
```

#### plan.json — PLAN.md frontmatter

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://chantier.build/schemas/v0.1.0/plan.json",
  "title": "Chantier PLAN.md frontmatter (v0.1.0 profile)",
  "description": "Validates PLAN.md frontmatter only. Task-block YAML is validated by chantier validate-task via inline awk extraction; see ADR 0002 §Plan schema for the rationale.",
  "type": "object",
  "required": ["plan_id", "phase", "created", "declared_skills"],
  "properties": {
    "plan_id": {
      "type": "string",
      "pattern": "^[0-9]{2}-[a-z][a-z0-9-]*$"
    },
    "phase": {
      "type": "string",
      "pattern": "^[0-9]{2}(\\.[0-9]+)?-[a-z][a-z0-9-]*$"
    },
    "created": {
      "type": "string",
      "pattern": "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
    },
    "declared_skills": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "status": {
      "type": "string",
      "enum": ["draft", "in_progress", "completed", "blocked"]
    },
    "date_started": {
      "type": "string"
    },
    "date_completed": {
      "type": "string"
    },
    "duration_estimated": {
      "type": "string"
    },
    "duration_actual": {
      "type": "string"
    },
    "note": {
      "type": "string"
    }
  },
  "additionalProperties": true
}
```

#### skill.json — SKILL.md frontmatter

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://chantier.build/schemas/v0.1.0/skill.json",
  "title": "Chantier SKILL.md frontmatter (v0.1.0 profile)",
  "description": "SKILL.md frontmatter schema per ADR 0001 Surface 2. The harness_adapters enum is the sole NFR-001 carve-out: harness names appear here only to constrain skill metadata, not to invoke harness tooling.",
  "type": "object",
  "required": ["id", "version", "inputs_schema", "state_reads", "state_writes", "outputs_schema", "portable", "harness_adapters"],
  "properties": {
    "id": {
      "type": "string",
      "pattern": "^[a-z][a-z0-9-]*$"
    },
    "version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "inputs_schema": {
      "type": "object"
    },
    "state_reads": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "state_writes": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "outputs_schema": {
      "type": "object"
    },
    "portable": {
      "type": "boolean"
    },
    "harness_adapters": {
      "type": "array",
      "items": {
        "type": "string",
        "enum": ["claude-code", "cursor", "codex-cli", "copilot-cli", "gemini-cli", "opencode"]
      }
    }
  },
  "additionalProperties": true
}
```

Note on the `harness_adapters` enum in `skill.json`: the six harness identifiers `"claude-code"`, `"cursor"`, `"codex-cli"`, `"copilot-cli"`, `"gemini-cli"`, `"opencode"` appear here solely to constrain skill metadata — they do not invoke harness tooling. This is the sole NFR-001 carve-out for harness identifiers in the core schemas.

### Hybrid strict/permissive validation

Per D-05: required field presence is **strict** — a YAML frontmatter document missing any key listed in `required` is rejected with exit code 1 (contract violation). Unrecognized top-level keys are **permissive** — `additionalProperties: true` in every schema permits forward-compatible metadata additions. The validator emits a warning to stderr for any top-level key not listed in `properties`, but does not reject the document.

This hybrid mode allows skill authors to add metadata fields to their frontmatter without breaking existing validation, while still catching typos in required field names (e.g., `plan-id` instead of `plan_id`).

### Concurrency: mkdir-mutex with stale-PID detection

Per D-Discretion #4, REVISED by RESEARCH §"Claude's Discretion review" row 4: the original concurrency mechanism specified in CONTEXT.md ("flock with macOS BSD / Linux util-linux compat wrapper") is **superseded by this ADR**. The reason: `flock(1)` is absent on macOS Darwin — direct environment probe confirms this. No portable compat wrapper is possible because the command does not exist on the target platform.

The approved concurrency mechanism is the **mkdir-mutex pattern with stale-PID detection**:

1. `acquire_lock()` attempts to create a lockdir atomically (`mkdir LOCKDIR`). If mkdir succeeds, the lock is held; write the current PID to `LOCKDIR/pid`.
2. On contention (mkdir fails), read the PID from `LOCKDIR/pid` and test with `kill -0 PID`. If the process no longer exists, the lock is stale — recover by `rm -rf LOCKDIR` and retry.
3. If the holding process is alive, sleep and retry up to a configurable limit (default: 5 retries, 0.5s sleep). On retry exhaustion, exit 2 (runtime error).
4. On lock acquisition, arm a `trap` to release the lock on EXIT, INT, TERM, HUP signals. The current shell is never placed inside a pipeline while holding the lock (avoiding the subshell issue where the trap doesn't fire).

This pattern is canonical per the bash-hackers wiki mutex howto (https://bash-hackers.gabe565.com/howto/mutex/). It is POSIX-compliant, portable across macOS, Linux, and BSD, and requires only `mkdir`, `kill`, `rm`, and `sleep` — all POSIX baseline.

The lockdir is placed at `"${STATE_FILE}.lock"` relative to the STATE.md being modified. It is never committed to git (the `.gitignore` entry for `.chantier/` covers it if the default STATE.md path is used).

### Exit-code matrix

Per D-Discretion §"Error model":

| Exit code | Meaning | When |
|-----------|---------|------|
| 0 | Success | Normal completion. |
| 1 | Contract violation | Validation failed: event name fails shape regex; required schema field missing; acceptance criteria not found in output.md; portable skill contains a harness identifier. |
| 2 | Runtime error | Missing dependency (jq not found); write failure; lock contention after retries exhausted. |
| 3 | Usage error | Unknown subcommand; missing required flag; unrecognized flag. |

`--json-errors` is a top-level flag parsed **before** subcommand dispatch. When set, error messages are emitted to stderr as JSON objects (`{"error": "...", "code": N}`) instead of plain text. This allows programmatic callers to parse error detail without screen-scraping.

### Self-test gates

Per D-Discretion #11, REVISED by RESEARCH §"Claude's Discretion review" row 11: the original self-test check "flock available" is replaced with "mkdir-lock works" (same reason as the concurrency revision above). The self-test (`chantier --self-test`) verifies:

1. `jq` is present and executable.
2. All five schemas at `core/schemas/*.json` parse as valid JSON (`jq empty`).
3. `STATE.md` (if it exists at `.planning/STATE.md`) has `format_version: 0.1.0` in its frontmatter.
4. The mkdir-lock mechanism works: create a test lockdir, verify it is held, release it.
5. The binary source (the running `$0` file) contains no harness identifier from the deny-list (`mcp__`, `claude_ai_`, `@codebase`, `claude-code`, `cursor`, `codex-cli`, `copilot-cli`, `gemini-cli`, `opencode`). This is the "harness-deny-list-in-self" check added per RESEARCH recommendation.
6. The binary source contains no CRLF line endings (verified via `file $0 | grep -v CRLF`). This is the "no-CRLF-in-self" check added per RESEARCH recommendation.
7. All subcommands respond to `--help` with exit 0.

Checks 5 and 6 were added to prevent portability regressions that caused repeated pain during Phase 2 development. They are zero-cost: both run in under 100ms on any POSIX system.

### Migration

Per D-04: the migration of the existing `STATE.md` from Markdown table (format_version 0.1.0-interim) to JSONL (format_version 0.1.0) happens in a **dedicated git commit**. No permanent `chantier state migrate` subcommand is shipped.

Migration approach:
1. All 10 existing Markdown table rows are converted to JSONL objects following the per-row mapping rule in PATTERNS.md: `timestamp` → `ts`, `event` → `event`, `actor` → `actor`, `summary` → `summary`, `refs` → one-element or multi-element array; `task` and `skill` are `null` for all historical rows (Phase 1 events carried no task or skill association).
2. The frontmatter `format_version` is bumped from `0.1.0-interim` to `0.1.0`. The `format_note` body is updated to describe JSONL.
3. The migration commit message includes the pre-migration Markdown table verbatim in a quoted block (per RESEARCH Open Question 2). No `.bak` file is committed; git history is the backup.
4. After the migration commit, one additional event is appended via `chantier state append` (not by hand), proving the binary works on the migrated file.

This migration is non-reversible by design. The JSONL format is the permanent format for STATE.md going forward.

---

## Consequences

### Positive

- **Machine-friendly event log.** JSONL is parseable with `jq` in one pass, greppable with `grep`, and diffable line-by-line. Downstream tooling in Phase 3+ can query event history without parsing Markdown.
- **Deterministic schemas at version 0.1.0.** The five schemas are pinned, documented, and inline in this ADR. Phase 3 skill authors have a stable contract to author against.
- **Portable across macOS, Linux, and BSD.** The mkdir-mutex replaces the macOS-absent `flock` with a POSIX-baseline mechanism. The binary runs identically on all three families.
- **Trust surface stays at `sh` + `jq`.** NFR-002 is satisfied. No additional dependency is required for core binary operation.
- **Dogfood from day one.** The migration and first `phase.completed` append are performed using the binary itself, proving round-trip correctness on real historical data.

### Negative / costs

- **Hand-rolled subset validators are Chantier-specific code.** The jq schema validator and the awk frontmatter extractor are not off-the-shelf tools. If the supported keyword subset proves too narrow for Phase 3+ skill authors, the validator must be extended — and every extension must be tested and documented.
- **Frontmatter subset prohibits legitimate YAML idioms.** Skill authors cannot use nested maps in frontmatter. This is a real constraint. Authors who need structured configuration must serialize it as a JSON string or use a companion file.
- **Non-standard JSON Schema subset risks user confusion.** A user who writes a schema using `oneOf` or `$ref` will get no validation error from the binary — the keywords are silently ignored. ADR 0002 cannot be summarized as "we validate JSON Schema" without the qualifier "draft-07 profile as documented here."

### Neutral / deferred

- **The indicative event taxonomy is non-binding.** Event names are validated by shape, not by vocabulary. New namespaces can be introduced by any authorized producer without requiring an ADR revision. This is intentional for discoverability.
- **STATE.md compaction remains out of scope.** The append-only log grows unboundedly in v0.1. The compaction question is deferred (see §Open questions, item 2).

---

## Alternatives considered

### A. Markdown table for STATE.md (status quo)

**Rejected** per D-01. Markdown tables are human-readable but not reliably machine-parseable without ad-hoc escaping. A single summary that contains a pipe character (`|`) breaks every naive table parser. Downstream tools cannot depend on the column shape. JSONL is greppable, diffable, and parseable with standard tools.

### B. `flock(1)` for concurrency

**Rejected.** `flock` is absent on macOS Darwin — confirmed by direct environment probe (2026-05-29). No portable compat wrapper is possible because the command does not exist on the target platform. The mkdir-mutex achieves the same safety guarantee using only POSIX baseline tools.

### C. `ajv` CLI shellout for schema validation

**Rejected.** Shelling out to `ajv` requires Node.js, which violates NFR-002 (the trust surface must stay at `sh` + `jq`). The supported keyword subset covers every keyword used in the five v0.1.0 schemas; full draft-07 compliance is not required at this stage.

### D. `yq` for YAML frontmatter parsing

**Rejected.** `yq` is a Go binary that violates NFR-002. An awk+jq frontmatter extractor for the documented subset is implementable in ~20 lines of POSIX awk — no additional binary needed.

### E. Full JSON Schema draft-07 implementation in jq

**Rejected.** A complete draft-07 implementation would require thousands of lines of jq. The single-file binary constraint (NFR-002) makes this impractical. The supported keyword subset covers all five v0.1.0 schemas; the subset profile is formally documented in §JSON Schema subset profile so users understand the limitation.

### F. Permanent `chantier state migrate` subcommand

**Rejected.** No version upgrade story exists for v0.1. Testing a phantom version matrix is premature. The migration is a one-shot operation committed to git history, with the pre-migration table preserved verbatim in the commit body. If a future version requires a new format, the migration path will be designed at that time.

---

## Open questions (intentionally deferred)

The following four questions were explicitly deferred in ADR 0001 §"Open questions (intentionally deferred)". This ADR does **not** address them. They remain open:

1. **Versioning skills across breaking changes.** Semver in front-matter is the obvious answer, but who pins versions in `PLAN.md`? Probably a `chantier.lock` file. Deferred to a later ADR. *(From ADR 0001, item 1, verbatim.)*

2. **`STATE.md` compaction.** When does append-only become unmanageable? At what threshold do we cut a milestone-end snapshot? Deferred. *(From ADR 0001, item 2, verbatim.)*

3. **`inputs_schema` strictness mode.** `inputs_schema` is declared but who enforces it? Could be JSON Schema with `ajv` shelled out; could be looser. Deferred until we have three concrete skills. *(From ADR 0001, item 3, verbatim.)*

4. **Skill-to-skill composition syntax.** Can a skill invoke another skill? If yes, how does that interact with the dossier model? Likely yes-via-subtasks, but designing the syntax is premature. *(From ADR 0001, item 4, verbatim.)*

Two new questions surfaced by Phase 2 research but not blocking v0.1:

5. **Should `--self-test` compare ADR 0002 inline schemas with `core/schemas/*.json` byte-for-byte?** A drift-detection check in self-test would catch T-02-06-DRIFT automatically without a human audit. Deferred pending decision on whether the self-test should be schema-aware or content-agnostic. *(RESEARCH §"Claude's Discretion review" row 2.)*

6. **Should `actor` fallback be `"unknown"`, `"ci"`, or `"system"`?** The v0.1 convention is `"unknown"` when `git config user.name` returns empty. A v0.2 revisit could distinguish CI environments (via `CI` environment variable) from system-automated events. *(RESEARCH Assumption A6.)*

---

## Approval

This ADR codifies the runtime format and binary contract established by plans 02-01 through 02-05. Once accepted, downstream tooling can depend on these schemas at version 0.1.0. Phase 3 skill authors have a stable contract.

- [x] Approved by founding contributors in the bootstrap session, 2026-05-30.
- [x] Specific decisions ratified: D-01 through D-13 from CONTEXT.md; mkdir-mutex replacing flock per REVISED Discretion #4; expanded self-test gates per REVISED Discretion #11; frontmatter subset profile (top-level scalars + simple lists); JSON Schema subset profile (7 supported keywords, explicit NOT-supported list); JSONL STATE.md format with one-shot migration; actor fallback to `"unknown"`.
- Four ADR-0001 open questions explicitly re-flagged as still deferred: skill versioning and lockfile, STATE.md compaction, inputs_schema strictness, skill-to-skill composition syntax.
