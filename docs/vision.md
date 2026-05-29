# Vision

> Chantier — A long-haul build framework for AI coding agents. State that persists. Skills that compose. Builds that ship.

## The problem

By mid-2026, the ecosystem of "spec-driven / context-engineering" frameworks for AI coding agents has settled into two architectural philosophies that solve complementary problems but do not talk to each other:

**Philosophy A — State machine.** Frameworks in this tradition treat the project as a long-running state machine: phases, milestones, plans, and reviews are durable artifacts on disk. Multi-week work is possible because a fresh session can resume by reading the state. The dominant living example is [GSD redux](https://github.com/open-gsd/get-shit-done-redux), the community continuation of the original GSD project after its governance collapse in April 2026. Its strength is macro-continuity. Its weakness is that it has no opinion about *how* an individual task should be executed — tasks are paragraphs in a plan, not disciplined units.

**Philosophy B — Skill library.** Frameworks in this tradition treat each task as a disciplined micro-execution: TDD red/green is mandatory, code review runs between tasks, every task gets a fresh subagent in an isolated worktree. The dominant living example is [Superpowers](https://github.com/obra/superpowers) by Jesse Vincent. Its strength is micro-discipline and cross-agent portability. Its weakness is admitted by its author: multi-day continuity is "partially unresolved" — the memory system "is all there but unwired."

A serious developer working on a multi-week project today either picks one and patches the other half by hand, or runs both and reconciles them every morning. Both options waste time and leak state.

## The thesis

Chantier holds that **macro continuity and micro discipline are not in tension**. They are two halves of the same problem, and they can be unified through a single, file-readable contract.

A real-world construction site has two things in parallel: a durable master plan (the phases, the floors to raise, the milestone inspections — the macro), and disciplined trades (the mason, the electrician, the plumber — each with their method, their tools, their quality protocol — the micro). Neither replaces the other. Chantier delivers both: a system that knows where it is across weeks, **and** knows how to execute each task with discipline.

## Four non-negotiable principles

These are derived directly from the failure modes of the two predecessor traditions.

### 1. Macro and micro are both first-class

The state-machine layer (`PROJECT.md`, `ROADMAP.md`, `STATE.md`, per-phase plans and reviews) inherits from the GSD tradition. The skill library (composable `SKILL.md` units with TDD, code review, worktree isolation) inherits from the Superpowers tradition. **The two are bound by an explicit contract**, defined in [ADR 0001](adr/0001-state-skill-contract.md), instead of by filename convention or hidden coupling. A `PLAN.md` declares which skills it will invoke. A skill declares which state it reads and writes. The contract is auditable with `cat`, `jq`, and `grep`.

### 2. Cross-agent portability from day one

Skill bodies are pure Markdown + portable shell. Any harness-specific code lives in `adapters/<harness>/`. The same skill runs under Claude Code, Cursor, Codex CLI, Copilot CLI, Gemini CLI, OpenCode — because all of them can read files and execute shell. The orchestration layer is expressible in Markdown + Shell, not in TypeScript bound to a single harness's SDK.

### 3. Self-improving by design

At the close of every phase, an `extract-skills-from-phase` step proposes new skills or refinements of existing ones, based on what actually worked. This is the normal cycle, not a manual archeology dig. Skill extraction is a write-side concern (skills emit structured summaries as they run), not a read-side mining job (parsing 2,000 markdown files in retrospect).

### 4. Multi-contributor governance from commit one

Chantier is hosted under a GitHub org (`chantier-build`), not a personal account. Architectural decisions are versioned ADRs in `docs/adr/`. Copyright is collective (`Chantier Contributors`). License is MIT, pure — no token, no crypto, no SaaS lock-in. The lesson from the original GSD is direct: never depend on a single maintainer.

## What Chantier is not

- **Not a fork** of GSD or Superpowers. It is a greenfield project that explicitly inherits architectural tradition from both, attributes them in [LICENSE-CREDITS](../LICENSE-CREDITS), and diverges where the inheritance map says it must.
- **Not a token, not crypto, not SaaS, ever.** This is not a position the project will revisit.
- **Not a replacement for Claude Code / Cursor / Codex / etc.** Chantier is an orchestration layer that runs *on top of* an AI coding harness, not a substitute for one.
- **Not for trivial work.** A 50-line script does not need a state machine. Chantier targets multi-day, multi-phase projects where state and discipline both matter.

## How the project is built

Chantier is built using Chantier-as-it-becomes. The `.planning/` directory in this repository is real. Each phase of the framework's own construction is recorded in it. This is intentional dogfooding: if Chantier cannot describe its own construction, it cannot describe yours.

The current state is **Foundation stage**: the architecture exists in documents ([inheritance-map.md](research/inheritance-map.md), [ADR 0001](adr/0001-state-skill-contract.md), this vision), and the runtime does not exist yet. Building the runtime is the next phase.

## How to read further

- [docs/research/inheritance-map.md](research/inheritance-map.md) — concept-by-concept derivation from GSD and Superpowers, including what we drop on purpose and what we explicitly invent.
- [docs/adr/0001-state-skill-contract.md](adr/0001-state-skill-contract.md) — the founding contract. Read this before proposing any changes.
- [CONTRIBUTING.md](../CONTRIBUTING.md) — governance model and how decisions are made.
- [LICENSE-CREDITS](../LICENSE-CREDITS) — reciprocal credits to GSD and Superpowers.
