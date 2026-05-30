# Phase 5: Dogfood E2E - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-30
**Phase:** 5-dogfood-e2e
**Areas discussed:** Dogfood feature + skill ; E2E test shape + NFR audits ; ROADMAP migration + cutover ; F1–F4 disposition + skill matrix

---

## Gray area selection (multi-select)

User selected ALL four proposed gray areas:

| Area | Selected |
|------|----------|
| Scénario dogfood + skill | ✓ |
| Forme test E2E + audits NFR | ✓ |
| Migration ROADMAP + cutover GSD | ✓ |
| F1–F4 + matrice skills | ✓ |

---

## Area 1 — Dogfood feature & executing skill

| Option | Description | Selected |
|--------|-------------|----------|
| F3 upstream/ + TDD (Recommended) | Fix F3 (upstream/ symlinks staging on depends_on) via test-driven-development skill. 2-task plan exercising multi-task chain. | ✓ |
| chantier state show --tail + TDD | Small binary feature via TDD. Doesn't touch ADR 0001 contract; doesn't resolve a finding. | |
| 5th skill (receiving-code-review) + subagent-driven-dev | New skill via subagent-driven-development. Heavier; v0.1 caps at 4 skills (FR-009). | |
| ADR 0004 (Surface 3 propagation) + requesting-code-review | Documentation-only; doesn't naturally trigger validate-task gate 5 (skill expects a diff). | |

**User's choice:** F3 upstream/ + TDD
**Notes:** Bundles the F3 fix with the dogfood exercise — the two-task chain that proves F3 is also the loop that proves the framework. Convergence intentional.

---

## Area 2.1 — tests/e2e/ structure

| Option | Description | Selected |
|--------|-------------|----------|
| Bats unique + tmp project (Recommended) | tests/e2e/full_loop.bats: creates tmp project via `chantier new`, writes synthetic PLAN.md, dispatches via stub, validates. SC#1 literal compliance. | ✓ |
| Sous-projet fixture pre-canned + driver | tests/e2e/fixtures/dogfood-project/ pre-written. Doesn't test `chantier new` (potential SC#1 violation). | |
| Mix : tmp pour new, fixture pour PLAN | Hybrid. More complexity for little gain. | |

**User's choice:** Bats unique + tmp project
**Notes:** `chantier new` must be invoked by the test itself per SC#1 wording "full new-project → plan → execute → verify loop".

---

## Area 2.2 — Adapter dispatch (stub vs real)

| Option | Description | Selected |
|--------|-------------|----------|
| Stub défaut + CHANTIER_E2E_REAL_CLAUDE opt-in (Recommended) | CHANTIER_CLAUDE_BIN stub by default (NFR-004, offline CI strict). CHANTIER_E2E_REAL_CLAUDE=1 unsets stub, real claude -p invoked for local validation. | ✓ |
| Stub only | No real-claude hook. Simpler but loses local validation option. F2 stays 100% v0.2. | |
| Real par défaut, stub opt-in | Inverse. Violates NFR-004 by default. Inacceptable. | |

**User's choice:** Stub défaut + CHANTIER_E2E_REAL_CLAUDE opt-in
**Notes:** Same pattern as Phase 4 D-15. The env gate is v0.1's contribution to F2 — wire ships now, use lands v0.2.

---

## Area 2.3 — NFR-001..006 audit shape

| Option | Description | Selected |
|--------|-------------|----------|
| Un fichier consolidé (Recommended) | core/tests/nfr_audits.bats with 6 @test groups, one per NFR. Reuses existing patterns. Path: core/tests/ (audit) distinct from tests/e2e/ (workflow). | ✓ |
| Six fichiers bats séparés | More granular but fragments suite, duplicates boilerplate. | |
| Extension chantier --self-test | Runtime/audit coupling violates ADR 0002 separation. | |
| Réutiliser existant + ajouter manquants | Loses readability of "one file = SC#4". | |

**User's choice:** Un fichier consolidé
**Notes:** SC#4 → file mapping is obvious. Six @test groups make independence explicit.

---

## Area 3.1 — ROADMAP migration shape

| Option | Description | Selected |
|--------|-------------|----------|
| Minimaliste : nettoyer marqueurs GSD (Recommended) | Strip "Format note" callout + GSD-parser conventions. Keep narrative + ADR 0001-conformant frontmatter. Audit-friendly diff. | ✓ |
| Restructuration vers YAML-first | Rewrite body in pure YAML. Loses narrative readability. Breaks Markdown convention. | |
| Validation enforced par binary | Add `chantier validate-roadmap`. Scope creep — binary doesn't ship new verbs in v0.1. | |

**User's choice:** Minimaliste : nettoyer marqueurs GSD
**Notes:** Narrowest diff possible. Frontmatter already validates against `core/schemas/roadmap.json` (Phase 2 D-06).

---

## Area 3.2 — Cutover timing

| Option | Description | Selected |
|--------|-------------|----------|
| Commit final + event cutover.completed (Recommended) | Migration + GSD invocation removal = final commit of Phase 5 per SC#5 literal. cutover.completed event records the historic point. Prior STATE.md history not rewritten. | ✓ |
| Avant l'exécution dogfood | Migrates before dogfood execution. Violates SC#5 "final commit". Loses symbolic moment. | |
| Sans event explicite (silencieux) | No STATE.md event. Loses historic marker; incoherent with phase.completed / adr.accepted pattern. | |

**User's choice:** Commit final + event cutover.completed
**Notes:** Matches the project's existing pattern of marking transitions explicitly in STATE.md. The `bootstrap.harness.chosen` event (2026-05-29T18:30:00Z) gets its bookend.

---

## Area 4.1 — F1–F4 findings disposition

| Option | Description | Selected |
|--------|-------------|----------|
| F3 (= feature dogfood) + F1 ADR 0004 Proposed (Recommended) | F3 = dogfood feature (cf Area 1). F1 = ADR 0004 codifies Surface 3 propagation, status Proposed (ratification post-Phase 5). F2/F4 stay v0.2 explicit. | ✓ |
| Tous les 4 (F1+F2+F3+F4) | F2 = scope creep (needs API key + CI gate, declared v0.2). F4 = no failure signal yet. Too broad. | |
| Seulement F3, skip ADR 0004 | F1 risks getting lost in Phase 4 plan 03 SUMMARY without codification. | |
| Aucun fix, juste audits + migration | "One small feature" becomes ambiguous (nothing real to plan→execute→verify). | |

**User's choice:** F3 + F1 ADR 0004 Proposed
**Notes:** ADR 0004 mirrors ADR 0003's "Proposed until lived-experience evidence" pattern. Discovered-then-codified is becoming a Chantier convention.

---

## Area 4.2 — Skill matrix coverage in tests/e2e/

| Option | Description | Selected |
|--------|-------------|----------|
| Skill unique (TDD) (Recommended) | tests/e2e/full_loop.bats exercises only TDD via adapter. The other 3 skills are proven via Phase 3 skill_*_e2e.bats (direct) and the adapter pattern is proven via Phase 4. Matrix-via-adapter is mechanical extension v0.2 per Phase 3 D-17. | ✓ |
| Matrice 4-skills via adapter | 4 skills, each via adapter in its own @test. Duplicates coverage. Slows CI. Not justified for v0.1. | |
| Matrice 2-skills (TDD + autre) | Mid-range without clear criterion for the "other". Arbitrary. | |

**User's choice:** Skill unique (TDD)
**Notes:** Explicit non-scope. Planner must not extend coverage opportunistically; v0.2 mechanical extension when second adapter ships.

---

## Claude's Discretion

The following implementation-level decisions remain open to planner / researcher refinement (verbatim from CONTEXT.md §"Claude's Discretion"):

1. PLAN.md task pair shape for the F3 dogfood (task IDs, state_reads/state_writes paths, inputs blocks, acceptance bullets).
2. The F3 fix shape inside `adapters/claude-code/run-task.sh` (symlink full upstream task dir vs per-file output.json).
3. PLAN.md `depends_on` ordering enforcement (adapter topo-sort vs operator dispatches in order).
4. ADR 0004 exact prose (status Proposed; codified contract per Phase 4 plan 03 fix).
5. `nfr_audits.bats` shellcheck invocation shape (per-file loop vs find ... | xargs).
6. NFR-005 non-English glyph regex (UTF-8 class vs hand-rolled accented set).
7. `cutover.completed` event refs payload (include `bootstrap.harness.chosen` timestamp back-ref?).
8. Whether to extract the CHANTIER_CLAUDE_BIN stub into a shared test_helper or duplicate inline.
9. Synthetic project name used in `chantier new` inside the e2e test.
10. Phase 5 `phase.completed` event via adapter or direct binary append.
11. Concurrency lock for parallel `run-task.sh` (Phase 4 carry-forward; not exercised by design in Phase 5).

---

## Deferred Ideas

Captured in CONTEXT.md §"Deferred Ideas". Summary list:

- Second harness adapter (v0.2.0)
- F2 (real-claude dispatch path in CI) — env gate ships, use is v0.2
- F4 (strict worktree validation) — v0.2 unless dogfood signal
- 5th reference skill — FR-009 cap
- `chantier validate-roadmap` and `chantier task-lookup` subcommands — v0.2+
- YAML-first ROADMAP rewrite — too disruptive for v0.1
- Matrix-via-adapter coverage — v0.2 mechanical extension (Phase 3 D-17)
- ADR 0003 ratification — post-Phase 5
- ADR 0004 ratification — requires second adapter
- STATE.md compaction — post-v0.1 (ADR 0001 OQ #2)
- `extract-skills-from-phase` — v0.3.0
- Concurrency lock for parallel run-task.sh
- `CHANTIER_TRANSCRIPT=1` transcript gate
- Workflow skill authoring (per maturity-path.md sketch)
- `--self-test` extended to cover six NFRs (rejected: coupling)
- Other tests/ subdirectories beyond `tests/e2e/`
