# Phase 2: Runtime core — Pattern Map

**Mapped:** 2026-05-29
**Files analyzed:** 18 new files (one of them a non-trivial migration of an existing file)
**Analogs found:** 7 partial in-repo / 18  — Chantier is greenfield for the runtime tier; the binary, schemas, and bats suite have **no in-repo analog**. The ADR file and the migration of `STATE.md` do have direct analogs.

> **Note for the planner:** This is a greenfield phase. The expected outcome — and the actual finding here — is that **the bulk of new files (`core/bin/chantier`, `core/schemas/*.json`, `core/tests/**`)** have no existing in-repo analog. For those, this document points the planner at the relevant patterns and code excerpts inside `02-RESEARCH.md` (Patterns 1–7, Code Examples §"State of the Art", Pitfalls 1–9) — that is the canonical pattern source for this phase, *not* anything that lives under `core/` today (which is empty). For files that DO have in-repo analogs — the ADR, the scaffold templates emitted by `chantier new`, the migrated `STATE.md` — concrete excerpts with line numbers are provided below.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `core/bin/chantier` (CREATE) | binary / CLI entrypoint | request-response (CLI invocations) + file-I/O (JSONL append, scaffold writes) | **None in repo** — Phase 1 left `core/` empty. Pattern source = `02-RESEARCH.md` Patterns 1, 2, 3, 6, 7. | greenfield |
| `core/schemas/project.json` (CREATE) | config / schema | static data | **None in repo** — no JSON Schemas exist yet. Field set derives from `.planning/PROJECT.md` frontmatter. | greenfield (data source exists) |
| `core/schemas/requirements.json` (CREATE) | config / schema | static data | **None in repo**. Field set derives from `.planning/REQUIREMENTS.md` frontmatter. | greenfield (data source exists) |
| `core/schemas/roadmap.json` (CREATE) | config / schema | static data | **None in repo**. Field set derives from `.planning/ROADMAP.md` (note: this file currently has no frontmatter — see §"No Analog Found"). | greenfield (partial data source) |
| `core/schemas/plan.json` (CREATE) | config / schema | static data | **None in repo**. Field set derives from `.planning/phases/01-foundation/PLAN.md` frontmatter + ADR 0001 Surface 1 task block. | greenfield (data source exists) |
| `core/schemas/skill.json` (CREATE) | config / schema | static data | **None in repo**. Field set derives from ADR 0001 Surface 2 SKILL.md frontmatter spec (no shipped skill yet). | greenfield (spec source exists) |
| `core/tests/state_append.bats` (CREATE) | test | request-response (invoke binary, assert stdout/exit/file state) | **None in repo** — no tests exist yet. Pattern source = `02-RESEARCH.md` §"bats-core skeleton test". | greenfield |
| `core/tests/state_show.bats` (CREATE) | test | request-response | **None in repo**. Same pattern source as above. | greenfield |
| `core/tests/validate_task.bats` (CREATE) | test | request-response | **None in repo**. Same pattern source. | greenfield |
| `core/tests/new.bats` (CREATE) | test | request-response + file-I/O assertion | **None in repo**. Same pattern source. | greenfield |
| `core/tests/self_test.bats` (CREATE) | test | request-response | **None in repo**. Same pattern source. | greenfield |
| `core/tests/fixtures/PLAN.valid.md` (CREATE) | test fixture | static data | `.planning/phases/01-foundation/PLAN.md` | exact (different content, same shape) |
| `core/tests/fixtures/PLAN.invalid-missing-required.md` (CREATE) | test fixture | static data | `.planning/phases/01-foundation/PLAN.md` (degraded variant) | exact (shape derived from valid) |
| `core/tests/fixtures/output.valid.md` (CREATE) | test fixture | static data | **None in repo** — no `output.md` has ever been produced. Spec source = ADR 0001 Surface 3 + Pattern 4 Gate 5. | greenfield |
| `core/tests/fixtures/output.missing-acceptance.md` (CREATE) | test fixture | static data | Sibling fixture above (degraded variant). | greenfield |
| `docs/adr/0002-runtime-binary-and-state-format.md` (CREATE) | documentation / ADR | static data | **`docs/adr/0001-state-skill-contract.md`** | exact |
| `.planning/STATE.md` (MODIFY — one-shot migration) | data / event log | file-I/O batch (one-shot rewrite, then back to append-only JSONL) | **`.planning/STATE.md`** (the current file) | exact (this IS the file being migrated) |
| `.gitattributes` (CREATE) | config | static data | **None in repo** — file does not currently exist (verified by `ls`). Pattern source = `02-RESEARCH.md` Pitfall 3. | greenfield |

**Classification notes:**

- The orchestrator brief mentioned "already-established repo conventions" for `.gitattributes` — direct verification shows the file **does not exist yet**. Phase 2 creates it (per Pitfall 3, to prevent CRLF corruption of the shipped shell binary).
- `STATE.md` is the only "modify" in this phase. Every other entry is a fresh create. The migration is a single dedicated commit per D-04; the file before that commit is Markdown table, the file after that commit is JSONL.
- `bats-support` and `bats-assert` under `core/tests/test_helper/` are **git submodules**, not files we author. They are added via `git submodule add` and tracked as commits in `.gitmodules`. They are listed here for completeness only — no pattern extraction applies.

---

## Pattern Assignments

### `docs/adr/0002-runtime-binary-and-state-format.md` (documentation / ADR)

**Analog:** `docs/adr/0001-state-skill-contract.md` (the only ADR in the repo)

**Why this is a strong analog:** ADR 0002 must match ADR 0001's house style byte-for-byte (heading hierarchy, status block, MADR-adapted structure). The research document explicitly mandates this: `02-RESEARCH.md` §"Don't Hand-Roll" → row "ADR template" says **"ADR 0002 must match exactly"** the conventions of ADR 0001.

**Header block pattern** (`docs/adr/0001-state-skill-contract.md` lines 1–14):

```markdown
# ADR 0001 — The State / Skill Contract

- **Status:** Accepted
- **Date proposed:** 2026-05-29
- **Date accepted:** 2026-05-29
- **Deciders:** Chantier founding contributors
- **Supersedes:** —
- **Superseded by:** —

> [One-paragraph framing of why this ADR exists, ending with "every later ADR builds on it" or similar.]

---

## Context
```

**Copy to ADR 0002:** Same six bullets in the same order; replace the title with "ADR 0002 — Runtime binary and state format". The `Supersedes` field is `—`; `Superseded by` is `—`.

**Section structure pattern** (extracted by reading the section headers across `docs/adr/0001-state-skill-contract.md`):

| Line | Heading | Purpose |
|------|---------|---------|
| 16 | `## Context` | The three findings forcing the ADR (for 0002: NFR-002 trust surface, `flock` absent on macOS, no pure-jq schema validator) |
| 32 | `## Decision` | The actual decisions — for 0002 this enumerates D-01..D-13 plus the two subset profiles (frontmatter, JSON Schema) |
| 36, 82, 142, 164 | `### Surface N — …` | ADR 0001 uses three surfaces; ADR 0002 instead uses thematic subsections (e.g., `### STATE.md JSONL format`, `### Frontmatter subset profile`, `### JSON Schema subset profile`, `### Event taxonomy and shape regex`, `### Exit-code error model`, `### Concurrency`, `### Self-test gates`) |
| 178 | `## Consequences` | Positive / Negative / Neutral subsections |
| 203 | `## Alternatives considered` | Lettered subsections A, B, C, ... — for 0002: Markdown table vs JSONL, flock vs mkdir-mutex, ajv shellout vs jq subset, yq vs awk+jq |
| 231 | `## Open questions (intentionally deferred)` | Numbered list. ADR 0002 **must explicitly re-flag** ADR 0001's four open questions as still deferred (per CONTEXT.md `<canonical_refs>`). |
| 240 | `## Approval` | Sign-off checkboxes |

**Quoted-sub-block pattern for inline schemas** — ADR 0001 uses fenced ` ```yaml ` and ` ```markdown ` blocks to embed example structures inline. ADR 0002 must use ` ```json ` blocks to embed each of the five schemas in full (per `02-RESEARCH.md` Open Question 1 recommendation). Example fence in ADR 0001 lines 40–73 (the embedded PLAN.md YAML block).

**Alternatives-considered idiom** (`docs/adr/0001-state-skill-contract.md` lines 205–227):

```markdown
### A. State injected via SessionStart hook (Superpowers' approach)

**Rejected.** Documented in Superpowers #237 to break for subagents; structurally unimplementable on harnesses without a hook system (a Codex CLI without `SessionStart` cannot do this). Adopting it would either fork the framework per-harness or accept that subagents skip discipline. Both unacceptable.
```

**Copy to ADR 0002:** Same pattern. Header is `### {Letter}. {Short alternative name}`. Body starts with `**Rejected.**` (or `**Accepted with caveats.**`) followed by a single paragraph explaining why. One alternative per subsection.

**Approval block pattern** (`docs/adr/0001-state-skill-contract.md` lines 240–246):

```markdown
## Approval

This ADR is the **point of no return** the brief identifies. Once accepted, every later ADR must justify any divergence from these surfaces. No code that resembles runtime should be written until a human has signed off.

- [x] Approved by founding contributors in the bootstrap session, 2026-05-29.
- [x] Specific decisions ratified: [enumerate].
- Four questions deliberately deferred: [enumerate].
```

**Copy to ADR 0002:** Same pattern. Replace "point of no return" framing with the ADR-0002-specific framing ("This ADR codifies the runtime format and binary contract. Once accepted, downstream tooling can depend on these schemas at version 0.1.0."). The `[x]` checkboxes should be `[ ]` in the draft, flipped to `[x]` upon sign-off in a follow-up commit (matching ADR 0001's lifecycle, where 0001's status moved Proposed→Accepted in commit `8889c59`, per STATE.md line 20).

---

### `.planning/STATE.md` (MODIFY — one-shot migration)

**Analog:** itself (this is a format migration, not a from-scratch authoring)

**Why this is a strong analog:** D-04 mandates the migration converts the existing 10 Markdown-table rows verbatim into JSONL. The source data IS the existing file; the destination format is specified in D-01/D-02.

**Source pattern — current frontmatter** (`.planning/STATE.md` lines 1–10):

```yaml
---
project_id: chantier
created: 2026-05-29
format_version: 0.1.0-interim
format_note: |
  STATE.md is append-only per ADR 0001. Format will be finalized in ADR 0002.
  Until then: Markdown table, one row per event, one event per line, no multi-line cells, no row deletion.
  Edits to historical rows are a contract violation.
  Mutation is allowed only via `chantier state append` once the binary exists; during the foundation phase, rows were authored by hand.
---
```

**Source pattern — table row shape** (`.planning/STATE.md` line 14 header + line 16 example):

```markdown
| timestamp           | event                     | actor  | summary | refs |
|---------------------|---------------------------|--------|---------|------|
| 2026-05-29T17:00:00Z | bootstrap.session.started | MAoDzi | Brief received, session plan proposed, all seven ADR sign-offs validated | brief |
```

**Destination pattern — post-migration frontmatter (per D-04):**

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

Note the `format_version` bump (`0.1.0-interim` → `0.1.0`) and the body-rule change (Markdown table → JSON Lines) — both verbatim per D-04.

**Destination pattern — per-line shape (per D-02):**

```json
{"ts":"2026-05-29T17:00:00Z","event":"bootstrap.session.started","actor":"MAoDzi","task":null,"skill":null,"summary":"Brief received, session plan proposed, all seven ADR sign-offs validated","refs":["brief"]}
```

**Per-row mapping rule** (derived from `02-RESEARCH.md` §"Runtime State Inventory"):

| Markdown column → JSONL field | Transformation |
|-------------------------------|----------------|
| `timestamp` → `ts` | verbatim, ISO-8601 UTC string |
| `event` → `event` | verbatim, dotted-namespace string |
| `actor` → `actor` | verbatim (all 10 rows use `MAoDzi`) |
| (none in source) → `task` | `null` for all 10 historical rows (no task association) |
| (none in source) → `skill` | `null` for all 10 historical rows (no skill execution yet) |
| `summary` → `summary` | verbatim |
| `refs` → `refs` | string-split on whitespace into an array; for the multi-token row (`bootstrap.harness.chosen`, line 25, which contains `ROADMAP.md`) treat as one-element array |

**Migration commit message pattern** — must follow the existing `STATE.md` row style for the `repo.published` / `phase.completed` events. Examine `STATE.md` line 23 (`phase.completed`, references `.planning/phases/01-foundation/SUMMARY.md`) for the commit-message-as-event idiom: the commit message body **must** include the pre-migration markdown table verbatim in a folded block (per `02-RESEARCH.md` Open Question 2 recommendation: "do not commit `.bak`; rely on git history; include the pre-migration table in the commit body").

---

### `core/tests/fixtures/PLAN.valid.md` (test fixture)

**Analog:** `.planning/phases/01-foundation/PLAN.md`

**Why this is a strong analog:** The fixture must be a valid `PLAN.md` per the schema being authored in this same phase (`core/schemas/plan.json`). The shipping plan from Phase 1 is the only real, dogfood-validated PLAN.md in the repo.

**Frontmatter pattern** (`.planning/phases/01-foundation/PLAN.md` lines 1–12):

```yaml
---
plan_id: 01-foundation-bootstrap
phase: 01-foundation
created: 2026-05-29
status: completed
declared_skills: []
note: |
  Phase 1 was executed before the skill library existed. All tasks are inline (no skill invocation).
  ...
---
```

**Task block pattern** (`.planning/phases/01-foundation/PLAN.md` lines 22–38, the `t1` block):

```markdown
## Task `t1` — Verify identity availability

\`\`\`yaml
task: t1
skill: inline
inputs:
  resources:
    - chantier.dev
    - npm/chantier
    - npm/@chantier/core
    - github.com/chantier-build
state_reads: []
state_writes:
  - .planning/STATE.md
depends_on: []
acceptance:
  - "All four resources verified free as of 2026-05-29"
  - "GitHub user 'chantier' is the known dormant squatter (acceptable per brief)"
\`\`\`
```

**Copy to fixture:** Same shape — a `PLAN.md` frontmatter block, then a sequence of `## Task \`tN\` — Title` headings each followed by a fenced ` ```yaml ` block containing the task fields per ADR 0001 Surface 1. For the **valid** fixture, all required fields (`task`, `skill`, `state_writes`, `acceptance`) must be present and well-formed. For the **invalid-missing-required** fixture (sibling file), remove `acceptance:` from one of the task blocks (gate-3 violation per ADR 0001 validation gate 5 → `core/tests/validate_task.bats`).

---

### `.planning/STATE.md` migrated → `core/tests/fixtures/...` (test fixture pattern for outputs)

For `core/tests/fixtures/output.valid.md` and `output.missing-acceptance.md`, there is **no in-repo analog** — no skill has ever run, so no `output.md` exists in the repo. The pattern source is:
- ADR 0001 §Surface 3 (mandatory `output.md` + `output.json`).
- `02-RESEARCH.md` Pattern 4 gate 5 (the acceptance-section heading regex `^##\s+Acceptance\s*$`).

**Required shape for `output.valid.md`** (synthesized from Pattern 4 gate 5):

```markdown
# Task t1 output

[Free-form skill summary — what the skill did, what it produced.]

## Acceptance

- [Verbatim copy of each acceptance criterion from the PLAN.md task block.]
- [...]
```

**Required shape for `output.missing-acceptance.md`:** identical, but with the `## Acceptance` heading removed (or replaced with `## Acceptance criteria` — note the case-sensitive regex `^##\s+Acceptance\s*$` will reject this variant).

---

### `core/bin/chantier` (binary / CLI entrypoint)

**Analog:** **None in repo.** This is the first runtime file Chantier has ever produced.

**Pattern source (canonical):** `02-RESEARCH.md` Patterns 1–7 + Pitfalls 1–9 + the "State of the Art" code examples. The planner should treat `02-RESEARCH.md` lines 254–807 as the analog corpus for this file — they contain every idiom needed (dispatch shape, lock, append, validate, render, scaffold, self-test).

**Anchor patterns the planner should lift verbatim into the plan's "actions" section:**

| Concern | Source (in `02-RESEARCH.md`) | Notes |
|---------|------------------------------|-------|
| Shebang + IFS + LC_ALL prelude | Pattern 1 lines 258–290 | Always start with `#!/bin/sh`, `set -eu`, explicit `IFS=' \t\n'`, `LC_ALL=C; export LC_ALL`. Never `#!/bin/bash`. |
| Subcommand dispatch (`case "$1" in`) | Pattern 1 lines 292–306 | Reject unknown subcommands with exit 3 (usage error per D-Discretion error model). |
| `acquire_lock()` mkdir-mutex with stale-PID detection | Pattern 2 lines 319–344 | Replaces the `flock` plan from D-Discretion #4 (verdict: REVISE — `flock` is absent on macOS). |
| `state_append()` with `getopts` + jq line construction | Pattern 3 lines 357–401 | Note repeated `-r` flag accumulation via newline-joined string (POSIX has no arrays). Apply event-shape regex D-09 *twice* — once with shell `case` glob (cheap), once with jq `test()` (authoritative). |
| `state_show()` jq @tsv → null-placeholder → `column -t` | Pattern 6 lines 572–581 | Null/empty fields **must** be substituted with `-` before piping; BSD `column` collapses tabs otherwise (Pitfall 2). |
| `validate_task()` mapped to 5 ADR-0001 gates | Pattern 4 lines 408–460 | All 5 gates exit code 1 (contract violation). Path-canonicalisation for gate 1 (`cd && pwd`) must reject paths outside the repo root. |
| `validate_against_schema()` jq subset validator | Pattern 5 lines 487–558 | Implements the keyword subset `type / required / properties / additionalProperties / pattern / enum / items`. Anything else in a schema is **silently ignored** — ADR 0002 must call this out. |
| `extract_frontmatter_as_json()` awk + jq | Code Examples §"Verifying a frontmatter file" lines 737–762 | Frontmatter subset profile: top-level scalars + simple lists only. Nested maps not supported (ADR 0002 must call this out). |
| `new_project()` heredoc scaffolds | Pattern 7 lines 590–633 | Use unquoted `<<EOF` only where `$name` / `$(date)` interpolation is needed; use quoted `<<'EOF'` everywhere else (Pitfall 8). |
| `self_test()` body | Code Examples §"Self-test" lines 778–805 | Per the Claude's-Discretion-#11 REVISE verdict: replace "flock available" check with "mkdir-lock works"; add CRLF-in-self check and harness-deny-list-in-self check. |

**Anti-patterns the planner must explicitly forbid in the plan:**

| Forbidden | Why | Where stated |
|-----------|-----|--------------|
| `#!/bin/bash` shebang | Bash-ism leak risk | `02-RESEARCH.md` §"Anti-Patterns" |
| `set -o pipefail` | Not POSIX, breaks on `dash` | same |
| `[[ … ]]` | Bash-only | same |
| `echo -e` / `echo -n` | Cross-shell behaviour differs | same |
| `local` | Not POSIX | same |
| Sourcing helper files (`. lib.sh`) | Violates NFR-002 (single-file binary) | same |
| Embedded harness identifiers (`claude-code`, `cursor`, `mcp__…`, `claude_ai_…`, `@codebase`, `codex-cli`, `copilot-cli`, `gemini-cli`, `opencode`) | Violates NFR-001; the deny-list is asymmetric (the binary itself is checked, AND skill bodies are checked) | D-Discretion + `02-RESEARCH.md` Pattern 4 gate 4 |
| Calling `flock` | Not on macOS | Pitfall 1 + Claude's-Discretion #4 REVISE |
| Calling `yq` | Not in dependency budget | `02-RESEARCH.md` §"Standard Stack" alternatives |
| `eval` anywhere | Shell injection surface | `02-RESEARCH.md` §"Security Domain" |
| Unquoted `$VAR` in `[ … ]` tests | Empty-var breakage | Anti-Patterns |

---

### `core/schemas/{project,requirements,roadmap,plan,skill}.json` (config / schemas)

**Analog:** **None in repo** — no JSON Schemas exist. But the **field set** for each is derivable from existing frontmatter samples.

**Field-source map** (where to read to enumerate required fields per D-07):

| Schema file | Required-fields source (in-repo) | Notes |
|-------------|----------------------------------|-------|
| `core/schemas/project.json` | `.planning/PROJECT.md` lines 1–10 (frontmatter) | Required: `project_id`, `created`, `license`, `copyright`, `status`. Optional but observed: `governance`, `primary_artifact`, `current_milestone`. |
| `core/schemas/requirements.json` | `.planning/REQUIREMENTS.md` lines 1–6 (frontmatter) | Required: `project_id`, `milestone`, `created`, `status`. |
| `core/schemas/roadmap.json` | `.planning/ROADMAP.md` — **NO FRONTMATTER PRESENT** (verified by direct read; the file begins with `# Roadmap: Chantier`). | See §"No Analog Found". ADR 0002 must decide whether `chantier new` emits a ROADMAP.md *with* frontmatter (recommended; consistency with the other docs) or matches the current shape (no frontmatter). Either way the schema for v0.1 must reflect the decision. |
| `core/schemas/plan.json` | `.planning/phases/01-foundation/PLAN.md` lines 1–12 (frontmatter) + ADR 0001 §"Surface 1" lines 40–73 (task block) | Schema must validate **both** the top-level frontmatter AND the embedded YAML task blocks. The frontmatter requires: `plan_id`, `phase`, `created`, `declared_skills`. Optional: `status`, `note`. Each task block (per ADR 0001) requires: `task`, `skill`, `state_writes`, `acceptance`; optional: `inputs`, `state_reads`, `depends_on`. |
| `core/schemas/skill.json` | ADR 0001 §"Surface 2" lines 95–120 | No real skill exists yet (Phase 3). Schema must require: `id`, `version`, `inputs_schema`, `state_reads`, `state_writes`, `outputs_schema`, `portable`, `harness_adapters`. |

**Schema-file shape pattern** (synthesized from `02-RESEARCH.md` Pattern 5 → the validator only honours these keywords):

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://chantier.build/schemas/v0.1.0/project.json",
  "title": "Chantier PROJECT.md frontmatter (v0.1.0 profile)",
  "type": "object",
  "required": ["project_id", "created", "license", "copyright", "status"],
  "properties": {
    "project_id": {"type": "string", "pattern": "^[a-z][a-z0-9-]*$"},
    "created":    {"type": "string", "pattern": "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"},
    "license":    {"type": "string", "enum": ["MIT"]},
    "copyright":  {"type": "string"},
    "status":     {"type": "string", "enum": ["draft", "active", "foundation_complete", "shipped", "archived"]}
  },
  "additionalProperties": true
}
```

**Note the hybrid mode (D-05):** `additionalProperties: true` permits forward-compatible metadata; only the keys listed in `required` are enforced strictly. The shipped jq validator (Pattern 5) emits a *warning* — not an error — when a top-level key is not in `properties` (this is the "permissive with warning for unknown top-level keys" half of D-05).

---

### `core/tests/*.bats` files (tests)

**Analog:** **None in repo** — no test infrastructure exists yet.

**Pattern source:** `02-RESEARCH.md` Code Examples §"bats-core skeleton test" (lines 808–846) is the canonical example. Excerpt:

```bash
#!/usr/bin/env bats

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    export CHANTIER="$BATS_TEST_DIRNAME/../bin/chantier"
    export TMPHOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$TMPHOME/.planning"
    cat > "$TMPHOME/.planning/STATE.md" <<'EOF'
---
format_version: 0.1.0
---
EOF
    cd "$TMPHOME"
}

@test "state append rejects invalid event name" {
    run "$CHANTIER" state append -e "BAD_NAME" -m "summary"
    assert_failure 1
    assert_output --partial "shape regex"
}
```

**Apply to all 5 test files.** Per-file scope:

| File | Test coverage scope | Key assertions |
|------|--------------------|-----------------|
| `state_append.bats` | FR-003 | event-regex enforcement (D-09), one-line atomicity, repeated `-r` accumulation, concurrent-append safety under mkdir-lock |
| `state_show.bats` | D-03 | column rendering, null→`-` substitution, header row present |
| `validate_task.bats` | FR-004 | each of the five ADR-0001 gates fails with exit 1 in isolation |
| `new.bats` | FR-002 | all 5 scaffold files emitted, each parses (jq for config.json, frontmatter extracted cleanly for the four md files), HTML-comment TODOs present |
| `self_test.bats` | FR-001 + D-Discretion #11 | every check from `self_test()` passes when run against the freshly-built binary in this repo |

---

### `.gitattributes` (config)

**Analog:** **None in repo** — verified absent.

**Pattern source:** `02-RESEARCH.md` Pitfall 3 (CRLF line endings break the shebang). Required content:

```
* text=auto eol=lf
core/bin/chantier text eol=lf
```

The first line is the global default (every text file LF on commit); the second is a redundant-but-explicit guard on the shell binary (the file most catastrophically broken by CRLF). No other file in the repo currently exists where CRLF would be load-bearing; adding the global default now is the cheap moment to do it.

---

## Shared Patterns

### Frontmatter discipline (project-wide convention)

**Source:** every `.planning/*.md` file in the repo (`PROJECT.md` lines 1–10, `REQUIREMENTS.md` lines 1–6, `STATE.md` lines 1–10, the planning sub-files).

**Apply to:** every Markdown file `chantier new` emits, and every schema in `core/schemas/`.

**Pattern:** YAML front-matter fenced between `---` delimiters at the top of the file, top-level scalars + simple lists only (no nested maps). The body is free-form Markdown after the closing `---`.

```markdown
---
key1: scalar
key2: 2026-05-29
key3:
  - item1
  - item2
---

# Document title

[Body content]
```

**Why shared:** Both the awk frontmatter extractor (`02-RESEARCH.md` Code Examples §"Verifying a frontmatter file") AND the schema validator (Pattern 5) rely on this shape. The frontmatter subset profile (top-level scalars + simple lists) is the load-bearing constraint ADR 0002 must formally declare.

### Event-name discipline (binary-enforced shape)

**Source:** `.planning/STATE.md` lines 16–26 (the current rows). Every row's `event` field matches `{noun}.{verb}` or `{noun}.{verb}.{sub}`: `bootstrap.session.started`, `research.completed`, `adr.accepted`, `adr.status.updated`, `scaffold.committed`, `github.org.created`, `repo.published`, `phase.completed`, `phase.next.declared`, `bootstrap.harness.chosen`, `phase.context.gathered`.

**Apply to:** every `chantier state append --event X` invocation (the binary's regex `^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$` is calibrated to these existing values; the migration must produce JSONL lines whose `event` field round-trips through the regex without rejection).

**Verification trick:** before shipping, dry-run the migration script and pipe each emitted `event` field through the binary's own regex check. All 10 must pass.

### Append-only contract (NFR-003)

**Source:** ADR 0001 §"Surface 3" lines 142–162 + NFR-003 (`.planning/REQUIREMENTS.md` line 31).

**Apply to:** `state_append()` in the binary (the *only* writer); also `validate_task()` should NOT touch `STATE.md` (it is a read-only validator). The `--self-test` should optionally lint that historical lines are unmodified between runs (out of scope for v0.1 per `02-RESEARCH.md` §"Security Domain" — documented as social convention).

### Exit-code matrix (binary-wide error model)

**Source:** D-Discretion §"Error model" in `02-CONTEXT.md` lines 50.

**Apply to:** every subcommand of the binary, every `bats` test, and every error path in the migration script.

| Exit | Meaning | When |
|------|---------|------|
| 0 | success | normal completion |
| 1 | contract violation | validation failed (event regex, schema, acceptance) |
| 2 | runtime error | missing dependency, write failure, lock contention |
| 3 | usage error | bad flags, missing required arg, unknown subcommand |

`--json-errors` is a top-level flag (per `02-RESEARCH.md` Open Question 4 recommendation), parsed before subcommand dispatch.

### Harness-identifier deny-list (NFR-001 enforcement)

**Source:** D-Discretion §"`validate-task` portability deny-list" (`02-CONTEXT.md` line 49) + Pattern 4 gate 4 (`02-RESEARCH.md`).

**Apply to:**
- `validate-task` gate 4 (the binary greps skill body files when the skill declares `portable: true`).
- `--self-test` (the binary greps **its own** source — `$0` — for the same identifiers; the binary fails self-test if any harness name leaks into it).

**Deny-list (v0.1 hardcoded):** `mcp__`, `claude_ai_`, `@codebase`, `claude-code`, `cursor`, `codex-cli`, `copilot-cli`, `gemini-cli`, `opencode`.

**Carve-out:** Adapter directories (`adapters/<harness>/`, created in Phase 4) are the **only** location where the harness name may legitimately appear. Phase 2 does not ship any adapters, so for Phase 2 the deny-list applies repo-wide.

---

## No Analog Found

Files for which no in-repo analog exists. Planner should refer to `02-RESEARCH.md` as the canonical pattern source:

| File | Role | Data Flow | Reason | Pattern source |
|------|------|-----------|--------|----------------|
| `core/bin/chantier` | binary | request-response + file-I/O | Greenfield — `core/` is empty seed | `02-RESEARCH.md` Patterns 1–7, Pitfalls 1–9, Code Examples §"Self-test", §"Verifying a frontmatter file", §"bats-core skeleton test" |
| `core/schemas/*.json` (5 files) | schema | static data | No JSON Schemas exist in the repo | `02-RESEARCH.md` Pattern 5 (the supported keyword subset) + the in-repo frontmatter samples enumerated under §"Pattern Assignments → core/schemas/..." above |
| `core/schemas/roadmap.json` (specifically) | schema | static data | `.planning/ROADMAP.md` has **no frontmatter at all** — direct verification shows the file starts at line 1 with `# Roadmap: Chantier`. ADR 0002 must therefore *decide* the ROADMAP frontmatter shape from first principles, not derive it from existing usage. | ADR 0002 design choice — recommend mirroring `PROJECT.md` (`project_id`, `created`, `milestone`, `status`) |
| `core/tests/*.bats` (5 files) | test | request-response | No test infrastructure exists in repo | `02-RESEARCH.md` Code Examples §"bats-core skeleton test" |
| `core/tests/fixtures/output.valid.md` | fixture | static data | No `output.md` has ever been produced (no skill has run) | ADR 0001 Surface 3 + `02-RESEARCH.md` Pattern 4 gate 5 (the heading-regex spec) |
| `core/tests/fixtures/output.missing-acceptance.md` | fixture | static data | Sibling of above; degraded variant | Same |
| `.gitattributes` | config | static data | File does not exist in repo (verified) | `02-RESEARCH.md` Pitfall 3 |
| `core/tests/test_helper/bats-{support,assert}/` | dev-time submodules | n/a | External submodules; not authored in-repo | `02-RESEARCH.md` Standard Stack §"Installation"; the planner adds them via `git submodule add` per the README excerpt at lines 124–131 |

---

## Metadata

**Analog search scope:**
- `/Users/alexislegrand/Code et Dev/Chantier/.planning/` (all files — frontmatter, event log, embedded YAML task blocks)
- `/Users/alexislegrand/Code et Dev/Chantier/docs/adr/` (only `0001-state-skill-contract.md`)
- `/Users/alexislegrand/Code et Dev/Chantier/docs/` (other docs scanned for ADR-style conventions; only `vision.md` exists, irrelevant to runtime patterns)
- `/Users/alexislegrand/Code et Dev/Chantier/core/` (empty — `.gitkeep` only)
- `/Users/alexislegrand/Code et Dev/Chantier/skills/` (empty — `.gitkeep` only)
- repo root for `.gitattributes` (absent) and `.gitignore` (present, scanned for relevant ignore patterns — `.chantier/` is already correctly ignored for the staging area introduced in ADR 0001)

**Files scanned:** 12
**Strong in-repo analogs identified:** 3 (ADR 0001 for ADR 0002; existing STATE.md for the migrated STATE.md; Phase-1 PLAN.md for the test fixture PLAN.valid.md)
**Files declared greenfield (no analog):** 15 of 18

**Pattern extraction date:** 2026-05-29

**Cross-references:**
- `02-CONTEXT.md` D-01..D-13 (decisions); D-Discretion #1..#11 (with #4 and #11 marked REVISE by research).
- `02-RESEARCH.md` §"Architecture Patterns" 1–7; §"Common Pitfalls" 1–9; §"Code Examples"; §"Claude's Discretion review".
- ADR 0001 §"Surface 1", §"Surface 2", §"Surface 3", §"Validation gate".
- `01-foundation/SUMMARY.md` §"Validation of ADR 0001 schema" — the three findings (STATE.md format, frontmatter schemas, event vocabulary) Phase 2 closes.
