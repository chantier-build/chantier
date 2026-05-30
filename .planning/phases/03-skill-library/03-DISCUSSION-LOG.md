# Phase 3: Skill library - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `03-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-05-30
**Phase:** 3-Skill library
**Areas discussed:** `run.sh` shape and role, Subagent discipline framing, PRESSURE.md format, `harness_adapters` declaration

---

## `run.sh` shape and role

### Q1 — Existence policy

| Option | Description | Selected |
|--------|-------------|----------|
| All 4 — uniform (Recommended) | Each skill embeds `run.sh`, even minimal. Single code path for the Phase 4 adapter. Phase 2 already anticipated this. | ✓ |
| Only when side-effects | `using-git-worktrees` has `run.sh`; TDD could be markdown-only. Adapter must handle two cases. | |
| None — markdown-only | SKILL.md body is everything. Adapter calls `chantier state append` after. More logic in each adapter. | |

**User's choice:** All 4 ship `run.sh` (uniform).

### Q2 — `run.sh` content beyond final state append

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal glue + declared hooks | Source env, read inputs, call skill entrypoint, write outputs, state append. No real business work in `run.sh`. | |
| Real shell work when relevant (Recommended) | `run.sh` runs deterministic mechanics (`git worktree add`, `bats`, `git diff`). SKILL.md = WHEN/WHY, `run.sh` = HOW. Less drift between harnesses. | ✓ |
| `run.sh` = state append + I/O only | Ultra-thin. All real work goes through harness-native tools. | |

**User's choice:** Real shell work when relevant.

### Q3 — Who produces `output.md` and `output.json`

| Option | Description | Selected |
|--------|-------------|----------|
| `run.sh` generates both (Recommended) | Deterministic outputs from `run.sh`. NFR-001-safe by construction. | ✓ |
| Agent writes `output.md`, `run.sh` produces `output.json` | Human prose + machine-deterministic JSON. Risk of harness identifier leakage. | |
| Hybrid skeleton + agent prose | `run.sh` writes structure; agent fills marked blocks. More flexibility, more grep surface. | |

**User's choice:** `run.sh` generates both.

### Q4 — Exit-code policy on legitimate failure

| Option | Description | Selected |
|--------|-------------|----------|
| Skill-declared exit-code matrix (Recommended) | Each `SKILL.md` documents its matrix. `validate-task` reads business state from `output.json`. Exit ≠ 0 = technical incident only. | ✓ |
| Binary-unified matrix (0/1/2/3) | Inherit `chantier` binary's matrix. Business failure encoded as 0 + flag in `output.json`. | |
| Silence-on-success | Exit 0 = OK; any other code stops. Business vs technical distinction reads from `output.md`. | |

**User's choice:** Skill-declared exit-code matrix.

---

## Subagent discipline framing

### Q1 — How does the body impose discipline without `SessionStart`?

| Option | Description | Selected |
|--------|-------------|----------|
| Verifiable Invariants + read-aloud (Recommended) | Numbered `## Invariants` section + closing acknowledgment requirement. Output.md re-cites; `validate-task` greps presence. | ✓ |
| Self-cited checklist + acceptance | Body has a copy-paste checklist with ✓/✗ items; gate 5 verifies presence. Lighter, less rigor. | |
| Mandatory pre-flight written by `run.sh` | `run.sh` writes a "DISCIPLINE FRAME" header to `output.md` independent of the body. More rigid; less expressive output. | |

**User's choice:** Verifiable Invariants + read-aloud.

### Q2 — Shared vs per-skill invariants

| Option | Description | Selected |
|--------|-------------|----------|
| Shared skeleton + specifics (Recommended) | 3-invariant common kernel (NFR-001, append-only STATE.md, state_writes containment) + 2–4 skill-specific invariants per body. | ✓ |
| Fully per-skill invariants | Each `SKILL.md` defines its invariants from scratch. More expressive, more drift risk. | |
| Externalized shared file | `skills/_shared/INVARIANTS.md` referenced from each `state_reads`. Single source but adds a file outside ADR 0001. | |

**User's choice:** Shared skeleton + specifics.

### Q3 — How to validate the subagent actually applied discipline

| Option | Description | Selected |
|--------|-------------|----------|
| Measurable proof per invariant (Recommended) | Each invariant has a metric in `output.json` (e.g., TDD `red_step_timestamp < green_step_timestamp`). validate-task gate 5 checks existence AND coherence. | ✓ |
| Textual acknowledgment suffices | output.md "Invariants acknowledged" section; validate-task greps the citation. Doesn't distinguish disciplined agent from copy-paste agent. | |
| Cross-skill review | Discipline enforced by paired skills (`requesting-code-review` checks TDD post-hoc). More coupling. | |

**User's choice:** Measurable proof per invariant.

### Q4 — Does `subagent-driven-development` document #237 explicitly?

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit `## Why no hooks` section (Recommended) | Short section citing #237 and ADR 0001 §6. Pedagogy + traceability for new contributors. | ✓ |
| Minimal ADR pointer | One-line "See ADR 0001 §6 for context." Shorter bodies, depends on follow-through. | |
| Pure procedure, no meta | Body talks only about WHAT to do; rationale lives in ADR 0001 + inheritance-map. | |

**User's choice:** Explicit `## Why no hooks` section.

---

## PRESSURE.md format

### Q1 — Format for adversarial scenarios

| Option | Description | Selected |
|--------|-------------|----------|
| Structured spec (Recommended) | Fixed template per scenario: Situation / Temptation / Required response / Disqualifier. Greppable, comparable, forces explicit disqualifier. | ✓ |
| Narrative case-study (Superpowers style) | 1–3 paragraph stories illustrating the failure mode. More readable; less enforceable. | |
| Machine-runnable (bats-based) | Each scenario = a `pressure/scenario-N.bats` file simulating a mock subagent. Most rigorous; needs fake-harness infrastructure (out of scope v0.1). | |

**User's choice:** Structured spec.

### Q2 — Cialdini taxonomy coverage

| Option | Description | Selected |
|--------|-------------|----------|
| Time pressure + Sunk cost (mini Superpowers) (Recommended) | Each skill ships one of each. Covers the two reproducible levers from Vincent's methodology post. ~8 scenarios in Phase 3. | ✓ |
| Full Cialdini (6 levers) | Full coverage per skill. ~24 scenarios in Phase 3 — heavy authoring load. | |
| Skill-specific axes | Each skill picks its most relevant 2–3 levers. More relevance, less comparability. | |

**User's choice:** Time pressure + Sunk cost.

### Q3 — Disqualifier linked to SKILL.md invariant?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — 1:1 Disqualifier → Invariant mapping (Recommended) | Each Disqualifier cites the violated SKILL.md invariant by number AND the `output.json` metric. Couples PRESSURE ↔ SKILL ↔ validate-task. | ✓ |
| No — free-form prose | Disqualifier is prose, no formal invariant reference. More flexible, less traceable. | |
| Partial — italic mention | "*Invariants violated: 2, 4.*" line in italic. Trade-off, no metric cited. | |

**User's choice:** 1:1 Disqualifier → Invariant mapping.

### Q4 — Front-matter for `PRESSURE.md`

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal front-matter declaring levers (Recommended) | YAML: `skill_id`, `scenarios: [{id, levers, invariants_referenced}]`. Greppable, not validated by chantier in v0.1. | ✓ |
| No front-matter — pure markdown | PRESSURE.md is 100% prose. No machine index. | |
| Full front-matter with inline invariants | Frontmatter copies invariants. Very redundant with SKILL.md. | |

**User's choice:** Minimal front-matter declaring levers.

### Q5 — Cross-skill PRESSURE references

| Option | Description | Selected |
|--------|-------------|----------|
| No — each `PRESSURE.md` autonomous (Recommended) | Duplicate scenarios across skills when a lever applies to multiple. No cross-references. Subagent reads one file. | ✓ |
| Yes — cross-references allowed | Allowed to cite another skill's PRESSURE scenario. Avoids duplication; creates read-dependencies. | |
| Future `skills/_shared/PRESSURE-PATTERNS.md` | Externalize Cialdini levers into a shared file. DRY but adds a non-ADR-0001 file; defer to v0.2 if needed. | |

**User's choice:** Each `PRESSURE.md` autonomous.

---

## `harness_adapters` declaration

### Q1 — Policy for the `harness_adapters` field

| Option | Description | Selected |
|--------|-------------|----------|
| Tested-only — `[claude-code]` (Recommended) | Each skill declares only what is actually tested. Honest operational claim. Extends after each successful adapter E2E. | ✓ |
| Aspirational — all 6 enum values | All six harnesses listed upfront. Signals ambition; unverified claim. | |
| Pragmatic subset | List harnesses with the right primitives (claude-code, codex-cli, cursor). Compromise, requires per-skill rationale. | |

**User's choice:** Tested-only — `[claude-code]`.

### Q2 — Documenting extensibility

| Option | Description | Selected |
|--------|-------------|----------|
| Note in `SKILL.md` body + ADR-ready (Recommended) | Short `## Portability claim` section in every body with the extension recipe. Inline guidance for contributors. | ✓ |
| Externalized in a future ADR | No mention in `SKILL.md`. ADR 0003 will document the protocol when the 2nd adapter ships. Bodies lighter; less discoverable for v0.1. | |
| `skills/README.md` central explainer | Single file explains the policy for all 4 skills. Less duplication but adds a file outside ADR 0001. | |

**User's choice:** Note in `SKILL.md` body + ADR-ready.

### Q3 — Machine test for `harness_adapters` uniformity

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — `bats` enforces uniformity (Recommended) | Test parses `skills/*/SKILL.md`, checks all `harness_adapters` arrays are identical. Catches accidental drift. | ✓ |
| No — independence per skill | Each skill may legitimately diverge. The first adapter in Phase 4 surfaces divergences by construction. | |
| Non-blocking warning | bats `--warn-only` flags divergence. Trade-off, classic silent-drift risk. | |

**User's choice:** `bats` enforces uniformity.

### Q4 — Extension criterion for adding a harness

| Option | Description | Selected |
|--------|-------------|----------|
| Mechanical: E2E test passes = extend (Recommended) | Objective rule, no subjective judgment. Criterion lives in the `## Portability claim` section. Phase 4 adds `claude-code` after its own E2E. | ✓ |
| ADR per adapter | Each new adapter needs an ADR. Heavyweight, justified only if architectural decisions are non-trivial. | |
| Contributor discretion | No formal rule. Risk of drift. | |

**User's choice:** Mechanical E2E-test criterion.

---

## Claude's Discretion

None of the questions had an explicit "you decide" answer — the user chose a concrete option in all 17 question turns. However, several implementation-level decisions were intentionally left to the planner per the workflow's downstream-awareness contract:

- Invariant wording (kernel + skill-specific) — D-05, D-06 constrain shape, not prose.
- `inputs_schema` content per skill — sketched at plan time, strictness deferred per ADR 0001 OQ #3.
- `outputs_schema` fields beyond discipline metrics.
- Internal shell function naming in `run.sh`.
- PRESSURE.md scenarios beyond the mandatory two per skill.
- `requesting-code-review` scope shape (single vs paired with future `receiving`).
- Authoring order of the four skills (parallel wave vs sequential).
- Acknowledge-block format / placement / structure.
- `state_reads` / `state_writes` paths per skill.
- Placement of the bats uniformity test (D-16).
- Skill body length.

See `03-CONTEXT.md` §"Claude's Discretion" for the full list.

## Deferred Ideas

See `03-CONTEXT.md` §"Deferred Ideas" for the complete list. Highlights:

- `inputs_schema` strictness mode (ADR 0001 OQ #3).
- `chantier.lock` skill version pinning (ADR 0001 OQ #1).
- STATE.md compaction (ADR 0001 OQ #2).
- Skill-to-skill composition syntax (ADR 0001 OQ #4).
- Second harness adapter (REQUIREMENTS §Out of scope v0.1).
- Full Cialdini taxonomy (6 levers) — only 2 in v0.1.
- Machine-runnable PRESSURE scenarios (bats against mock subagent) — markdown spec only in v0.1.
- `skills/_shared/PRESSURE-PATTERNS.md` — defer to v0.2 if duplication becomes painful.
- `receiving-code-review` as a sister skill — candidate for v0.2.
- `extract-skills-from-phase` (already deferred to v0.3.0).
- ADR per adapter as an extension protocol — rejected in favor of mechanical E2E criterion.
