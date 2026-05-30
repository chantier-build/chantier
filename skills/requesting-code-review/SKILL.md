---
id: requesting-code-review
version: 1.0.0
inputs_schema:
  type: object
  required: [diff_base_ref, diff_head_ref, scope_paths]
  properties:
    diff_base_ref:
      type: string
    diff_head_ref:
      type: string
    scope_paths:
      type: array
      items:
        type: string
    reviewer_focus:
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
    - diff_base_ref
    - diff_head_ref
    - diff_file_count
    - review_prompt_path
    - review_prompt_word_count
    - invariants_applied
  properties:
    diff_base_ref:
      type: string
    diff_head_ref:
      type: string
    diff_file_count:
      type: number
    review_prompt_path:
      type: string
    review_prompt_word_count:
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

# Requesting code review

## Purpose

Prepare a focused review request from a scoped diff so that the reviewer -- human or another agent -- can act on a small, attributed change set rather than wading through a whole-repo diff. The skill produces `review_prompt.md` as a deterministic artifact the reviewer reads in full: the artifact cites an explicit base-to-head ref range, lists the path scopes that bound the diff, and embeds the diff itself so the reviewer never has to re-derive what is being reviewed.

## When to use

- A feature branch is feature-complete and a reviewer is about to be asked to read it -- a focused request beats "look at the branch".
- A long-running branch needs a mid-stream review of a specific subset (e.g., the controller layer only) while the rest of the branch continues to evolve.
- A hand-off to a different agent or human is imminent and the request needs to make the scope of attention unambiguous in writing.
- A reproduction patch or hotfix needs a second pair of eyes on exactly the changed lines, not on tangential refactors that landed in the same branch.
- NOT for "just take a look at the whole repo" requests -- that pattern violates the scoped-diff invariant and produces a review nobody actually reads.

## Invariants

These invariants apply to every invocation of this skill. The kernel (1-3) is shared with every skill in this project; 4 is specific to scoped-diff discipline.

1. **Portability.** No file written by this skill contains a harness identifier. (Kernel) (Proof: gate 4 deny-list scan over `output.md`, `output.json`, and `run.sh`.)
2. **State log append-only.** The skill mutates STATE.md only via `chantier state append`. (Kernel) (Proof: the only `STATE.md` write performed by `run.sh` is the final `chantier state append -e skill.completed` invocation.)
3. **State writes containment.** The skill writes only inside paths declared in `state_writes`. (Kernel) (Proof: gate 1 path containment check; `state_writes` lists `{phase}/tasks/{task}/` and `.planning/STATE.md`.)
4. **Scoped diff.** The review request cites an explicit `base...head` ref range and at least one path filter; never an unscoped `git diff`. (Proof: `output.json.diff_base_ref` and `output.json.diff_head_ref` both non-empty AND `output.json.diff_file_count` is a recorded integer AND `output.json.review_prompt_path` references an actual file.)

Every invariant has a measurable proof in `output.json` (see `outputs_schema`). The list of which invariants were applied is captured in `output.json.invariants_applied`.

## How

1. Scope matters because reviewer attention is finite. A 12-file scoped request gets read line-by-line; a 312-file unscoped one gets skimmed for vibes and merged. The skill enforces scope by requiring base/head refs AND a path filter list as inputs, and by recording the resulting `diff_file_count` so a too-large request is visible after the fact rather than silently delivered.

2. Use the three-dot range (`base...head`) rather than two-dot (`base..head`). Three-dot computes the diff against the common ancestor, so a long-running branch that has merged main several times during its life produces a diff that shows only the branch's own work, not the back-and-forth of mainline catch-up commits. Two-dot would mix the two and obscure attribution.

3. Path filters preserve attribution. Without them, a refactor that touched 40 files becomes indistinguishable in the review from the 3 files that hold the actual behaviour change. With them, the request says "review the behaviour change in these three files; the 40-file rename is mechanical and already greenlit by the test suite."

4. Invoke this skill when the work is feature-complete, not while it is still landing. The diff that goes into the review request is the diff the reviewer will read; if the branch is still moving, the review will be against a moving target and the request becomes worthless within minutes. Stabilise first; request second.

5. The `reviewer_focus` input is for hints the diff cannot communicate (e.g., "the round-tripping in src/billing/invoice.ts is the load-bearing change; the rest is dead-code removal"). It is NOT a TODO list for the reviewer -- review TODOs belong in PLAN.md, not in a one-shot review request that will not be read again after the merge.

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
| 0 | Success or business-state outcome encoded in `output.json` (including empty diff) |
| 2 | Technical incident: missing inputs.yml, missing git, missing jq, filesystem error |

Business outcomes are NEVER encoded in exit codes. An empty diff is recorded as `diff_file_count: 0` with `run.sh` exiting 0.

## Acknowledge before acting

Before invoking `run.sh`, list (in writing, in the agent's own words) which invariants from the `## Invariants` section apply to the current task. For any review-request task, all four (kernel 1, 2, 3 plus skill-specific 4) apply. State in one sentence why each applies. After producing this list, invoke `run.sh`. The applied list will appear in `output.md` under `## Invariants applied` (written by `run.sh`, not by you). If you cannot state why an invariant applies, do not proceed -- re-read the body and re-examine `inputs.yml`.
