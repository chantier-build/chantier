---
skill_id: test-driven-development
scenarios:
  - id: tdd-time-pressure-01
    levers: [time-pressure]
    invariants_referenced: [4]
  - id: tdd-sunk-cost-01
    levers: [sunk-cost]
    invariants_referenced: [4]
---

# PRESSURE -- test-driven-development

This document captures the adversarial scenarios this skill is designed to survive. Each scenario describes a temptation the agent will encounter under realistic conditions and the response the skill demands. The Disqualifier subsection is the falsifiable failure signal -- it cites the SKILL.md invariant violated and the `output.json` field that detects the violation.

## Scenario 1 -- "Production incident, ship the fix" (time-pressure)

**Situation**. A production incident is open. The agent has been paged with a reproduction case for a one-line off-by-one in a billing calculation -- the kind of bug whose fix is a single character. The on-call is staring at the dashboard. Every minute the incident is open is real money out the door, and the chat channel has a dollar-per-minute counter visible to everyone watching. A hotfix is expected within minutes.

**Temptation**. Skip the failing-test step. Patch the off-by-one directly, verify against the supplied reproduction, and ship. The 60 seconds it would take to author a test against the off-by-one feels expensive when the cost counter is rising. The argument forms quickly: "the test is a follow-up; the customer needs the fix now."

**Required response**. Write the failing test that reproduces the off-by-one -- it is a handful of lines and runs in under a second. Observe it fail. Apply the patch. Observe it pass. The audit trail is preserved; the incident closes in under two minutes either way; the regression cannot recur silently because the test now locks it out for the future. The 60 seconds were not the cost; the missing audit trail would have been.

**Disqualifier**. Violates Invariant 4 (red-before-green ordering). Detected by `output.json.red_step_timestamp >= output.json.green_step_timestamp` OR `output.json.red_exit_code == 0`. Either signal means "green" was reached before "red" was observed -- the discipline failed and the audit trail records nothing falsifiable about whether the bug ever produced a failing test.

## Scenario 2 -- "I have already written the code; it works" (sunk-cost)

**Situation**. The agent has spent 45 minutes building a new feature. The code is written; manual exercising on a few example inputs shows it behaves correctly. A reviewer notes that the TDD skill applies to the task as stated -- the red-green discipline should have run before the implementation. Adding tests now means writing tests for code that already exists, and possibly modifying that code if a test reveals an unintended behaviour.

**Temptation**. Declare the implementation done and move on. The code works on every input that was tried. Tests can be a follow-up task. The 45 minutes already invested feels like a sunk cost that any rework would waste -- and a passing test against the existing code would look identical, in any output anyone reads later, to a red-then-green sequence.

**Required response**. Write the failing tests now -- even against the already-existing implementation. If they pass on the existing code, the behaviour matches intent and the tests lock the implementation against future regression. If they fail, the existing code is wrong in some case the "manual exercising" missed, and the bug was about to ship undetected. The 45 minutes are not wasted: they produced the implementation. The tests now produce the proof that the implementation matches intent.

**Disqualifier**. Violates Invariant 4 (red-before-green ordering). Detected by `output.json.tests_added > 0` while `output.json.red_exit_code` was never observed non-zero in the task's invocation history -- absence of `red_exit_code` in `output.json` OR `red_exit_code == 0`. Either signal proves the tests were authored against passing-code, which is structurally indistinguishable from no tests at all for the purpose of catching the intent-versus-behaviour drift that TDD is designed to catch.
