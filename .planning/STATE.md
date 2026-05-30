---
project_id: chantier
created: 2026-05-29
format_version: 0.1.0-interim
format_note: |
  STATE.md is append-only per ADR 0001. Format will be finalized in ADR 0002.
  Until then: Markdown table, one row per event, one event per line, no multi-line cells, no row deletion.
  Edits to historical rows are a contract violation.
  Mutation is allowed only via `chantier state append` once the binary exists; during the foundation phase, rows were authored by hand.
---

# State log

| timestamp | event | actor | summary | refs |
|---|---|---|---|---|
| 2026-05-29T17:00:00Z | bootstrap.session.started | MAoDzi | Brief received, session plan proposed, all seven ADR sign-offs validated | brief |
| 2026-05-29T17:15:00Z | research.completed | MAoDzi | Inheritance map written from GSD redux, Superpowers, and obra/superpowers#237 finding | docs/research/inheritance-map.md |
| 2026-05-29T17:25:00Z | adr.accepted | MAoDzi | ADR 0001 (state/skill contract) accepted; 7 surface decisions ratified, 4 questions deferred | docs/adr/0001-state-skill-contract.md |
| 2026-05-29T17:30:00Z | scaffold.committed | MAoDzi | Repo skeleton committed (README, LICENSE, LICENSE-CREDITS, CONTRIBUTING, vision, gitignore) | commit f26b630 |
| 2026-05-29T17:32:00Z | adr.status.updated | MAoDzi | ADR 0001 status moved from Proposed to Accepted after sign-off | commit 8889c59 |
| 2026-05-29T17:45:00Z | github.org.created | MAoDzi | Org chantier-build created on GitHub | github.com/chantier-build |
| 2026-05-29T17:50:00Z | repo.published | MAoDzi | Repo chantier-build/chantier pushed public; Discussions enabled, Wiki and Projects disabled | github.com/chantier-build/chantier |
| 2026-05-29T18:00:00Z | phase.completed | MAoDzi | Phase 01-foundation marked complete after backfill into .planning/ | .planning/phases/01-foundation/SUMMARY.md |
| 2026-05-29T18:00:00Z | phase.next.declared | MAoDzi | Phase 02-runtime-core declared as next; needs ADR 0002 and core/bin/chantier | .planning/ROADMAP.md |
| 2026-05-29T18:30:00Z | bootstrap.harness.chosen | MAoDzi | Decision: use GSD as Chantier's planning/execution harness for phases 2-5 (Option A in pre-flight check); ROADMAP.md rewritten to GSD parser format to unblock /gsd-plan-phase. Cutover to Chantier's native commands happens at end of Phase 5 (dogfood-e2e), at which point ROADMAP.md migrates back to ADR 0001 format. | ROADMAP.md |
| 2026-05-30T00:06:01Z | phase.context.gathered | MAoDzi | Phase 02-runtime-core context captured: STATE.md→JSONL, hybrid strict/permissive front-matter schemas, dotted-namespace event convention with shape-regex enforcement, commented-stub scaffold; 9 Claude's Discretion items recorded. Ready for /gsd-plan-phase 2. | .planning/phases/02-runtime-core/02-CONTEXT.md |
| 2026-05-29T00:00:00Z | plan.completed | claude-sonnet-4-6 | Plan 02-01 complete: bats-support v0.3.0 and bats-assert v2.2.4 vendored as submodules, .gitattributes LF guard written, 5 bats scaffold files and 4 ADR-0001 fixtures created, bats core/tests/ exits 0 | .planning/phases/02-runtime-core/02-01-SUMMARY.md |
| 2026-05-29T00:00:00Z | plan.completed | claude-sonnet-4-6 | Plan 02-02 complete: 5 JSON Schema draft-07 files authored at core/schemas/{project,requirements,roadmap,plan,skill}.json; all pass jq empty; additionalProperties true (D-05); skill.json enforces all 8 ADR 0001 Surface 2 fields; NFR-001 carve-out documented | .planning/phases/02-runtime-core/02-02-SUMMARY.md |
| 2026-05-30T00:00:00Z | plan.completed | claude-sonnet-4-6 | Plan 02-03 complete: core/bin/chantier skeleton (333 lines, POSIX sh, shellcheck clean, --self-test all green with 16 checks, harness-deny-list via HARNESS_DENY_LIST_CHECK marker, exit-code matrix 0/1/2/3); core/tests/self_test.bats with 11 real @test blocks all passing | .planning/phases/02-runtime-core/02-03-SUMMARY.md |
| 2026-05-30T00:00:00Z | plan.completed | claude-sonnet-4-6 | Plan 02-04 complete: state_append() with mkdir-as-mutex+retry (FR-003), state_show() with BSD-column-collapse mitigation (D-03), two-pass D-09 event regex, 4 auto-fixed bugs (rmdir/tostring/retry/empty-refs); 36 bats tests green across 3 suites; shellcheck clean; 440-line binary | .planning/phases/02-runtime-core/02-04-SUMMARY.md |
