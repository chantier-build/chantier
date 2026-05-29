# ADR 0001 — The State / Skill Contract

- **Status:** Proposed
- **Date:** 2026-05-29
- **Deciders:** Chantier founding contributors
- **Supersedes:** —
- **Superseded by:** —

> Chantier exists because the GSD tradition holds the macro state but ignores micro discipline, while the Superpowers tradition holds the micro discipline but loses cross-session continuity. This ADR defines the **single contract** that lets a state machine and a skill library talk to each other without coupling, while remaining portable across AI coding harnesses (Claude Code, Cursor, Codex, Copilot CLI, Gemini CLI, OpenCode, etc.).
>
> This is the founding architectural decision of Chantier. Every later ADR builds on it.

---

## Context

Inheritance map (`docs/research/inheritance-map.md`) records three findings that force this ADR:

1. **State must be filesystem-native.** GSD already proves multi-week continuity is possible when `PROJECT.md`, `ROADMAP.md`, `STATE.md`, and `phases/N/` live on disk and survive session boundaries. Any state mechanism that lives in conversation memory cannot serve resumed sessions or fresh subagents.

2. **Skill bodies must be substrate-portable.** Superpowers' six-harness reach is achieved because `skills/<name>/SKILL.md` is pure Markdown + Shell with no harness-specific code. The moment a skill calls a harness-specific tool by name (`mcp__claude_ai_xxx`, Cursor's `@codebase`, etc.), portability dies.

3. **Subagents do not see session-injected context.** Superpowers issue [#237](https://github.com/obra/superpowers/issues/237) documents that subagents miss the `SessionStart`-injected discipline framework and "rationalize skipping TDD." Any contract that depends on hook injection is broken-by-design for the subagent case and unimplementable on harnesses without a hook system.

These three findings rule out: in-memory state, harness-coupled skills, and hook-propagated discipline. What remains is a **file-readable, file-writable, harness-agnostic** contract.

A second pressure: GSD's filenames carry meaning (`phases/01-auth/01-02-PLAN.md`). The brief flags this as fragile — a typo in a directory name silently breaks the loader. Chantier must treat filenames as **hints for humans**, never as the canonical identifier read by tools.

---

## Decision

Chantier defines one contract with three surfaces. All three are file-based, all three are inspectable with `cat` / `jq` / `grep`, and all three are written by the same agents that read them.

### Surface 1 — How a `PLAN.md` declares the skills it will invoke

`PLAN.md` is a Markdown document with a YAML front-matter header and a structured task list. Each task is a YAML block fenced under a heading. The canonical task identifier lives **inside** the block, not in any filename.

```markdown
---
plan_id: 02-auth-foundation
phase: 02-auth
created: 2026-05-29
declared_skills:
  - test-driven-development
  - using-git-worktrees
  - requesting-code-review
---

# Plan: Auth foundation

## Task `t1` — Define User schema

```yaml
task: t1
skill: skills/scaffolding/define-domain-model
inputs:
  model_name: User
  fields:
    - { name: id, type: uuid, primary: true }
    - { name: email, type: string, unique: true }
state_reads:
  - .planning/PROJECT.md
  - .planning/REQUIREMENTS.md
state_writes:
  - .planning/phases/02-auth/tasks/t1/
depends_on: []
acceptance:
  - "User model file exists at src/domain/user.ts"
  - "Unit test for User schema exists and passes"
```
````

**Invariants:**

- `task` is the canonical identifier within the plan. The file `phases/02-auth/02-01-PLAN.md` could be renamed to `auth-foundation.md` without changing any agent's behavior, because lookups read the YAML, not the path.
- `skill` is a path (or registry ID) pointing to a `SKILL.md`. If absent, the task is "inline" and the executor handles it without a skill (rare; for trivial glue).
- `declared_skills` (in front-matter) is a redundant listing of every skill referenced in the plan. Planners write it; verifiers can sanity-check it.
- `state_reads` and `state_writes` are file paths relative to the repository root. **They are the contract.** Any skill execution that reads outside `state_reads` or writes outside `state_writes` is a contract violation and the executor must reject the result.

### Surface 2 — How a skill accesses current state

A skill is a directory `skills/<name>/` containing at minimum:

```
skills/<name>/
├── SKILL.md         # frontmatter + body (Markdown)
├── PRESSURE.md      # adversarial scenarios this skill survives (per inheritance map §9)
└── run.sh           # optional; the shell entry point if the skill needs side effects
```

`SKILL.md` front-matter declares the skill's contract:

```yaml
---
id: test-driven-development
version: 1.0.0
inputs_schema:
  required: [target_file, test_framework]
  optional: [coverage_target]
state_reads:
  - "{phase}/CONTEXT.md"
  - "{phase}/tasks/{depends_on}/output.json"
state_writes:
  - "{phase}/tasks/{task}/"
  - ".planning/STATE.md"      # append-only event log only
outputs_schema:
  output_md: "human-readable summary"
  output_json: "{ tests_added: int, coverage_delta: float }"
portable: true                 # body uses no harness-specific tool
harness_adapters:
  - claude-code
  - cursor
  - codex-cli
  - copilot-cli
  - gemini-cli
  - opencode
---
```

**How the skill actually reads state:**

The executor stages a **dossier** under a known working directory before invoking the skill body. The dossier contains:

```
.chantier/dossiers/<task>/
├── inputs.yml          # the YAML `inputs` block from PLAN.md, copied verbatim
├── reads/              # symlinks (or copies) of every path in `state_reads`
│   ├── PROJECT.md
│   ├── REQUIREMENTS.md
│   └── ...
├── upstream/           # outputs of every task listed in `depends_on`
│   └── t0/output.json
└── env.sh              # exports CHANTIER_TASK_ID, CHANTIER_PHASE, CHANTIER_WORKTREE
```

The skill body opens files in `./reads/`, `./upstream/`, and `./inputs.yml`. **It never reaches into conversation memory, session context, or any harness-specific store.** This makes the same skill body executable by Claude Code, by a Codex subagent, by a Cursor agent, or by a plain shell script that wraps an LLM call — because all of them can read files.

When the host harness can't naturally stage the dossier, the **harness adapter** (`adapters/<harness>/run-task.sh`) does the staging. The adapter is the only harness-specific code in the framework; the skill is invariant.

### Surface 3 — How a skill records its output in state

The skill writes into the paths it declared in `state_writes`. Two formats are mandatory; a third is opt-in.

**Mandatory: `output.md`** — human-readable summary, used by `/chantier verify` and read by the next planner.

**Mandatory: `output.json`** — machine-readable result, consumed by downstream tasks whose `depends_on` includes this task. The schema is whatever the skill declared in `outputs_schema`.

**Optional: append to `.planning/STATE.md`** — through a single, controlled append-only API:

```bash
chantier state append \
  --event "task.completed" \
  --task "t1" \
  --skill "test-driven-development" \
  --summary "User schema defined, 3 tests added"
```

The append API is the *only* permitted way to mutate `STATE.md`. Direct edits to `STATE.md` from inside a skill are a contract violation. This keeps the decision log auditable: every line in `STATE.md` is timestamped, attributed, and recoverable.

`chantier state append` is implemented as a portable shell command (POSIX `sh` + `jq`), checked into the repo as `core/bin/chantier`. Harness adapters do not reimplement it — they invoke it.

### Validation gate

Before an executor accepts a skill's output as "done", it runs `chantier validate-task <task>` which checks:

1. Every path the skill wrote to is inside `state_writes`.
2. `output.md` exists and is non-empty.
3. `output.json` matches `outputs_schema`.
4. If the skill declared `portable: true`, no file it wrote contains a harness-specific identifier (a portable enforcement grep).
5. Acceptance criteria from `PLAN.md` are present in `output.md`'s "Acceptance" section.

A failed validation is a re-runnable error, not a destructive one. Outputs are kept under `phases/N/tasks/<task>/attempts/<n>/` for forensics.

---

## Consequences

### Positive

- **Resumability is automatic.** Any agent picking up an in-flight phase reads `STATE.md`, finds the last completed task, reads its `output.json`, and continues. No session memory required.
- **Subagent dispatch is safe.** A subagent receives only its dossier and the skill body; both are file paths. The Superpowers #237 failure mode (subagent rationalizing skipped TDD because it never saw the discipline frame) cannot occur, because the discipline is *in the skill body the subagent must read to execute its task.*
- **Harness migration is one adapter.** Porting Chantier to a new harness means writing one `adapters/<new-harness>/run-task.sh` that stages dossiers the way that harness expects. Skill bodies do not change.
- **Filenames stop being load-bearing.** A directory rename never breaks a lookup, because lookups read YAML identifiers.
- **Audit trail is real.** `STATE.md` is append-only; every line is timestamped and attributed.

### Negative / costs

- **More upfront ceremony per skill.** A skill author cannot write `// TODO: read whatever I need`. They must declare `state_reads` and stick to it. This is the price of portability and subagent safety.
- **Dossier staging has a per-task overhead.** Symlinks or copies are cheap, but for plans with hundreds of trivial tasks the framework will feel heavier than "just run the LLM."
- **JSON schema drift risk.** `outputs_schema` is a place where skill authors can make breaking changes invisibly. We will need a `skill version` discipline (semver in `SKILL.md` front-matter) and a regression suite.
- **`STATE.md` append-only means it grows unboundedly.** Real projects will eventually want compaction. Out of scope for this ADR; flagged for ADR-0004 or later.
- **`chantier` core binary becomes a load-bearing dependency.** If `core/bin/chantier` has a bug, the whole framework wobbles. Mitigation: keep it small, POSIX-only, heavily tested.

### Neutral / deferred

- **Hooks are still allowed**, but only as *optimizations*, never as the only path. A harness with hooks can pre-stage dossiers more cleanly; a harness without hooks falls back to the explicit shell adapter. Both paths are first-class.
- **Auto-invocation of skills** (Superpowers-style "if you have a skill, use it") is harness-dependent and lives outside this contract. The contract handles explicit invocation; auto-invocation is layered on top by harness adapters that wish to support it.

---

## Alternatives considered

### A. State injected via SessionStart hook (Superpowers' approach)

**Rejected.** Documented in Superpowers #237 to break for subagents; structurally unimplementable on harnesses without a hook system (a Codex CLI without `SessionStart` cannot do this). Adopting it would either fork the framework per-harness or accept that subagents skip discipline. Both unacceptable.

### B. Conversation-memory state (the agent "remembers" the project)

**Rejected.** A resumed session next week reads zero of last week's conversation. A fresh subagent reads zero of the parent's conversation. This is the exact failure GSD already solved with `.planning/`; backsliding here would erase the project's reason for existing.

### C. Database-backed state (SQLite, key-value store)

**Rejected for v0.** Filesystem is the most portable substrate available — every harness can read files, not every harness can shell out to `sqlite3` reliably. SQLite is a tempting v2 cache layer for very large projects (compacting `STATE.md`, indexing skill outputs), but premature today. Filesystem files in Markdown / JSON / YAML are diffable, grepable, and human-readable; that wins by default.

### D. Implicit naming-convention contracts (GSD's `N-MM-PLAN.md` pattern as load-bearing)

**Rejected.** The brief explicitly flags this as fragile. We keep zero-padded names as readable hints, never as the source of truth. Lookups go through YAML identifiers.

### E. Per-harness embedded contracts (one schema for Claude, one for Cursor, ...)

**Rejected.** This is the road to becoming "yet another Claude Code framework that someone forked for Cursor." Superpowers proved one body across six harnesses is achievable. Chantier inherits that goal and refuses to compromise it.

### F. No `state_reads`/`state_writes` declarations, trust the skill body

**Rejected.** Without explicit declarations, the validator cannot enforce containment, the planner cannot reason about parallelism (two tasks with disjoint `state_writes` are parallel-safe; that's not knowable from skill bodies), and the human reader cannot audit the blast radius. The ceremony cost is real but lower than the cost of accidentally racing two skills onto the same `STATE.md` line.

---

## Open questions (intentionally deferred)

1. **Versioning skills across breaking changes.** Semver in front-matter is the obvious answer, but who pins versions in `PLAN.md`? Probably a `chantier lock` file. Deferred to a later ADR.
2. **`STATE.md` compaction.** When does append-only become unmanageable? At what threshold do we cut a milestone-end snapshot? Deferred.
3. **Inputs validation.** `inputs_schema` is declared but who enforces it? Could be JSON Schema with `ajv` shelled out; could be looser. Deferred until we have three concrete skills.
4. **Composition syntax.** Can a skill invoke another skill? If yes, how does that interact with the dossier model? Likely yes-via-subtasks, but designing the syntax is premature.

---

## Approval

This ADR is the **point of no return** the brief identifies. Once accepted, every later ADR must justify any divergence from these surfaces. No code that resembles runtime should be written until a human has signed off.

- [ ] Approved by: ___________________
- [ ] Date: ___________________
