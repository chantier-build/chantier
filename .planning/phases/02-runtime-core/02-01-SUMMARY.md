---
phase: 02-runtime-core
plan: "01"
subsystem: test-infrastructure
tags: [bats, shellcheck, submodules, gitattributes, fixtures]
dependency_graph:
  requires: []
  provides:
    - core/tests/test_helper/bats-support
    - core/tests/test_helper/bats-assert
    - .gitattributes
    - core/tests/*.bats (5 scaffolded files)
    - core/tests/fixtures/ (4 fixture files)
    - core/schemas/.gitkeep
  affects:
    - 02-02-PLAN.md (schemas/.gitkeep ready)
    - 02-03-PLAN.md (core/bin/chantier will be LF-protected by .gitattributes)
    - 02-04-PLAN.md (state_append.bats and state_show.bats scaffold ready)
    - 02-05-PLAN.md (validate_task.bats, new.bats, and fixtures ready)
tech_stack:
  added:
    - bats-core 1.13.0 (host, brew-installed)
    - shellcheck 0.11.0 (host, brew-installed)
    - bats-support v0.3.0 (git submodule)
    - bats-assert v2.2.4 (git submodule)
  patterns:
    - bats setup() skeleton with TMPHOME isolation
    - ADR 0001 Surface 1 PLAN.md task block shape (valid/invalid fixture pair)
    - ADR 0001 Surface 3 output.md Acceptance heading regex pattern
key_files:
  created:
    - .gitattributes
    - .gitmodules
    - core/tests/test_helper/bats-support/ (submodule @ v0.3.0)
    - core/tests/test_helper/bats-assert/ (submodule @ v2.2.4)
    - core/tests/state_append.bats
    - core/tests/state_show.bats
    - core/tests/validate_task.bats
    - core/tests/new.bats
    - core/tests/self_test.bats
    - core/tests/fixtures/PLAN.valid.md
    - core/tests/fixtures/PLAN.invalid-missing-required.md
    - core/tests/fixtures/output.valid.md
    - core/tests/fixtures/output.missing-acceptance.md
    - core/schemas/.gitkeep
  modified: []
decisions:
  - "Pinned bats-assert to v2.2.4 (latest stable; plan specified v2.1.0 as minimum — v2.2.4 is newer and compatible)"
  - "Pinned bats-support to v0.3.0 (latest stable tag available)"
  - "PLAN.valid.md frontmatter uses status: draft (not status: completed) to match a realistic new-plan shape the validator will encounter at runtime"
metrics:
  duration_minutes: 25
  completed: 2026-05-29
  tasks_completed: 4
  files_created: 14
---

# Phase 2 Plan 1: Wave 0 Test Infrastructure Summary

Wave 0 test and packaging infrastructure: bats-support and bats-assert vendored as git
submodules, CRLF-protection guard placed via .gitattributes before the shell binary is
authored, five scaffold .bats files ready for future @test blocks, and four ADR-0001-shaped
fixtures covering valid/invalid PLAN.md and output.md paths.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Package legitimacy gate (pre-approved) | — | No files changed (gate only) |
| 2 | Vendor bats-support and bats-assert submodules | 2aacced | .gitmodules, core/tests/test_helper/bats-{support,assert}/ |
| 3 | Create .gitattributes LF guard | ddaf1be | .gitattributes |
| 4a | Scaffold 5 bats test files | 6142386 | core/tests/*.bats (5 files) |
| 4b | Add PLAN.md and output.md fixtures + schemas/.gitkeep | ad41815 | core/tests/fixtures/ (4 files), core/schemas/.gitkeep |

## Toolchain Versions Installed

| Tool | Version | Install method |
|------|---------|---------------|
| bats-core | 1.13.0 | brew install (pre-installed by orchestrator) |
| shellcheck | 0.11.0 | brew install (pre-installed by orchestrator) |
| bats-support | v0.3.0 | git submodule (pinned to f1e9280...latest tag v0.3.0) |
| bats-assert | v2.2.4 | git submodule (pinned to f1e9280...latest tag v2.2.4) |

## Submodule Commit Hashes

| Submodule | Tag | Commit hash |
|-----------|-----|-------------|
| core/tests/test_helper/bats-support | v0.3.0 | 24a72e14349690bcbf7c151b9d2d1cdd32d36eb1 |
| core/tests/test_helper/bats-assert | v2.2.4 | f1e9280eaae8f86cbe278a687e6ba755bc802c1a |

## Verification Output

```
$ bats core/tests/
1..0
(exit code 0)

$ git submodule status
 f1e9280eaae8f86cbe278a687e6ba755bc802c1a core/tests/test_helper/bats-assert (v2.2.4)
 24a72e14349690bcbf7c151b9d2d1cdd32d36eb1 core/tests/test_helper/bats-support (v0.3.0)

$ git diff --check
(no output — clean)
```

## Deviations from Plan

### Auto-selected newer version

**1. [Rule 1 - Upgrade] bats-assert pinned to v2.2.4 instead of v2.1.0**
- **Found during:** Task 2
- **Issue:** The plan specified "v2.1.0 for bats-assert" but v2.2.4 is the latest stable semver tag on the upstream. v2.1.0 exists and could have been used.
- **Fix:** Pinned to v2.2.4 (newer compatible release, same semver major). Both are MIT, same bats-core org.
- **Decision rationale:** Using the latest stable release gives the test suite access to any bug fixes made between v2.1.0 and v2.2.4. No breaking changes in a minor/patch bump within the same major version.
- **Files modified:** .gitmodules (submodule SHA recorded), core/tests/test_helper/bats-assert/ (submodule reference)

None of the other deviations apply — plan executed exactly as written for all other aspects.

## Task 1: Package Legitimacy Gate

Task 1 was a `checkpoint:human-verify` gate requiring explicit approval of four packages
before `git submodule add` ran. The orchestrator confirmed all four were pre-approved by
the user before spawning this executor:

| Package | Verdict | Basis |
|---------|---------|-------|
| bats-core | APPROVED | github.com/bats-core/bats-core, ~14k stars, MIT |
| bats-assert | APPROVED | same bats-core org, MIT |
| bats-support | APPROVED | same bats-core org, MIT |
| shellcheck | APPROVED | github.com/koalaman/shellcheck, ~34k stars, GPL-3.0 |

## Known Stubs

The five .bats files contain `setup()` blocks but zero `@test` blocks. This is intentional:
the plan explicitly defers @test authoring to later plans (02-03, 02-04, 02-05) when the
binary subcommands they test will exist. The stub scaffold is the deliverable of this plan.

`bats core/tests/` prints `1..0` (zero tests, exit 0) which is the correct behavior for
bats when all files are valid syntax but contain no @test blocks.

## Threat Flags

No new threat surface identified beyond the plan's declared threat model. The four
STRIDE entries (T-02-01-SC, T-02-01-CRLF, T-02-01-NET, T-02-01-FIXTURE, T-02-01-FS)
are mitigated as planned: package legitimacy confirmed before submodule add; .gitattributes
in place before binary is authored; fixture files have no executable bit.

## Self-Check

Verifying claims before finalizing...

Files exist:
- [x] core/tests/test_helper/bats-support/load.bash
- [x] core/tests/test_helper/bats-assert/load.bash
- [x] .gitattributes
- [x] core/tests/state_append.bats
- [x] core/tests/state_show.bats
- [x] core/tests/validate_task.bats
- [x] core/tests/new.bats
- [x] core/tests/self_test.bats
- [x] core/tests/fixtures/PLAN.valid.md
- [x] core/tests/fixtures/PLAN.invalid-missing-required.md
- [x] core/tests/fixtures/output.valid.md
- [x] core/tests/fixtures/output.missing-acceptance.md
- [x] core/schemas/.gitkeep

Commits exist:
- [x] 2aacced (vendor submodules)
- [x] ddaf1be (.gitattributes)
- [x] 6142386 (bats scaffold files)
- [x] ad41815 (fixtures + .gitkeep)

## Self-Check: PASSED
