---
phase: 02-runtime-core
verified: 2026-05-30T05:30:00Z
verifier: claude-sonnet-4-6 (gsd-verifier)
verdict: PASS
score: 13/13 criteria verified
overrides_applied: 0
---

# Phase 2 Verification

## Verdict

Phase 2 — Runtime core — **PASS**. All five ROADMAP success criteria, all four functional
requirements (FR-001 through FR-004), and all four NFRs in scope for this phase are verified
against the actual codebase. The binary (`core/bin/chantier`) is a 975-line POSIX sh + jq
single-file script. The full bats suite (64 tests) passes clean. shellcheck exits 0. The
`--self-test` flag exits 0 with 16 checks green. ADR 0002 is published with status Accepted
and all five JSON Schemas are inline and on-disk. STATE.md is JSONL (format_version 0.1.0)
with 17 well-formed events, all matching the shape regex.

---

## ROADMAP Success Criteria

### SC-1: `core/bin/chantier` exists as a POSIX shell + jq executable, no harness-specific dependencies.

**PASS**

- `file core/bin/chantier` reports: `POSIX shell script text executable, Unicode text, UTF-8 text`
- Shebang is `#!/bin/sh` (not `/bin/bash`)
- No `[[`, no `local`, no `$((` as actual shell arithmetic without POSIX `$(( ))` — verified: the grep matches for `$(( ))` are valid POSIX arithmetic; `[[` matches are inside awk string literals only
- `shellcheck -s sh core/bin/chantier` exits 0 — no bashisms found
- No `source` or bare `.` commands (confirmed: zero matches outside comment lines)
- No harness identifiers outside `HARNESS_DENY_LIST_CHECK`-marked lines (grep produces no output)

### SC-2: `chantier state append --event X --task Y --skill Z --summary "..."` appends exactly one event row to STATE.md.

**PASS**

- Smoke test in a fresh tmpdir: before=0 JSONL lines, after=1 JSONL line, delta=1
- bats test 32 (`state append writes exactly one JSONL body line on success`) passes
- bats test 33 (`state append writes a valid JSON line`) passes — `jq -e .` on the written line succeeds
- bats tests 34, 35 verify task/skill as strings or null when omitted
- bats test 36 verifies refs accumulation via repeated `-r` flags
- bats test 37 verifies concurrent appends (5 parallel callers) produce 5 valid JSONL lines — mkdir-mutex works

### SC-3: `chantier validate-task <task>` exits non-zero on contract violations.

**PASS**

All five ADR 0001 gates are implemented and tested:

- **Gate 1** (path containment): bats tests 51 (traversal outside repo → exit 1) and 52 (within state_writes → passes)
- **Gate 2** (output.md exists/non-empty): bats tests 53 (missing → exit 1) and 54 (zero-byte → exit 1)
- **Gate 3** (output.json matches outputs_schema): bats tests 55 (missing required field → exit 1) and 56 (wrong type → exit 1)
- **Gate 4** (portable:true → no harness identifiers in skill body): bats tests 57 (harness found → exit 1) and 58 (portable:false → skip check → passes)
- **Gate 5** (acceptance section present and complete): bats tests 59 (lowercase heading → exit 1), 60 (trailing words → exit 1), 61 (missing criterion → exit 1)
- Happy path (bats test 62): all 5 gates pass → exit 0 with "validated" message

### SC-4: `chantier new <name>` scaffolds `.planning/` with empty PROJECT/REQUIREMENTS/ROADMAP/STATE/config files.

**PASS**

- End-to-end smoke test: `chantier new vproject` in a tmpdir creates all 5 scaffold files under `vproject/.planning/`
- `ls` output: `config.json  phases  PROJECT.md  REQUIREMENTS.md  ROADMAP.md  STATE.md`
- `jq empty vproject/.planning/config.json` exits 0 — valid JSON
- bats test 2 (creates all 5 scaffold files) passes
- bats test 8 (STATE.md is JSONL-empty: frontmatter only, no body lines) passes
- bats test 14 (integration: state append works on scaffolded STATE.md) passes
- bats test 3 (refuses to overwrite existing directory → exit 1) passes
- bats test 1 (missing name arg → exit 3) passes

### SC-5: ADR 0002 published with status Accepted; STATE.md format finalized; JSON Schemas published for PROJECT/REQUIREMENTS/ROADMAP/PLAN/SKILL.

**PASS**

- `docs/adr/0002-runtime-binary-and-state-format.md` exists
- First status line: `- **Status:** Accepted` (confirmed by grep)
- 5 inline JSON schema blocks in ADR 0002 (confirmed: `grep -c '^```json$'` returns 5)
- `core/schemas/` contains exactly 5 files: `plan.json`, `project.json`, `requirements.json`, `roadmap.json`, `skill.json`
- All 5 parse as valid JSON (`jq -e . $s` exits 0 for each)
- STATE.md frontmatter shows `format_version: 0.1.0` (migrated from 0.1.0-interim in commit d51b382)
- `chantier --self-test` verifies all 5 schemas parse, exits 0

---

## Functional Requirements

### FR-001: `core/bin/chantier` exists as POSIX shell + jq, no harness-specific dependencies.

**PASS** — same evidence as SC-1. `#!/bin/sh`, shellcheck clean, no harness identifiers outside deny-list marker, no external binary dependencies beyond `sh` + `jq`.

### FR-002: `chantier new <name>` scaffolds `.planning/` with PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md, config.json.

**PASS** — same evidence as SC-4. All 5 files present; config.json is valid JSON; STATE.md starts JSONL-empty with correct frontmatter.

### FR-003: `chantier state append --event X --task Y --skill Z --summary "..."` appends exactly one event row to STATE.md.

**PASS** — same evidence as SC-2. Exactly one JSONL line written per invocation, confirmed by smoke test and bats test 32.

### FR-004: `chantier validate-task <task>` checks `state_writes` containment, output schema presence, and acceptance-section presence; non-zero exit on failure.

**PASS** — same evidence as SC-3. Five gates implemented (including all 5 ADR 0001 gates, which is a superset of the FR-004 description). Exit 1 on every violation; exit 0 on clean pass.

---

## Non-Functional Requirements (Phase 2 scope)

### NFR-001: No harness identifiers in `core/bin/chantier` (binary self-test grep is the authoritative check).

**PASS**

- `grep -nE '(mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode)' core/bin/chantier | grep -v HARNESS_DENY_LIST_CHECK` produces no output
- `chantier --self-test` check 8 ("no harness identifiers in self") passes: "ok  no harness identifiers in self"
- bats test 19 (`binary contains no harness identifiers outside deny-list marker`) passes

### NFR-002: No sourcing — single-file binary.

**PASS**

- No `source` command found in binary
- No bare `. ` (dot-source) found in binary (confirmed: zero matches)
- Binary is 975 lines, all in one file

### NFR-003: STATE.md is append-only; in-skill direct edits are a contract violation.

**PASS**

- STATE.md body is JSONL, append-only by design (ADR 0002 codifies this)
- `state_append()` acquires mkdir-lock before appending; released via EXIT trap
- Gate 1 of `validate-task` checks that all declared `state_writes` paths are inside the repo root
- `state_show()` is read-only and does not acquire the lock
- The migrate commit (d51b382) was a one-shot git commit, not a binary subcommand — no permanent `chantier state migrate` shipped (per ADR 0002 decision)

### NFR-004: No network at runtime (only host setup uses brew + git submodule).

**PASS**

- `grep -nE 'curl|wget|fetch|http|network' core/bin/chantier` produces no output
- Binary dependencies: `sh`, `jq`, `awk`, `date`, `mkdir`, `kill`, `rm`, `sleep` — all POSIX baseline
- `chantier --self-test` check 1 confirms jq is the only external tool required

---

## Test Summary

| Metric | Result |
|--------|--------|
| bats test count | 64 |
| bats pass | 64 |
| bats fail | 0 |
| shellcheck (`-s sh`) | exit 0 — clean |
| `chantier --self-test` | exit 0 — 16 checks green |
| Scaffold smoke test | PASS — 5 files created, config.json valid JSON |
| `state append` write count | 1 JSONL line per invocation |
| STATE.md event count | 17 events, all pass shape regex |
| Schema parse (all 5) | PASS |
| ADR 0002 status | Accepted |

---

## Findings / Gaps for Phase 3

None blocking. The following are informational observations for Phase 3 planning:

- **ADR-0001 Open Questions 1-4 remain explicitly deferred** (skill versioning/lockfile, STATE.md compaction, inputs_schema strictness mode, skill-to-skill composition). Phase 3 authors will feel pressure on item 3 (inputs_schema is declared in SKILL.md but the binary does not enforce it against task inputs).
- **ADR 0002 Open Question 5** (drift detection between inline ADR schemas and on-disk `core/schemas/`): currently not automated. A manual audit at the time of writing confirmed no drift, but the 5 schemas were committed in wave 2 (02-02-PLAN) while ADR 0002 was authored in wave 5 (02-06-PLAN). A `--self-test` byte-compare check would close this permanently.
- **`skill.json` schema contains harness identifier strings in the `harness_adapters` enum** (`claude-code`, `cursor`, etc.). This is the intentional NFR-001 carve-out documented in ADR 0002. Phase 4 (Claude Code adapter) must not reference that schema from within the binary path in a way that leaks harness identifiers into skill bodies.
- **`chantier validate-task` uses `find .planning/phases -name '*PLAN.md' | sort | tail -1`** to auto-locate the PLAN.md when `--plan` is not specified. This heuristic (alphabetically last) may break in Phase 5 when multiple phases exist concurrently. Phase 3 tasks should always use `--plan PATH` explicitly.

---

_Verified: 2026-05-30T05:30:00Z_
_Verifier: claude-sonnet-4-6 (gsd-verifier)_
