# Phase 3: Skill library - Pattern Map

**Mapped:** 2026-05-30
**Files analyzed:** 18 (15 new, 1 new fixture-class × 4, 2 modified)
**Analogs found:** 18 / 18 (greenfield phase but all patterns inherit from Phase 2 binary, Phase 2 bats suite, ADR 0001, and ADR 0002 — every new file has a load-bearing analog in-tree)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `skills/using-git-worktrees/SKILL.md` | skill-contract (frontmatter doc) | static document, schema-validated | `core/schemas/skill.json` (schema) + RESEARCH.md Example 1 (template) | template-match (no prior SKILL.md in tree) |
| `skills/using-git-worktrees/PRESSURE.md` | skill-doc (adversarial scenarios) | static document, not validated v0.1 | RESEARCH.md Pattern 4 (template) | template-match (greenfield artifact class) |
| `skills/using-git-worktrees/run.sh` | skill-executable (POSIX shell entry) | dossier-read → mechanical-work → output emit → state append | `core/bin/chantier` lines 1–13 (prelude), 92–126 (lock+trap, optional), 196 (jq emission), `state_append` lines 188 (timestamp), 207 (final write) | role-match (binary is shell, not a skill, but uses identical idioms) |
| `skills/test-driven-development/SKILL.md` | skill-contract | static, schema-validated | same as above + RESEARCH.md Code Examples §1 | template-match |
| `skills/test-driven-development/PRESSURE.md` | skill-doc | static | RESEARCH.md Pattern 4 §"Scenario 1 — Production is down" + §"Scenario 2 — sunk cost" (canonical exemplar) | exemplar (worked example in RESEARCH) |
| `skills/test-driven-development/run.sh` | skill-executable | red→green test runs → output | RESEARCH.md Code Examples §2 (fully worked example) + `core/bin/chantier` line 196 (jq), 188 (timestamp), 207 (write) | exemplar |
| `skills/requesting-code-review/SKILL.md` | skill-contract | static | same template path | template-match |
| `skills/requesting-code-review/PRESSURE.md` | skill-doc | static | Pattern 4 template | template-match |
| `skills/requesting-code-review/run.sh` | skill-executable | git diff (scoped) → review prompt file → outputs | `core/bin/chantier` (idioms) + RESEARCH.md Pitfall 10 (canonical `git diff` invocation) | role-match |
| `skills/subagent-driven-development/SKILL.md` | skill-contract (+ `## Why no hooks` per D-08) | static | same template + RESEARCH.md Example 4 (safe URL for #237) | template-match |
| `skills/subagent-driven-development/PRESSURE.md` | skill-doc (≥2 scenarios, optional 3rd "authority") | static | Pattern 4 template | template-match |
| `skills/subagent-driven-development/run.sh` | skill-executable | subtask brief fan-out → outputs | `core/bin/chantier` (idioms); subject to deny-list grep — no `claude-code`, `cursor`, etc. in body | role-match |
| `core/tests/skill_uniformity.bats` | bats test (cross-skill structural) | file-discover → frontmatter parse → assert | `core/tests/validate_task.bats` lines 1–24 (setup/loaders), 89+ (helper fns) + RESEARCH.md Pattern 5 (worked example) | role-match + exemplar |
| `core/tests/skill_using_git_worktrees_e2e.bats` | bats test (end-to-end per skill) | fixture mount → invoke run.sh → invoke `chantier validate-task` | `core/tests/validate_task.bats` (canonical fixture+invoke shape) | role-match |
| `core/tests/skill_test_driven_development_e2e.bats` | bats test (e2e) | same | `core/tests/validate_task.bats` | role-match |
| `core/tests/skill_requesting_code_review_e2e.bats` | bats test (e2e) | same | `core/tests/validate_task.bats` | role-match |
| `core/tests/skill_subagent_driven_development_e2e.bats` | bats test (e2e) | same | `core/tests/validate_task.bats` | role-match |
| `core/tests/fixtures/skills/<name>/dossier/inputs.yml` × 4 | bats fixture (static dossier) | static input file | `core/tests/fixtures/output.valid.md`, `PLAN.valid.md` (existing fixture layout) | role-match |
| `.planning/phases/03-skill-library/03-SUMMARY.md` | phase-close document | static markdown | `.planning/phases/02-runtime-core/02-06-SUMMARY.md` (canonical precedent shape) | exact |
| `.planning/STATE.md` (append) | JSONL state log (modified) | append-only event row via `chantier state append` | Phase 2 binary `state_append` flow (lines 133–209); appended via `chantier state append -e phase.completed ...` | exact |
| `.planning/ROADMAP.md` (modified) | roadmap annotation (handled by gsd-sdk orchestrator) | static annotation | n/a — orchestrator concern, not executor work | n/a |

## Pattern Assignments

### `skills/<name>/run.sh` (skill-executable, dossier-read → work → emit → state append)

**Analog:** `core/bin/chantier` — the binary itself is the canonical POSIX-shell-with-jq idiom for this project. Every `run.sh` mirrors its prelude, locking discipline (when applicable), timestamp format, and JSON emission strategy.

**Imports / prelude pattern** (`core/bin/chantier` lines 1–13):

```sh
#!/bin/sh
# Copyright (c) 2026 Chantier Contributors
# SPDX-License-Identifier: MIT
#
# chantier -- portable state/skill runtime (POSIX sh, no bashisms)
# Single-file binary. No sourcing. No bashisms. Mkdir-lock for concurrency.

set -eu
IFS='
'
LC_ALL=C
export LC_ALL
```

Every `run.sh` MUST begin with the identical four-line discipline (`set -eu`; literal newline `IFS`; `LC_ALL=C`; `export LC_ALL`). The license header is REQUIRED on every shipped shell file in-tree (verified: binary has it). This is the only acceptable prelude shape for Phase 3 — anything else fails the "POSIX, no bashisms, deterministic locale" bar set in NFR-002 and confirmed by Phase 2.

**Timestamp idiom** (`core/bin/chantier` line 188):

```sh
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

Every `run.sh` uses this EXACT format for any timestamp it writes to `output.json` (e.g., `red_step_timestamp`, `green_step_timestamp`, `worktree_setup_started_at`). ISO-8601 UTC, second precision, trailing `Z`. Matches the STATE.md `ts` field byte-for-byte so cross-artifact joins are exact.

**JSON emission canonical pattern** (`core/bin/chantier` lines 194–205, the load-bearing `state_append` JSONL-line builder):

```sh
# Build the JSONL line via jq (all values flow through --arg, never eval'd — T-02-04-INJ)
# -c produces compact single-line JSON (correct JSONL format; tostring would double-encode)
LINE=$(
    printf '%s\n' "$REFS" \
    | jq -R -s -c --arg ts "$TS" --arg ev "$EVENT" --arg ac "$ACTOR" \
              --arg ta "${TASK:-}" --arg sk "${SKILL:-}" --arg sm "$SUMMARY" \
        'split("\n") | map(select(length>0))
         | { ts: $ts, event: $ev, actor: $ac,
             task: (if $ta=="" then null else $ta end),
             skill: (if $sk=="" then null else $sk end),
             summary: $sm, refs: . }'
)
```

EVERY value flows through `--arg` (string) or `--argjson` (pre-parsed JSON). NEVER `printf '{"k":"%s"}' "$v"`. The `T-02-04-INJ` marker in the comment is the Phase 2 traceability anchor for the JSON-injection threat — Phase 3 `run.sh` inherits this defence. `output.json` emission in each skill MUST use `jq -n` (no input) with the same `--arg`/`--argjson` discipline; compact `-c` is optional for `output.json` (pretty-print acceptable since it is read by humans and by `jq -e`, both of which accept either).

**Final-line `state append` invocation** (skills' last action, per ADR 0001 Surface 3 + RESEARCH.md Pattern 1 step 5):

```sh
chantier state append \
    -e skill.completed \
    -t "${CHANTIER_TASK_ID:-unknown}" \
    -s "<skill-id>" \
    -m "<skill <name> completed; see output.json for measured invariants>" \
    -r "$TASK_DIR/output.md" \
    -r "$TASK_DIR/output.json"

exit 0
```

`output.md` and `output.json` are written BEFORE this call (Pitfall 4). `${CHANTIER_TASK_ID:-unknown}` fallback is required — the binary already accepts the literal `unknown` actor (verified `core/bin/chantier` line 189: `ACTOR=$(git config user.name 2>/dev/null || printf 'unknown')`). Repeat `-r` flags for each output file, per the `state_append` getopts loop (`core/bin/chantier` line 165: `r) REFS="${REFS}${REFS:+$NL}${OPTARG}"`).

**Exit-code discipline** (per D-04 + RESEARCH.md Pitfall 3):

Skills MUST `exit 0` on business-state failures (e.g., red-step test failing in TDD, baseline-dirty in worktrees). Business state goes in `output.json`. Non-zero exits ONLY for technical incidents (missing `inputs.yml`, jq absent, filesystem errors). The pattern for capturing a child process's exit code without aborting:

```sh
set +e   # disable early-exit guard for this single invocation
sh -c "$TEST_COMMAND" > "$TASK_DIR/red.out" 2>&1
RED_EXIT=$?
set -e
```

This pattern is shown in RESEARCH.md Code Examples §2 lines 880–883 and is the only POSIX-correct way to capture a non-zero exit when `set -e` is active.

**Optional: heredoc patterns for `output.md`** (`core/bin/chantier` lines 761 unquoted vs 826 quoted):

- Unquoted `<<EOF` when interpolating measured values (timestamps, paths): `cat > output.md <<EOF\n...$VAR...\nEOF`.
- Quoted `<<'EOF'` for static template text (e.g., a literal Acceptance bullet that must echo PLAN.md verbatim): prevents accidental `$` expansion.

The `output.md` heading `## Acceptance` is load-bearing (gate 5, see Shared Pattern below).

---

### `skills/<name>/SKILL.md` (skill-contract, static schema-validated document)

**Analog:** `core/schemas/skill.json` (the schema each SKILL.md frontmatter MUST satisfy) + RESEARCH.md Code Examples §1 (full worked frontmatter for `test-driven-development`).

**Required frontmatter fields** (`core/schemas/skill.json` line 7):

```json
"required": ["id", "version", "inputs_schema", "state_reads", "state_writes", "outputs_schema", "portable", "harness_adapters"]
```

All eight MUST be present. Field constraints from the schema:

- `id`: `^[a-z][a-z0-9-]*$` (kebab-case, starts with lowercase letter). The four shipped skill IDs (`using-git-worktrees`, `test-driven-development`, `requesting-code-review`, `subagent-driven-development`) all satisfy this — verified by inspection.
- `version`: `^[0-9]+\.[0-9]+\.[0-9]+$` (semver triple). All four ship at `1.0.0`.
- `inputs_schema`, `outputs_schema`: `type: object` — internal structure NOT parsed by the binary's awk frontmatter extractor (Pitfall 2). Per ADR 0002 JSON Schema subset profile, only `type`, `required`, `properties`, `pattern`, `enum`, `items` keywords are valid.
- `state_reads`, `state_writes`: array of strings; the `state_writes` paths are checked by validate-task gate 1 for containment under repo root (`core/bin/chantier` lines 597–631).
- `portable`: boolean. All four Phase 3 skills declare `portable: true` (this triggers gate 4 deny-list scan of body files).
- `harness_adapters`: array, items enum-constrained to `["claude-code", "cursor", "codex-cli", "copilot-cli", "gemini-cli", "opencode"]`. D-14 mandates `[claude-code]` uniformly.

**Body structure pattern** (RESEARCH.md Pattern 3, applies to all four SKILL.md bodies uniformly):

The body MUST have these sections in this order (D-05 + D-15; D-08 only for `subagent-driven-development`):

1. `# <Skill display name>`
2. `## Purpose` (2 sentences)
3. `## When to use` (3–5 bullets)
4. `## Invariants` — numbered list; kernel 1–3 + skill-specific 4..N
5. `## How` (3–8 steps at WHEN/WHY level, not HOW mechanics)
6. `## Why no hooks` — **ONLY** in `subagent-driven-development/SKILL.md` (D-08). Cite `https://github.com/obra/superpowers/issues/237` exactly — RESEARCH.md Example 4 verifies this URL passes the deny-list grep.
7. `## Portability claim` (D-15 boilerplate, ~4 numbered extension steps)
8. `## Exit code matrix (from run.sh)` (per-skill table per D-04)
9. `## Acknowledge before acting` (RESEARCH.md Example 5 shape; closes the body)

**Kernel invariants prose** (D-06; identical text across all four SKILL.md files for invariants 1–3):

1. **Portability.** No file written by this skill contains a harness identifier. (Kernel)
2. **State log append-only.** The skill mutates STATE.md only via `chantier state append`. (Kernel)
3. **State writes containment.** The skill writes only inside paths declared in `state_writes`. (Kernel)

Each skill adds 1–3 skill-specific invariants numbered 4..N. Every invariant has a measurable proof field in `output.json` (D-07).

**Length budget:** 100–180 lines per body (RESEARCH.md Pattern 3 + Assumption A7). The four bodies should be visually comparable in length.

---

### `skills/<name>/PRESSURE.md` (skill-doc, adversarial scenarios)

**Analog:** RESEARCH.md Pattern 4 + Code Examples adversarial-scenario block (lines 471–506 — fully worked exemplar for `test-driven-development`).

**Frontmatter pattern** (D-12):

```yaml
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
```

Minimal YAML — `skill_id` + `scenarios` array. NOT validated by `chantier validate-task` v0.1 (D-12). Frontmatter subset profile rules apply (no nested maps outside arrays-of-objects which are tolerated since this is documentation, not contract).

**Scenario structure pattern** (D-09 — four mandatory subsections, identical shape across all skills):

```markdown
## Scenario N — <title> (<lever>)

**Situation.** <Concrete context — who, where, what's happening, what just went wrong.>

**Temptation.** <The attractive shortcut. Why it looks rational in the moment.>

**Required response.** <What the skill demands. Often: "do the thing the skill enforces, even though X minutes feels expensive.">

**Disqualifier.** Violates Invariant <N> (<short invariant name>). Detected by `output.json.<field>` <comparison> <value>.
```

The Disqualifier subsection MUST cite (1) the invariant number, (2) the invariant's short name, (3) the `output.json` field that detects the violation, (4) the comparison and reference value. This is D-11. Greppable across all four PRESSURE files with `grep -E '^\*\*(Situation|Temptation|Required response|Disqualifier)\*\*'`.

**Minimum coverage** (D-10): Each PRESSURE.md ships at least one **time-pressure** scenario AND one **sunk-cost** scenario. `subagent-driven-development` may add a third "authority" scenario per Claude's Discretion (RESEARCH.md Assumption A8).

**Autonomy rule** (D-13): no cross-references between PRESSURE.md files. If a lever applies to multiple skills, duplicate-and-contextualize, do not centralize.

---

### `core/tests/skill_uniformity.bats` (bats test, cross-skill structural)

**Analog:** `core/tests/validate_task.bats` (canonical bats setup + assertion idiom; 350 lines, 16 tests, Phase 2 baseline) + RESEARCH.md Pattern 5 (fully worked uniformity test, lines 519–591).

**Setup pattern** (`core/tests/validate_task.bats` lines 7–24):

```bash
setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    export CHANTIER="$BATS_TEST_DIRNAME/../bin/chantier"
    export FIXTURES="$BATS_TEST_DIRNAME/fixtures"
    mkdir -p "$BATS_TEST_TMPDIR/home"
    cd "$BATS_TEST_TMPDIR/home"
    # Canonicalize TMPHOME to avoid macOS /var -> /private/var symlink mismatch.
    export TMPHOME
    TMPHOME=$(pwd -P)
    mkdir -p "$TMPHOME/.planning"
    cat > "$TMPHOME/.planning/STATE.md" <<'EOF'
---
format_version: 0.1.0
---
EOF
}
```

For `skill_uniformity.bats`, the setup differs: the test reads the live `skills/` tree, not a fixture. The setup is therefore shorter: just `load` the two helpers and `cd "$BATS_TEST_DIRNAME/../.."` to repo root. RESEARCH.md Pattern 5 shows this shape on lines 525–529.

**Per-test assertion idiom** — RESEARCH.md Pattern 5 (canonical exemplar) is reproduced verbatim and is the executor's reference. Key shape: discover skills with `find skills -mindepth 1 -maxdepth 1 -type d`; `skip` if none exist (so Wave 1 lands green before any skill body is authored); `fail` with diagnostic message for any drift.

**Three @test blocks** to ship in this single file (RESEARCH.md Pattern 5 — co-locates the structural-compliance surface):

1. `@test "every shipped skill declares harness_adapters: [claude-code]"` — D-16.
2. `@test "every shipped skill has a PRESSURE.md with at least two scenarios"` — FR-010. Uses `grep -cE '^## Scenario [0-9]'` count.
3. `@test "every shipped skill ships a run.sh per D-01"` — D-01. Checks `[ -f run.sh ]` and `[ -x run.sh ]`.

Optional additional blocks (per RESEARCH.md Validation Architecture):
- `@test "every shipped skill's SKILL.md has Acknowledge before acting heading"` — D-05 acknowledge-block presence check (planner discretion).
- `@test "no harness identifier in any skill body file (gate-4 mirror)"` — runs `grep -rE` over `skills/` for the deny-list. Mirrors the binary's gate 4.

---

### `core/tests/skill_<name>_e2e.bats` × 4 (bats test, end-to-end per skill)

**Analog:** `core/tests/validate_task.bats` — same setup pattern as above; same `run` / `[ "$status" -eq 0 ]` assertion idiom for `chantier validate-task` invocation.

**Test shape** (per RESEARCH.md Open Question 5 recommendation):

```bash
@test "<skill-name>: end-to-end through chantier validate-task" {
    # 1. Mount fixture dossier into TMPHOME
    cp -r "$FIXTURES/skills/<name>/dossier"/* .
    # 2. Build a minimal PLAN.md with one task that invokes the skill
    #    (mirrors make_plan helper from validate_task.bats lines 29-71)
    make_plan_invoking_skill "<skill-name>" "<task-id>"
    # 3. Stage the dossier where the skill expects to find it
    cd ".planning/phases/test-phase/tasks/<task-id>"
    cp "$FIXTURES/skills/<name>/dossier/inputs.yml" .
    # 4. Invoke the skill's run.sh
    run sh "$TMPHOME/skills/<name>/run.sh"
    [ "$status" -eq 0 ]
    [ -f output.md ]
    [ -f output.json ]
    # 5. Validate via chantier validate-task
    cd "$TMPHOME"
    run "$CHANTIER" validate-task "<task-id>"
    [ "$status" -eq 0 ]
}
```

The fixture dossier shape (`core/tests/fixtures/skills/<name>/dossier/inputs.yml`) is per-skill — content sketched in RESEARCH.md Pattern 2 per-skill table.

---

### `core/tests/fixtures/skills/<name>/dossier/inputs.yml` × 4 (bats fixture, static input)

**Analog:** `core/tests/fixtures/output.valid.md` and `core/tests/fixtures/PLAN.valid.md` — existing fixture layout (file in `core/tests/fixtures/` directly, no subdirectory). Phase 3 introduces a deeper structure (`fixtures/skills/<name>/dossier/`) to mirror the ADR 0001 Surface 2 dossier model. This is a minor extension, justified by ADR 0001 §"Surface 2 dossier" specifying `inputs.yml` lives at `<dossier>/inputs.yml`.

**Content pattern** (per RESEARCH.md Pattern 2, derived from each skill's `inputs_schema`):

```yaml
# core/tests/fixtures/skills/test-driven-development/dossier/inputs.yml
target_file: "src/billing/invoice.ts"
test_framework: "bats"
phase: "red"
```

```yaml
# core/tests/fixtures/skills/using-git-worktrees/dossier/inputs.yml
branch_name: "feature/test-task"
setup_command: "true"  # no-op for fixture
base_ref: "main"
```

```yaml
# core/tests/fixtures/skills/requesting-code-review/dossier/inputs.yml
diff_base_ref: "main"
diff_head_ref: "HEAD"
scope_paths: ["src/", "tests/"]
```

```yaml
# core/tests/fixtures/skills/subagent-driven-development/dossier/inputs.yml
subtask_count: 2
parent_brief: "Implement payment provider integration"
```

The frontmatter subset profile applies here too: simple scalars and flat string lists only.

---

### `.planning/phases/03-skill-library/03-SUMMARY.md` (phase-close document)

**Analog:** `.planning/phases/02-runtime-core/02-06-SUMMARY.md` — EXACT precedent shape. Lines 1–40 show the canonical YAML frontmatter (phase, plan, subsystem, tags, dependency_graph, tech_stack, key_files, decisions, metrics) followed by the body sections. Phase 3's SUMMARY mirrors this exactly, substituting:

- `phase: 03-skill-library`
- `plan: "close"` (or a numbered close plan per planner's choice — Phase 2 used `06` because it was the close plan)
- `tags: [skills, pressure, harness-adapters, phase-close]`
- `dependency_graph.requires: [02-06]` (Phase 2's accepted ADR 0002)
- `dependency_graph.provides: [skill-library-v1, four-reference-skills]`
- `key_files.created: [skills/using-git-worktrees/*, skills/test-driven-development/*, skills/requesting-code-review/*, skills/subagent-driven-development/*, core/tests/skill_uniformity.bats, core/tests/skill_*_e2e.bats]`
- `decisions: <synthesis of D-01..D-17 actually shipped>`
- `metrics.duration: ...; metrics.completed: 2026-MM-DD`

Body sections from the Phase 2 precedent: `# Phase 03 Close Summary` (h1), `## What Was Shipped` (per task or per skill), `## Decisions Locked` (recap), `## Test Suite` (bats counts before/after), `## Notes for Phase 4` (handoff).

---

### `.planning/STATE.md` (modified — append event)

**Analog:** Phase 2's `state_append` flow — `.planning/STATE.md` is JSONL and append-only. The single mutation Phase 3 makes is via `chantier state append`, NOT direct edit (Pitfall: direct edits violate Kernel Invariant 2 which Phase 3's own skills enforce).

**Invocation pattern** (from `core/bin/chantier` lines 196–207, the `state_append` flow):

```sh
chantier state append \
    -e phase.completed \
    -t phase-03 \
    -s phase-3-skill-library \
    -m "Phase 3 closed: four skills shipped, uniformity bats test green, validate-task accepts each skill end-to-end" \
    -r .planning/phases/03-skill-library/03-SUMMARY.md \
    -r skills/using-git-worktrees/ \
    -r skills/test-driven-development/ \
    -r skills/requesting-code-review/ \
    -r skills/subagent-driven-development/
```

Matches Phase 2's close pattern (verified in STATE.md row inserted at Phase 2 close — see RESEARCH.md "State of the Art" row 4: "Dogfood state append via binary"). The event name `phase.completed` satisfies the ADR 0002 dotted-namespace regex `^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$` enforced at `core/bin/chantier` lines 177–186.

---

## Shared Patterns

### Acceptance heading (gate 5)

**Source:** `core/bin/chantier` line 423.
**Apply to:** Every `run.sh`'s `output.md` heredoc emission.

```sh
# Verified regex from validate_task verify_acceptance:
# grep -qE '^##[[:space:]]+Acceptance[[:space:]]*$'
```

The literal heading string is `## Acceptance` — capital A, no trailing words, no trailing punctuation, optional trailing whitespace before newline. Every Phase 3 `run.sh` MUST write this exact heading in `output.md`. Each acceptance bullet underneath MUST echo a PLAN.md acceptance bullet verbatim (`core/bin/chantier` lines 432–440 do `case "$_va_body" in *"$_va_crit"*)` — substring match). If the run.sh's heredoc writes "## Acceptance Criteria" or "## acceptance" (lowercase), gate 5 fails.

### Harness deny-list (gate 4)

**Source:** `core/bin/chantier` lines 686–702 (gate 4) + lines 906–917 (self-test).
**Apply to:** Every file in `skills/<name>/` other than `SKILL.md` (the binary scans `find "$_vt_skill_dir" -type f` and skips `SKILL.md` per line 691).

```sh
# Verified deny-list pattern from core/bin/chantier line 687:
_vt_deny_pat='mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode' # HARNESS_DENY_LIST_CHECK
```

Constraints this imposes on every Phase 3 skill body file (`PRESSURE.md`, `run.sh`, any other file in `skills/<name>/`):

- The literal strings `claude-code`, `cursor`, `codex-cli`, `copilot-cli`, `gemini-cli`, `opencode`, `mcp__`, `claude_ai_`, `@codebase` MUST NOT appear anywhere — including comments, URLs, error messages, JSON values written into `output.json`, `printf` strings.
- The carve-out `SKILL.md` is exempted (because `harness_adapters: [claude-code]` is required by `skill.json`).
- The carve-out marker `HARNESS_DENY_LIST_CHECK` in the binary lets the self-test exclude its own line; Phase 3 skill bodies have NO equivalent carve-out — the words simply must not appear.

The known-safe URL form for citing the obra/superpowers#237 finding (used in `subagent-driven-development/SKILL.md` per D-08): `https://github.com/obra/superpowers/issues/237` — verified by `grep -E` against the deny-list (RESEARCH.md Example 4 and Assumption A11).

### State-writes containment (gate 1)

**Source:** `core/bin/chantier` lines 593–631.
**Apply to:** Every SKILL.md `state_writes:` declaration; every `run.sh` write path.

Every directory `run.sh` writes to MUST be declared in `state_writes`. The validate-task gate canonicalizes paths via `cd <parent> && pwd -P` and rejects paths that resolve outside repo root. Phase 3 skills' canonical `state_writes`:

```yaml
state_writes:
  - "{phase}/tasks/{task}/"
  - ".planning/STATE.md"
```

The `{phase}/{task}` template-substitution syntax is consistent with ADR 0001 §"Surface 2 dossier" examples (RESEARCH.md Assumption A9). The `.planning/STATE.md` declaration is required because `chantier state append` (the final line of every `run.sh`) writes there.

### Event-shape regex (state_append precondition)

**Source:** `core/bin/chantier` lines 177–186.
**Apply to:** Every `chantier state append -e <event>` call inside `run.sh`.

```sh
# Verified shell pre-check pattern:
case "$EVENT" in
    *[!a-z0-9.]*|[!a-z]*|*..*|.*|*.)
        printf 'chantier: event name fails shape regex ^[a-z][a-z0-9]*(\\.[a-z][a-z0-9]*)+$\n' >&2
        exit 1
        ;;
esac
# Authoritative jq check follows on line 185.
```

Skill events MUST satisfy `^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$`. Phase 3 skills use `skill.completed` (matches: starts lowercase, single internal dot, all lowercase). Other valid examples: `skill.failed`, `skill.red_step.completed`. INVALID examples that would fail the regex: `Skill.completed` (uppercase), `.skill.completed` (leading dot), `skill..completed` (double dot), `skill_completed` (no dot — needs at least one).

### mkdir-mutex locking (Phase 3 skills do NOT use this directly)

**Source:** `core/bin/chantier` lines 92–126.
**Apply to:** None of the Phase 3 `run.sh` files acquire this lock themselves. The lock is held only by `chantier state append`, which each skill invokes once at the end. RESEARCH.md "Don't Hand-Roll" row 4 confirms: skills MUST NOT reimplement `flock`-style locking. The mkdir-mutex pattern is shown here only for context — if a future skill needs cross-skill mutual exclusion, this is the pattern (NOT `flock`, which is absent on macOS Darwin):

```sh
# From core/bin/chantier lines 92-126 — for reference only, NOT invoked by Phase 3 skills
acquire_lock() {
    _retries=0
    while [ "$_retries" -le "$LOCK_RETRIES" ]; do
        if mkdir "$LOCKDIR" 2>/dev/null; then
            printf '%s\n' "$$" > "$PIDFILE"
            trap 'rm -f "$PIDFILE"; rmdir "$LOCKDIR" 2>/dev/null' EXIT INT TERM HUP
            return 0
        fi
        # ... stale-PID detection elided ...
    done
}
```

If a Phase 3 skill DOES need a lock (none of the four reference skills do — verified by walking each `run.sh` sketch in RESEARCH.md), it MUST arm the EXIT trap in the same shell as the `mkdir` (Pitfall 6 in Phase 2 RESEARCH: never `acquire_lock` inside a pipeline subshell — the trap won't fire).

### bats setup + helpers idiom (test files)

**Source:** `core/tests/validate_task.bats` lines 7–24 (setup) + lines 29–87 (`make_plan`, `make_task_dir` helpers).
**Apply to:** `core/tests/skill_uniformity.bats` (partial — needs only the loaders, not the TMPHOME scaffolding) + all four `core/tests/skill_<name>_e2e.bats` files (full TMPHOME scaffolding).

The `make_plan` helper (lines 29–71 of validate_task.bats) is reusable verbatim for the e2e tests — it builds a synthetic `PLAN.md` in `TMPHOME/.planning/phases/test-phase/PLAN.md` with a `task:` block, `state_writes:` list, and `acceptance:` list. Each `skill_<name>_e2e.bats` invokes `make_plan` to construct a PLAN.md that names the skill under test, then invokes the skill's `run.sh`, then `chantier validate-task` with that PLAN.

The `make_task_dir` helper (lines 75–87) — used to seed `output.md` and `output.json` directly in validate-task tests — is NOT needed in skill e2e tests because the skill's `run.sh` writes those files itself (D-03). Skill e2e tests are stricter than validate-task tests in this respect.

The `macOS /var → /private/var symlink canonicalization` step (lines 14–17 of validate_task.bats) is REQUIRED in every e2e test that compares paths — gate 1 in `core/bin/chantier` does `pwd -P` and Phase 3 e2e tests must match.

## No Analog Found

None. Every Phase 3 new-file class has a load-bearing analog in the Chantier tree:

- Shell scripts → `core/bin/chantier` (idioms, jq emission, timestamp, locking).
- Bats tests → `core/tests/validate_task.bats` (setup, helpers, assertion shape).
- Bats fixtures → `core/tests/fixtures/` (existing layout).
- Phase summary → `.planning/phases/02-runtime-core/02-06-SUMMARY.md` (precedent).
- Skill frontmatter contract → `core/schemas/skill.json` (schema source-of-truth).
- Skill body structure → RESEARCH.md Pattern 3 (greenfield artifact class — pattern derived from Phase 2 CONTEXT.md "Integration Points" + ADR 0001 Surface 2 + RESEARCH.md's worked exemplar for `test-driven-development`).
- PRESSURE.md → RESEARCH.md Pattern 4 (greenfield artifact class — pattern derived from the four locked decisions D-09..D-13).

The two greenfield artifact classes (SKILL.md body and PRESSURE.md) are template-matched rather than file-matched because no prior SKILL.md/PRESSURE.md exists in-tree. The templates ship as worked exemplars in RESEARCH.md (Pattern 3 and Pattern 4 respectively), and every locked decision (D-05..D-13) constrains their shape. The planner can treat these templates as canonical for the four shipped skills.

## Metadata

**Analog search scope:** `core/bin/chantier` (binary), `core/tests/*.bats` (Phase 2 test suite), `core/tests/fixtures/` (Phase 2 fixtures), `core/schemas/skill.json` (frontmatter contract), `.planning/phases/02-runtime-core/02-06-SUMMARY.md` (close-summary precedent), `docs/adr/0001-state-skill-contract.md` and `docs/adr/0002-runtime-binary-and-state-format.md` (referenced via RESEARCH.md sourcing).

**Files scanned (read or grep):** 7 (`core/bin/chantier`, `core/tests/validate_task.bats`, `core/schemas/skill.json`, `.planning/phases/02-runtime-core/02-06-SUMMARY.md`, `.planning/phases/03-skill-library/03-CONTEXT.md`, `.planning/phases/03-skill-library/03-RESEARCH.md`, directory listings of `core/tests/`, `core/tests/fixtures/`, `skills/`).

**Pattern extraction date:** 2026-05-30.

**Confidence:** HIGH on all analog excerpts (every line number verified against the actual file). HIGH on shared patterns (every gate behaviour cross-checked between `core/bin/chantier` and `core/tests/validate_task.bats`).
