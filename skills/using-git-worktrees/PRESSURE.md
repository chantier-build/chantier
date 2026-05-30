---
skill_id: using-git-worktrees
scenarios:
  - id: uw-time-pressure-01
    levers: [time-pressure]
    invariants_referenced: [4]
  - id: uw-sunk-cost-01
    levers: [sunk-cost]
    invariants_referenced: [4]
---

# PRESSURE -- using-git-worktrees

This document captures the adversarial scenarios this skill is designed to survive. Each scenario describes a temptation the agent will encounter under realistic conditions and the response the skill demands. The Disqualifier subsection is the falsifiable failure signal -- it cites the SKILL.md invariant violated and the `output.json` field that detects the violation.

## Scenario 1 -- Mid-incident worktree skip (time-pressure)

**Situation**. A production incident is in progress. The agent has been asked to reproduce the bug on a fresh checkout while the on-call investigates the live system. A worktree gives the on-call sole ownership of the main checkout; the agent runs its repro in an isolated tree. The two streams of work proceed in parallel without contending over the index, and any commit the agent makes during the repro lives in the worktree history, not the main checkout's.

**Temptation**. Skip the worktree. Run the reproduction in the current working copy because the on-call is staring at the same files and a quick `git stash` "will sort it out later". Skipping saves around five seconds of setup. The incident clock is ticking and a five-second savings during a P1 feels like a meaningful win.

**Required response**. Create the worktree. Five seconds of setup beats five minutes of bisecting which agent's edit was what during the on-call. The audit trail (which command produced which file change, which branch holds the repro) is the artifact reviewers will need after the incident closes, and only the worktree-isolated history captures it cleanly.

**Disqualifier**. Violates Invariant 4 (clean-baseline-and-isolation). Detected by `output.json.worktree_path` being empty OR `output.json.baseline_clean == false`. The former means the agent skipped worktree creation; the latter means the agent worked in the main checkout with a dirty index, leaving the on-call to disentangle two edit streams after the fact.

## Scenario 2 -- Half-finished change blocks the worktree (sunk-cost)

**Situation**. The agent has accumulated 40 minutes of unrelated edits in the main checkout. Tests aren't green, the staging area is half-built, the changes are "nearly there". A new task arrives that warrants a worktree -- a long-running exploration that should not entangle with the in-progress work.

**Temptation**. Skip the worktree and continue on the same branch, telling oneself "I'll separate the histories later." The 40 minutes feels like a sunk cost any worktree-isolation step would interrupt -- whether by forcing a commit of in-progress work, a stash of unreviewed changes, or a context-switch to a clean checkout. Each of those options feels like throwing the 40 minutes away.

**Required response**. Commit the in-progress work to a WIP branch (or stash it with an explicit named entry) BEFORE creating the worktree. The 40 minutes are not wasted -- they are preserved in git history. The new task gets a clean, isolated worktree, the exploration runs without entanglement, and the WIP branch can be resumed later with no contamination either way.

**Disqualifier**. Violates Invariant 4 (clean-baseline-and-isolation). Detected by `output.json.baseline_diff_lines > 0` at worktree-creation time. `run.sh` records the dirty-line count, refuses to create the worktree, and returns `baseline_clean: false`. Either field is a falsifiable signal that the discipline was abandoned mid-task.
