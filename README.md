# Chantier

**A long-haul build framework for AI coding agents.**
**State that persists. Skills that compose. Builds that ship.**

> Status: **Foundation stage** — architecture proposed, runtime not yet implemented. The first architectural decision ([ADR 0001](docs/adr/0001-state-skill-contract.md)) defines the contract; everything else is downstream of it.

---

## What

Most frameworks for AI coding agents force a choice:

- **State machine frameworks** (GSD-style) give you long-term memory across weeks of work — phases, milestones, plans on disk — but no discipline at the task level.
- **Skill library frameworks** (Superpowers-style) give you per-task discipline — TDD, code review, worktree isolation — but their multi-day continuity is admitted-incomplete.

Chantier is the first framework built to be both at once.

You keep your project context across weeks (a real `.planning/` filesystem, not session memory). **And** every task executes through a disciplined skill — TDD if the skill demands it, code review between tasks, worktree isolation by default. The two halves are bound by one file-based contract, defined in [ADR 0001](docs/adr/0001-state-skill-contract.md), that subagents and resumed sessions can read without any session-injected magic.

Open source. MIT. Portable target: Claude Code, Cursor, Codex CLI, Copilot CLI, Gemini CLI, OpenCode.

## Why

The 2025–2026 ecosystem of "spec-driven / context-engineering" frameworks for AI coding agents converged on two complementary-but-disjoint philosophies. No single framework does both well. Serious users juggle two frameworks and patch the seams by hand.

The inheritance map in [`docs/research/inheritance-map.md`](docs/research/inheritance-map.md) records, concept by concept, what Chantier keeps from each tradition and what it invents to bridge them.

## When *not* to use Chantier

Chantier is explicitly **not** for:

- **Trivial scripts.** A 50-line one-off does not need a state machine. Use the agent of your choice directly.
- **Single-session work.** If a task finishes before you close the laptop, the macro layer is dead weight.
- **Replacing your coding agent.** Chantier sits *above* Claude Code / Cursor / Codex; it does not replace them.

Target use: multi-day, multi-phase projects where you need a build to survive context resets, session changes, and contributor handoffs.

## Anti-features (explicit)

- ❌ Not a fork of GSD or Superpowers. Greenfield, inspired, attributed (see [LICENSE-CREDITS](LICENSE-CREDITS)).
- ❌ No token. No crypto. No monetary primitive. Ever. (Lesson from the original GSD's `$GSD` rug-pull.)
- ❌ Not a SaaS. Chantier runs locally on your machine. No telemetry by default.
- ❌ Not "universal." Chantier targets long projects with structure, not every workflow.

## Quickstart (placeholder — runtime not yet implemented)

The commands below describe the *intended* end-state once the runtime exists. They do **not** work yet.

```bash
# Install (target shape — not yet published)
npm install -g chantier

# Start a new project
chantier new my-project
cd my-project

# Define the first phase, then plan and execute
chantier plan-phase 1
chantier execute-phase 1
chantier verify-phase 1
chantier ship
```

What works today: the architecture documents in `docs/`. The runtime, the skill library, and the harness adapters are the next phases of the project itself — built using Chantier-as-it-becomes (`.planning/` is real; we dogfood from day one).

## Where to start reading

1. [`docs/vision.md`](docs/vision.md) — the refined vision and architectural thesis.
2. [`docs/research/inheritance-map.md`](docs/research/inheritance-map.md) — concept-by-concept inheritance from GSD and Superpowers.
3. [`docs/adr/0001-state-skill-contract.md`](docs/adr/0001-state-skill-contract.md) — the founding contract. Every later ADR justifies divergence from this one.

## Contributing

Chantier is built under a multi-contributor governance model from commit one — no single-maintainer dependency. See [CONTRIBUTING.md](CONTRIBUTING.md) for the model, and [docs/adr/](docs/adr/) for how architectural decisions are made.

## License

MIT. See [LICENSE](LICENSE). Copyright is collective (`Chantier Contributors`). Reciprocal credits to the projects that taught us how in [LICENSE-CREDITS](LICENSE-CREDITS).
