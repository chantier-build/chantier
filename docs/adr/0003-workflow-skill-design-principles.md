# ADR 0003 — Workflow skill design principles

- **Status:** Proposed
- **Date proposed:** 2026-05-30
- **Date accepted:** —
- **Deciders:** Chantier founding contributors
- **Supersedes:** —
- **Superseded by:** —

> ADR 0001 established the state/skill contract. ADR 0002 codified the runtime binary and the state format. Neither addresses how the **workflow** layer (the user-facing operations that a contributor invokes to plan, execute, verify, review, and ship work) is structured. This ADR proposes the design principles for that layer, before any workflow skill is authored.
>
> The ADR is **Proposed**, not Accepted. Ratification is deferred until after Phase 5 (dogfood-e2e) so the principles can be validated against lived experience rather than against a conversation alone.

---

## Provenance

This ADR was drafted following a strategic discussion between a founding contributor (MAoDzi) and Claude Opus 4.7 on 2026-05-29 to 2026-05-30. The conversation explored how Chantier should evolve its user-facing surface after v0.1.0 — specifically, how to deliver an ergonomic experience comparable to GSD without sacrificing the portability and discipline that motivated Chantier in the first place.

The principles below are the **distilled output** of that discussion. They are deliberately framed as design constraints, not as a list of skills to write. The companion document `docs/strategy/maturity-path.md` sketches a candidate workflow-skill set, but that list is explicitly non-binding and may be revised as Phase 5 dogfooding produces evidence.

---

## Context

Three forces motivate this ADR:

### 1. The v0.1.0 surface is too thin for ergonomic use

Phase 2 ships the binary with five subcommands: `new`, `state append`, `state show`, `validate-task`, `--self-test`. Phase 3 ships four micro-discipline skills: `using-git-worktrees`, `test-driven-development`, `requesting-code-review`, `subagent-driven-development`. Phase 4 ships the Claude Code adapter.

A user who has just installed v0.1.0 can:

- Scaffold a project (`chantier new`).
- Append state events manually.
- Validate that a task respects the ADR 0001 contract.
- Invoke a micro-discipline skill via the adapter.

A user who has just installed v0.1.0 **cannot**:

- Plan a phase without manually writing `PLAN.md` against the schema.
- Get a situational-awareness report (no equivalent to `/gsd-progress`).
- Execute a sequence of tasks in batch.
- Verify phase-goal achievement programmatically.
- Review or ship work through a guided process.

Every operation above can be performed in conversation with the harness's LLM, but the absence of a canonical, portable, schema-validated **skill** for each operation means that two users on the same project may end up with divergent artifacts. This is the friction the workflow layer must close.

### 2. The extract-skills-from-phase mechanism does not produce workflow skills

ADR 0001 §Surface 2 and `docs/vision.md` §Principle 3 establish that skill libraries grow through `extract-skills-from-phase` (deferred to v0.3.0 per `.planning/REQUIREMENTS.md`). The mechanism is designed to surface **domain-specific patterns** that have recurred enough during execution to warrant canonization — for example, `bisect-flaky-test`, `migrate-stripe-customer`, `extract-graphql-resolver`.

This mechanism is structurally unsuited to workflow skills. Workflow skills are:

- **Cross-cutting**: they orchestrate other skills rather than operating on a domain.
- **Already designed**: their shape has been validated by two years of GSD usage (`/gsd-plan-phase`, `/gsd-progress`, etc.).
- **Required from day one**: a user cannot wait three months of dogfooding to acquire the ability to plan a phase.

Waiting for emergence to produce workflow skills would mean the first 3–6 months of Chantier use are ergonomically barren. The opportunity cost is unacceptable.

### 3. GSD's surface has accumulated dette

The reference implementation (GSD redux) surfaces approximately 80 commands across its skill registry. Many of these commands overlap:

- `discuss-phase`, `spec-phase`, and `plan-phase` all produce artifacts consumed by the same execution step.
- `verify-work`, `validate-phase`, and `verifier` all produce verification verdicts at different granularities.
- A long tail of `audit-*` variants produces overlapping integrity reports.

The proliferation reflects organic growth, not deliberate design. Chantier has the opportunity — exactly once, before any workflow skill is written — to set design constraints that prevent the same accumulation.

---

## Decision

Chantier adopts four principles for the workflow skill layer. These principles apply to any skill that orchestrates other skills, produces a project-level artifact (PLAN.md, progress report, verification verdict, etc.), or sequences a multi-step user-facing operation.

### Principle 1 — Workflow skills are written intentionally

Workflow skills are **not** produced by `extract-skills-from-phase`. They are authored deliberately, in dedicated planning phases, against an explicit specification. The authoring path is:

1. A founding contributor (or, post-Org-formed stage, any maintainer) opens an ADR or feature plan describing the workflow skill's intent and surface.
2. The skill is written in `skills/<name>/` per the SKILL.md schema (ADR 0001 §Surface 2).
3. The skill is exercised in a dedicated phase using TDD (the skill `test-driven-development` from Phase 3).
4. The skill passes `chantier validate-task` for at least one real task before merge.

The `extract-skills-from-phase` mechanism remains the canonical path for **domain skills**. The two families coexist; the boundary is enforced by reviewer judgment, not by tooling.

### Principle 2 — One verb, one livrable, no semantic doublons

No two workflow skills shall produce the same artifact, occupy the same conceptual slot, or be invokable as substitutes for each other. Concretely:

- A skill that produces `PLAN.md` is unique. If a second skill claims to "discuss the phase before planning," it must either (a) merge with the planning skill as an internal phase, or (b) produce a **distinct** artifact (e.g., `DISCUSS.md`) that the planning skill consumes.
- A skill that emits a verification verdict is unique. Variants for code-review, security-review, UI-review may exist, but they must all consume the same verdict format and produce reports under the same review umbrella.
- A skill that displays project state is unique. Modes (`--blockers`, `--stats`, `--forensic`) may be passed as flags, not as separate skills.

Reviewers SHALL reject any proposed workflow skill whose `outputs_schema` overlaps with an existing skill's `outputs_schema` unless the new skill explicitly supersedes the old one (and the old one is deprecated in the same merge).

### Principle 3 — Thin skill, smart LLM

The body of a workflow skill SHALL be a **contract**, not a prompt. Specifically:

- The SKILL.md body describes **what** the skill produces: input shape, output shape, state reads, state writes, acceptance criteria.
- The SKILL.md body does **not** prescribe the exact prompting strategy, conversational protocol, or step-by-step instructions to the underlying LLM.
- The harness-side implementation (the adapter, or the LLM operating under the adapter) is responsible for deciding **how** to satisfy the contract.

Rationale: a thick prompt encoded in SKILL.md locks the skill to a specific LLM and harness behavior. A thin contract lets each harness adapter (and each LLM model version) optimize the "how" without breaking the "what." This is what makes the same skill portable across Claude Code, Cursor, Codex, Gemini CLI, and OpenCode.

Practical limit: a workflow SKILL.md body is **expected to be under 200 lines**. If a workflow skill needs more than 200 lines of body to describe its contract, it is doing too much and should be decomposed.

### Principle 4 — Chaining is explicit, in PLAN.md, not magic in the skill

A workflow skill SHALL NOT invoke another workflow skill silently. If `verify-phase` needs the output of `execute-phase`, the chaining lives in `PLAN.md` as two sequential tasks, not as an internal call hidden inside `verify-phase`'s implementation.

Forbidden patterns:

- A `--auto` mode that chains plan → execute → verify → ship without leaving an explicit trace in `STATE.md` of each step.
- A workflow skill that reads `STATE.md` to determine which other workflow skill to invoke next.
- A workflow skill whose acceptance criteria depend on side effects produced by another workflow skill invoked in the same execution.

Permitted patterns:

- A workflow skill consumes a file produced by a previous step (read-only). The file path is declared in `state_reads`.
- A workflow skill invokes a **micro-discipline skill** (`test-driven-development`, `using-git-worktrees`). This is composition, not chaining — the micro-discipline skill is an implementation detail of the workflow step, not a peer operation.

Rationale: implicit chaining recreates the situation GSD users sometimes hit, where a multi-step orchestration fails halfway and the user cannot recover because they do not know which step ran, which produced output, and which is now in an inconsistent state. Explicit chaining in `PLAN.md` makes the trace forensic and recoverable.

---

## Consequences

### Positive

- **A user can resume any workflow at any step.** Because chaining is in `PLAN.md` and every step appends to `STATE.md`, a session interruption never leaves "where am I in the magic --auto pipeline" ambiguity.
- **Portability is forced at design time, not at audit time.** A 200-line contractual SKILL.md cannot accidentally reference a Claude Code tool name; a 2000-line prompt-encoded SKILL.md easily can. NFR-001 (portability grep) is cheaper to enforce against thin skills.
- **The skill registry stays small.** With doublons forbidden and the boundary between workflow and domain enforced, the workflow set is expected to converge at 5–10 skills — not 80.
- **Future model upgrades land transparently.** When Claude Opus 5 or a successor model arrives, the harness adapter swaps the model; the workflow skill body does not change, because it never encoded model-specific prompting.

### Negative

- **More upfront design discipline.** Authors cannot write a workflow skill as "let me drop my favorite prompt into SKILL.md." Every workflow skill requires a real specification step.
- **Initial UX feels less guided than GSD.** GSD's elaborate prompts produce hand-holding conversations out of the box. Chantier's thin contracts leave more interpretation to the harness LLM, which may produce a less consistent experience between harnesses in the short term.
- **Composition rules add cognitive load.** Distinguishing "workflow skill chains another workflow skill" (forbidden) from "workflow skill invokes a micro-discipline skill" (permitted) requires a clear taxonomy maintained in the docs.

### Mitigations

- **Document the workflow vs. domain taxonomy explicitly** in `docs/skill-taxonomy.md` (deferred until the first workflow skill is merged, to ground the taxonomy in concrete examples).
- **Provide a workflow-skill template** in `skills/_templates/workflow/` so that authors start from a contract-shaped skeleton, not a blank file.
- **In the first workflow skill PR**, include a worked example showing how the same skill produces equivalent outputs under Claude Code and Cursor adapters. This becomes the portability reference.

---

## Alternatives considered

### Alternative A — Defer all workflow skills to extract-skills-from-phase

**Description.** Refuse to write workflow skills intentionally. Wait for `extract-skills-from-phase` (v0.3.0) to surface them from real dogfooding, just like domain skills.

**Why rejected.** Workflow skills are structurally different from domain skills (see Context §2). The shape of `plan-phase` is already known from two years of GSD evidence; waiting for it to emerge from extraction is performative purity at the cost of 3–6 months of unnecessary ergonomic friction. The emergence mechanism is the right tool for patterns whose shape is **not yet clear**. Workflow skills are not in that category.

### Alternative B — Port GSD commands 1:1

**Description.** Take GSD's ~80 commands and port each one to a Chantier workflow skill, preserving the same names, scopes, and surfaces.

**Why rejected.** GSD's surface accumulated organically over two years. Approximately 30% of its commands overlap semantically (see Context §3). A 1:1 port would import that dette as a permanent design liability. Chantier has the rare opportunity to set deliberate design constraints **once**, before the surface grows. Surrendering that opportunity for the convenience of name-matching with a predecessor framework would be a strategic error.

### Alternative C — No workflow skills at all; rely on prose docs

**Description.** Ship no workflow skills. Instead, publish a `docs/workflows/` directory describing — in prose, for human readers — how to perform the equivalent of `plan-phase`, `progress`, `verify-phase` in conversation with the user's chosen harness LLM.

**Why rejected.** This is viable for a framework targeting 10–20 expert users who tolerate ambiguity, but Chantier targets broader adoption (see `.planning/PROJECT.md` §"Target user" and the implied scale of `chantier-build` as a multi-Owner org). Without skill enforcement, the experience between two users on the same project diverges to the point where their `STATE.md` and `PLAN.md` outputs are no longer interoperable. The whole point of the ADR 0001 contract is to prevent that divergence. Pure-docs would undermine it.

### Alternative D — Thick prompt-encoded SKILL.md (the GSD pattern)

**Description.** Allow workflow skills whose body is a 1000–3000 line prompt instructing the LLM exactly how to behave. This matches GSD's actual implementation strategy.

**Why rejected (this is Principle 3 inverted).** A thick prompt body is brittle: it encodes assumptions about LLM behavior, conversational style, and even specific tool names. Every model version risks breaking the prompt's expected behavior. Every harness adapter must somehow "interpret" the prompt rather than satisfy a contract. Portability suffers, maintenance compounds, and the skill body becomes unauditable in the `cat` / `jq` / `grep` sense that ADR 0001 §Decision foundationally requires.

---

## Open questions (deferred)

This ADR does **not** decide the following. They are flagged for resolution in subsequent ADRs or in the post-Phase-5 ratification of this ADR:

1. **Workflow skill versioning vs. micro-discipline skill versioning.** When `plan-phase` v0.3.0 invokes `test-driven-development` v0.2.0, how is the compatibility expressed? `chantier.lock`-style pinning (deferred per REQUIREMENTS.md) may answer this, but the answer has to be coordinated with this ADR's Principle 4 (composition rules).

2. **The canonical workflow skill set.** This ADR establishes the principles; it does not enumerate the skills. The candidate list lives in `docs/strategy/maturity-path.md` as a sketch. Each skill will require its own design (and possibly its own ADR for skills that introduce novel patterns).

3. **The `inputs_schema` and `outputs_schema` conventions for workflow skills.** Should workflow skills accept their primary input as a file path, a JSON object on stdin, or a CLI flag? Should outputs be Markdown, JSON, or both? Deferred to the first workflow skill PR (likely `plan-phase`) — the first implementation sets the convention.

4. **Harness adapter responsibilities for workflow skills.** What part of "satisfy the workflow contract" is the adapter's job vs. the LLM's job vs. the skill body's job? The Claude Code adapter from Phase 4 only handles micro-discipline skill dispatch; workflow skills may require richer adapter responsibilities (e.g., conversational orchestration). Deferred to the second adapter PR (v0.2.0) so the question is forced by a second harness, not by speculation.

5. **Discoverability commands.** Should `chantier skill list` and `chantier skill show <name>` be added to the binary, or should they themselves be workflow skills? Not blocking for this ADR but tightly coupled to the workflow surface. Deferred.

---

## Ratification path

This ADR remains in **Proposed** status until:

1. Phase 5 (dogfood-e2e) ships, providing first-person evidence of where the v0.1.0 surface actually hurts.
2. At least one of the v0.2.0+ adapters (Cursor, Codex) is operational, so portability is tested against two harnesses before the first workflow skill is written.
3. A founding contributor (or, post-Org-formed stage, a maintainer) reviews this ADR against the dogfood findings and either:
   - Updates the principles to reflect what was actually learned, then moves status to **Accepted**.
   - Or rejects the principles outright and opens a successor ADR.

Until ratification, this ADR is advisory. The first workflow skill PR should reference this ADR and explicitly call out any deviation, so deviations are visible rather than implicit.

---

## References

- ADR 0001 — The State / Skill Contract — establishes the SKILL.md schema that workflow skills must conform to.
- ADR 0002 — Runtime binary and state format — establishes the validation surface that workflow skills are checked against.
- `docs/vision.md` §Principle 3 — Self-improving by design — frames `extract-skills-from-phase` as the canonical growth mechanism, which this ADR carves out workflow skills from.
- `docs/strategy/maturity-path.md` — companion strategic sketch listing candidate workflow skills and the multi-version path toward v1.0.0.
- `docs/research/inheritance-map.md` §10 — Self-improvement / learning extraction — the original analysis of how skill libraries grow.
