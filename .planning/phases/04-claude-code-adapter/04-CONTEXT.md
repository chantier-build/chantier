# Phase 4: Claude Code adapter - Context

**Gathered:** 2026-05-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 4 ships the first harness adapter at `adapters/claude-code/` and proves the ADR 0001 Surface 2 dossier model is implementable end-to-end. The adapter is a POSIX-shell entry point that, given a task ID, stages a per-task dossier inside the operator's worktree, dispatches a Claude Code subagent via the headless `claude -p` binary to read the skill body and execute `run.sh`, and surfaces the result to `chantier validate-task`. The phase also adds the mechanical guard that proves `adapters/claude-code/` is the only place in the source tree allowed to name the harness.

Phase 4 ships when: (1) `adapters/claude-code/run-task.sh <task-id>` stages a dossier at `$WORKTREE/.chantier/dossiers/<task>/` containing `inputs.yml`, `reads/`, `upstream/`, `env.sh` per ADR 0001 Surface 2; (2) the adapter dispatches a subagent that reads `SKILL.md` and executes the skill's `run.sh`; (3) one end-to-end task invocation of the `test-driven-development` skill passes `chantier validate-task` green inside a pre-created git worktree; (4) a new bats audit (`core/tests/adapter_isolation.bats`) verifies that `claude-code` and `mcp__claude_ai_` appear nowhere in the audited tree except under `adapters/claude-code/`.

Phase 4 does **not** ship: the full integration test that exercises new-project → plan → execute → verify (Phase 5 owns `tests/e2e/`); a second harness adapter (deferred to v0.2.0); the migration of `ROADMAP.md` back to Chantier-native format (Phase 5); auto-invocation, multi-task batching, or parallel dispatch; a real-network test against the Anthropic API (NFR-004 — the e2e uses a deterministic stub via `CHANTIER_CLAUDE_BIN`); ratification of ADR 0003 (still Proposed; this phase only USES Principles 3-4 as informants, does not promote the ADR).

</domain>

<decisions>
## Implementation Decisions

### Dispatch mechanism

- **D-01:** The adapter dispatches a real Claude Code subagent via the headless CLI: `claude -p "<prompt>"`. A vrai sous-process per task — isolation conforms to ADR 0001 ("subagent receives only its dossier and the skill body; both are file paths") and to the framing phrase "a plain shell script that wraps an LLM call." The adapter itself stays POSIX sh; NFR-002's `sh + jq` substrate is preserved.
- **D-02:** The dispatch prompt is a minimal heredoc inlined in `run-task.sh`, ~15 lines. It tells the subagent: `cd` into the dossier, source `env.sh`, read `skill/SKILL.md`, acknowledge invariants, exec `skill/run.sh`, report the exit code. The prompt is a **pointer**, not a re-statement of discipline — the discipline lives in the SKILL.md body. Aligns ADR 0003 (Proposed) Principle 3 "thin skill, smart LLM." No sibling template file, no `--allowedTools` whitelist in v0.1 (validate-task gate 4 is the post-hoc guard).
- **D-03:** The adapter brackets each task with two STATE.md events: `task.started` before invoking `claude -p`, and `task.completed` (validate-task green) or `task.failed` (any earlier exit non-zero, OR validate-task red) after. The skill's `run.sh` continues to append its own `skill.completed` per Phase 3 D-04. Net: three events per successful task — `task.started` (adapter), `skill.completed` (skill), `task.completed` (adapter). Failure mode emits `task.started` + `task.failed` (skill may or may not reach `skill.completed`).
- **D-04:** The adapter reproduces the binary's 4-value exit-code matrix: `0` = green (skill exit 0 and validate-task gate 5 green), `1` = contract violation (validate-task red), `2` = invocation error (malformed dossier, missing PLAN/SKILL lookup, claude returned non-zero for prompt-level reasons), `3` = environment error (`claude` binary not on PATH or not executable, `jq` missing). On validate-task red, the adapter moves `output.md` + `output.json` to `phases/N/tasks/<task>/attempts/<n>/` (n auto-incremented), then exits 1. Re-running `run-task.sh` repeats from scratch and increments n on the next failure. Aligns ADR 0001 §"A failed validation is a re-runnable error, not a destructive one."

### Worktree integration

- **D-05:** The operator pre-creates the git worktree with `git worktree add` and `cd`s into it before invoking `run-task.sh`. The adapter does not call `git worktree add`. On invocation, the adapter validates `git rev-parse --is-inside-work-tree` and refuses to proceed if false (exit 2, invocation error). Separation rationale: `using-git-worktrees` is the project-level worktree skill for the developer's own work; the adapter's worktree is the operator's responsibility. ROADMAP SC#3 ("executed in a worktree") is satisfied by the test setup performing `git worktree add` before invoking the adapter.
- **D-06:** The dossier lives at `$WORKTREE/.chantier/dossiers/<task>/` — worktree-local, not main-repo-shared. Parallel-safe by construction (two worktrees = two dossier roots). Cleanup of a worktree (`git worktree remove`) atomically purges its dossier + outputs. The `<task>` segment is the task ID from PLAN.md, never a filename.
- **D-07:** `env.sh` is belt-and-suspenders. The adapter writes `env.sh` into the dossier with `CHANTIER_TASK_ID`, `CHANTIER_PHASE`, `CHANTIER_WORKTREE` exported (forensic record + ADR 0001 contract). The adapter ALSO exports the same vars in its own process before invoking `claude -p` (subprocess inheritance — `claude -p` inherits env). The subagent prompt (D-02) instructs the subagent to `source ./env.sh` after `cd`'ing into the dossier (the load-bearing path). Triple safety — if one layer leaks, the vars remain present. Zero modification to Phase 3 skills (which read PWD + rely on externally exported `CHANTIER_TASK_ID`, as `core/tests/skill_*_e2e.bats` already do).
- **D-08:** After a successful task (validate-task green), the dossier at `$WORKTREE/.chantier/dossiers/<task>/` is **preserved**, not deleted. The operator (or a future cleanup skill) decides when to purge. Forensic inspection — "what did the subagent see as input?" — remains possible days later. Cost: `.chantier/dossiers/` grows with each run; worktree-local scope bounds the growth, and `git worktree remove` purges everything in one shot. Symmetric with the `attempts/<n>/` preservation policy (D-04).

### NFR-001 carve-out for the adapter

- **D-09:** A new bats test, `core/tests/adapter_isolation.bats`, audits the source tree for cross-harness contamination. It greps for the ADR 0002 deny-list pattern (`mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode`) and asserts zero matches outside the allowed paths. Path-only exemption — no marker file, no per-line opt-out comment. Composes naturally with the Phase 2/3 grep-based enforcement pattern (event shape regex, harness deny-list, skill uniformity).
- **D-10:** Inside `adapters/claude-code/`, the substrings `claude-code` and `mcp__claude_ai_` are allowed (the directory IS the harness's adapter; it may invoke MCP tools by name if it interacts with the Claude session). All OTHER deny-list substrings (`cursor`, `codex-cli`, `copilot-cli`, `gemini-cli`, `opencode`, bare `mcp__` outside `mcp__claude_ai_`) remain forbidden inside `adapters/claude-code/` — this is the cross-adapter pollution guard. When `adapters/cursor/` ships later, the same audit asserts the symmetric isolation for it.
- **D-11:** Audit scope is source/test paths: `core/`, `skills/`, `tests/`, and `adapters/*` except the path being audited. Exempt entirely: `docs/` (ADRs, vision, research, and strategy may freely name any harness), `.planning/` (notably STATE.md which logs free-form event summaries that already mention `claude-code` historically), and `core/bin/chantier` (which has its own `HARNESS_DENY_LIST_CHECK` marker for the `--self-test` self-scan). The audit and the binary's self-scan coexist; both exist for different scopes.
- **D-12:** The audit runs in the existing bats suite (no separate CI job, no subcommand on the binary). Failure mode: bats test red, surfaces the offending file path, blocks the merge. Aligns with how Phase 3's `skill_uniformity.bats` failed any cross-skill divergence.

### End-to-end proof shape

- **D-13:** The Phase 4 e2e exercises the `test-driven-development` skill via its red-phase fixture (`test_command: "false"`, exits 1 deterministically). Mirror of `core/tests/skill_test_driven_development_e2e.bats` — same fixture, same skill, but dispatched through the adapter (`claude -p`) instead of directly (`sh run.sh`). Comparable signal: `output.json.red_exit_code = 1`, `output.json.red_step_timestamp` ISO-8601, `invariants_applied` length ≥ 4, validate-task gate 5 green. Other three skills not exercised in this phase's e2e — Phase 5 dogfood may exercise the matrix.
- **D-14:** The e2e test lives at `core/tests/adapter_claude_code_e2e.bats`. Composes with the 71-test bats suite from Phase 2/3 (same loaders, same TMPHOME helper convention, same fixture style). Naming: `adapter_<harness>_e2e.bats` becomes the pattern for future adapter tests. Not under `adapters/claude-code/tests/` (avoids fragmenting test discovery); not under `tests/e2e/` (that path is reserved for Phase 5's integration-test).
- **D-15:** The test uses a deterministic stub of `claude` via `CHANTIER_CLAUDE_BIN`. The setup writes a ~10-line shell stub that does `cd "$DOSSIER" && . ./env.sh && sh ./skill/run.sh && exit $?`, plus a minimal echo of a "subagent transcript" line for trace fidelity. The adapter resolves `${CHANTIER_CLAUDE_BIN:-claude}` from PATH. Result: offline, deterministic, NFR-004-compliant, no API key needed. The real `claude` binary works in local dev when the env var is unset. Phase 5 may layer a real-claude variant for a real LLM dogfood.
- **D-16:** Operator-facing CLI: `adapters/claude-code/run-task.sh <task-id>`. Single positional argument, the task ID. The adapter discovers the plan via the same mechanism as `chantier validate-task <task>` — walk `cwd`'s `.planning/phases/*/PLAN.md` files, find the YAML task block whose `task:` field matches. Symmetric and consistent with the binary's UX. No `--plan`, no `--worktree` flags in v0.1 — needs emerge later. Flag-based options are deferred until a real ergonomic need surfaces.

### Claude's Discretion

The following implementation-level decisions remain open to planner / researcher refinement.

- **Subagent transcript persistence.** The stub records a faux subagent transcript line; whether the real `claude -p` invocation also captures its stdout/stderr into a `subagent.transcript.log` file under the dossier (for forensics) is open. Suggested but not mandated; planner decides based on `claude -p` output verbosity.
- **PLAN.md task lookup mechanics.** Resolving `<task-id>` to a plan file: should the adapter reuse the lookup that `chantier validate-task` already implements (call the binary as a subprocess, e.g. `chantier task-lookup <id>` if such a subcommand exists or is added), or duplicate the walk-and-grep inline? Planner picks based on whether such a binary subcommand exists or would be cheap to add.
- **Stub script invocation contract.** The stub at `CHANTIER_CLAUDE_BIN` must accept whatever flags/args `claude -p` accepts (since the adapter calls `$CHANTIER_CLAUDE_BIN -p "$PROMPT"`). The stub may ignore most of them; exact ignored-flag handling is planner's call. A minimal robustness contract: `-p` is recognized; stdin/stdout are passthrough-ish.
- **Worktree validation strictness.** The adapter refuses to run outside a worktree (`git rev-parse --is-inside-work-tree` false → exit 2). Whether the validation also forbids running in the **main** working tree (i.e., `git rev-parse --show-toplevel` equals the main repo, not a linked worktree) — i.e., "you must be in a `git worktree add`-created worktree, not the original checkout" — is planner discretion. Strict interpretation aligns with ROADMAP SC#3; lax interpretation simplifies dev.
- **Audit shell syntax.** The exact grep invocation in `adapter_isolation.bats` (e.g., `grep -rln 'pat' --include='*.sh' --include='*.md' core/ skills/ tests/ adapters/cursor/ ...` vs `find ... -type f -exec grep ...`) is planner's call. Must be POSIX-portable (no `--include` if it's a GNU extension that BSD grep lacks; consider `find ... -print0 | xargs -0 grep`).
- **task.started event payload.** `task.started` event ts/actor/refs are open; the minimum is `task: "<id>"`, `skill: "<skill-id>"`, `summary: "dispatch via claude-code adapter"`. Whether to include `worktree: "<path>"` in refs is planner's call.
- **`attempts/<n>/` numbering.** Lookup the next n by globbing `attempts/[0-9]*` and incrementing the max — straightforward; planner picks zero-pad width (likely 2 or 3 digits).
- **Subagent prompt heredoc wording.** ~15-line target is the budget; exact prose is the planner's responsibility. Must reference SKILL.md by path, must instruct ack-then-exec ordering, must reference `env.sh` sourcing.
- **Dispatch concurrency.** Two `run-task.sh` invocations on the same task ID in the same worktree: not designed for safe parallelism in v0.1. Whether to add a mkdir-mutex lock on `.chantier/dossiers/<task>/.lock` (analog of Phase 2's `state_append` mutex) is planner discretion. Recommend leaving out for v0.1; surface as a deferred idea if real concurrency need emerges.
- **`output.md` Acceptance section pass-through.** The skill writes Acceptance items into `output.md`; gate 5 substring-matches them. The adapter is unaware of this contract beyond passing it through. No discretion needed unless `claude -p` mangles the output.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Founding contract (load-bearing)

- `docs/adr/0001-state-skill-contract.md` — Surface 2 defines the dossier shape (`inputs.yml`, `reads/`, `upstream/`, `env.sh` with the three required exports) that the adapter must stage; Surface 3 defines the `output.md` / `output.json` / `chantier state append` triplet that the skill produces. §"Validation gate" enumerates the five gates `chantier validate-task` enforces — D-04's matrix maps to gate outcomes. §Consequences "Subagent dispatch is safe" frames the #237 finding that the dispatch model (D-01, D-02) must respect.
- `docs/adr/0002-runtime-binary-and-state-format.md` — codifies the deny-list pattern (`mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode`) that D-09/D-10/D-11 audit against, the exit-code matrix (0/1/2/3) D-04 mirrors, the event-name regex `^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$` that D-03's `task.started`/`task.completed`/`task.failed` events satisfy, and the `HARNESS_DENY_LIST_CHECK` marker convention D-11 explicitly coexists with.
- `docs/adr/0003-workflow-skill-design-principles.md` — **Proposed**, advisory only. Principle 3 ("thin skill, smart LLM") informs D-02's minimal-prompt choice; Principle 4 ("chaining is explicit, in PLAN.md") informs D-05's refusal to internally compose `using-git-worktrees`. This phase does NOT ratify ADR 0003.

### Phase scope and acceptance

- `.planning/ROADMAP.md` §"Phase 4: Claude Code adapter" — phase goal, dependencies, success criteria 1–4 (especially SC#3 "in a worktree" → D-05/D-06, SC#4 "only file outside docs containing claude-code" → D-09/D-10/D-11).
- `.planning/REQUIREMENTS.md` — FR-008 (adapter exists, can stage a dossier), NFR-001 (no harness identifiers — and its escape hatch for the adapter itself, D-10), NFR-002 (POSIX sh + jq — applies to `core/bin/chantier`, not the adapter, but the adapter sticks to POSIX sh by D-01), NFR-004 (no network — D-15 stub), NFR-005 (English public artifacts).
- `.planning/PROJECT.md` — v0.1.0 success criterion 4 ("Claude Code harness adapter works end-to-end"); out-of-scope-forever list (no harness replacement — the adapter is the bridge, never the substrate).

### Prior-phase decisions still load-bearing

- `.planning/phases/02-runtime-core/02-CONTEXT.md` — Phase 2 set the `STATE.md` JSONL format, the dotted-namespace event convention, and the mkdir-mutex pattern. D-03's events follow Phase 2's convention; the planner may reach for mkdir-mutex if dispatch concurrency surfaces.
- `.planning/phases/03-skill-library/03-CONTEXT.md` — D-01 (uniform `run.sh`) makes the adapter's one-code-path policy possible; D-02 (`run.sh` is the deterministic worker) means the adapter never re-implements the skill's mechanics; D-04 (skills `chantier state append` themselves) is why the adapter's bracketing events (D-03) do NOT include `skill.completed`; D-05/D-08 (subagent acknowledge invariants) is the discipline framing the prompt (D-02) instructs the subagent to follow; D-14 (`harness_adapters: [claude-code]`) is the tested-only claim THIS phase is shipping to validate; D-17 (mechanical extension criterion) means the test in D-14 becomes the template for the next adapter.
- `.planning/phases/03-skill-library/03-SUMMARY.md` — confirms the four skills are shipped and the bats suite is at 71/0 going into Phase 4.

### Reusable runtime references

- `core/bin/chantier` — lines 666–702 (gate 4 deny-list grep, scans skill body files); lines 905–913 (`--self-test` HARNESS_DENY_LIST_CHECK self-scan with marker); the existing exit-code matrix the adapter mirrors. The adapter calls this binary for `state append` (events) and `validate-task` (gate). The binary does NOT extend to scan `adapters/`; that's what `adapter_isolation.bats` (D-09) adds.
- `core/schemas/skill.json` — `harness_adapters` enum (currently `["claude-code"]`); declared in every Phase 3 skill's SKILL.md frontmatter. Phase 4 ships the adapter that validates the declaration.
- `core/tests/skill_test_driven_development_e2e.bats` — D-13's e2e mirror reuses this test's setup pattern (TMPHOME, make_plan helper, fixture dossier copy, validate-task assertion). The new `adapter_claude_code_e2e.bats` (D-14) shares the loaders and helpers.
- `core/tests/fixtures/skills/test-driven-development/dossier/inputs.yml` — the deterministic red-phase fixture (`test_command: "false"`) that D-13's e2e reuses verbatim.
- `skills/test-driven-development/SKILL.md` and `run.sh` — the body the subagent reads and the script the subagent execs. Frontmatter declares `harness_adapters: [claude-code]` which Phase 4 must keep valid.
- `skills/using-git-worktrees/` — adjacent skill, NOT composed by the adapter (D-05). Reference for what a project-level worktree skill looks like, distinct from adapter-level worktree posture.

### Lineage and posture

- `docs/research/inheritance-map.md` §6 (subagent + worktrees + the #237 caveat) — the structural reason D-01 mandates a real subagent process and D-02 keeps the prompt thin.
- `docs/strategy/maturity-path.md` — sketch only; non-binding. Frames "Family B — Workflow skills" which the adapter sits adjacent to but is NOT (the adapter is harness-glue, not a workflow skill).
- `LICENSE-CREDITS` — greenfield posture; the adapter is original Chantier code, not ported from any predecessor framework.

### Out-of-scope reminders (deferred, do not address in Phase 4)

- Second harness adapter (`adapters/cursor/`, etc.) — deferred to v0.2.0 per REQUIREMENTS §Out of scope.
- `tests/e2e/` integration test (full new-project → plan → execute → verify loop) — Phase 5 owns this.
- Network-attached test with real `claude` API — NFR-004 + D-15 stub policy.
- ADR 0001 OQ #3 (inputs_schema strictness) — still deferred; the adapter accepts whatever `inputs.yml` the dossier holds.
- ADR 0001 OQ #4 (skill-to-skill composition) — still deferred; the adapter does NOT compose `using-git-worktrees` (D-05).
- `chantier.lock` skill version pinning — still deferred.
- Auto-discover and dispatch a batch of tasks — out of scope for v0.1.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `core/bin/chantier` exposes `state append` (D-03's `task.started`/`task.completed`/`task.failed` go through this) and `validate-task` (D-04's gate is this binary's exit code). The adapter shells out to these as subprocesses; no new binary subcommand required.
- `core/bin/chantier` lines 666–702 implement gate 4 (deny-list grep over skill body files). The adapter's audit (D-09) is parallel-purpose for the adapter's directory but distinct location (a bats test, not a binary gate) and distinct scope (cross-tree, not per-skill-dir).
- `core/tests/skill_test_driven_development_e2e.bats` — the e2e shape Phase 4's `adapter_claude_code_e2e.bats` mirrors (TMPHOME isolation, make_plan helper, fixture dossier copy, validate-task assertion). Reuse loaders and helpers verbatim where possible.
- `core/tests/fixtures/skills/test-driven-development/dossier/inputs.yml` — the deterministic red-phase fixture D-13 reuses.
- Test-helper submodules `bats-support` and `bats-assert` under `core/tests/test_helper/` are loaded in every existing e2e bats; new adapter e2e loads the same.
- The `chantier state append` event taxonomy already includes `task.started`, `task.completed`, `skill.completed` (ADR 0002 §Event taxonomy table). D-03's events are within the existing namespace.

### Established Patterns

- **Greppable enforcement.** Phase 2's event shape regex (POSIX shell `case` + jq `test()`), Phase 3's `skill_uniformity.bats` (D-16), the binary's `HARNESS_DENY_LIST_CHECK` marker — all converge on the pattern Phase 4 extends: a bats test or binary check that surfaces violations via plain grep/regex, never via runtime validators. D-09 (adapter audit), D-13 (validate-task as e2e gate) follow.
- **Frontmatter-first documents + grep'able paths.** All `.planning/`, `docs/adr/`, `core/schemas/` artifacts lead with YAML or JSON Schema metadata. The adapter's own SKILL/PLAN-adjacent artifacts (if any — likely just `run-task.sh` itself + maybe a README) are not constrained to this pattern; the adapter is shell scripts, not authored documents.
- **POSIX shell + jq substrate.** Per NFR-002, the binary. The adapter is also written in POSIX shell (D-01) — no Bash-only features, no Python/Node. The dependency surface stays `sh + jq + git + claude`.
- **No-network default.** NFR-004. D-15's stub ensures the e2e is offline; real `claude` invocation is a local-dev or release-time concern, never a CI requirement.
- **mkdir-as-mutex for concurrency.** Phase 2's `state_append` uses `mkdir` as a portable POSIX mutex (per ADR 0002's "flock absent on macOS" finding). If dispatch concurrency surfaces as a Phase 4+ issue (planner discretion per Claude's Discretion list), the same pattern applies.
- **Greenfield originality.** Per `LICENSE-CREDITS`, the adapter is authored from scratch, not lifted from any predecessor. Superpowers / GSD-redux are inspiration via `docs/research/inheritance-map.md`, not code.

### Integration Points

- **Skill `run.sh` contract (Phase 3 D-01, D-02, D-04).** Skills' `run.sh` is the deterministic worker. The adapter stages the dossier → the subagent reads SKILL.md → the subagent invokes `run.sh` → `run.sh` writes `output.md` + `output.json` and appends `skill.completed` to STATE.md. The adapter NEVER writes outputs and NEVER re-implements skill mechanics.
- **`chantier validate-task` gates 1–5.** The adapter runs validate-task after the subagent finishes. Gate 4 (deny-list grep on skill body) and gate 5 (Acceptance items in `output.md`) are the most-likely-to-flake; D-04's `attempts/<n>/` quarantine catches failures non-destructively.
- **`harness_adapters: [claude-code]` declared in every Phase 3 SKILL.md frontmatter.** The Phase 4 adapter is what makes the declaration honest per Phase 3 D-14 (tested-only). The new adapter audit (D-09–D-12) is part of "tested-only" enforcement for the cross-adapter direction.
- **`STATE.md` JSONL format from ADR 0002.** D-03's adapter events use the same JSONL row schema (`ts`, `event`, `actor`, `task`, `skill`, `summary`, `refs`). No new schema, just new event namespace usage.

### Empty directory awaiting Phase 4

- `adapters/` — does not exist yet. Phase 4 creates `adapters/claude-code/` with `run-task.sh` and any necessary helpers; structure is greenfield, planner's design (within D-01–D-16 constraints).

</code_context>

<specifics>
## Specific Ideas

- The user accepted the recommended option on all 16 question turns across the four areas. Continuing the Phase 3 pattern. Planner can treat the recommended options as load-bearing rather than tentative; deviation requires explicit rationale.
- The user repeatedly favored **path-only separation over flag-based or marker-based exemption** (D-09 path-only audit over marker file; D-05 operator-pre-creates over flag-driven worktree creation). Aligned with the broader Chantier preference for `cat`/`jq`/`grep` legibility — paths are the simplest discriminator.
- **Belt-and-suspenders preferred over single-layer enforcement** for env.sh (D-07: file written + process export + subagent sources). Same instinct that produced Phase 2's two-pass event regex (case + jq) and Phase 3's `output.json` discipline metrics paired with PRESSURE.md Disqualifiers. The user trusts multiple-layer enforcement more than any single check.
- **Symmetric UX with `chantier validate-task`** (D-16: `run-task.sh <task-id>`) — the user opted for consistency over explicitness. Future adapter CLIs should follow the same single-positional-arg shape unless an emergent flag need surfaces.
- **Test the adapter against the strongest existing fixture** (D-13: TDD red phase). The user picked the skill with the most measurable outputs and the most deterministic fixture, not the simplest one. Same instinct as Phase 3 D-07 — falsifiable signal over textual ceremony.
- **ADR 0003 (Proposed) is consulted but not ratified.** Principle 3 informs D-02 (thin prompt) and Principle 4 informs D-05 (no internal composition); the principles are advisory inputs, not gates. Phase 5 dogfood may promote ADR 0003 to Accepted; Phase 4 stays out of that decision.

</specifics>

<deferred>
## Deferred Ideas

These were touched during discussion but explicitly deferred to keep Phase 4 focused:

- **Second harness adapter (`adapters/cursor/`, `adapters/codex-cli/`, etc.).** REQUIREMENTS §Out of scope for v0.1.0. The audit (D-09) is already shaped so it will Just Work when the second adapter ships — assert each adapter's own identifier appears only in that adapter's directory (cross-adapter pollution check). Revisit after Phase 5 dogfood.
- **`tests/e2e/` full integration test.** Phase 5 owns the new-project → plan → execute → verify loop. Phase 4's `core/tests/adapter_claude_code_e2e.bats` is a unit-flavored e2e against the adapter only, not the full loop.
- **Real `claude` API call in CI.** NFR-004 forbids network. D-15's `CHANTIER_CLAUDE_BIN` stub keeps the e2e offline; a real-claude variant for release-time validation is a v0.2+ concern (and likely requires an env-gated test, not a CI default).
- **`--allowedTools` lockdown on the subagent.** Considered for Q1.4 dispatch; deferred. ADR 0003 Principle 3 says the LLM decides "how"; validate-task gate 4 is the post-hoc guard. Revisit if the bats audit catches harness identifiers leaking into `output.md` despite the discipline framing.
- **Sibling template file for the dispatch prompt.** Considered for Q2 dispatch (template `adapters/claude-code/subagent.prompt.md`). Deferred — D-02's inline heredoc is sufficient; promote to a template only if the prompt grows past ~30 lines.
- **`subagent.transcript.log` capture.** Whether the adapter records `claude -p`'s stdout/stderr into the dossier for forensics. Claude's Discretion item; planner picks based on `claude -p` verbosity. Revisit if debugging real-claude dispatch becomes a recurring need.
- **PLAN.md task lookup via a new `chantier` subcommand.** Whether `core/bin/chantier task-lookup <id>` should exist as a reusable lookup or be inline in the adapter. Claude's Discretion item; if added, design must align with NFR-002.
- **Concurrent task dispatch safety.** Two `run-task.sh` invocations on the same task ID. Deferred — single-task dispatch is enough for v0.1. mkdir-mutex on `.chantier/dossiers/<task>/.lock` is the natural pattern when needed.
- **Composition of `using-git-worktrees` as a pre-task.** Explicitly rejected for D-05 (operator-pre-creates) and consistent with ADR 0003 (Proposed) Principle 4 (no implicit chaining). Re-open only if a strong dogfood signal in Phase 5 surfaces.
- **`run-task.sh` flag-based options.** No `--plan`, no `--worktree`, no `--dry-run` in v0.1 per D-16. Flag emergence is fine in v0.2 if real ergonomic need surfaces.
- **Strict-vs-lax worktree validation.** Whether `run-task.sh` refuses to run in the main checkout (only `git worktree add`-created worktrees are valid) is Claude's Discretion. Strict aligns ROADMAP SC#3; lax simplifies dev workflows.
- **`extract-skills-from-phase` self-improvement skill.** Already deferred to v0.3.0 per PROJECT.md.
- **ADR 0003 ratification.** Deferred until after Phase 5 dogfood per the ADR itself. Phase 4 USES the principles, does not promote them.
- **`STATE.md` compaction.** Still deferred per ADR 0001 OQ #2. Phase 4's three events per task add to STATE.md's growth; Phase 5 dogfood will surface whether compaction needs to come sooner.

</deferred>

---

*Phase: 4-Claude Code adapter*
*Context gathered: 2026-05-30*
