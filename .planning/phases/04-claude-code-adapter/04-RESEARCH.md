# Phase 4: Claude Code adapter — Research

**Researched:** 2026-05-30
**Domain:** POSIX-shell harness adapter; headless CLI subprocess dispatch; ADR 0001 Surface 2 dossier staging; cross-tree static audit
**Confidence:** HIGH

## Summary

Phase 4 ships `adapters/claude-code/run-task.sh`, a POSIX-shell adapter that stages a per-task dossier inside an operator-provided git worktree, dispatches a `claude -p` headless subagent to read `SKILL.md` and exec `run.sh`, then routes the result through `chantier validate-task`. The dispatch contract is intentionally thin (ADR 0003 Principle 3): a ~15-line heredoc instructs the subagent to source `env.sh`, read the skill body, exec `run.sh`, and report the exit code. Three STATE.md events bracket the run (`task.started` → `skill.completed` → `task.completed` | `task.failed`). A new bats audit (`adapter_isolation.bats`) enforces NFR-001's cross-tree carve-out: `claude-code` and `mcp__claude_ai_` are allowed only inside `adapters/claude-code/`; all other deny-list tokens remain forbidden everywhere.

The phase has unusually high decision density (D-01 through D-16 already locked) and the technical surface is small: ~150 lines of POSIX sh in the adapter, ~80 lines of bats audit, ~180 lines of bats e2e mirroring `core/tests/skill_test_driven_development_e2e.bats`. The hard problems are not implementation effort — they are (1) honoring the path-only NFR-001 carve-out without leaking deny-list tokens into the audit *script itself* (it must reference `claude-code` to know what to exempt), (2) building a deterministic `CHANTIER_CLAUDE_BIN` stub that satisfies whatever flags the adapter passes, and (3) avoiding heredoc-injection in the dispatch prompt while keeping it inline per D-02.

Environment verification confirms `claude` 2.1.126 is installed at `/usr/local/bin/claude`, supports `-p`/`--print` headless mode with stdout output, accepts `--output-format text|json|stream-json`, and reads a single positional `prompt` argument. The headless contract is stable and matches D-01/D-15's assumptions. All other dependencies (`jq` 1.7.1, `git` 2.50.1, `bats` 1.13.0, `shellcheck` 0.11.0) are present and version-compatible with Phase 2/3.

**Primary recommendation:** Build a minimal three-section adapter (preflight checks → dossier staging → dispatch + bracketing). Reuse Phase 3's `make_plan` helper and TMPHOME setup verbatim for the e2e. The PLAN.md task lookup mechanic (Open Question) is best resolved by inline awk reusing `chantier validate-task`'s gate 1 extraction pattern — adding `chantier task-lookup` is unnecessary surface area for v0.1.

---

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

**Dispatch mechanism:**
- **D-01:** The adapter dispatches a real Claude Code subagent via the headless CLI: `claude -p "<prompt>"`. A vrai sous-process per task — isolation conforms to ADR 0001 ("subagent receives only its dossier and the skill body; both are file paths") and to the framing phrase "a plain shell script that wraps an LLM call." The adapter itself stays POSIX sh; NFR-002's `sh + jq` substrate is preserved.
- **D-02:** The dispatch prompt is a minimal heredoc inlined in `run-task.sh`, ~15 lines. It tells the subagent: `cd` into the dossier, source `env.sh`, read `skill/SKILL.md`, acknowledge invariants, exec `skill/run.sh`, report the exit code. The prompt is a **pointer**, not a re-statement of discipline — the discipline lives in the SKILL.md body. Aligns ADR 0003 (Proposed) Principle 3 "thin skill, smart LLM." No sibling template file, no `--allowedTools` whitelist in v0.1 (validate-task gate 4 is the post-hoc guard).
- **D-03:** The adapter brackets each task with two STATE.md events: `task.started` before invoking `claude -p`, and `task.completed` (validate-task green) or `task.failed` (any earlier exit non-zero, OR validate-task red) after. The skill's `run.sh` continues to append its own `skill.completed` per Phase 3 D-04. Net: three events per successful task — `task.started` (adapter), `skill.completed` (skill), `task.completed` (adapter). Failure mode emits `task.started` + `task.failed` (skill may or may not reach `skill.completed`).
- **D-04:** The adapter reproduces the binary's 4-value exit-code matrix: `0` = green (skill exit 0 and validate-task gate 5 green), `1` = contract violation (validate-task red), `2` = invocation error (malformed dossier, missing PLAN/SKILL lookup, claude returned non-zero for prompt-level reasons), `3` = environment error (`claude` binary not on PATH or not executable, `jq` missing). On validate-task red, the adapter moves `output.md` + `output.json` to `phases/N/tasks/<task>/attempts/<n>/` (n auto-incremented), then exits 1. Re-running `run-task.sh` repeats from scratch and increments n on the next failure. Aligns ADR 0001 §"A failed validation is a re-runnable error, not a destructive one."

**Worktree integration:**
- **D-05:** The operator pre-creates the git worktree with `git worktree add` and `cd`s into it before invoking `run-task.sh`. The adapter does not call `git worktree add`. On invocation, the adapter validates `git rev-parse --is-inside-work-tree` and refuses to proceed if false (exit 2, invocation error). Separation rationale: `using-git-worktrees` is the project-level worktree skill for the developer's own work; the adapter's worktree is the operator's responsibility. ROADMAP SC#3 ("executed in a worktree") is satisfied by the test setup performing `git worktree add` before invoking the adapter.
- **D-06:** The dossier lives at `$WORKTREE/.chantier/dossiers/<task>/` — worktree-local, not main-repo-shared. Parallel-safe by construction (two worktrees = two dossier roots). Cleanup of a worktree (`git worktree remove`) atomically purges its dossier + outputs. The `<task>` segment is the task ID from PLAN.md, never a filename.
- **D-07:** `env.sh` is belt-and-suspenders. The adapter writes `env.sh` into the dossier with `CHANTIER_TASK_ID`, `CHANTIER_PHASE`, `CHANTIER_WORKTREE` exported (forensic record + ADR 0001 contract). The adapter ALSO exports the same vars in its own process before invoking `claude -p` (subprocess inheritance — `claude -p` inherits env). The subagent prompt (D-02) instructs the subagent to `source ./env.sh` after `cd`'ing into the dossier (the load-bearing path). Triple safety — if one layer leaks, the vars remain present. Zero modification to Phase 3 skills (which read PWD + rely on externally exported `CHANTIER_TASK_ID`, as `core/tests/skill_*_e2e.bats` already do).
- **D-08:** After a successful task (validate-task green), the dossier at `$WORKTREE/.chantier/dossiers/<task>/` is **preserved**, not deleted. The operator (or a future cleanup skill) decides when to purge. Forensic inspection — "what did the subagent see as input?" — remains possible days later.

**NFR-001 carve-out:**
- **D-09:** A new bats test, `core/tests/adapter_isolation.bats`, audits the source tree for cross-harness contamination. Greps for the ADR 0002 deny-list pattern (`mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode`) and asserts zero matches outside the allowed paths. Path-only exemption — no marker file, no per-line opt-out comment.
- **D-10:** Inside `adapters/claude-code/`, the substrings `claude-code` and `mcp__claude_ai_` are allowed (the directory IS the harness's adapter). All OTHER deny-list substrings (`cursor`, `codex-cli`, `copilot-cli`, `gemini-cli`, `opencode`, bare `mcp__` outside `mcp__claude_ai_`) remain forbidden inside `adapters/claude-code/`.
- **D-11:** Audit scope is source/test paths: `core/`, `skills/`, `tests/`, and `adapters/*` except the path being audited. Exempt entirely: `docs/`, `.planning/`, and `core/bin/chantier` (which has its own `HARNESS_DENY_LIST_CHECK` marker for the `--self-test` self-scan).
- **D-12:** The audit runs in the existing bats suite (no separate CI job). Failure mode: bats test red, surfaces the offending file path, blocks the merge.

**End-to-end proof:**
- **D-13:** The Phase 4 e2e exercises the `test-driven-development` skill via its red-phase fixture (`test_command: "false"`, exits 1 deterministically). Same fixture, same skill, but dispatched through the adapter (`claude -p`) instead of directly (`sh run.sh`). Comparable signal: `output.json.red_exit_code = 1`, `output.json.red_step_timestamp` ISO-8601, `invariants_applied` length ≥ 4, validate-task gate 5 green.
- **D-14:** The e2e test lives at `core/tests/adapter_claude_code_e2e.bats`. Composes with the 71-test bats suite. Naming: `adapter_<harness>_e2e.bats` becomes the pattern for future adapter tests.
- **D-15:** The test uses a deterministic stub of `claude` via `CHANTIER_CLAUDE_BIN`. The setup writes a ~10-line shell stub that does `cd "$DOSSIER" && . ./env.sh && sh ./skill/run.sh && exit $?`, plus a minimal echo of a "subagent transcript" line for trace fidelity. The adapter resolves `${CHANTIER_CLAUDE_BIN:-claude}` from PATH.
- **D-16:** Operator-facing CLI: `adapters/claude-code/run-task.sh <task-id>`. Single positional argument. The adapter discovers the plan via the same mechanism as `chantier validate-task <task>` — walk `cwd`'s `.planning/phases/*/PLAN.md` files, find the YAML task block whose `task:` field matches.

### Claude's Discretion

Implementation-level decisions remaining open to planner/researcher refinement:

- **Subagent transcript persistence.** Whether the real `claude -p` invocation captures its stdout/stderr into a `subagent.transcript.log` file under the dossier (for forensics).
- **PLAN.md task lookup mechanics.** Reuse the lookup that `chantier validate-task` implements (call the binary as a subprocess, e.g., `chantier task-lookup <id>` if added), or duplicate the walk-and-grep inline.
- **Stub script invocation contract.** The stub at `CHANTIER_CLAUDE_BIN` must accept whatever flags/args `claude -p` accepts. The stub may ignore most of them; exact ignored-flag handling is planner's call.
- **Worktree validation strictness.** Whether to forbid running in the main checkout, or only require any worktree.
- **Audit shell syntax.** The exact grep invocation in `adapter_isolation.bats` (POSIX-portable).
- **task.started event payload.** Whether to include `worktree: "<path>"` in refs.
- **`attempts/<n>/` numbering.** Zero-pad width (likely 2 or 3 digits).
- **Subagent prompt heredoc wording.** ~15-line target is the budget; exact prose is the planner's responsibility.
- **Dispatch concurrency.** Whether to add a mkdir-mutex lock on `.chantier/dossiers/<task>/.lock`.
- **`output.md` Acceptance section pass-through.** The skill writes Acceptance items into `output.md`; gate 5 substring-matches them.

### Deferred Ideas (OUT OF SCOPE)

- **Second harness adapter** (`adapters/cursor/`, `adapters/codex-cli/`, etc.) — deferred to v0.2.0.
- **`tests/e2e/` full integration test** — Phase 5 owns the new-project → plan → execute → verify loop.
- **Real `claude` API call in CI** — NFR-004 forbids network.
- **`--allowedTools` lockdown on the subagent** — validate-task gate 4 is the post-hoc guard.
- **Sibling template file for the dispatch prompt** — D-02's inline heredoc is sufficient; promote only if prompt grows past ~30 lines.
- **`subagent.transcript.log` capture mandate** — Claude's Discretion item.
- **PLAN.md task lookup via a new `chantier` subcommand** — Claude's Discretion item.
- **Concurrent task dispatch safety** — deferred; single-task dispatch is enough for v0.1.
- **Composition of `using-git-worktrees` as a pre-task** — explicitly rejected for D-05.
- **`run-task.sh` flag-based options** — No `--plan`, no `--worktree`, no `--dry-run` in v0.1 per D-16.
- **`extract-skills-from-phase` self-improvement skill** — deferred to v0.3.0.
- **ADR 0003 ratification** — deferred until after Phase 5 dogfood.
- **`STATE.md` compaction** — still deferred per ADR 0001 OQ #2.

</user_constraints>

---

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FR-008 | `adapters/claude-code/` exists and can stage a dossier for a task. | Architecture Pattern 1 (Three-section adapter) + Pattern 2 (Dossier staging schema) + Code Example 1 (adapter skeleton) + Code Example 2 (dossier writer) + Validation Architecture (full proof chain through adapter_claude_code_e2e.bats). |

</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Operator-facing CLI (`run-task.sh <task-id>`) | Adapter shell script | — | Per D-16, the adapter is the entry point; no binary subcommand needed. |
| PLAN.md task lookup (resolve `<task-id>` → skill, state_writes, acceptance) | Adapter shell script | core/bin/chantier (validate-task gate 1 awk pattern is the source of truth, can be re-used inline) | D-Discretion item: planner chooses inline vs binary subcommand. Recommendation: inline, mirroring `validate-task`'s extraction awk. |
| Dossier staging (write `inputs.yml`, `reads/`, `upstream/`, `env.sh`, copy skill body) | Adapter shell script | — | Per D-06 and ADR 0001 Surface 2; the adapter is the only code that knows the dossier shape. |
| Worktree precondition check (`git rev-parse --is-inside-work-tree`) | Adapter shell script | git | Per D-05; the operator pre-creates, the adapter validates. |
| Env injection (`CHANTIER_TASK_ID`, `CHANTIER_PHASE`, `CHANTIER_WORKTREE`) | Adapter shell script (triple layer per D-07) | claude subprocess inherits env | Belt-and-suspenders: written to `env.sh`, exported in adapter process, sourced by subagent. |
| Subagent dispatch (`claude -p "$PROMPT"`) | Adapter shell script | claude CLI (Anthropic) | Per D-01; real subprocess, not a library call. `${CHANTIER_CLAUDE_BIN:-claude}` indirection per D-15. |
| Skill body execution (`sh run.sh`) | Subagent | Phase 3 skills directly | Per D-02; the prompt tells the subagent to exec, then the skill owns the mechanics. |
| Output emission (`output.md`, `output.json`) | Skill `run.sh` | — | Per Phase 3 D-03; the adapter never writes outputs. |
| `skill.completed` STATE.md event | Skill `run.sh` | core/bin/chantier (`state append`) | Per Phase 3 D-04; the adapter never appends `skill.completed`. |
| `task.started` / `task.completed` / `task.failed` STATE.md events | Adapter shell script | core/bin/chantier (`state append`) | Per D-03; only the adapter appends these. |
| Validation gate enforcement (5 ADR 0001 gates) | core/bin/chantier (`validate-task`) | — | Per D-04; the adapter shells out, never duplicates logic. |
| Quarantine on failure (`attempts/<n>/`) | Adapter shell script | — | Per D-04; the adapter moves outputs before exiting 1. |
| Cross-tree isolation audit | core/tests/adapter_isolation.bats | bats + grep | Per D-09/D-10/D-11/D-12; static check, runs in existing bats suite. |
| End-to-end proof | core/tests/adapter_claude_code_e2e.bats | bats + Phase 3 fixture | Per D-13/D-14/D-15; mirrors `skill_test_driven_development_e2e.bats` with adapter in the middle. |

---

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| POSIX `sh` (`/bin/sh`) | system | Adapter scripting language | NFR-002 carve-out applies to binary; D-01 extends it to the adapter; macOS dash-equivalent + Linux dash agree on the subset Phase 2/3 use. `[VERIFIED: /bin/sh exists on macOS 15.7.4]` |
| `git` | 2.50.1 (Apple) | Worktree validation (`git rev-parse --is-inside-work-tree`); PLAN.md is in a git repo | Already a Chantier baseline assumption (Phase 3 `using-git-worktrees`). `[VERIFIED: git --version on host]` |
| `jq` | 1.7.1-apple | None directly in the adapter (chantier binary uses jq for state append); needed if adapter emits JSON | Already required by `core/bin/chantier`; no new dependency. `[VERIFIED: jq --version on host]` |
| `claude` (Claude Code CLI) | 2.1.126 | Headless subagent dispatch via `-p`/`--print` | Per D-01; the headless contract is the only adapter-specific dependency. `[VERIFIED: /usr/local/bin/claude --version on host]` |
| `core/bin/chantier` | 0.1.0 | `state append` (events), `validate-task` (gates) | Shipped Phase 2; reused as subprocess. `[VERIFIED: core/bin/chantier --version]` |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `bats-core` | 1.13.0 | Test harness for `adapter_isolation.bats` and `adapter_claude_code_e2e.bats` | Composes with existing 71-test suite at `core/tests/`. `[VERIFIED: bats --version on host]` |
| `bats-support` + `bats-assert` | 0.3.0 + 2.2.4 (vendored) | Test assertions | Loaded by every existing e2e bats test; reuse verbatim. `[VERIFIED: core/tests/test_helper/ exists]` |
| `shellcheck` | 0.11.0 | Static analysis of `run-task.sh` and the stub | Phase 2/3 ran every shell artifact through `shellcheck --shell=sh`; Phase 4 must too. `[VERIFIED: shellcheck --version on host]` |
| `awk` (POSIX) | system | Inline extraction of `skill:`, `state_writes:`, `acceptance:` from PLAN.md task block | Pattern lifted from `core/bin/chantier` lines 530-572 (validate-task gate 1 extraction). `[VERIFIED: awk present, used by chantier binary]` |
| `find` (POSIX) | system | `find … -type f` for adapter_isolation.bats grep scope | macOS BSD find ≠ GNU find; restrict to POSIX flags (`-type`, `-name`, `-print`). `[VERIFIED: pattern works in core/tests/skill_uniformity.bats]` |

### Alternatives Considered

| Instead of | Could Use | Why Rejected |
|------------|-----------|--------------|
| `claude -p "$PROMPT"` (positional) | `printf '%s' "$PROMPT" \| claude -p` (stdin) | Adapter prompt fits comfortably in argv; stdin requires extra `--input-format text` handling and complicates the stub. The positional form is what `claude --help` documents as the primary headless contract. `[VERIFIED: claude --help shows "claude -p <prompt>"]` |
| `claude -p --output-format json` | `claude -p` (default text) | JSON output adds parsing complexity; the adapter does not consume the subagent's stdout (the skill writes files; we read files). Text default is simpler and aligns with D-02's minimal prompt. `[CITED: claude --help "Output format (only works with --print)"]` |
| Inline awk for PLAN.md lookup | New `chantier task-lookup <id>` subcommand | Adding a subcommand for a single-caller lookup is premature surface area. The awk pattern already lives in `core/bin/chantier` lines 530-572 and is well-tested. Recommend inline; if a second consumer appears in v0.2, extract then. |
| Separate `subagent.prompt.md` template file | Inline heredoc per D-02 | D-02 locked. The CONTEXT.md explicitly notes "promote to a template only if the prompt grows past ~30 lines." |
| `git worktree add` inside the adapter | Operator pre-creates per D-05 | D-05 locked. Separation: `using-git-worktrees` is the dev skill; adapter worktree is operator responsibility. |
| `flock` for `.chantier/dossiers/<task>/.lock` | mkdir-mutex (Phase 2 pattern) | Phase 2 / ADR 0002 already established mkdir-mutex over flock because `flock(1)` is absent on macOS Darwin. If concurrency is added (Claude's Discretion), reuse the Phase 2 pattern. |

### Installation

No new packages installed for Phase 4. All dependencies already present on the host (verified):
```bash
# Verification only — no install needed:
command -v sh && command -v git && command -v jq && command -v claude && command -v bats
```

### Version Verification

| Tool | Probe | Result |
|------|-------|--------|
| claude CLI | `claude --version` | `2.1.126 (Claude Code)` `[VERIFIED]` |
| jq | `jq --version` | `jq-1.7.1-apple` `[VERIFIED]` |
| git | `git --version` | `git version 2.50.1 (Apple Git-155)` `[VERIFIED]` |
| bats | `bats --version` | `Bats 1.13.0` `[VERIFIED]` |
| shellcheck | `shellcheck --version` | `0.11.0` `[VERIFIED]` |
| macOS | `sw_vers` | `15.7.4 / 24G517` `[VERIFIED]` |
| /bin/sh | `sh --version` | bash 3.2.57 (sh-compat mode) `[VERIFIED]` |

---

## Package Legitimacy Audit

> **N/A for Phase 4.** This phase installs no external packages. All dependencies (`claude`, `jq`, `git`, `bats-core`, `bats-support`, `bats-assert`, `shellcheck`) were already verified and installed in Phase 1/2/3. The bats helper submodules (`bats-support` v0.3.0, `bats-assert` v2.2.4) were vendored in plan 02-01 with explicit version pinning. No new package manifests, no new `npm install`, no new `pip install`, no new `cargo add`. The Package Legitimacy Gate protocol is satisfied trivially.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| (none) | — | — | — | — | — | — |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
                  ┌─────────────────────────────────┐
                  │ Operator                        │
                  │ (Phase 5 dogfood, or CI bats)   │
                  └────────────┬────────────────────┘
                               │ 1. git worktree add <wt>  (per D-05)
                               │ 2. cd <wt>
                               │ 3. adapters/claude-code/run-task.sh <task-id>
                               ▼
       ┌────────────────────────────────────────────────────┐
       │ adapters/claude-code/run-task.sh                   │
       │                                                    │
       │ ┌────────────────────────────────────────────────┐ │
       │ │ Preflight (D-04 exit 2/3 boundary)             │ │
       │ │  - command -v claude / jq (else exit 3)        │ │
       │ │  - git rev-parse --is-inside-work-tree (D-05)  │ │
       │ │  - PLAN.md lookup → resolve skill, state_writes│ │
       │ │  - SKILL.md exists; harness_adapters honored   │ │
       │ └─────────────────┬──────────────────────────────┘ │
       │                   ▼                                │
       │ ┌────────────────────────────────────────────────┐ │
       │ │ Stage dossier  $WORKTREE/.chantier/dossiers/<task>/   │
       │ │  - inputs.yml  (copy from fixture/PLAN inputs)         │
       │ │  - reads/      (symlink state_reads paths)             │
       │ │  - upstream/   (symlink upstream task outputs)         │
       │ │  - env.sh      (write CHANTIER_TASK_ID etc., D-07)     │
       │ │  - skill/      (copy SKILL.md + run.sh + PRESSURE.md)  │
       │ └─────────────────┬──────────────────────────────┘ │
       │                   ▼                                │
       │ ┌────────────────────────────────────────────────┐ │
       │ │ chantier state append -e task.started ... (D-03)│ │
       │ └─────────────────┬──────────────────────────────┘ │
       │                   ▼                                │
       │ ┌────────────────────────────────────────────────┐ │
       │ │ Export env + dispatch (D-01, D-07)             │ │
       │ │  CHANTIER_TASK_ID=… ${CHANTIER_CLAUDE_BIN:-claude} \  │
       │ │      -p "<~15-line heredoc dispatch prompt>" (D-02)   │ │
       │ └─────────────────┬──────────────────────────────┘ │
       │                   │                                │
       │                   ▼                                │
       │       ┌───────────────────────────────────────────┐│
       │       │ Subagent (claude -p subprocess)           ││
       │       │  1. cd .chantier/dossiers/<task>/         ││
       │       │  2. . ./env.sh    (D-07 load-bearing src) ││
       │       │  3. cat ./skill/SKILL.md  + acknowledge   ││
       │       │  4. sh ./skill/run.sh                     ││
       │       │     └─→ writes output.md, output.json     ││
       │       │     └─→ chantier state append             ││
       │       │            -e skill.completed (Phase 3 D-04)│
       │       └─────────────────┬─────────────────────────┘│
       │                         ▼                          │
       │ ┌────────────────────────────────────────────────┐ │
       │ │ chantier validate-task <task-id> (D-04 gate)   │ │
       │ │  - 5 gates: path containment, output.md/.json, │ │
       │ │    portability grep, acceptance items          │ │
       │ └─────────────────┬──────────────────────────────┘ │
       │                   │                                │
       │   gate green ──────┤────── gate red                │
       │                   ▼            ▼                   │
       │ ┌────────────────────────┐ ┌────────────────────┐ │
       │ │ state append           │ │ Move output.{md,    │ │
       │ │   -e task.completed    │ │  json} → attempts/  │ │
       │ │ exit 0                 │ │  <n>/  (D-04)       │ │
       │ └────────────────────────┘ │ state append        │ │
       │                            │   -e task.failed    │ │
       │                            │ exit 1              │ │
       │                            └────────────────────┘ │
       └────────────────────────────────────────────────────┘
                               │
                               ▼
                    Operator reads exit code; STATE.md has 2-3 events
                    Dossier preserved on disk (D-08) for forensics
```

**Audit lifecycle (parallel surface, runs in bats suite, not in adapter call path):**
```
   ┌─────────────────────────────────────────────────────────┐
   │ core/tests/adapter_isolation.bats (D-09, D-10, D-11, D-12) │
   │  for each PATH in {core/, skills/, tests/,                 │
   │                    adapters/*/ except path-being-audited}:│
   │    grep -rE 'mcp__|claude_ai_|@codebase|claude-code|       │
   │              cursor|codex-cli|copilot-cli|gemini-cli|      │
   │              opencode' $PATH                               │
   │    assert 0 matches                                        │
   │  Exempt: docs/, .planning/, core/bin/chantier (HARNESS_…)  │
   │  Carve-out: inside adapters/claude-code/, only             │
   │             `claude-code` and `mcp__claude_ai_` allowed   │
   └─────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
adapters/
└── claude-code/
    ├── README.md              # operator-facing usage (English, NFR-005)
    └── run-task.sh            # ~150 lines POSIX sh, chmod +x, shellcheck clean

core/tests/
├── adapter_isolation.bats     # NEW — D-09/D-10/D-11/D-12 audit
└── adapter_claude_code_e2e.bats  # NEW — D-13/D-14/D-15 e2e with stub
```

**Notes on placement:**
- `adapters/claude-code/run-task.sh` is the only operator entry point; no subcommands, no helpers (D-16).
- The bats tests live under `core/tests/` so they compose with the existing 71-test suite via `bats core/tests/` (planner can confirm by running). Naming pattern `adapter_<harness>_e2e.bats` is the template for v0.2's `adapters/cursor/`.
- No `adapters/claude-code/tests/` subdirectory — would fragment test discovery (Phase 3 D-14 chose `core/tests/skill_<name>_e2e.bats` for the same reason).

### Pattern 1: Three-Section Adapter

**What:** The adapter has exactly three logical sections in `run-task.sh`: preflight (environment + lookup), staging (dossier writer), dispatch (event + claude + validate + bracket). Each section has a clear exit code boundary.

**When to use:** Always — this is the only structure that maps the adapter's flow to the D-04 exit matrix without intermixing concerns.

**Example:**
```sh
# Source: synthesis of D-04 exit matrix + Phase 2 core/bin/chantier dispatch model

#!/bin/sh
set -eu; IFS='
'; LC_ALL=C; export LC_ALL

# Section 1: Preflight (exit boundary: 3 environment / 2 invocation / continue)
# - command -v claude  → exit 3 if missing
# - command -v jq      → exit 3 if missing  (chantier binary needs it for state append)
# - git rev-parse --is-inside-work-tree  → exit 2 if false
# - parse argv: $1 = task-id, else exit 3 "usage: run-task.sh <task-id>"
# - locate PLAN.md and resolve task block → exit 2 if not found
# - locate skills/<id>/SKILL.md → exit 2 if not found

# Section 2: Stage dossier (exit boundary: 2 invocation / continue)
# - mkdir -p $WORKTREE/.chantier/dossiers/<task>/{reads,upstream,skill}
# - write env.sh (CHANTIER_TASK_ID, CHANTIER_PHASE, CHANTIER_WORKTREE)
# - copy inputs.yml from PLAN.md task block (or test fixture in e2e)
# - cp SKILL.md PRESSURE.md run.sh into skill/

# Section 3: Dispatch (exit boundary: 0/1 business / continue from D-04 matrix)
# - chantier state append -e task.started …
# - export CHANTIER_TASK_ID=… (subprocess inheritance per D-07)
# - "${CHANTIER_CLAUDE_BIN:-claude}" -p "$(cat <<'PROMPT'
#     cd .chantier/dossiers/<task>/
#     . ./env.sh
#     cat ./skill/SKILL.md      # acknowledge invariants
#     sh ./skill/run.sh
#     exit $?
#     PROMPT
#   )"  → claude exit non-zero → state append task.failed; exit 2
# - chantier validate-task <task-id>  → non-zero → mv outputs → attempts/<n>/; state append task.failed; exit 1
# - chantier state append -e task.completed …
# - exit 0
```

### Pattern 2: Dossier Staging Schema

**What:** The dossier under `$WORKTREE/.chantier/dossiers/<task>/` follows ADR 0001 Surface 2 verbatim, with one Phase 4 addition: a `skill/` subdirectory holding the copied skill body.

**Why a `skill/` subdir:** The subagent's prompt (D-02) says "read `skill/SKILL.md`, exec `skill/run.sh`". If the skill body lived at `$WORKTREE/skills/<id>/`, the subagent would need a path the operator chose; placing it under the dossier makes the dossier self-contained and the prompt path-stable.

**Example:**
```
$WORKTREE/.chantier/dossiers/t1/
├── inputs.yml          # copied from PLAN.md task block (or fixture)
├── reads/              # symlinks to state_reads paths
│   └── PROJECT.md → ../../../PROJECT.md
├── upstream/           # symlinks to depends_on tasks' outputs (empty if depends_on: [])
├── env.sh              # CHANTIER_TASK_ID=t1; export CHANTIER_TASK_ID; …
└── skill/              # copy of skills/<id>/ contents
    ├── SKILL.md
    ├── PRESSURE.md
    └── run.sh          # exec'd by subagent
```

**Notes:**
- `reads/` and `upstream/` use **symlinks** per ADR 0001 §"Surface 2 — How a skill accesses current state" ("symlinks or copies"). Symlinks are cheaper and let `cat ./reads/PROJECT.md` always reflect the current file. Phase 3 fixtures use copies (no `reads/` in dossier); Phase 4 should use symlinks because real adapter dossiers reference live state.
- The Phase 4 e2e (D-13) uses a fixture with no `reads/` or `upstream/` entries (TDD red-phase fixture is self-contained), so the e2e path only needs to handle the empty case correctly.
- `env.sh` is the only mandatory file; the rest depend on what the task declares.

### Pattern 3: PLAN.md Inline Task Lookup (awk-based, matches `validate-task`)

**What:** Resolve `<task-id>` to `(plan_path, phase, skill_id, state_writes, acceptance)` by walking `.planning/phases/*/PLAN.md`, finding the YAML task block whose `task:` field matches, and extracting needed fields with awk.

**When to use:** In `run-task.sh` preflight. Use the same awk shape as `core/bin/chantier` lines 530-572 to keep grammar drift between binary and adapter at zero.

**Example:**
```sh
# Source: core/bin/chantier lines 530-572 (validate-task gate 1 extraction), adapted

# Find PLAN.md whose YAML body contains `task: <id>`
TASK_ID="$1"
PLAN_PATH=$(find .planning/phases -name '*PLAN.md' -type f 2>/dev/null \
    | sort \
    | while IFS= read -r _p; do
        grep -q "task: $TASK_ID" "$_p" 2>/dev/null && printf '%s\n' "$_p" && break
      done)

[ -n "$PLAN_PATH" ] || {
    printf 'run-task: task %s not found in any .planning/phases/*/PLAN.md\n' "$TASK_ID" >&2
    exit 2
}

# Extract skill id from the matching task block (awk pattern from validate-task)
SKILL_ID=$(awk -v task="$TASK_ID" '
    /^```yaml/ { in_yaml=1; buf=""; next }
    /^```/ && in_yaml {
        in_yaml=0
        if (buf ~ "task: " task "(\n|$)") {
            n = split(buf, lines, "\n")
            for (i=1; i<=n; i++) {
                if (lines[i] ~ /^skill:/) {
                    gsub(/^skill:[[:space:]]*"?|"?[[:space:]]*$/, "", lines[i])
                    print lines[i]
                }
            }
        }
        buf=""; next
    }
    in_yaml { buf = buf $0 "\n" }
' "$PLAN_PATH")
```

### Pattern 4: Thin Dispatch Prompt (~15 lines, no discipline restatement)

**What:** Per D-02, the heredoc prompt is a *pointer*, not a re-statement of discipline. The discipline lives in `skill/SKILL.md`. The prompt's job: tell the subagent where it is, what to read first, what to execute, and how to report.

**When to use:** Always. The prompt must fit comfortably under 30 lines (else promote to a sibling file per CONTEXT.md deferred ideas).

**Example:**
```sh
# Source: synthesis of D-02 (~15 lines, pointer not restatement) + ADR 0003 Principle 3

PROMPT=$(cat <<'PROMPT_EOF'
You are dispatched by the Chantier Claude Code adapter to execute one skill task.

Your working directory is the task dossier: $DOSSIER_PATH

Do this, in order:
  1. cd "$DOSSIER_PATH"
  2. Source env.sh: . ./env.sh
  3. Read skill/SKILL.md end-to-end. Acknowledge (in your own words) which
     Invariants listed in `## Invariants` apply to this task and why.
  4. Execute the skill: sh ./skill/run.sh
  5. Report the exit code from run.sh as your final line: "EXIT $?"

Do not invent additional steps. The discipline is in skill/SKILL.md.
Do not edit any file outside the paths declared in skill/SKILL.md state_writes.
PROMPT_EOF
)

# Substitute $DOSSIER_PATH (single-quoted heredoc prevented inline expansion)
PROMPT=$(printf '%s' "$PROMPT" | sed "s|\$DOSSIER_PATH|$DOSSIER|g")

"${CHANTIER_CLAUDE_BIN:-claude}" -p "$PROMPT"
```

**Notes:**
- Quoted heredoc `<<'PROMPT_EOF'` prevents shell from expanding `$DOSSIER_PATH` at heredoc time. The post-substitution is explicit (and a single sed call avoids the trap of including raw `$VAR` in argv passed to claude).
- The prompt counts ~13 prose lines, well within the 15-line budget. It contains no `claude-code` substring (the prompt is harness-agnostic by design — the adapter is what knows the harness name).
- No `--allowedTools` whitelist (deferred per CONTEXT.md; gate 4 catches leaks post-hoc).

### Pattern 5: `CHANTIER_CLAUDE_BIN` Stub for Deterministic E2E

**What:** Per D-15, the e2e test uses a ~10-line shell stub instead of the real `claude` binary. The stub simulates dispatch: `cd` to the dossier, source `env.sh`, exec `run.sh`, exit with run.sh's exit code. Also echoes one "subagent transcript" line for trace fidelity.

**When to use:** In `core/tests/adapter_claude_code_e2e.bats` setup. The real `claude` binary works in local dev when `CHANTIER_CLAUDE_BIN` is unset.

**Example:**
```bash
# Source: synthesis of D-15 (~10 lines, mimics dispatch) + Phase 3 e2e fixture pattern

# In setup():
mkdir -p "$BATS_TEST_TMPDIR/stub"
cat > "$BATS_TEST_TMPDIR/stub/claude" <<'STUB_EOF'
#!/bin/sh
# CHANTIER_CLAUDE_BIN stub — deterministic subagent emulator (Phase 4 D-15)
# Accepts -p <prompt> (positional after flag); ignores all other flags.
# Reads dossier path from the prompt's $DOSSIER_PATH substitution token.
set -eu
PROMPT=""
while [ $# -gt 0 ]; do
    case "$1" in
        -p|--print) shift; PROMPT="$1" ;;
        *) ;; # ignore all other flags (output-format, model, etc.)
    esac
    shift 2>/dev/null || true
done
# Extract dossier path from prompt (matches the post-sed substitution in adapter)
DOSSIER=$(printf '%s\n' "$PROMPT" | sed -n 's|.*\(/.*\.chantier/dossiers/[^ ]*\).*|\1|p' | head -1)
[ -n "$DOSSIER" ] || { printf 'stub: could not parse dossier path\n' >&2; exit 1; }
printf 'subagent (stub): cd %s\n' "$DOSSIER"
cd "$DOSSIER"
. ./env.sh
sh ./skill/run.sh
exit $?
STUB_EOF
chmod +x "$BATS_TEST_TMPDIR/stub/claude"
export CHANTIER_CLAUDE_BIN="$BATS_TEST_TMPDIR/stub/claude"
```

**Notes:**
- The stub ignores `--output-format`, `--model`, etc. — per CONTEXT.md Claude's Discretion, "exact ignored-flag handling is planner's call." Minimal contract: parses `-p <prompt>`.
- Echoes one trace line (`subagent (stub): cd …`) per D-15 ("plus a minimal echo of a 'subagent transcript' line for trace fidelity").
- The stub script file itself contains the substring `claude` (it IS called `claude`) — this is fine because the stub lives under `$BATS_TEST_TMPDIR`, not in the repo source tree. The adapter_isolation.bats audit scopes only to repo paths.

### Pattern 6: Path-Only NFR-001 Audit (the trap-laden one)

**What:** Per D-09/D-10/D-11/D-12, a bats test greps the source tree for the deny-list and asserts zero matches outside allowed paths. The trap: the audit script itself MUST mention the deny-list tokens to know what to forbid, so the bats file would self-trigger if naively grep'd.

**When to use:** `core/tests/adapter_isolation.bats`. The pattern is unique to this audit; do not copy verbatim elsewhere.

**Example:**
```bash
# Source: synthesis of D-09/D-10/D-11/D-12 + core/bin/chantier --self-test HARNESS_DENY_LIST_CHECK pattern (lines 907-918)

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    cd "$BATS_TEST_DIRNAME/../.."
}

@test "cross-tree NFR-001: deny-list tokens absent outside adapters/claude-code/" {
    # Audit-scope paths per D-11 (core/, skills/, tests/ — and sibling adapters/ when they exist).
    # Exempted entirely per D-11: docs/, .planning/, core/bin/chantier.
    # Carve-out per D-10: adapters/claude-code/ may contain `claude-code` and `mcp__claude_ai_`.

    # Build full deny-list (matches core/bin/chantier line 912 verbatim).
    _full='mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode'

    # Build narrower list applied INSIDE adapters/claude-code/ (drops claude-code + mcp__claude_ai_).
    _narrow='@codebase|cursor|codex-cli|copilot-cli|gemini-cli|opencode'

    _violations=""

    # Scope 1: core/ except core/bin/chantier (binary self-tests; HARNESS_DENY_LIST_CHECK markers)
    # Scope 2: skills/ except SKILL.md `harness_adapters: - claude-code` frontmatter entries
    # Scope 3: tests/ (none yet — top-level tests/ doesn't exist; placeholder for Phase 5)
    # Scope 4: adapters/*/ except adapters/claude-code/

    # Use find … -print0 | xargs -0 grep for POSIX portability (no --include needed).
    while IFS= read -r _file; do
        [ -n "$_file" ] || continue
        case "$_file" in
            core/bin/chantier) continue ;;  # has its own HARNESS_DENY_LIST_CHECK markers
            skills/*/SKILL.md)
                # Sanctioned harness_adapters entry; everything else is a violation
                if grep -vE '^[[:space:]]*-[[:space:]]*claude-code$' "$_file" | grep -qE "$_full"; then
                    _violations="${_violations}${_file}\n"
                fi
                ;;
            adapters/claude-code/*)
                if grep -qE "$_narrow" "$_file"; then
                    _violations="${_violations}${_file}\n"
                fi
                ;;
            *)
                if grep -qE "$_full" "$_file"; then
                    _violations="${_violations}${_file}\n"
                fi
                ;;
        esac
    done <<EOF
$(find core skills adapters -type f 2>/dev/null | sort)
EOF

    if [ -n "$_violations" ]; then
        printf 'adapter_isolation: deny-list violations:\n%b' "$_violations" >&2
        false
    fi
}
```

**Notes:**
- The audit script itself contains the deny-list tokens *inside string literals*. Critically, `core/tests/adapter_isolation.bats` IS under `core/tests/` and thus within the audit scope — so the script would self-trigger unless we treat it specially. Two options:
  1. **Skip-self approach:** Add `case "$_file" in core/tests/adapter_isolation.bats) continue ;;` (analogous to skipping `core/bin/chantier`).
  2. **Marker approach:** Use the same `HARNESS_DENY_LIST_CHECK` marker convention as the binary and filter with `grep -v 'HARNESS_DENY_LIST_CHECK'` before applying the deny-list grep.
- **Recommendation:** Option 2 (marker), because it's the established Phase 2 pattern and explicit. Plan should reflect this.
- The `core/bin/chantier` `--self-test` self-scan (lines 907-918) already uses option 2; the new adapter audit composes naturally with it.
- The deny-list regex is the same alternation pattern used in `core/bin/chantier` line 912 — drift between the two would be a Phase 4 defect. Recommend: keep both string-literally identical and add a Phase 4 plan note to update both in lockstep if a future harness joins the list.

### Anti-Patterns to Avoid

- **Re-implementing skill mechanics in the adapter.** The adapter never writes `output.md` / `output.json`, never re-reads `inputs.yml`, never decides what `phase: red` means. All of that belongs to `run.sh`. Phase 3 D-01/D-02/D-03 already locked this; the adapter's job is *staging + dispatch*.
- **Embedding the dispatch prompt in a separate Markdown file.** D-02 explicitly forbids this for v0.1 (sibling template file is a deferred idea). Keep the prompt inline as a quoted heredoc.
- **Calling `claude` without the `${CHANTIER_CLAUDE_BIN:-claude}` indirection.** Per D-15, the e2e MUST be deterministic and offline. Hardcoding `claude` would make the e2e require Anthropic API access (NFR-004 violation).
- **Letting the adapter write `skill.completed`.** That event is the skill's responsibility per Phase 3 D-04. The adapter writes only `task.started`, `task.completed`, `task.failed`. Three events per successful task, two per failure.
- **Auto-creating the worktree.** D-05 explicitly delegates this to the operator. Auto-creation would recreate the implicit-chaining anti-pattern ADR 0003 Principle 4 rejects.
- **Deleting the dossier on success.** D-08 preserves it for forensics. The operator (or future cleanup skill) decides when to purge.
- **`set -e` interactions with `claude` exit codes.** The adapter MUST capture `claude`'s exit code under `set +e` brackets (analog of `run.sh`'s `RED_EXIT` capture pattern, Phase 3 plan 03-03). Otherwise a non-zero claude exit would abort the adapter before the `task.failed` state append.
- **Heredoc `$VAR` expansion inside the dispatch prompt.** Use quoted heredoc `<<'EOF'` and substitute via `sed` after, to avoid the heredoc-injection residual risk Phase 3 open issue #8 flagged for `subagent-driven-development`. Untrusted dossier contents (in operator workflows) could otherwise inject shell into the prompt.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PLAN.md YAML task-block parsing | Custom YAML parser | Inline awk pattern from `core/bin/chantier` lines 530-572 | Already production-tested in 71/0 bats suite; identical grammar prevents drift between binary's `validate-task` and adapter's lookup. |
| File locking for `.chantier/dossiers/<task>/.lock` (if added) | `flock`-based mutex | `mkdir`-as-mutex with stale-PID detection (Phase 2 pattern, `core/bin/chantier` lines 82-126) | `flock(1)` is absent on macOS Darwin (ADR 0002 §"flock(1) is absent on macOS"). |
| STATE.md event emission | Direct write to JSONL file | `chantier state append` subprocess | Per ADR 0001 Surface 3 ("the append API is the only permitted way to mutate STATE.md"); the binary holds the mkdir-mutex and enforces the event-shape regex. |
| Task validation logic | Re-implementing 5 ADR 0001 gates | `chantier validate-task <task>` subprocess | The binary already implements all 5 gates with path canonicalization, schema validation, deny-list grep, acceptance substring match. Duplication would diverge. |
| Worktree creation | `git worktree add` inside adapter | Operator pre-creates per D-05 | Explicit decision; separation of concerns. |
| YAML frontmatter extraction from SKILL.md | yq/Python | The awk extractor pattern already in `core/bin/chantier` (`extract_frontmatter_as_json`) or its idioms | NFR-002 forbids yq; awk subset works for ADR 0002's frontmatter subset profile (top-level scalars + simple lists). |
| Concurrency primitive | Custom locking | `mkdir` mutex (Phase 2 pattern) — only IF dispatch concurrency is added (Claude's Discretion deferred) | Same reason as mkdir-mutex above. |
| Subagent transcript capture (if added) | Custom tee + log rotation | `claude -p … > $DOSSIER/subagent.transcript.log 2>&1` | Standard shell redirection; rotation is a v0.2+ concern. |
| Heredoc-safe `$VAR` injection | Inline `$VAR` in unquoted heredoc | Quoted heredoc + post-`sed` substitution (Pattern 4) | Phase 3 plan 03-05 found `$()` and backticks in unquoted-heredoc-interpolated values are shell-evaluated (open issue #8); same risk applies to the dispatch prompt. |

**Key insight:** The adapter is glue. Every load-bearing capability already lives in `core/bin/chantier` (events, validation, gates, deny-list, mkdir-mutex), in Phase 3 skills (`run.sh` deterministic worker), or in the OS (`git`, `awk`, `find`, `claude`). Phase 4's job is to wire them together with minimum new logic. If the adapter grows past ~200 lines of shell, the planner should suspect logic that should live elsewhere.

---

## Runtime State Inventory

> Phase 4 ships new files only — no rename, no refactor, no migration of existing data. The Runtime State Inventory is included for completeness; every category is "nothing found."

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — verified: Chantier persists state only in `.planning/STATE.md` (JSONL) and per-task `output.md`/`output.json` files (Phase 2/3 design); no databases, no Redis, no caches. The new dossiers under `$WORKTREE/.chantier/dossiers/<task>/` are *new* artifacts written by Phase 4, not pre-existing state. | None |
| Live service config | None — verified: Chantier has no external services. No n8n, no Datadog, no Cloudflare, no GitHub Actions yet. The only "service" referenced is the Anthropic `claude` CLI, and Phase 4 invokes it as a subprocess with no persistent registration. | None |
| OS-registered state | None — verified: no launchd plists, no systemd units, no Windows Task Scheduler tasks, no cron jobs, no pm2 processes. Phase 4 ships only files in the repo. | None |
| Secrets / env vars | New env vars *introduced* by Phase 4 (not renamed): `CHANTIER_TASK_ID`, `CHANTIER_PHASE`, `CHANTIER_WORKTREE` (per D-07 + ADR 0001 env.sh), plus operator-supplied `CHANTIER_CLAUDE_BIN` override (per D-15). The names are new; no existing code reads them under the same names. | None — these are new exports, declared in adapter + env.sh |
| Build artifacts / installed packages | None — Phase 4 installs nothing (Package Legitimacy Audit section confirms). No pip egg-info, no compiled binaries, no Docker images, no npm globals. | None |

**The canonical question:** "After every file in the repo is updated, what runtime systems still have the old string cached, stored, or registered?" — Answer: nothing, because Phase 4 introduces new artifacts only.

---

## Common Pitfalls

### Pitfall 1: Heredoc variable expansion in the dispatch prompt
**What goes wrong:** Unquoted heredoc `<<EOF` expands `$DOSSIER_PATH` (intentional) but also expands any `$()` or backticks present in operator-controlled context — most relevantly, in `inputs.yml` values copied into the prompt (none today, but future). Subagent receives executed shell, not the intended prompt text.
**Why it happens:** POSIX heredoc rule: only the form `<<'TOKEN'` (with quoted delimiter) disables expansion. `<<EOF` and `<<"EOF"` both expand. Phase 3 plan 03-05 hit this exact class of bug (open issue #8, `subagent-driven-development`).
**How to avoid:** Use quoted heredoc `<<'PROMPT_EOF'` for the dispatch prompt. Substitute the dossier path explicitly with a `sed` call after capture. Never include operator-controlled values in the prompt without escaping.
**Warning signs:** Subagent reports "command not found" for tokens that look like prompt prose; or worse, silently executes shell from `inputs.yml`.

### Pitfall 2: `set -e` aborts before `task.failed` state append
**What goes wrong:** Adapter has `set -eu` (POSIX safe default, matches `core/bin/chantier`). When `claude -p` exits non-zero, the shell aborts immediately — no `task.failed` event is appended, STATE.md shows only a dangling `task.started`.
**Why it happens:** `set -e` does not distinguish "this command is allowed to fail" from "this command is fatal." Phase 3 plan 03-03 hit the same trap with the TDD red step (`run.sh` brackets the test runner under `set +e` ... `set -e`).
**How to avoid:** Bracket the `claude -p` call:
```sh
set +e
"${CHANTIER_CLAUDE_BIN:-claude}" -p "$PROMPT"
CLAUDE_EXIT=$?
set -e
if [ "$CLAUDE_EXIT" -ne 0 ]; then
    chantier state append -e task.failed -t "$TASK_ID" -s "$SKILL_ID" -m "claude -p exited $CLAUDE_EXIT" -r "$DOSSIER"
    exit 2  # D-04: invocation error
fi
```
Same pattern for the `chantier validate-task` call.
**Warning signs:** STATE.md ends with `task.started` and no closing event; bats e2e fails with cryptic "test aborted" rather than a clean "validate-task red" message.

### Pitfall 3: `attempts/<n>/` number-collision under retry
**What goes wrong:** Operator runs `run-task.sh t1`, validate-task red, outputs moved to `attempts/01/`. Operator fixes, runs again, validate-task red. Adapter naively writes `attempts/01/` again, clobbering the prior attempt.
**Why it happens:** Naive `n=01` hardcoding, or wrong glob (`ls attempts/*` returns `attempts/01/` and the adapter thinks "max is 01, so use 01").
**How to avoid:** Use a glob-and-max idiom:
```sh
NEXT_N=1
for d in "$TASK_DIR"/attempts/[0-9]*; do
    [ -d "$d" ] || continue
    n=$(basename "$d" | sed 's/^0*//')  # strip leading zeros
    [ "$n" -ge "$NEXT_N" ] && NEXT_N=$((n + 1))
done
ATTEMPT_DIR=$(printf '%s/attempts/%02d' "$TASK_DIR" "$NEXT_N")
mkdir -p "$ATTEMPT_DIR"
mv "$TASK_DIR/output.md" "$TASK_DIR/output.json" "$ATTEMPT_DIR/"
```
Zero-pad width is Claude's Discretion (CONTEXT.md); `%02d` is conventional and supports up to 99 attempts comfortably.
**Warning signs:** Forensic inspection of `attempts/01/` shows files from the latest run, not the first; STATE.md `task.failed` events outnumber `attempts/` subdirectories.

### Pitfall 4: macOS BSD `find` vs GNU `find` for the audit
**What goes wrong:** Audit script uses `find … --include='*.md'` or `find … -regextype posix-extended` — GNU-only flags. Fails silently on macOS BSD with "find: --include: unknown predicate" or behavior change.
**Why it happens:** macOS ships BSD find by default. GNU find from homebrew (`gfind`) is not portable.
**How to avoid:** Stick to POSIX find flags: `-type`, `-name`, `-print`, `-print0`, `-maxdepth`/`-mindepth` (the latter two are BSD extensions but widely supported including macOS). Use `find … -type f` and pipe to a while-read loop for portable filtering. Phase 2 `core/bin/chantier --self-test` and Phase 3 `skill_uniformity.bats` already follow this pattern.
**Warning signs:** Audit passes on macOS dev, fails on Linux CI (or vice versa); silent skips of files that should have been scanned.

### Pitfall 5: `git rev-parse --is-inside-work-tree` returns true in `.git/` subdirectories
**What goes wrong:** Operator accidentally runs `run-task.sh t1` from `$WORKTREE/.git/` (or any subdirectory). `git rev-parse --is-inside-work-tree` returns `true` (which is "true" the literal text). Adapter proceeds with wrong dossier path.
**Why it happens:** `--is-inside-work-tree` answers "are we inside the work tree?" (yes for `.git/` because `.git/` lives at the work-tree root). It does NOT answer "is cwd the work-tree root?"
**How to avoid:** Use `git rev-parse --show-toplevel` to get the work-tree root, then compare to PWD:
```sh
WORKTREE=$(git rev-parse --show-toplevel 2>/dev/null) || {
    printf 'run-task: not inside a git work tree\n' >&2
    exit 2
}
# WORKTREE is now the absolute path to the work-tree root.
# Use $WORKTREE/.chantier/dossiers/<task>/ for the dossier regardless of CWD.
```
This sidesteps both the `.git/`-subdirectory edge case AND the "lax-vs-strict worktree validation" Claude's Discretion item by using the work-tree root as the canonical anchor.
**Warning signs:** Dossier appears at unexpected paths; `cd $DOSSIER` in subagent fails with "no such file or directory."

### Pitfall 6: Subprocess env inheritance interacts badly with shell quoting
**What goes wrong:** Adapter does `export CHANTIER_TASK_ID="$TASK_ID"` then `claude -p "$PROMPT"`. If `$TASK_ID` contains shell metacharacters (it shouldn't, but operator typos happen), the export succeeds but subagent reads malformed value.
**Why it happens:** `export` is safe for assignment but the variable's value is unbounded. Subagent's `. ./env.sh` re-imports the value from a file, which is safer — but if env.sh is written via unquoted heredoc, it inherits the same risk.
**How to avoid:** Validate `TASK_ID` against the YAML grammar (`[a-z][a-z0-9_-]*`) at the start of preflight. Write `env.sh` via quoted-string emission:
```sh
# Validate task ID against expected grammar
case "$TASK_ID" in
    [a-z]*) ;;
    *) printf 'run-task: invalid task id: %s\n' "$TASK_ID" >&2; exit 3 ;;
esac
case "$TASK_ID" in
    *[!a-zA-Z0-9_-]*) printf 'run-task: task id contains invalid characters\n' >&2; exit 3 ;;
esac
# Safe to embed now
cat > "$DOSSIER/env.sh" <<EOF
CHANTIER_TASK_ID="$TASK_ID"
CHANTIER_PHASE="$PHASE"
CHANTIER_WORKTREE="$WORKTREE"
export CHANTIER_TASK_ID CHANTIER_PHASE CHANTIER_WORKTREE
EOF
```
**Warning signs:** Subagent reports "syntax error in env.sh"; `chantier state append` rejects the task ID as not matching its grammar.

### Pitfall 7: `chantier state append` CWD-relative path resolution
**What goes wrong:** Adapter calls `chantier state append -e task.started …` from inside `$WORKTREE` (or worse, from inside `$DOSSIER`). The binary defines `STATE_FILE=".planning/STATE.md"` and `LOCKDIR=".planning/.chantier.lock"` as CWD-relative (`core/bin/chantier` lines 19-20). If CWD lacks `.planning/`, the binary writes a new STATE.md in the wrong place.
**Why it happens:** Phase 2 deliberately made these paths CWD-relative because skills' `run.sh` invokes `chantier state append` from arbitrary task directories. Phase 3 plan 03-02 hit this — fixed by wrapping the call in a subshell that `cd`s to project root.
**How to avoid:** Same fix Phase 3 adopted (subshell + cd):
```sh
(
    cd "$WORKTREE"  # WORKTREE is the project root for the operator's task
    chantier state append -e task.started -t "$TASK_ID" -s "$SKILL_ID" -m "..." -r "$DOSSIER"
)
```
Note: in Phase 4, `$WORKTREE` IS the project root (operator's git worktree contains a full Chantier checkout with `.planning/`). Phase 3 fix is the canonical pattern; do not invent a new one.
**Warning signs:** STATE.md events appear in unexpected paths; `state append` succeeds silently but the event is invisible to `chantier state show`.

---

## Code Examples

### Example 1: Adapter Skeleton (~120 lines, illustrative)

```sh
#!/bin/sh
# Copyright (c) 2026 Chantier Contributors
# SPDX-License-Identifier: MIT
#
# adapters/claude-code/run-task.sh — Phase 4 / FR-008
# Source: synthesis of D-01..D-16 + Phase 2 dispatch model + Phase 3 subshell-cd pattern

set -eu
IFS='
'
LC_ALL=C
export LC_ALL

# Section 1: Preflight ====================================================

# Usage
TASK_ID="${1:-}"
if [ -z "$TASK_ID" ]; then
    printf 'run-task: usage: run-task.sh <task-id>\n' >&2
    exit 3
fi

# Validate TASK_ID grammar (Pitfall 6)
case "$TASK_ID" in
    [a-z]*[!a-zA-Z0-9_-]*|*[!a-zA-Z0-9_-]*|"") 
        printf 'run-task: invalid task id: %s\n' "$TASK_ID" >&2; exit 3 ;;
esac

# Dependencies (D-04: exit 3 environment)
command -v claude  >/dev/null 2>&1 || \
    [ -n "${CHANTIER_CLAUDE_BIN:-}" ] || \
    { printf 'run-task: claude not on PATH (set CHANTIER_CLAUDE_BIN to override)\n' >&2; exit 3; }
command -v jq      >/dev/null 2>&1 || { printf 'run-task: jq not on PATH\n' >&2; exit 3; }
command -v chantier >/dev/null 2>&1 || { printf 'run-task: chantier not on PATH\n' >&2; exit 3; }

# Worktree validation (D-05) — use --show-toplevel to sidestep Pitfall 5
WORKTREE=$(git rev-parse --show-toplevel 2>/dev/null) || {
    printf 'run-task: not inside a git work tree (D-05)\n' >&2; exit 2
}
cd "$WORKTREE"

# PLAN.md lookup (Pattern 3) → resolves PLAN_PATH, PHASE, SKILL_ID
# … awk pattern from validate-task gate 1, omitted for brevity …
# (See Pattern 3 above for the full snippet.)

# Section 2: Stage dossier ================================================

DOSSIER="$WORKTREE/.chantier/dossiers/$TASK_ID"
mkdir -p "$DOSSIER/reads" "$DOSSIER/upstream" "$DOSSIER/skill"

# Write env.sh (D-07 belt-and-suspenders)
cat > "$DOSSIER/env.sh" <<EOF
CHANTIER_TASK_ID="$TASK_ID"
CHANTIER_PHASE="$PHASE"
CHANTIER_WORKTREE="$WORKTREE"
export CHANTIER_TASK_ID CHANTIER_PHASE CHANTIER_WORKTREE
EOF

# Copy inputs.yml from PLAN.md (extracted via awk earlier) → DOSSIER/inputs.yml
# Copy skill body: SKILL.md, PRESSURE.md, run.sh
cp "$WORKTREE/skills/$SKILL_ID/SKILL.md"    "$DOSSIER/skill/SKILL.md"
cp "$WORKTREE/skills/$SKILL_ID/PRESSURE.md" "$DOSSIER/skill/PRESSURE.md"
cp "$WORKTREE/skills/$SKILL_ID/run.sh"      "$DOSSIER/skill/run.sh"
chmod +x "$DOSSIER/skill/run.sh"

# Symlink state_reads into DOSSIER/reads/ (per task block's state_reads list)
# … omitted for brevity; one ln -s per state_reads entry …

# Section 3: Dispatch =====================================================

# task.started event (D-03) — subshell-cd per Pitfall 7
(cd "$WORKTREE" && chantier state append \
    -e task.started \
    -t "$TASK_ID" \
    -s "$SKILL_ID" \
    -m "dispatch via claude-code adapter" \
    -r "$DOSSIER")

# Build dispatch prompt (Pattern 4) — quoted heredoc + sed substitution
PROMPT=$(cat <<'PROMPT_EOF'
You are dispatched by the Chantier Claude Code adapter to execute one skill task.

Your working directory is the task dossier: __DOSSIER__

Do this, in order:
  1. cd "__DOSSIER__"
  2. Source env.sh: . ./env.sh
  3. Read skill/SKILL.md end-to-end. Acknowledge (in your own words) which
     Invariants listed in `## Invariants` apply to this task and why.
  4. Execute the skill: sh ./skill/run.sh
  5. Report the exit code from run.sh as your final line: "EXIT $?"

Do not invent additional steps. The discipline is in skill/SKILL.md.
Do not edit any file outside the paths declared in skill/SKILL.md state_writes.
PROMPT_EOF
)
PROMPT=$(printf '%s' "$PROMPT" | sed "s|__DOSSIER__|$DOSSIER|g")

# Export env vars for subprocess inheritance (D-07 layer 2 of triple)
export CHANTIER_TASK_ID="$TASK_ID"
export CHANTIER_PHASE="$PHASE"
export CHANTIER_WORKTREE="$WORKTREE"

# Dispatch — bracket exit-code capture per Pitfall 2
set +e
"${CHANTIER_CLAUDE_BIN:-claude}" -p "$PROMPT"
CLAUDE_EXIT=$?
set -e

if [ "$CLAUDE_EXIT" -ne 0 ]; then
    (cd "$WORKTREE" && chantier state append \
        -e task.failed -t "$TASK_ID" -s "$SKILL_ID" \
        -m "claude -p exited $CLAUDE_EXIT" -r "$DOSSIER")
    exit 2  # D-04: invocation error
fi

# Validate-task — same bracketing
set +e
chantier validate-task "$TASK_ID"
VT_EXIT=$?
set -e

TASK_DIR="$WORKTREE/.planning/phases/$PHASE/tasks/$TASK_ID"
if [ "$VT_EXIT" -ne 0 ]; then
    # Quarantine outputs to attempts/<n>/ (Pitfall 3)
    NEXT_N=1
    for d in "$TASK_DIR"/attempts/[0-9]*; do
        [ -d "$d" ] || continue
        n=$(basename "$d" | sed 's/^0*//')
        [ "$n" -ge "$NEXT_N" ] && NEXT_N=$((n + 1))
    done
    ATTEMPT_DIR=$(printf '%s/attempts/%02d' "$TASK_DIR" "$NEXT_N")
    mkdir -p "$ATTEMPT_DIR"
    [ -f "$TASK_DIR/output.md" ]   && mv "$TASK_DIR/output.md"   "$ATTEMPT_DIR/"
    [ -f "$TASK_DIR/output.json" ] && mv "$TASK_DIR/output.json" "$ATTEMPT_DIR/"

    (cd "$WORKTREE" && chantier state append \
        -e task.failed -t "$TASK_ID" -s "$SKILL_ID" \
        -m "validate-task red; outputs in attempts/$NEXT_N" -r "$ATTEMPT_DIR")
    exit 1  # D-04: contract violation
fi

(cd "$WORKTREE" && chantier state append \
    -e task.completed -t "$TASK_ID" -s "$SKILL_ID" \
    -m "claude-code adapter dispatch + validate-task green" -r "$TASK_DIR")
exit 0
```

### Example 2: E2E Test Skeleton (mirroring `skill_test_driven_development_e2e.bats`)

```bash
#!/usr/bin/env bats
# Source: synthesis of D-13/D-14/D-15 + core/tests/skill_test_driven_development_e2e.bats

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'

    export CHANTIER="$BATS_TEST_DIRNAME/../bin/chantier"
    export FIXTURES="$BATS_TEST_DIRNAME/fixtures"
    export REPO_ROOT
    REPO_ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)
    export ADAPTER="$REPO_ROOT/adapters/claude-code/run-task.sh"

    export PATH="$REPO_ROOT/core/bin:$PATH"

    mkdir -p "$BATS_TEST_TMPDIR/home"
    cd "$BATS_TEST_TMPDIR/home"
    export TMPHOME
    TMPHOME=$(pwd -P)

    # Phase 4 setup ADDS: create a real git worktree (D-05 requires it)
    git init -q "$TMPHOME"
    cd "$TMPHOME"
    git config user.email "test@chantier" && git config user.name "test"
    mkdir -p .planning/phases
    cat > .planning/STATE.md <<'EOF'
---
format_version: 0.1.0
---
EOF
    git add -A && git commit -q -m "initial"

    # Per D-05, operator pre-creates worktree. Test acts as operator.
    WORKTREE_DIR="$BATS_TEST_TMPDIR/wt"
    git worktree add -q "$WORKTREE_DIR" -b test-branch
    export WORKTREE="$WORKTREE_DIR"

    # Stub CHANTIER_CLAUDE_BIN per D-15 (Pattern 5)
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
DOSSIER=$(printf '%s\n' "$PROMPT" | sed -n 's|.*\(/.*\.chantier/dossiers/[^ "]*\).*|\1|p' | head -1)
[ -n "$DOSSIER" ] || { printf 'stub: no dossier in prompt\n' >&2; exit 1; }
printf 'subagent (stub): cd %s\n' "$DOSSIER"
cd "$DOSSIER" && . ./env.sh && sh ./skill/run.sh
exit $?
STUB_EOF
    chmod +x "$BATS_TEST_TMPDIR/stub/claude"
    export CHANTIER_CLAUDE_BIN="$BATS_TEST_TMPDIR/stub/claude"
}

@test "claude-code adapter dispatches test-driven-development red phase end-to-end" {
    TASK="t1"
    SKILL="test-driven-development"

    # Copy skill body into worktree
    mkdir -p "$WORKTREE/skills/$SKILL"
    cp "$REPO_ROOT/skills/$SKILL/SKILL.md"    "$WORKTREE/skills/$SKILL/SKILL.md"
    cp "$REPO_ROOT/skills/$SKILL/PRESSURE.md" "$WORKTREE/skills/$SKILL/PRESSURE.md"
    cp "$REPO_ROOT/skills/$SKILL/run.sh"      "$WORKTREE/skills/$SKILL/run.sh"
    chmod +x "$WORKTREE/skills/$SKILL/run.sh"

    # Build PLAN.md with inputs from the Phase 3 fixture
    # (make_plan helper lifted verbatim from skill_test_driven_development_e2e.bats)
    ACC1="A failing test was observed before any production code was written for this task."
    ACC2="After the production change, the same test command exits zero."

    mkdir -p "$WORKTREE/.planning/phases/test-phase"
    cat > "$WORKTREE/.planning/phases/test-phase/PLAN.md" <<EOF
---
plan_id: test-plan
phase: test-phase
created: 2026-05-30
status: draft
declared_skills: ["$SKILL"]
---

## Task \`$TASK\` -- adapter e2e

\`\`\`yaml
task: $TASK
skill: $SKILL
inputs:
  target_file: core/bin/chantier
  test_framework: bats
  phase: red
  test_command: "false"
state_writes:
  - ".planning/phases/test-phase/tasks/$TASK/"
depends_on: []
acceptance:
  - "$ACC1"
  - "$ACC2"
\`\`\`
EOF

    # Adapter MUST be invoked from inside the worktree (D-05)
    cd "$WORKTREE"
    run "$ADAPTER" "$TASK"

    if [ "$status" -ne 0 ]; then
        printf 'adapter output: %s\n' "$output" >&2
        printf 'state log:\n' >&2
        cat "$WORKTREE/.planning/STATE.md" >&2
    fi
    [ "$status" -eq 0 ]

    # Dossier was created
    [ -d "$WORKTREE/.chantier/dossiers/$TASK" ]
    [ -f "$WORKTREE/.chantier/dossiers/$TASK/env.sh" ]
    [ -f "$WORKTREE/.chantier/dossiers/$TASK/skill/SKILL.md" ]

    # Outputs were written by run.sh (preserved per D-08)
    TASK_DIR="$WORKTREE/.planning/phases/test-phase/tasks/$TASK"
    [ -f "$TASK_DIR/output.md" ]
    [ -f "$TASK_DIR/output.json" ]

    # D-13 measurable signals
    _red_exit=$(jq -r '.red_exit_code' "$TASK_DIR/output.json")
    [ "$_red_exit" -eq 1 ]
    run jq -e '.red_step_timestamp | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")' "$TASK_DIR/output.json"
    [ "$status" -eq 0 ]
    run jq -e '.invariants_applied | length >= 4' "$TASK_DIR/output.json"
    [ "$status" -eq 0 ]

    # D-03 three-event signal: task.started + skill.completed + task.completed
    _events=$(grep -cE '"event":"task\.started"|"event":"skill\.completed"|"event":"task\.completed"' "$WORKTREE/.planning/STATE.md")
    [ "$_events" -eq 3 ]
}
```

### Example 3: Adapter Isolation Audit (`adapter_isolation.bats`)

See Pattern 6 above for the full code. Key invariants the planner must preserve:
- HARNESS_DENY_LIST_CHECK markers on the deny-list literal lines (so the bats file does not self-trigger).
- Two-list approach: `_full` outside `adapters/claude-code/`, `_narrow` inside (which drops `claude-code` and `mcp__claude_ai_` from the forbidden set).
- POSIX `find` only (no GNU `--include`).
- Explicit exemption for `core/bin/chantier`, `.planning/`, `docs/` (already exempt by virtue of not being in the scope walk, but the planner should document this).

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Skill bodies contain harness invocations (e.g., `mcp__claude_ai_*` tool calls) | Skill bodies harness-agnostic; harness adapter is the only place harness identifiers live | ADR 0001 (Phase 1) | Skills portable across harnesses; adapter is the single point of substrate coupling |
| Subagents receive session-injected discipline (Superpowers' SessionStart hook) | Subagents read discipline from the skill body they execute (filesystem propagation, not memory) | ADR 0001 Surface 2 + obra/superpowers#237 finding | Subagents on harnesses without hooks (Codex, Gemini) work identically to those with hooks (Claude Code) |
| GSD-style 80+ commands with overlapping verbs | One verb per livrable; chaining explicit in PLAN.md (ADR 0003 Principle 4) | ADR 0003 Proposed | Reduces surface area; prevents the dette GSD accumulated organically |
| Markdown-table STATE.md (Phase 1) | JSONL STATE.md (Phase 2 / ADR 0002) | 2026-05-30 (Phase 2 ship) | Machine-parseable event log; downstream tools (adapter, validate-task) can query without ad-hoc parsing |
| flock-based concurrency primitive | mkdir-as-mutex with stale-PID detection | ADR 0002 (Phase 2) | flock(1) absent on macOS Darwin — mkdir is POSIX baseline; same safety, cross-platform |
| Markdown-table STATE.md with hardcoded format | Frontmatter `format_version: 0.1.0`, JSONL body, append-only | ADR 0002 (Phase 2) | Versioned format; future migrations have a hook |
| Thick prompt-encoded SKILL.md (GSD pattern) | Thin contract-shaped SKILL.md (ADR 0003 Principle 3, Proposed) | ADR 0003 Proposed (2026-05-30) | Skills portable across LLM model versions; prompt strategy decided by adapter+LLM, not by skill author |

**Deprecated/outdated:**
- **flock-based locking** — explicitly superseded by ADR 0002 for macOS portability. Adapter (if it adds concurrency) inherits mkdir-mutex.
- **Implicit chaining of workflow skills** — ADR 0003 Principle 4 forbids; adapter must not internally compose `using-git-worktrees` (D-05 confirms).
- **Auto-create worktree inside adapter** — explicitly rejected for v0.1 (operator-pre-creates; D-05).
- **Sibling template file for dispatch prompt** — deferred until prompt exceeds ~30 lines.

---

## Assumptions Log

> Claims tagged `[ASSUMED]` in this research that may need user confirmation before becoming locked decisions.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The dispatch prompt at ~15 lines (D-02) suffices for the subagent to read SKILL.md, acknowledge invariants, exec run.sh, and report exit — without prompt-engineering refinement | Pattern 4 (Thin Dispatch Prompt) | Real `claude -p` invocations might require additional prompt scaffolding (e.g., explicit "do not output additional commentary"); Pitfall is silent — subagent works but emits extra prose. Mitigated by D-15 stub being deterministic in tests; real-claude validation deferred to Phase 5. |
| A2 | Inline awk for PLAN.md lookup (Pattern 3) is preferable to adding `chantier task-lookup <id>` subcommand | Architectural Responsibility Map; Standard Stack §Alternatives Considered | If the v0.2 second adapter also needs lookup, the binary subcommand becomes the right factoring. Recommend planner re-evaluates if v0.2 is on near horizon. |
| A3 | Adapter isolation audit should use `HARNESS_DENY_LIST_CHECK` marker convention (Phase 2 pattern) rather than skip-self filename match | Pattern 6 (Path-Only NFR-001 Audit) | If planner picks skip-self instead, the audit is shorter but inconsistent with the binary self-test. Either works; marker is recommended for consistency. |
| A4 | `attempts/<n>/` zero-pad width of 2 digits (`%02d`) suffices for v0.1 (Pitfall 3) | Pitfall 3 | If a task ever fails >99 times in one run, the format breaks. Astronomically unlikely; 3 digits would be safer. Claude's Discretion item; planner picks. |
| A5 | The dossier `skill/` subdirectory (Pattern 2) is the right place to put the copied skill body, rather than referencing `$WORKTREE/skills/<id>/` directly from the prompt | Pattern 2 (Dossier Staging Schema) | Direct reference avoids the copy, but couples the prompt to the operator's worktree layout. Subdir keeps the dossier self-contained — favored. |
| A6 | The Phase 4 e2e can use symlinks for `reads/` and `upstream/` (ADR 0001 says "symlinks or copies") | Pattern 2 | If the e2e runs on a filesystem that disallows symlinks (rare today but Windows WSL edge cases), copies are safer. Recommendation: symlink with fallback to `cp -r` on failure. |
| A7 | The dispatch prompt's use of `__DOSSIER__` token + `sed` substitution (Pattern 4) is the canonical way to safely inject one variable into a quoted heredoc | Pattern 4 + Pitfall 1 | If `$DOSSIER` ever contains `|` or `&`, sed `s|…|…|g` breaks. Mitigated because `$DOSSIER` is a Chantier-controlled path under `.chantier/dossiers/<task-id>/` and TASK_ID is grammar-validated (Pitfall 6). Worth noting in the plan. |
| A8 | The PLAN.md task block must include an `inputs:` field that the adapter copies verbatim into `inputs.yml` (matching what skills like `test-driven-development` read) | Code Example 1 + Code Example 2 | ADR 0001 Surface 1's PLAN.md schema includes `inputs:` but PLAN.md spec is mostly free-form YAML. Plan should explicitly extract `inputs:` from the task block via awk (same pattern as state_writes) and write `inputs.yml`. |
| A9 | Existing Phase 3 fixtures (`core/tests/fixtures/skills/test-driven-development/dossier/inputs.yml`) can be reused by Phase 4's e2e as the PLAN.md task `inputs:` block | Code Example 2 (e2e) | Phase 3 e2e copies the fixture as the dossier's `inputs.yml` directly; Phase 4 e2e embeds the same scalars into the PLAN.md `inputs:` block. The mapping is straightforward but the planner should verify Phase 4's adapter correctly writes `inputs.yml` from PLAN.md `inputs:`. |
| A10 | `core/tests/skill_subagent_driven_development_e2e.bats` (Phase 3) was not consulted in detail; the test_driven_development e2e is sufficient as the structural mirror | Pattern Reference | If the subagent skill's e2e has setup nuances Phase 4's e2e should adopt, this assumption mis-prioritizes. Test_driven_development was chosen because D-13 explicitly names it; risk low. |

**If this table is empty: All claims in this research were verified or cited — no user confirmation needed.** (This table is non-empty; the planner and discuss-phase should review.)

---

## Open Questions (RESOLVED)

All five questions were resolved during planning per the recommendations below. The resolutions are also cited in `04-02-PLAN.md` (`<action>` block: "Resolves Open Questions A1-A5") and `04-03-PLAN.md` Sub-task A. This section's `(RESOLVED)` heading marker closes the §13a Dimension-11 gate.

1. **RESOLVED — capture `claude -p` stdout/stderr on real-claude path only.** Default to `> "$DOSSIER/subagent.transcript.log" 2>&1` when `CHANTIER_CLAUDE_BIN` is unset (real-claude path); skip for the deterministic stub. Single `if [ -z "${CHANTIER_CLAUDE_BIN:-}" ]; then` branch in `run-task.sh`. Cheap addition, high forensic value when debugging real LLM behavior. — Implemented in plan 04-02.

2. **RESOLVED — `task.started` event includes worktree path in refs.** `chantier state append ... -r "$WORKTREE"` adds one extra ref alongside task id and skill id. Useful for parallel-worktree forensic correlation; STATE.md size impact negligible. — Implemented in plan 04-02.

3. **RESOLVED — dispatch concurrency lock deferred to v0.2+.** CONTEXT.md's "leave out for v0.1" recommendation accepted. mkdir-mutex pattern from Phase 2 is the canonical answer when added; surface as a deferred idea in `04-SUMMARY.md` so Phase 5 dogfood can revisit if real concurrency need surfaces. — Resolved as defer; documented in plan 04-03 SUMMARY task.

4. **RESOLVED — `chantier task-lookup <id>` subcommand deferred.** Inline awk (Pattern 3, mirroring `core/bin/chantier:530-572`) works for v0.1's single adapter. If `adapters/cursor/` (v0.2+) needs the same lookup, extract then with two real callers driving the API shape. — Resolved as defer; inline awk implemented in plan 04-02.

5. **RESOLVED — lax worktree validation for v0.1.** `git rev-parse --show-toplevel` accepts both linked worktrees and the main checkout. Strict mode (reject main checkout via `git worktree list --porcelain` comparison) blocks the in-place dev loop; ROADMAP SC#3's wording ("executed in a worktree") is satisfied by the e2e setup performing `git worktree add` per D-05 — the adapter does not need to re-enforce. Document the decision in a `run-task.sh` comment citing this OQ. Revisit if Phase 5 dogfood produces a real wrong-tree incident. — Implemented in plan 04-02.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `/bin/sh` (POSIX) | Adapter scripting | ✓ | bash 3.2.57 (sh-compat mode) | — |
| `git` | Worktree validation (D-05) | ✓ | 2.50.1 (Apple Git-155) | — |
| `jq` | `chantier state append` (subprocess) | ✓ | 1.7.1-apple | — |
| `awk` (POSIX) | PLAN.md inline lookup (Pattern 3) | ✓ | system | — |
| `find` (POSIX) | `adapter_isolation.bats` scope walk | ✓ | system BSD | — |
| `claude` CLI | Real dispatch (D-01) | ✓ | 2.1.126 (Claude Code) | `CHANTIER_CLAUDE_BIN` stub (D-15) for e2e |
| `bats-core` | Phase 4 e2e + audit | ✓ | 1.13.0 | — |
| `bats-support`, `bats-assert` | Test helpers | ✓ | vendored 0.3.0 + 2.2.4 | — |
| `shellcheck` | Static analysis of adapter | ✓ | 0.11.0 | — |
| `core/bin/chantier` | `state append`, `validate-task` | ✓ | 0.1.0 | — |
| `skills/test-driven-development/` (full set) | E2E fixture (D-13) | ✓ | 1.0.0 (Phase 3 shipped) | — |
| `core/tests/fixtures/skills/test-driven-development/dossier/inputs.yml` | E2E inputs (D-13) | ✓ | Phase 3 shipped | — |
| macOS / Linux POSIX baseline | Cross-platform portability | ✓ macOS 15.7.4 | — | Linux CI also supported per Phase 2/3 design |

**Missing dependencies with no fallback:** None — every Phase 4 dependency is already present on the host (Phase 2/3 baseline).

**Missing dependencies with fallback:** None — `claude` CLI works but the e2e uses the `CHANTIER_CLAUDE_BIN` stub by design (NFR-004, D-15).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `bats-core` 1.13.0 (with vendored `bats-support` 0.3.0 + `bats-assert` 2.2.4) |
| Config file | none (bats requires none; tests discover via `core/tests/*.bats` glob) |
| Quick run command | `bats core/tests/adapter_isolation.bats core/tests/adapter_claude_code_e2e.bats` |
| Full suite command | `bats core/tests/` (composes with the 71-test suite; target after Phase 4: 73/0) |
| Phase 4 specific | `bats core/tests/adapter_*.bats` (matches just the new tests) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FR-008 | Adapter exists at `adapters/claude-code/run-task.sh` and is executable | unit | `bats core/tests/adapter_claude_code_e2e.bats` (setup asserts `[ -x "$ADAPTER" ]`) | ❌ Wave 0 (file does not exist yet) |
| FR-008 | Adapter stages dossier with `inputs.yml`, `reads/`, `upstream/`, `env.sh` per ADR 0001 Surface 2 | e2e | `bats core/tests/adapter_claude_code_e2e.bats` (asserts dossier shape after run) | ❌ Wave 0 |
| FR-008 | Adapter dispatches a Claude Code subagent that reads SKILL.md and execs run.sh | e2e | `bats core/tests/adapter_claude_code_e2e.bats` (stub emulates dispatch; real path manual-verify in Phase 5 dogfood) | ❌ Wave 0 |
| FR-008 | Adapter brackets task with `task.started` + `task.completed` events (D-03) | e2e | `grep -cE '"event":"task\.(started|completed)"' STATE.md` equals 2 for success path | ❌ Wave 0 |
| FR-008 | One e2e task invocation works (D-13, ROADMAP SC#3) | e2e | `bats core/tests/adapter_claude_code_e2e.bats` (one @test block, validate-task exits 0) | ❌ Wave 0 |
| FR-008 | NFR-001 cross-tree audit: `claude-code` and `mcp__claude_ai_` appear nowhere outside `adapters/claude-code/` (D-09, D-10, D-11, D-12) | unit | `bats core/tests/adapter_isolation.bats` (one @test block, asserts 0 violations) | ❌ Wave 0 |
| FR-008 | Adapter exit-code matrix matches D-04 (0/1/2/3) | unit | could be added as 4 @test blocks in `adapter_claude_code_e2e.bats` — recommended addition by planner | ❌ Wave 0 |
| FR-008 | Adapter is shellcheck-clean | unit | `shellcheck --shell=sh adapters/claude-code/run-task.sh` (exits 0 — Phase 3 convention) | ❌ Wave 0 |
| NFR-001 | No harness identifiers in skill bodies | (already enforced by `chantier validate-task` gate 4) | `bats core/tests/skill_*_e2e.bats` (already green) | ✓ Phase 3 |
| NFR-002 | POSIX sh + jq substrate maintained (adapter inherits per D-01) | unit | `shellcheck --shell=sh adapters/claude-code/run-task.sh` + grep for bashisms | ❌ Wave 0 |
| NFR-004 | No network access in adapter or e2e | unit | implicit: `CHANTIER_CLAUDE_BIN` stub keeps e2e offline; manual audit of `run-task.sh` for curl/wget | ❌ Wave 0 |
| NFR-005 | English-only artifacts (adapter README, run-task.sh comments, bats descriptions) | manual | code review at phase close | manual |
| NFR-006 | MIT license + collective copyright headers in new files | manual | `head -3 adapters/claude-code/run-task.sh` + `core/tests/adapter_*.bats` headers | manual |

### Sampling Rate

- **Per task commit:** `bats core/tests/adapter_*.bats` (under 5 seconds; fast feedback)
- **Per wave merge:** `bats core/tests/` (the full 73-test suite after Phase 4 lands)
- **Phase gate:** Full suite green + `shellcheck adapters/claude-code/run-task.sh` exit 0 + `chantier --self-test` "all green" + manual deny-list audit `grep -rE '<pat>' adapters/claude-code/ core/ skills/ | grep -v 'HARNESS_DENY_LIST_CHECK'` returns NOTHING

### Wave 0 Gaps

- [ ] `adapters/claude-code/` directory — create (mkdir + .gitkeep if needed)
- [ ] `adapters/claude-code/run-task.sh` — the adapter itself (~120-150 lines)
- [ ] `adapters/claude-code/README.md` — operator-facing usage (optional but recommended; English per NFR-005)
- [ ] `core/tests/adapter_isolation.bats` — NEW test (~80 lines; Pattern 6)
- [ ] `core/tests/adapter_claude_code_e2e.bats` — NEW test (~180 lines; Code Example 2)
- [ ] `core/tests/fixtures/adapter_claude_code/` — optional dedicated fixture dir (recommended NOT — reuse Phase 3 fixture inline via PLAN.md task `inputs:` per Code Example 2)

**No Wave 0 framework install needed** — bats, shellcheck, and the helper submodules are already in place.

---

## Security Domain

> Phase 4 is a shell-script adapter dispatching subprocesses on local filesystem. The threat surface is small (no network, no untrusted input from a wire format) but real (operator-controlled task IDs, future operator-controlled `inputs.yml` content). The relevant ASVS categories follow.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Not applicable — local shell tool, no auth surface in v0.1. Future v0.2+ may need consideration if `claude` requires API key handling. |
| V3 Session Management | no | No persistent sessions in the adapter. `claude -p` is stateless per invocation. |
| V4 Access Control | partial | The adapter inherits the operator's filesystem permissions. `git rev-parse --is-inside-work-tree` is the only access gate; no privilege boundary. |
| V5 Input Validation | yes | `TASK_ID` grammar validation (Pitfall 6); awk pattern for PLAN.md extraction validates YAML shape implicitly; `state_writes` path containment enforced by `chantier validate-task` gate 1. |
| V6 Cryptography | no | No crypto in v0.1. Future `claude` API key handling (deferred to v0.2) will need consideration. |
| V8 Data Protection | partial | Dossier under `$WORKTREE/.chantier/dossiers/<task>/` is preserved on success (D-08) — operator must consider whether dossier contents include sensitive data (the answer for Phase 4 e2e: no, it's all checked-in fixture data). |
| V12 File / Resource | yes | `cp` + symlink staging from `state_reads` paths — potential for symlink-following exploits if `state_reads` contains attacker-controlled paths. Mitigated because `state_reads` is declared in PLAN.md (operator-authored). |
| V14 Configuration | yes | Adapter reads `CHANTIER_CLAUDE_BIN` env var to swap the `claude` binary (D-15). If an attacker can set this env var, they can run arbitrary code in the dispatch path. Mitigated by the same "operator runs the adapter" trust model. |

### Known Threat Patterns for shell-adapter-dispatching-subprocess stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Shell injection via TASK_ID (e.g., `t1; rm -rf ~`) | Tampering / Elevation | Grammar validation at preflight; only `[a-z][a-zA-Z0-9_-]*` accepted (Pitfall 6). |
| Heredoc-injection via operator-controlled `inputs.yml` content into dispatch prompt | Tampering | Quoted heredoc `<<'EOF'` + explicit `sed` substitution; no `$()` or backticks ever evaluated from operator data (Pattern 4 + Pitfall 1). Phase 3 open issue #8 documents the same risk class for `subagent-driven-development`. |
| Symlink traversal in `state_reads` symlinking (`reads/PROJECT.md → ../../../etc/passwd`) | Information disclosure | `chantier validate-task` gate 1 enforces path containment (canonicalized via `cd && pwd -P`); symlinks resolve before the check; out-of-root paths fail. |
| `CHANTIER_CLAUDE_BIN` env var hijack (attacker sets to malicious binary) | Elevation of privilege | Adapter inherits the operator's process env; operator trust assumption. Documented in plan as a known limitation (matches `claude` CLI's own threat model). |
| `attempts/<n>/` directory race (two parallel runs collide) | Denial of service | Adapter is single-task per invocation; parallel dispatch is deferred (CONTEXT.md). If added, mkdir-mutex (Phase 2 pattern) is the recommended fix. |
| Cross-harness identifier leak (`cursor`, `codex-cli`, etc.) inside `adapters/claude-code/` | Compliance | `adapter_isolation.bats` audit (D-09–D-12) static-check enforces the path-only carve-out (D-10). |
| TOCTOU on `git rev-parse --is-inside-work-tree` (operator moves out of worktree between check and dispatch) | Tampering | Accepted limitation; the adapter is single-threaded and short-running; window is microseconds. Documented in plan. |
| Subagent ignores discipline, modifies files outside `state_writes` | Tampering | `chantier validate-task` gate 1 catches at validation time; `attempts/<n>/` quarantine preserves evidence; STATE.md `task.failed` event is durable. |
| Subagent leaks harness identifier into `output.md` / `output.json` | Compliance | `chantier validate-task` gate 4 deny-list grep catches; D-04 routes to exit 1 + `attempts/<n>/`. |

---

## Sources

### Primary (HIGH confidence — verified directly in this session)

- **Local Chantier repo files** (read in full or in relevant ranges this session):
  - `.planning/phases/04-claude-code-adapter/04-CONTEXT.md` — D-01 through D-16, Claude's Discretion items, deferred ideas
  - `.planning/REQUIREMENTS.md` — FR-008, NFR-001/002/004/005
  - `.planning/STATE.md` — Phase 3 close + Phase 4 context-gathered events
  - `.planning/ROADMAP.md` — Phase 4 success criteria 1-4
  - `.planning/config.json` — workflow toggles (research_phase: true, parallelization disabled)
  - `docs/adr/0001-state-skill-contract.md` — Surface 1/2/3, validation gates, §"Subagent dispatch is safe"
  - `docs/adr/0002-runtime-binary-and-state-format.md` — deny-list (line `mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode`), exit matrix, event-name regex, JSONL format, mkdir-mutex pattern
  - `docs/adr/0003-workflow-skill-design-principles.md` — Principles 1-4, Proposed status, ratification path
  - `docs/research/inheritance-map.md` §6 — subagent + worktrees + #237 caveat
  - `core/bin/chantier` lines 1-50, 82-126, 450-572, 650-712, 855-930 — preflight, mkdir-mutex, validate-task lookup awk, gate 4 deny-list, self-test deny-list with HARNESS_DENY_LIST_CHECK marker
  - `core/schemas/skill.json` — harness_adapters enum
  - `core/tests/skill_test_driven_development_e2e.bats` — full test (D-14 mirror target)
  - `core/tests/skill_uniformity.bats` — POSIX find pattern, cross-skill audit precedent
  - `core/tests/fixtures/skills/test-driven-development/dossier/inputs.yml` — deterministic red-phase fixture (D-13)
  - `skills/test-driven-development/SKILL.md` and `run.sh` — what subagent reads + execs
  - `.planning/phases/02-runtime-core/02-CONTEXT.md` and `.planning/phases/03-skill-library/03-CONTEXT.md` — prior phase decisions still load-bearing
  - `.planning/phases/03-skill-library/03-SUMMARY.md` — §"Note for Phase 4" handoff
- **Direct CLI probes (this session):**
  - `claude --version` → 2.1.126; `claude --help` → confirmed `-p` / `--print`, `--output-format text|json|stream-json`, positional `[prompt]`, `--system-prompt`, etc.
  - `jq --version` → 1.7.1-apple
  - `git --version` → 2.50.1 (Apple Git-155)
  - `bats --version` → 1.13.0
  - `shellcheck --version` → 0.11.0
  - `sw_vers` → macOS 15.7.4
  - `git worktree list` → `/Users/alexislegrand/Code et Dev/Chantier  e1fbb4d [main]`

### Secondary (MEDIUM confidence — cross-referenced but not exhaustively verified)

- ADR 0001 §"Subagent dispatch is safe" framing — confirmed by re-reading; the framing phrase "a plain shell script that wraps an LLM call" is cited verbatim in D-01.
- `core/bin/chantier --self-test` HARNESS_DENY_LIST_CHECK marker pattern — confirmed at lines 907-918; the pattern is the recommended (Pattern 6) approach for `adapter_isolation.bats`.

### Tertiary (LOW confidence — would benefit from real-claude dogfood validation in Phase 5)

- Assumption A1 (~15-line prompt sufficient): based on D-02's locked decision and ADR 0003 Principle 3, but real-claude behavior not exercised in this phase (only stub).
- Assumption A7 (`__DOSSIER__` token + `sed` substitution): pattern is correct for the current use case; edge cases with special chars in `$DOSSIER` documented but not stress-tested.
- Subagent prompt heredoc wording (Claude's Discretion): the example in Pattern 4 is a draft; planner authors the final wording.

---

## Metadata

**Confidence breakdown:**

- **Standard stack:** HIGH — all dependencies verified on the host this session with version output; no new packages needed.
- **Architecture (Patterns 1-6):** HIGH — every pattern grounded in existing Phase 2/3 code; D-01 through D-16 explicitly map to a pattern.
- **Pitfalls:** HIGH — all 7 pitfalls grounded in prior-phase auto-fixes (Phase 2 plan 02-04 `set -e` boundaries; Phase 3 plan 03-02 subshell-cd; Phase 3 plan 03-03 grep-c TAP-line counter; Phase 3 plan 03-05 heredoc-injection residual risk).
- **NFR-001 audit (Pattern 6):** MEDIUM — the marker-vs-skip-self decision is documented and recommended, but planner finalizes.
- **Validation Architecture:** HIGH — composition with existing 71-test bats suite is mechanical; failure modes for each Wave 0 gap are deterministic.
- **Security Domain:** MEDIUM — applicable threats catalogued; mitigations exist for all but the trust-the-operator items (which are explicitly accepted limitations consistent with Chantier's local-tool posture).
- **Open Questions:** HIGH — each has a recommendation grounded in CONTEXT.md or prior-phase patterns.

**Research date:** 2026-05-30
**Valid until:** 2026-06-13 (14 days; the `claude` CLI changes monthly and could shift the `-p` contract; Phase 2/3 prior-phase decisions are stable).
