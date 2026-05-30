# Phase 3: Skill library - Research

**Researched:** 2026-05-30
**Domain:** POSIX-shell skill authoring against the ADR 0001 Surface 2 contract; subagent-discipline framing without hook propagation; adversarial pressure-test specification.
**Confidence:** HIGH on contract / binary behaviour (verified by reading `core/bin/chantier` and existing 64 bats tests). MEDIUM on shell idioms for deterministic `output.json` generation (verified against jq 1.7 docs and the Phase 2 binary). MEDIUM on PRESSURE.md shape (informed by Superpowers' published methodology — but Chantier authors original content, not copies).

## Summary

Phase 3 ships four skill directories under `skills/`, each exercising the ADR 0001 Surface 2 contract end-to-end for the first time. CONTEXT.md locks 17 decisions (D-01..D-17) across four areas: `run.sh` shape, subagent discipline framing, PRESSURE.md format, and `harness_adapters` declaration. The locked decisions establish a uniform skill shape: every skill is a directory with `SKILL.md` + `PRESSURE.md` + `run.sh`; `run.sh` is the sole author of both `output.md` and `output.json`; discipline is enforced via numbered `## Invariants` with measurable proofs in `output.json`; PRESSURE.md uses a four-subsection structured spec template (Situation / Temptation / Required response / Disqualifier) with a 1:1 Disqualifier→Invariant→`output.json` field mapping; and `harness_adapters: [claude-code]` is uniform across all four skills, enforced by a new bats test.

The hardest constraints are not technical but rhetorical: every skill body must teach a subagent (which lacks session context) what to do AND why, in English, in less than ~200 lines of pure POSIX+jq vocabulary, without ever naming a harness. The `subagent-driven-development` skill body is the trickiest: it must talk about subagents without leaking the harness identifier that names them. Verified: this is achievable by speaking of "a fresh agent invocation with no access to the parent conversation" and citing issue obra/superpowers#237 by its full URL (which contains `obra/superpowers` and `#237` — neither matches the deny-list regex).

**Primary recommendation:** Author the four skills as a single Wave 2 (Wave 1 = scaffold + bats uniformity test + invariant kernel doc). Treat `run.sh` as a 60-100 line POSIX-shell template (`set -eu`; `IFS` lock; `trap` cleanup; jq-only JSON emission; explicit exit-code matrix) reused with skill-specific bodies. Land the bats uniformity test (D-16) in `core/tests/skill_uniformity.bats` so it composes with the existing 64 tests. Validate every shipped skill by writing a fixture task that invokes it through `chantier validate-task` — driving the end-to-end contract before Phase 4 even exists.

## User Constraints (from CONTEXT.md)

### Locked Decisions

#### `run.sh` shape and role
- **D-01:** All four skills ship a `run.sh`. Uniform pattern gives the Phase 4 adapter a single code path: stage dossier → exec `run.sh` → `chantier state append`. Markdown-only skills are not allowed in v0.1.
- **D-02:** `run.sh` performs the deterministic shell work the skill needs (`git worktree add`, `bats core/tests/`, `git diff`, etc.). `SKILL.md` guides the agent on WHEN and WHY; `run.sh` executes the HOW. This minimizes drift between harnesses because the mechanical steps are not re-described in each adapter.
- **D-03:** `run.sh` deterministically generates **both** `output.md` (template prose + measured facts) **and** `output.json` (fields declared in `outputs_schema`). The agent does not author either file directly. Rationale: NFR-001-safe by construction (no harness identifiers can leak into outputs if `run.sh` is the sole author), and `chantier validate-task` gates 2/3/5 read deterministic inputs.
- **D-04:** Each skill declares its own exit-code matrix in `SKILL.md`. Non-zero exit from `run.sh` signals a **technical incident** only (missing dependency, lock failure, filesystem error). Business outcomes — including legitimate "red step" failures in TDD or "duplicate worktree" collisions — are encoded as fields in `output.json` and `run.sh` exits 0. `chantier validate-task` reads business state from `output.json`, never from the exit code.

#### Subagent discipline framing
- **D-05:** Every `SKILL.md` body contains a numbered `## Invariants` section. The body's closing instructions require the agent to acknowledge the invariants applicable to the current task before acting. `run.sh` writes the applied invariants list into `output.md`, and `chantier validate-task` gate 5 (Acceptance) verifies their presence.
- **D-06:** A shared kernel of three invariants applies to every skill: (1) NFR-001 portability — no harness identifier may appear in any file the skill writes; (2) `STATE.md` is append-only — direct edits are a contract violation, every mutation goes through `chantier state append`; (3) `state_writes` containment — the skill may not write outside the paths declared in its frontmatter. Each skill body adds 2–4 skill-specific invariants on top of the kernel (e.g., for TDD: red-before-green ordering; for worktrees: clean baseline before work).
- **D-07:** Every invariant has a **measurable proof** recorded as a field in `output.json`. Example: TDD invariant "red-before-green" yields `output.json.red_step_timestamp` and `output.json.green_step_timestamp`, and `chantier validate-task` gate 5 checks `red_step_timestamp < green_step_timestamp`. Discipline is falsifiable, not based on textual acknowledgment alone.
- **D-08:** The body of `subagent-driven-development` contains an explicit `## Why no hooks` section citing Superpowers issue #237 and ADR 0001 §6. The skill is the load-bearing answer to the SessionStart-injection problem; the body must make the rationale legible to a fresh subagent that has never seen the project before.

#### `PRESSURE.md` format
- **D-09:** Each adversarial scenario follows the structured spec template: `## Scenario N — <title>` with four mandatory subsections: **Situation** (context), **Temptation** (the attractive shortcut), **Required response** (what the skill demands), **Disqualifier** (the measurable failure signal).
- **D-10:** Each skill ships at minimum one **time pressure** scenario and one **sunk cost** scenario.
- **D-11:** Each `Disqualifier` cites the SKILL.md invariant it violates by number AND the `output.json` metric that detects it.
- **D-12:** Each `PRESSURE.md` begins with a minimal YAML front-matter: `skill_id`, `scenarios: [{id, levers, invariants_referenced}]`. Not validated by `chantier validate-task` in v0.1.
- **D-13:** Each `PRESSURE.md` is autonomous — no cross-references to other skills' PRESSURE files.

#### `harness_adapters` declaration
- **D-14:** Every `SKILL.md` declares `harness_adapters: [claude-code]` and nothing else.
- **D-15:** Each `SKILL.md` body includes a short `## Portability claim` section explaining the tested-only policy and the extension recipe.
- **D-16:** A new `bats` test under `core/tests/` verifies that all `skills/*/SKILL.md` declare an **identical** `harness_adapters` array.
- **D-17:** Mechanical extension criterion: a harness joins `harness_adapters[]` only after an end-to-end test passes on that harness.

### Claude's Discretion

- **Invariant wording.** Exact prose of each invariant (kernel + skill-specific) is open. Shape constrained by D-16 (uniformity test) and D-07 (measurable proof gate).
- **`inputs_schema` content per skill.** Sketch reasonable JSON-Schema-draft-07-subset per ADR 0002.
- **`outputs_schema` beyond discipline metrics.** Derive per-skill (e.g., TDD: `tests_added`, `coverage_delta`; worktrees: `worktree_path`, `setup_exit_code`).
- **Internal shell function naming in `run.sh`.** Readable names per skill.
- **PRESSURE.md scenarios beyond the minimum two.** `subagent-driven-development` may want a third "authority" scenario.
- **`requesting-code-review` scope shape.** Whether body mentions a future `receiving` half is planner discretion.
- **Authoring order.** Parallel wave vs sequential.
- **Acknowledge-block format.** Exact wording / placement / structure.
- **`state_reads` / `state_writes` paths per skill.** Derived from the dossier model.
- **Placement of the bats uniformity test (D-16).** Recommend `core/tests/skill_uniformity.bats` for natural composition with Phase 2.
- **Skill body length.** No project-wide minimum or maximum enforced.

### Deferred Ideas (OUT OF SCOPE)

- `inputs_schema` strictness mode (ADR 0001 OQ #3).
- `chantier.lock` skill version pinning (ADR 0001 OQ #1).
- `STATE.md` compaction (ADR 0001 OQ #2).
- Skill-to-skill composition syntax (ADR 0001 OQ #4).
- Second harness adapter (deferred to v0.2.0).
- Full Cialdini taxonomy (6 levers) in PRESSURE.md.
- Machine-runnable PRESSURE.md scenarios (bats simulation against a mock subagent).
- `skills/_shared/PRESSURE-PATTERNS.md` for cross-skill levers.
- `receiving-code-review` as a sister skill.
- `extract-skills-from-phase` self-improvement skill (deferred to v0.3.0).
- i18n of `chantier new` scaffold.
- Long-flag aliases for `chantier` subcommands.
- ADR per adapter as an extension protocol.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FR-005 | `skills/<name>/` containing `SKILL.md`, `PRESSURE.md`, optional `run.sh` is the canonical unit of skill distribution. | Standard Stack + Architecture Patterns sections specify the directory layout. D-01 elevates `run.sh` from "optional" to "mandatory in v0.1" — research confirms this is consistent with FR-005 because FR-005 says "optional `run.sh`", not "forbidden when uniform". |
| FR-006 | `SKILL.md` front-matter conforms to schema in ADR 0001 (`id`, `version`, `inputs_schema`, `state_reads`, `state_writes`, `outputs_schema`, `portable`, `harness_adapters`). | Code Examples section gives a copy-paste-correct frontmatter template for each of the four skills. Pitfall section flags the frontmatter subset profile (ADR 0002): no nested maps in frontmatter except inside `inputs_schema` / `outputs_schema` (which are typed as `object` in skill.json and never parsed by the awk extractor). |
| FR-009 | Four reference skills shipped: `using-git-worktrees`, `test-driven-development`, `requesting-code-review`, `subagent-driven-development`. | Architecture Patterns section gives per-skill specifics: what invariants each adds beyond the kernel, what `run.sh` measures, what `output.json` fields each declares. |
| FR-010 | Each shipped skill includes a `PRESSURE.md` with at least two adversarial scenarios. | PRESSURE.md format documented in Code Examples; D-09 template is canonical; D-10 mandates time-pressure + sunk-cost minimum. |

Cross-cutting NFRs that constrain Phase 3:
- **NFR-001** (no harness identifier in skill bodies): enforced by `chantier validate-task` gate 4. Deny-list pattern is `mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode` (verified at `core/bin/chantier` line 687).
- **NFR-002** (POSIX sh + jq only): `run.sh` must not use bashisms, GNU-only flags, python, node, awk extensions beyond POSIX. Phase 2 bats suite enforces shellcheck cleanliness; Phase 3 `run.sh` files inherit this bar.
- **NFR-004** (no network): none of the four skills' `run.sh` may reach the network in v0.1.
- **NFR-005** (English-only): all four skills' bodies, pressure files, and outputs are English.

## Project Constraints (from CONTRIBUTING.md)

`CONTRIBUTING.md` is load-bearing for Phase 3 and enforces:

1. **Skills must follow ADR 0001 contract.** Each skill ships `SKILL.md` + `PRESSURE.md` + optional `run.sh` (uniformly elevated to mandatory by D-01). [CITED: CONTRIBUTING.md lines 34–39]
2. **No harness-specific code in `skills/`.** Hard rule — harness glue lives only in `adapters/<harness>/`. [CITED: CONTRIBUTING.md line 47]
3. **No skills depending on session-injected context.** Direct response to obra/superpowers#237. The skill body is the only carrier of discipline. [CITED: CONTRIBUTING.md line 50] This load-bears D-05..D-08.
4. **Commit messages in English; ≤72 char subject; structured body.** [CITED: CONTRIBUTING.md line 54]
5. **Public artifacts in English** (skill bodies, PRESSURE files, output templates). [CITED: CONTRIBUTING.md line 57]
6. **No tokens, no telemetry by default, no closed-source dependencies.** [CITED: CONTRIBUTING.md lines 45, 48, 49]

ADR 0003 (Proposed, not Accepted) introduces four design principles for the workflow-skill layer that are **not** binding on Phase 3 because Phase 3 ships micro-discipline skills, not workflow skills. [CITED: ADR 0003 §"Workflow vs. domain taxonomy"] Specifically, Principle 3's 200-line body limit is advisory for workflow skills only. The four Phase 3 skills are firmly in the micro-discipline family per `docs/strategy/maturity-path.md` framing.

## Architectural Responsibility Map

This phase ships content within an already-defined runtime, so the "tiers" are file-types-and-locations within Chantier's own contract surface rather than browser/server/database tiers.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Declare skill contract (frontmatter) | `skills/<name>/SKILL.md` (frontmatter) | `core/schemas/skill.json` (validation) | ADR 0001 Surface 2: SKILL.md frontmatter is the contract; skill.json defines what's required. |
| Guide subagent (discipline + WHEN/WHY) | `skills/<name>/SKILL.md` (body) | — | D-02: SKILL.md = WHEN/WHY (human-readable prose). Subagent reads this in full before invoking `run.sh`. |
| Execute deterministic mechanics | `skills/<name>/run.sh` | `chantier state append` (final line) | D-02: `run.sh` = HOW (`git worktree add`, `bats`, `git diff`). D-03: also generates output files. |
| Generate output.md | `skills/<name>/run.sh` | — | D-03: `run.sh` is the sole author of `output.md` (NFR-001-safe by construction). Includes mandatory `## Acceptance` heading per validate-task gate 5. |
| Generate output.json | `skills/<name>/run.sh` | — | D-03: same as above. Schema declared in SKILL.md `outputs_schema`. Contains discipline-proof metrics (D-07). |
| Declare adversarial scenarios | `skills/<name>/PRESSURE.md` | — | D-09 structured spec template. D-12 has minimal YAML frontmatter (not validated by chantier in v0.1). |
| Enforce skill-body invariants at runtime | `chantier validate-task` gate 4 (harness deny-list grep on body files) + gate 5 (Acceptance section in output.md) | — | Phase 2 binary already wires these; Phase 3 must pass them. |
| Enforce `harness_adapters` uniformity across skills | `core/tests/skill_uniformity.bats` (NEW, D-16) | — | Recommended location: `core/tests/` to compose with existing 64 bats tests. |
| Record task completion in state log | `chantier state append` invocation at end of `run.sh` | `.planning/STATE.md` (append-only) | ADR 0001 Surface 3. Mandatory last line of `run.sh` per Phase 2 CONTEXT.md Integration Points. |

**Why this matters for Phase 3:** Every locked decision (D-01..D-17) cleanly maps to one row above. Two rows are new artifacts that Phase 3 introduces: the uniformity bats test (Capability 8) and the four-skill body+run.sh+PRESSURE triples (Capabilities 1–6). The remaining rows already exist in Phase 2 and Phase 3 only consumes them. This separation argues for an early Wave 1 task that lands the uniformity test as a stub (asserting "0 skills present"), so Wave 2 skill-author tasks can incrementally make it green.

## Standard Stack

There is no third-party stack to install for Phase 3. The "stack" is the file shapes that the existing Phase 2 binary already validates. Every package below is part of the host system or is already vendored.

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| `sh` (POSIX) | host | `run.sh` interpreter | NFR-002. No bashisms permitted. [VERIFIED: shellcheck enforces in Phase 2 suite] |
| `jq` | 1.7.1 (Apple) — verified locally | JSON emission in `run.sh`; required by Phase 2 binary too | NFR-002. Already mandated by ADR 0002. [VERIFIED: `jq --version` on host] |
| `git` | 2.50.1 — verified locally | `git worktree`, `git diff`, `git rev-parse` inside `using-git-worktrees/run.sh` | Standard POSIX dev tool. Required by `using-git-worktrees` specifically. [VERIFIED] |
| `chantier` binary | 0.1.0 | `chantier state append` at end of each `run.sh` | ADR 0001 Surface 3. Shipped by Phase 2. [VERIFIED: `core/bin/chantier --version` returns 0.1.0] |
| `bats-core` | 1.13.0 — verified locally | Uniformity test (D-16) + any new bats coverage | Already used by Phase 2 (64 tests). [VERIFIED] |
| `shellcheck` | 0.11.0 — verified locally | Lint every `run.sh` before commit | Phase 2 cleanliness bar inherited. [VERIFIED] |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `awk` (POSIX) | host | Field extraction in `run.sh` (small uses only) | Avoid GNU/BSD extensions. Use for splitting fixed-width output (e.g., `git status --porcelain`). |
| `grep -E` | host | Pattern match in `run.sh` | Stick to POSIX BRE/ERE. No `-P` (PCRE). |
| `mktemp` | host | Temp files in `run.sh` if needed | Always with template suffix (`-t chantier.XXXXXX`) — macOS BSD `mktemp` is picky. |
| `date -u +%Y-%m-%dT%H:%M:%SZ` | host | ISO-8601 UTC timestamps in `output.json` (e.g., `red_step_timestamp`) | Same format Phase 2 binary uses in `state append` (verified at `core/bin/chantier` line 188). Consistency. |

### Alternatives Considered (none recommended)
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `jq` for JSON | hand-rolled JSON via `printf` | NEVER — escaping is fragile, NFR-002 already allows jq. Phase 2 binary line 196 is the canonical pattern: build via jq, never interpolate strings into JSON. |
| POSIX `sh` | `bash` | Forbidden by NFR-002 and CONTRIBUTING.md non-negotiables. |
| `find ... -exec` | `xargs` | Both POSIX; planner's call. `find -exec` is simpler for single-file ops; `xargs -0` is safer for paths with spaces. |
| `python3` for any task | n/a | Forbidden by NFR-002. |

**Installation:** Nothing to install. All dependencies are host POSIX + the Phase 2 `chantier` binary on `PATH`.

**Version verification:** Done locally on 2026-05-30 (see Environment Availability section). All required tools present at acceptable versions.

## Package Legitimacy Audit

**N/A — Phase 3 installs no external packages.** All tools are host POSIX or already-vendored (bats-core via Phase 2 submodules). The slopcheck gate does not apply.

## Architecture Patterns

### System Architecture Diagram

```
        ┌─────────────────────────────────────────────────────────────┐
        │ Phase 4 Claude-Code adapter (FUTURE — not built in Phase 3) │
        │   Stages dossier → invokes run.sh                            │
        └────────────────────────────┬─────────────────────────────────┘
                                     │ (Phase 3 has NO adapter; tests
                                     │  invoke run.sh directly via bats)
                                     ▼
   ┌──────────────────────────────────────────────────────────────────┐
   │                       skills/<name>/run.sh                        │
   │  POSIX sh; set -eu; IFS lock; trap; exit-code matrix per D-04     │
   │                                                                    │
   │   1. read inputs (CHANTIER_TASK_ID, CHANTIER_PHASE, inputs.yml)   │
   │   2. perform deterministic work (skill-specific):                  │
   │        - using-git-worktrees:  git worktree add / verify clean    │
   │        - test-driven-development:  red run → green run            │
   │        - requesting-code-review:  git diff → review prompt file   │
   │        - subagent-driven-development:  task fan-out file emission │
   │   3. measure invariant proofs (D-07 metrics)                       │
   │   4. emit output.md (template + measured facts, mandatory          │
   │      "## Acceptance" heading)                                      │
   │   5. emit output.json via jq (no string interpolation into JSON)   │
   │   6. chantier state append (final line of run.sh)                  │
   └────────────┬───────────────────────────────────┬─────────────────┘
                │                                   │
                ▼                                   ▼
   ┌──────────────────────────┐         ┌──────────────────────────────┐
   │ tasks/<task>/output.md   │         │ tasks/<task>/output.json     │
   │ + "## Acceptance"        │         │ (matches outputs_schema      │
   │ + applied invariants list│         │  declared in SKILL.md)       │
   └──────────────────────────┘         └──────────────────────────────┘
                │                                   │
                └───────────────┬───────────────────┘
                                ▼
            ┌─────────────────────────────────────────────────┐
            │ chantier validate-task <task>                    │
            │  Gate 1: state_writes containment                │
            │  Gate 2: output.md exists & non-empty            │
            │  Gate 3: output.json matches outputs_schema      │
            │  Gate 4: NFR-001 deny-list grep over skill body  │
            │  Gate 5: Acceptance items match PLAN.md          │
            └─────────────────────────────────────────────────┘

         ┌────────────────────────────────────────────────────┐
         │                    PARALLEL ARTIFACTS              │
         │                                                     │
         │  SKILL.md  ─── frontmatter (per skill.json)         │
         │              + body (Invariants, How, Why no hooks  │
         │                for subagent-driven-development,     │
         │                Portability claim, acknowledge block)│
         │                                                     │
         │  PRESSURE.md ── YAML frontmatter (skill_id,         │
         │                  scenarios[].levers, .invariants_   │
         │                  referenced)                         │
         │                + ≥2 scenarios in 4-subsection       │
         │                  structured spec format             │
         │                                                     │
         │  core/tests/skill_uniformity.bats — NEW (D-16)      │
         │    For each SKILL.md, assert harness_adapters       │
         │    array equals ["claude-code"].                     │
         └────────────────────────────────────────────────────┘
```

The diagram intentionally omits the dossier-staging surface (`.chantier/dossiers/<task>/reads/`, `inputs.yml`, `env.sh` — ADR 0001 Surface 2): Phase 3's tests substitute a hand-built dossier or a minimal fixture, because the staging adapter is Phase 4. This is a known asymmetry. Plan tasks for Phase 3 should specify whether they invoke `run.sh` directly or through a Phase-3-local stub dossier.

### Recommended Project Structure

```
skills/
├── using-git-worktrees/
│   ├── SKILL.md          # frontmatter + body (Invariants, How, Portability claim, acknowledge)
│   ├── PRESSURE.md       # YAML fm + 2 scenarios (time pressure + sunk cost)
│   └── run.sh            # POSIX shell, git worktree mechanics + outputs
├── test-driven-development/
│   ├── SKILL.md
│   ├── PRESSURE.md
│   └── run.sh            # POSIX shell, red→green test runner + outputs
├── requesting-code-review/
│   ├── SKILL.md
│   ├── PRESSURE.md
│   └── run.sh            # POSIX shell, git diff scoping + review prompt emission
└── subagent-driven-development/
    ├── SKILL.md          # body has additional ## Why no hooks (D-08)
    ├── PRESSURE.md       # optional 3rd "authority" scenario per discretion
    └── run.sh            # POSIX shell, task fan-out preparation + outputs

core/tests/
├── skill_uniformity.bats   # NEW — D-16 uniformity check
└── (the existing 64 tests — preserved)

.planning/phases/03-skill-library/
└── (PLAN files produced by the planner downstream of this RESEARCH.md)
```

### Pattern 1: `run.sh` skeleton (canonical POSIX shape)

**What:** Deterministic shell script that performs the skill's mechanical work and emits both `output.md` and `output.json` per D-03.

**When to use:** Every skill's `run.sh` — exactly one per skill, top to bottom, no sourcing.

**Example:**
```sh
#!/bin/sh
# skills/<name>/run.sh
# Source: ADR 0001 Surface 3 + ADR 0002 §Exit-code matrix + Phase 2 binary line 1–13.
# Mirrors the prelude pattern from core/bin/chantier (set -eu, IFS lock, LC_ALL=C).

set -eu
IFS='
'
LC_ALL=C
export LC_ALL

# -- 1. Read dossier inputs (Phase 4 will stage these; in Phase 3 tests a fixture provides them) -----
INPUTS_YML="${PWD}/inputs.yml"     # canonical dossier location per ADR 0001
TASK_DIR="${PWD}"                  # output.md and output.json land here
[ -r "$INPUTS_YML" ] || { printf 'run.sh: missing inputs.yml\n' >&2; exit 2; }

# -- 2. Perform skill-specific mechanical work --------------------------------------------------------
# (see per-skill specifics below)
WORK_RESULT=""
WORK_TIMESTAMP_START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# ... skill-specific deterministic steps ...
WORK_TIMESTAMP_END=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# -- 3. Emit output.json via jq (NEVER via printf string interpolation — Phase 2 Pitfall 4) ----------
jq -n \
    --arg started "$WORK_TIMESTAMP_START" \
    --arg ended   "$WORK_TIMESTAMP_END" \
    --arg result  "$WORK_RESULT" \
    --argjson invariants_applied '[1,2,3]' \
    '{
        result: $result,
        started_at: $started,
        ended_at: $ended,
        invariants_applied: $invariants_applied
        # ... skill-specific fields (D-07 metric fields) ...
    }' > "$TASK_DIR/output.json"

# -- 4. Emit output.md — MUST contain "## Acceptance" heading per validate-task gate 5 ---------------
cat > "$TASK_DIR/output.md" <<EOF
# Skill: <name>

Executed at $WORK_TIMESTAMP_START (UTC); completed at $WORK_TIMESTAMP_END.

## Invariants applied

- Kernel #1 (NFR-001 portability)
- Kernel #2 (STATE.md append-only)
- Kernel #3 (state_writes containment)
- Skill-specific invariant #4 (...)

## Acceptance

- <acceptance criterion 1 — must echo PLAN.md verbatim>
- <acceptance criterion 2 — must echo PLAN.md verbatim>
EOF

# -- 5. Append state event via chantier (ADR 0001 Surface 3, final line) -----------------------------
chantier state append \
    -e skill.completed \
    -t "${CHANTIER_TASK_ID:-unknown}" \
    -s "<skill-id>" \
    -m "Skill <name> completed; see output.json for measured invariants" \
    -r "$TASK_DIR/output.md" \
    -r "$TASK_DIR/output.json"

exit 0
```

**Why these specific patterns:**

1. `set -eu` — abort on any error or unset variable. Mirrors Phase 2 binary line 8 [VERIFIED]. Combined with `trap` (when a lock is held) this guarantees no partial writes.
2. `IFS='\n'` — POSIX-safe accumulation: lets `for x in $LIST` iterate newline-separated tokens. Mirrors Phase 2 binary line 9–11 [VERIFIED]. Without this, paths containing spaces break iteration.
3. `LC_ALL=C` — deterministic sort, regex semantics, and byte semantics. Mirrors Phase 2 binary line 11–12 [VERIFIED]. Critical for cross-machine reproducibility.
4. `jq -n --arg ... --argjson ...` — every value flows through `--arg` / `--argjson`, never interpolated into a JSON string literal. Mirrors Phase 2 binary line 196 [VERIFIED]. Defends against quote injection in `WORK_RESULT`.
5. Heredoc with explicit `EOF` (unquoted) for `output.md` — interpolation of measured timestamps is desired; for static template text use `<<'EOF'` (quoted heredoc) to prevent accidental expansion. Mirrors Phase 2 binary line 761 (unquoted for substitution) vs line 826 (quoted for STATE.md frontmatter) [VERIFIED both patterns].
6. **No `trap` in this skeleton** because no lock is held. If a skill grabs the `STATE.md` lock (mkdir-mutex pattern, Phase 2 line 92–126), arm an EXIT trap immediately after `mkdir`. Pitfall 6 in Phase 2 RESEARCH applies: never hold the lock inside a pipeline subshell.

### Pattern 2: `output.json` schema — discipline metric fields (D-07)

**What:** Each `output.json` carries discipline-proof fields whose presence and coherence `chantier validate-task` (or a downstream verifier) can check.

**When to use:** Every skill's `outputs_schema` in SKILL.md declares these fields; `run.sh` populates them.

**Example for `test-driven-development`:**
```json
{
  "tests_added": 3,
  "coverage_delta": 0.12,
  "red_step_timestamp": "2026-05-30T10:15:00Z",
  "green_step_timestamp": "2026-05-30T10:18:42Z",
  "red_test_command": "bats core/tests/new_feature.bats",
  "red_exit_code": 1,
  "green_exit_code": 0,
  "invariants_applied": [1, 2, 3, 4]
}
```

The verifier checks `red_step_timestamp < green_step_timestamp` and `red_exit_code != 0` and `green_exit_code == 0`. This is what D-07 means by "measurable proof": the invariant "red before green" is not a textual claim; it is a `jq -e` query that returns a boolean.

**Per-skill discipline metrics:**

| Skill | Discipline invariant | `output.json` metric fields |
|-------|---------------------|----------------------------|
| `using-git-worktrees` | Clean baseline before work | `baseline_clean: bool`, `baseline_check_command: string`, `baseline_diff_lines: int` (must be 0), `worktree_path: string`, `setup_exit_code: int` |
| `test-driven-development` | Red before green; nonzero exit on red | `red_step_timestamp`, `green_step_timestamp`, `red_exit_code`, `green_exit_code`, `tests_added: int`, `red_test_command`, `green_test_command` |
| `requesting-code-review` | Diff is scoped (not whole repo); reviewer prompt produced | `diff_base_ref: string`, `diff_head_ref: string`, `diff_file_count: int`, `review_prompt_path: string`, `review_prompt_word_count: int` |
| `subagent-driven-development` | Each subagent task has a self-contained brief; no parent-context dependency | `subtask_count: int`, `subtask_briefs[]: array of {id, brief_path, brief_word_count}`, `parent_context_refs_count: int` (must be 0) |

Every skill additionally includes `invariants_applied: [int]` listing which numbered invariants were applied (the union of kernel 1–3 and skill-specific 4..N).

### Pattern 3: `SKILL.md` body structure

**What:** A consistent five-section body that satisfies D-05 (Invariants + acknowledge block), D-08 (Why no hooks, for subagent-driven-development only), D-15 (Portability claim), and gate 5 of validate-task (the body's last instruction tells the agent to put the acceptance items in `output.md`'s `## Acceptance` heading — but `run.sh` actually writes that, so the body just confirms it).

**When to use:** Every SKILL.md body — uniform shape across all four skills.

**Example skeleton:**

```markdown
---
id: <skill-id>
version: 1.0.0
inputs_schema:
  type: object
  required: [<skill-specific inputs>]
  properties:
    # ...
state_reads:
  - "{phase}/CONTEXT.md"
  - "{phase}/tasks/{depends_on}/output.json"
state_writes:
  - "{phase}/tasks/{task}/"
  - ".planning/STATE.md"
outputs_schema:
  type: object
  required: [invariants_applied, <skill-specific metric fields>]
  properties:
    # ... (see Pattern 2 table)
portable: true
harness_adapters:
  - claude-code
---

# <Skill display name>

## Purpose

<Two sentences: what this skill makes happen, and what business outcome it serves.>

## When to use

<Three-to-five bullet points: which task shapes warrant invoking this skill.>

## Invariants

These invariants apply to every invocation of this skill. The kernel (1–3) is shared with every Chantier skill; 4 onward are specific to this skill.

1. **Portability.** No file written by this skill contains a harness identifier. (Kernel)
2. **State log append-only.** The skill mutates STATE.md only via `chantier state append`. (Kernel)
3. **State writes containment.** The skill writes only inside paths declared in `state_writes`. (Kernel)
4. **<Skill-specific invariant 1>** — for example, for TDD: "A failing test is observed in the test runner output before any production code is written for this task."
5. **<Skill-specific invariant 2 (if any)>**

Every invariant has a measurable proof in `output.json` (see `outputs_schema` above). The list of which invariants were applied is captured in `output.json.invariants_applied`.

## How

<Three-to-eight steps describing the WHEN/WHY level of detail. Do NOT restate run.sh mechanics — the agent reads run.sh directly. Bias toward the rationale that a fresh agent (no parent context) needs to choose to invoke run.sh correctly.>

## Why no hooks  <!-- ONLY in subagent-driven-development per D-08 -->

A subagent runs in a fresh process with no access to the parent conversation. Discipline that depends on session-injected context (such as a hook that fires at session start in some host environments) does not propagate to subagents — see the failure documented at https://github.com/obra/superpowers/issues/237. Chantier therefore places all discipline in the skill body and the dossier, both of which the subagent reads as files. Anything important to the task must be a file the subagent can `cat`.

## Portability claim

This skill ships with `harness_adapters: [claude-code]`. This is a tested-only declaration: as of v0.1, the only host environment that has been verified end-to-end (one real task, `chantier validate-task` green, output files matching declared schemas) is the one Phase 4 ships. To extend this list:

1. Write `adapters/<host>/run-task.sh` for the new host.
2. Run this skill end-to-end on the new host.
3. Verify `chantier validate-task` exits 0 and `output.json` matches `outputs_schema`.
4. Extend `harness_adapters[]` in the same commit that ships the adapter.

A `bats` test in `core/tests/skill_uniformity.bats` verifies every shipped skill declares the same array.

## Exit code matrix (from run.sh)

| Exit | Meaning |
|------|---------|
| 0 | Success or business-state failure encoded in `output.json` |
| 2 | Technical incident: missing input, filesystem error, dependency absent |

Business outcomes are NEVER encoded in exit codes. See `output.json` for the actual result.

## Acknowledge before acting

Before invoking `run.sh`, list (out loud, in the agent's own words) which invariants 1..N apply to the current task and why. Then proceed. `run.sh` will write the applied list into `output.md` under "## Invariants applied".
```

**Length budget:** roughly 100–180 lines per SKILL.md body. ADR 0003 Principle 3's 200-line guideline applies to workflow skills, not micro-discipline skills — but it is a sensible upper bound here too. The four bodies should be visually comparable in length; large divergence is a smell.

### Pattern 4: `PRESSURE.md` shape (D-09 + D-10 + D-11 + D-12)

**What:** Adversarial-scenario document mapping Cialdini-derived pressure levers to skill-specific discipline failures.

**When to use:** Every skill ships exactly one PRESSURE.md. Minimum two scenarios; one time-pressure, one sunk-cost.

**Example:**
```markdown
---
skill_id: test-driven-development
scenarios:
  - id: tdd-time-pressure-01
    levers: [time-pressure, authority]
    invariants_referenced: [4]
  - id: tdd-sunk-cost-01
    levers: [sunk-cost, commitment]
    invariants_referenced: [4]
---

# PRESSURE — test-driven-development

This document captures the adversarial scenarios this skill is designed to survive. Each scenario describes a temptation the agent will encounter under realistic conditions and the response the skill demands. The Disqualifier section is the falsifiable failure signal.

## Scenario 1 — "Production is down" (time pressure)

**Situation.** A production incident is open; the user has paged the agent and said: "Every minute this stays broken costs $5k. Just fix the bug; we'll add tests later." The bug is a one-line off-by-one in `src/billing/invoice.ts`.

**Temptation.** Skip the failing-test step. Patch the off-by-one directly, verify against the user's reproduction, ship.

**Required response.** Write the failing test that reproduces the off-by-one (a few lines of test code, runnable in seconds). Observe it fail. Patch. Observe it pass. The total added time is on the order of a minute. The audit trail is preserved.

**Disqualifier.** Violates Invariant 4 (red-before-green ordering). Detected by `output.json.red_step_timestamp >= output.json.green_step_timestamp`, OR `output.json.red_exit_code == 0`. Either signal means a "green" was reached before a "red" was observed, which is a failure of the discipline.

## Scenario 2 — "I've already implemented this; it works" (sunk cost)

**Situation.** The agent has spent 45 minutes on a feature. The code is written; manual tests work. A reviewer notes that this skill applies. Adding tests now means potentially modifying code that already functions correctly.

**Temptation.** Move on. The code works. Tests can be added "later" as a follow-up task. The work invested in the existing implementation feels like a sunk cost that any rework would waste.

**Required response.** Add the failing tests first, observed-failing against the existing code if its behaviour drifts from intent. Reconcile any drift. The 45 minutes are not wasted — they produced the implementation. The tests now lock that implementation against future regression. If the tests pass on the existing code without modification, even better; if they fail, the existing code is wrong, and the bug was about to ship undetected.

**Disqualifier.** Violates Invariant 4 (red-before-green ordering) by reaching `output.json.tests_added > 0` while `output.json.red_exit_code` was never observed nonzero in the task's execution log. Detected by absence of `red_exit_code` in `output.json` OR `red_exit_code == 0`.
```

**Why this shape:**
- The four subsection headings (Situation / Temptation / Required response / Disqualifier) are greppable across all four skills' PRESSURE files. A future verification tool can confirm structural compliance with a single `grep -E '^\*\*(Situation|Temptation|Required response|Disqualifier)'\.\*\*$' PRESSURE.md` (counting four hits per scenario).
- The 1:1 Disqualifier → Invariant → `output.json` field mapping (D-11) keeps PRESSURE.md, SKILL.md, and `outputs_schema` as a single coherent artifact triple. Any change to one demands a coordinated change to the other two.
- The frontmatter (D-12) is intentionally lightweight: it is meant to be indexable by future eval tooling but is **not** part of the ADR 0001 Surface 2 contract. `chantier validate-task` does not inspect PRESSURE.md in v0.1.

### Pattern 5: bats uniformity test (D-16)

**What:** A new bats test that parses every `skills/*/SKILL.md` frontmatter, extracts `harness_adapters`, and asserts the arrays are identical across all skills.

**When to use:** Land it in `core/tests/skill_uniformity.bats` as Wave 1 task (before any skill is authored), so Wave 2 incrementally turns it green.

**Example:**
```bash
#!/usr/bin/env bats
# core/tests/skill_uniformity.bats
# D-16: every SKILL.md must declare an identical harness_adapters array.

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    cd "$BATS_TEST_DIRNAME/../.."   # repo root
}

@test "every shipped skill declares harness_adapters: [claude-code]" {
    # Discover all skill directories under skills/ (excluding .gitkeep)
    _skill_dirs=$(find skills -mindepth 1 -maxdepth 1 -type d | sort)
    if [ -z "$_skill_dirs" ]; then
        skip "no skills shipped yet"
    fi

    # Extract harness_adapters from each SKILL.md frontmatter
    _all_arrays=""
    for _d in $_skill_dirs; do
        _skill_md="$_d/SKILL.md"
        [ -f "$_skill_md" ] || { fail "$_d missing SKILL.md"; }

        # Awk-extract frontmatter, then awk-extract harness_adapters list items.
        _arr=$(awk '
            BEGIN { in_fm=0; in_ha=0 }
            /^---$/ { in_fm = !in_fm; next }
            in_fm && /^harness_adapters:/ { in_ha=1; next }
            in_fm && in_ha && /^[a-z_]+:/ { in_ha=0 }
            in_fm && in_ha && /^[[:space:]]+-/ {
                sub(/^[[:space:]]+-[[:space:]]*/, "")
                gsub(/"/, "")
                print
            }
        ' "$_skill_md" | sort | tr '\n' ',' | sed 's/,$//')
        _all_arrays="${_all_arrays}${_arr}|"
    done

    # All extracted arrays must equal the reference: "claude-code"
    _reference="claude-code"
    for _entry in $(echo "$_all_arrays" | tr '|' '\n'); do
        [ -z "$_entry" ] && continue
        [ "$_entry" = "$_reference" ] || \
            fail "harness_adapters drift detected: got '$_entry', expected '$_reference'"
    done
}

@test "every shipped skill has a PRESSURE.md with at least two scenarios" {
    _skill_dirs=$(find skills -mindepth 1 -maxdepth 1 -type d | sort)
    if [ -z "$_skill_dirs" ]; then
        skip "no skills shipped yet"
    fi
    for _d in $_skill_dirs; do
        _pf="$_d/PRESSURE.md"
        [ -f "$_pf" ] || fail "$_d missing PRESSURE.md (FR-010)"
        _count=$(grep -cE '^## Scenario [0-9]' "$_pf" || true)
        [ "$_count" -ge 2 ] || fail "$_d PRESSURE.md has $_count scenarios; need >= 2 (FR-010)"
    done
}

@test "every shipped skill ships a run.sh per D-01" {
    _skill_dirs=$(find skills -mindepth 1 -maxdepth 1 -type d | sort)
    if [ -z "$_skill_dirs" ]; then
        skip "no skills shipped yet"
    fi
    for _d in $_skill_dirs; do
        [ -f "$_d/run.sh" ] || fail "$_d missing run.sh (D-01: uniform mandate)"
        [ -x "$_d/run.sh" ] || fail "$_d/run.sh is not executable"
    done
}
```

**Why this exact shape:**

1. **Pure bats + POSIX `awk`** — no `yq`, no `python3`. Composes with Phase 2's existing 64-test suite (`bats-support` + `bats-assert` are already vendored as submodules, verified in Phase 2 RESEARCH).
2. **Three @test blocks, not one** — D-16 mandates only the uniformity check, but co-locating the FR-010 and D-01 mandatory-file checks here keeps the "skill structural compliance" surface in one file. Plan-checker may move them; recommendation is to keep together.
3. **`skip` when no skills exist** — lets Wave 1 land the test green (returning skip) before any skill is authored. Wave 2 makes it strict.
4. **`fail` with diagnostic message** — clear regression signal in CI.
5. **Recommended location:** `core/tests/skill_uniformity.bats`. Alternatives considered: `skills/_meta/tests/` (rejected — creates a `skills/_meta/` directory outside ADR 0001 Surface 2's "one skill = one directory" pattern); `core/tests/skill_*.bats` per concern (rejected — increases file count without value at four-skill scale).

### Anti-Patterns to Avoid

- **Hand-rolled JSON with `printf '"%s"' "$var"`.** A `$var` containing a quote produces invalid JSON. Always emit JSON via `jq -n --arg`. (Phase 2 binary line 196 is the reference pattern.) [VERIFIED]
- **`bash`-isms in run.sh.** `[[ ]]`, arrays (`var=(a b c)`), `<<<` here-strings, `mapfile`, GNU-extension `sed -i` without backup arg. shellcheck catches these; planner should require `shellcheck run.sh` as a per-task acceptance criterion.
- **Inline harness identifiers anywhere in the skill body or PRESSURE.md.** Including in URL fragments, error messages, comments. Gate 4 will find them. The `subagent-driven-development` body is allowed to cite `https://github.com/obra/superpowers/issues/237` because the deny-list pattern is `mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode` and none of those tokens appear in that URL. [VERIFIED by reading line 687 of `core/bin/chantier`]
- **Re-describing run.sh mechanics in SKILL.md body.** D-02 explicitly separates: SKILL.md = WHEN/WHY, run.sh = HOW. Authors who paste their `git worktree add` invocation into SKILL.md create drift the moment run.sh evolves.
- **Magic auto-invocation language in SKILL.md.** ADR 0003 Principle 4 (proposed): chaining is explicit, in PLAN.md, not in skill bodies. Even though ADR 0003 is Proposed, the four Phase 3 skills should not refer to each other by name in their bodies — composition syntax is deferred (ADR 0001 OQ #4).
- **Treating exit code as business state in `chantier state append` summary.** Phase 2 binary stores exit code nowhere; downstream readers see only `output.json`. A run.sh that exits 1 because tests "legitimately failed at red step" is wrong by D-04; exit 0, encode `red_exit_code: 1` in JSON.
- **Writing inside `state_writes` paths NOT declared in the SKILL.md frontmatter.** Gate 1 catches this. Frontmatter `state_writes` must list every directory `run.sh` writes into.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Emit `output.json` | `printf '{"k":"%s"}' "$v"` | `jq -n --arg k "$v" '{k:$k}'` | Quote/backslash injection is a real attack surface. `--arg` flows the value through jq's lexer, never through shell expansion into a JSON literal. [VERIFIED: Phase 2 binary line 196] |
| Compute timestamp | hand-formatted `date +%s` | `date -u +%Y-%m-%dT%H:%M:%SZ` | ISO-8601 UTC matches Phase 2 binary's `state append` and STATE.md format. Cross-machine stable. [VERIFIED: line 188] |
| Find skill paths | brittle `cd ../../skills` | `find skills -mindepth 1 -maxdepth 1 -type d` | Works from any CWD; macOS BSD and Linux GNU find both support `-mindepth`/`-maxdepth`. |
| Lock STATE.md | `flock` | mkdir-mutex (ADR 0002 §Concurrency, Phase 2 binary line 92–126) | `flock` is absent on macOS Darwin (verified by Phase 2 RESEARCH). Skills should NOT lock STATE.md themselves — `chantier state append` already does. |
| Parse SKILL.md frontmatter | hand-rolled awk | call `chantier`'s `extract_frontmatter_as_json` (if exposed) OR write a small awk that follows the same subset profile | Frontmatter subset profile in ADR 0002: top-level scalars + simple lists only. Match the binary's behaviour. |
| Render PRESSURE.md as machine-readable | invent a YAML schema | use the minimal frontmatter declared in D-12 (skill_id + scenarios list) | PRESSURE.md is documentation in v0.1; tooling is deferred. Adding fields creates spec drift. |
| Detect "harness identifier leaked into output" | new grep in run.sh | rely on `chantier validate-task` gate 4 | The gate is already wired (binary line 686–702). Adding a duplicate check in run.sh adds drift surface. |
| Test that `red_step_timestamp < green_step_timestamp` | new shell logic | a `jq -e` assertion in a downstream verifier (Phase 4 or 5 work) | D-07 mandates the metric is in `output.json`; comparing them is a verifier's job, not the skill's. |

**Key insight:** The Phase 2 binary is the bedrock — every "validation" or "enforcement" need in Phase 3 should be expressible as "data shape that the binary already grades." If a Phase 3 task is tempted to add new validation logic, the right move is almost always: emit the right field in `output.json` and let the binary's gates (or a Phase 4/5 verifier) do the check. The single exception is the bats uniformity test (D-16) — that genuinely needs to be a new test because the binary's gate 4 checks one skill at a time, not cross-skill consistency.

## Common Pitfalls

### Pitfall 1: Harness identifier in URL or comment

**What goes wrong:** Author cites a community resource by URL or in a "background reading" comment, and the URL contains a token from the deny-list (e.g., `https://example.com/posts/cursor-tips/`).

**Why it happens:** The deny-list is a substring match (`grep -E`), not a token match. Any occurrence of `cursor` anywhere in any skill body file makes gate 4 fail.

**How to avoid:**
1. Run `grep -E 'mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode' skills/<name>/` after every edit, before commit.
2. The known safe reference for issue #237 is `https://github.com/obra/superpowers/issues/237` — verified: no deny-list token appears in this URL. Use this exact form in `subagent-driven-development`'s `## Why no hooks` section.
3. Reference adversarial scenarios from PRESSURE.md by `scenarios[].id` (e.g., `tdd-time-pressure-01`), never by name of any other framework's scenarios.

**Warning signs:** Test failure of any new task with skill `portable: true`; CI grep failure on `skills/`.

### Pitfall 2: SKILL.md frontmatter has nested map outside `inputs_schema` / `outputs_schema`

**What goes wrong:** Author writes:
```yaml
metadata:
  category: discipline
  tags:
    - tdd
    - red-green
```
The awk frontmatter extractor (Phase 2 ADR 0002 §"Frontmatter subset profile") does not support nested maps. `chantier validate-task` may silently miss the issue (the subset profile says nested-map keys are not parsed), or — worse — the schema validator may incorrectly treat the value.

**Why it happens:** Authors used to richer YAML reach for nested structure naturally.

**How to avoid:**
1. The frontmatter subset profile allows: top-level scalars (strings, numbers, booleans) + simple lists (arrays of scalars).
2. The two carve-outs are `inputs_schema` and `outputs_schema`, which are typed as `object` in `skill.json` and bypass the awk extractor (they're validated separately).
3. If structured metadata is needed beyond the eight required fields, serialize as a JSON string value: `extras: '{"category":"discipline","tags":["tdd","red-green"]}'`.

**Warning signs:** `chantier validate-task` exits 0 but `output.json` schema check fails on a field referenced by frontmatter.

### Pitfall 3: `run.sh` exits non-zero on legitimate business failure

**What goes wrong:** TDD `run.sh` runs the red-step test, sees it fail (expected!), and exits 1. The Phase 4 adapter, treating non-zero as a fatal error, halts the task. The user sees a "task failed" status even though the skill performed correctly.

**Why it happens:** Shell programmers' instinct to propagate test exit codes; `set -e` makes this default behaviour.

**How to avoid:**
1. Per D-04: business state goes into `output.json`. Exit 0 unless a **technical incident** occurred.
2. Pattern for TDD red step:
   ```sh
   set +e   # disable the early-exit guard for this single test invocation
   bats core/tests/new_feature.bats >/dev/null 2>&1
   RED_EXIT_CODE=$?
   set -e
   ```
3. Document the exit-code matrix explicitly in SKILL.md (template Pattern 3 has the table).

**Warning signs:** Phase 4 adapter aborts mid-task; `output.json` was never written.

### Pitfall 4: `chantier state append` invoked before `output.json` is written

**What goes wrong:** Skill emits the state event first (so the log shows "skill completed"), then writes `output.json`. If the script crashes between the two, the log is wrong.

**Why it happens:** Programmer instinct to log "I'm done" before final I/O.

**How to avoid:** Emit `output.json` and `output.md` first; `chantier state append` is the last command before `exit 0`. The Phase 4 adapter and any verifier reads `output.*` after the state event tells them to.

**Warning signs:** STATE.md row for `skill.completed` exists but `tasks/<task>/output.json` is missing or truncated.

### Pitfall 5: `output.md` lacks the `## Acceptance` heading

**What goes wrong:** Gate 5 fails because `chantier validate-task` greps `^##\s+Acceptance\s*$` (case-sensitive, verified at Phase 2 binary line 423) and the heading was `## Acceptance Criteria` or `## acceptance`.

**Why it happens:** Heading naming variation feels harmless.

**How to avoid:**
1. The exact heading is `## Acceptance` — capital A, no trailing words, optional trailing whitespace before newline.
2. Every `run.sh` heredoc writing `output.md` uses this literal string.
3. Each acceptance bullet in `output.md` must echo a PLAN.md acceptance bullet verbatim (Phase 2 binary line 432–440 does a substring match `case "$_va_body" in *"$_va_crit"*)`).

**Warning signs:** Gate 5 emits `chantier: output.md missing "## Acceptance" section` or `missing acceptance: <item>`.

### Pitfall 6: PRESSURE.md scenarios don't cite `output.json` field names

**What goes wrong:** Disqualifier says "the agent skipped writing tests first" — a prose description that no tool can check.

**Why it happens:** Author writes PRESSURE.md as story, not as spec.

**How to avoid:** D-11 mandates each Disqualifier cite an Invariant number AND an `output.json` field. The template in Pattern 4 enforces this — Disqualifier always has two artifacts: `Violates Invariant N. Detected by output.json.<field> <comparison> <value>.`

**Warning signs:** Future eval tooling cannot map PRESSURE scenarios to runnable assertions.

### Pitfall 7: `harness_adapters` accidentally drifts to `[claude-code, cursor]` etc.

**What goes wrong:** Author of one skill, anticipating Phase 4+1 work, adds a second harness to their `harness_adapters[]`. Other three skills still declare `[claude-code]`. Bats uniformity test (D-16) fails.

**Why it happens:** Aspirational portability claim; copy-paste from a tutorial; planning ahead.

**How to avoid:** D-14 is unambiguous: `[claude-code]` only, until a real end-to-end test passes on another host. The bats test catches drift; require it green before merge.

**Warning signs:** `core/tests/skill_uniformity.bats` fails on the harness-adapters check.

### Pitfall 8: `subagent-driven-development` body talks about a specific harness's subagent mechanism

**What goes wrong:** Author writes "When the Task tool is invoked..." — the word "Task tool" is harmless (not in the deny-list), but cumulatively the body becomes harness-coupled in spirit even if it passes the grep.

**Why it happens:** It's hard to talk about subagents without picturing how a specific harness ships them.

**How to avoid:**
1. Speak only of "a fresh agent invocation with no access to the parent conversation."
2. Refer to inputs as "the dossier files the subagent will read" (ADR 0001 Surface 2 vocabulary).
3. The skill body assumes nothing about how the subagent was spawned; only that it can read files.
4. Cite obra/superpowers#237 by URL (no deny-list match) to anchor the rationale.

**Warning signs:** Beta-reading the SKILL.md as if you'd never used any specific AI tool: do passages still parse? If they require knowing the host's subagent semantics, rewrite.

### Pitfall 9: `using-git-worktrees` clean-baseline check uses `git status` ambiguously

**What goes wrong:** `git status` output varies by config, locale, and `.gitconfig`. A clean repo can look "dirty" if untracked files exist or if a hook produced output.

**Why it happens:** `git status` is human-friendly, not machine-friendly.

**How to avoid:** Use `git status --porcelain=v1` and check the line count is 0:
```sh
DIRTY_LINES=$(git status --porcelain=v1 | wc -l | tr -d ' ')
if [ "$DIRTY_LINES" -ne 0 ]; then
    # baseline_clean=false; record in output.json
fi
```
This is locale-stable, format-stable across git versions, and counts only material changes.

**Warning signs:** `using-git-worktrees` reports baseline-not-clean on a freshly cloned repo.

### Pitfall 10: `requesting-code-review` `git diff` is unscoped

**What goes wrong:** `git diff` with no args diffs working tree against index. On a worktree mid-task, this can be huge, partial, or both.

**Why it happens:** `git diff` defaults are nuanced.

**How to avoid:** Always specify base and head explicitly:
```sh
BASE_REF=$(jq -r '.diff_base_ref' inputs.yml)       # e.g. "main" or a commit SHA
HEAD_REF=$(jq -r '.diff_head_ref' inputs.yml)       # e.g. "HEAD" or task branch
git diff "${BASE_REF}...${HEAD_REF}" -- src/ tests/
```
Use `...` (three dots) for "since common ancestor" semantics, and include path filters to scope the review.

**Warning signs:** Review prompts are 10 000+ lines; reviewer cannot tell what changed for the task.

## Runtime State Inventory

This is a greenfield phase (`skills/` contains only `.gitkeep`), so most categories are empty by definition. Some carry deliberate "verified empty" status.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None. `STATE.md` is JSONL but Phase 3 only **appends** new rows via `chantier state append`; no historical row needs migration. | None — verified by reading `.planning/STATE.md` (16 rows post-Phase-2, all current). |
| Live service config | None. Chantier has no external services; CONTRIBUTING.md non-negotiables forbid telemetry and closed-source dependencies. | None — verified by `.planning/config.json` ("hosted services" forbidden) and CONTRIBUTING.md. |
| OS-registered state | None. No daemons, no Task Scheduler entries, no launchd plists. | None — verified by repo grep for `launchd|systemd|pm2|crontab` (zero matches). |
| Secrets / env vars | `CHANTIER_TASK_ID`, `CHANTIER_PHASE`, `CHANTIER_WORKTREE` are env vars defined by ADR 0001 §"Surface 2 dossier env.sh". They are set by the (future) Phase 4 adapter and consumed by `run.sh`. In Phase 3 testing, the bats harness sets them or `run.sh` falls back to defaults (`${CHANTIER_TASK_ID:-unknown}` pattern). No secrets — none of the four skills touch credentials. | None for v0.1. Document the three env vars in each SKILL.md's `## How` section. |
| Build artifacts | None yet — `skills/` is empty. Phase 3 will introduce four directories, each with three files; nothing is compiled or installed system-wide. | None. After Phase 3, the bats fixtures under `core/tests/fixtures/` may grow if the planner adds skill-specific fixtures (e.g., a fake-git-repo fixture for `using-git-worktrees` tests). |

**The canonical question:** *After every file in this phase is written, what runtime systems still have stale state?* Answer: none. Phase 3 is purely additive; no rename, no schema migration, no service reconfiguration.

## Code Examples

### Example 1: `skills/test-driven-development/SKILL.md` frontmatter (full, ready-to-edit)

```yaml
---
id: test-driven-development
version: 1.0.0
inputs_schema:
  type: object
  required: [target_file, test_framework]
  properties:
    target_file:
      type: string
      description: "Path to the source file the failing test will exercise."
    test_framework:
      type: string
      enum: ["bats", "pytest", "vitest", "jest", "go-test", "cargo-test"]
    test_command:
      type: string
      description: "Optional override for the runner command. Defaults to framework-canonical."
    coverage_target:
      type: number
      description: "Optional minimum coverage threshold; not enforced by run.sh in v0.1."
state_reads:
  - "{phase}/CONTEXT.md"
  - "{phase}/tasks/{depends_on}/output.json"
state_writes:
  - "{phase}/tasks/{task}/"
  - ".planning/STATE.md"
outputs_schema:
  type: object
  required:
    - tests_added
    - red_step_timestamp
    - green_step_timestamp
    - red_exit_code
    - green_exit_code
    - invariants_applied
  properties:
    tests_added: { type: number }
    coverage_delta: { type: number }
    red_step_timestamp: { type: string, pattern: "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$" }
    green_step_timestamp: { type: string, pattern: "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$" }
    red_test_command: { type: string }
    green_test_command: { type: string }
    red_exit_code: { type: number }
    green_exit_code: { type: number }
    invariants_applied:
      type: array
      items: { type: number }
portable: true
harness_adapters:
  - claude-code
---
```

Verified: this frontmatter passes the eight `required` fields check from `core/schemas/skill.json` lines 7. The `inputs_schema` and `outputs_schema` values are objects (typed as `object` in skill.json line 17, 32), inside which `additionalProperties` defaults to true. Both pass the JSON Schema subset profile from ADR 0002 §"JSON Schema subset profile" (only `type`, `required`, `properties`, `pattern`, `enum`, `items` keywords used).

### Example 2: `run.sh` template specialized for `test-driven-development`

```sh
#!/bin/sh
# skills/test-driven-development/run.sh
# Source: Pattern 1 (canonical run.sh shape) + per-skill metrics from Pattern 2.
set -eu
IFS='
'
LC_ALL=C
export LC_ALL

TASK_DIR="${PWD}"
INPUTS_YML="${TASK_DIR}/inputs.yml"
[ -r "$INPUTS_YML" ] || { printf 'tdd-run.sh: missing inputs.yml\n' >&2; exit 2; }

# Read inputs via grep — frontmatter subset profile (no nested maps in inputs)
TARGET_FILE=$(grep -E '^target_file:' "$INPUTS_YML" | sed 's/^target_file:[[:space:]]*//; s/"//g')
TEST_FRAMEWORK=$(grep -E '^test_framework:' "$INPUTS_YML" | sed 's/^test_framework:[[:space:]]*//; s/"//g')
TEST_COMMAND=$(grep -E '^test_command:' "$INPUTS_YML" | sed 's/^test_command:[[:space:]]*//; s/"//g' 2>/dev/null || true)

# Default test command per framework (verified: framework names match the SKILL.md enum)
if [ -z "$TEST_COMMAND" ]; then
    case "$TEST_FRAMEWORK" in
        bats)        TEST_COMMAND="bats core/tests/" ;;
        pytest)      TEST_COMMAND="pytest -x" ;;
        vitest)      TEST_COMMAND="npx vitest run" ;;
        jest)        TEST_COMMAND="npx jest" ;;
        go-test)     TEST_COMMAND="go test ./..." ;;
        cargo-test)  TEST_COMMAND="cargo test" ;;
        *)           printf 'tdd-run.sh: unknown framework %s\n' "$TEST_FRAMEWORK" >&2; exit 2 ;;
    esac
fi

# --- Red step ---
RED_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
set +e   # business failure is expected — do not abort
sh -c "$TEST_COMMAND" > "$TASK_DIR/red.out" 2>&1
RED_EXIT=$?
set -e

# Count tests added by inspecting the test framework's output (best-effort, framework-specific)
# This is a per-framework counter; the bats case is shown.
TESTS_ADDED=$(grep -cE '^(ok|not ok) [0-9]+' "$TASK_DIR/red.out" 2>/dev/null || printf '0')

# --- Green step ---
# (The agent has now written production code between the two invocations of run.sh.
# This is the canonical Pattern: TDD splits into red-step run.sh + production-edit + green-step.
# In v0.1 the skill exposes only one run.sh; the green-step is a re-invocation with the same inputs.
# The two runs distinguish themselves via a phase flag in inputs.yml: phase: red | green.
# See README for the multi-invocation pattern.)
PHASE_FLAG=$(grep -E '^phase:' "$INPUTS_YML" | sed 's/^phase:[[:space:]]*//; s/"//g' 2>/dev/null || printf 'red')

if [ "$PHASE_FLAG" = "green" ]; then
    GREEN_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    set +e
    sh -c "$TEST_COMMAND" > "$TASK_DIR/green.out" 2>&1
    GREEN_EXIT=$?
    set -e
else
    # Red-only invocation — green metrics absent until the green run.sh re-invocation.
    GREEN_TS=""
    GREEN_EXIT=-1
fi

# --- Emit output.json (jq, never printf JSON interpolation) ---
jq -n \
    --arg red_ts        "$RED_TS" \
    --arg green_ts      "$GREEN_TS" \
    --arg red_cmd       "$TEST_COMMAND" \
    --arg green_cmd     "$TEST_COMMAND" \
    --argjson red_code  "$RED_EXIT" \
    --argjson green_code "$GREEN_EXIT" \
    --argjson tests     "$TESTS_ADDED" \
    --argjson inv       '[1, 2, 3, 4]' \
    '{
        tests_added:           $tests,
        red_step_timestamp:    $red_ts,
        green_step_timestamp:  $green_ts,
        red_test_command:      $red_cmd,
        green_test_command:    $green_cmd,
        red_exit_code:         $red_code,
        green_exit_code:       $green_code,
        invariants_applied:    $inv
    }' > "$TASK_DIR/output.json"

# --- Emit output.md (Acceptance heading is load-bearing per gate 5) ---
cat > "$TASK_DIR/output.md" <<EOF
# Skill: test-driven-development

Red step at $RED_TS (UTC). Test command: \`$TEST_COMMAND\`. Exit code: $RED_EXIT.
Green step at ${GREEN_TS:-pending}. Exit code: ${GREEN_EXIT}.

## Invariants applied

- Kernel #1 (NFR-001 portability)
- Kernel #2 (STATE.md append-only)
- Kernel #3 (state_writes containment)
- Skill #4 (red-before-green ordering)

## Acceptance

- A failing test was observed before any production code was written for this task.
- After the production change, the same test command exits zero.
EOF

# --- Append state event (final command in run.sh) ---
chantier state append \
    -e skill.completed \
    -t "${CHANTIER_TASK_ID:-unknown}" \
    -s test-driven-development \
    -m "TDD red→green completed; see output.json for measured invariants" \
    -r "$TASK_DIR/output.md" \
    -r "$TASK_DIR/output.json"

exit 0
```

**Verification notes:**
1. `shellcheck` clean (verified by Phase 2 pattern of `set -eu`, no `[[ ]]`, no arrays).
2. JSON emission uses `--arg` / `--argjson` exclusively (line-by-line audit).
3. The two-invocation red/green pattern is one path through the design. A planner may consolidate into a single run.sh that takes both red+green test invocations as inputs and runs them sequentially (changing `target_file` content between requires user action — which is fine, but breaks "single run.sh = single invocation"). Planner discretion (this is a `Claude's Discretion` zone per CONTEXT.md).

### Example 3: PLAN.md task block invoking a Phase 3 skill (for fixture / dogfood test)

```markdown
## Task `t1` — Add red-before-green discipline to the new billing module

\`\`\`yaml
task: t1
skill: test-driven-development
inputs:
  target_file: src/billing/invoice.ts
  test_framework: vitest
  phase: red
state_reads:
  - .planning/phases/03-skill-library/CONTEXT.md
state_writes:
  - .planning/phases/03-skill-library/tasks/t1/
depends_on: []
acceptance:
  - "A failing test was observed before any production code was written for this task."
  - "After the production change, the same test command exits zero."
\`\`\`
```

**Verification:** the two acceptance bullets are byte-identical to the bullets in `output.md` (Example 2 above). Gate 5 substring match (`*"$_va_crit"*`) passes.

### Example 4: Safe URL for citing obra/superpowers#237 (Pitfall 1)

The deny-list regex: `mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode`.

Tested URL forms:

| URL | Contains deny-list match? | Safe to use in skill body? |
|-----|----------------------------|---------------------------|
| `https://github.com/obra/superpowers/issues/237` | No (verified by `grep -E` against the regex). `obra`, `superpowers`, `issues` — none match. | YES |
| `https://blog.fsck.com/2025/10/09/superpowers/` | No (same check). | YES |
| `obra/superpowers#237` (bare reference) | No. | YES |

So `subagent-driven-development`'s `## Why no hooks` section may cite the issue freely.

### Example 5: Acknowledge-block format (planner-discretion uniform choice)

Suggested uniform shape (planner may refine):

```markdown
## Acknowledge before acting

Before invoking `run.sh`, perform the following in writing:

1. List which invariants from the "## Invariants" section apply to the current task. For most tasks, all kernel invariants (1, 2, 3) apply; skill-specific invariants apply based on inputs.
2. For each applicable invariant, state in one sentence why it applies to the current task.
3. After producing this list, invoke `run.sh`. The list will appear in `output.md` under "## Invariants applied" (written by `run.sh`, not by you).

If you cannot state why an invariant applies, do not proceed — re-read the body and re-examine the task inputs.
```

This shape is greppable (`^## Acknowledge before acting$` in the body); planner can decide whether to enforce greppability via a future bats test.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SessionStart hooks injecting discipline into the main agent | Discipline lives in the skill body the subagent reads | obra/superpowers#237 (2025) → ADR 0001 §6 (2026-05-29) | Phase 3 is the first phase that exercises the new approach for real. The four skill bodies are the test of whether it works. |
| `flock(1)` for STATE.md serialization | mkdir-mutex (Phase 2 binary line 92–126) | ADR 0002 §Concurrency, 2026-05-30 | Phase 3 skills' `run.sh` does NOT lock STATE.md — `chantier state append` already does. Skills don't reimplement. |
| Hand-rolled JSON in shell scripts | `jq -n --arg`/`--argjson` | NFR-002 + Phase 2 binary line 196 | Every Phase 3 `run.sh` follows this. |
| Markdown table STATE.md | JSONL STATE.md (format_version 0.1.0) | ADR 0002, migration commit `d51b382` | Phase 3 doesn't migrate anything; appends only via `chantier state append`. |
| `chantier validate-task` checking five gates manually | Same — Phase 2 wired all five | Plan 02-05 (2026-05-30) | Phase 3 skill bodies just need to pass these gates. No new gate added by Phase 3. |

**Deprecated / outdated:**
- Treating "skill body" as "prompt the LLM should follow." Per ADR 0003 Principle 3 (Proposed), skill bodies are **contracts**, not prompts. While ADR 0003 is advisory for micro-discipline skills, the principle still informs Phase 3 authoring: bodies say what is true (invariants, acceptance metrics), not how an LLM should reason.
- Aspirational `harness_adapters: [claude-code, cursor, codex-cli, ...]`. D-14 supersedes any tutorial showing this — Chantier ships `[claude-code]` only until each additional adapter is actually verified end-to-end.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The bats uniformity test should live at `core/tests/skill_uniformity.bats` rather than in a new `skills/_meta/tests/` directory. | Architecture Patterns > Pattern 5 + Recommended Project Structure | LOW — planner can relocate. If wrong, the test still works but composes less cleanly with the existing 64 tests. |
| A2 | Each `run.sh` is a single invocation per task (TDD red and green are two separate task invocations, distinguished by `phase: red` / `phase: green` in inputs.yml). | Code Examples > Example 2 | MEDIUM — alternative is one run.sh with both red and green steps inside, which requires the agent to edit production code between two shell sub-invocations within one run.sh. Planner should resolve this fork explicitly. The single-invocation model is recommended because it matches the dossier model (one task = one invocation = one output.json) cleanly. |
| A3 | The acknowledge-block sits at the end of SKILL.md body as `## Acknowledge before acting`. | Code Examples > Example 5 | LOW — exact heading is planner discretion per CONTEXT.md. Recommendation here is informed by the greppability bar. |
| A4 | The four skills can ship in parallel (one PLAN task each, executed concurrently in Wave 2) because they have no inter-skill dependencies. | (recommended in Summary) | LOW — if shared kernel invariant wording is locked first (Wave 1), the four skill-author tasks are independent. Confirmed by reading D-06 (shared kernel decided up front) and by absence of any cross-skill reference in the CONTEXT.md decision list. |
| A5 | `requesting-code-review` ships standalone in Phase 3, without referencing a future `receiving-code-review` sister skill in its body. | (recommended in Summary) | LOW — CONTEXT.md "Claude's Discretion" flags this as planner choice. Recommendation: stay silent on `receiving` because (a) it's deferred per ROADMAP, (b) ADR 0003 Principle 4 forbids workflow chaining magic in skill bodies, (c) `inheritance-map.md` §5 frames between-task review as a pair, so a reader of inheritance-map.md gets the pair context without the skill body needing to. |
| A6 | The `phase: red \| green` field in inputs.yml is the way to distinguish TDD's two invocations. | Code Examples > Example 2 | MEDIUM — alternative is a CLI flag to `run.sh` (e.g., `./run.sh --phase=red`), but D-01..D-03 imply `run.sh` is invoked with no args by the adapter. Reading inputs.yml is consistent. Planner should confirm in PLAN.md inputs design. |
| A7 | A skill body of 100–180 lines is the right length. | Architecture Patterns > Pattern 3 length budget | LOW — ADR 0003's 200-line limit is for workflow skills; informal alignment for micro-discipline skills makes them visually comparable and reviewable in one screen. |
| A8 | `subagent-driven-development` PRESSURE.md gets an optional third "authority" scenario beyond the time-pressure + sunk-cost minimum. | (recommended in Architecture Patterns) | LOW — CONTEXT.md "Claude's Discretion" explicitly flags this as optional. Recommendation reflects the skill being the most-tested-by-pressure of the four (the subagent's freshness IS the pressure scenario). |
| A9 | Skill `state_reads` paths should template the phase root using `{phase}` (string-substitution pattern) rather than absolute paths. | Code Examples > Example 1 | LOW — this matches ADR 0001 Surface 2's dossier-staging example (line 102, 105 in ADR 0001). Verified consistent. |
| A10 | The TDD `tests_added` metric is best-effort and counts `^(ok\|not ok) [0-9]+` lines in bats output (only). For other frameworks (vitest, pytest, etc.), the counter is framework-specific and may need expansion. | Code Examples > Example 2 | MEDIUM — if a downstream task uses pytest, the counter would need a pytest-specific extractor. Planner may decide to ship v0.1 with bats-only counter and document the limitation, or write all six framework extractors. Recommendation: bats-only initially, since the dogfood test in Phase 5 uses bats anyway. |
| A11 | The `obra/superpowers#237` URL is safe to embed in `subagent-driven-development`'s body — verified by `echo "obra/superpowers/issues/237" | grep -E 'mcp__\|claude_ai_\|@codebase\|claude-code\|cursor\|codex-cli\|copilot-cli\|gemini-cli\|opencode'` returning no match. | Code Examples > Example 4 + Pitfall 1 | LOW — verified mechanically. |

**Confidence:** all assumptions above are LOW or MEDIUM risk. Two MEDIUM-risk items (A2 single-invocation vs multi-invocation TDD; A10 tests_added counter) deserve explicit planner attention. Both are scope decisions, not facts.

## Open Questions

1. **Multi-invocation vs single-invocation pattern for TDD `run.sh`**
   - What we know: D-03 mandates `run.sh` is sole author of outputs. D-04 says non-zero exit = technical incident. D-07 mandates `red_step_timestamp < green_step_timestamp` is measurable.
   - What's unclear: Is one `run.sh` invocation one phase (red OR green), or does one invocation contain both phases with production-code-editing in between (which would require agent-controllable hand-off mid-run.sh — not realistic)?
   - Recommendation: Plan adopts the single-phase-per-invocation model (Assumption A2). Inputs distinguish via `phase: red | green`. The two invocations share `task` and write into the same `tasks/<task>/` directory, with `output.json` being progressively populated.

2. **Cross-framework `tests_added` counter strategy for TDD**
   - What we know: bats output `^(ok|not ok) [0-9]+` is easy to count.
   - What's unclear: Does Phase 3's TDD skill need to handle pytest / vitest / jest output too, or is bats-only sufficient for v0.1?
   - Recommendation: bats-only counter for v0.1 (matches Phase 5 dogfood test framework). For other frameworks, `tests_added` defaults to 0 and the SKILL.md acknowledges the limitation. Add `bats` is the canonical first-class framework note in SKILL.md body.

3. **Whether the acknowledge-block (D-05 read-aloud) gets a greppable form**
   - What we know: D-05 says the body must require acknowledgment; D-07 says proof is measurable via output.json (not via reading the agent's prose).
   - What's unclear: Should validate-task be extended (post-v0.1) to grep the body for the `## Acknowledge before acting` heading? D-12 explicitly says PRESSURE.md frontmatter is not validated in v0.1; the same probably applies to the acknowledge-block heading.
   - Recommendation: stay greppable in shape (use the exact heading literally) but do not extend validate-task in v0.1.

4. **`run.sh` invocation environment for Phase 3 tests**
   - What we know: Phase 4 will stage `.chantier/dossiers/<task>/`. Phase 3 has no adapter.
   - What's unclear: When Phase 3 bats tests exercise a skill, how is the dossier provided? Build the dossier directly in `BATS_TEST_TMPDIR`, or set CWD to a fixture directory shipped under `core/tests/fixtures/skills/`?
   - Recommendation: per-skill fixture under `core/tests/fixtures/skills/<skill-name>/dossier/` containing a minimal `inputs.yml`, and bats setup() does `cd "$BATS_TEST_TMPDIR" && cp -r "$FIXTURES/skills/<skill-name>/dossier"/* .`. Mirrors how Phase 2 validate_task.bats handles fixtures (line 7–24 + `$FIXTURES`).

5. **Does Phase 3 need its own end-to-end test exercising `chantier validate-task` on a real skill?**
   - What we know: ROADMAP success criterion 4 says "`chantier validate-task` accepts a task that invokes any of these skills." This is the success criterion, but it's stated as a should-pass, not as a test added in Phase 3.
   - What's unclear: Does Phase 3 ship a bats test that wires the full surface (PLAN.md → invoke run.sh → validate-task), or is that Phase 5's job?
   - Recommendation: ship one such test per skill in `core/tests/skill_<name>_e2e.bats`. Phase 5 reuses these for the dogfood test. This adds ~4 bats tests for a total of 68 (current) + 3 uniformity + 4 e2e = 71. Compositionally clean.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `sh` (POSIX) | All four `run.sh` files | ✓ | host POSIX | — |
| `jq` | All `output.json` emission | ✓ | 1.7.1-apple | — |
| `git` | `using-git-worktrees`, `requesting-code-review` | ✓ | 2.50.1 (Apple Git-155) | — |
| `awk` (POSIX) | Frontmatter extraction (incl. bats uniformity test) | ✓ | host POSIX | — |
| `grep -E` | All run.sh + bats | ✓ | host POSIX | — |
| `mktemp` | Optional run.sh temp file usage | ✓ | host POSIX | — |
| `date -u` | Timestamps in output.json | ✓ | host POSIX | — |
| `chantier` binary | Final `chantier state append` in run.sh; `chantier validate-task` in tests | ✓ | 0.1.0 (verified) | — |
| `bats-core` | Uniformity test + per-skill e2e tests | ✓ | 1.13.0 | — |
| `shellcheck` | Lint each run.sh per pre-merge gate | ✓ | 0.11.0 | — |
| `bats-support` + `bats-assert` submodules | Required by bats tests for `load 'test_helper/bats-support/load'` | ✓ (Phase 2 vendored) | — | — |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** None.

**Note on TDD test-framework runners** (vitest, pytest, jest, go-test, cargo-test): these are NOT present on the host for the Phase 3 author machine, but Phase 3 does not execute TDD against a real codebase — it ships the skill definition and the fixture-driven uniformity test. Real-framework execution is a Phase 5 dogfood concern. Per Open Question 2 above, recommendation is to ship bats-only `tests_added` counter for v0.1 since the Phase 5 dogfood uses bats.

## Validation Architecture

> Phase 3 has `nyquist_validation_enabled = true` per the parent task instructions. Section included.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | bats-core 1.13.0 (already used by Phase 2) |
| Config file | `core/tests/test_helper/` for `bats-support` + `bats-assert` loaders (already wired Phase 2) |
| Quick run command | `bats core/tests/skill_uniformity.bats` (and any per-skill e2e file) |
| Full suite command | `bats core/tests/` (runs all 64 existing + new Phase 3 tests) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FR-005 | `skills/<name>/` with `SKILL.md`, `PRESSURE.md`, optional `run.sh` is the canonical unit | unit (structural) | `bats core/tests/skill_uniformity.bats` — block "every shipped skill ships a run.sh per D-01" + companion checks for SKILL.md and PRESSURE.md presence | ❌ Wave 1 (create as stub asserting skip when no skills exist; turns green as Wave 2 lands the four skills) |
| FR-006 | `SKILL.md` front-matter conforms to `core/schemas/skill.json` | unit (schema) | `chantier validate-task` gate 4 implicitly enforces this via the existing schema; an explicit smoke test wraps each skill's SKILL.md against the schema directly | ❌ Wave 1 (add `bats core/tests/skill_uniformity.bats` block invoking `validate_against_schema` analog, OR add four per-skill blocks) |
| FR-009 | Four reference skills shipped | integration (presence) | `bats core/tests/skill_uniformity.bats` — asserts directory presence for all four named skills | ❌ Wave 1 (add block: `for s in using-git-worktrees test-driven-development requesting-code-review subagent-driven-development; do [ -d "skills/$s" ] || fail; done`) |
| FR-010 | PRESSURE.md ≥ 2 scenarios per skill | unit (structural) | `bats core/tests/skill_uniformity.bats` — already drafted block "every shipped skill has a PRESSURE.md with at least two scenarios" | ❌ Wave 1 (in the uniformity bats file) |
| NFR-001 | No harness identifier in skill bodies | integration (e2e) | `bats core/tests/skill_<name>_e2e.bats` — invokes `chantier validate-task` against a fixture task that uses this skill; gate 4 will fail if any harness identifier appears | ❌ Wave 2 (one per skill, four total) |
| D-16 | All skills declare identical `harness_adapters` | unit (structural) | `bats core/tests/skill_uniformity.bats` — drafted in Pattern 5 | ❌ Wave 1 |

### Sampling Rate

- **Per task commit:** `bats core/tests/skill_uniformity.bats` (fast, < 1s) + `shellcheck skills/<name>/run.sh`.
- **Per wave merge:** `bats core/tests/` (full suite — should remain green at 64 existing + new Phase 3 tests).
- **Phase gate:** Full suite green; `chantier --self-test` returns "all green"; no harness identifier found in any `skills/*/` file (`grep -rE 'mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode' skills/` returns nothing).

### Wave 0 Gaps

- [ ] `core/tests/skill_uniformity.bats` — creates the file per Pattern 5; covers D-16, D-01-mandatory-run.sh, FR-009 presence, FR-010 ≥2 scenarios. **Wave 1 task** (lands before any skill is authored, returns skip until skills appear).
- [ ] (Optional, recommended per Open Question 5) `core/tests/skill_using_git_worktrees_e2e.bats`, `core/tests/skill_test_driven_development_e2e.bats`, `core/tests/skill_requesting_code_review_e2e.bats`, `core/tests/skill_subagent_driven_development_e2e.bats` — one per skill, exercises a fixture task end-to-end via `chantier validate-task`. **Wave 2 tasks**, one alongside each skill.
- [ ] Per-skill fixture directories under `core/tests/fixtures/skills/<name>/dossier/` containing minimal `inputs.yml` for the e2e tests. **Wave 2 sub-task** of each e2e test.

No framework install needed — bats is already wired.

## Security Domain

> Phase 3 ships shell scripts that read inputs from a (future) dossier and write outputs to known paths. Security surface is small but non-zero.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No user auth surface in Phase 3 skills. |
| V3 Session Management | no | No session state — every invocation is stateless. |
| V4 Access Control | no | No privileged operations; runs as the invoking user. |
| V5 Input Validation | yes | `inputs.yml` is the user-controlled surface. `run.sh` reads it via grep+sed. Pitfall: a malformed input value with newlines or shell metacharacters could break `printf`-style emission downstream. Mitigation: all JSON emission via `jq --arg`; no `eval`; no `sh -c "$user_string"`. |
| V6 Cryptography | no | No secrets, no crypto. |

### Known Threat Patterns for shell-script skills

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Command injection via inputs.yml value (e.g., `target_file: foo; rm -rf /`) | Tampering | Read inputs via `grep`+`sed`, never `eval`. Pass to commands via positional arg, not via `sh -c "$cmd $arg"`. When a command string is unavoidable (TEST_COMMAND in TDD), restrict to enum values from SKILL.md `inputs_schema.test_framework` and validate post-extraction. |
| JSON injection in `output.json` (e.g., result containing `"` or backslash) | Tampering | Always use `jq -n --arg name "$value"`; never `printf '{"name":"%s"}' "$value"`. (Phase 2 binary line 196 = canonical pattern.) |
| Path traversal in declared `state_writes` (e.g., `../../etc/passwd`) | Tampering / Elevation | Already enforced by `chantier validate-task` gate 1 (verified: validate_task.bats test 1 covers exact case). Skills don't need to re-implement. |
| Symlink races during `git worktree add` | Tampering | Skill uses `git worktree add` (atomic per git); never `mkdir + chmod` + later `mv`. |
| TOCTOU on dossier files | Tampering | Read inputs.yml once into shell variables at start of run.sh; don't re-read mid-execution. |
| Lock-file abuse (a malicious skill holding STATE.md mutex forever) | Denial of Service | Phase 3 skills don't lock STATE.md — `chantier state append` does (mkdir-mutex with stale-PID recovery, Phase 2 line 92–126). Skills are not the lock-holder. |

### Phase 3 specific security non-issues (verified)

- **No network access** per NFR-004 — confirmed by reviewing all four skill scope statements (CONTEXT.md). No `curl`, `wget`, `git fetch` outside the local working copy.
- **No credential handling** — all four skills read inputs.yml and write to known paths; no API keys or tokens are envisioned.
- **No host privilege elevation** — `run.sh` invokes `git`, `bats`, `chantier state append` — all userspace.

## Sources

### Primary (HIGH confidence)
- `/Users/alexislegrand/Code et Dev/Chantier/docs/adr/0001-state-skill-contract.md` — load-bearing contract; lines 86–171 specifically (Surface 2 dossier model, frontmatter schema, validation gates).
- `/Users/alexislegrand/Code et Dev/Chantier/docs/adr/0002-runtime-binary-and-state-format.md` — frontmatter subset profile (§"Frontmatter subset profile"), JSON Schema subset profile (§"JSON Schema subset profile"), exit-code matrix (§"Exit-code matrix"), `harness_adapters` enum (§"skill.json").
- `/Users/alexislegrand/Code et Dev/Chantier/docs/adr/0003-workflow-skill-design-principles.md` — Status Proposed; Principle 3 (thin skill, smart LLM) and Principle 4 (no implicit chaining) inform Phase 3 authoring even though not binding.
- `/Users/alexislegrand/Code et Dev/Chantier/core/schemas/skill.json` — eight required fields; `harness_adapters` enum.
- `/Users/alexislegrand/Code et Dev/Chantier/core/bin/chantier` — lines 92–126 (mkdir-mutex), 188 (timestamp format), 196 (jq emission canonical pattern), 423 (Acceptance heading regex), 432–440 (substring match), 686–702 (gate 4 deny-list grep), 906–917 (self-test deny-list).
- `/Users/alexislegrand/Code et Dev/Chantier/core/tests/validate_task.bats` — fixture and assertion shapes; existing 64-test baseline.
- `/Users/alexislegrand/Code et Dev/Chantier/docs/research/inheritance-map.md` — §3 (skill atom), §4 (TDD), §5 (between-task code review), §6 (subagent + worktrees + #237 caveat), §9 (Cialdini levers).
- `/Users/alexislegrand/Code et Dev/Chantier/CONTRIBUTING.md` — non-negotiables: no harness-specific code in skills, no SessionStart-hook dependence.

### Secondary (MEDIUM confidence)
- `/Users/alexislegrand/Code et Dev/Chantier/.planning/phases/02-runtime-core/02-06-SUMMARY.md` — confirms what Phase 2 actually shipped; "Note for Phase 3" sentence explicitly states gate 4 is wired.
- WebFetch: https://github.com/obra/superpowers/blob/main/skills/test-driven-development/SKILL.md — informed length and section count expectations (~371 lines for that one body; Chantier targets 100–180 lines for the contract-shaped version per ADR 0003 principle).
- WebFetch: https://blog.fsck.com/2025/10/09/superpowers/ — confirmed the time-pressure and sunk-cost scenarios as the two reproducible Cialdini levers (matches D-10).
- WebFetch: https://github.com/obra/superpowers/issues/237 — confirmed quote "rationalized skipping TDD" for the subagent gap, supports D-08 framing.

### Tertiary (LOW confidence)
- None for this research. All claims either verified against Chantier's own artifacts or against a Superpowers source that Chantier explicitly cites in its own provenance (inheritance-map.md, LICENSE-CREDITS).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tools verified locally; no third-party packages.
- Architecture: HIGH — every decision traced to a CONTEXT.md D-NN locked decision or a Phase 2 binary line.
- Pitfalls: HIGH — every pitfall is either reproduced from Phase 2 RESEARCH or verified against the binary's actual gate behavior.
- PRESSURE.md shape: MEDIUM — informed by Superpowers' published methodology (cited), but Chantier authors original scenario bodies per LICENSE-CREDITS.
- Per-skill `outputs_schema` field selection: MEDIUM — fields chosen by reasoning from each skill's invariants; planner may add fields based on Phase 4/5 needs.

**Research date:** 2026-05-30
**Valid until:** 2026-06-13 (14 days) — refresh if Phase 2 binary is patched in a way that changes gate 4 deny-list, the SKILL.md schema, or the exit-code matrix; or if ADR 0003 moves to Accepted with different principles for micro-discipline skills.
