---
id: subagent-driven-development
version: 1.0.0
inputs_schema:
  type: object
  required: [subtask_count, parent_brief]
  properties:
    subtask_count:
      type: number
    parent_brief:
      type: string
    subtask_focus:
      type: array
      items:
        type: string
state_reads:
  - "{phase}/CONTEXT.md"
  - "{phase}/tasks/{depends_on}/output.json"
state_writes:
  - "{phase}/tasks/{task}/"
  - ".planning/STATE.md"
outputs_schema:
  type: object
  required:
    - subtask_count
    - subtask_briefs
    - parent_context_refs_count
    - subagent_invariants_acknowledged_count
    - invariants_applied
  properties:
    subtask_count:
      type: number
    subtask_briefs:
      type: array
      items:
        type: object
    parent_context_refs_count:
      type: number
    subagent_invariants_acknowledged_count:
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

# Subagent-driven development

## Purpose

Fan a parent task out into self-contained subtask briefs, each a file on disk that a fresh agent invocation can read without any parent-conversation context. The skill is the load-bearing answer to the discipline-loss problem documented at https://github.com/obra/superpowers/issues/237 -- discipline cannot live in session-injected hooks; it must live in the files the subagent reads.

## When to use

- A parent task is too large to complete inside one context window and naturally splits into independent subtasks.
- A parent task benefits from parallel execution by multiple fresh agent invocations, each working from its own brief.
- A parent task's discipline (kernel invariants, scoped review, worktree isolation, red-before-green ordering) must survive the parent-to-subagent context boundary.
- A subagent is about to be dispatched and the parent context contains background no fresh invocation will see -- the brief MUST capture everything the subagent needs from a cold start.
- NOT for tasks that compose mid-flight (the subagent has no channel back to the parent during execution); NOT for tasks whose subtasks share mutable state without explicit isolation (use the worktree skill first).

## Invariants

These invariants apply to every invocation of this skill. The kernel (1-3) is shared with every skill in this project; 4 and 5 are specific to subagent-driven fan-out discipline.

1. **Portability.** No file written by this skill contains a harness identifier. (Kernel) (Proof: gate 4 deny-list scan over `output.md`, `output.json`, `run.sh`, and every emitted `subtask_brief_<id>.md` file.)
2. **State log append-only.** The skill mutates STATE.md only via `chantier state append`. (Kernel) (Proof: the only `STATE.md` write performed by `run.sh` is the final `chantier state append -e skill.completed` invocation.)
3. **State writes containment.** The skill writes only inside paths declared in `state_writes`. (Kernel) (Proof: gate 1 path containment check; `state_writes` lists `{phase}/tasks/{task}/` and `.planning/STATE.md`.)
4. **Self-contained subtask briefs.** Every subtask brief is a file on disk that the subagent can `cat`; no item in the brief depends on parent-conversation context the subagent does not have. (Proof: `output.json.subtask_briefs[].brief_path` references actual files AND `output.json.parent_context_refs_count == 0`.)
5. **Kernel acknowledgement.** Every dispatched subtask brief begins by reading aloud the three kernel invariants. (Proof: `output.json.subagent_invariants_acknowledged_count >= 3`.)

Every invariant has a measurable proof in `output.json` (see `outputs_schema`). The list of which invariants were applied is captured in `output.json.invariants_applied`.

## How

1. The subtask brief lives on disk because the fresh invocation has no parent context to fall back on. Anything the subagent needs -- design, inputs, expected outputs, disqualifying failure modes -- must appear in the brief itself or in dossier files the brief points to. There is no second channel.

2. The brief acknowledges the kernel invariants verbatim because the subagent cannot rely on hooks to inject them. The acknowledgement is not for the dispatcher's benefit; it is the only mechanism that propagates the project's discipline across the context boundary. See `## Why no hooks` below for the underlying constraint.

3. Each subtask is independent. The fan-out exists so subtasks can be executed in parallel by separate fresh invocations; if two subtasks must share mutable state mid-execution, they are not actually independent and the fan-out is the wrong shape -- collapse them or stage the work behind a worktree first.

4. Use this skill when the parent task is structurally ready to split: subtasks are scoped, inputs are known, expected outputs are stated. Do NOT use it as a procrastination device when the parent task is still being scoped -- dispatching half-formed subtasks produces fresh invocations that ask questions the brief cannot answer (and which the parent context cannot relay to them).

5. The `subtask_focus` input is a per-subtask one-line hint that narrows the parent_brief for that particular subtask. It is NOT a substitute for the full brief; the brief still must be self-contained. Think of `subtask_focus` as the chapter title and the brief body as the chapter.

## Why no hooks

A fresh agent invocation runs without access to the parent conversation. Discipline that depends on session-injected context -- such as a hook that fires at session start in some host environments to remind the agent of project invariants -- does not propagate to fresh invocations. The failure mode is documented at https://github.com/obra/superpowers/issues/237 and is the load-bearing constraint that motivates ADR 0001 §6. Chantier therefore places all discipline in the skill body and the dossier files, both of which the fresh invocation reads as files. Anything important to the task must be a file the fresh invocation can `cat`.

Invariants 4 and 5 are the mechanical embodiment of this rule: every subtask brief is a file on disk, and every brief acknowledges the kernel invariants verbatim. The brief is the only thing that crosses the context boundary; everything that matters travels with it.

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
| 0 | Success or business-state outcome encoded in `output.json` (including a brief that records `parent_context_refs_count > 0`) |
| 2 | Technical incident: missing inputs.yml, `subtask_count < 1`, missing jq, filesystem error |

Business outcomes are NEVER encoded in exit codes. A brief that reveals `parent_context_refs_count > 0` is recorded honestly in `output.json` with `run.sh` exiting 0; downstream verification of Invariant 4 sees the breach and the disqualifier fires.

## Acknowledge before acting

Before invoking `run.sh`, list (in writing, in the agent's own words) which invariants from the `## Invariants` section apply to the current task. For any subagent-driven task, all five (kernel 1, 2, 3 plus skill-specific 4 and 5) apply. State in one sentence why each applies. After producing this list, invoke `run.sh`. The applied list will appear in `output.md` under `## Invariants applied` (written by `run.sh`, not by you). Each emitted subtask brief begins with the three kernel invariants read aloud verbatim -- that read-aloud is what makes Invariant 5 measurable. If you cannot state why an invariant applies, do not proceed -- re-read the body and re-examine `inputs.yml`.
