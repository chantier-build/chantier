---
skill_id: requesting-code-review
scenarios:
  - id: rcr-time-pressure-01
    levers: [time-pressure]
    invariants_referenced: [4]
  - id: rcr-sunk-cost-01
    levers: [sunk-cost]
    invariants_referenced: [4]
---

# PRESSURE -- requesting-code-review

This document captures the adversarial scenarios this skill is designed to survive. Each scenario describes a temptation the agent will encounter under realistic conditions and the response the skill demands. The Disqualifier subsection is the falsifiable failure signal -- it cites the SKILL.md invariant violated and the `output.json` field that detects the violation.

## Scenario 1 -- "Ship before the release window closes" (time-pressure)

**Situation**. The release window closes in 30 minutes. The branch has accumulated 18 commits across 7 functional files plus 3 ancillary files touched by a tooling change. The reviewer is on the same call and says "just send me the whole diff -- I'll find the bits that matter." Time is short, the reviewer is technically capable, and articulating scope feels like a luxury when the deadline is concrete and minutes away.

**Temptation**. Run `git diff main` with no head ref and no path filters. Paste the result into the call's chat. The reviewer is competent; they can grep. The 90 seconds of scope articulation feels expensive against the 30-minute window, and the reviewer's own request was explicitly "just send me everything."

**Required response**. Send the scoped request: cite `main...HEAD` explicitly, list the path scopes (the 7 functional files; the 3 tooling files in a separate scope or omitted with a note), and write a one-line `reviewer_focus` ("billing rounding change in src/billing/invoice.ts; the tooling churn is mechanical and can be skimmed unless the build broke"). Total cost: ~90 seconds. The reviewer's would-be 5 minutes of triage becomes 90 seconds of confirmation. The release window closes on time, and the audit trail records what was reviewed against what -- not "everything", which is unreviewable in any later forensic.

**Disqualifier**. Violates Invariant 4 (scoped-diff). Detected by `output.json.diff_base_ref` empty OR `output.json.review_prompt_path` referencing a file whose recorded command shows `git diff` invoked without a `--` path filter. Either signal means the request was sent unscoped, the reviewer-attention budget was assumed infinite, and the discipline was abandoned because the deadline made it feel optional.

## Scenario 2 -- "The branch is too tangled to scope cleanly" (sunk-cost)

**Situation**. Three weeks of work landed on a single branch: a feature, an internal refactor, a generated rename pass, and an unrelated bug fix that the agent picked up along the way. The branch is too tangled to scope cleanly without surgery the agent does not want to do. Cherry-picking, interactive rebase, or splitting into multiple branches all feel like throwing away three weeks of git history that already exists in a working shape.

**Temptation**. Skip the scoping step entirely. Send the whole branch with a "sorry it's tangled" note. The reviewer can sort it out -- they have been in the loop for weeks, they know the context, and the three weeks of accumulated work feel like a sunk cost that any pre-review surgery would interrupt. Each splitting option (rebase, cherry-pick, four separate review requests) feels like a rework tax on work already done.

**Required response**. Pick one of two paths and commit. EITHER (a) split the branch into separate review requests for each scope -- four invocations of this skill, each with its own narrow `scope_paths`, each producing a `review_prompt.md` the reviewer can address atomically; OR (b) be honest in `reviewer_focus`: "this branch combines four unrelated changes; review the feature under src/feature/, ignore the rename -- it is generated and identity-checked by build/rename.sh, and the refactor under src/lib/ has been ground-truthed against the existing test suite which still passes." Either path produces a `review_prompt_path` whose body is scope-aware. The three weeks are not wasted: they produced four reviewable units, or one annotated request that names them.

**Disqualifier**. Violates Invariant 4 (scoped-diff). Detected by `output.json.diff_file_count > 50` AND `output.json.review_prompt_word_count > 5000` with no narrowing scope_paths recorded -- i.e., the inputs.yml staged in the dossier shows a single wildcard scope. Either over-sized signal proves the scoping step was abandoned because the branch felt too tangled to touch -- which is exactly the moment scope discipline matters most.
