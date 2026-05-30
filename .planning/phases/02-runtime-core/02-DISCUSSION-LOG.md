# Phase 2: Runtime core - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-29
**Phase:** 02-runtime-core
**Areas discussed:** Format STATE.md, Schemas strictness, Event taxonomy, Scaffold `chantier new`

---

## Gray area selection

**Question:** Phase 2 — Runtime core. Which gray areas to discuss before researcher/planner? (multi-select)

| Option | Description | Selected |
|--------|-------------|----------|
| Format STATE.md | Core of ADR 0002: keep current Markdown table, migrate to JSON Lines, or hybrid format. | ✓ |
| Schemas strictness | JSON Schemas for PROJECT/REQUIREMENTS/ROADMAP/PLAN/SKILL front-matters: strict, permissive, or hybrid. | ✓ |
| Event taxonomy | STATE.md events vocabulary: closed registry, dotted-namespace convention, or free-form. | ✓ |
| Scaffold `chantier new` | Truly empty files, commented stubs, or example-filled templates. | ✓ |

**User's choice:** All four areas.

---

## Format STATE.md

| Option | Description | Selected |
|--------|-------------|----------|
| JSONL + render-cmd (Recommended) | One line = one JSON object. Robust `jq` parsing (aligned with ADR 0001 "cat/jq/grep"). Add `chantier state show` to render as a table for human reading. Newline/pipe escaping comes for free. Cost: raw `cat STATE.md` is less skimmable. | ✓ |
| Markdown table strict | Keep the current format but document strict rules: no `|` in cells, encoded newlines, fixed columns. Eye-readable. Parsing: awk + manual escapes, fragile on rich summaries. | |
| Hybride header + JSONL | Readable YAML frontmatter (log metadata) + JSONL body for events. Compromise: human for global context, machine for events. Cost: two parsers. | |

**User's choice:** JSONL + render-cmd. Preview side-by-side was shown; user accepted without amendment.
**Notes:** The `chantier state show` companion command (D-03) is explicit user preference — substitutes for losing Markdown-table skimmability.

---

## Schemas strictness

| Option | Description | Selected |
|--------|-------------|----------|
| Hybride strict+permissif (Recommended) | `required` strict (typo in `state_writes` → immediate rejection); optional fields permissive (warning if unknown, forward-compat for future skill versions). Best security/forward-compat ratio. | ✓ |
| Strict everywhere | additionalProperties:false on everything. Reject any field not declared. Max safety but every new optional field needs an ADR/schema revision. | |
| Permissive except required | Validate only `required` fields; everything else free. Simpler to implement in pure jq, but lets typos slip on critical optional fields (`harness_adapter` singular vs plural would pass unnoticed). | |

**User's choice:** Hybride strict+permissif.

---

## Event taxonomy

| Option | Description | Selected |
|--------|-------------|----------|
| Convention {noun}.{verb} libre (Recommended) | ADR 0002 documents dotted-namespace convention + indicative list of recommended events (`task.completed`, `phase.completed`, `adr.accepted`, etc.) but the binary does NOT enforce a closed registry. Allows organic evolution as skills appear. Phase 1 already proved this convention emerges without constraint. | ✓ |
| Registre fermé validé | ADR 0002 publishes ~12 canonical events; `chantier state append --event X` rejects any unlisted event. Audit-friendly but blocking: every new event type needs an ADR or registry version bump. | |
| Free-form total | No convention, any string accepted. Maximum flexibility, zero audit-ability — STATE.md becomes unanalyzable long-term. | |

**User's choice:** Convention {noun}.{verb} libre.
**Notes:** Claude's autonomous decision to enforce shape via regex `^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$` (D-09) was accepted in the closing batch.

---

## Scaffold `chantier new`

| Option | Description | Selected |
|--------|-------------|----------|
| Stubs commentés (Recommended) | Each file contains its minimal frontmatter + 1-3 empty sections with HTML comment guides (`<!-- TODO: vision en une phrase -->`). User edits, doesn't discover. No fictional content to delete. First impression: guidance without presumption. | ✓ |
| Fichiers réellement vides | PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md, config.json — all created but 0 byte (or just mandatory YAML frontmatter). Purism: no presumption. Cost: user faces a blank page, must read docs to know what to write. | |
| Templates exemple pré-remplis | Fictional charter ("Example Project: build a TODO CLI"), 2-3 demo FRs, an example event in STATE.md. Helps starting but risks copy-paste without thought; each user must clean up. | |

**User's choice:** Stubs commentés.

---

## Closing decision

**Question:** Principal decisions taken; 9 autonomous (Claude's Discretion) decisions listed. Ready for CONTEXT.md, deeper exploration, or override?

| Option | Description | Selected |
|--------|-------------|----------|
| Prêt pour CONTEXT.md (Recommended) | Write CONTEXT.md, DISCUSSION-LOG.md, commit, update STATE.md, next session uses `/gsd-plan-phase 2`. | ✓ |
| Creuser une zone supplémentaire | Open one more gray area (compaction, dossier staging, output.json schema validator, etc.). | |
| Override sur une décision autonome | Revisit one of the 9 Claude's Discretion items. | |

**User's choice:** Prêt pour CONTEXT.md. All 9 autonomous decisions accepted as written.

---

## Claude's Discretion

The following were listed in the closing summary and approved en bloc by the user:

1. **STATE.md migration timing** — clean break at Phase 2 ship time, dedicated commit, `format_version` bumped to `0.1.0`.
2. **JSON Schema location** — `core/schemas/*.json` (runtime-importable), text quoted in ADR 0002.
3. **Event regex enforcement** — `^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$` shape only, no vocabulary check.
4. **Concurrency on `state append`** — `flock(1)` with macOS BSD ⇄ Linux util-linux compat wrapper.
5. **Argument parsing style** — POSIX `getopts` short flags only, no GNU long-flags.
6. **Test framework** — `bats-core` in `core/tests/`, not shipped in runtime artefacts.
7. **Binary structure** — single-file `core/bin/chantier`, `case` dispatch on subcommand.
8. **Scaffold language** — English only for v0.1 (NFR-005 applied to runtime output).
9. **`validate-task` portability deny-list** — hardcoded list for v0.1: `mcp__`, `claude_ai_`, `@codebase`, and the literal harness names.

Additional discretion items added in CONTEXT.md but not in the closing summary:
- Exit code model (`0`/`1`/`2`/`3` + `--json-errors` flag).
- Acceptance section regex (`^##\s+Acceptance\s*$`).
- `chantier --self-test` adapter readiness check.

---

## Deferred Ideas

Surfaced during analysis but not opened for discussion (already deferred elsewhere or out of scope for Phase 2):

- STATE.md compaction strategy (ADR 0001 Open Question #2).
- `chantier.lock` skill version pinning (ADR 0001 Open Question #1).
- `inputs_schema` strictness model (ADR 0001 Open Question #3).
- Skill-to-skill composition syntax (ADR 0001 Open Question #4).
- Second harness adapter (REQUIREMENTS §Out of scope for v0.1.0).
- `chantier state compact` / `chantier state query` convenience subcommands.
- Long-flag aliases on subcommand args.
- i18n of `chantier new` scaffold output.
