# `.planning/` — dogfooding marker

This directory is intentionally present and (mostly) empty.

Chantier is designed to manage long-running projects through a structured `.planning/` filesystem (see [ADR 0001](../docs/adr/0001-state-skill-contract.md)). The first project that will use Chantier's own runtime to manage its work is **Chantier itself**. This directory is the seed.

It will be populated by Chantier's own phases as the runtime comes into existence. Specifically:

- `PROJECT.md` — generated when `chantier new-project` is implemented and run.
- `ROADMAP.md` — generated when the first roadmap is committed.
- `STATE.md` — append-only event log starting at the first executed phase.
- `phases/N-name/` — per-phase artifacts (plans, reviews, task outputs).
- `config.json` — workflow toggles.

Until then, the directory holds only this README. The presence of the directory is a commitment, not a state.

## Why dogfood from day one

If Chantier cannot describe its own construction in its own format, it cannot honestly claim to describe yours. The risk is small: at worst, we discover the format is wrong while building the framework, in which case we change the format, which is exactly what we want before publishing v1.

This is also the natural place to catch design flaws in the state/skill contract. Friction encountered here is friction every user would have encountered too.
