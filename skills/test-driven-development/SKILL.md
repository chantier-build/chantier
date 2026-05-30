---
id: test-driven-development
version: 1.0.0
inputs_schema:
  type: object
  required: [target_file, test_framework, phase]
  properties:
    target_file:
      type: string
    test_framework:
      type: string
      enum: ["bats", "pytest", "vitest", "jest", "go-test", "cargo-test"]
    test_command:
      type: string
    phase:
      type: string
      enum: ["red", "green"]
state_reads:
  - "{phase}/CONTEXT.md"
  - "{phase}/tasks/{depends_on}/output.json"
state_writes:
  - "{phase}/tasks/{task}/"
  - ".planning/STATE.md"
outputs_schema:
  type: object
  required:
    - tests_added
    - red_step_timestamp
    - green_step_timestamp
    - red_exit_code
    - green_exit_code
    - invariants_applied
  properties:
    tests_added:
      type: number
    red_step_timestamp:
      type: string
      pattern: "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"
    green_step_timestamp:
      type: string
      pattern: "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"
    red_test_command:
      type: string
    green_test_command:
      type: string
    red_exit_code:
      type: number
    green_exit_code:
      type: number
    coverage_delta:
      type: number
    invariants_applied:
      type: array
      items:
        type: number
portable: true
harness_adapters:
  - claude-code
---

# Test-driven development

## Purpose

Make the failing-test-first discipline mechanical and falsifiable. The skill produces an audit trail in `output.json` -- two timestamps and two exit codes -- that proves the red step was observed before any production change, and that the same test command exits zero after the change.

## When to use

- Any task whose intent is a change in behaviour that a test can express (a new feature, a new code path, a new validation rule).
- Bug fixes where the failing test is the reproduction case: the test fails on the broken code, passes on the fix, and locks the regression out for the future.
- Refactors guarded by an existing green suite -- the test command runs both before and after to confirm the refactor was behaviour-preserving.
- Not for documentation-only changes -- there is no behaviour to assert.
- Not for purely configuration changes whose effect cannot be expressed as a test assertion (e.g., adjusting a comment, renaming a private variable that no test names).

## Invariants

These invariants apply to every invocation of this skill. The kernel (1-3) is shared with every skill in this project; 4 is specific to TDD discipline.

1. **Portability.** No file written by this skill contains a harness identifier. (Kernel) (Proof: gate 4 deny-list scan over `output.md`, `output.json`, and `run.sh`.)
2. **State log append-only.** The skill mutates STATE.md only via `chantier state append`. (Kernel) (Proof: the only `STATE.md` write performed by `run.sh` is the final `chantier state append -e skill.completed` invocation.)
3. **State writes containment.** The skill writes only inside paths declared in `state_writes`. (Kernel) (Proof: gate 1 path containment check; `state_writes` lists `{phase}/tasks/{task}/` and `.planning/STATE.md`.)
4. **Red before green.** A failing test for the change is observed in the test runner output before any production code is written for this task. (Proof: `output.json.red_step_timestamp < output.json.green_step_timestamp` AND `output.json.red_exit_code != 0` AND `output.json.green_exit_code == 0`.)

Every invariant has a measurable proof in `output.json` (see `outputs_schema`). The list of which invariants were applied is captured in `output.json.invariants_applied`.

## How

1. Treat the failing test as the proof-of-intent. A test that already passes against the current code does not prove the next change is well-defined; it proves only that the current code does what the test says. Discipline begins by writing the test that captures what the change should make true, and confirming that the test currently fails.

2. Run the skill in two invocations: first with `phase: red`, then with `phase: green`. The first invocation writes the failing-test timestamp and exit code into `output.json`. After the production change is written, the second invocation reads the prior `output.json` from the same task directory, merges in the green-step fields, and rewrites the file. The two-invocation split is what makes the ordering measurable -- a single invocation could not falsifiably attest that red was observed before the change.

3. Let `run.sh` own the mechanics: launching the test runner, capturing the exit code under `set +e` so a legitimate red-step failure does not abort the script, counting test cases from runner output. The body answers WHEN and WHY; `run.sh` answers HOW. Adapters bind the runner invocation to the host environment without re-authoring the discipline.

4. Resist the urge to write "the tests after the implementation." The PRESSURE.md scenarios document why this is the most common failure mode: sunk-cost reasoning makes already-written code feel finished, and a passing test against existing code looks indistinguishable from a falsifiable red-then-green sequence -- except the audit trail in `output.json` will reveal a missing or zero `red_exit_code`.

5. Pick a `test_framework` that matches the project. The v0.1 first-class framework is `bats` (it is what this project dogfoods); `pytest`, `vitest`, `jest`, `go-test`, and `cargo-test` are accepted in `inputs_schema` with documented limitations on the `tests_added` counter for runners whose output format diverges from TAP-style `ok` / `not ok` lines.

## Portability claim

This skill ships with a single-entry `harness_adapters` list (see frontmatter). That is a tested-only declaration: the only host environment that has been verified end-to-end (one real task, `chantier validate-task` green, `output.json` matching `outputs_schema`) is the one declared in the frontmatter. To extend the list:

1. Write `adapters/<host>/run-task.sh` for the new host.
2. Run this skill end-to-end on the new host with a representative dossier (one red invocation, one green invocation).
3. Verify `chantier validate-task` exits 0 and `output.json` matches `outputs_schema`.
4. Extend `harness_adapters[]` in the same commit as the new adapter ships.

A bats test in `core/tests/skill_uniformity.bats` verifies every shipped skill declares the same array.

## Exit code matrix (from run.sh)

| Exit | Meaning |
|------|---------|
| 0 | Success or business-state outcome encoded in `output.json` (including the legitimate red-step failure) |
| 2 | Technical incident: missing inputs.yml, unknown test_framework, missing jq, filesystem error |

Business outcomes are NEVER encoded in exit codes. A failing red step is recorded as `red_exit_code: <nonzero>` in `output.json`, and `run.sh` itself exits 0 because the failure is the intended business state of the red invocation.

## Acknowledge before acting

Before invoking `run.sh`, list (in writing, in the agent's own words) which invariants from the `## Invariants` section apply to the current task. For TDD, all four invariants (kernel 1, 2, 3 plus skill-specific 4) apply unless the task is documentation-only or configuration-only -- in which case TDD is not the right skill. For each applicable invariant, state in one sentence why it applies to the current task. After producing this list, invoke `run.sh` with `phase: red` in `inputs.yml`; observe the test fail; write the production change; re-invoke with `phase: green`. The applied list will appear in `output.md` under `## Invariants applied` (written by `run.sh`, not by you). If you cannot state why an invariant applies, do not proceed -- re-read the body and re-examine `inputs.yml`.
