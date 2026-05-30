# Phase 3: Skill library - Context

**Gathered:** 2026-05-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 3 authors the first four reference skills and ships them as Chantier's first end-to-end exercise of the ADR 0001 Surface 2 contract. Each skill is a directory under `skills/<name>/` containing `SKILL.md` (frontmatter per `core/schemas/skill.json`), `PRESSURE.md` (at least two adversarial scenarios), and `run.sh` (POSIX shell entry point). The four skills are: `using-git-worktrees`, `test-driven-development`, `requesting-code-review`, `subagent-driven-development`.

Phase 3 ships when: (1) all four skill directories exist and pass `chantier validate-task` when invoked from a task; (2) no skill body contains a harness-specific identifier (NFR-001 enforced by `chantier validate-task` gate 4); (3) each skill's `PRESSURE.md` contains at least two adversarial scenarios in the structured format defined below; (4) every shipped skill is authored as original Chantier content per the greenfield posture in `LICENSE-CREDITS`.

Phase 3 does **not** ship: the Claude Code adapter that stages dossiers (Phase 4); the end-to-end dogfood test that invokes these skills via the adapter (Phase 5); `receiving-code-review` as a sister skill (deferred — only the requesting half is in scope); skill versioning / `chantier.lock` (ADR 0001 OQ #1, still deferred); `inputs_schema` strictness mode (ADR 0001 OQ #3, still deferred); skill-to-skill composition syntax (ADR 0001 OQ #4, still deferred); `extract-skills-from-phase` self-improvement skill (deferred to v0.3.0).

</domain>

<decisions>
## Implementation Decisions

### `run.sh` shape and role
- **D-01:** All four skills ship a `run.sh`. Uniform pattern gives the Phase 4 adapter a single code path: stage dossier → exec `run.sh` → `chantier state append`. Markdown-only skills are not allowed in v0.1.
- **D-02:** `run.sh` performs the deterministic shell work the skill needs (`git worktree add`, `bats core/tests/`, `git diff`, etc.). `SKILL.md` guides the agent on WHEN and WHY; `run.sh` executes the HOW. This minimizes drift between harnesses because the mechanical steps are not re-described in each adapter.
- **D-03:** `run.sh` deterministically generates **both** `output.md` (template prose + measured facts) **and** `output.json` (fields declared in `outputs_schema`). The agent does not author either file directly. Rationale: NFR-001-safe by construction (no harness identifiers can leak into outputs if `run.sh` is the sole author), and `chantier validate-task` gates 2/3/5 read deterministic inputs.
- **D-04:** Each skill declares its own exit-code matrix in `SKILL.md`. Non-zero exit from `run.sh` signals a **technical incident** only (missing dependency, lock failure, filesystem error). Business outcomes — including legitimate "red step" failures in TDD or "duplicate worktree" collisions — are encoded as fields in `output.json` and `run.sh` exits 0. `chantier validate-task` reads business state from `output.json`, never from the exit code.

### Subagent discipline framing
- **D-05:** Every `SKILL.md` body contains a numbered `## Invariants` section. The body's closing instructions require the agent to acknowledge the invariants applicable to the current task before acting. `run.sh` writes the applied invariants list into `output.md`, and `chantier validate-task` gate 5 (Acceptance) verifies their presence.
- **D-06:** A shared kernel of three invariants applies to every skill: (1) NFR-001 portability — no harness identifier may appear in any file the skill writes; (2) `STATE.md` is append-only — direct edits are a contract violation, every mutation goes through `chantier state append`; (3) `state_writes` containment — the skill may not write outside the paths declared in its frontmatter. Each skill body adds 2–4 skill-specific invariants on top of the kernel (e.g., for TDD: red-before-green ordering; for worktrees: clean baseline before work).
- **D-07:** Every invariant has a **measurable proof** recorded as a field in `output.json`. Example: TDD invariant "red-before-green" yields `output.json.red_step_timestamp` and `output.json.green_step_timestamp`, and `chantier validate-task` gate 5 checks `red_step_timestamp < green_step_timestamp`. Discipline is falsifiable, not based on textual acknowledgment alone.
- **D-08:** The body of `subagent-driven-development` contains an explicit `## Why no hooks` section citing Superpowers issue #237 and ADR 0001 §6. The skill is the load-bearing answer to the SessionStart-injection problem; the body must make the rationale legible to a fresh subagent that has never seen the project before.

### `PRESSURE.md` format
- **D-09:** Each adversarial scenario follows the structured spec template: `## Scenario N — <title>` with four mandatory subsections: **Situation** (context), **Temptation** (the attractive shortcut), **Required response** (what the skill demands), **Disqualifier** (the measurable failure signal). Greppable, comparable across skills, forces authors to define the disqualifier explicitly.
- **D-10:** Each skill ships at minimum one **time pressure** scenario and one **sunk cost** scenario. This mirrors the two Cialdini-derived levers Superpowers actually documents as proven (per Vincent's methodology post). Full six-lever Cialdini coverage is deferred.
- **D-11:** Each `Disqualifier` cites the SKILL.md invariant it violates by number AND the `output.json` metric that detects it. Example: `Disqualifier: Violates Invariant 2 (red-before-green). Detected by output.json.red_step_timestamp >= output.json.green_step_timestamp.` This couples PRESSURE.md to SKILL.md as a single artifact pair.
- **D-12:** Each `PRESSURE.md` begins with a minimal YAML front-matter: `skill_id`, `scenarios: [{id, levers, invariants_referenced}]`. The front-matter is greppable for future eval tooling but is **not** validated by `chantier validate-task` in v0.1 — `PRESSURE.md` is documentation, not part of the ADR 0001 Surface 2 contract.
- **D-13:** Each `PRESSURE.md` is autonomous — no cross-references to other skills' PRESSURE files. When a lever applies to multiple skills (e.g., "time pressure" likely applies to all four), the scenario is duplicated and contextualized per skill rather than centralized.

### `harness_adapters` declaration
- **D-14:** v0.1 policy is **tested-only**. Every `SKILL.md` declares `harness_adapters: [claude-code]` and nothing else. Rationale: the only adapter that will exist by the end of v0.1 is `adapters/claude-code/` (Phase 4); aspirational claims about Cursor, Codex CLI, Copilot CLI, Gemini CLI, or OpenCode would be unverified and inconsistent with Chantier's "honest about what works" posture.
- **D-15:** Each `SKILL.md` body includes a short `## Portability claim` section explaining the tested-only policy and the extension recipe: (a) write `adapters/<harness>/run-task.sh`, (b) run this skill end-to-end on that harness with `chantier validate-task` green, (c) extend `harness_adapters[]` in the same commit as the adapter ships. The recipe lives inline in every skill so contributors discover it without reading an ADR.
- **D-16:** A new `bats` test under `core/tests/` verifies that all `skills/*/SKILL.md` declare an **identical** `harness_adapters` array. Divergence between skills (e.g., three on `[claude-code]` and one on `[claude-code, cursor]` by accident) fails the suite. Single uniformity check, no per-skill override path in v0.1.
- **D-17:** Mechanical extension criterion: a harness joins `harness_adapters[]` only after an end-to-end test (one real task, `chantier validate-task` green, `output.md` / `output.json` conformant to the skill's declared schemas) passes on that harness. No per-adapter ADR is required; the test pass is the gate.

### Claude's Discretion
The following are implementation-level decisions made by Claude in the absence of user preference. Planner and researcher may refine.

- **Invariant wording.** The exact prose of each invariant (both kernel and skill-specific) is open. Planner drafts; the bats uniformity test (D-16) and the validate-task gate 5 check (D-07) constrain the shape but not the wording.
- **`inputs_schema` content per skill.** ADR 0001 OQ #3 (inputs strictness) is still deferred. Planner sketches a sensible JSON-Schema-draft-07-subset (per ADR 0002's subset profile) for each skill's expected inputs without trying to settle the strictness debate. Examples: `target_file` and `test_framework` for TDD; `branch_name` and `setup_command` for worktrees.
- **`outputs_schema` beyond discipline metrics.** Each skill's `output.json` carries discipline-verification fields (D-07) plus skill-specific result fields (e.g., for TDD: `tests_added`, `coverage_delta`; for worktrees: `worktree_path`, `setup_exit_code`). Planner derives the field set per skill.
- **Internal shell function naming in `run.sh`.** No project-wide convention enforced. Planner picks readable function names per skill.
- **PRESSURE.md scenarios beyond the minimum two.** Authors may add additional scenarios if a skill warrants it (e.g., `subagent-driven-development` may want a third "authority" scenario where the parent context appears to override discipline). Mandatory minimum is two per skill.
- **`requesting-code-review` scope shape.** Superpowers paired `requesting-code-review` with `receiving-code-review`; Phase 3 ships only the requesting half (per ROADMAP success criterion 1). Whether the skill body mentions a future `receiving` half, or stays silent, is planner discretion.
- **Authoring order of the four skills.** Whether they ship in a parallel wave (one PLAN task each, executed concurrently) or sequentially is a plan-level question. Planner decides based on inter-skill dependencies (likely none, but worth checking).
- **Acknowledge-block format.** Exact wording / placement / structure of the read-aloud acknowledgment block at the end of each `SKILL.md` body. Planner picks one shape and applies it uniformly across the four skills.
- **`state_reads` / `state_writes` paths per skill.** Each skill declares its own; planner derives reasonable defaults from the dossier model (ADR 0001 Surface 2) and from each skill's role.
- **Placement of the bats uniformity test (D-16).** `core/tests/skill_uniformity.bats` vs `skills/_meta/tests/` vs another location. Planner places it where it composes naturally with the existing Phase 2 bats suite.
- **Skill body length.** Superpowers' bodies are "hundreds of words". Planner authors at a length that makes the invariants and acknowledgment block actionable; no project-wide minimum or maximum enforced.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Founding contract (load-bearing)
- `docs/adr/0001-state-skill-contract.md` — Surface 2 defines the `SKILL.md` frontmatter contract, the dossier model that skills read from, and the validation gates that `chantier validate-task` enforces. §6 documents the #237 finding that load-bears the Subagent Discipline Framing decisions (D-05..D-08).
- `docs/adr/0002-runtime-binary-and-state-format.md` — codifies the 8 required SKILL.md frontmatter fields enforced by gate 4, the validation subset profile, and the exit-code matrix (relevant to D-04). Specifies the NFR-001 deny-list (`mcp__`, `claude_ai_`, `@codebase`, `claude-code`, `cursor`, `codex-cli`, `copilot-cli`, `gemini-cli`, `opencode`).
- `core/schemas/skill.json` — the JSON Schema draft-07 file that `chantier validate-task` gate 4 imports. The eight required fields and the `harness_adapters` enum constrain D-14..D-16.

### Phase scope and acceptance
- `.planning/ROADMAP.md` §Phase 3 — phase goal, dependencies, success criteria 1–5.
- `.planning/REQUIREMENTS.md` — FR-005 (skill directory layout), FR-006 (SKILL.md frontmatter conforms to ADR 0001), FR-009 (the four skills shipped), FR-010 (PRESSURE.md ≥2 scenarios); NFR-001 (no harness identifiers in skill bodies), NFR-005 (English-only).
- `.planning/PROJECT.md` — out-of-scope-forever list (no tokens, no SaaS, no harness replacement) plus the v0.1.0 success summary.

### Lineage and posture
- `docs/research/inheritance-map.md` — §3 (skill atom), §4 (TDD), §5 (between-task code review), §6 (subagent + worktrees + the #237 caveat), §9 (Cialdini-derived pressure-testing). Establishes what Chantier inherits in concept but authors originally.
- `LICENSE-CREDITS` — "Chantier is a greenfield project, not a fork." Skills are authored originally; Superpowers and GSD-redux are acknowledged in this credits file and in `docs/research/`, not by copying their skill bodies.

### Prior-phase context
- `.planning/phases/02-runtime-core/02-CONTEXT.md` — `<code_context>` §"Integration Points" anticipated that each skill ships `run.sh` ending in `chantier state append`. D-01 confirms this; D-02 specifies the rest of `run.sh`.
- `.planning/phases/02-runtime-core/02-06-SUMMARY.md` — §"Note for Phase 3" confirms the SKILL.md frontmatter schema and validate-task gate 4 are wired and ready to validate authored skills.

### Out-of-scope reminders (deferred, do not address in Phase 3)
- ADR 0001 §"Open questions (intentionally deferred)" — all four still deferred: skill versioning + lockfile, STATE.md compaction, inputs_schema strictness, skill-to-skill composition.
- ADR 0002 §"Open questions" — six items, all out of scope for Phase 3.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `core/bin/chantier` — exposes `state append` (D-04 routes business state through `output.json` rather than `state append`, but skills' `run.sh` ends with one `state append` call per ADR 0001 Surface 3) and `validate-task` with all five gates already wired. Skills built in Phase 3 are validated against this binary as authored.
- `core/schemas/skill.json` — single source of truth for the eight required SKILL.md frontmatter fields. The `harness_adapters` enum constrains D-14.
- `core/tests/` — existing bats suite (64 tests at Phase 2 close). The new uniformity test (D-16) composes here.
- `.planning/STATE.md` JSONL format — `run.sh` calls `chantier state append` for the task lifecycle event; the dotted-namespace convention (`task.completed`, `skill.invoked`, etc.) per ADR 0002 §Event taxonomy applies.

### Established Patterns
- **Frontmatter-first documents.** Every `.planning/` and `core/schemas/` artifact leads with YAML frontmatter or JSON Schema metadata. `SKILL.md` and `PRESSURE.md` follow the same pattern (D-12).
- **Greppable enforcement.** Phase 2 chose grep-able regexes (e.g., the D-09 event shape regex `^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$`, the `HARNESS_DENY_LIST_CHECK` marker in `chantier --self-test`) over runtime validators. Phase 3 inherits this pattern: D-07 (measurable invariant proofs in `output.json`), D-11 (Disqualifier ↔ invariant ↔ output.json field), and D-16 (bats uniformity check on `harness_adapters`) all enforce by static or post-hoc grep.
- **No-network default.** NFR-004 holds. None of the four skills' `run.sh` may reach the network unless the skill explicitly opts in (none does in v0.1).
- **MADR-shaped ADRs.** ADR 0001 and ADR 0002 follow the same MADR house style. If Phase 3 surfaces a new ADR-worthy decision (e.g., resolving an OQ during authoring), it should mirror that style.

### Integration Points
- **Phase 4 (Claude Code adapter):** `adapters/claude-code/run-task.sh` stages the dossier per ADR 0001 Surface 2 (`./reads/`, `./upstream/`, `./inputs.yml`, `./env.sh`) and invokes the skill's `run.sh`. D-01's uniform `run.sh` policy guarantees the adapter has one code path. D-14's tested-only `harness_adapters` list will grow from `[claude-code]` to whatever Phase 4 actually proves end-to-end.
- **Phase 5 (Dogfood E2E):** `tests/e2e/` will exercise the full new-project → plan → execute → verify loop using at least one of these four skills. D-03's deterministic `output.md` / `output.json` generation makes the test byte-stable.
- **`chantier validate-task` gates already enforce:** gate 4 (harness deny-list grep on skill bodies, paths checked against `core/schemas/skill.json`), gate 5 (Acceptance section present in `output.md`). D-05's read-aloud invariants block satisfies gate 5; D-07's metric fields satisfy validate-task's runtime checks.

### Empty directory awaiting Phase 3
- `skills/` — contains only `.gitkeep`. Phase 3 populates `skills/using-git-worktrees/`, `skills/test-driven-development/`, `skills/requesting-code-review/`, `skills/subagent-driven-development/`, each with `SKILL.md`, `PRESSURE.md`, `run.sh`.

</code_context>

<specifics>
## Specific Ideas

- The user accepted the recommended option on every question across all four areas (16 of 16 question turns). Strong signal that the workflow's recommendation logic matched the user's mental model; planner can treat the recommended options as load-bearing rather than tentative.
- The user repeatedly favored **falsifiable discipline** over textual acknowledgment (D-07, D-11, D-16): measurable proofs in `output.json`, explicit mappings between PRESSURE scenarios and invariants, and a bats test enforcing inter-skill uniformity. This is consistent with Phase 2's pattern of grep-based enforcement (event shape regex, harness deny-list marker) and should guide planner choices when faced with "convention vs check" forks.
- "Tested-only" `harness_adapters` (D-14) is the user's preferred operational stance: honesty about what works over aspirational portability claims. Apply the same principle to other forward-looking claims in skill bodies (e.g., do not claim "future skill X will compose with this one" — say only what is shipped and tested).
- The greenfield-not-a-fork posture in `LICENSE-CREDITS` is reaffirmed: skills are authored as Chantier originals, with Superpowers / GSD acknowledged in `docs/research/inheritance-map.md` and `LICENSE-CREDITS`, never by copying their skill bodies.

</specifics>

<deferred>
## Deferred Ideas

These were touched during discussion but explicitly deferred to keep Phase 3 focused:

- **`inputs_schema` strictness mode.** Still deferred per ADR 0001 OQ #3. Phase 3 sketches reasonable schemas (planner discretion) without trying to settle the strictness debate. Will need a real ADR once three concrete skills exist and real-world drift surfaces.
- **`chantier.lock` skill version pinning.** Still deferred per ADR 0001 OQ #1. Becomes useful once skills start upgrading; Phase 3 ships skills at v1.0.0 with no consumers yet.
- **STATE.md compaction.** Still deferred per ADR 0001 OQ #2. Phase 5 dogfood may surface the pressure; Phase 3 stays out.
- **Skill-to-skill composition syntax.** Still deferred per ADR 0001 OQ #4. `subagent-driven-development` arguably composes with `test-driven-development` and `requesting-code-review` (a subagent runs TDD then requests review); Phase 3 may surface a natural shape, but the syntax is not designed here.
- **Second harness adapter.** REQUIREMENTS §Out of scope for v0.1.0. Deferred to v0.2.0; revisit after Phase 4 lands `adapters/claude-code/` and Phase 5 dogfoods it.
- **Full Cialdini taxonomy (6 levers) in PRESSURE.md.** v0.1 covers only time pressure and sunk cost (D-10). Adding reciprocity, commitment, social proof, and authority/scarcity scenarios is a v0.2+ enhancement once we have evidence of which levers actually trip Chantier-shipped skills.
- **Machine-runnable PRESSURE.md scenarios (bats simulation against a mock subagent).** Considered (Area 3, option 3). Deferred — requires a "fake harness" test fixture not designed yet. v0.1 ships markdown spec scenarios per D-09.
- **`skills/_shared/PRESSURE-PATTERNS.md` for cross-skill levers.** Considered (Area 3, option 3). Deferred — adds a file outside ADR 0001's "one skill = one directory" model. Revisit in v0.2 only if duplication across the four PRESSURE.md files becomes painful.
- **`receiving-code-review` as a sister skill to `requesting-code-review`.** ROADMAP success criterion 1 mandates only the requesting half in Phase 3. The receiving half is a candidate for v0.2 once Phase 5 dogfood shows how between-task review actually flows in practice.
- **`extract-skills-from-phase` self-improvement skill.** Already deferred to v0.3.0 per `.planning/config.json` and PROJECT.md.
- **i18n of `chantier new` scaffold.** Already deferred (NFR-005 holds for v0.1); not re-opened in Phase 3.
- **Long-flag aliases for `chantier` subcommands.** Already deferred from Phase 2; not re-opened.
- **ADR per adapter as an extension protocol.** Considered for Area 4 option 2. Rejected in favor of D-17 (mechanical E2E-test criterion). Re-open if a future adapter introduces architectural decisions that warrant a formal ADR.

</deferred>

---

*Phase: 3-Skill library*
*Context gathered: 2026-05-30*
