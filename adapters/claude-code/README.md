# Claude Code adapter

This directory ships the Chantier harness adapter for the Claude Code subagent
runtime. Given a task ID, `run-task.sh` stages a Surface 2 dossier inside the
operator's pre-created git worktree (per ADR 0001), dispatches a headless
`claude -p` subagent (or a deterministic stub via `CHANTIER_CLAUDE_BIN`) to
read the skill body and exec its `run.sh`, then routes the result through
`chantier validate-task` with the full ADR 0002 exit-code matrix wired.

## Usage

```sh
adapters/claude-code/run-task.sh <task-id>
```

Single positional argument. The adapter discovers the plan by walking
`.planning/phases/*/PLAN.md` for the YAML task block whose `task:` field
matches `<task-id>` — the same mechanism `chantier validate-task` uses.

## Prerequisites

The operator MUST:

1. Pre-create a git worktree with `git worktree add` and `cd` into it
   (the adapter refuses to run outside any git work tree).
2. Have `claude`, `jq`, and `chantier` on `$PATH` (the adapter refuses to
   run if any dependency is missing).
3. Ensure `.planning/STATE.md` exists at the worktree root with a JSONL
   format header (per ADR 0002).

The adapter itself never creates a worktree — that responsibility belongs
to the operator, keeping the project-level `using-git-worktrees` skill
separate from adapter-level worktree posture.

## Environment variables exported to the subagent

| Variable             | Purpose                                              |
|----------------------|------------------------------------------------------|
| `CHANTIER_TASK_ID`   | Task ID dispatched (matches PLAN.md `task:` field)   |
| `CHANTIER_PHASE`     | Phase directory name (basename of dirname of PLAN.md)|
| `CHANTIER_WORKTREE`  | Absolute path to the worktree root                   |

The adapter writes all three to `$WORKTREE/.chantier/dossiers/<task>/env.sh`
AND exports them in its own process before invoking `claude -p` so subprocess
inheritance covers the path; the dispatch prompt instructs the subagent to
also `source env.sh` after `cd`-ing into the dossier. Three layers of safety.

## Exit-code matrix

| Code | Meaning                                              | When                                                                                          |
|------|------------------------------------------------------|-----------------------------------------------------------------------------------------------|
| 0    | Green — skill completed and validate-task passed     | `claude -p` exit 0 AND `chantier validate-task <task-id>` exit 0                              |
| 1    | Contract violation — validate-task red               | `chantier validate-task` exit non-zero; outputs quarantined to `.planning/phases/<phase>/tasks/<task>/attempts/<NN>/` |
| 2    | Invocation error                                      | Not inside a git worktree; PLAN.md / SKILL.md lookup failed; `claude -p` exit non-zero       |
| 3    | Environment error                                     | Missing `claude` / `jq` / `chantier` binary; task-id grammar invalid; missing argument        |

This matrix matches `core/bin/chantier`'s own (ADR 0002).

## `CHANTIER_CLAUDE_BIN` override

For offline / deterministic execution (CI, e2e tests, dev without a Claude
session), set `CHANTIER_CLAUDE_BIN` to the path of any binary that accepts
`-p <prompt>` and exits 0 on success. The adapter resolves
`${CHANTIER_CLAUDE_BIN:-claude}` from `$PATH` when present, otherwise the
real `claude` CLI. This indirection is mandatory: NFR-004 forbids network
calls in CI, so the project's bats e2e tests inject a ~10-line stub.

Real-claude path additionally captures the dispatch transcript to
`$WORKTREE/.chantier/dossiers/<task>/subagent.transcript.log` for
post-mortem forensics; the stub path produces no transcript (it is
deterministic and uninteresting to log).

## Dossier layout

After dispatch (success or failure), the dossier is preserved at
`$WORKTREE/.chantier/dossiers/<task-id>/`:

```
inputs.yml                  -- extracted from PLAN.md inputs: block
env.sh                      -- the three exports above
reads/                      -- symlinks to declared state_reads paths
upstream/                   -- reserved for depends_on outputs (Phase 5)
skill/SKILL.md              -- copied from skills/<skill-id>/
skill/PRESSURE.md           -- copied from skills/<skill-id>/
skill/run.sh                -- copied from skills/<skill-id>/ (executable)
subagent.transcript.log     -- real-claude path only
```

Operator (or a future cleanup skill) decides when to purge. `git worktree
remove` atomically discards the entire dossier tree.

## Events appended to STATE.md

The adapter brackets each dispatch with two events:

- `task.started` — appended before `claude -p` is invoked (refs the dossier
  and worktree paths).
- `task.completed` or `task.failed` — appended after validate-task returns.

The skill's `run.sh` continues to append its own `skill.completed` event
between the two adapter events — the adapter never emits `skill.completed`
itself (that boundary belongs to the skill).

A successful task therefore produces three events in `.planning/STATE.md`:
`task.started`, `skill.completed`, `task.completed`. A failed task produces
`task.started` followed by `task.failed`; `skill.completed` may or may not
appear depending on whether the skill's `run.sh` reached its trailing
`state append` call.
