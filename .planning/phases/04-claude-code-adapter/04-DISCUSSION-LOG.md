# Phase 4: Claude Code adapter - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-30
**Phase:** 4-Claude Code adapter
**Areas discussed:** Dispatch mechanism, Worktree integration, NFR-001 carve-out, E2E proof shape

---

## Gray area selection

| Area | Selected |
|------|----------|
| Dispatch mechanism | ✓ |
| Worktree integration | ✓ |
| NFR-001 carve-out | ✓ |
| E2E proof shape | ✓ |

User selected all four areas — no skips.

---

## Dispatch mechanism

### Q1 — Dispatch model

| Option | Description | Selected |
|--------|-------------|----------|
| `claude -p` headless | Adapter shell-out to `claude -p "<prompt>"` per task ; real Claude subprocess subagent isolation ; aligns ADR 0001 "plain shell script that wraps an LLM call" ; adapter stays POSIX sh | ✓ |
| Agent SDK programmatique | Python/TS Claude Agent SDK ; more power (streaming, fine control) ; adds Python/Node to adapter substrate | |
| Pas de subagent (exec direct) | `run-task.sh` stages dossier and `exec sh run.sh` ; no Claude subprocess ; deviates from ROADMAP SC#2 and re-opens the #237 failure mode | |
| Task-tool délégué au parent | Adapter stages + writes dispatch packet ; parent Claude invokes Task tool to spawn subagent ; couples adapter to interactive parent (won't run in CI / standalone scripts) | |

**User's choice:** `claude -p` headless (Recommended).

### Q2 — Prompt assembly

| Option | Description | Selected |
|--------|-------------|----------|
| Prompt minimal inline | ~15-line heredoc in `run-task.sh` pointing the subagent at SKILL.md ; aligns ADR 0003 Principle 3 "thin skill / smart LLM" | ✓ |
| Template sibling file | `adapters/claude-code/subagent.prompt.md` with placeholders ; separable, testable, but adds an artifact + shell templating | |
| SKILL.md seul (zero adapter prompt) | `cat SKILL.md \| claude -p` ; puriste, but SKILL.md is discipline-prose, not machine-instruction | |
| Prompt + tool restrictions strict | Minimal prompt + `--allowedTools` whitelist ; more guard-rails, but couples to Claude Code CLI flags (volatile) | |

**User's choice:** Prompt minimal inline (Recommended).

### Q3 — STATE.md events from the adapter

| Option | Description | Selected |
|--------|-------------|----------|
| `task.started` + `task.completed/failed` | Adapter brackets ; skill keeps its `skill.completed` ; three events per task | ✓ |
| Rien — trust le skill | Only `skill.completed` from `run.sh` ; loses dispatch-failure trace | |
| `task.dispatched` + `task.validated` | New verbs more semantically precise ; adds taxonomy entries | |
| `task.completed` seulement | Single closing event ; loses "started but didn't finish" signal | |

**User's choice:** `task.started` + `task.completed/failed` (Recommended).

### Q4 — Failure semantics

| Option | Description | Selected |
|--------|-------------|----------|
| Matrix 0/1/2/3 + `attempts/<n>/` | Mirror binary matrix ; quarantine red outputs ; aligns ADR 0001 "re-runnable error" | ✓ |
| Propagation simple | Adapter exit = max(claude exit, validate-task exit) ; no attempts mechanism ; re-run overwrites | |
| Verdict file always exit 0 | Adapter exit 0, verdict in `output.md` ; breaks shell conventions | |
| Pas d'attempts en v0.1 | Matrix 0/1/2/3 without `attempts/<n>/` ; minimaliste | |

**User's choice:** Matrix 0/1/2/3 + `attempts/<n>/` (Recommended).

---

## Worktree integration

### Q1 — Worktree responsibility

| Option | Description | Selected |
|--------|-------------|----------|
| Opérateur pré-crée | Caller does `git worktree add` ; adapter validates `git rev-parse --is-inside-work-tree` ; clean separation from `using-git-worktrees` skill | ✓ |
| Adapter crée si manquant | `run-task.sh` does `git worktree add` if not in worktree ; duplicates skill logic ; cleanup unclear | |
| Compose `using-git-worktrees` | Adapter invokes the skill as pre-task ; violates ADR 0003 (Proposed) Principle 4 ; chicken-and-egg if main task IS using-git-worktrees | |
| Worktree-agnostique | No CHANTIER_WORKTREE ; ignores ROADMAP SC#3 | |

**User's choice:** Opérateur pré-crée (Recommended).

### Q2 — Dossier path resolution

| Option | Description | Selected |
|--------|-------------|----------|
| Dans le worktree | `$WORKTREE/.chantier/dossiers/<task>/` ; self-contained per worktree, parallel-safe, atomic cleanup | ✓ |
| Dans le repo principal | `$REPO_ROOT/.chantier/dossiers/<task>/` ; shared across worktrees, but parallel-conflict-prone | |
| Sous `phases/N/tasks/<task>/` | Co-located with output.md/output.json ; deviates from `.chantier/dossiers/` canonical name | |

**User's choice:** Dans le worktree (Recommended).

### Q3 — env.sh contract

| Option | Description | Selected |
|--------|-------------|----------|
| Belt-and-suspenders | Adapter writes env.sh + exports vars + subagent sources ; triple safety ; zero Phase 3 patching | ✓ |
| Subagent source uniquement | env.sh load-bearing ; subagent forgetting to source = empty env | |
| env.sh documentation only | Vars live in run-task.sh process ; nobody sources env.sh ; can drift from reality | |
| Skills sourcent eux-mêmes | Patch Phase 3 skills' run.sh ; risk breaking 71 green bats tests | |

**User's choice:** Belt-and-suspenders (Recommended).

### Q4 — Dossier preservation after success

| Option | Description | Selected |
|--------|-------------|----------|
| Préservé | Operator decides when to purge ; forensic inspection days later ; symmetric with `attempts/<n>/` | ✓ |
| Supprimé sur succès | `rm -rf .chantier/dossiers/<task>/` after green ; cleaner but loses post-success forensics | |
| Move to `phases/N/tasks/<task>/dossier-archive/` | New path schema ; adds state_writes entry | |

**User's choice:** Préservé (Recommended).

---

## NFR-001 carve-out

### Q1 — Audit mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Bats audit, path-only exemption | New `core/tests/adapter_isolation.bats` ; composable with Phase 2/3 grep pattern | ✓ |
| Subcommand `chantier audit-adapters` | New binary subcommand ; redundant with bats tests ; adds to core that must stay slim | |
| Marker file `.harness-exempt` | Declarative marker file ; more explicit but adds mechanism to maintain | |
| Documentation seule | README explains the rule ; no automated check ; fails SC#4 "verified by grep" | |

**User's choice:** Bats audit, path-only exemption (Recommended).

### Q2 — Audit scope inside the adapter

| Option | Description | Selected |
|--------|-------------|----------|
| `claude-code` + `mcp__claude_ai_` exempts | Both allowed inside `adapters/claude-code/` ; other harness names still forbidden ; cross-adapter pollution check | ✓ |
| `claude-code` seul exempté | Adapter cannot use MCP tools by name ; strictest ; compatible with `claude -p`-only dispatch | |
| Rien interdit dans l'adapter | Full path-skip ; allows cross-contamination by accident | |
| Whitelist explicite par fichier | `IDENTIFIERS.allow.txt` per-adapter ; explicit but adds maintenance | |

**User's choice:** `claude-code` + `mcp__claude_ai_` exempts (Recommended).

### Q3 — Audit path scope

| Option | Description | Selected |
|--------|-------------|----------|
| `core/` + `skills/` + `tests/` + other `adapters/` | Source/test code only ; docs and .planning exempt ; binary keeps its own marker | ✓ |
| Tout sauf `adapters/claude-code/` and `docs/` | Includes `.planning/STATE.md` and binary ; requires cleaning STATE.md and keeping marker distinct | |
| Per-line marker comment | `# CHANTIER_HARNESS_OK: claude-code` ; granular but adds noise | |
| Only `.sh` and `.md` in source | Skips JSON / YAML / fixtures ; arbitrary surface | |

**User's choice:** `core/` + `skills/` + `tests/` + other `adapters/` (Recommended).

---

## E2E proof shape

### Q1 — Skill exercised in the e2e

| Option | Description | Selected |
|--------|-------------|----------|
| test-driven-development | Deterministic red-phase fixture (`test_command: "false"`) ; measurable outputs (red_step_timestamp, red_exit_code) ; Phase 3 e2e mirror | ✓ |
| using-git-worktrees | Double-worktree case interesting but adds complexity to first e2e | |
| requesting-code-review | Simplest body but harder fixture (needs git diff) | |
| Les quatre (matrice) | 4× scope for v0.1 ; Phase 5 dogfood covers matrix naturally | |

**User's choice:** test-driven-development (Recommended).

### Q2 — Test location

| Option | Description | Selected |
|--------|-------------|----------|
| `core/tests/adapter_claude_code_e2e.bats` | Composes with existing bats suite ; same loaders/helpers as skill e2e ; `adapter_<harness>_e2e.bats` pattern | ✓ |
| `adapters/claude-code/tests/e2e.bats` | Co-located with adapter ; new test location to document ; CI must discover multiple roots | |
| `tests/e2e/` (root) | Reserved for Phase 5 integration test ; encroachment | |
| `run-task.sh --self-test` | Independent of bats ; doubles test effort, loses CI integration | |

**User's choice:** `core/tests/adapter_claude_code_e2e.bats` (Recommended).

### Q3 — `claude` binary dependency

| Option | Description | Selected |
|--------|-------------|----------|
| Stub script via `CHANTIER_CLAUDE_BIN` | ~10-line stub script ; deterministic, offline, NFR-004-safe ; real `claude` when var unset | ✓ |
| Skip-if-missing | `command -v claude \|\| skip` ; CI without claude skips ; loses continuous guarantee | |
| Hard require `claude` | Test fails without claude ; NFR-004 violation if real API call | |
| Staging-only unit test | No dispatch tested ; SC#3 not mechanically verified | |

**User's choice:** Stub script via `CHANTIER_CLAUDE_BIN` (Recommended).

### Q4 — CLI shape

| Option | Description | Selected |
|--------|-------------|----------|
| `run-task.sh <task-id>` | Symmetric with `chantier validate-task <task>` ; auto plan-lookup | ✓ |
| `run-task.sh <plan-path> <task-id>` positional | Two args explicit ; no lookup ambiguity ; more verbose | |
| `run-task.sh --plan PATH --task ID` flags | Future-proof ; boilerplate for common case | |
| `run-task.sh <dossier-path>` | Separates stage/dispatch ; pushes staging to operator (against ADR 0001) | |

**User's choice:** `run-task.sh <task-id>` (Recommended).

---

## Claude's Discretion

See CONTEXT.md `<decisions>` §"Claude's Discretion" for the full list. Items the user explicitly left to planner / researcher:

- Subagent transcript persistence — capture `claude -p` stdout/stderr to `subagent.transcript.log` ?
- PLAN.md task lookup mechanics — reuse a (new?) `chantier task-lookup` subcommand or inline walk
- Stub script invocation contract — exact arg/flag handling of `CHANTIER_CLAUDE_BIN` stub
- Worktree validation strictness — refuse main checkout too, or accept any worktree
- Audit shell syntax — POSIX-portable grep invocation in `adapter_isolation.bats`
- `task.started` event payload — refs include worktree path ?
- `attempts/<n>/` numbering — zero-pad width
- Subagent prompt heredoc wording — exact prose within ~15-line budget
- Dispatch concurrency — mkdir-mutex on `.chantier/dossiers/<task>/.lock` ?
- `output.md` Acceptance pass-through — already handled by skill `run.sh`

---

## Deferred Ideas

Ideas mentioned during discussion but explicitly noted for future phases:

- Second harness adapter (`adapters/cursor/` etc.) — v0.2.0
- `tests/e2e/` full integration test — Phase 5
- Real `claude` API call in CI — NFR-004 + v0.2+
- `--allowedTools` lockdown on the subagent — revisit if leaks
- Sibling template file for the dispatch prompt — promote if heredoc grows
- Subagent transcript capture (`subagent.transcript.log`) — planner discretion
- `chantier task-lookup` subcommand — planner discretion
- Concurrent task dispatch safety — single-task is enough for v0.1
- Composition of `using-git-worktrees` as a pre-task — rejected, re-open only if dogfood signals
- `run-task.sh` flag-based options — emerge if needed in v0.2
- Strict-vs-lax worktree validation — planner discretion
- `extract-skills-from-phase` — already deferred to v0.3.0
- ADR 0003 ratification — Phase 5 dogfood feedback
- `STATE.md` compaction — Phase 5 dogfood feedback
