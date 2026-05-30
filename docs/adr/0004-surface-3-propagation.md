# ADR 0004 -- Surface 3 propagation

- **Status:** Proposed
- **Date proposed:** 2026-05-30
- **Date accepted:** --
- **Deciders:** Chantier founding contributors
- **Supersedes:** --
- **Superseded by:** --

> ADR 0001 Surface 3 mandates that a skill records its output as `output.md` and `output.json` under the paths declared in `state_writes` -- which resolve, for every shipped skill in v0.1.0, to `.planning/phases/<phase>/tasks/<task>/`. ADR 0001 specifies the destination; it does not specify the mechanism. Phase 3 D-04 made the skill responsible for emitting both files to its own current working directory; Phase 4 D-06 placed that working directory inside the dossier root (`$WORKTREE/.chantier/dossiers/<task>/`). These two decisions are independently sound but, taken together, leave a gap: the skill writes to the dossier, while `chantier validate-task` reads from the task directory.
>
> Phase 4 plan 03 (`adapters/claude-code/run-task.sh` end-to-end test) discovered the gap when `chantier validate-task` returned exit 1 with "output.md missing" even though the skill had run cleanly. The adapter was the only component aware of both directories and the only component invoked between subagent exit and validation. A ~12-line `cp` block was added to the adapter that copies plain files from the dossier root to the task directory, excluding the adapter-owned artifacts (`inputs.yml`, `env.sh`, `subagent.transcript.log`) and the subdirectories (`reads/`, `upstream/`, `skill/`). The contract worked; the v0.1.0 ship gates went green; the contract has not been codified.
>
> This ADR codifies it. Status is **Proposed**; ratification requires a second harness adapter to validate the contract cross-harness.

---

## Provenance

This ADR is the F1 finding from `.planning/phases/04-claude-code-adapter/04-SUMMARY.md` §Handoff Notes. The discovery happened during Phase 4 plan 03 dogfood: the new end-to-end test asserted that `validate-task` returned exit 0 after a clean skill run, and it did not. The skill (`test-driven-development`) had written `output.md` and `output.json` to its current working directory; the adapter's dispatch heredoc had set that directory to `$DOSSIER`; `validate-task` was reading from `$WORKTREE/.planning/phases/$PHASE/tasks/$TASK_ID/`; the two paths did not converge.

The patch landed in `adapters/claude-code/run-task.sh` (see References below for the exact line range at the time of writing). The fix has been live since Phase 4 plan 03 close (commit referenced in `.planning/STATE.md` `plan.completed` event for 04-03). Phase 5 plan 02 promotes the in-tree implementation choice to an architectural contract that any future harness adapter must honor.

---

## Context

Three forces motivate this ADR:

### 1. ADR 0001 Surface 3 specifies the destination, not the mechanism

ADR 0001 §Surface 3 says the skill writes into the paths it declared in `state_writes`. Every shipped v0.1.0 skill declares `state_writes: - "{phase}/tasks/{task}/"` -- i.e., the canonical task directory under `.planning/phases/`. The contract is destination-only: it does not say who copies, when, with what exclusions, or whether the skill itself emits directly to that path. ADR 0001 §Surface 2's dossier example (line 134, `upstream/t0/output.json`) shows that downstream task dossiers see upstream outputs at canonical task-directory paths, which implies somebody propagates them there -- but ADR 0001 does not assign the responsibility.

### 2. Phase 3 D-04 + Phase 4 D-06 force the gap

Phase 3 D-04 made every skill responsible for emitting `output.md` and `output.json` to its current working directory (`$PWD`), so the skill body does not need to know about phase or task identifiers. Phase 4 D-06 placed the skill's working directory inside the dossier root (`$WORKTREE/.chantier/dossiers/<task>/`) so the skill can read its inputs by relative path (`./inputs.yml`, `./reads/...`, `./upstream/...`) without further indirection. Both decisions individually preserve portability: the same skill body runs under any harness adapter that constructs the same dossier shape. Neither decision propagates the skill's output back to the canonical task directory where `chantier validate-task` expects to find it.

### 3. The adapter is the only component aware of both directories

The skill body sees only the dossier (Phase 3 D-04 isolation). The runtime binary (`core/bin/chantier validate-task`) sees only the task directory. The adapter is the only component that constructs the dossier, dispatches the skill, and is invoked between the subagent exit and the validation step. The adapter is therefore the only component capable of bridging the two namespaces. Anywhere else the propagation might live -- inside the skill body (defeats Phase 3 portability), inside the validate gate (couples gate to dossier shape), or inside a separate runtime verb (adds a fourth contract surface) -- introduces tighter coupling than the adapter-owned propagation step it replaces.

---

## Decision

The adapter SHALL, after the wrapped subagent (`claude -p` or the `CHANTIER_CLAUDE_BIN` deterministic stub) exits 0 AND BEFORE invoking `chantier validate-task`, copy every plain file from `$DOSSIER/` to `$TASK_DIR/`, EXCLUDING:

- The adapter-owned artifacts: `inputs.yml`, `env.sh`, `subagent.transcript.log`.
- All subdirectories of the dossier: `reads/`, `upstream/`, `skill/`.

Concretely:

```sh
TASK_DIR="$WORKTREE/.planning/phases/$PHASE/tasks/$TASK_ID"
mkdir -p "$TASK_DIR"
for _out in "$DOSSIER"/*; do
    [ -f "$_out" ] || continue
    case "$(basename "$_out")" in
        inputs.yml|env.sh|subagent.transcript.log) continue ;;
    esac
    cp "$_out" "$TASK_DIR/"
done
```

The exclusion list is a static contract. The adapter implementation lists each excluded filename literally rather than computing it from an external manifest. The `cp` is intentional (not `mv`): Phase 4 D-08 mandates dossier preservation so the dossier remains forensically inspectable even after propagation completes.

On `claude -p` (or stub) failure, the adapter SHALL NOT perform propagation to `$TASK_DIR`. Instead, the adapter performs the Phase 4 D-04 exit-matrix-wired move of any pre-existing `output.md` or `output.json` to `.planning/phases/<phase>/tasks/<task>/attempts/<NN>/` and exits non-zero. Propagation to the canonical task directory is gated on a green dispatch; failed attempts are quarantined.

Validation (`chantier validate-task`) runs against `$TASK_DIR` after propagation completes. The five validation gates from ADR 0001 §Validation operate on stable canonical paths regardless of which harness adapter ran the skill -- which is the contract this ADR exists to guarantee.

---

## Consequences

### Positive

- **The skill body remains harness-agnostic.** The skill does not need to know `$CHANTIER_TASK_DIR` or any phase-aware path. It writes to its own `$PWD`; the adapter does the rest. Phase 3 portability claim is preserved.
- **Dossier preservation and canonical-path validation coexist.** Phase 4 D-08 keeps the dossier inspectable; Phase 5's ADR 0004 keeps validation operating on the canonical state-writes path. Neither concern compromises the other.
- **Surface 3 validation gates (gates 2 and 3 in `chantier validate-task`) operate on stable canonical paths regardless of harness.** A future second adapter that honors this ADR produces an identical `$TASK_DIR` layout; the same `validate-task` invocation passes on both.
- **The contract is observable by file inspection.** No introspection of the adapter binary is required -- a `diff` between `$DOSSIER/` and `$TASK_DIR/` after a successful run is the audit.

### Negative

- **The exclusion list is a static contract -- adapter-owned artifacts added in the future must be explicitly added to the list.** If a future adapter writes a new bookkeeping file at the dossier root, the propagation loop will copy it to the task directory unless the exclusion list is updated. Drift risk is real and must be managed by code review.
- **Per-file `cp` is non-transactional.** An adapter killed mid-propagation leaves `$TASK_DIR` partial. Phase 4 has not surfaced this in production, and v0.1.0 does not address it.
- **Propagation adds I/O on every successful dispatch.** A skill that emits dozens of plain files at the dossier root pays the per-file `cp` cost. Acceptable in v0.1.0 (typical skill emits two files); flagged for future review if a heavy-output skill ships.

### Mitigations

- The static NFR-003 audit (Phase 5 plan 02, `core/tests/nfr_audits.bats` @test for NFR-003) catches accidental `>` writes to STATE.md outside `state_append()`. The same audit pattern can be extended in a future plan to catch out-of-band writes to `$TASK_DIR` outside the adapter's propagation loop, if such drift surfaces.
- Code review of any new harness adapter MUST include explicit verification of the exclusion list against this ADR.
- A future v0.2+ may add transactional propagation (`cp` to `$TASK_DIR/.staging/`, then atomic rename) if a real partial-propagation failure mode surfaces in production.

---

## Alternatives considered

### Alternative A -- Skill writes directly to TASK_DIR

**Description.** Make the skill body responsible for resolving `$CHANTIER_TASK_DIR` (exported by `env.sh`) and write `output.md` + `output.json` directly to that path, skipping the dossier-root emission entirely.

**Why rejected.** Couples every skill body to the adapter's environment-variable contract. Phase 3 D-04 deliberately made the skill body's emission target `$PWD` so that the skill code is trivially portable: `cat > output.md` works under any dispatcher that arranges the working directory correctly. Requiring `cat > "$CHANTIER_TASK_DIR/output.md"` exports knowledge of the canonical state-writes layout into every skill body, multiplying the surface that must change if the path convention ever evolves. ADR 0001 §Decision foundationally requires that skills be readable with `cat` / `jq` / `grep` without harness-aware indirection; Alternative A undermines that posture.

### Alternative B -- Symlink dossier root to TASK_DIR before dispatch

**Description.** Before dispatch, `ln -s "$TASK_DIR" "$DOSSIER"` (or the inverse) so that any write inside the dossier appears under the task directory automatically.

**Why rejected.** Couples two namespaces that ADR 0001 treats as distinct. A failing skill (exit non-zero, partial outputs) leaves partial state at the canonical task-directory path before the gate runs; ADR 0001 §Validation gate expects to operate on final state, not in-flight state. The Phase 4 D-04 exit-matrix (move output.{md,json} to `attempts/<NN>/` on failure) would also have to learn about the symlink semantics, multiplying the special cases. Per-file `cp` after a green dispatch is conceptually simpler and operationally safer.

### Alternative C -- Skill emits a manifest, adapter consumes it

**Description.** Have the skill emit a `MANIFEST.json` declaring which files in the dossier should be promoted to the task directory; the adapter reads the manifest and copies only the declared files.

**Why rejected.** Adds a new file format and a new contract surface (Surface 3a) for negligible benefit. The current `cp dossier/* -> TASK_DIR/` with a four-entry exclusion list achieves the same outcome -- propagate all plain skill output, exclude only the adapter-owned bookkeeping -- with no new format. The manifest approach would also require schema validation, version evolution, and every skill author to remember to emit it. The static exclusion list lives in one place (the adapter), is reviewable by inspection, and adds zero burden on skill authors.

---

## Open questions (deferred)

This ADR does not decide the following. They are flagged for resolution in subsequent ADRs or in the post-ratification revision of this ADR:

1. **Subdirectory propagation.** The current contract copies only plain files in `$DOSSIER/` root. If a future skill writes artifacts into a subdirectory of the dossier (`attempts/`, `logs/`, `screenshots/`), the propagation step does not promote them to the task directory. Phase 5 dogfood does not exercise this. Revisit if a v0.2+ skill needs subdirectory artifacts at the canonical task-directory path.

2. **Atomic propagation.** The current `cp` is per-file. A killed adapter mid-propagation leaves `$TASK_DIR` partial. Phase 4 has not surfaced this in production; v0.2+ may add a transactional rename pattern (`cp` to `$TASK_DIR/.staging/`, then `mv` to final location) if a failure mode surfaces.

3. **Exclusion-list canonicalization.** Should the list of excluded filenames live in a single canonical place (e.g., `core/schemas/adapter-exclusions.json`) read by every adapter, or remain inlined in each `run-task.sh`? Trade-off: DRY across adapters versus POSIX-shell-portable JSON parsing in each adapter. Defer until a second adapter ships and the drift cost is observable.

---

## Ratification path

This ADR remains in **Proposed** status until:

1. A second harness adapter (e.g., `adapters/cursor/`, `adapters/codex-cli/`) ships and exercises the Surface 3 propagation contract.
2. A bats test under `tests/e2e/` proves the contract works on both adapters: `output.md` and `output.json` land in `$TASK_DIR`; excluded artifacts (`inputs.yml`, `env.sh`, `subagent.transcript.log`, the three subdirectories) remain only in the dossier.
3. A founding contributor (or, post-Org-formed stage, a maintainer) reviews this ADR with cross-harness evidence and either updates the contract or moves status to **Accepted**.

Until ratification, this ADR is advisory. The first cross-harness propagation pull request should reference this ADR explicitly and call out any deviation, so deviations are visible rather than implicit.

---

## References

- `docs/adr/0001-state-skill-contract.md` §Surface 3 -- establishes that `output.md` + `output.json` are mandatory and resolves the destination paths to `.planning/phases/<phase>/tasks/<task>/`.
- `docs/adr/0001-state-skill-contract.md` §Surface 2 -- establishes the dossier model that propagation copies FROM; the example at line 134 shows `upstream/t0/output.json` at the canonical task-directory path that propagation must produce.
- `docs/adr/0002-runtime-binary-and-state-format.md` -- defines the exit-code matrix the adapter honors when propagation succeeds (exit 0) or the wrapped subagent fails (exit 1, with outputs moved to `attempts/<NN>/`).
- `docs/adr/0003-workflow-skill-design-principles.md` -- Principle 4 (chaining is explicit in PLAN.md, not magic in skills) reinforces the position that propagation belongs in the adapter, not in implicit skill-to-skill composition.
- `.planning/phases/04-claude-code-adapter/04-03-SUMMARY.md` -- the discovery moment and the patch that this ADR codifies.
- `adapters/claude-code/run-task.sh` (Section 5 "Surface 3 propagation" -- approximately lines 221-238 at the time of writing) -- the in-tree implementation that this ADR promotes to a cross-adapter contract.
- `.planning/phases/05-dogfood-e2e/05-CONTEXT.md` §D-09 -- the locked decision authorizing this ADR's authorship in Phase 5 Proposed status with deferred ratification.
- `.planning/REQUIREMENTS.md` §Acceptance -- the v0.1.0 ship clause "ADR record contains ... at least one ADR resolving one of the four deferred questions from ADR 0001" that ADR 0004 helps satisfy.
