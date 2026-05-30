# Strategic sketch — Path to a mature Chantier

- **Status:** Sketch. Not a roadmap commitment.
- **Date drafted:** 2026-05-30
- **Drafted by:** Founding contributor (MAoDzi) with Claude Opus 4.7
- **Scope:** Post-v0.1.0 direction, candidate workflow skill set, multi-version arc through v1.0.0
- **Ratification:** None required. This is a thinking artifact that informs but does not constrain future ROADMAP.md edits.

> This document captures the output of a strategic discussion on 2026-05-29 and 2026-05-30 about how Chantier should evolve after v0.1.0 ships. It is a sketch, not a plan. The ROADMAP.md remains the binding artifact for committed milestone work; this document feeds into it but does not replace it. Read this when planning a new milestone, not when reading the project's current commitments.

---

## What this document is and is not

**This document is:**

- A snapshot of strategic thinking captured before lived experience can override it.
- A candidate workflow skill set with consolidation rationale.
- A multi-version arc (v0.2.0 → v1.0.0) with proposed sequencing and rationale.
- An honest inventory of alternatives considered and the reasons they were set aside.

**This document is not:**

- A commitment. Nothing here is binding.
- A roadmap. The roadmap is `.planning/ROADMAP.md`, which currently covers v0.1.0 only.
- Ratified design. ADR 0003 (Proposed) captures the principles that flow from this discussion; this document captures the surrounding sketch.

**When this document becomes stale:**

- After Phase 5 (dogfood-e2e), real experience will produce evidence that overrides much of this sketch. At that point, this document should be either:
  - Pruned heavily, keeping only what dogfooding confirmed.
  - Replaced by a new strategic sketch for the next milestone (v0.2.0+) based on dogfood findings.
  - Deleted, if the dogfooding makes its content moot.

---

## The two families of skills

A core observation that shapes everything below: skills in Chantier divide into two families, with different growth mechanisms.

### Family A — Domain skills (emergent)

Skills that operate on a specific kind of work: `migrate-stripe-customer`, `bisect-flaky-test`, `extract-graphql-resolver`, `deploy-with-feature-flag`, `audit-react-bundle-size`.

**Growth path.** These skills are produced by `extract-skills-from-phase` (deferred to v0.3.0 per REQUIREMENTS.md). A user runs Chantier on a real project; a pattern recurs across 3+ tasks; the extraction mechanism proposes a draft skill; the user authors the `PRESSURE.md` and promotes the draft to `skills/domain/<name>/`. A subset of these may, after enough real-world exercise, be proposed via PR to the central repository and become reference skills.

**Speed.** Slow. Months per skill from first occurrence to canonization.

**Why slow is correct.** A domain skill written speculatively (before 3 real occurrences) almost always encodes assumptions that break on the second project. The emergence path is the only way to produce domain skills that survive contact with reality.

### Family B — Workflow skills (intentional)

Skills that orchestrate other skills or produce project-level artifacts: `plan-phase`, `progress`, `execute-phase`, `verify-phase`, `extract-learnings`, `review`, `ship`.

**Growth path.** These skills are authored deliberately, following the principles in ADR 0003 (Proposed). Each one has a clear shape already validated by two years of GSD usage; the authoring task is to **transpose** that shape into a portable SKILL.md that conforms to ADR 0001 §Surface 2 — not to discover the shape.

**Speed.** Fast. Once ADR 0003 is ratified and the workflow-skill template is in place, a workflow skill PR should take days to weeks per skill, not months.

**Why fast is correct.** Waiting for `extract-skills-from-phase` to emerge `plan-phase` from real usage is performative purity. The user needs `plan-phase` from the first day; the emergence path is the right tool for unknown shapes, not for known ones.

---

## Candidate workflow skill set (the minimal 7)

This list is a **sketch**, not a commitment. It will be revised against Phase 5 dogfood findings before any of these skills is authored.

| # | Skill | Primary livrable | Replaces (in GSD heritage) | Notes |
|---|---|---|---|---|
| 1 | `plan-phase` | `.planning/phases/NN-name/PLAN.md` | `discuss-phase`, `spec-phase`, `plan-phase`, `pattern-mapper`, `phase-researcher` | Internal protocol: (a) ambiguity scoring, (b) pattern lookup, (c) PLAN.md emission. Single skill, not five. |
| 2 | `progress` | Human-readable report + machine-readable JSON | `progress`, `health`, `stats`, `audit-uat` | Modes: default (situational awareness), `--forensic` (6-check integrity audit). |
| 3 | `execute-phase` | Sequenced task execution with state events per task | `execute-phase`, `execute-plan`, `gsd-quick` | Optional `--task <id>` for single-task execution. No magic `--auto` (per ADR 0003 Principle 4). |
| 4 | `verify-phase` | Phase-goal verification verdict | `verifier`, `validate-phase`, `nyquist-auditor`, `verify-work` | Goal-backward analysis. Single verdict format. |
| 5 | `review` | Multi-pillar review report | `code-review`, `ui-review`, `security-review`, `eval-review` | Modes via flag (`--code`, `--ui`, `--security`, `--eval`). Shared verdict format across modes. |
| 6 | `extract-learnings` | `LEARNINGS.md` for the phase | `extract-learnings` | Human-readable. Distinct from `extract-skills-from-phase`, which is the machine-extractor for domain skills. The two are complementary, not substitutes. |
| 7 | `ship` | PR opened, branch clean, gates green | `ship`, `pr-branch` | Single skill that touches the remote. All other workflow skills are local-only. |

**Why 7 and not 50.** GSD's surface accumulated to ~80 commands organically over two years, with significant semantic overlap (see ADR 0003 Context §3). Chantier's chance to set boundaries is *before* the first workflow skill is written. The minimal set above covers the operations a user actually needs to complete a phase end-to-end. Additions should be justified by lived friction, not anticipated need.

**Why not 5.** A smaller set would force overloading: `progress` becomes a god-skill with too many modes, or `review` swallows `verify-phase` and conflates "is the phase done" with "is the code reviewable." The current shape preserves clear semantic boundaries while resisting proliferation.

---

## The five parallel chantiers toward maturity

A trap to avoid: thinking maturity is one chantier (the skill library). It is five, and they advance somewhat independently.

### Chantier 1 — Workflow skills

- **What.** The 7-skill set above (or whatever it becomes post-dogfood).
- **How.** Intentional authoring per ADR 0003.
- **Estimated effort.** 2–3 weeks per skill, 7 skills, plus integration ⇒ ~3 months for the full set.

### Chantier 2 — Domain skills

- **What.** Skills extracted from real projects via `extract-skills-from-phase`.
- **How.** Run Chantier on 2–3 real projects (different domains), let the extraction mechanism propose drafts, canonize the good ones locally, PR the universal ones upstream.
- **Estimated effort.** Background. ~6 months to produce a meaningful first batch.

### Chantier 3 — Harness adapters

- **What.** `adapters/cursor/`, `adapters/codex/`, `adapters/gemini-cli/`, `adapters/opencode/`. Phase 4 ships `adapters/claude-code/`; the others are deliberate additions.
- **How.** One adapter per milestone. Each adapter is a planning phase of its own.
- **Estimated effort.** ~1 month per adapter once the first one (Phase 4) establishes the template.

### Chantier 4 — Binary UX

- **What.** `chantier skill list`, `chantier skill show <name>`, better `state show` output, error messages with remediation hints, possibly a `chantier doctor` command.
- **How.** Incremental binary improvements, each one in its own small ADR if it changes the surface.
- **Estimated effort.** Continuous low-volume work over the v0.2.0 → v1.0.0 arc.

### Chantier 5 — Governance and community

- **What.** Org-formed stage criteria from CONTRIBUTING.md: at least 3 active maintainers, MAINTAINERS.md populated, every PR reviewed by someone other than the author, MAINTAINERS.md becomes load-bearing.
- **How.** Outreach, first external contributors, deliberate handoff of decisions to the org rather than to founders. Likely accelerated by a public beta after v0.4.0.
- **Estimated effort.** Calendar-bound, not effort-bound. Likely 6–12 months from v0.1.0 publication.

---

## Proposed multi-version arc

This arc is a **sketch**. Each milestone bullet is a candidate, not a commitment.

### v0.1.0 — Foundation + runtime + adapter (Phases 1 through 5, in progress)

What ships: binary, 4 micro-discipline skills, Claude Code adapter, end-to-end dogfood test. Status as of 2026-05-30: Phase 2 complete; Phases 3, 4, 5 pending.

### v0.2.0 — Second adapter (Chantier 3)

What ships: `adapters/cursor/` or `adapters/codex/` (whichever has the larger user base or the cleanest portability surface). Established as a planning phase.

**Why this milestone, and why before workflow skills.** Writing workflow skills against a single harness adapter risks hidden coupling — a workflow skill body might unintentionally encode Claude-Code-specific subagent dispatch patterns, prompt conventions, or tool-name expectations. Forcing the workflow layer to satisfy two adapters from day one is the structural protection against that risk. The portability NFR (NFR-001) is cheap to enforce; the cost of removing hidden coupling after the fact is high.

### v0.3.0 — `extract-skills-from-phase` (Chantier 2 unlocked)

What ships: the meta-skill that proposes domain-skill drafts at phase close. Already on the REQUIREMENTS.md deferred list.

**Why this milestone now.** Domain-skill growth needs this mechanism unlocked. Without it, domain-skill emergence is manual and burdensome, and the Chantier 2 chantier cannot start in earnest. v0.3.0 is the unlock, not the payoff — the payoff comes over the following 6 months as real-project usage produces extractions.

### v0.4.0 — Workflow skills, suite 1 (Chantier 1, first wave)

What ships: `plan-phase`, `progress`, `execute-phase` — the three most painful absences in the v0.1.0 → v0.3.0 user experience.

**Why this order and grouping.** `plan-phase` is the single largest friction (every phase requires manual PLAN.md authoring without it). `progress` is the second-largest friction (no situational awareness). `execute-phase` follows because it depends on the PLAN.md shape that `plan-phase` produces. Verifying and shipping can still be done manually in v0.4.0; they are not blocking.

### v0.5.0 — Workflow skills, suite 2 (Chantier 1, second wave)

What ships: `verify-phase`, `review`, `extract-learnings`, `ship`.

**Why this order.** Verifying and reviewing are needed for any team larger than one. `extract-learnings` is needed once a user has shipped two or three phases and wants to capture cross-phase wisdom. `ship` is last because PR creation is a "polished moment" — it should be added when the workflow already feels mature.

### v0.6.0 — Third adapter + UX polish

What ships: a third harness adapter (whichever of Codex / Cursor / Gemini-CLI / OpenCode is not yet covered), plus the first batch of Chantier 4 binary-UX improvements: `chantier skill list`, `chantier skill show`, improved error messages.

### v1.0.0 — Stable

What ships: at this stage Chantier crosses from "Org-formed" to "Stable" per CONTRIBUTING.md. Semantic-versioned skill registry, deprecation policy, MAINTAINERS.md load-bearing, first public release with PR external contributions accepted. By this point Chantier has been used on real projects for 9–12 months and the workflow ergonomics approach parity with GSD while preserving full portability.

**Estimated calendar.** If Phases 3-5 take 2–3 months together (v0.1.0 complete by autumn 2026), v1.0.0 lands ~12 months later: ~late 2027.

---

## Three contrarian principles (the design heuristics)

These are not formal decisions (those live in ADR 0003). They are heuristics that shape the work above.

### Heuristic 1 — Resist surface proliferation

GSD's surface accumulated to ~80 commands; ~30% are semantic doublons. Chantier's lever to prevent the same accumulation is one good word: **no**. Every proposed workflow skill must justify why it is not a flag on an existing skill, not a phase of an existing skill, or not redundant with an existing skill. The default answer to "should we add a new workflow skill" is no until proven otherwise.

### Heuristic 2 — Thin skill, smart LLM

This is Principle 3 of ADR 0003, restated as a design heuristic: every line of prompt-encoded instruction in a SKILL.md body is a future portability bug. A workflow skill that is 200 lines of contract + 0 lines of prompt is more durable than a workflow skill that is 50 lines of contract + 1000 lines of prompt. When in doubt, cut prompt, expand contract.

### Heuristic 3 — Dogfood before you decide

Phase 5 (dogfood-e2e) is not a checkbox phase. It is the structural protection against premature decisions about everything after v0.1.0. Until Phase 5 has produced evidence about what actually hurts in v0.1.0 use, this entire document should be treated as informed speculation. The Phase 5 retrospective is the right moment to ratify ADR 0003, prune this strategic sketch, and commit to a concrete v0.2.0 ROADMAP.md.

---

## Alternatives considered

These alternatives were evaluated during the source discussion and not selected.

### Alt 1 — Defer all workflow skills to extract-skills-from-phase

Rejected because workflow skills are not in the "shape unknown" regime where emergence helps. See ADR 0003 §Alternative A.

### Alt 2 — Port GSD commands 1:1

Rejected because GSD's surface carries ~30% semantic dette accumulated organically. Chantier's chance to set deliberate constraints expires the moment the first workflow skill is merged. See ADR 0003 §Alternative B.

### Alt 3 — No workflow skills; rely on prose docs

Rejected because Chantier targets broader adoption than a 10–20 expert-user framework, and pure docs cannot prevent inter-user artifact divergence. See ADR 0003 §Alternative C.

### Alt 4 — One mega-skill called `workflow` with subcommands

Considered but not adopted. A single `workflow` skill with subcommands (`workflow plan`, `workflow progress`, `workflow ship`) would reduce file proliferation but at the cost of muddying the SKILL.md contract: one skill cannot have seven distinct `outputs_schema` declarations without becoming meaningless. The granular per-operation skill is the right unit of contractual cleanliness.

### Alt 5 — Write the workflow skills before Phase 5

Considered and rejected. Writing workflow skills before dogfood means encoding speculation about what hurts. Phase 5 is cheap insurance against authoring 7 skills, learning that 3 of them are the wrong shape, and refactoring under load. Better to ship the foundation, dogfood it honestly, **then** author the workflow layer with evidence.

---

## Open questions (deferred)

1. **Which harness for the second adapter (v0.2.0)?** Cursor and Codex are both plausible. The decision should weigh: (a) which has the larger user overlap with Chantier's target audience, (b) which has the cleanest extension/MCP surface to integrate with the dossier-staging pattern. Defer until v0.2.0 planning.

2. **How to validate workflow skill portability under two adapters.** The first workflow skill PR should include a test fixture that runs the same skill under Claude Code and the second adapter, asserting equivalent artifact production. The shape of that test fixture is not yet specified.

3. **Should `progress --forensic` remain a flag or become its own skill?** Currently sketched as a flag (Principle 2: consolidate). A counter-argument: if the forensic audit grows beyond ~6 checks, it may deserve its own skill. Revisit during `progress` design.

4. **`extract-learnings` vs `extract-skills-from-phase`.** Both run at phase close. Do they share invocation? Do they compose? Currently sketched as independent skills. May benefit from a single phase-close ritual that runs both.

5. **Public release calendar.** This sketch implies v1.0.0 ~late 2027. Is that aggressive enough for community adoption, or too slow to capture the current ecosystem window? The trade-off is real and not captured here. Defer to v0.4.0 planning.

---

## References

- ADR 0001 — The State / Skill Contract
- ADR 0002 — Runtime binary and state format
- ADR 0003 — Workflow skill design principles (Proposed)
- `docs/vision.md`
- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `CONTRIBUTING.md` — stages of project maturity
- `docs/research/inheritance-map.md` §10 — Self-improvement / learning extraction
