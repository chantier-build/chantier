# Contributing to Chantier

Chantier is built under a **multi-contributor governance model from commit one**. This is not aspirational language — it is a direct response to a known failure mode in this ecosystem: when a framework depends on one person, the framework dies when that person disappears. Chantier is designed so that no single contributor — including its founding contributors — is structurally required for the project to continue.

This document records how that works in practice.

## Project stage

| Stage | What it means | Where we are |
|---|---|---|
| **Founding** | Initial contributors lay the architecture and seed the ADR record. No org yet, decisions reviewed in PRs. | ← here |
| **Org-formed** | GitHub org `chantier-build` exists, at least 3 active maintainers, [MAINTAINERS.md](MAINTAINERS.md) populated, every merged PR has ≥1 maintainer review from someone other than the author. | next |
| **Stable** | Versioned releases, semantic-versioned skill registry, deprecation policy in place. | later |

A `MAINTAINERS.md` file will appear in this repository when the project enters the **Org-formed** stage. Until then, contributions are reviewed by founding contributors and discussed in the open via PRs and ADRs.

## How decisions are made

**Architectural decisions are made by ADR.** Every load-bearing technical choice lives in [`docs/adr/`](docs/adr/), numbered sequentially. The first one ([ADR 0001](docs/adr/0001-state-skill-contract.md)) is the state/skill contract — everything downstream of it must justify any divergence.

If you want to propose a structural change:

1. Open a PR that adds a new ADR (`docs/adr/NNNN-short-name.md`).
2. Status starts at `Proposed`. Discussion happens in the PR.
3. A maintainer (or, until the org forms, a founding contributor) moves it to `Accepted` after consensus, or `Rejected` with the rationale captured in the file.
4. Code changes go in a separate PR that references the accepted ADR.

If you want to propose a non-structural change (bug fix, new skill, doc improvement), open a normal PR. No ADR required.

## What we accept

We accept:

- **New skills** in `skills/<name>/` that follow the contract defined in ADR 0001. Each skill must ship with:
  - `SKILL.md` — body and front-matter declaring `state_reads`, `state_writes`, `inputs_schema`, `outputs_schema`, portability claim.
  - `PRESSURE.md` — the adversarial scenarios this skill survives (per [Superpowers' pressure-testing](https://blog.fsck.com/2025/10/09/superpowers/) tradition).
  - Optional `run.sh` if the skill performs side effects.
- **Harness adapters** in `adapters/<harness>/` that stage dossiers for a new AI coding harness without modifying any skill body.
- **Documentation improvements** anywhere in `docs/`.
- **Test coverage** for `core/` and individual skills.

## What we will not accept

These are project-level non-negotiables. PRs that violate them will be closed:

- ❌ **Tokens, crypto, or monetary primitives of any kind.** This is a direct lesson from the original GSD's `$GSD` rug-pull.
- ❌ **Harness-specific code in `skills/` or in `core/`.** Skill bodies are pure Markdown + portable shell. Harness-specific glue belongs only in `adapters/<harness>/`.
- ❌ **Telemetry by default.** Any data collection must be opt-in, documented, and minimal.
- ❌ **Closed-source dependencies.** Chantier depends only on MIT/Apache/BSD-licensed software.
- ❌ **Skills that depend on session-injected context** (e.g., `SessionStart` hooks). The contract requires file-readable state. See [`obra/superpowers#237`](https://github.com/obra/superpowers/issues/237) for the failure mode this rule prevents.

## Commit and PR conventions

- Commit messages are in **English**, written so a reader six months from now understands *why* the change was made, not just what. One-line subject (≤72 chars), blank line, structured body.
- Reference the ADR or issue your PR responds to.
- One logical change per commit; one logical PR per concern. Use squash merges only when commits are noisy WIP.
- Public-facing artifacts (README, docs, skill bodies) are in English. Conversations on issues and PRs are open to any language; the merged artifact stays English.

## Code of conduct

We default to the [Contributor Covenant](https://www.contributor-covenant.org/) v2.1. A formal `CODE_OF_CONDUCT.md` will be added when the org forms; until then, contributors are expected to behave consistently with that covenant.

## How to reach the project

- **For bugs and feature requests:** open a GitHub issue once the org repository exists.
- **For security concerns:** a security contact email will be published when the org forms. Until then, open a private issue or contact a founding contributor directly via the address listed in the most recent commit's `Author:` field.

## Founding contributors

This section will become `MAINTAINERS.md` once the org forms. Until then, founding contributors are recognized through their commit attributions in the git history. Anyone landing three or more accepted PRs during the founding stage is invited to become a maintainer when the org is formed.
