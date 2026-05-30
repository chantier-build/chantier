# Phase 2: Runtime core - Context

**Gathered:** 2026-05-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 2 ships the first runtime artifact of Chantier: a portable `core/bin/chantier` POSIX shell + jq binary exposing `state append`, `validate-task`, and `new <name>` subcommands; and publishes ADR 0002 codifying the `STATE.md` format, the JSON Schemas for the five front-matter document types (`PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `PLAN.md`, `SKILL.md`), and the controlled-vocabulary convention for `STATE.md` events.

Phase 2 does **not** ship: skill bodies (Phase 3), the Claude Code adapter (Phase 4), an end-to-end dogfood test (Phase 5), a second harness adapter (v0.2.0), `chantier.lock` skill version pinning (v0.3.0), or `STATE.md` compaction (post-v0.1).

</domain>

<decisions>
## Implementation Decisions

### STATE.md format (ADR 0002 core decision)
- **D-01:** `STATE.md` body is **JSON Lines**. One event per line, one JSON object per event, append-only. Aligns with ADR 0001's explicit goal that state be "inspectable with cat / jq / grep" and gives downstream tools a parser-stable interface without ad-hoc Markdown escaping.
- **D-02:** Schema of each line: `{ "ts": <ISO-8601 UTC string>, "event": <dotted-name string>, "actor": <string>, "task": <string|null>, "skill": <string|null>, "summary": <string>, "refs": [<string>...] }`. `task`/`skill` are nullable for non-task events (e.g. `bootstrap.session.started`, `adr.accepted`).
- **D-03:** Ship a `chantier state show` companion subcommand that renders the JSONL body as a fixed-width column table for human reading. This is the substitute for losing the Markdown-table skim experience.
- **D-04:** Migration: convert the existing 10 rows in `.planning/STATE.md` (currently Markdown table, `format_version: 0.1.0-interim`) to JSONL in a dedicated commit at Phase 2 ship time. Bump frontmatter `format_version` to `0.1.0`. Commit message must document the migration explicitly.

### Front-matter JSON Schema strictness
- **D-05:** Validation model is **hybrid strict/permissive**: every field declared `required` in the schema is validated strictly (typo → rejection); every other field is permitted (additionalProperties allowed), with a warning emitted for unknown top-level keys. Catches load-bearing typos while leaving room for skill authors to add forward-compatible metadata without an ADR each time.
- **D-06:** Schemas live in `core/schemas/{project,requirements,roadmap,plan,skill}.json` as canonical JSON Schema draft-07 documents. ADR 0002 quotes them inline as the spec-of-record; the JSON files are the runtime-importable artefacts consumed by `chantier validate-task`.
- **D-07:** Required fields per schema are derived from ADR 0001 Surface 1 (PLAN.md, SKILL.md) and from current usage in `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`. ADR 0002 must enumerate them and freeze them for v0.1.

### Event taxonomy
- **D-08:** STATE.md event names follow a documented **dotted-namespace convention** `{noun}.{verb}` (e.g. `task.completed`, `phase.completed`, `adr.accepted`, `bootstrap.session.started`). No closed registry is enforced at runtime; teams add new event types as they emerge.
- **D-09:** `chantier state append --event X` validates the *shape* of `X` against the regex `^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$` and rejects anything that doesn't match. This enforces the convention without locking the vocabulary.
- **D-10:** ADR 0002 publishes an indicative (non-exhaustive) list of recommended events grouped by namespace: `bootstrap.*`, `adr.*`, `phase.*`, `task.*`, `skill.*`, `scaffold.*`, `repo.*`, `github.*`. The list documents intent; the binary does not check membership.

### `chantier new <name>` scaffold
- **D-11:** Scaffold produces commented stubs, not empty files and not example-filled templates. Each generated file in `.planning/` contains:
  - The minimal mandatory YAML frontmatter for that document type (per the schema from D-06).
  - One to three empty section headings (`## Vision`, `## Functional requirements`, etc.) following the patterns established in this repo's `.planning/PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`.
  - Inline HTML comments (`<!-- TODO: ... -->`) guiding the first edit without pre-deciding content.
- **D-12:** Scaffold output is **English only** for v0.1 (NFR-005 applies to runtime artefacts produced by `chantier`, not only to public docs). i18n hook deferred.
- **D-13:** Scaffold files produced: `PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md`, `config.json`. The `STATE.md` produced is JSONL-empty (no header lines, ready for first `state append`); frontmatter is in the file's YAML opener as in `.planning/STATE.md`.

### Claude's Discretion
The following are implementation-level decisions made by Claude in the absence of user preference. Planner and researcher may refine.

- **Concurrency** — `chantier state append` wraps its append operation in `flock(1)` with a portable wrapper handling the macOS BSD / Linux util-linux flock interface differences. Locking is essential because Phase 4 will dispatch Claude Code subagents in parallel; without serialization, concurrent appends would corrupt the JSONL stream.
- **Argument parsing** — Strictly POSIX-compatible style: `chantier state append -e <event> -t <task> -s <skill> -m <summary> -r <ref> [-r <ref>...]`. Short flags only (no GNU `--long-form`) to keep the binary auditable as pure POSIX shell.
- **Test framework** — `bats-core` for unit tests of the binary. Tests live in `core/tests/` and run via the system `bats` CLI. `bats-core` is itself a POSIX-portable bash test framework; using it does not violate FR-001 because tests are not shipped runtime code.
- **Binary structure** — Single-file `core/bin/chantier` script with a `case "$1" in` dispatch on the subcommand and one shell function per subcommand. No sourcing of helper files: distribution is one chmod +x file. Keeps the trust surface small (NFR-002).
- **`validate-task` portability grep deny-list** — Hardcoded for v0.1: `mcp__`, `claude_ai_`, `@codebase`, the literal harness names `claude-code`, `cursor`, `codex-cli`, `copilot-cli`, `gemini-cli`, `opencode` (all forbidden in skill body files when `portable: true`). Configurability deferred to v0.2 when more harnesses exist.
- **Error model** — Exit codes: `0` success, `1` contract violation (validation failed), `2` runtime error (missing dependency, write failure), `3` usage error (bad flags). Errors emit JSON on stderr when `--json-errors` is passed, plain text otherwise. Matches the pattern used by `gsd-tools.cjs` for adapter-friendliness.
- **`output.md` Acceptance section** — `chantier validate-task` looks for a heading matching the regex `^##\s+Acceptance\s*$` in `output.md` (case-sensitive). The body following the heading must contain one bullet or numbered item per acceptance criterion declared in the PLAN.md task block.
- **Self-test** — `chantier --self-test` (no subcommand) runs an internal sanity check (jq present, flock available, schemas parse, all subcommands respond to `--help`). Useful for adapter installations to gate readiness.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Founding contract (load-bearing)
- `docs/adr/0001-state-skill-contract.md` — the three surfaces (PLAN declares skills, skill reads dossier, skill writes state) and the five validation gates that `chantier validate-task` implements. Every binary behavior must be traceable to this ADR.
- `docs/research/inheritance-map.md` — derives the constraints (POSIX, no harness identifiers, no in-memory state) from GSD redux + Superpowers + Superpowers issue #237.

### Phase scope and acceptance
- `.planning/ROADMAP.md` §Phase 2 — phase goal, dependencies, success criteria 1–5.
- `.planning/REQUIREMENTS.md` — FR-001 through FR-004 (Phase 2 functional requirements), NFR-001 through NFR-006 (apply to every phase but enforced first here).
- `.planning/PROJECT.md` — out-of-scope-forever list (no tokens, no SaaS, no harness replacement); v0.1.0 success summary.

### Migration source data
- `.planning/STATE.md` — current interim Markdown-table state log (10 rows from Phase 1) that Phase 2 migrates to JSONL per D-04. Frontmatter `format_version: 0.1.0-interim` is the migration trigger.
- `.planning/phases/01-foundation/SUMMARY.md` — explicitly flags the three findings that Phase 2 must close: STATE.md format, front-matter JSON Schemas, event vocabulary. Read the "Validation of ADR 0001 schema" section.

### Out-of-scope reminders (deferred, do not implement in Phase 2)
- ADR 0001 §"Open questions (intentionally deferred)" — skill versioning + lockfile, STATE.md compaction, inputs_schema strictness, skill-to-skill composition. All four remain deferred; ADR 0002 must explicitly call out that it does not address them.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.planning/STATE.md` frontmatter (yaml) — the format-version + format-note pattern is reusable as the model for the ADR 0002 STATE.md frontmatter schema.
- `.planning/ROADMAP.md` frontmatter and section structure — provides the de facto template for what `chantier new` should generate for `ROADMAP.md`.
- `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md` — same: their current structure becomes the canonical template seeded by `chantier new`.

### Established Patterns
- **Frontmatter-first documents.** Every `.planning/` file leads with a YAML frontmatter block. JSON Schemas must validate frontmatter only — body is free-form Markdown.
- **Append-only event log.** `.planning/STATE.md` already enforces "no row deletion, no edits to historical rows" by convention. Phase 2 codifies it in the binary.
- **Collective attribution.** Existing rows in `STATE.md` use `MAoDzi` as actor; ADR 0002 should specify that `actor` is the git committer login (or `--actor` override) and document the value should be a stable identifier, not a real name.
- **No-network default.** `.gitignore` and `.planning/` content show no external API calls. `chantier` binary must respect NFR-004 by never reaching the network in any of its three subcommands.

### Integration Points
- **Phase 3 (Skill library):** the four reference skills will each include a `run.sh` that ends with `chantier state append`. Phase 2 must ship the binary discoverable on `PATH` after install (install instructions in README) so skill `run.sh` scripts can shell out portably.
- **Phase 4 (Claude Code adapter):** `adapters/claude-code/run-task.sh` will call `chantier validate-task` after each skill execution and `chantier state append` for the task lifecycle events. The adapter is the only file allowed to reference `claude-code` by name (NFR-001 carve-out); the binary itself must remain harness-agnostic.
- **Phase 5 (Dogfood E2E):** `tests/e2e/` will invoke `chantier new`, then the full Phase 2-built command surface. Test stability requires deterministic output: scaffold contents and exit codes must be byte-stable across runs.

### Empty directories awaiting Phase 2
- `core/` exists as a seed directory only. Phase 2 populates `core/bin/chantier`, `core/schemas/*.json`, `core/tests/` (bats).
- `skills/` exists but is empty (filled by Phase 3).
- `adapters/` does not yet exist — created by Phase 4.

</code_context>

<specifics>
## Specific Ideas

- The user explicitly wants the `chantier state show` rendering command (D-03) to compensate for losing Markdown-table skimmability. Researcher / planner should treat `state show` as a first-class subcommand on equal footing with `state append`, not as a developer afterthought.
- The user accepted JSONL with no hesitation when shown the preview side-by-side. The clean break migration (D-04) is preferred over a hybrid transition because the repo is in foundation phase and STATE.md has only 10 historical rows — the cost of a one-shot migration is minimal.
- "Convention libre" (D-08) was accepted over a closed registry because Phase 1 already produced sensible event names organically without enforcement. Locking the vocabulary too early would discourage downstream contributors from inventing legitimate new event types.

</specifics>

<deferred>
## Deferred Ideas

These were touched during discussion but explicitly deferred to keep Phase 2 focused:

- **STATE.md compaction strategy.** Append-only grows unboundedly; eventually a milestone-end snapshot mechanism will be needed. Already deferred by ADR 0001 §Open Questions #2. Re-flagged here; do not implement in Phase 2.
- **`chantier.lock` skill version pinning.** Same status: ADR 0001 §Open Questions #1. Useful once Phase 3 ships four skills and skill upgrades start happening; premature in Phase 2.
- **`inputs_schema` strictness mode.** ADR 0001 §Open Questions #3. Cannot be properly designed until three concrete skills exist. Phase 3 will surface the needs.
- **Skill-to-skill composition syntax.** ADR 0001 §Open Questions #4. No need until a skill wants to delegate to another skill; Phase 3 will tell us if and how.
- **Second harness adapter.** REQUIREMENTS §Out of scope for v0.1.0. Deferred to v0.2.0; revisit after Phase 4 lands the Claude Code adapter.
- **`chantier state compact`, `chantier state query`** convenience subcommands. Tempting to add but not required for v0.1.0 success criteria. If they emerge as obvious in Phase 5 dogfood, add to v0.2 backlog.
- **Long-flag (`--event`) aliases on subcommand args.** Possible v0.2 enhancement for ergonomics; v0.1 stays strictly POSIX short-flag.
- **i18n of `chantier new` scaffold.** Locale-aware stubs would help non-English authors but conflicts with NFR-005 for v0.1. Revisit after v0.1 ships.

</deferred>

---

*Phase: 2-Runtime core*
*Context gathered: 2026-05-29*
