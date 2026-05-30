# Phase 5: Dogfood E2E — Research

**Researched:** 2026-05-30
**Domain:** Bats-driven end-to-end integration testing; POSIX-shell-adapter F3 fix (depends_on / upstream/ symlinking); cross-tree static audit (six NFRs); minimalist ROADMAP migration; ADR codification reflex
**Confidence:** HIGH

## Summary

Phase 5 closes Chantier v0.1.0 by eating its own dogfood: a single two-task plan, executed through the binary + adapter shipped in Phases 2–4, fixes the F3 finding (empty `upstream/` directories in the adapter) using the `test-driven-development` skill. The exercise produces three artifacts: (1) a top-level `tests/e2e/full_loop.bats` that re-runs a deterministic version of the workflow under offline CI, (2) a consolidated `core/tests/nfr_audits.bats` containing six `@test` blocks (one per NFR-001..NFR-006), and (3) ADR 0004 in Proposed status codifying the Surface 3 propagation contract that Phase 4 plan 03 discovered. The final commit migrates `.planning/ROADMAP.md` from the GSD-parser format back to the ADR-0001-native format and records a `cutover.completed` event. After this commit, Chantier ceases to depend on GSD's commands.

Decision density is extremely high — D-01..D-10 are locked in `05-CONTEXT.md` plus 11 Claude's Discretion items. The technical surface is small (~30 lines of POSIX sh in the adapter for the F3 fix, ~250 lines of bats e2e mirroring `adapter_claude_code_e2e.bats`, ~150 lines of bats audit reusing patterns from `adapter_isolation.bats`, ~70 lines of ADR 0004 in the established template). The hard problems are: (1) building a synthetic two-task `PLAN.md` whose `depends_on: [t1]` exercises the F3 fix while remaining hermetic and offline; (2) writing six NFR audits whose pass criteria are byte-stable across BSD `grep`/`awk`/`sed` (macOS dev) and GNU equivalents (CI); (3) authoring an NFR-005 regex that distinguishes legitimate URLs/quoted-conversation prose from accidental French leakage into English-only artifacts; (4) keeping the ROADMAP migration diff minimal enough that `git log -p` shows "GSD → native" as a focused change, not a sea-of-changes rewrite.

Environment is fully verified: `bats` 1.13.0, `shellcheck` 0.11.0, `jq` (binary already required), `git` 2.50.1 are all on the host. The CHANTIER_CLAUDE_BIN stub from Phase 4 (`core/tests/adapter_claude_code_e2e.bats:84-100`) is reusable byte-identically; the F3 fix integrates at `adapters/claude-code/run-task.sh:118` (the `mkdir -p` line that currently emits empty `upstream/`). All four shipped skills already declare `harness_adapters: [claude-code]`; matrix-via-adapter coverage is explicitly deferred to v0.2 per D-10.

**Primary recommendation:** Land work in four plans across three waves: **Wave 1** (parallel) — Plan 05-01 ships the F3 fix in the adapter + an in-tree bats regression test (the "t1 writes failing test → t2 makes it green" loop as the dogfood). Plan 05-02 authors ADR 0004 (Proposed) and `core/tests/nfr_audits.bats` with six `@test` blocks. **Wave 2** (blocks on Wave 1) — Plan 05-03 ships `tests/e2e/full_loop.bats` (end-to-end loop with `chantier new` + multi-task chain + `CHANTIER_E2E_REAL_CLAUDE` env gate). **Wave 3** (blocks on Wave 2; final commit of Phase 5) — Plan 05-04 ships the ROADMAP minimalist migration + `cutover.completed` event + Phase 5 close (SUMMARY.md). Full bats suite must go from 73/0 → 75/0 across Plans 05-02 and 05-03 (one new file each); `full_loop.bats` may add additional `@test`s under the same file count.

---

<user_constraints>

## User Constraints (from 05-CONTEXT.md)

### Locked Decisions

**Dogfood feature & executing skill:**

- **D-01:** The "one small feature" planned-executed-verified through Chantier-on-Chantier is **Finding F3 from the Phase 4 handoff**: implement `upstream/` symlink staging for `depends_on` in `adapters/claude-code/run-task.sh`. The fix is a focused loop in the adapter: parse the task block's `depends_on` YAML key, and for each upstream task ID `tN`, create `$DOSSIER/upstream/tN/` as a symlink to `.planning/phases/$CHANTIER_PHASE/tasks/tN/` (or per-file `output.json` link).
- **D-02:** The executing skill is `test-driven-development`. Exactly two tasks: `t1` writes a failing bats test asserting `upstream/t1/output.json` exists in `t2`'s dossier; `t2` modifies `adapters/claude-code/run-task.sh` to make the test green AND declares `depends_on: [t1]`, so `upstream/t1/output.json` from t1's run is staged into t2's dossier (proving the F3 fix uses itself).

**tests/e2e/ integration test shape:**

- **D-03:** Phase 5 ships one bats file at `tests/e2e/full_loop.bats` (NOT `core/tests/`). Single-bats end-to-end test creates a tmp project via `chantier new <name>`, writes synthetic two-task PLAN.md mirroring F3 dogfood shape, dispatches via stub adapter, asserts full loop emits expected STATE.md events plus `validate-task`-green on both tasks. Loads the same `core/tests/test_helper/{bats-support, bats-assert}` submodules.
- **D-04:** Adapter dispatch in `tests/e2e/full_loop.bats` uses the `CHANTIER_CLAUDE_BIN` deterministic stub by default. A `CHANTIER_E2E_REAL_CLAUDE=1` env hook unsets `CHANTIER_CLAUDE_BIN` so the test invokes the real `claude -p` binary for opt-in local validation; CI never sets this flag.

**NFR-001..006 independent audit shape:**

- **D-05:** Audits live in a single consolidated file `core/tests/nfr_audits.bats` with **six `@test` groups**, one per NFR. Path is `core/tests/`, not `tests/e2e/`.
- **D-06:** Per-NFR audit shape:
  - **NFR-001:** reuse deny-list pattern from `core/tests/adapter_isolation.bats`; may delegate or duplicate the small grep.
  - **NFR-002:** `shellcheck --shell=sh` over every `.sh` file in `core/bin/`, `core/tests/`, `adapters/*/`, `skills/*/`; plus grep for forbidden bash-only constructs (`[[ ]]`, `<<<`, `mapfile`, arrays).
  - **NFR-003:** grep for `>` (single-redirect to `STATE.md`) outside `core/bin/chantier`'s `state_append` function.
  - **NFR-004:** grep for forbidden network primitives (`curl`, `wget`, direct IPs, `http://`, `https://`) in `core/bin/`, `adapters/*/run-task.sh`, `skills/*/run.sh`. Documentation `.md` files exempt.
  - **NFR-005:** grep for common non-English glyph ranges (accented chars `é à ç ô ù`, etc.) outside `.planning/` and `docs/strategy/`. Audit walks `README.md`, `LICENSE*`, `CONTRIBUTING.md`, `docs/adr/`, `docs/vision.md`, `docs/research/`, `core/`, `skills/`, `adapters/`, `tests/`.
  - **NFR-006:** assert `LICENSE` starts with `MIT License`; assert `LICENSE-CREDITS` exists; grep every `*.sh` for `SPDX-License-Identifier: MIT`; grep `Chantier Contributors` in `LICENSE`; no per-person `(c) <name>` in `LICENSE` or shebanged sources.

**ROADMAP migration & cutover off GSD:**

- **D-07:** ROADMAP migration is **minimalist**. Strip temporary GSD-parser markers — the "Format note (temporary)" callout, the GSD-parser disclaimer, GSD-specific indentation conventions. Keep narrative structure: front-matter, Phases overview list, Phase Details, Progress table. The frontmatter already validates against `core/schemas/roadmap.json`; no schema change.
- **D-08:** Cutover happens in the **final commit of Phase 5**. Bundle in that single commit: (a) ROADMAP migration diff; (b) any residual `gsd-sdk` / `gsd-tools` references removed from `.planning/` artifacts (audit confirms); (c) `cutover.completed` event appended to STATE.md via `chantier state append --event cutover.completed --summary "ROADMAP migrated to ADR 0001 native format. GSD ceases to be invoked in Chantier's own workflows."`. Refs `[".planning/ROADMAP.md", "<commit-sha>"]`. Phase 4 plans and prior STATE.md history NOT rewritten.

**F1–F4 findings disposition:**

- **D-09:** F3 = dogfood feature (D-01). F1 = author **ADR 0004** in this phase, status Proposed, codifying the Surface 3 propagation contract Phase 4 plan 03 discovered (`cp` of plain files from dossier root to TASK_DIR, excluding `inputs.yml`, `env.sh`, `subagent.transcript.log`). Ratification deferred until a second adapter exists. F2 and F4 remain v0.2 backlog explicitly.

**Matrix skills coverage:**

- **D-10:** `tests/e2e/full_loop.bats` exercises **only `test-driven-development` via the adapter**. The three other shipped skills are NOT exercised through the adapter in Phase 5.

### Claude's Discretion (11 items — planner decides)

1. PLAN.md task pair shape for the F3 dogfood (task IDs, `state_reads` / `state_writes` paths, `inputs` blocks, `acceptance` bullets).
2. F3 fix shape inside `adapters/claude-code/run-task.sh`: symlink full upstream task dir vs per-file `output.json`.
3. PLAN.md `depends_on` ordering enforcement: adapter topo-sort vs operator dispatches in order.
4. ADR 0004 exact prose (Context, Decision, Consequences, Alternatives, Open questions sections).
5. `nfr_audits.bats` shellcheck shape: per-file loop vs `find ... | xargs shellcheck`.
6. NFR-005 non-English glyph regex (UTF-8 class vs hand-rolled accented set).
7. `cutover.completed` event refs payload (whether to include `bootstrap.harness.chosen` timestamp back-ref).
8. Whether to extract the `CHANTIER_CLAUDE_BIN` stub into a shared helper or duplicate inline.
9. Synthetic project name used in `chantier new` inside the e2e test.
10. Phase 5 `phase.completed` event via adapter or direct binary append (symmetry with prior four phases suggests direct).
11. Concurrency lock for parallel `run-task.sh` (Phase 4 carry-forward; not exercised by design in Phase 5).

### Deferred Ideas (OUT OF SCOPE)

- Second harness adapter (v0.2.0).
- F2 (real-claude dispatch path in CI) — env gate ships, use is v0.2.
- F4 (strict worktree validation) — v0.2 unless dogfood signal.
- 5th reference skill — FR-009 caps at four.
- `chantier validate-roadmap`, `chantier task-lookup` subcommands — v0.2+.
- YAML-first ROADMAP rewrite — too disruptive.
- Matrix-via-adapter coverage of all four skills — v0.2 mechanical extension.
- ADR 0003 ratification — post-Phase 5.
- ADR 0004 ratification — requires second adapter.
- STATE.md compaction — post-v0.1.
- `extract-skills-from-phase` — v0.3.0.
- Concurrency lock for parallel `run-task.sh`.
- `CHANTIER_TRANSCRIPT=1` transcript gate.
- Workflow skill authoring (per `maturity-path.md` sketch).
- `--self-test` extended to cover six NFRs (rejected: ADR 0002 coupling).
- Other `tests/` subdirectories beyond `tests/e2e/`.

</user_constraints>

---

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NFR-001 | Skill bodies contain no harness-specific identifiers; enforced by `chantier validate-task` portability grep. | `nfr_audits.bats` @test #1 reuses byte-identical deny-list from `core/tests/adapter_isolation.bats:46` and `core/bin/chantier:687/:912`. Pattern is proven (73/0 already). |
| NFR-002 | The `chantier` binary depends only on POSIX shell + jq. | `nfr_audits.bats` @test #2 runs `shellcheck --shell=sh` on every `.sh` file in `core/`, `adapters/`, `skills/`, `tests/`; greps bash-only constructs. Already proven clean for `core/bin/chantier` (975 lines) and `adapters/claude-code/run-task.sh` (253 lines). |
| NFR-003 | `STATE.md` is append-only; in-skill direct edits are a contract violation. | `nfr_audits.bats` @test #3 greps for `>[[:space:]]*.*STATE\.md` outside `core/bin/chantier` (where `state_append()` is the only sanctioned writer at line 207). Runtime guard is `acquire_lock` mkdir-mutex (ADR 0002); this audit is the **static** companion. |
| NFR-004 | The framework runs without network access except where a skill explicitly opts in. | `nfr_audits.bats` @test #4 greps for `curl\|wget\|http[s]?://\|nc -\|telnet ` in `core/bin/chantier`, `adapters/*/run-task.sh`, `skills/*/run.sh` (executable code only). Three legitimate `https://` URLs in skill body PROSE (`skills/subagent-driven-development/{SKILL.md,PRESSURE.md}` citing issue #237) are in `.md` files — exempt by file extension. |
| NFR-005 | All public artifacts (README, docs, code, skill bodies, commit messages) are in English. | `nfr_audits.bats` @test #5 greps a non-English glyph regex over `README.md`, `LICENSE*`, `CONTRIBUTING.md`, `docs/adr/`, `docs/vision.md`, `docs/research/`, `core/`, `skills/`, `adapters/`, `tests/`. Exempts `.planning/` (French session prose) and `docs/strategy/` (sketches quote conversation). |
| NFR-006 | License is MIT, copyright is collective (`Chantier Contributors`). No token, no SaaS lock-in. | `nfr_audits.bats` @test #6 asserts: `LICENSE` starts with `MIT License`; `LICENSE-CREDITS` exists; every `*.sh` has `SPDX-License-Identifier: MIT`; `LICENSE` contains `Chantier Contributors`; no per-person `(c) <name>` in `LICENSE` or shebanged sources. Currently verified clean: `head -3 LICENSE` shows `MIT License\n\nCopyright (c) 2026 Chantier Contributors`; `adapters/claude-code/run-task.sh:2-3` and `skills/test-driven-development/run.sh:2-3` carry the SPDX header. |

</phase_requirements>

---

## Project Constraints (from CLAUDE.md)

No `./CLAUDE.md` exists in the project root. Project-specific constraints flow from canonical references in `05-CONTEXT.md`:

- **ADR 0001** — load-bearing contract. State/skill surfaces are immutable. Surface 2 §"upstream/" is the literal source for D-01/D-02; Surface 3 §"output.md + output.json + chantier state append" is what ADR 0004 codifies.
- **ADR 0002** — runtime spec. JSONL STATE.md row schema is the only event format. Event-shape regex `^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$` is enforced twice (case-glob + jq test()). `cutover.completed` matches the regex (D-08).
- **ADR 0003 (Proposed)** — workflow skill design principles. Phase 5 dogfood is the lived-experience evidence ADR 0003 needs to move from Proposed to Accepted. Principle 4 ("chaining is explicit in PLAN.md, not magic in skills") justifies D-02's two-task chain with `depends_on` rather than internal skill composition.
- **NFR-001..006** — verified by the six `@test`s in `nfr_audits.bats`. Tree-level invariants; pre-existing tests (`adapter_isolation.bats`, `skill_uniformity.bats`) cover subsets — the new file makes the SC#4-to-test mapping explicit.
- **PROJECT.md** — v0.1.0 SC#5 ("Chantier's own development is managed by Chantier") is what Phase 5 closes.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| F3 upstream/ symlink staging | `adapters/claude-code/run-task.sh` | — | ADR 0001 Surface 2: the adapter stages the dossier. The binary owns no per-task staging logic. |
| Multi-task chain semantics (`depends_on`) | `adapters/claude-code/run-task.sh` | PLAN.md surface | The adapter reads `depends_on` from the PLAN.md task block. PLAN.md is the declaration; the adapter is the executor. |
| Synthetic project scaffold | `core/bin/chantier new` | — | Phase 2 FR-002 owns project scaffolding. The e2e test calls the existing binary; no new scaffold logic in Phase 5. |
| End-to-end loop orchestration | `tests/e2e/full_loop.bats` | (test harness only) | bats is the test runner. The test acts as the operator: invokes `chantier new`, writes PLAN.md, runs the adapter, runs `validate-task`. |
| Stub-adapter dispatch (offline CI) | `CHANTIER_CLAUDE_BIN` stub in `$BATS_TEST_TMPDIR/stub/claude` | — | Lives outside the audit scope (D-11). Inline POSIX-sh script per Phase 4 D-15. |
| Six NFR audits | `core/tests/nfr_audits.bats` | (reuses helpers from existing bats files) | Tree-level static invariants. One `@test` per NFR per D-05. |
| ADR codification | `docs/adr/0004-surface-3-propagation.md` | — | Documentation tier. Status Proposed; ratification deferred per D-09. |
| ROADMAP migration | `.planning/ROADMAP.md` (in-place edit) | — | In-place edit preserves git blame history. Frontmatter unchanged (already validates per Phase 2 D-06). |
| `cutover.completed` event emission | `chantier state append` | (invoked by hand in final commit) | The binary is the only sanctioned STATE.md writer (NFR-003). Operator invokes; no new code. |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bats-core | 1.13.0 | Test runner for `tests/e2e/full_loop.bats` + `core/tests/nfr_audits.bats` | [VERIFIED: host probe] `/usr/local/bin/bats --version` returns `Bats 1.13.0`; already used by all 73 pre-existing tests in `core/tests/`. Phase 2 D-Wave-0 vendored this; no upgrade. |
| bats-support | 0.3.0 (submodule) | `load 'test_helper/bats-support/load'` — provides `fail`, `batslib_*` helpers | [VERIFIED: in tree] `core/tests/test_helper/bats-support/` is a git submodule; loaded by all 9 existing bats files. |
| bats-assert | 2.2.4 (submodule) | `load 'test_helper/bats-assert/load'` — provides `assert_output`, `assert_failure`, etc. | [VERIFIED: in tree] `core/tests/test_helper/bats-assert/` is a git submodule; loaded by all 9 existing bats files. |
| jq | 1.7.1 | JSONL parsing in `output.json` assertions; STATE.md row counts | [VERIFIED: already required] `chantier` and skills all require `jq`; the e2e and audits also use it. No new dependency. |
| shellcheck | 0.11.0 | NFR-002 audit primitive | [VERIFIED: host probe] `/usr/local/bin/shellcheck --version` returns `0.11.0`; already used in Phase 2..4 commit-time linting. Audit declares `command -v shellcheck` precondition; skips with explanation if absent (matches existing bats pattern from `core/tests/self_test.bats`). |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| git worktree | (built-in to git 2.50.1) | `git worktree add` for the e2e test's synthetic project | [VERIFIED: Phase 4 mirror] `adapter_claude_code_e2e.bats:55-71` already does this; Phase 5 reuses verbatim. |
| grep (BSD/GNU) | system | Static audit primitive | [VERIFIED: portability] Phase 4 `adapter_isolation.bats:42-122` uses POSIX-portable grep idioms; Phase 5 reuses the same. |
| find (BSD/GNU) | system | Tree walk for audit + shellcheck driver | [VERIFIED: Phase 4 idiom] `find core skills adapters -type f -print` works on BSD + GNU. No `-print0` or `-regextype` (GNU-only). |
| awk (BSD/GNU) | system | YAML extraction (existing adapter reuses) | [VERIFIED: adapter already uses] `adapters/claude-code/run-task.sh:21-54` `extract_task_field()` is BSD/GNU-portable. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Single `nfr_audits.bats` (D-05) | Six separate `nfr_001.bats` ... `nfr_006.bats` | More granular but fragments suite, duplicates boilerplate. D-05 rejected. |
| `CHANTIER_CLAUDE_BIN` stub in shared helper | Duplicate ~14-line stub inline in `tests/e2e/full_loop.bats` | Shared helper = DRY; inline = zero coupling. Discretion item #8 — planner picks based on whether the stub needs e2e-specific behavior (e.g., dispatch-sequence logging). |
| Per-file `shellcheck` loop in NFR-002 | `find ... -name '*.sh' -print0 \| xargs -0 shellcheck` | Both POSIX-portable. Per-file loop has better bats failure legibility (which file failed); xargs is faster but harder to attribute. Discretion item #5. |
| Symlink-full-upstream-dir for F3 | Symlink-only-output.json file | Per-file (output.json) gives tighter least-privilege; full-dir is more general (depending task may want artifacts beyond `output.json`). ADR 0001 Surface 2 example shows `upstream/t0/output.json` (file-level), suggesting file-level intent. Discretion item #2. **Recommendation:** start with per-file `output.json`; extend if a downstream task needs more (Phase 5 dogfood itself does not). |
| `find ... | xargs grep` in NFR audits | While-read loop with case-arm dispatch | Phase 4 chose while-read + case-arm (`adapter_isolation.bats:55-111`) for per-path exemption logic. Phase 5 should follow the same pattern in `nfr_audits.bats` for the path-specific NFR-001 and NFR-005 exemptions. |

**Installation:**

No installation needed — every dependency is already present in the project. The two new bats files load existing helpers; the F3 fix is a ~30-line addition to an existing POSIX-sh adapter; ADR 0004 is a new Markdown file in `docs/adr/`.

**Version verification:** All dependencies probed on host as of 2026-05-30; all match Phase 2..4 production versions. No registry installs in this phase.

---

## Package Legitimacy Audit

This phase installs **no external packages**. Every tool used is either:

- Already required by Phase 2..4 (`bats`, `bats-support`, `bats-assert`, `jq`, `shellcheck`, `git`)
- A POSIX baseline tool (`grep`, `find`, `awk`, `sed`, `mkdir`, `ln`, `cp`)

| Package | Registry | Age | Downloads | Source Repo | Disposition |
|---------|----------|-----|-----------|-------------|-------------|
| (none) | — | — | — | — | No installs in Phase 5 |

**Packages removed due to slopcheck verdict:** none (none recommended).
**Packages flagged as suspicious:** none.

The phase ships only in-tree files: a small adapter patch, three new test/audit/ADR files, an in-place ROADMAP edit. NFR-002 is satisfied by definition.

---

## Architecture Patterns

### System Architecture Diagram

```
                       ┌─────────────────────────────────┐
                       │  Operator (the bats test)       │
                       │  acts as the human operator     │
                       └────────────────┬────────────────┘
                                        │
                        ┌───────────────┼───────────────┐
                        ▼               ▼               ▼
              ┌──────────────┐  ┌─────────────┐  ┌──────────────┐
              │ chantier new │  │  write      │  │  invoke      │
              │ <name>       │  │  PLAN.md    │  │  adapter     │
              │ (Phase 2)    │  │  (in test)  │  │  run-task.sh │
              └──────┬───────┘  └──────┬──────┘  └──────┬───────┘
                     │                 │                 │
                     ▼                 ▼                 ▼
                ┌─────────────────────────────────────────────┐
                │  $WORKTREE/.planning/ + .chantier/dossiers/ │
                │  (greenfield project, populated as test runs)│
                └─────────────────┬───────────────────────────┘
                                  │
                  ┌───────────────┴───────────────┐
                  ▼                               ▼
        ┌──────────────────┐            ┌──────────────────┐
        │  Task t1 dispatch│            │  Task t2 dispatch│
        │  (no upstream)   │            │  depends_on: [t1]│
        └────────┬─────────┘            └────────┬─────────┘
                 │                               │
                 │ stages dossier                │ stages dossier
                 │ → empty upstream/             │ → upstream/t1/output.json
                 │                               │   (F3 fix: NEW behavior)
                 ▼                               ▼
        ┌──────────────────┐            ┌──────────────────┐
        │ CHANTIER_CLAUDE_ │            │ CHANTIER_CLAUDE_ │
        │ BIN stub:        │            │ BIN stub:        │
        │ cd dossier;      │            │ cd dossier;      │
        │ source env.sh;   │            │ source env.sh;   │
        │ sh skill/run.sh  │            │ sh skill/run.sh  │
        └────────┬─────────┘            └────────┬─────────┘
                 │                               │
                 ▼                               ▼
        ┌──────────────────┐            ┌──────────────────┐
        │ TDD red-phase    │            │ TDD red-phase    │
        │ run.sh writes    │            │ run.sh writes    │
        │ output.md +      │            │ output.md +      │
        │ output.json      │            │ output.json      │
        └────────┬─────────┘            └────────┬─────────┘
                 │                               │
                 ▼                               ▼
        ┌──────────────────┐            ┌──────────────────┐
        │ adapter Surface 3│            │ adapter Surface 3│
        │ propagation: cp  │            │ propagation: cp  │
        │ dossier/* → TASK_│            │ dossier/* → TASK_│
        │ DIR              │            │ DIR              │
        └────────┬─────────┘            └────────┬─────────┘
                 │                               │
                 ▼                               ▼
        ┌──────────────────┐            ┌──────────────────┐
        │ chantier validate│            │ chantier validate│
        │ -task t1         │            │ -task t2         │
        │ → green          │            │ → green          │
        └────────┬─────────┘            └────────┬─────────┘
                 │                               │
                 └───────────────┬───────────────┘
                                 ▼
                       ┌─────────────────────┐
                       │ STATE.md (JSONL):   │
                       │ task.started   × 2  │
                       │ skill.completed × 2 │
                       │ task.completed × 2  │
                       └─────────────────────┘
                                 │
                                 ▼
                       ┌─────────────────────┐
                       │ test assertions:    │
                       │ jq counts events    │
                       │ verify TASK_DIR/    │
                       │ output.json exists  │
                       │ verify upstream/t1/ │
                       │ output.json in t2   │
                       └─────────────────────┘
```

The diagram shows two parallel-but-sequential dispatches (t1 first, then t2 because t2 depends on t1's output). The F3 fix is the box "stages dossier → upstream/t1/output.json (NEW behavior)"; without the fix, this becomes "stages dossier → empty upstream/" (current Phase 4 behavior).

### Recommended Project Structure (post-Phase 5)

```
Chantier/
├── tests/                          # NEW top-level directory
│   └── e2e/
│       └── full_loop.bats          # NEW (D-03) — full integration test
├── core/
│   ├── bin/chantier                # unchanged
│   ├── schemas/                    # unchanged
│   └── tests/
│       ├── nfr_audits.bats         # NEW (D-05) — 6 @test consolidated audit
│       ├── adapter_isolation.bats  # unchanged (pre-existing)
│       ├── adapter_claude_code_e2e.bats  # unchanged
│       ├── skill_*_e2e.bats × 4    # unchanged
│       ├── self_test.bats          # unchanged
│       ├── state_append.bats       # unchanged
│       ├── state_show.bats         # unchanged
│       ├── new.bats                # unchanged
│       ├── validate_task.bats      # unchanged
│       ├── skill_uniformity.bats   # unchanged
│       ├── test_helper/            # unchanged (bats-support + bats-assert)
│       └── fixtures/               # unchanged
├── adapters/
│   └── claude-code/
│       ├── run-task.sh             # PATCHED (D-01) — F3 fix at line ~118
│       └── README.md               # POSSIBLY PATCHED (D-01 note about upstream/)
├── skills/                         # unchanged (no new skill per FR-009 cap)
├── docs/
│   ├── adr/
│   │   ├── 0001-state-skill-contract.md          # unchanged
│   │   ├── 0002-runtime-binary-and-state-format.md  # unchanged
│   │   ├── 0003-workflow-skill-design-principles.md # unchanged (Proposed)
│   │   └── 0004-surface-3-propagation.md         # NEW (D-09) — Proposed
│   ├── research/                   # unchanged
│   └── strategy/                   # unchanged
├── .planning/
│   ├── ROADMAP.md                  # MIGRATED (D-07) — minimalist diff
│   ├── STATE.md                    # APPENDED (D-08) — cutover.completed event
│   ├── phases/05-dogfood-e2e/      # populated by this phase's planning artifacts
│   ├── PROJECT.md                  # POSSIBLY PATCHED — status → shipped on phase close
│   ├── REQUIREMENTS.md             # unchanged
│   └── config.json                 # unchanged
├── LICENSE                         # unchanged (NFR-006 anchor)
├── LICENSE-CREDITS                 # unchanged
├── README.md                       # POSSIBLY PATCHED (link to tests/e2e/, mention v0.1.0)
└── CONTRIBUTING.md                 # unchanged
```

### Pattern 1: bats E2E with `chantier new` + multi-task chain

**What:** A single-file bats integration test that orchestrates the full Chantier loop: `chantier new` to scaffold a fresh project under `$BATS_TEST_TMPDIR`, hand-author a synthetic two-task PLAN.md, dispatch each task via the adapter under a CHANTIER_CLAUDE_BIN stub, run `chantier validate-task` on each, assert STATE.md events.

**When to use:** This is Phase 5's `tests/e2e/full_loop.bats`. It is the only file under the new top-level `tests/e2e/` directory in v0.1.0.

**Example (skeleton — planner authors the full body):**

```sh
#!/usr/bin/env bats
# tests/e2e/full_loop.bats — Phase 5 dogfood E2E (SC#1–SC#5).
# Source: ADR 0001 §full contract + 05-CONTEXT.md D-01..D-10.

setup() {
    load '../../core/tests/test_helper/bats-support/load'
    load '../../core/tests/test_helper/bats-assert/load'

    export REPO_ROOT
    REPO_ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)
    export CHANTIER="$REPO_ROOT/core/bin/chantier"
    export ADAPTER="$REPO_ROOT/adapters/claude-code/run-task.sh"  # HARNESS_DENY_LIST_CHECK

    export PATH="$REPO_ROOT/core/bin:$PATH"

    mkdir -p "$BATS_TEST_TMPDIR/home"
    cd "$BATS_TEST_TMPDIR/home"
    export TMPHOME
    TMPHOME=$(pwd -P)

    # CHANTIER_CLAUDE_BIN stub (D-04). Reused from Phase 4 D-15 verbatim.
    mkdir -p "$BATS_TEST_TMPDIR/stub"
    cat > "$BATS_TEST_TMPDIR/stub/claude" <<'STUB_EOF'
#!/bin/sh
set -eu
PROMPT=""
while [ $# -gt 0 ]; do
    case "$1" in
        -p|--print) shift; PROMPT="$1" ;;
        *) ;;
    esac
    shift 2>/dev/null || true
done
DOSSIER=$(printf '%s\n' "$PROMPT" | grep -oE '/[^ "]+/\.chantier/dossiers/[^ "]+' | head -n 1)
[ -n "$DOSSIER" ] || { printf 'stub: no dossier in prompt\n' >&2; exit 1; }
printf 'subagent (stub): cd %s\n' "$DOSSIER"
cd "$DOSSIER" && . ./env.sh && sh ./skill/run.sh
exit $?
STUB_EOF
    chmod +x "$BATS_TEST_TMPDIR/stub/claude"

    # D-04 opt-in: if the operator sets CHANTIER_E2E_REAL_CLAUDE=1, unset the
    # stub so the real `claude` binary on PATH is invoked instead. CI never
    # sets this flag — NFR-004 default offline holds.
    if [ "${CHANTIER_E2E_REAL_CLAUDE:-}" != "1" ]; then
        export CHANTIER_CLAUDE_BIN="$BATS_TEST_TMPDIR/stub/claude"
    fi
}

@test "tests/e2e/full_loop: chantier new + 2-task chain + adapter dispatch + validate-task green on both tasks" {
    cd "$TMPHOME"

    # SC#1: full new-project → plan → execute → verify loop.
    run "$CHANTIER" new chantier-e2e-dogfood
    [ "$status" -eq 0 ]
    cd "$TMPHOME/chantier-e2e-dogfood"

    # The synthetic project needs a git init for the adapter's
    # `git rev-parse --show-toplevel` (D-05 lax check).
    git init -q
    git config user.email "test@chantier"
    git config user.name "test"
    git add -A
    git commit -q -m "scaffold"

    # Copy the live test-driven-development skill into the synthetic project.
    mkdir -p skills/test-driven-development
    cp "$REPO_ROOT/skills/test-driven-development/SKILL.md"    skills/test-driven-development/
    cp "$REPO_ROOT/skills/test-driven-development/PRESSURE.md" skills/test-driven-development/
    cp "$REPO_ROOT/skills/test-driven-development/run.sh"      skills/test-driven-development/
    chmod +x skills/test-driven-development/run.sh

    # Write the synthetic 2-task PLAN.md.
    # t1: produces output.json via TDD red phase (deterministic `false` test_command).
    # t2: depends_on: [t1]; the adapter F3 fix stages upstream/t1/output.json.
    mkdir -p .planning/phases/dogfood-phase
    cat > .planning/phases/dogfood-phase/PLAN.md <<'PLAN_EOF'
---
plan_id: 01-dogfood
phase: dogfood-phase
created: 2026-05-30
status: draft
declared_skills: ["test-driven-development"]
---

## Task `t1` -- producer

```yaml
task: t1
skill: test-driven-development
inputs:
  target_file: "src/dummy.sh"
  test_framework: "bats"
  phase: "red"
  test_command: "false"
state_writes:
  - ".planning/phases/dogfood-phase/tasks/t1/"
depends_on: []
acceptance:
  - "A failing test was observed before any production code was written for this task."
  - "After the production change, the same test command exits zero."
```

## Task `t2` -- consumer (exercises F3 fix)

```yaml
task: t2
skill: test-driven-development
inputs:
  target_file: "src/dummy.sh"
  test_framework: "bats"
  phase: "red"
  test_command: "false"
state_writes:
  - ".planning/phases/dogfood-phase/tasks/t2/"
depends_on: [t1]
acceptance:
  - "A failing test was observed before any production code was written for this task."
  - "After the production change, the same test command exits zero."
```
PLAN_EOF

    # Dispatch t1 first (no upstream). D-04 operator-orders-dispatch in v0.1.
    run "$ADAPTER" t1
    [ "$status" -eq 0 ]
    [ -f ".planning/phases/dogfood-phase/tasks/t1/output.json" ]

    # Dispatch t2 second. The F3 fix stages upstream/t1/output.json into the
    # t2 dossier BEFORE the subagent runs.
    run "$ADAPTER" t2
    [ "$status" -eq 0 ]
    [ -f ".planning/phases/dogfood-phase/tasks/t2/output.json" ]

    # SC#2: validate-task green on both. Re-running gates idempotence.
    run "$CHANTIER" validate-task t1
    [ "$status" -eq 0 ]
    run "$CHANTIER" validate-task t2
    [ "$status" -eq 0 ]

    # F3 fix proof: t2's dossier has upstream/t1/output.json.
    # The dossier may have been preserved (D-08) so the staged symlink/copy
    # is still inspectable.
    DOSSIER_T2=".chantier/dossiers/t2"
    [ -e "$DOSSIER_T2/upstream/t1/output.json" ]

    # SC#2: populated STATE.md without contract violations. Six events expected:
    #   task.started t1, skill.completed t1, task.completed t1,
    #   task.started t2, skill.completed t2, task.completed t2.
    _started=$(grep -cE '"event":"task\.started"' .planning/STATE.md)
    [ "$_started" -eq 2 ]
    _skill=$(grep -cE '"event":"skill\.completed"' .planning/STATE.md)
    [ "$_skill" -eq 2 ]
    _completed=$(grep -cE '"event":"task\.completed"' .planning/STATE.md)
    [ "$_completed" -eq 2 ]

    # SC#3 hermetic: CHANTIER_CLAUDE_BIN was set (unless E2E_REAL_CLAUDE opt-in).
    if [ "${CHANTIER_E2E_REAL_CLAUDE:-}" != "1" ]; then
        [ -n "$CHANTIER_CLAUDE_BIN" ]
        [ -x "$CHANTIER_CLAUDE_BIN" ]
    fi
}
```

### Pattern 2: Six-`@test` consolidated NFR audit

**What:** A single bats file (`core/tests/nfr_audits.bats`) with six `@test` groups, one per NFR. Each `@test` is independent (no shared mutable state between them); each greps the source tree with a pattern; each exempts specific paths or comment markers as the per-NFR contract dictates.

**When to use:** This is Phase 5's `core/tests/nfr_audits.bats`. Path is `core/tests/` (audit) deliberately distinct from `tests/e2e/` (workflow proof), per D-05 rationale.

**Example (NFR-004 audit skeleton — planner authors all six):**

```sh
@test "nfr_audits: NFR-004 — no network primitives in executable code" { # HARNESS_DENY_LIST_CHECK
    # Forbidden: curl, wget, http://, https://, nc -, telnet, bare IPv4.
    # Scope: executable code only (.sh + binary). Documentation .md files
    # are exempt — URLs in prose (e.g., citing issue #237) are fine.
    # The CHANTIER_CLAUDE_BIN indirection and the real-claude opt-in path
    # both defer to `claude -p` whose network access is the skill's opt-in
    # per NFR-004; the audit catches a `curl` in a skill's run.sh, not the
    # `claude` binary's own network behavior.
    _net_pat='curl[[:space:]]|wget[[:space:]]|http[s]?://|nc[[:space:]]-|telnet[[:space:]]'
    _violations=""
    while IFS= read -r _file; do
        [ -n "$_file" ] || continue
        # Strip HARNESS_DENY_LIST_CHECK-marker lines and quoted-comment lines
        # (a line starting with `#` AND containing a URL is documentation).
        if grep -v 'HARNESS_DENY_LIST_CHECK' "$_file" \
           | grep -vE '^[[:space:]]*#.*http' \
           | grep -qE "$_net_pat"; then
            _violations="${_violations}${_file}
"
        fi
    done <<EOF
$(find core/bin adapters skills -type f \( -name '*.sh' -o -name 'chantier' \) 2>/dev/null | sort)
EOF
    if [ -n "$_violations" ]; then
        printf 'nfr_audits: NFR-004 violations (network primitives in executable code):\n%b' "$_violations" >&2
        false
    fi
}
```

### Pattern 3: F3 fix integration loop in `run-task.sh`

**What:** A small POSIX-sh loop inserted after the existing `mkdir -p "$DOSSIER/reads" "$DOSSIER/upstream" "$DOSSIER/skill"` at `adapters/claude-code/run-task.sh:118`. The loop parses `depends_on` via the existing `extract_task_field` helper (block-dash mode), then for each upstream task ID `tN`, creates a symlink (or copy) from `$DOSSIER/upstream/tN/output.json` to `.planning/phases/$PHASE/tasks/tN/output.json`.

**When to use:** This is Phase 5's load-bearing source change. The loop is the only modification to `adapters/claude-code/run-task.sh`. ~10 lines, ~30 with the matching adapter README update.

**Example (per-file `output.json` shape — Discretion item #2 recommendation):**

```sh
# F3 fix: stage upstream/<tN>/output.json for every tN in depends_on.
# Per-file symlink (ADR 0001 Surface 2 example uses upstream/t0/output.json).
# Symlink chosen over copy: tighter least-privilege, downstream reads only.
# If symlink fails (e.g., upstream task not yet executed), fall back to a
# clear stderr warning — operator must dispatch tN before t(N+1) in v0.1
# per D-03 Discretion #3 ("operator dispatches in order").
DEPENDS_ON=$(extract_task_field "$TASK_ID" depends_on block-dash "$PLAN_PATH")
printf '%s\n' "$DEPENDS_ON" | while IFS= read -r _up_task; do
    [ -n "$_up_task" ] || continue
    _up_out="$WORKTREE/.planning/phases/$PHASE/tasks/$_up_task/output.json"
    if [ ! -f "$_up_out" ]; then
        printf 'run-task: depends_on=%s but %s not found; dispatch %s first\n' \
            "$_up_task" "$_up_out" "$_up_task" >&2
        exit 2
    fi
    mkdir -p "$DOSSIER/upstream/$_up_task"
    ln -s "$_up_out" "$DOSSIER/upstream/$_up_task/output.json" 2>/dev/null || \
        cp "$_up_out" "$DOSSIER/upstream/$_up_task/output.json"
done
```

### Anti-Patterns to Avoid

- **Topological-sort in the adapter (Discretion item #3).** Tempting because it would let the operator `run-task.sh t2` without first running t1. Rejected for v0.1: violates "no flags in v0.1" (D-16 from Phase 4 — single positional task ID, no batch mode); adds a new failure-mode dependency cycle on `state_reads` resolution; and the e2e test can drive sequential dispatch deterministically without it. v0.2+ if ergonomic need surfaces.
- **Recursing on `depends_on` in the adapter.** Same trap. The adapter dispatches one task; the operator (or a future workflow skill from ADR 0003's principles) orchestrates the chain.
- **Re-implementing `chantier validate-task` semantics in `tests/e2e/full_loop.bats`.** The test must INVOKE the binary, not inline-check the same gates. The binary is what ships; the test verifies the binary's behavior on a real workflow.
- **NFR-005 regex that matches everything Unicode.** A naive `[^[:ascii:]]` matches legitimate UTF-8 in JSON encoding (none should exist, but if it did the false positive would be confusing). Use a hand-rolled accented-Latin set or `[À-ÿ]` UTF-8 class — both narrower than full-Unicode rejection. Discretion item #6.
- **Putting NFR audits in `tests/e2e/`.** Audits are tree-level static invariants, not workflow proofs. D-05 explicitly separates paths: `core/tests/` (audit + runtime tests) vs `tests/e2e/` (workflow tests).
- **Cleaning up `.chantier/dossiers/` in the test.** Phase 4 D-08 dossier preservation — the test inspects `upstream/t1/output.json` AFTER the run as the F3-fix proof. `$BATS_TEST_TMPDIR` auto-cleanup handles teardown.
- **Touching Phase 4's `04-SUMMARY.md` or prior plan files.** D-08 — "Phase 4 plans and prior STATE.md history are NOT rewritten." Historical record preserved.
- **Rewriting ROADMAP.md from scratch (YAML-first).** D-07 minimalist. The diff should be ~5–10 lines (strip the "Format note (temporary)" callout, possibly an indentation tweak), NOT a full rewrite.
- **Adding `chantier validate-roadmap` to the binary.** Considered + rejected (D-07 Deferred). The frontmatter already validates against `core/schemas/roadmap.json` via Phase 2 D-06 permissive `additionalProperties: true`. No new verb in v0.1.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| YAML parsing in the F3 fix | Custom YAML parser | Existing `extract_task_field` helper at `adapters/claude-code/run-task.sh:21-54` (block-dash mode) | Already exists, already POSIX-sh, already tested by Phase 4 e2e. ~30 lines that handle the YAML subset Chantier supports (ADR 0002). |
| PLAN.md task discovery | Re-traverse `.planning/phases/` from the test | Existing `find .planning/phases -name '*PLAN.md'` from `adapters/claude-code/run-task.sh:92` or `core/bin/chantier validate_task:502` | Two production implementations already. The e2e test should follow the same idiom. |
| JSONL row counting | `awk`/`sed` line parser | `grep -c '"event":"task\.started"' .planning/STATE.md` | Per `adapter_claude_code_e2e.bats:274-279` — already proven. JSONL one-row-per-line property is the load-bearing invariant. |
| Bats stub for `claude -p` | Hand-roll an argv parser | Reuse the Phase 4 D-15 stub from `core/tests/adapter_claude_code_e2e.bats:84-100` verbatim | Already proven across 73 tests. The argv shape (`-p` / `--print` + ignore others) is the contract; no new shape needed. Discretion item #8 decides extract-to-helper vs inline-duplicate. |
| Schema validation in audits | Re-implement schema checking in bats | Invoke `chantier validate-task` (gates 1–5 already implement it) | NFR-002 — the binary is the single source of validation truth. Audits assert tree-level static properties; runtime validation is the binary's job. |
| Worktree creation in `tests/e2e/full_loop.bats` | `mkdir -p` + manual `.git/` scaffold | `git init -q && git config + git commit -q` mirror of `adapter_claude_code_e2e.bats:55-67` | Real git operations are cheap (~50ms each). The test's hermetic requirement is `$BATS_TEST_TMPDIR` isolation, not "no git." |
| `cutover.completed` event payload | Hand-write JSONL | `chantier state append --event cutover.completed --summary "..." --ref ".planning/ROADMAP.md" --ref "<commit-sha>"` | NFR-003 — only `state_append()` is allowed to write STATE.md. The binary handles the mkdir-mutex, the ISO-8601 timestamp, the `actor` field from `git config user.name`, the JSONL line construction. |
| ADR 0004 template | Invent a new ADR shape | Mirror `docs/adr/0003-workflow-skill-design-principles.md` structure (Status, Provenance, Context, Decision, Consequences, Alternatives, Open questions, Ratification path, References) | Three ADRs already establish the shape. Consistency aids future readers. |

**Key insight:** Phase 5 is fundamentally a **composition phase**, not a creation phase. Almost every brick is already on the shelf — the work is selecting the right bricks and snapping them together in the right order. The two genuinely new pieces are (1) the ~10-line F3 fix loop and (2) the ~70-line ADR 0004. Everything else is mirroring an existing test, replaying an existing audit pattern, or invoking an existing binary.

---

## Runtime State Inventory

> Phase 5 is greenfield-additive for source code (new files: ADR 0004, two bats files; small patch: adapter) but includes a documentation migration (ROADMAP.md) and a state event emission (cutover.completed). The runtime state inventory is therefore included.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| **Stored data** | `.planning/STATE.md` (JSONL append-only): grows by ~10 events during Phase 5 (1× `phase.context.gathered` already at row 49; 4× `plan.completed` for plans 05-01..05-04; 5–7 events from the dogfood loop dispatch itself when the bats e2e runs in CI; 1× `phase.completed`; 1× `cutover.completed`). No existing rows modified. | None — append-only via `chantier state append` per NFR-003. |
| **Live service config** | None — Chantier has no external services. No Datadog tags, no Cloudflare tunnels, no n8n workflows, no Tailscale ACLs. | None. |
| **OS-registered state** | None — no Task Scheduler entries, no launchd plists, no systemd units, no pm2 saved processes. Chantier is a CLI invoked on demand. | None. |
| **Secrets and env vars** | `CHANTIER_CLAUDE_BIN` (Phase 4 — test-only env var, no secret), `CHANTIER_E2E_REAL_CLAUDE` (NEW in Phase 5 — opt-in flag, no secret), `CHANTIER_TASK_ID` / `CHANTIER_PHASE` / `CHANTIER_WORKTREE` (Phase 4 — runtime-only, set by adapter, no secret). No API keys, no tokens. NFR-006 reinforces: "no token, no SaaS lock-in." | None — env vars are documented in `adapters/claude-code/README.md`; the new `CHANTIER_E2E_REAL_CLAUDE` should be added to the same table. |
| **Build artifacts / installed packages** | `core/tests/test_helper/{bats-support, bats-assert}/` (git submodules — Phase 2 Wave 0). No npm `node_modules/`, no `__pycache__/`, no `target/`, no `.venv/`. Pure shell + submodules. | None — submodules already initialized; no compile step. |

**The canonical question — "After every file in the repo is updated, what runtime systems still have the old string cached, stored, or registered?":** None. Chantier has no caches, no compiled artifacts, no installed binaries on a system other than the shell scripts that live in git. The ROADMAP migration is in-place edit of `.planning/ROADMAP.md`; no other system holds a stale copy.

---

## Common Pitfalls

### Pitfall 1: Path with space in project root

**What goes wrong:** `/Users/alexislegrand/Code et Dev/Chantier/` contains a space. Every shell command must quote paths. Unquoted variable expansion in a heredoc or `cat` command silently truncates at the space.

**Why it happens:** Bats `$BATS_TEST_DIRNAME` and `$REPO_ROOT` inherit the parent path; `cd "$BATS_TEST_DIRNAME/../.."` resolves correctly only with double quotes.

**How to avoid:**
- Always double-quote `$REPO_ROOT`, `$WORKTREE`, `$TMPHOME`, `$DOSSIER`, `$BATS_TEST_TMPDIR` in every command.
- The e2e test creates a *new* project under `$BATS_TEST_TMPDIR/home/chantier-e2e-dogfood/` — the tmpdir path on macOS is typically `/private/var/folders/...` (no space), but use `pwd -P` canonicalization (Phase 4 idiom from `adapter_claude_code_e2e.bats:48-50`) to canonicalize against the macOS `/var → /private/var` symlink.
- Run the test once on the unmodified host (path with space) before committing; if a bats output shows truncation at "Code", the quoting is wrong.

**Warning signs:** `Bats error: file not found: /Users/alexislegrand/Code` (truncated at space).

### Pitfall 2: BSD vs GNU tool divergence (macOS dev, Linux CI)

**What goes wrong:** macOS ships BSD `grep`, `sed`, `awk`, `find`, `column`. Linux CI ships GNU equivalents. Some flags differ:
- `sed -i` requires `-i ''` on BSD but `-i` alone on GNU.
- `find -print0` works on both; `find -regextype` is GNU-only.
- `column -t -s "$(printf '\t')"` collapses repeated tabs on BSD (already mitigated in `state_show()` via "-"-padding per Phase 2 D-03).
- `grep -oE` is portable; `grep -P` (PCRE) is GNU-only.
- `awk` BSD `getline` returns differently on `eof` vs `error` than GNU.

**Why it happens:** Phase 5 is the FIRST phase where CI portability for new bats files matters at the dogfood scale. Phase 4 e2e and `adapter_isolation.bats` already paved this road but the F3 fix and the NFR audits add new shell.

**How to avoid:**
- The F3 fix uses only `mkdir`, `ln -s`, `cp`, and the existing `extract_task_field` awk grammar — all known BSD/GNU portable.
- The NFR-002 audit MUST use `shellcheck --shell=sh` (not `--shell=bash`); the `[[ ]]` / `<<<` / `mapfile` / arrays grep is byte-stable BSD/GNU.
- The NFR-004 audit's `grep -vE` for HARNESS_DENY_LIST_CHECK + URL-in-comment is byte-stable.
- The NFR-005 audit's regex must use `[À-ÿ]` (UTF-8 byte range) or hand-rolled accented set; do NOT rely on `[[:alpha:]]` with a locale-specific assumption (BSD `LC_ALL=C` vs GNU `LC_ALL=en_US.UTF-8` differ).
- Run the bats suite on a macOS host before pushing (`bats core/tests/ tests/e2e/`). Phase 4 already does this; Phase 5 must too.

**Warning signs:** A test that passes on macOS but fails in CI with a `grep: extended regular expression` error.

### Pitfall 3: `CHANTIER_CLAUDE_BIN` stub silently consumes flags it shouldn't

**What goes wrong:** The Phase 4 stub (`adapter_claude_code_e2e.bats:84-100`) recognizes `-p|--print` and silently ignores all other flags. If the F3 fix or the e2e test passes a NEW flag (e.g., `--output-format json`), the stub's `case` arm consumes it but the subsequent `shift 2>/dev/null || true` may swallow the prompt argument or fail to advance.

**Why it happens:** The stub is designed to be minimal; flag parsing is best-effort.

**How to avoid:**
- The adapter currently calls `claude -p "$PROMPT"` (single flag + positional). The F3 fix should NOT add new flags to the dispatch — it only adds dossier-staging behavior.
- If the e2e test ever needs a new flag, update the stub's argv loop FIRST in a separate commit, run all 73 + new tests green, then add the flag use.
- Verify the stub's loop terminates cleanly: print `argv parsed; PROMPT=...` to stderr in dev to confirm.

**Warning signs:** Stub exits 1 with `stub: no dossier in prompt` after a flag change.

### Pitfall 4: F3 fix breaks when `depends_on` is `[]`

**What goes wrong:** The current adapter calls `mkdir -p "$DOSSIER/reads" "$DOSSIER/upstream" "$DOSSIER/skill"` unconditionally. The F3 fix adds a loop that may run zero times (for tasks with `depends_on: []`). If the loop's `printf '%s\n' "$DEPENDS_ON" | while IFS= read -r _up_task` doesn't handle the empty-input case, it may emit a spurious error or skip the empty-list path entirely.

**Why it happens:** The existing `state_reads` loop at `adapters/claude-code/run-task.sh:139-143` already handles the empty case (`[ -n "$_sr_path" ] || continue`). The F3 fix must mirror this exactly.

**How to avoid:**
- Use the byte-identical idiom: `printf '%s\n' "$DEPENDS_ON" | while IFS= read -r _up_task; do [ -n "$_up_task" ] || continue; ...; done`.
- Add a bats test (or the in-tree dogfood test from Plan 05-01) that exercises BOTH the empty-`depends_on` case (t1) and the non-empty case (t2). The Phase 5 dogfood naturally exercises both.

**Warning signs:** Phase 4's 73 tests start failing after the F3 patch (because t1-style tasks with `depends_on: []` start emitting errors).

### Pitfall 5: NFR-005 false positives on legitimate English content

**What goes wrong:** A naive accented-character regex matches `naïve`, `café`, `résumé`, `crème`, `façade`, `Pokémon` — all legitimate English (or commonly anglicized) words that may appear in docs or comments.

**Why it happens:** D-06 says "common non-English glyph ranges (accented chars `é à ç ô ù`, etc.)". The intent is to catch sentences-in-French, not isolated borrowed words.

**How to avoid:**
- Use a regex that matches **density** of accented characters, not a single occurrence — e.g., `grep -c '[À-ÿ]' "$_file"` and flag files with `> 5` matches per 100 lines. False positives drop dramatically.
- Or: use a hand-rolled whitelist of "isolated-loanword" allowed lines and grep for non-whitelisted matches. More work, fewer false positives.
- Or: simply grep for **specific French words** common in MAoDzi's discussion prose (`avec`, `donc`, `ainsi`, `pour`, `dans`, `c'est`, `n'est`) — catches the failure mode (French-leaking-into-English) without flagging loanwords. Recommended.
- Discretion item #6 — planner picks. **Recommendation:** grep for 5+ French stop-words OR more than 10% of lines containing `[À-ÿ]` characters; either threshold flags accidental French leakage without flagging isolated loanwords.

**Warning signs:** NFR-005 audit flags `naïve`, `café`, `résumé` in `docs/research/inheritance-map.md`.

### Pitfall 6: ADR 0004 status "Proposed" but missing the Ratification path section

**What goes wrong:** ADR 0003 ships in `Proposed` status with a `## Ratification path` section listing the conditions for moving to Accepted. ADR 0004 must follow the same pattern (D-09 says "status Proposed"; ratification requires a second adapter per F2 deferred).

**Why it happens:** Without an explicit Ratification path, "Proposed" becomes ambient and gets forgotten. ADR 0003 sets the precedent.

**How to avoid:**
- ADR 0004 MUST include a `## Ratification path` section. Conditions: (1) a second harness adapter ships (v0.2.0+); (2) the Surface 3 propagation contract is exercised cross-harness; (3) a maintainer reviews and updates ADR 0004 with cross-harness evidence, then moves status to Accepted.
- Conditions should be observable, not aspirational. Both conditions above are observable (a `git log` shows the second adapter; a bats test shows the contract works cross-harness).

**Warning signs:** ADR 0004 ends at "## Alternatives considered" or "## Open questions" without a path forward.

### Pitfall 7: Cutover event lands in the wrong commit

**What goes wrong:** D-08 says the cutover happens in the **final commit of Phase 5**. If the ROADMAP migration lands in commit A and the `cutover.completed` event lands in commit B (because `chantier state append` happens in a subsequent step), the symbolic moment is fractured and `git log` is confusing.

**Why it happens:** `chantier state append` appends to STATE.md and (per Phase 2 D-04) historically was committed in dedicated migration commits. The natural reflex is to separate.

**How to avoid:**
- Plan 05-04 (Wave 3) explicit task sequence: (1) edit ROADMAP.md per D-07; (2) `chantier state append --event cutover.completed --summary "..." --ref ".planning/ROADMAP.md" --ref "<HEAD-SHA-of-this-commit>"`; (3) `git add -A` (ROADMAP.md + STATE.md + any phase-close SUMMARY.md); (4) ONE commit.
- The `--ref "<commit-sha>"` is the commit being created — this is a chicken-and-egg problem. Recommended workaround: omit the commit-sha ref in the event, OR run a second commit that amends the event line with the now-known SHA. Per `cutover.completed` event refs payload (Discretion #7), simpler to omit the SHA and rely on the appearance of the event-row's `ts` field landing within the commit's timestamp range.
- **Recommendation:** event refs = `[".planning/ROADMAP.md", ".planning/STATE.md"]` — both files mutated in the same commit. The git log will show the SHA naturally; no need to self-reference. If Discretion #7 is "include `bootstrap.harness.chosen` timestamp back-ref" — RECOMMENDED YES: refs = `[".planning/ROADMAP.md", "bootstrap.harness.chosen@2026-05-29T18:30:00Z"]`. Adds audit hygiene; small.

**Warning signs:** `git log -p .planning/STATE.md` shows the cutover event in a different commit than the ROADMAP migration.

### Pitfall 8: Bats e2e test passes locally because `claude` IS on PATH

**What goes wrong:** D-04 says CI must be offline; default is the stub. If the dev's local `claude` binary IS on PATH and the test doesn't strictly export `CHANTIER_CLAUDE_BIN`, the adapter's `${CHANTIER_CLAUDE_BIN:-claude}` indirection silently invokes the real binary on the local dev's machine. The test passes (because claude actually works) but the test would FAIL in CI.

**Why it happens:** The Phase 4 setup is explicit: `export CHANTIER_CLAUDE_BIN="$BATS_TEST_TMPDIR/stub/claude"`. Phase 5 must replicate this AND respect the `CHANTIER_E2E_REAL_CLAUDE` opt-in.

**How to avoid:**
- Per the setup() skeleton above, default to setting `CHANTIER_CLAUDE_BIN`. Only unset (i.e., let the adapter use real `claude`) when `CHANTIER_E2E_REAL_CLAUDE=1` is explicitly set by the operator.
- Run `unset CHANTIER_CLAUDE_BIN; bats tests/e2e/full_loop.bats` once locally — should still pass via the in-setup() default. Then run `CHANTIER_E2E_REAL_CLAUDE=1 bats tests/e2e/full_loop.bats` to exercise the opt-in path (real `claude -p`).
- CI's `bats tests/e2e/` invocation includes neither env var; the test's setup() sets `CHANTIER_CLAUDE_BIN` by default.

**Warning signs:** CI runs `bats tests/e2e/full_loop.bats` and fails with `run-task: claude binary not found and CHANTIER_CLAUDE_BIN unset (D-15)` — meaning the setup() default branch was skipped.

---

## Code Examples

### Example 1: ADR 0004 skeleton (planner authors body)

```markdown
# ADR 0004 — Surface 3 propagation

- **Status:** Proposed
- **Date proposed:** 2026-05-30
- **Date accepted:** —
- **Deciders:** Chantier founding contributors
- **Supersedes:** —
- **Superseded by:** —

> ADR 0001 §Surface 3 specifies that a skill writes `output.md` and `output.json`
> into paths declared in `state_writes`. Phase 4 plan 03 discovered that the
> adapter must perform a propagation step: the skill's `run.sh` writes to its
> `$PWD` (the dossier root, per Phase 4 D-06 worktree-local dossier model),
> but `chantier validate-task` looks for those files in
> `.planning/phases/<phase>/tasks/<task>/`. The adapter bridges this gap with
> a `cp` of plain files from dossier root to TASK_DIR (excluding adapter-owned
> artifacts: `inputs.yml`, `env.sh`, `subagent.transcript.log`).
>
> This ADR codifies that propagation contract. Status is **Proposed**;
> ratification requires a second harness adapter to validate the contract
> cross-harness.

---

## Provenance

[Describe Phase 4 plan 03 discovery — the e2e test caught a real gap in the
smoke-test; the 12-line fix at `adapters/claude-code/run-task.sh:202-219`
made the dossier→state_writes round-trip work.]

## Context

[Three forces: (1) ADR 0001 Surface 3 specifies the *destination* but not the
mechanism; (2) Phase 4 D-06 dossier-worktree-local model means the skill's
`$PWD` is the dossier, not the TASK_DIR; (3) Phase 3 D-04 says the skill is
responsible for emitting `output.md` + `output.json` to its $PWD. The adapter
must bridge these.]

## Decision

[Specify: the adapter SHALL copy every plain file from `$DOSSIER/` to
`$TASK_DIR/`, EXCEPT `inputs.yml`, `env.sh`, `subagent.transcript.log`, and
subdirectories (`reads/`, `upstream/`, `skill/`). Use `cp` not `mv` to honor
Phase 4 D-08 dossier preservation. The copy happens AFTER the subagent's
`claude -p` exits 0, BEFORE `chantier validate-task` runs.]

## Consequences

### Positive
- The skill body does not need to know about TASK_DIR — it writes to `$PWD`.
- Dossier preservation (forensics) and TASK_DIR canonicalization coexist.

### Negative
- The exclusion list is a static contract; new adapter-owned artifacts must
  be added to the list explicitly. Drift risk over time.

## Alternatives considered

### A. Skill writes directly to TASK_DIR (no adapter propagation)
[Rejected: requires every skill to know `$CHANTIER_TASK_DIR` env var; couples
skill bodies to adapter scaffold; violates Phase 3 D-04 self-emission.]

### B. Symlink dossier root to TASK_DIR before dispatch
[Rejected: would couple the two namespaces; failing skill leaves partial
state in TASK_DIR; ADR 0001 Surface 3 wants the gates run against final state.]

### C. Skill emits a manifest, adapter consumes it
[Rejected: adds a new file format; current `cp dossier/* → TASK_DIR/` with
exclusion list achieves the same outcome with no new contract.]

## Open questions (deferred)

1. **Subdirectory propagation.** Currently only plain files in `$DOSSIER/`
   root are copied. If a skill writes artifacts into a subdirectory (e.g.,
   `attempts/`), the propagation step does not include them. Phase 5 dogfood
   does not exercise this; revisit if a v0.2 skill needs subdirectory artifacts.

2. **Atomic propagation.** Currently `cp` is per-file. If the adapter is
   killed mid-propagation, TASK_DIR is partial. Phase 4 has not surfaced this;
   v0.2+ may add a transactional rename.

## Ratification path

This ADR remains **Proposed** until:

1. A second harness adapter (e.g., `adapters/cursor/`) ships and exercises
   the propagation contract.
2. A bats test under `tests/e2e/` proves the contract works on both adapters
   (the contract `output.md` + `output.json` land in TASK_DIR; excluded
   artifacts remain only in the dossier).
3. A maintainer reviews and updates this ADR with cross-harness evidence,
   then moves status to **Accepted**.

Until ratification, this ADR is advisory. The first cross-harness propagation
PR should reference this ADR explicitly.

## References

- ADR 0001 §Surface 3 — establishes that `output.md` + `output.json` are mandatory.
- Phase 4 plan 03 SUMMARY — the discovery moment.
- `adapters/claude-code/run-task.sh:202-219` — the implementation that this
  ADR codifies.
```

### Example 2: ROADMAP minimalist migration diff

The current `.planning/ROADMAP.md` (165 lines) contains exactly one block that must be stripped:

```diff
 # Roadmap: Chantier

-> **Format note (temporary):** This roadmap follows GSD's `gsd-tools` parser format because Chantier uses GSD as its bootstrap planning harness until its own runtime exists (Phase 2). The arc is documented in [STATE.md](STATE.md) under the `bootstrap.harness.chosen` event. Once Phase 5 (dogfood-e2e) ships, this file will be migrated back to Chantier's native format per ADR 0001 — at which point GSD will no longer be invoked in Chantier's own workflows.
-
 ## Overview
```

That's the entire migration per D-07 minimalist intent. Optional further cleanup:
- Phase 5's "Plans" line `- [ ] 05-01: TBD (produced by '/gsd-plan-phase 5'...)` should be replaced with the actual list of plan IDs after Phase 5 completes (`- [x] 05-01-PLAN.md`, `- [x] 05-02-PLAN.md`, etc.) — this is normal phase-close housekeeping, not GSD-format migration.
- The "Plans: TBD" → "Plans: 4 plans (complete)" update mirrors Phase 4's pre/post-close diff.
- No frontmatter changes (already valid per `core/schemas/roadmap.json` permissive `additionalProperties`).
- No removal of the `## Progress` table — it remains, with Phase 5 row marked `Complete | 2026-05-30`.

### Example 3: `cutover.completed` event invocation

```sh
# Final commit of Phase 5. Run from the project root.
chantier state append \
    --event cutover.completed \
    --summary "ROADMAP migrated to ADR 0001 native format. GSD ceases to be invoked in Chantier's own workflows." \
    --ref ".planning/ROADMAP.md" \
    --ref ".planning/STATE.md" \
    --ref "bootstrap.harness.chosen@2026-05-29T18:30:00Z"
```

The third `--ref` is the recommended Discretion #7 resolution: include the bookend back-reference to the `bootstrap.harness.chosen` event (row 24 in STATE.md, `2026-05-29T18:30:00Z`). Audit hygiene; small. The event-name regex from ADR 0002 D-09 (`^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$`) accepts `cutover.completed` — verified by mental application of the regex.

---

## State of the Art

Phase 5 is the first phase where Chantier's own tooling is the production validator. Prior phases were "build the tooling"; Phase 5 is "verify the tooling builds the tooling." The closest precedent in the broader ecosystem is GSD's `/gsd-plan-phase` self-use — which Chantier explicitly leaves behind in this same phase per D-08.

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phase 4 used `/gsd-plan-phase 4` to plan, GSD's tooling to execute | Phase 5 uses `/gsd-plan-phase 5` to plan, Chantier's `adapters/claude-code/run-task.sh` + `chantier validate-task` to execute the dogfood; future phases plan via Chantier's native tooling | This phase, end of v0.1.0 | The cutover symbolic moment — `bootstrap.harness.chosen` event from 2026-05-29 gets its `cutover.completed` bookend. |
| Adapter emitted empty `upstream/` dir for all tasks (Phase 4 baseline) | Adapter parses `depends_on` and stages `upstream/<tN>/output.json` from prior task's emission | Phase 5 plan 05-01 | F3 finding resolved; multi-task chains now work end-to-end. |
| ROADMAP.md in GSD-parser format (temporary per `bootstrap.harness.chosen` 2026-05-29T18:30:00Z) | ROADMAP.md in Chantier-native format per ADR 0001 | Phase 5 plan 05-04 final commit | No tooling depends on GSD parser format anymore; Chantier owns its planning. |
| Surface 3 propagation was undocumented (implicit in `adapters/claude-code/run-task.sh:202-219` since Phase 4 plan 03) | Surface 3 propagation codified in ADR 0004 (Proposed) | Phase 5 plan 05-02 | Future second-adapter authors have a written contract to satisfy. |

**Deprecated/outdated:**

- The `> **Format note (temporary):**` callout block at the top of `.planning/ROADMAP.md` (per D-07). Removed by plan 05-04.
- The `0/TBD` row in `.planning/ROADMAP.md` Progress table for Phase 5 (replaced by `4/4 | Complete | 2026-05-30`).
- (Nothing in source code is deprecated by Phase 5 — the F3 fix is purely additive to `adapters/claude-code/run-task.sh`.)

---

## Assumptions Log

All factual claims in this research were tagged `[VERIFIED]` (probed via host commands or grepped from the in-tree source), `[CITED]` (sourced from an existing in-repo ADR or Phase summary), or, where present, `[ASSUMED]`. The following claims are tagged `[ASSUMED]` and need either user confirmation or runtime verification during planning:

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The two-task dogfood chain produces exactly 6 STATE.md events in the e2e test (2× task.started + 2× skill.completed + 2× task.completed). | Pattern 1 e2e skeleton | If wrong, the test's `grep -c '"event":"task\.started"'` assertions need adjustment. Self-correcting: the test exit will reveal the actual count, and the assertion gets patched. LOW risk. |
| A2 | The F3 fix per-file `output.json` symlink is the right granularity (vs full-dir symlink). | Standard Stack alternatives | If wrong, the t2 task can't read t1's `red.out` or `green.out` files for whatever reason. Discretion item #2 reserves the choice; the planner can re-evaluate against the e2e test's needs. MEDIUM risk — flag for re-confirmation when planning Plan 05-01. |
| A3 | The NFR-005 French-stopwords approach (grep `avec`, `donc`, `c'est`, etc.) is preferable to the broad `[À-ÿ]` regex. | Pitfall 5 | If wrong, the audit produces false positives that block CI on legitimate loanwords. Discretion item #6 — planner decides; both approaches are valid. LOW risk. |
| A4 | `cutover.completed` is acceptable as a new event namespace per ADR 0002's "indicative event taxonomy is non-binding" clause. | Pitfall 7 + Code Example 3 | If wrong, the audit/binary rejects the event. But ADR 0002 explicitly says new namespaces require no ADR revision, and the event-shape regex accepts `cutover.completed`. LOW risk. |
| A5 | Plans 05-01 and 05-02 are parallel-safe (no file overlap). | Primary recommendation | If wrong, the planner must serialize them. Quick check: 05-01 touches `adapters/claude-code/run-task.sh` + `adapters/claude-code/README.md` + a new in-tree bats test; 05-02 touches `docs/adr/0004-*.md` + `core/tests/nfr_audits.bats`. **Zero overlap — assumption verified by file-set inspection.** Reclassify as [VERIFIED]. |
| A6 | The `CHANTIER_E2E_REAL_CLAUDE` env-var convention should match the existing `CHANTIER_*` naming convention (Phase 4 `CHANTIER_CLAUDE_BIN`, `CHANTIER_TASK_ID`, etc.). | Pattern 1 e2e skeleton | LOW risk — naming is consistent with existing prefix; no contract change. |
| A7 | The bats suite should grow from 73 to 75 across the two new files (1 @test in `nfr_audits.bats` is actually 6 @tests; `full_loop.bats` is 1 @test). Actual count: 73 → 73 + 6 + 1 = 80, NOT 75. | Primary recommendation | RECTIFIED IN PLACE: actual expected count is **80/0** at Phase 5 close (six NFR audits + one e2e test). Memory hint that says "75/0" undercounts. |

**Reclassification:** A5 (verified) — files do not overlap.
**Self-correction:** A7 — the suite at Phase 5 close should be 80/0 (73 + 1 from `full_loop.bats` + 6 from `nfr_audits.bats`), not 75/0. **Planner must use 80/0** as the expected suite size in any verification gates.

---

## Open Questions

### 1. Where does the F3 fix's in-tree bats regression test live?

**What we know:** Plan 05-01 ships the F3 fix AND a TDD-style failing-then-passing test (per D-02). The test belongs in `core/tests/` because it's a runtime regression test for the adapter.
**What's unclear:** Should it be a NEW file (`core/tests/adapter_upstream_e2e.bats`) or an additional `@test` block in the existing `core/tests/adapter_claude_code_e2e.bats`?
**Recommendation:** NEW file. The existing file is the FR-008 e2e proof; mixing the F3 regression test would couple two concerns. New file: `core/tests/adapter_upstream_e2e.bats`. Suite goes 73 → 74 here, then 74 → 80 after Plans 05-02 and 05-03.

**Re-correction of A7:** 73 (Phase 4 close) → 74 (Plan 05-01 in-tree regression test) → 80 (Plan 05-02 adds 6 NFR audits) → 81 (Plan 05-03 adds full_loop e2e). Final Phase 5 close: **81/0**.

### 2. Should ADR 0004's "Surface 3 propagation" name be changed to match Chantier's evolving vocabulary?

**What we know:** D-09 calls the contract "Surface 3 propagation." ADR 0001 §Surface 3 specifies the destination paths; the gap Phase 4 plan 03 filled is the dossier→TASK_DIR mechanism.
**What's unclear:** Is "Surface 3 propagation" the right name, or "Dossier propagation" / "Output staging" / "Surface 2-to-3 bridge"?
**Recommendation:** Keep "Surface 3 propagation" — it matches CONTEXT.md D-09 verbiage and the Phase 4 SUMMARY's section heading. Renaming risks introducing a third ADR vocabulary divergence.

### 3. Does the e2e test create the synthetic project name `chantier-e2e-dogfood` (Discretion item #9)?

**What we know:** Discretion item #9 reserves the choice.
**Recommendation:** Yes, `chantier-e2e-dogfood`. It's descriptive, kebab-case (matches the project's `^[a-z][a-z0-9-]*$` ID pattern), and self-documenting in `bats` output. The alternative `chantier-test` is more generic but loses the "dogfood" semantic.

### 4. Does `nfr_audits.bats` delegate NFR-001 to the existing `adapter_isolation.bats`, or duplicate?

**What we know:** D-06 says "may delegate to `adapter_isolation.bats`'s logic via a sourced helper, or duplicate the small grep."
**Recommendation:** **Duplicate** the small grep inline in `nfr_audits.bats`. Rationale: bats does not support `source`-loading another test file's `@test` blocks cleanly; the `adapter_isolation.bats` @test stays as the canonical Phase 4 audit; the new `nfr_audits.bats` NFR-001 @test is the SC#4-explicit gate. Two tests, same pattern — minor redundancy, very clear contract.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bats | `tests/e2e/full_loop.bats`, `core/tests/nfr_audits.bats` | ✓ | 1.13.0 | — (Phase 2 hard requirement) |
| shellcheck | NFR-002 audit in `nfr_audits.bats` | ✓ | 0.11.0 | Skip @test with `command -v shellcheck` precondition (matches existing bats pattern) |
| jq | F3 fix indirectly (not used in fix loop itself); STATE.md row counting in e2e | ✓ | (≥1.6) | — (Phase 2 hard requirement; binary depends on it) |
| git | e2e test setup (`git init`, `git worktree add`, `git config`) | ✓ | 2.50.1 | — (Phase 4 hard requirement) |
| chantier (in-tree binary) | e2e test invokes `chantier new`, `chantier validate-task`, `chantier state append` | ✓ | (v0.1.0 from Phase 2) | — (the unit under integration test) |
| claude (real binary) | OPT-IN only via `CHANTIER_E2E_REAL_CLAUDE=1` | (not required for CI; available locally if installed) | (varies) | `CHANTIER_CLAUDE_BIN` stub is the default — CI never invokes real claude |
| Python / Node.js / Ruby / Go / Rust | (none) | — | — | NFR-002 forbids — this phase ships only POSIX shell + jq. |

**Missing dependencies with no fallback:** none.

**Missing dependencies with fallback:** none (shellcheck is the only conditional dependency; the audit's `@test` skips cleanly when absent).

---

## Validation Architecture

> This section is required per Nyquist Dimension 8 and the Phase 5 instructions. The default for `workflow.nyquist_validation` is enabled (the `.planning/config.json` key is absent, treat as enabled).

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bats-core 1.13.0 + bats-support 0.3.0 + bats-assert 2.2.4 |
| Config file | none (bats discovers `.bats` files by path) |
| Quick run command | `bats core/tests/adapter_upstream_e2e.bats` (per-plan), `bats core/tests/nfr_audits.bats`, `bats tests/e2e/full_loop.bats` |
| Full suite command | `bats core/tests/ tests/e2e/` (must exit 0 with the new 81/0 count at Phase 5 close) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| NFR-001 | No harness identifiers in skill bodies (cross-tree) | unit / static audit | `bats core/tests/nfr_audits.bats -f 'NFR-001'` | ❌ Wave 0 — Plan 05-02 ships `core/tests/nfr_audits.bats` |
| NFR-002 | POSIX sh + jq only; shellcheck clean | unit / static audit | `bats core/tests/nfr_audits.bats -f 'NFR-002'` | ❌ Wave 0 — Plan 05-02 |
| NFR-003 | STATE.md append-only; only `state_append()` writes | unit / static audit | `bats core/tests/nfr_audits.bats -f 'NFR-003'` | ❌ Wave 0 — Plan 05-02 |
| NFR-004 | No network primitives in executable code | unit / static audit | `bats core/tests/nfr_audits.bats -f 'NFR-004'` | ❌ Wave 0 — Plan 05-02 |
| NFR-005 | English-only public artifacts | unit / static audit | `bats core/tests/nfr_audits.bats -f 'NFR-005'` | ❌ Wave 0 — Plan 05-02 |
| NFR-006 | MIT + collective copyright + SPDX headers | unit / static audit | `bats core/tests/nfr_audits.bats -f 'NFR-006'` | ❌ Wave 0 — Plan 05-02 |
| SC#1 | `tests/e2e/` integration test runs full new-project → plan → execute → verify | integration | `bats tests/e2e/full_loop.bats` | ❌ Wave 0 — Plan 05-03 ships |
| SC#2 | Populated STATE.md without contract violations | integration | `bats tests/e2e/full_loop.bats` (asserts 6 events + validate-task green ×2) | ❌ Wave 0 — Plan 05-03 |
| SC#3 | Test passes in CI without network access | integration | `unset CHANTIER_E2E_REAL_CLAUDE; bats tests/e2e/full_loop.bats` | ❌ Wave 0 — Plan 05-03 |
| SC#4 | NFR-001..006 independently verified | unit / static audit | `bats core/tests/nfr_audits.bats` | ❌ Wave 0 — Plan 05-02 (6 @test blocks) |
| SC#5 | ROADMAP migrated to ADR 0001 native format in final commit | manual gate | `git log -p -1 .planning/ROADMAP.md` shows the migration; `head -5 .planning/ROADMAP.md` shows no "Format note (temporary)" | ❌ Wave 0 — Plan 05-04 |
| F3 fix (D-01) | Adapter stages `upstream/<tN>/output.json` for tasks with `depends_on: [tN]` | integration / regression | `bats core/tests/adapter_upstream_e2e.bats` | ❌ Wave 0 — Plan 05-01 |
| ADR 0004 authored (D-09) | `docs/adr/0004-surface-3-propagation.md` exists with Status: Proposed | manual gate | `head -10 docs/adr/0004-surface-3-propagation.md` shows correct frontmatter | ❌ Wave 0 — Plan 05-02 |
| `cutover.completed` event (D-08) | STATE.md contains the event in the final commit | manual gate | `grep '"event":"cutover.completed"' .planning/STATE.md` returns 1 | ❌ Wave 0 — Plan 05-04 |

### Sampling Rate

- **Per task commit:** Whatever single `@test` corresponds to the task (e.g., Plan 05-01 task t2 runs `bats core/tests/adapter_upstream_e2e.bats`).
- **Per wave merge:** `bats core/tests/ tests/e2e/` (full suite; 81/0 target).
- **Phase gate:** Full suite green at Phase 5 close, all six SC#1–SC#5 + F3 + ADR 0004 + cutover gates green, before any phase.completed event.

### Wave 0 Gaps

The following test infrastructure must be created in Phase 5 (no pre-existing file covers it):

- [ ] `core/tests/adapter_upstream_e2e.bats` — F3 fix regression test (Plan 05-01)
- [ ] `core/tests/nfr_audits.bats` — six NFR audits (Plan 05-02)
- [ ] `tests/e2e/` — new top-level directory (Plan 05-03)
- [ ] `tests/e2e/full_loop.bats` — full integration test (Plan 05-03)
- [ ] `docs/adr/0004-surface-3-propagation.md` — Proposed-status ADR (Plan 05-02)

Framework install: none — bats + shellcheck + jq + git already on host (verified in Environment Availability).

---

## Security Domain

> `security_enforcement` is not set in `.planning/config.json`; absent = enabled. The Security Domain section is included.

### Applicable ASVS Categories

Chantier ships a POSIX shell + jq framework with NO authentication, NO sessions, NO network, NO database, NO web surface. Most ASVS categories do not apply.

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V1 Architecture, Design, Threat Modeling | yes (limited) | The ADR series (0001..0004) IS the threat model. ADR 0001 §Decision lists the surfaces; the audit harness enforces them. |
| V2 Authentication | no | Chantier is a local CLI. No accounts, no tokens. NFR-006 enforces "no token, no SaaS lock-in." |
| V3 Session Management | no | No sessions. STATE.md is the only persistence. |
| V4 Access Control | yes (filesystem only) | `chantier validate-task` Gate 1 enforces state_writes containment (no path escape outside repo root). Phase 2 D-Discretion-#4 mkdir-mutex enforces serialization of STATE.md writes. |
| V5 Input Validation | yes | Task IDs validated against `^[a-z][a-z0-9_-]*$` regex in BOTH the binary (Pitfall 6 idiom) and the adapter (`adapters/claude-code/run-task.sh:67-74`). Frontmatter validated via the jq subset validator (ADR 0002). All values flow through `--arg` / `--argjson` in jq invocations — never `printf %s` into JSON (T-02-04-INJ defense from `core/bin/chantier:196` and `skills/test-driven-development/run.sh:140-148`). |
| V6 Cryptography | no | No crypto. No secrets at rest. |
| V7 Error Handling and Logging | yes (limited) | STATE.md is the audit log. `state_append()` is the only sanctioned writer. `set -eu` prelude in every shell file. |
| V8 Data Protection | no | No PII, no sensitive data. STATE.md content is project-public. |
| V9 Communication | no | No network. NFR-004 enforces. |
| V10 Malicious Code | yes (limited) | NFR-002 forbids non-baseline binaries. NFR-006 forbids individual copyright lines (collective copyright prevents drive-by personal-credit attempts). |
| V11 Business Logic | yes (limited) | The ADR 0001 §"contract" surfaces are the business logic. `validate-task` Gates 1–5 catch contract violations. |
| V12 Files and Resources | yes | Gate 1 enforces state_writes containment via `cd && pwd -P` canonicalization (Phase 2 RESEARCH Security Domain row 2). Path traversal (`../`, absolute paths) rejected. |
| V13 API and Web Service | no | No API. |
| V14 Configuration | yes (limited) | `.planning/config.json` is the only config. No secrets, no SaaS endpoints. |

### Known Threat Patterns for POSIX-shell-and-jq stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Shell injection via task ID or PLAN.md content | Tampering | Task ID regex validation (`^[a-zA-Z0-9_-]*$`) at every CLI entry point; `--arg`/`--argjson` for jq; all PLAN.md content flows through awk extraction, never `eval`. |
| Path traversal via `state_writes` value | Tampering, Elevation of Privilege | Gate 1 `cd && pwd -P` canonicalization + repo-root containment check (`core/bin/chantier:616-622`); absolute paths rejected (`:625-630`). |
| Symlink attack on `upstream/<tN>/output.json` (F3 fix) | Tampering | `ln -s` target is computed from `extract_task_field "$TASK_ID" depends_on` → controlled path. The adapter validates that `$WORKTREE/.planning/phases/$PHASE/tasks/<tN>/output.json` exists before symlinking; if missing, exit 2 (Pitfall 4). No external attacker controls the source path. |
| Race condition in STATE.md write | Tampering, Repudiation | mkdir-mutex with stale-PID detection (Phase 2 D-Discretion-#4); 5 retries with 0.5s sleep; trap-on-EXIT for lock release. |
| Harness identifier leak (subagent context contamination) | Information Disclosure | NFR-001 cross-tree audit (`adapter_isolation.bats` + new `nfr_audits.bats` @test #1); deny-list grep with path-only carve-out for `adapters/claude-code/`. |
| Network exfiltration via skill body | Information Disclosure | NFR-004 audit greps for network primitives in executable code; documentation `.md` exempt. |
| French content leaking into public English artifacts | (operational hygiene) | NFR-005 audit (D-06) greps non-English glyph regex; `.planning/` and `docs/strategy/` exempt. |
| Per-person copyright in collective project | (governance) | NFR-006 audit asserts `Chantier Contributors` in `LICENSE`; rejects `(c) <name>` patterns outside `LICENSE-CREDITS`. |

The F3 fix in Phase 5 adds NO new threat surface that the existing controls don't already cover — the symlink target is computed from PLAN.md (already validated), the symlink lives inside `$DOSSIER` (already inside `$WORKTREE`, audited by Gate 1), and no operator-supplied untrusted input flows into the new code path.

---

## Sources

### Primary (HIGH confidence)

- `docs/adr/0001-state-skill-contract.md` — the load-bearing contract (Surfaces 1/2/3, validation gates 1–5)
- `docs/adr/0002-runtime-binary-and-state-format.md` — JSONL STATE.md format, event-shape regex, exit-code matrix, mkdir-mutex pattern, schema subset profile
- `docs/adr/0003-workflow-skill-design-principles.md` — Principle 4 ("chaining is explicit in PLAN.md") informs D-02
- `.planning/REQUIREMENTS.md` — NFR-001..006 verbatim definitions, FR-009 four-skill cap, Acceptance §"v0.1.0 ships when"
- `.planning/ROADMAP.md` §Phase 5 — phase goal, SCs 1–5
- `.planning/PROJECT.md` — v0.1.0 SC#5 ("Chantier's own development is managed by Chantier")
- `.planning/phases/04-claude-code-adapter/04-SUMMARY.md` — Handoff Notes for Phase 5, F1–F4 findings, Surface 3 propagation discovery
- `core/bin/chantier` lines 129–207 (state_append), 448–714 (validate_task), 717–847 (new_project), 687/912 (deny-list)
- `adapters/claude-code/run-task.sh` (253 lines) — full adapter source, the F3 fix integrates at line 118
- `core/tests/adapter_claude_code_e2e.bats` (293 lines) — the shape mirror for `tests/e2e/full_loop.bats`
- `core/tests/adapter_isolation.bats` (124 lines) — the NFR-001 audit pattern template
- `core/tests/skill_test_driven_development_e2e.bats` (170 lines) — Phase 3 direct-invocation TDD test
- `core/tests/fixtures/skills/test-driven-development/dossier/inputs.yml` — deterministic red-phase fixture
- `LICENSE`, `LICENSE-CREDITS` — NFR-006 anchor files
- Host probes (2026-05-30): `bats --version` → 1.13.0; `shellcheck --version` → 0.11.0; `grep -rE 'curl\|wget\|http://\|https://' core/ adapters/ skills/` → only `.md` doc URLs (issue #237 citations in subagent-driven-development).

### Secondary (MEDIUM confidence)

- `.planning/STATE.md` — JSONL audit trail, used to verify the cutover bookend (`bootstrap.harness.chosen` at row 24, `2026-05-29T18:30:00Z`)
- `.planning/phases/04-claude-code-adapter/04-RESEARCH.md` — Phase 4 research as stylistic template for this document
- `.planning/phases/05-dogfood-e2e/05-CONTEXT.md` and `05-DISCUSSION-LOG.md` — operator's locked decisions and audit trail

### Tertiary (LOW confidence)

- None. All findings traced to in-repo primary sources or live host probes.

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — every dependency verified on host (bats, shellcheck, jq, git) and matches Phase 2..4 production versions.
- Architecture: HIGH — F3 fix integrates against an unchanged adapter line; ADR 0004 mirrors ADR 0003 template; e2e test mirrors Phase 4 adapter_claude_code_e2e.bats verbatim except for the multi-task chain extension.
- Pitfalls: HIGH — 8 pitfalls catalogued from Phase 2..4 actual experience (path-with-space, BSD/GNU divergence, stub argv, F3 empty-list, NFR-005 false-positives, ADR-template completeness, cutover-commit timing, default-CHANTIER_CLAUDE_BIN).
- ROADMAP migration: HIGH — exact diff identified (one block stripped, no schema change).
- ADR 0004 content: MEDIUM — structure HIGH (ADR 0003 template mirrored), prose is planner's authorship (Discretion item #4).
- NFR-005 regex: MEDIUM — Discretion item #6 unresolved; recommendation favors French-stopwords approach over broad `[À-ÿ]`.
- Expected bats suite final count: HIGH — corrected to 81/0 (73 + 1 + 6 + 1).

**Research date:** 2026-05-30
**Valid until:** 2026-06-29 (30 days — Chantier's surfaces are stable per ADR 0001/0002; the only update vector before then is a v0.2 adapter or skill drop, both deferred).

## RESEARCH COMPLETE
