# Phase 5: Dogfood E2E - Context

**Gathered:** 2026-05-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 5 closes the v0.1.0 loop. It does three things, in one phase: (1) plan, execute, and verify a small Chantier feature **using only Chantier's own tooling** — `chantier new`, `adapters/claude-code/run-task.sh`, `chantier validate-task`, `chantier state append` — with zero `/gsd-*` invocation along the way; (2) ship `tests/e2e/full_loop.bats` that re-executes a deterministic version of that loop in CI without network access; (3) verify NFR-001 through NFR-006 independently via a consolidated audit harness at `core/tests/nfr_audits.bats`. The final commit of Phase 5 migrates `.planning/ROADMAP.md` from the GSD-parser format back to the ADR 0001 native format and records a `cutover.completed` event in STATE.md — the historical point at which Chantier ceases to depend on GSD's commands.

The "small feature" Chantier-on-Chantier delivers is the Finding F3 fix from the Phase 4 handoff: `adapters/claude-code/run-task.sh` currently emits an empty `upstream/` directory in every dossier; for a task whose YAML block declares `depends_on: [t0]`, the adapter must symlink (or copy) `upstream/t0/output.json` from `.planning/phases/<phase>/tasks/t0/output.json`. The plan therefore contains two tasks — task `t1` produces an `output.json`, task `t2` declares `depends_on: [t1]` and reads `upstream/t1/output.json` — and the dogfood proves the multi-task chain end-to-end. The skill that executes both tasks is `test-driven-development` (already adapter-proven in Phase 4 D-13, with the most measurable discipline signal). One ADR is authored in this phase: ADR 0004 (status Proposed), codifying the Surface 3 propagation contract that the Phase 4 plan 03 fix discovered. Ratification of ADR 0003 and ADR 0004 remains deferred — both are validated against this phase's lived experience, then promoted in a subsequent commit (likely v0.1.1 or v0.2.0 entry).

Phase 5 does **not** ship: a second harness adapter (deferred to v0.2.0); a real-network test of `claude -p` in CI (NFR-004; opt-in via `CHANTIER_E2E_REAL_CLAUDE=1` for local dev, never CI); F2 (real-claude dispatch path coverage); F4 (strict worktree validation hardening); a fifth reference skill (FR-009 caps at four); ratification of ADR 0003 (Workflow skill design principles) or ADR 0004 (Surface 3 propagation) — both stay Proposed; `extract-skills-from-phase` (v0.3.0); STATE.md compaction (post-v0.1); the matrix of all four skills exercised through the adapter in `tests/e2e/` (the three not exercised are already proven via `core/tests/skill_*_e2e.bats` direct invocation from Phase 3; matrix-via-adapter is a v0.2 mechanical extension per Phase 3 D-17); a `chantier validate-roadmap` subcommand; a `chantier task-lookup` subcommand.

</domain>

<decisions>
## Implementation Decisions

### Dogfood feature & executing skill

- **D-01:** The "one small feature" planned-executed-verified through Chantier-on-Chantier is **Finding F3 from the Phase 4 handoff**: implement `upstream/` symlink staging for `depends_on` in `adapters/claude-code/run-task.sh`. Phase 4 plan 02 emitted an empty `upstream/` directory regardless of the task's `depends_on` field; Phase 5 closes the gap. The fix is a focused loop in the adapter: parse the task block's `depends_on` YAML key, and for each upstream task ID `tN`, create `$DOSSIER/upstream/tN/` as a symlink to `.planning/phases/$CHANTIER_PHASE/tasks/tN/` (or per-file `output.json` link, planner's call). The choice serves three goals at once — it fixes a real backlog finding, it exercises a Surface 2 path the adapter has not yet stressed (`upstream/` was always empty), and it gives the dogfood a natural two-task plan structure.
- **D-02:** The skill that executes the F3 fix is `test-driven-development`. The plan contains exactly two tasks: `t1` writes a failing bats test (`core/tests/adapter_upstream_e2e.bats` or similar — planner picks the name) that builds a synthetic two-task plan and asserts `upstream/t1/output.json` exists in `t2`'s dossier; `t2` modifies `adapters/claude-code/run-task.sh` to make the test green, and declares `depends_on: [t1]` so `upstream/t1/output.json` from t1's run is staged into t2's dossier (proving the F3 fix uses itself). TDD was already adapter-proven in Phase 4 D-13, the red→green is measurable via `output.json.red_step_timestamp < output.json.green_step_timestamp` (Phase 3 D-07), and the skill body already encodes the red-before-green invariant. The three other shipped skills (`using-git-worktrees`, `requesting-code-review`, `subagent-driven-development`) remain proven via Phase 3's direct `skill_*_e2e.bats` tests; their adapter coverage is v0.2 mechanical extension.

### tests/e2e/ integration test shape

- **D-03:** Phase 5 ships one bats file at `tests/e2e/full_loop.bats` (not `core/tests/`). It is the only file under the new top-level `tests/e2e/` directory in v0.1.0. The test creates a temporary project via `chantier new <name>` (real binary invocation — SC#1 explicitly requires "full new-project → plan → execute → verify"), writes a synthetic two-task `PLAN.md` mirroring the F3 dogfood shape, dispatches via the stub adapter, and asserts the full loop emits the expected STATE.md events plus a `validate-task`-green outcome on both tasks. Single-file integration test, no pre-canned fixture project. Mirror of Phase 4's `core/tests/adapter_claude_code_e2e.bats` style but at the full-loop scale (chantier new + multi-task plan + multi-dispatch + validate). The test loads the same `core/tests/test_helper/{bats-support, bats-assert}` submodules as the existing bats suite — no new test framework, no new helpers directory.
- **D-04:** Adapter dispatch in `tests/e2e/full_loop.bats` uses the `CHANTIER_CLAUDE_BIN` deterministic stub by default — same pattern as Phase 4 D-15, same NFR-004 compliance, same offline CI strict guarantee. A `CHANTIER_E2E_REAL_CLAUDE=1` env hook unsets `CHANTIER_CLAUDE_BIN` so the test invokes the real `claude -p` binary for opt-in local validation; CI never sets this flag. The stub shape from Phase 4 (`core/tests/adapter_claude_code_e2e.bats:82-91`) is reused — planner decides whether to extract the stub into `core/tests/test_helper/stubs/claude.sh` for DRY (light refactor) or duplicate the ~14-line stub inline (zero coupling). F2 (real-claude dispatch path) remains in v0.2 backlog: this is the env-gate that lets a future v0.2 contributor exercise it without further code change.

### NFR-001..006 independent audit shape

- **D-05:** Audits live in a single consolidated file `core/tests/nfr_audits.bats` with **six `@test` groups**, one per NFR. Single audit file — SC#4 "NFR-001 through NFR-006 are independently verified" is satisfied by the six discrete `@test`s, while the consolidated file makes the SC#4-to-test mapping obvious to any reader. Path is `core/tests/`, not `tests/e2e/` — audits are tree-level invariants that exist whether or not the e2e loop runs; the e2e workflow file at `tests/e2e/full_loop.bats` is workflow proof. Bats subsystem is the same (loads the same helpers, composes with the existing 73-test suite — Phase 5 close should land at 75/0 with the two new files).
- **D-06:** Per-NFR audit shape inside `nfr_audits.bats`:
  - **NFR-001 (no harness identifiers in skill bodies):** reuse the deny-list pattern from `core/tests/adapter_isolation.bats` — same regex, same path-only D-10 carve-out for `adapters/claude-code/`. The new audit's NFR-001 `@test` may delegate to `adapter_isolation.bats`'s logic via a sourced helper, or duplicate the small grep. The existing test is not deleted; the new `@test` is the SC#4-explicit gate that says "yes, NFR-001 is audited under tests/e2e dogfood, per ROADMAP".
  - **NFR-002 (POSIX sh + jq only):** `shellcheck --shell=sh` over every `.sh` file in `core/bin/`, `core/tests/`, `adapters/*/`, `skills/*/`; plus a grep for forbidden bash-only constructs (`[[ ]]`, `<<<`, `mapfile`, arrays). `command -v shellcheck` precondition; skip the `@test` with explanation if shellcheck is absent (matches existing bats pattern).
  - **NFR-003 (STATE.md append-only):** grep for `>` (single-redirect to `STATE.md`) outside `core/bin/chantier`'s `state_append` function — any code outside that one function writing to STATE.md is the violation. Audit the source tree, not runtime behavior. The runtime mkdir-mutex (Phase 2 D-09) is the runtime guard; this audit is the static guard.
  - **NFR-004 (no network by default):** grep for forbidden network primitives (`curl`, `wget`, direct IPs, `http://`, `https://`) in `core/bin/`, `adapters/*/run-task.sh`, `skills/*/run.sh`. Documentation `.md` files exempt (URLs in docs are fine). The opt-in `CHANTIER_E2E_REAL_CLAUDE` and the existing `CHANTIER_CLAUDE_BIN` defer to `claude -p` (whose network calls are the skill's opt-in per NFR-004); both are caught only if their invocation path is unconditional.
  - **NFR-005 (English only):** grep for common non-English glyph ranges (accented chars `é à ç ô ù`, etc.) outside `.planning/` (where French session prose appears in STATE.md summaries) and `docs/strategy/` (sketches may quote conversation). The audit walks `README.md`, `LICENSE*`, `CONTRIBUTING.md`, `docs/adr/`, `docs/vision.md`, `docs/research/`, `core/`, `skills/`, `adapters/`, `tests/`. Surfaces accidental French-leakage into public artifacts.
  - **NFR-006 (MIT + collective copyright):** assert `LICENSE` starts with `MIT License`; assert `LICENSE-CREDITS` exists; grep every `*.sh` for an `SPDX-License-Identifier: MIT` header (existing Phase 4 D-NFR-006 convention); grep that `Chantier Contributors` appears in `LICENSE` (collective copyright); no per-person individual `(c) <name>` in `LICENSE` or shebanged sources.

### ROADMAP migration & cutover off GSD

- **D-07:** ROADMAP migration is **minimalist**. Strip the temporary GSD-parser markers — specifically the "Format note (temporary)" callout block, the "GSD's `gsd-tools` parser format" disclaimer, and any GSD-specific indentation conventions (e.g., the `Plans:` un-bulleted header inside Phase blocks if the parser required it). Keep the narrative structure: front-matter, Phases overview list, Phase Details with Goal/Depends on/Requirements/Success Criteria/Plans subsections, Progress table. The frontmatter already validates against `core/schemas/roadmap.json` (Phase 2 D-06 — permissive `additionalProperties: true`); no schema change. No YAML-first rewrite, no `chantier validate-roadmap` subcommand (v0.2+ if real ergonomic need surfaces). Audit-friendly, minimal disruption, lets `git log` show "GSD → native" as a focused diff rather than a sea-of-changes rewrite.
- **D-08:** Cutover happens in the **final commit of Phase 5**, per SC#5 literal wording. Bundle in that single commit: (a) the ROADMAP migration diff per D-07; (b) any residual `gsd-sdk` / `gsd-tools` invocations removed from `.planning/` artifacts (none expected but the audit confirms); (c) a `cutover.completed` event appended to STATE.md via `chantier state append --event cutover.completed --summary "ROADMAP migrated to ADR 0001 native format. GSD ceases to be invoked in Chantier's own workflows."`. The event refs `[".planning/ROADMAP.md", "<commit-sha>"]`. Phase 4 plans and prior STATE.md history are NOT rewritten — the historical record of `bootstrap.harness.chosen` (2026-05-29T18:30:00Z) and the GSD-driven Phase 1–4 commits remain. Phase 5 itself is the last phase planned via `/gsd-plan-phase` per ROADMAP §Phase 5 "the last GSD-driven planning in Chantier's history"; once cutover is complete, future milestones plan via Chantier's own workflow layer (or, transitionally, by hand against ADR 0001 until v0.2 ships workflow skills).

### F1–F4 findings disposition

- **D-09:** F3 = **dogfood feature** (D-01). F1 = author **ADR 0004** in this phase, status Proposed, codifying the Surface 3 propagation contract that the Phase 4 plan 03 fix discovered (dossier → state_writes propagation via `cp` of plain files from dossier root to TASK_DIR, excluding `inputs.yml`, `env.sh`, `subagent.transcript.log`). Ratification of ADR 0004 is deferred — same pattern as ADR 0003: Proposed status, ratified once a second adapter exists and the contract is exercised cross-harness, likely in a v0.2 phase. F2 and F4 remain v0.2 backlog explicitly, with the explicit rationale recorded here so they are not silently lost: F2 requires an API key + opt-in CI gate (env-gated already wired via `CHANTIER_E2E_REAL_CLAUDE` in D-04 — the gate IS the v0.1 contribution); F4 (strict worktree validation) has no failure signal yet — the Phase 4 lax interpretation has produced zero incidents, and tightening without evidence is over-engineering per Chantier's "honest about what works" posture.

### Matrix skills coverage

- **D-10:** `tests/e2e/full_loop.bats` exercises **only `test-driven-development` via the adapter** (the skill chosen for the F3 dogfood feature in D-02). The three other shipped skills (`using-git-worktrees`, `requesting-code-review`, `subagent-driven-development`) are NOT exercised through the adapter in Phase 5. Rationale: (a) all four skills are already proven via Phase 3's `core/tests/skill_*_e2e.bats` (direct invocation tests, four files, four green); (b) the adapter pattern is proven via Phase 4's `adapter_claude_code_e2e.bats` (TDD via adapter, green); (c) extending coverage to the full 4×adapter matrix is mechanical per Phase 3 D-17 ("a harness joins `harness_adapters[]` only after an end-to-end test passes on that harness"); the test-pass criterion is satisfied for `claude-code` by Phase 4's TDD-via-adapter run, not by every skill exercised on every adapter. The full matrix is explicit v0.2 work — likely landing alongside the second harness adapter, when symmetric coverage matters.

### Claude's Discretion

The following implementation-level decisions remain open to planner / researcher refinement.

- **PLAN.md task pair shape for the F3 dogfood.** D-02 fixes the high-level structure (t1 writes failing test; t2 makes it green and uses depends_on:[t1]). Exact task IDs, exact `state_reads` / `state_writes` paths, exact `inputs` blocks, and exact `acceptance` bullets are the planner's call — must conform to ADR 0001 Surface 1 and the schemas in `core/schemas/plan.json` and `core/schemas/skill.json`.
- **The F3 fix shape inside `adapters/claude-code/run-task.sh`.** Whether to symlink the entire upstream task directory (`ln -s ../../.../tasks/tN $DOSSIER/upstream/tN`) or just the `output.json` file is open. Symlinking the dir is more general (the depending task may want more than `output.json`); per-file gives tighter least-privilege. Planner decides; the ADR 0001 Surface 2 example shows `upstream/t0/output.json` (file-level), which suggests file-level is the intent — but the adapter's job is to make `state_reads`-declared paths visible, so the planner should re-read ADR 0001 §"Surface 2" before deciding.
- **PLAN.md `depends_on` ordering enforcement.** The adapter must dispatch t1 before t2 (because t2's dossier needs t1's output). Whether the adapter itself topologically sorts when invoked as `run-task.sh t2` (and refuses to run if t1 hasn't completed), or whether the operator dispatches `run-task.sh t1` then `run-task.sh t2` manually, is open. The latter is simpler (consistent with D-16's "no flags in v0.1" Phase 4 stance); the former is more user-friendly. Planner picks; the dogfood test in `tests/e2e/full_loop.bats` can drive whichever choice deterministically.
- **ADR 0004 exact prose.** D-09 fixes status (Proposed) and the codified contract (Surface 3 propagation via `cp` from dossier root to TASK_DIR, excluding `inputs.yml` / `env.sh` / `subagent.transcript.log`). Exact wording, including the alternatives-considered section and the Consequences section, is the planner's authorship.
- **`nfr_audits.bats` shellcheck shape.** Whether the NFR-002 `@test` invokes `shellcheck --shell=sh` per-file in a loop, or uses `find ... -name '*.sh' -print0 | xargs -0 shellcheck --shell=sh`, is open. Both POSIX-portable; planner picks based on bats output legibility.
- **NFR-005 non-English glyph regex.** D-06 says "common non-English glyph ranges". Exact regex is planner discretion — likely `[À-ÿ]` UTF-8-class or a smaller hand-rolled set covering accented Latin chars; balance false-positives (e.g., `naïve` in English prose) against detection coverage.
- **`cutover.completed` event refs payload.** D-08 says refs include the ROADMAP path and the commit SHA. Whether to also include the prior `bootstrap.harness.chosen` event timestamp as a back-reference (`2026-05-29T18:30:00Z`) is open. Adds audit hygiene; small.
- **Whether to extract the `CHANTIER_CLAUDE_BIN` stub into a shared helper.** D-04 leaves this to planner. Extract to `core/tests/test_helper/stubs/claude.sh` if the stub is identical between `adapter_claude_code_e2e.bats` and `tests/e2e/full_loop.bats`; duplicate inline if the e2e variant needs extra behaviors (e.g., logging the dispatch sequence for the multi-task chain assertion).
- **Synthetic project name used in `chantier new` inside the e2e test.** Arbitrary string within bats tmp dir. Planner picks something descriptive (e.g., `chantier-e2e-dogfood`).
- **Whether to record `phase.completed` for Phase 5 via the adapter or via direct `chantier state append`.** The four prior phases recorded `phase.completed` via direct binary invocation (not through a skill). Symmetry suggests the same here, but it's not load-bearing.
- **Concurrency lock for parallel `run-task.sh` on the same task ID.** Carried from Phase 4 Claude's Discretion. The two-task chain (t1 sequential, then t2) does not exercise parallelism by design. If Phase 5 dogfood incidentally surfaces a need (unlikely), mkdir-mutex on `.chantier/dossiers/<task>/.lock` is the natural pattern.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Founding contract (load-bearing)

- `docs/adr/0001-state-skill-contract.md` — Surface 1 (PLAN.md task blocks; D-02's `depends_on` field; `state_reads` / `state_writes` containment), Surface 2 (dossier model; `upstream/` directory the F3 fix populates), Surface 3 (`output.md` + `output.json` + `chantier state append`; the propagation ADR 0004 codifies). §Validation gate enumerates the five gates `chantier validate-task` enforces. §Consequences "Subagent dispatch is safe" frames why D-04's stub is contract-honest. §Open questions OQ #4 (skill-to-skill composition) is NOT addressed by F3 — F3 is data-flow staging, not skill composition.
- `docs/adr/0002-runtime-binary-and-state-format.md` — codifies STATE.md JSONL row schema (D-08's `cutover.completed` event uses this schema), the dotted-namespace event-name regex (`cutover.completed` matches `^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$`), the deny-list pattern audited in D-06 NFR-001, the exit-code matrix the adapter and binary both honor.
- `docs/adr/0003-workflow-skill-design-principles.md` — **Proposed**, advisory only. The post-Phase-5 ratification target. Phase 5 dogfood may produce evidence that confirms or contradicts the four principles. Principle 4 ("chaining is explicit in PLAN.md, not magic in skills") informs D-02's choice to express the two-task chain as two PLAN.md tasks with `depends_on`, not as an internal skill composition.
- `docs/adr/0004-surface-3-propagation.md` (TO BE AUTHORED by Phase 5 per D-09) — **Proposed status**, codifies the dossier → TASK_DIR propagation contract (`cp` of plain files from dossier root to `.planning/phases/<phase>/tasks/<task>/`, excluding `inputs.yml`, `env.sh`, `subagent.transcript.log`) that Phase 4 plan 03 discovered. Ratification deferred until a second harness adapter exists.

### Phase scope and acceptance

- `.planning/ROADMAP.md` §Phase 5 — phase goal, dependencies, success criteria 1–5. SC#5 is the literal source for D-07/D-08 (cutover timing + final-commit semantics). SC#3 is the literal source for D-04 (offline-by-default). SC#4 is the literal source for D-05/D-06 (six NFRs independently verified).
- `.planning/REQUIREMENTS.md` — NFR-001..006 in scope for Phase 5 audits (D-05/D-06 map directly); FR-009 caps at four skills (used to defend D-01's choice to NOT create a fifth skill); Acceptance §"v0.1.0 ships when" lists the integration test in `tests/e2e/` as a literal v0.1.0 ship condition.
- `.planning/PROJECT.md` — v0.1.0 success criterion 5 ("Chantier's own development is managed by Chantier") is what Phase 5 closes; out-of-scope-forever list (no tokens, no SaaS, no harness replacement) constrains all decisions.

### Prior-phase decisions still load-bearing

- `.planning/phases/02-runtime-core/02-CONTEXT.md` — D-01 (STATE.md JSONL), D-08/D-09 (dotted-namespace events + shape regex), D-11 (commented-stub scaffold from `chantier new`), Claude's Discretion (mkdir-mutex pattern). D-04's `chantier new` invocation in `tests/e2e/full_loop.bats` runs the binary that Phase 2 shipped.
- `.planning/phases/03-skill-library/03-CONTEXT.md` — D-01/D-02 (uniform `run.sh` shape), D-04 (skill writes `skill.completed` itself), D-07 (every invariant has a measurable proof — D-02 leans on `red_step_timestamp < green_step_timestamp` for the TDD dogfood), D-14/D-17 (tested-only `harness_adapters: [claude-code]`; mechanical extension criterion for matrix coverage; D-10's deferral is this).
- `.planning/phases/04-claude-code-adapter/04-CONTEXT.md` — D-04 (exit matrix the e2e test asserts), D-05/D-06 (operator-pre-creates worktree; dossier worktree-local), D-13 (TDD red-phase fixture pattern), D-15 (CHANTIER_CLAUDE_BIN stub — D-04's direct ancestor), D-16 (single-positional-arg CLI). Discretion items consumed: the `attempts/<n>/` numbering, `task.started` event payload, transcript persistence — Phase 4 picked specific shapes; Phase 5 may rely on those shapes but may not redecide them.
- `.planning/phases/04-claude-code-adapter/04-SUMMARY.md` §Handoff Notes — F1–F4 findings (F1, F3 explicitly entering Phase 5 scope per D-09; F2, F4 explicitly out-of-scope). §"Surface 3 propagation discovery" — the source of ADR 0004 (D-09).

### Reusable runtime references

- `core/bin/chantier` — `state append` for the `cutover.completed` event (D-08), `validate-task` invoked twice in the e2e test (once per task in the chain, D-03), `new <name>` for the tmp project scaffold (D-03), `--self-test` not affected by Phase 5.
- `adapters/claude-code/run-task.sh` — the F3 fix locus (D-01). Currently emits empty `upstream/` at line ~118 (`mkdir -p "$DOSSIER/reads" "$DOSSIER/upstream" "$DOSSIER/skill"`); the fix adds a loop after that line that parses `depends_on` and stages symlinks/copies.
- `adapters/claude-code/README.md` — must be updated alongside the F3 fix if behavior changes for the operator (e.g., note that `upstream/` is now populated from `depends_on`).
- `core/tests/adapter_claude_code_e2e.bats` — the **shape mirror** for `tests/e2e/full_loop.bats`. Lines 82–91 are the `CHANTIER_CLAUDE_BIN` stub; lines 55–68 are the real `git worktree add` setup. Phase 5's e2e composes both at the larger scale (full loop, not just one task).
- `core/tests/adapter_isolation.bats` — the **NFR-001 audit pattern** D-06 reuses. The deny-list regex, the path-only carve-out shape, the HARNESS_DENY_LIST_CHECK marker convention all carry into `nfr_audits.bats`.
- `core/tests/skill_test_driven_development_e2e.bats` — the **direct-invocation TDD test** that proves the skill in isolation. The dogfood test (D-03) is the through-the-adapter sibling.
- `core/tests/fixtures/skills/test-driven-development/dossier/inputs.yml` — the deterministic red-phase fixture (`test_command: "false"`). Reused (or analog) for the F3 dogfood's two tasks.
- `core/tests/test_helper/{bats-support, bats-assert}` — submodules every bats file loads; `tests/e2e/full_loop.bats` and `core/tests/nfr_audits.bats` both load them.
- `core/schemas/{plan,roadmap}.json` — Phase 5's PLAN.md (the dogfood phase plan) must validate; ROADMAP.md after D-07 migration must validate.

### Lineage and posture

- `docs/research/inheritance-map.md` — §6 (#237 finding + subagent isolation) is the load-bearing rationale for why D-04's stub remains contract-honest (the subagent sees only its dossier and skill body; the stub satisfies that interface).
- `docs/strategy/maturity-path.md` — sketch only, non-binding. Phase 5 dogfood produces the evidence that will determine whether the post-v0.1.0 sketch is acted on. NOT a planning input.
- `docs/vision.md` — the project thesis. Phase 5 closes the loop the thesis claims (macro continuity + micro discipline united by a file-readable contract); the integration test is the proof.
- `LICENSE` — the file the NFR-006 audit (D-06) reads. MIT collective copyright must remain.
- `LICENSE-CREDITS` — the file NFR-006 asserts the existence of. Greenfield posture preserved.

### Out-of-scope reminders (deferred, do not address in Phase 5)

- Second harness adapter (`adapters/cursor/`, `adapters/codex-cli/`, etc.) — v0.2.0 per REQUIREMENTS §Out of scope. The `nfr_audits.bats` deny-list pattern (D-06) is already shaped to work when a second adapter ships (add a case-arm).
- F2 (real-claude dispatch path in CI) — v0.2 via the `CHANTIER_E2E_REAL_CLAUDE` env gate (D-04 ships the gate; no CI use).
- F4 (strict worktree validation) — v0.2 unless a real failure signal surfaces during Phase 5.
- Fifth reference skill — FR-009 caps at four for v0.1.0.
- `chantier validate-roadmap` subcommand — v0.2+ if ergonomic need surfaces.
- `chantier task-lookup` subcommand — Phase 4 Claude's Discretion deferred; same posture in Phase 5.
- Matrix-via-adapter coverage of the 4 skills — v0.2 mechanical extension per Phase 3 D-17.
- ADR 0003 ratification — post-Phase 5, requires v0.2 evidence.
- ADR 0004 ratification — post-Phase 5, requires a second harness adapter to validate the contract cross-harness.
- STATE.md compaction — post-v0.1 per ADR 0001 OQ #2.
- `extract-skills-from-phase` — v0.3.0 per PROJECT.md.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `core/bin/chantier` exposes the three subcommands the e2e test drives (`new`, `state append`, `validate-task`). The 975-line POSIX-shell binary is the unit under integration — `tests/e2e/full_loop.bats` exercises its public surface end-to-end.
- `adapters/claude-code/run-task.sh` (253 lines, ships at Phase 4) is the dispatch primitive. Phase 5 modifies it for the F3 fix (D-01); the existing 16 D-NN decisions remain load-bearing.
- `core/tests/adapter_claude_code_e2e.bats` (293 lines) is the **shape mirror** for the new e2e test. The `setup()` block creates a real linked worktree via `git worktree add`; the `CHANTIER_CLAUDE_BIN` stub at lines 82–91 is the deterministic dispatcher; the validate-task assertion at the end is the gate. Phase 5's new e2e composes all three at the larger scale.
- `core/tests/adapter_isolation.bats` (124 lines) is the **NFR-001 audit pattern** template. The deny-list regex (byte-identical to `core/bin/chantier:687`/:912), the path-only D-10 carve-out, the HARNESS_DENY_LIST_CHECK marker, and the POSIX find/grep/case-arm idiom are all carried into `nfr_audits.bats`.
- `core/tests/skill_test_driven_development_e2e.bats` is the direct-invocation TDD test; the dogfood's `tests/e2e/full_loop.bats` is its through-the-adapter sibling.
- `core/tests/fixtures/skills/test-driven-development/dossier/inputs.yml` — deterministic red-phase fixture (`test_command: "false"` → exits 1). Either reused verbatim for the F3 dogfood's two tasks, or analog fixtures authored per task.
- `core/tests/test_helper/{bats-support, bats-assert}` submodules — loaded by every existing bats file; `tests/e2e/full_loop.bats` and `core/tests/nfr_audits.bats` load them identically.
- `chantier state append` event taxonomy includes `task.started`, `task.completed`, `task.failed`, `skill.completed`, `phase.completed`, `cutover.completed` (Phase 5's contribution). All match the D-09 regex from ADR 0002.

### Established Patterns

- **Greppable enforcement** — Phase 2's event-shape regex, Phase 3's `skill_uniformity.bats`, Phase 4's `adapter_isolation.bats`, `core/bin/chantier`'s `HARNESS_DENY_LIST_CHECK` marker. `core/tests/nfr_audits.bats` is the next instance, with six grep-based `@test`s.
- **Path-only enforcement over flag/marker enforcement** — Phase 4 D-09/D-10 codified this; D-06 NFR-001/004/005 follow. `adapters/claude-code/` and `docs/` carve-outs are by path, not by per-line opt-out comment.
- **Belt-and-suspenders multi-layer enforcement** — Phase 4 D-07 (env.sh + process exports + subagent sources); Phase 5 D-04 (CHANTIER_CLAUDE_BIN default stub + CHANTIER_E2E_REAL_CLAUDE opt-in + NFR-004 static audit) is the same instinct.
- **Symmetric UX across binary/adapter** — Phase 4 D-16 (`run-task.sh <task-id>` mirrors `chantier validate-task <task-id>`); Phase 5 inherits and does not extend.
- **POSIX shell + jq substrate** — NFR-002. The F3 fix in `run-task.sh` stays in POSIX sh; no helper scripts in other languages.
- **Deterministic stub for offline CI** — Phase 4 D-15 (`CHANTIER_CLAUDE_BIN` stub); Phase 5 D-04 reuses verbatim, adds the opt-in real-claude env gate.
- **mkdir-as-mutex for concurrency** — Phase 2 `state_append` uses it; Phase 5 does not exercise parallelism by design (two-task sequential chain), but the pattern is available if needed.
- **Greenfield originality** — `LICENSE-CREDITS`; Phase 5 authors original Chantier code, not lifted from any predecessor. The dogfood test exercises Chantier's own surface only.
- **Conditional file inclusion via `case` arm in bats audits** — `adapter_isolation.bats` uses this for path-specific exemptions; `nfr_audits.bats` extends the pattern across the six audits.

### Integration Points

- **Skill `run.sh` contract (Phase 3 D-01/D-02/D-04).** The dogfood plan's two tasks both invoke `skills/test-driven-development/run.sh`. The skill body is unchanged; only the plan structure changes (depends_on: [t1] in t2).
- **`chantier validate-task` gates 1–5.** Invoked twice in the e2e test (once per task in the chain). Gate 1 (state_writes containment) catches accidental leakage; gate 2 (output.md exists) and gate 3 (output.json schema match) are the propagation contract from ADR 0004; gate 4 (deny-list grep) is the static NFR-001 mirror; gate 5 (Acceptance items) is the discipline gate.
- **`harness_adapters: [claude-code]` in every Phase 3 SKILL.md.** Phase 5 dogfood validates this declaration through a multi-task chain — the strongest claim yet that TDD-via-claude-code works in the full ADR 0001 contract. The other three skills' adapter coverage remains "by analogy" per Phase 3 D-17 mechanical extension criterion.
- **STATE.md JSONL append-only.** Phase 5 emits five new event types in normal operation: `task.started` × 2, `skill.completed` × 2, `task.completed` × 2, `plan.completed` (Phase 5 plan close), `phase.completed` (Phase 5 close), `cutover.completed` (the final commit). Plus prior phases' history. NFR-003 audit (D-06) ensures no static violation of append-only.
- **F3 fix touches `adapters/claude-code/run-task.sh:~118`.** The current `mkdir -p "$DOSSIER/reads" "$DOSSIER/upstream" "$DOSSIER/skill"` line is augmented (NOT replaced) by a `depends_on` parsing loop + symlink/copy commands. The existing 16 D-NN decisions all remain valid; only behavior for non-empty `depends_on` is added.
- **`docs/adr/` is a new file (`0004-surface-3-propagation.md`).** Existing ADR template (matches 0001/0002/0003 style — Markdown with status frontmatter, Context, Decision, Consequences, Alternatives, Open questions).
- **`.planning/ROADMAP.md` migration is in-place edit, not file recreation.** Existing git blame history preserved; the diff is the narrowest possible per D-07.

### Empty directory awaiting Phase 5

- `tests/` — does not exist yet. Phase 5 creates `tests/e2e/` with `full_loop.bats`. Future top-level test categories (`tests/integration/`, `tests/manual/`, etc.) would slot in here; Phase 5 ships only `tests/e2e/`.

</code_context>

<specifics>
## Specific Ideas

- The user accepted the recommended option on all 8 question turns across the four areas. This continues the Phase 3 + Phase 4 pattern (16/16 then 8/8). Planner can treat the recommended options as load-bearing rather than tentative; deviation requires explicit rationale.
- The user's instinct here is **minimal disruption** — D-07 (ROADMAP minimalist migration), D-05 (consolidated single-file audit), D-09 (F2/F4 stay in backlog explicitly) all favor the smallest viable change. Matches the Phase 4 instinct ("path-only separation over flag-based exemption") at the Phase 5 scale.
- **Convergence of the F3 fix and the integration test** — D-01 (feature) and D-03 (test shape) share a substrate: the two-task chain. The same `depends_on` parsing logic the F3 fix implements is what `tests/e2e/full_loop.bats` exercises. This is intentional Chantier-on-Chantier: the test that proves the framework works is also the test that proves the fix works, and both are the same workflow.
- **ADR 0004 as the codification reflex** — D-09's choice to author ADR 0004 in Proposed status (rather than skipping or ratifying immediately) mirrors ADR 0003. Chantier's pattern is "discover during execution → codify in ADR → ratify after cross-experience evidence." Phase 5 surfaces a second instance of the same pattern; planner should treat this as a project convention, not a one-off.
- **The `CHANTIER_E2E_REAL_CLAUDE` env gate as v0.1's contribution to F2** — D-04's opt-in flag is the wire that v0.2 will use; Phase 5 ships the wire but not the use. Same posture as Phase 4 D-15: ship the indirection now, exercise it later when real-claude validation matters.
- **Skill matrix posture** — D-10 explicitly rejects the matrix-via-adapter at Phase 5, with rationale tied to Phase 3 D-17. Planner should not be tempted to "just add a few more @tests" to round out coverage; the mechanical extension is v0.2 by design.

</specifics>

<deferred>
## Deferred Ideas

These were touched during discussion but explicitly deferred to keep Phase 5 focused:

- **Second harness adapter (`adapters/cursor/`, `adapters/codex-cli/`, etc.).** REQUIREMENTS §Out of scope for v0.1.0. The `nfr_audits.bats` deny-list is shaped to accommodate a second adapter via a single case-arm addition.
- **F2 (real-claude dispatch path coverage in CI).** v0.2 work via the `CHANTIER_E2E_REAL_CLAUDE=1` env gate (D-04 ships the gate; no CI use in v0.1).
- **F4 (strict worktree validation).** v0.2 unless a Phase 5 dogfood incident surfaces. The Phase 4 lax interpretation has produced zero failures.
- **Fifth reference skill (e.g., `receiving-code-review`).** FR-009 caps v0.1 at four skills. v0.2+ extension.
- **`chantier validate-roadmap` subcommand.** ROADMAP migration in D-07 is in-place edit; the binary does not gain a new verb in v0.1. Considered if v0.2 ergonomic need surfaces.
- **`chantier task-lookup` subcommand.** Phase 4 Claude's Discretion deferred; Phase 5 inherits the same posture (PLAN.md task lookup remains inline in the adapter).
- **YAML-first ROADMAP rewrite.** Considered for D-07; rejected as too disruptive for v0.1.0. Markdown narrative preserved.
- **Matrix-via-adapter coverage of the 4 skills (one e2e per skill through `tests/e2e/`).** v0.2 mechanical extension per Phase 3 D-17. Phase 5 covers TDD only via adapter.
- **ADR 0003 ratification (workflow skill design principles).** Post-Phase 5 per the ADR itself. Phase 5 produces dogfood evidence; ratification commit lands in a later milestone.
- **ADR 0004 ratification (Surface 3 propagation).** Authored in Proposed status this phase (D-09); ratification requires a second harness adapter to validate the contract cross-harness — v0.2+.
- **STATE.md compaction.** Post-v0.1 per ADR 0001 OQ #2. Phase 5 adds ~6 new event types in normal operation plus the prior phases' history; compaction need will be evaluated at v0.2 entry.
- **`extract-skills-from-phase` self-improvement skill.** v0.3.0 per PROJECT.md.
- **Concurrency lock for parallel `run-task.sh` invocations.** Phase 4 Claude's Discretion; Phase 5 does not exercise parallelism by design. mkdir-mutex on `.chantier/dossiers/<task>/.lock` is the natural pattern when needed.
- **Subagent transcript persistence behind `CHANTIER_TRANSCRIPT=1`.** Phase 4 carried-forward. v0.2 ergonomic gate.
- **Workflow skill authoring (the candidate 7-skill set in `docs/strategy/maturity-path.md`).** v0.2.0+ per the strategy sketch; ADR 0003 must ratify first.
- **Extension of `--self-test` to cover the six NFRs.** Considered for D-05; rejected (runtime/audit coupling violates ADR 0002 separation).
- **`tests/integration/`, `tests/manual/`, other top-level test categories.** Phase 5 creates `tests/e2e/` only; future categories slot in here.

</deferred>

---

*Phase: 5-Dogfood E2E*
*Context gathered: 2026-05-30*
