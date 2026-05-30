---
phase: 04-claude-code-adapter
plan: 01
subsystem: bats-audit
tags: [audit, bats, nfr-001, harness-isolation, posix-shell, marker-convention]
requires:
  - core/bin/chantier:687
  - core/bin/chantier:912
  - core/tests/test_helper/bats-support
  - core/tests/test_helper/bats-assert
provides:
  - cross-tree NFR-001 carve-out audit (D-09)
  - path-only D-10 carve-out enforcement for adapters/claude-code/
  - HARNESS_DENY_LIST_CHECK marker convention extended to bats suite
affects:
  - core/tests/self_test.bats (marker added)
  - core/tests/skill_uniformity.bats (marker added)
  - core/tests/validate_task.bats (marker added)
tech-stack:
  added: []
  patterns:
    - per-file `grep -v HARNESS_DENY_LIST_CHECK` content filter (mirror of core/bin/chantier:913)
    - case-statement scope dispatch (full / narrow / SKILL.md / exempt)
    - POSIX find walk with stdin-piped grep-v filter (no GNU --include)
    - explicit double-belt self-exemption via case arm
key-files:
  created:
    - core/tests/adapter_isolation.bats
  modified:
    - core/tests/self_test.bats
    - core/tests/skill_uniformity.bats
    - core/tests/validate_task.bats
decisions:
  - D-09 audit shape (deny-list grep + path-only exemption) implemented
  - D-10 carve-out enforced via narrow deny-list inside adapters/claude-code/
  - D-11 exempt paths encoded as explicit case arms (core/bin/chantier and core/schemas/skill.json)
  - D-12 audit integrated into the existing bats suite (no separate CI job)
  - Rule 1 auto-fix applied: per-file `grep -v HARNESS_DENY_LIST_CHECK` content filter added (plan's pipeline-level filter alone was insufficient — would have flagged 4 legitimate files)
requirements:
  - FR-008
metrics:
  duration_minutes: ~25
  bats_suite_before: 71/0
  bats_suite_after: 72/0
  audit_file_lines: 124
  marker_count_in_audit: 25
completed: 2026-05-30
---

# Phase 04 Plan 01: NFR-001 carve-out audit harness Summary

`core/tests/adapter_isolation.bats` ships as a 124-line cross-tree audit that enforces the D-09/D-10/D-11/D-12 contract: deny-list tokens (`mcp__`, `claude_ai_`, `@codebase`, `claude-code`, `cursor`, `codex-cli`, `copilot-cli`, `gemini-cli`, `opencode`) are forbidden in `core/`, `skills/`, and sibling `adapters/*/` directories, with a path-only carve-out that permits `claude-code` and `mcp__claude_ai_` inside `adapters/claude-code/` only.

## What was built

One bats test file (`core/tests/adapter_isolation.bats`) implementing exactly one `@test` block. The audit walks `core/`, `skills/`, and `adapters/` via POSIX `find -type f`, then dispatches each file through a five-arm `case` statement:

1. **`core/bin/chantier`** — explicit D-11 exemption (the binary has its own `HARNESS_DENY_LIST_CHECK` self-scan in `--self-test`).
2. **`core/schemas/skill.json`** — explicit D-11 exemption (the JSON schema's `harness_adapters` enum lists every harness name as metadata, not as invocation; documented at `core/bin/chantier:908-909`).
3. **`core/tests/adapter_isolation.bats`** — double-belt self-exemption (RESEARCH §A3 recommendation) so a future edit that drops a marker still cannot make the audit self-flag.
4. **`skills/*/SKILL.md`** — applies the full deny-list, but first filters the sanctioned `  - claude-code` YAML frontmatter line (D-14 from Phase 3).
5. **`adapters/claude-code/*`** — applies the **narrow** deny-list (`@codebase|cursor|codex-cli|copilot-cli|gemini-cli|opencode`); the `claude-code` and `mcp__claude_ai_` substrings are sanctioned per D-10. Cross-adapter pollution still rejected.
6. **default `*`** — applies the full deny-list.

For every non-exempt arm, the per-file scan runs `grep -v 'HARNESS_DENY_LIST_CHECK' "$_file" | grep -qE "$_pattern"` (mirror of `core/bin/chantier:913`), so any line tagged with the `HARNESS_DENY_LIST_CHECK` marker is filtered out of the content before the deny-list pattern is applied.

## Byte-identical proof

The audit's `_full` regex string is byte-identical to `core/bin/chantier:687` and `:912`:

```
mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode
```

Verification (executed during this plan):
```sh
$ diff <(grep -oE '[a-z_@]+(\|[a-z_@-]+)+' core/tests/adapter_isolation.bats | head -1) \
       <(sed -n "687p" core/bin/chantier | grep -oE '[a-z_@]+(\|[a-z_@-]+)+')
# (no output — byte-identical)
$ diff <(grep -oE '[a-z_@]+(\|[a-z_@-]+)+' core/tests/adapter_isolation.bats | head -1) \
       <(sed -n "912p" core/bin/chantier | grep -oE '[a-z_@]+(\|[a-z_@-]+)+')
# (no output — byte-identical)
```

## Marker convention extended to the bats suite

Three pre-existing test files contained legitimate deny-list-token mentions (test fixtures and reference values) and needed `HARNESS_DENY_LIST_CHECK` markers added so the audit does not flag them. This extends the marker convention from `core/bin/chantier` (Phase 2) and `core/tests/adapter_isolation.bats` (this plan) into the rest of the bats suite, keeping the project's NFR-001 enforcement pattern uniform:

| File | Lines marked | Reason |
|------|--------------|--------|
| `core/tests/self_test.bats` | 56–57 | Hosts a mirror of the deny-list literal to verify `--self-test` self-scan behavior. The deny-list pattern is extracted into a `_deny` variable so the marker rides on the assignment line; the `run sh -c '…$_deny…'` invocation interpolates the value. |
| `core/tests/skill_uniformity.bats` | 22, 28 | The `@test` title and the `_reference="claude-code"` expected value document Phase 3 D-14. |
| `core/tests/validate_task.bats` | 219, 234 | Two gate-4 test fixtures that intentionally inject harness identifiers into a skill body to exercise gate-4 fail / portable:false-skip paths. |

## Verification Results

| Check | Result |
|-------|--------|
| `bats core/tests/adapter_isolation.bats` | **1/0** (exit 0) |
| `bats core/tests/` (full suite) | **72/0** (exit 0; was 71 at Phase 3 close) |
| `grep -c 'HARNESS_DENY_LIST_CHECK' core/tests/adapter_isolation.bats` | **25** (≥ 6 required) |
| `grep -v '^#' core/tests/adapter_isolation.bats \| grep -v 'HARNESS_DENY_LIST_CHECK' \| grep -cE '<deny-list>'` | **0** (self-exempt by marker) |
| `_full` byte-identical to `core/bin/chantier:687` | yes (`diff` empty) |
| `_full` byte-identical to `core/bin/chantier:912` | yes (`diff` empty) |
| `core/bin/chantier --self-test` | still green (Phase 2 baseline preserved) |

**Sentinel-red probe (manual; NOT committed):** During verification, the falsifiability of the audit was demonstrated by creating `adapters/cursor/probe.txt` containing the string `this is some cursor adapter file`. Running the audit on the modified tree produced:

```
not ok 1 adapter_isolation: cross-tree NFR-001 carve-out — deny-list tokens absent outside adapters/claude-code/
# adapter_isolation: deny-list violations:
# adapters/cursor/probe.txt
```

Cleanup (`rm -rf adapters/cursor`) returned the suite to 1/0 green. The probe directory was deleted before committing; the working tree contains no sentinel artifacts.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Plan-specified pipeline marker filter was insufficient**

- **Found during:** Initial bats run after first draft.
- **Issue:** The plan's pattern instructed `find ... | grep -v 'HARNESS_DENY_LIST_CHECK\|test_helper/' | sort` and then per-file `grep -qE "$_full"`. The `grep -v` step in this pipeline operates on **paths** emitted by `find`, not on file contents, so it filters out files whose names contain `HARNESS_DENY_LIST_CHECK` (none) and `test_helper/` (the vendored bats submodules). It does NOT strip marker-tagged lines out of the deny-list grep on individual files. Consequence: the very first run flagged four pre-existing files that contain deny-list tokens legitimately:
  - `core/schemas/skill.json` (the `harness_adapters` enum metadata)
  - `core/tests/self_test.bats` (a mirror of the deny-list literal to verify `--self-test`)
  - `core/tests/skill_uniformity.bats` (the `claude-code` reference value from Phase 3 D-14)
  - `core/tests/validate_task.bats` (gate-4 test fixtures that intentionally embed harness names)
- **Fix:** Two coordinated changes:
  1. **Audit logic:** Changed each per-file deny-list grep from `grep -qE "$_full" "$_file"` to `grep -v 'HARNESS_DENY_LIST_CHECK' "$_file" | grep -qE "$_full"`. This mirrors `core/bin/chantier:913` exactly — the binary's `--self-test` already strips marker lines out of file content before the deny-list match, and the audit now follows the same proven pattern. The pipeline-level `grep -v 'HARNESS_DENY_LIST_CHECK'` was dropped (it never had a function on path names); the `test_helper/` filter was kept since it operates correctly on path names.
  2. **Schema exemption:** `core/schemas/skill.json` is JSON without shell comments, so the marker convention cannot reach line 42's enum. Added an explicit `case "$_file" in core/schemas/skill.json)` arm matching the existing `core/bin/chantier` exemption pattern. This is also the D-11 explicit-exempt-paths model (RESEARCH §A3).
  3. **Marker propagation:** Added `# HARNESS_DENY_LIST_CHECK` to the lines in `self_test.bats`, `skill_uniformity.bats`, and `validate_task.bats` that legitimately contain deny-list tokens. This extends the Phase 2 marker convention into the bats suite uniformly.
- **Files modified:** `core/tests/adapter_isolation.bats`, `core/tests/self_test.bats`, `core/tests/skill_uniformity.bats`, `core/tests/validate_task.bats`
- **Threat-model alignment:** matches T-04-01-02 (Tampering — marker convention) and T-04-01-04 (vendor noise). The plan's pattern was incomplete; this fix is the smallest change consistent with D-11 and with the binary's existing `HARNESS_DENY_LIST_CHECK` precedent.

### No architectural changes

No Rule 4 escalations occurred. Every fix above is mechanical and reuses an existing, validated pattern (`core/bin/chantier:913`).

## Acceptance criteria — closed

- [x] File `core/tests/adapter_isolation.bats` exists at the repo root.
- [x] `bats core/tests/adapter_isolation.bats` exits 0 against the current tree.
- [x] `bats core/tests/` reports 72 tests, 0 failures (was 71 at Phase 3 close).
- [x] `grep -c 'HARNESS_DENY_LIST_CHECK' core/tests/adapter_isolation.bats` returns ≥ 6 (returns 25).
- [x] `grep -v '^#' core/tests/adapter_isolation.bats | grep -v 'HARNESS_DENY_LIST_CHECK' | grep -cE '<deny-list>'` returns 0.
- [x] `_full` regex is byte-identical to `core/bin/chantier:687` and `:912` (verified via `diff`).
- [x] Sentinel-red proof demonstrated manually (and NOT committed). Working tree clean of probe artifacts.
- [x] Shellcheck NOT applicable to bats files (per plan).

## Forward-looking notes

- **Plan 02 readiness:** When `adapters/claude-code/run-task.sh` lands, the `adapters/claude-code/*)` case arm will activate against real files. It applies the narrow deny-list, so `claude-code` and `mcp__claude_ai_` substrings within that directory pass; `cursor`, `codex-cli`, etc., still fail. Sentinel: appending `cursor` to a file under `adapters/claude-code/` will make the audit red (verified pattern-level today; ready for Plan 02 to validate on real files).
- **Marker uniformity across suite:** The four bats files (`adapter_isolation.bats`, `self_test.bats`, `skill_uniformity.bats`, `validate_task.bats`) plus `core/bin/chantier` now all share the same `HARNESS_DENY_LIST_CHECK` convention. Future contributors who add new tests touching harness names need only follow the same per-line marker pattern.
- **No `.planning/` files affected by the audit:** `.planning/STATE.md` historically logs `claude-code` event summaries; D-11 keeps `.planning/` out of audit scope by NOT walking it. Same for `docs/`.

## Self-Check: PASSED

- `core/tests/adapter_isolation.bats` exists ✓
- `core/tests/self_test.bats` modified ✓
- `core/tests/skill_uniformity.bats` modified ✓
- `core/tests/validate_task.bats` modified ✓
- Per-task commit hash will be recorded by the final commit step below ✓
