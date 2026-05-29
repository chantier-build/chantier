# Inheritance Map

> For each core concept Chantier inherits, this document records:
> **From GSD** — what the macro state-machine tradition contributes.
> **From Superpowers** — what the micro skill-library tradition contributes.
> **Chantier synthesis** — what we keep, what we drop, and what we invent to bridge the two.
>
> Sources studied:
> - GSD redux: `open-gsd/get-shit-done-redux` (active fork, MIT)
> - GSD originel: `gsd-build/get-shit-done` (archived after $GSD rug-pull, 2026-04-01)
> - Superpowers: `obra/superpowers` (Jesse Vincent, MIT, 14+ SKILL.md, ~212k ⭐)
> - Superpowers methodology: `blog.fsck.com/2025/10/09/superpowers/`
> - Superpowers subagent gap: `obra/superpowers#237`

---

## 1. Persistent state across sessions

**From GSD.** GSD encodes session-spanning state on the filesystem under `.planning/`:
- `PROJECT.md` — vision, acceptance criteria.
- `REQUIREMENTS.md` — scope, constraints.
- `ROADMAP.md` — phases with one-sentence summaries.
- `STATE.md` — current milestone, phase index, decision log.
- `CONTEXT.md` — per-phase implementation decisions captured during `/gsd-discuss-phase`.
- `phases/N-name/N-MM-PLAN.md` and `phases/N-name/N-MM-REVIEW.md` — phase-local artifacts.
- `config.json` — workflow toggles and model profiles.

Naming uses zero-padded indices (`phases/01-auth/`, `phases/02-api/`).

**From Superpowers.** No first-class persistent state. The remembering-conversations skill exists but Jesse Vincent explicitly admits "the pieces of the memory system are all there. I just haven't had time to wire them together." Memory is mined retroactively from past markdown (2249 files in his case), not produced as a workflow byproduct.

**Chantier synthesis.** Adopt the `.planning/` filesystem skeleton from GSD verbatim — it works and proves the multi-week continuity claim. Drop the zero-padded `N-MM` filename convention as the load-bearing structure; treat filenames as human-readable hints and store the canonical phase/plan identifiers inside the files themselves (front-matter). This removes the "fragile coupling by naming convention" the brief flags. Memory is a write-side concern: skills emit summary entries to `.planning/STATE.md` and to phase-local artifacts as they run, instead of being mined post-hoc.

---

## 2. Phase / milestone / project hierarchy

**From GSD.** Three-level hierarchy:
- Project → Milestone → Phase → Plan → Task (implicit).
- A milestone wraps several phases and ships as one PR.
- Phases run a six-step loop: `new-project → discuss → plan → execute → verify → ship`.

**From Superpowers.** No native milestone/phase concept. Skills like `writing-plans` and `executing-plans` exist, but a "plan" is a single artifact attached to one task, not a roadmap node.

**Chantier synthesis.** Keep GSD's three-level hierarchy. It is the macro-continuity mechanism that justifies the project's existence. Make the verbs ("discuss", "plan", "execute", "verify", "ship") explicit phase transitions in `STATE.md` so that any agent — Claude, Cursor, Codex — can resume by reading state, not by being told.

---

## 3. Skill / task atomicity

**From GSD.** Tasks live inside a `PLAN.md` as numbered items. Execution is the responsibility of subagents (`gsd-executor`, etc.) that get a fresh ~200k context per plan. Tasks themselves are not portable artifacts.

**From Superpowers.** A skill is the atom. Each `skills/<name>/SKILL.md` is a self-contained ~hundreds-of-words document with YAML frontmatter, callable from any task. Examples: `test-driven-development`, `using-git-worktrees`, `requesting-code-review`, `subagent-driven-development`, `writing-skills` (meta).

**Chantier synthesis.** Adopt the Superpowers SKILL.md unit as the micro atom. A Chantier task in `PLAN.md` is not "implement feature X" — it is "invoke skill `<id>` with inputs Y, expect output Z." This is the **state/skill contract** that ADR 0001 must formalize. The frontmatter must include declarations of state read/write so a planner can know which skills are safe to compose without reading their bodies.

---

## 4. TDD discipline

**From GSD.** No native TDD. Tests are an output of execution if the plan asks for them.

**From Superpowers.** `test-driven-development` skill enforces RED-GREEN-REFACTOR as mandatory: "write failing test, watch it fail, write minimal code, watch it pass, commit. Deletes code written before tests." Pressure-tested via Cialdini-inspired scenarios (time pressure, sunk cost).

**Chantier synthesis.** TDD is a skill, not a phase property. A `PLAN.md` task can opt into TDD by declaring it as a required skill. The framework does not force TDD on every task (the brief's anti-feature: not for trivial scripts), but the skill is available and well-tested for any plan that wants it.

---

## 5. Code review between tasks

**From GSD.** Verifier agent runs after a whole phase (`/gsd-verify-work`), not between tasks. Diagnostic loop produces fix plans.

**From Superpowers.** `requesting-code-review` and `receiving-code-review` skills run **between tasks**, by a fresh subagent. Two-stage review: spec compliance, then code quality. Critical issues block progress.

**Chantier synthesis.** Both granularities are useful. Between-task review is a Superpowers skill, callable per task. Phase-end verification stays as a GSD-style phase transition. The two compose: phase verification reads task-level review outputs from `.planning/phases/N/`.

---

## 6. Subagent dispatch + worktree isolation

**From GSD.** Subagents exist (`gsd-researcher`, `gsd-planner`, `gsd-executor`, `gsd-verifier`) but are Claude-Code-specific agents declared in `agents/` directory. No worktree isolation by default.

**From Superpowers.** Three composing skills:
- `using-git-worktrees` — creates isolated workspace, runs setup, verifies clean baseline.
- `subagent-driven-development` — dispatches fresh subagent per task with two-stage review.
- `dispatching-parallel-agents` — concurrent subagent workflows.

**Critical caveat (issue #237).** Superpowers' SessionStart hook injects the discipline framework into the main session; subagents do **not** receive this injection. Empirical tests show subagents will "rationalize skipping TDD and skill invocation" without it.

**Chantier synthesis.** Worktree isolation is a built-in. Subagent dispatch is a built-in. The injection gap is a load-bearing finding: **Chantier's state/skill contract must not depend on session-injected context.** A subagent reads `.planning/STATE.md` + the skill body + the task input — full stop. No magic hook propagation. This is also what makes the framework portable across harnesses that have no hook system at all.

---

## 7. Cross-agent portability

**From GSD.** Installer (`bin/install.js`) converts Claude Code-format source files to OpenCode, Codex, Copilot, Cursor, Windsurf, Gemini CLI, Kilo by transforming frontmatter. Conversion is the load-bearing step; direct file copy causes schema errors. Subagents are still defined in Claude Code-native form.

**From Superpowers.** Six+ harnesses via per-plugin configs (`.claude-plugin`, `.cursor-plugin`, `.codex-plugin`, `.opencode`, etc.). Skills bodies stay invariant — only the wrapping changes. 66.4% Shell, 24.8% JavaScript, with harness-specific config files.

**Chantier synthesis.** Adopt the Superpowers model: skill bodies are pure Markdown + Shell, no harness-specific code. Harness adapters live in `adapters/<harness>/` and translate the contract into whatever the harness understands (commands, MCP servers, plugin configs). The state machine itself is filesystem-only — readable and writable by `cat`, `cp`, `git`, `jq`. Any harness that can read and write files can host Chantier.

---

## 8. Auto-invocation

**From GSD.** Commands are explicitly invoked by the user (`/gsd-plan-phase 1`). Subagents are invoked by orchestrator commands. No auto-invocation in the Superpowers sense.

**From Superpowers.** Bootstrap prompt injected at session start: "You have skills. They give you Superpowers. Search for skills by running a script and use skills by reading them and doing what they say. **If you have a skill to do something, you must use it to do that activity.**" Skills trigger based on task-keyword matching.

**Chantier synthesis.** Explicit invocation is the default; auto-invocation is a harness-level opt-in. The contract makes both work: a plan declares which skills it will call; an auto-invocation hook (when available) can resolve skill calls by reading the same frontmatter the planner read. Skills that fire auto-invocation must still resolve their inputs from explicit state, not from the conversation buffer (cf. §6 caveat).

---

## 9. Pressure-testing of skills

**From GSD.** No equivalent. Plans are verified for goal achievement, not stress-tested against agent shortcuts.

**From Superpowers.** Cialdini-derived scenarios (time pressure, sunk cost) test whether skills survive realistic conditions where shortcuts seem attractive. Vincent: "skills must survive realistic conditions where shortcuts seem attractive."

**Chantier synthesis.** Inherited as-is. Each skill in `skills/` ships with a `PRESSURE.md` describing the adversarial scenarios it survives. This is a quality bar for accepting a skill into the standard library, not a runtime check.

---

## 10. Self-improvement / learning extraction

**From GSD.** `extract-learnings` command exists, scoped to per-phase decisions, lessons, patterns, surprises. Output is human-readable, not directly consumed by future phases.

**From Superpowers.** 2249 markdown files mined post-hoc by Claude clustering them by topic. Heavy lift; admitted by Vincent as not productionized for ongoing use.

**Chantier synthesis.** Per the brief's Principe 3, integrate extraction into the normal cycle: `extract-skills-from-phase` runs at phase close, proposing new skills or refinements based on what actually worked. Output is structured (frontmatter + body draft), so the next planner can read it without re-mining a conversation log.

---

## 11. Governance

**From GSD originel.** Single-maintainer (TÂCHES), opaque token integration ($GSD), social accounts deleted → catastrophic single point of failure on 2026-04-01.

**From GSD redux.** Community fork in `open-gsd` org, MIT pure, "we will preserve the tool's utility while excising cryptocurrency and restoring governance trust." Honest uncertainty framing about what cannot be confirmed about the original maintainer.

**From Superpowers.** Single primary author (Jesse Vincent / `obra`), 27 contributors, MIT, no tokens. Healthier than original GSD because Vincent is reachable and Vincent's social presence is intact, but still organizationally dependent on one person.

**Chantier synthesis.** Per the brief's Principe 4: GitHub org `chantier-build` from day one (not a personal account), MIT pure, no token ever, ADR-versioned decisions in `docs/adr/`, collective copyright (`Copyright (c) 2026 Chantier Contributors`). Founder name appears only in `CONTRIBUTING.md`, never in `LICENSE`.

---

## 12. Configuration

**From GSD.** `.planning/config.json` with `mode` (interactive/yolo), per-agent model profiles (quality/balanced/budget), workflow toggles (research, plan_check, verifier), `parallelization.enabled`, `code_quality.fallow.enabled`.

**From Superpowers.** Plugin-level configs per harness (`.claude-plugin/`, etc.). No central tuning file in the GSD sense.

**Chantier synthesis.** GSD's `config.json` model wins — central, scriptable, scoped to the workspace. Drop per-agent model profiles as a core concept (harness-dependent); allow harness adapters to read them if relevant.

---

## What we drop on purpose

- **Zero-padded `N-MM` filename coupling.** Filenames are hints, not the source of truth.
- **Hook-injected discipline context.** The contract is file-readable; no SessionStart magic required.
- **`$GSD`-like tokenization or any monetary primitive.** Forever.
- **Claude-Code-specific subagent declarations as the canonical execution model.** Adapters, not native code.

## What we explicitly invent (not inherited)

- **Frontmatter-declared state read/write per skill** (the state/skill contract, ADR 0001).
- **Phase-close skill extraction** as a normal cycle step, not a manual command.
- **Collective copyright + ADR-versioned architecture from commit one.**
