---
id: using-git-worktrees
version: 1.0.0
inputs_schema:
  type: object
  required: [branch_name, setup_command, base_ref]
  properties:
    branch_name:
      type: string
      pattern: "^[A-Za-z0-9._/-]+$"
    setup_command:
      type: string
    base_ref:
      type: string
state_reads:
  - "{phase}/CONTEXT.md"
state_writes:
  - "{phase}/tasks/{task}/"
  - ".planning/STATE.md"
outputs_schema:
  type: object
  required:
    - baseline_clean
    - baseline_diff_lines
    - worktree_path
    - setup_exit_code
    - invariants_applied
  properties:
    baseline_clean:
      type: boolean
    baseline_diff_lines:
      type: number
    baseline_check_command:
      type: string
    worktree_path:
      type: string
    setup_exit_code:
      type: number
    started_at:
      type: string
      pattern: "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"
    ended_at:
      type: string
      pattern: "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"
    invariants_applied:
      type: array
      items:
        type: number
portable: true
harness_adapters:
  - claude-code
---

# Using git worktrees

## Purpose

Create a parallel-isolation worktree from a known-clean baseline so that mechanical work (test runs, dependency edits, exploratory commits) does not contaminate the calling agent's working tree. The skill exits without creating a worktree if the baseline is not clean, recording the contamination as a measurable failure rather than silently overwriting.

## When to use

- A parallel feature branch must be exercised while preserving the current checkout for unrelated review or on-call use.
- A long-running exploratory edit will accumulate state that should not block the main checkout from being committed or stashed cleanly.
- A destructive command (large refactor, dependency upgrade, schema migration trial) must run somewhere that cannot leak into production code paths.
- A known-good baseline must remain intact while a bug is reproduced or a hypothesis is tested in a separate tree.
- A reviewer or on-call shares the same checkout and contention over the index would force git-stash gymnastics.

## Invariants

These invariants apply to every invocation of this skill. The kernel (1-3) is shared with every skill in this project; 4 is specific to worktree isolation.

1. **Portability.** No file written by this skill contains a harness identifier. (Kernel) (Proof: gate 4 deny-list scan over `output.md`, `output.json`, and `run.sh`.)
2. **State log append-only.** The skill mutates STATE.md only via `chantier state append`. (Kernel) (Proof: the only `STATE.md` write performed by `run.sh` is the final `chantier state append -e skill.completed` invocation.)
3. **State writes containment.** The skill writes only inside paths declared in `state_writes`. (Kernel) (Proof: gate 1 path containment check; `state_writes` lists `{phase}/tasks/{task}/` and `.planning/STATE.md`.)
4. **Clean baseline before work.** The skill does not create a worktree if the current branch has a dirty index or untracked files. (Proof: `output.json.baseline_diff_lines == 0` AND `output.json.baseline_clean == true`.)

Every invariant has a measurable proof in `output.json` (see `outputs_schema`). The list of which invariants were applied is captured in `output.json.invariants_applied`.

## How

1. Confirm a worktree is the right tool for the current task: there is parallel work whose history must not entangle with the calling tree, OR a destructive run must be sandboxed without polluting the index. If the work is short and non-destructive, a worktree adds friction without benefit.

2. Treat the baseline check as load-bearing, not a formality. A dirty baseline at worktree creation time means later forensic work (which agent wrote which line during a long session) becomes guesswork. The skill records the dirty-line count when the baseline is dirty so the contamination is visible, not silent.

3. Let `run.sh` own the mechanical steps (`git status --porcelain=v1`, `git worktree add`, the setup command). The body answers WHEN and WHY; `run.sh` answers HOW. This split is the only reason the same skill can run under different host environments without re-authoring the mechanics.

4. Record the worktree path in `output.json` so downstream tasks (and human reviewers) can locate the isolated tree without re-deriving it from inputs. A blank `worktree_path` is the falsifiable signal that the skill was invoked but did not create the worktree.

5. Run the `setup_command` inside the new worktree, not in the parent. This is what isolation means in practice: the setup side effects (dependency installs, schema migrations, test runs) land in the worktree's working copy, never in the caller's.

6. Do not lock STATE.md from inside this skill. The final `chantier state append` call handles serialisation through the binary's own mkdir-mutex. A second lock attempt here would deadlock against the binary at runtime.

7. Surface a dirty baseline as a business outcome, not a technical failure. A dirty baseline returns exit 0 with `baseline_clean: false`; the caller decides whether to retry after a commit-or-stash. Conflating "baseline dirty" with "technical incident" would force every caller to inspect exit codes instead of the structured outcome in `output.json`.

## Portability claim

This skill ships with a single-entry `harness_adapters` list (see frontmatter). That is a tested-only declaration: the only host environment that has been verified end-to-end (one real task, `chantier validate-task` green, `output.json` matching `outputs_schema`) is the one declared in the frontmatter. To extend the list:

1. Write `adapters/<host>/run-task.sh` for the new host.
2. Run this skill end-to-end on the new host with a representative dossier.
3. Verify `chantier validate-task` exits 0 and `output.json` matches `outputs_schema`.
4. Extend `harness_adapters[]` in the same commit as the new adapter ships.

A bats test in `core/tests/skill_uniformity.bats` verifies every shipped skill declares the same array.

## Exit code matrix (from run.sh)

| Exit | Meaning |
|------|---------|
| 0 | Success or business-state failure encoded in `output.json` |
| 2 | Technical incident: missing inputs.yml, jq absent, git absent, filesystem error |

Business outcomes are NEVER encoded in exit codes. See `output.json` for the actual result (e.g., a dirty baseline returns exit 0 with `baseline_clean: false`).

## Acknowledge before acting

Before invoking `run.sh`, list (in writing, in the agent's own words) which invariants from the `## Invariants` section apply to the current task. For most tasks, all kernel invariants (1, 2, 3) apply; skill-specific invariant 4 applies whenever the task creates a worktree. For each applicable invariant, state in one sentence why it applies to the current task. After producing this list, invoke `run.sh`. The list will appear in `output.md` under `## Invariants applied` (written by `run.sh`, not by you). If you cannot state why an invariant applies, do not proceed — re-read the body and re-examine `inputs.yml`.
