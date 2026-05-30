# Phase 2: Runtime core - Research

**Researched:** 2026-05-29
**Domain:** Portable POSIX shell binary (`core/bin/chantier`) + jq-driven JSONL state log + JSON Schema draft-07 frontmatter validation
**Confidence:** HIGH for stack/portability findings; MEDIUM for the jq-as-schema-validator design (a deliberate trade-off, not a borrowed pattern)

## Summary

Phase 2 ships Chantier's first runtime artefact: a single-file POSIX shell + jq binary. Every implementation decision below flows from three immovable constraints recorded in `.planning/REQUIREMENTS.md`:

- **NFR-001 portability** — no bash-isms, no GNU-only flags, no harness identifiers in the binary.
- **NFR-002 trust surface** — single-file, no sourcing of helpers, dependency set capped at POSIX `sh` + `jq`.
- **NFR-004 no network** — the binary may never reach the network.

Two of the load-bearing questions in `<research_focus>` have non-obvious answers that the planner must internalise:

1. **`flock(1)` is not portable.** macOS Darwin does not ship `flock`. This was confirmed by direct probe of the target machine — `command -v flock` returned empty. The binary must use a portable shell-implemented lock (canonical pattern: `mkdir`-as-mutex with `trap` cleanup and stale-PID detection). `[VERIFIED: bash-hackers wiki + direct env probe on the host machine]`
2. **No pure-jq JSON Schema draft-07 validator exists in the public ecosystem.** A focused search of jqlang/jq issues, GitHub Marketplace, and the schema validator ecosystem found Java/JavaScript/Python implementations only. `[VERIFIED: jqlang/jq#3437 — open request, no implementation]`. The pragmatic resolution: implement a **constrained subset** of draft-07 inline in jq (the only keywords Phase 2 actually needs: `type`, `required`, `properties`, `additionalProperties`, `pattern`, `enum`) and explicitly document in ADR 0002 that Chantier validates a draft-07 *profile*, not the full spec. This keeps NFR-002 intact.

A third finding the planner must surface: **`yq` is not on the target machine**, and Chantier cannot acquire it without violating NFR-002 (single-file binary). YAML frontmatter must therefore be extracted with awk+sed and converted to JSON inline via a small jq-friendly representation. See §"Don't Hand-Roll" for the trade-off and the recommended approach.

**Primary recommendation:** Build the binary as a single POSIX `sh` script with `case "$1" in` dispatch and one shell function per subcommand. Use the `mkdir`-based lock pattern for concurrency. Validate JSON Schema draft-07 with an inline jq subset-validator that the ADR 0002 explicitly scopes. Render `state show` with jq `@tsv` → null-placeholder substitution → `column -t -s $'\t'`. Vendor `bats-core` + `bats-assert` + `bats-support` under `core/tests/test_helper/` as git submodules (not shipped in runtime artefacts, per D-Discretion #3).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| State mutation (`state append`) | Single-file binary (`core/bin/chantier`) | — | NFR-002 caps dependency set to `sh`+`jq`; only the binary writes `STATE.md`. |
| State rendering (`state show`) | Single-file binary | — | Lives next to the writer so the JSONL contract has one canonical reader/writer pair. |
| JSONL schema enforcement | Inline jq filters embedded in the binary | `core/schemas/*.json` (canonical text) | Schemas are runtime-imported but the *validator* is jq logic in the binary. |
| YAML frontmatter extraction | awk+sed inline functions in the binary | — | No `yq` allowed (NFR-002). Must be self-contained. |
| Concurrency control | `mkdir`-as-mutex with `trap` cleanup, shell-implemented | — | `flock(1)` absent on macOS — pure-shell pattern is the only portable option. |
| Scaffolding (`new <name>`) | Shell heredoc functions in the binary | — | NFR-002: no external template files. Heredocs keep templates inside the single binary. |
| Test execution | `bats-core` in `core/tests/` (host-side dev tool, not shipped) | — | D-Discretion #3: bats is dev-time only; runtime never invokes it. |
| ADR 0002 publication | Markdown file at `docs/adr/0002-*.md` | — | Documentation tier — no runtime coupling. |

## Project Constraints (from CLAUDE.md)

No `./CLAUDE.md` exists in the project root. The user's global `~/.claude/CLAUDE.md` only loads ruflo MCP routing and memory hooks — none of those directives apply to research output. Project-specific constraints are derived entirely from `REQUIREMENTS.md` (NFR-001..NFR-006) and `docs/adr/0001-state-skill-contract.md`.

## User Constraints (from CONTEXT.md)

### Locked Decisions

> Copied verbatim from `.planning/phases/02-runtime-core/02-CONTEXT.md`. The planner MUST honour these without alternative exploration.

- **D-01** `STATE.md` body is JSON Lines. One event per line, one JSON object per event, append-only.
- **D-02** Schema of each line: `{ "ts": <ISO-8601 UTC string>, "event": <dotted-name string>, "actor": <string>, "task": <string|null>, "skill": <string|null>, "summary": <string>, "refs": [<string>...] }`. `task`/`skill` are nullable for non-task events.
- **D-03** Ship `chantier state show` as a first-class subcommand rendering the JSONL body as a fixed-width column table.
- **D-04** Migration of the 10 existing rows in `.planning/STATE.md` to JSONL happens in a dedicated commit at Phase 2 ship time. Bump frontmatter `format_version` to `0.1.0`. Commit message documents the migration explicitly.
- **D-05** Hybrid strict/permissive front-matter validation: `required` strict, others permissive with warning for unknown top-level keys.
- **D-06** Schemas live in `core/schemas/{project,requirements,roadmap,plan,skill}.json` as canonical JSON Schema draft-07 documents. ADR 0002 quotes them inline.
- **D-07** Required fields per schema derived from ADR 0001 Surface 1 (PLAN.md, SKILL.md) and from current usage in `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`. ADR 0002 enumerates and freezes them for v0.1.
- **D-08** Event names follow a documented dotted-namespace `{noun}.{verb}` convention. No closed registry at runtime.
- **D-09** `chantier state append --event X` validates the shape of `X` against `^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$` and rejects mismatches.
- **D-10** ADR 0002 publishes an indicative (non-exhaustive) recommended events list grouped by namespace.
- **D-11** Scaffold produces commented stubs: minimal mandatory frontmatter + empty section headings + HTML-comment TODO guides.
- **D-12** Scaffold output is English-only for v0.1.
- **D-13** Scaffold files produced: `PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md`, `config.json`. `STATE.md` is JSONL-empty (frontmatter only, body empty, ready for first append).

### Claude's Discretion

> Copied verbatim. These are implementation defaults the researcher may refine. See §"Claude's Discretion review" at end of this document for the refinement verdicts.

- **Concurrency** — `flock(1)` with macOS BSD ⇄ Linux util-linux compat wrapper.
- **Argument parsing** — POSIX `getopts` short flags only.
- **Test framework** — `bats-core` in `core/tests/`, not shipped in runtime artefacts.
- **Binary structure** — Single-file `core/bin/chantier` with `case "$1" in` dispatch.
- **`validate-task` portability deny-list** — `mcp__`, `claude_ai_`, `@codebase`, harness names `claude-code`, `cursor`, `codex-cli`, `copilot-cli`, `gemini-cli`, `opencode`.
- **Error model** — Exit codes 0 (success), 1 (contract violation), 2 (runtime error), 3 (usage error). JSON errors on `--json-errors`, plain text otherwise.
- **`output.md` Acceptance section** — heading regex `^##\s+Acceptance\s*$`, body must contain one item per acceptance criterion in PLAN.md.
- **Self-test** — `chantier --self-test` checks jq present, flock available, schemas parse, all subcommands respond to `--help`.

### Deferred Ideas (OUT OF SCOPE)

- STATE.md compaction strategy
- `chantier.lock` skill version pinning
- `inputs_schema` strictness mode
- Skill-to-skill composition syntax
- Second harness adapter (v0.2.0)
- `chantier state compact`, `chantier state query`
- Long-flag (`--event`) aliases on subcommand args
- i18n of `chantier new` scaffold

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FR-001 | `core/bin/chantier` exists as POSIX shell + jq, no harness-specific dependencies. | §"Standard Stack" identifies the stack; §"Common Pitfalls #1-3" guards against bash-ism leaks; §"Architecture Patterns" describes the single-file dispatch shape. |
| FR-002 | `chantier new <name>` scaffolds `.planning/` with empty `PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md`, `config.json`. | §"Code Examples" provides the heredoc-based scaffold pattern that lives inside the single binary (NFR-002 compliant). |
| FR-003 | `chantier state append --event X --task Y --skill Z --summary "…"` appends exactly one event row to `STATE.md`. | §"Architecture Patterns - Pattern 3 (Atomic JSONL append)" and §"Common Pitfalls #4-5" cover lock acquisition, line-buffered atomicity, and concurrent-reader safety. |
| FR-004 | `chantier validate-task <task>` checks `state_writes` containment, output schema presence, and acceptance-section presence; non-zero exit on failure. | §"Architecture Patterns - Pattern 4 (Five validation gates)" maps ADR 0001's five gates to concrete shell checks with the exit-code matrix from CONTEXT.md (0/1/2/3). |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---|---|---|---|
| POSIX `sh` (dash semantics) | n/a (dash 0.5.x on Debian, `/bin/sh` on macOS) | Binary interpreter | NFR-001 demands POSIX-only; targeting `dash`-level semantics is the de facto portable-shell target (Alpine BusyBox `ash`, Debian `dash`, macOS `/bin/sh`, FreeBSD `sh` all converge here). `[CITED: oneuptime.com POSIX guide, OpenRC service-script-guide.md]` |
| `jq` | 1.7.1+ (1.7.1-apple confirmed on host) | JSON parsing, JSONL streaming, schema-validator subset | The only JSON tool the project allows. Phase 1 already standardised on it in ADR 0001's "cat/jq/grep" inspectability promise. `[VERIFIED: direct env probe on host]` |

### Supporting (dev-time only, never shipped at runtime)

| Library | Version | Purpose | When to Use |
|---|---|---|---|
| `bats-core` | 1.13.0 (Nov 2025) | Shell unit tests | Wave 1+ test tasks. `[VERIFIED: bats-core/bats-core github releases]` |
| `bats-assert` | 2.1.0 | Richer assertions (`assert_output`, `assert_failure`) | Same. Vendored as submodule under `core/tests/test_helper/bats-assert/`. `[VERIFIED: bats-core/bats-assert v2.1.0 tag]` |
| `bats-support` | latest tag | Required dependency of bats-assert | Same. Submodule under `core/tests/test_helper/bats-support/`. `[CITED: bats-core docs]` |
| `shellcheck` | 0.10+ | Static analysis of POSIX shell | Phase-gate check task; flags bash-isms, set -e gotchas, IFS bugs. `[CITED: shellcheck.net]` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| `mkdir`-as-mutex (recommended) | `flock(1)` directly | `flock` absent on macOS — would require Homebrew install step that violates "POSIX shell + jq only" promise of NFR-002. `[VERIFIED: env probe]` |
| `mkdir`-as-mutex (recommended) | `ln -s` symlink-as-mutex | Equivalent atomicity, but symlinks introduce filesystem-mode quirks on NFS and on case-insensitive macOS FS. `mkdir` is the unambiguous winner. `[CITED: bash-hackers wiki]` |
| `mkdir`-as-mutex (recommended) | `set -C` (noclobber redirect) | Subtle: `set -C` is POSIX, but its lock semantics break in subshell pipelines, and recovery from an orphaned lock file is harder than `rmdir` of an orphaned directory. `[CITED: bash-hackers wiki]` |
| Inline jq schema subset (recommended) | `ajv` CLI shellout | Violates NFR-002 (adds Node.js dependency); not a single-file binary anymore. |
| Inline jq schema subset (recommended) | `check-jsonschema` (Python) | Same problem. Adds Python + pip. |
| awk+sed YAML extractor (recommended) | `yq` (Go binary) | A static `yq` binary is portable but cannot be vendored inside `core/bin/chantier` as a single file; it would be a second runtime dependency, violating the "POSIX + jq" promise. `[VERIFIED: mikefarah/yq is Go-compiled, not pure shell]` |
| awk+sed YAML extractor (recommended) | `yaml.sh` (pure bash) | Pure bash, not POSIX sh; uses bash arrays. Would need substantial rewrite for `dash` compatibility. |

**Installation (host dev environment, not shipped):**
```bash
# macOS
brew install bats-core shellcheck
# bats-assert & bats-support vendored via git submodule into core/tests/test_helper/
git submodule add https://github.com/bats-core/bats-support core/tests/test_helper/bats-support
git submodule add https://github.com/bats-core/bats-assert  core/tests/test_helper/bats-assert
```

**Version verification (performed on host 2026-05-29):**
- `jq`: `/usr/bin/jq → 1.7.1-apple` `[VERIFIED: direct probe]`
- `flock`: **NOT PRESENT** on macOS Darwin 24.6.0 — confirms the mkdir-lock recommendation is mandatory, not optional. `[VERIFIED: direct probe]`
- `bats`: not installed — Wave 0 must install. `[VERIFIED: direct probe]`
- `yq`: not installed — confirms the awk+sed YAML extractor decision. `[VERIFIED: direct probe]`
- `shellcheck`: not installed — Wave 0 must install. `[VERIFIED: direct probe]`
- `dash`: `/bin/dash` present on macOS host — usable as a stricter-POSIX test interpreter in CI. `[VERIFIED: direct probe]`

## Package Legitimacy Audit

Phase 2 installs **zero packages into the shipped runtime** (the binary is single-file POSIX `sh` + a host-provided `jq`). The only "packages" involved are dev-time tools the contributor installs locally to run the test suite. None are wired into the binary or any shipped artefact.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---|---|---|---|---|---|---|
| `bats-core` | Homebrew + npm | 12+ yrs (since 2014) | Tens of thousands/wk on Homebrew analytics | github.com/bats-core/bats-core | not run (slopcheck unavailable on host) | Approved — vintage, MIT, ~14k ⭐. `[ASSUMED]` pending slopcheck run. |
| `bats-assert` | git submodule | 8+ yrs | n/a (submodule) | github.com/bats-core/bats-assert | not run | Approved — same org as bats-core. `[ASSUMED]` |
| `bats-support` | git submodule | 8+ yrs | n/a (submodule) | github.com/bats-core/bats-support | not run | Approved — same org. `[ASSUMED]` |
| `shellcheck` | Homebrew + apt | 13+ yrs | Heavy adoption | github.com/koalaman/shellcheck | not run | Approved — industry-standard. `[ASSUMED]` |

**Packages removed due to slopcheck [SLOP] verdict:** none (slopcheck not executed; see "Graceful degradation" note in the legitimacy gate protocol — all four are tagged `[ASSUMED]` and the planner should insert a `checkpoint:human-verify` gate before the Wave 0 install task, *but* these four projects are well-known, audit-able shell repositories with a decade-plus track record. The planner may reasonably collapse the verification into a single confirmation step rather than four.).

**Packages flagged as suspicious [SUS]:** none.

## Architecture Patterns

### System Architecture Diagram

```
                            ┌────────────────────────────────────┐
                            │  human (developer / CI runner)     │
                            │  $ chantier <subcmd> [opts...]     │
                            └─────────────────┬──────────────────┘
                                              │ POSIX exec
                                              ▼
                            ┌────────────────────────────────────┐
                            │      core/bin/chantier             │
                            │  (single POSIX sh file)            │
                            │                                    │
                            │  case "$1" in                      │
                            │    state)        state_*           │ ─── opens jq pipeline
                            │    validate-task) validate_task_*  │ ─── opens jq pipeline
                            │    new)          new_project       │ ─── heredoc templates
                            │    --self-test)  self_test         │
                            │    --help|*)     usage             │
                            │  esac                              │
                            └──┬──────────┬──────────┬───────────┘
                               │          │          │
            ┌──────────────────┘          │          └─────────────────────┐
            ▼                              ▼                                ▼
  ┌──────────────────────┐    ┌──────────────────────────┐    ┌────────────────────────┐
  │ acquire_lock()       │    │ jq schema-subset filter  │    │ .planning/ scaffold    │
  │   mkdir LOCKDIR ||   │    │   (validates required,   │    │   heredocs emit:       │
  │   stale check &&     │    │    type, pattern, enum,  │    │     PROJECT.md         │
  │   rmdir              │    │    additionalProperties) │    │     REQUIREMENTS.md    │
  │ trap rmdir EXIT      │    │   loaded from core/      │    │     ROADMAP.md         │
  └──────────┬───────────┘    │   schemas/*.json         │    │     STATE.md (empty    │
             │                └────────────┬─────────────┘    │       JSONL body,      │
             ▼                             │                  │       full frontmatter)│
  ┌──────────────────────┐                 │                  │     config.json        │
  │ append one JSON line │                 │                  └────────────────────────┘
  │ to .planning/STATE.md│                 │
  │ (line-buffered fwrite│                 │
  │  >= one O_APPEND syscall)              │
  └──────────────────────┘                 │
                                            ▼
                        ┌────────────────────────────────────┐
                        │   .planning/                       │
                        │   ├── STATE.md     (frontmatter +  │
                        │   │                 JSONL events)  │
                        │   ├── PROJECT.md   (frontmatter +  │
                        │   │                 markdown body) │
                        │   ├── REQUIREMENTS.md              │
                        │   └── ROADMAP.md                   │
                        └────────────────────────────────────┘
```

**Data-flow narrative for the primary use case (`chantier state append`):**
1. User invokes `chantier state append -e task.completed -t t1 -s tdd -m "..." -r commit/abc`.
2. Dispatcher matches `state` → calls `state_dispatch` → matches `append` → calls `state_append`.
3. `state_append` parses flags with `getopts`, validates each (event regex D-09, summary non-empty, refs append-accumulated).
4. `acquire_lock()` runs `mkdir "$LOCKDIR"` atomically; on success a trap is armed to `rmdir "$LOCKDIR"` on EXIT.
5. `jq -nc '{ts:..., event:..., ...}'` constructs exactly one minified JSON object on stdout.
6. The object is appended to `.planning/STATE.md` with `>> "$STATE_FILE"`. POSIX file-append semantics guarantee the entire write is one `O_APPEND` syscall; concurrent appends from another process may interleave at **line boundaries** but not within a line (because the JSON is built fully before the redirect).
7. Trap fires, `rmdir "$LOCKDIR"`, exit 0.

### Recommended Project Structure

```
core/
├── bin/
│   └── chantier              # the single-file binary (≤ ~800 lines POSIX sh)
├── schemas/
│   ├── project.json          # JSON Schema draft-07 (subset profile, see §"Don't Hand-Roll")
│   ├── requirements.json
│   ├── roadmap.json
│   ├── plan.json
│   └── skill.json
└── tests/
    ├── bats/                 # git submodule → bats-core/bats-core
    ├── test_helper/
    │   ├── bats-assert/      # git submodule
    │   └── bats-support/     # git submodule
    ├── state_append.bats
    ├── state_show.bats
    ├── validate_task.bats
    ├── new.bats
    ├── self_test.bats
    └── fixtures/
        ├── PLAN.valid.md
        ├── PLAN.invalid-missing-required.md
        ├── output.valid.md
        └── output.missing-acceptance.md

docs/adr/
├── 0001-state-skill-contract.md   # existing
└── 0002-runtime-binary-and-state-format.md   # new this phase

.planning/STATE.md            # migrated to JSONL in a dedicated commit
.planning/STATE.md.bak        # NOT COMMITTED — discarded after migration verification
```

### Pattern 1: Single-file POSIX shell binary with `case`-dispatch
**What:** One executable file. First-line shebang `#!/bin/sh`. Optional `set -eu` at the top (no `-o pipefail` — not POSIX). `case "$1" in` matches the subcommand, shifts, dispatches to a shell function declared earlier in the same file.
**When to use:** This is the canonical shape for portable CLI tools that must be distributable as a single `chmod +x` file — git's own hooks, openrc init scripts, busybox applets all follow this template.
**Example:**
```sh
#!/bin/sh
# Source: pattern derived from openrc service-script-guide.md + git pre-commit hook canon
# [CITED: github.com/OpenRC/openrc/blob/master/service-script-guide.md]
set -eu
IFS=' 	
'  # explicit IFS reset: space + tab + newline (POSIX-safe default)
LC_ALL=C  # eliminate locale-dependent sort/regex behavior (NFR-001 portability)
export LC_ALL

CHANTIER_VERSION="0.1.0"
STATE_FILE=".planning/STATE.md"
LOCKDIR=".planning/.chantier.lock"
SCHEMAS_DIR="$(dirname "$(readlink "$0" 2>/dev/null || printf '%s' "$0")")/../schemas"

usage() {
    cat <<'EOF'
chantier — portable state/skill runtime
Usage:
  chantier state append -e EVENT -t TASK -s SKILL -m SUMMARY [-r REF...]
  chantier state show
  chantier validate-task TASK_ID
  chantier new NAME
  chantier --self-test
  chantier --help
EOF
}

state_append()   { ...; }
state_show()     { ...; }
validate_task()  { ...; }
new_project()    { ...; }
self_test()      { ...; }

case "${1:-}" in
    state)
        shift
        case "${1:-}" in
            append) shift; state_append "$@" ;;
            show)   shift; state_show   "$@" ;;
            *) printf 'unknown state subcommand: %s\n' "${1:-}" >&2; exit 3 ;;
        esac
        ;;
    validate-task) shift; validate_task "$@" ;;
    new)           shift; new_project   "$@" ;;
    --self-test)   self_test ;;
    --help|-h|"")  usage ;;
    *) printf 'unknown subcommand: %s\n' "$1" >&2; exit 3 ;;
esac
```

### Pattern 2: `mkdir`-as-mutex with stale-PID detection
**What:** Use atomic `mkdir` to acquire an exclusive directory-lock. Store the caller's `$$` inside. On contention, check whether the holder PID still exists; if not, the lock is stale and we recover.
**When to use:** Every `state append` invocation. Phase 4 will dispatch subagents in parallel; without serialisation the JSONL stream corrupts when two `printf '%s\n' "$json" >> STATE.md` calls interleave at sub-line granularity.
**Example:**
```sh
# Source: bash-hackers.gabe565.com/howto/mutex/ (canonical pattern), simplified for POSIX sh
# [CITED: bash-hackers wiki — mkdir-as-mutex with PID & trap]
LOCKDIR=".planning/.chantier.lock"
PIDFILE="${LOCKDIR}/PID"

acquire_lock() {
    # First attempt
    if mkdir "$LOCKDIR" 2>/dev/null; then
        printf '%s\n' "$$" > "$PIDFILE"
        trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT INT TERM HUP
        return 0
    fi

    # Contention — check for stale lock
    if [ -f "$PIDFILE" ]; then
        OTHERPID=$(cat "$PIDFILE" 2>/dev/null) || OTHERPID=""
        if [ -n "$OTHERPID" ] && ! kill -0 "$OTHERPID" 2>/dev/null; then
            # holder is gone — recover
            rm -rf "$LOCKDIR"
            if mkdir "$LOCKDIR" 2>/dev/null; then
                printf '%s\n' "$$" > "$PIDFILE"
                trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT INT TERM HUP
                return 0
            fi
        fi
    fi

    printf 'chantier: state log busy (lock held by PID %s)\n' "${OTHERPID:-unknown}" >&2
    return 2
}
```
**Caveats** `[CITED: bash-hackers wiki]`:
- NFS — `mkdir` atomicity over NFS is *generally* honoured but is not guaranteed. Acceptable for v0.1 (Chantier is a local-dev tool).
- After a hard crash where the OS truncates the lock dir but not the PIDFILE, `kill -0` will report "no such process" and recovery triggers. This is correct.
- The lock's owner is the *parent* shell. If the binary fork-execs a subprocess that holds the lock, the trap on the parent is what releases it — which is exactly what we want.

### Pattern 3: Atomic JSONL append
**What:** Build the complete JSON object first (in jq, stdout-captured into a shell variable), then append the **single line** to `STATE.md` using `>>` redirection. Under the lock from Pattern 2, this is race-free.
**When to use:** Inside `state_append` after lock acquisition.
**Example:**
```sh
# [VERIFIED: jsonlines.org spec — "values can be appended at the end (possibly by concurrent producers)"]
# [CITED: jameshfisher.com — concurrent fwrites are NOT atomic; the lock above is what guarantees atomicity]
state_append() {
    EVENT="" TASK="" SKILL="" SUMMARY="" REFS=""
    while getopts ":e:t:s:m:r:" opt; do
        case "$opt" in
            e) EVENT="$OPTARG" ;;
            t) TASK="$OPTARG"  ;;
            s) SKILL="$OPTARG" ;;
            m) SUMMARY="$OPTARG" ;;
            r) REFS="${REFS}${REFS:+$NL}${OPTARG}" ;;  # accumulate with newline
            \?) printf 'unknown flag -%s\n' "$OPTARG" >&2; exit 3 ;;
            :)  printf 'flag -%s requires a value\n' "$OPTARG" >&2; exit 3 ;;
        esac
    done

    [ -n "$EVENT" ]   || { printf 'missing required -e\n' >&2; exit 3; }
    [ -n "$SUMMARY" ] || { printf 'missing required -m\n' >&2; exit 3; }

    # D-09 event-shape regex
    case "$EVENT" in
        *[!a-z0-9.]*|[!a-z]*|*..*|.*|*.) printf 'event name does not match ^[a-z][a-z0-9]*(\\.[a-z][a-z0-9]*)+$\n' >&2; exit 1 ;;
    esac
    # Final positive check via jq regex (jq has full PCRE-ish regex via test())
    printf '%s\n' "$EVENT" | jq -R -e 'test("^[a-z][a-z0-9]*(\\.[a-z][a-z0-9]*)+$")' >/dev/null \
        || { printf 'event name fails shape regex\n' >&2; exit 1; }

    TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    ACTOR=$(git config user.name 2>/dev/null || printf 'unknown')

    acquire_lock || exit $?

    # Build refs array from newline-separated REFS, handle empty cleanly
    LINE=$(
        printf '%s\n' "$REFS" \
        | jq -R -s --arg ts "$TS" --arg ev "$EVENT" --arg ac "$ACTOR" \
                  --arg ta "${TASK:-}" --arg sk "${SKILL:-}" --arg sm "$SUMMARY" \
            'split("\n") | map(select(length>0))
             | { ts: $ts, event: $ev, actor: $ac,
                 task: (if $ta=="" then null else $ta end),
                 skill: (if $sk=="" then null else $sk end),
                 summary: $sm, refs: . }
             | tostring'
    )

    printf '%s\n' "$LINE" >> "$STATE_FILE"
}
```

### Pattern 4: Five validation gates → concrete shell checks (FR-004)

This pattern maps ADR 0001's §"Validation gate" five-item list to executable checks in `validate_task`. Each gate has an exit-code mapping per the Claude's Discretion error model (0 success / 1 contract violation / 2 runtime error / 3 usage error).

| ADR 0001 gate | Shell check | Failure exit code |
|---|---|---|
| 1. Every path the skill wrote is inside `state_writes` | Diff `git status --porcelain` (or a stored pre-task snapshot of `find -newer`) against the union of glob-expanded `state_writes` entries declared in the task block. Any path outside → violation. | 1 |
| 2. `output.md` exists and is non-empty | `[ -s "$TASK_DIR/output.md" ]` | 1 |
| 3. `output.json` matches `outputs_schema` | Invoke the jq schema-subset validator (Pattern 5) against `$TASK_DIR/output.json` using the schema literal from SKILL.md frontmatter `outputs_schema` | 1 |
| 4. Portable: no harness identifier in skill body files (if `portable: true`) | `grep -E "mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode" $SKILL_BODY_FILES` → if any match, violation | 1 |
| 5. PLAN.md acceptance items present in `output.md` "Acceptance" section | (a) Extract task block's `acceptance:` list with awk+sed. (b) Locate `^## Acceptance` heading in output.md. (c) Confirm each acceptance string appears as a bullet/numbered item in the section body. | 1 |

**Idiom for gate 5 (the trickiest):**
```sh
# Extract acceptance criteria from PLAN.md task block (yaml fenced under heading)
extract_acceptance() {
    plan="$1"
    task="$2"
    awk -v task="$task" '
        /^```yaml/ { in_yaml=1; buf=""; next }
        /^```/ && in_yaml { in_yaml=0; if (buf ~ "task: " task) print buf; buf=""; next }
        in_yaml { buf = buf $0 "\n" }
    ' "$plan" | awk '
        /^acceptance:/  { collecting=1; next }
        /^[a-z]/        { collecting=0 }
        collecting && /^[[:space:]]+-/ {
            sub(/^[[:space:]]+-[[:space:]]*"?/, "")
            sub(/"?[[:space:]]*$/, "")
            print
        }
    '
}

# Extract Acceptance section body from output.md
extract_output_acceptance_body() {
    out="$1"
    awk '
        /^##[[:space:]]+Acceptance[[:space:]]*$/ { collecting=1; next }
        /^##[[:space:]]/                         { collecting=0 }
        collecting { print }
    ' "$out"
}

# Confirm each criterion appears in the section body
verify_acceptance() {
    plan="$1"; task="$2"; out="$3"
    body=$(extract_output_acceptance_body "$out")
    missing=0
    extract_acceptance "$plan" "$task" | while IFS= read -r crit; do
        case "$body" in
            *"$crit"*) ;;
            *) printf 'missing acceptance: %s\n' "$crit" >&2; missing=1 ;;
        esac
    done
    return "$missing"
}
```

### Pattern 5: Constrained jq draft-07 schema validator

**What:** A jq filter that validates a target JSON value against a *subset* of JSON Schema draft-07. The subset Phase 2 needs:
- `type` (string, only checking `string`, `number`, `boolean`, `array`, `object`, `null`)
- `required` (array of property names)
- `properties` (per-property schemas, recursively validated)
- `additionalProperties: false` (controlled by hybrid D-05: strict on required keys, permissive elsewhere)
- `pattern` (regex match on string values)
- `enum` (whitelist of values)
- `items` (uniform schema for array items)

**What it explicitly does NOT cover** (ADR 0002 must state these limitations):
- `$ref` (out — Phase 2 schemas are self-contained)
- `oneOf`/`anyOf`/`allOf`/`not` (out — not needed for current frontmatter shapes)
- `if`/`then`/`else` (out)
- `format` validators beyond simple regex (out)
- `definitions`/`$defs` (out — same as `$ref`)
- Numeric constraints (`minimum`/`maximum`/`multipleOf`) (out — no current use)

**Example (the validator filter itself, embeddable in the binary):**
```sh
# [VERIFIED: hand-implementation; no upstream pure-jq validator exists per jqlang/jq#3437]
# Validates $TARGET against $SCHEMA using a jq subset-validator.
# Emits violations on stderr (one per line), returns non-zero on any violation.

validate_against_schema() {
    target="$1"   # path to JSON file
    schema="$2"   # path to schema file

    jq -e -n \
        --slurpfile data   "$target" \
        --slurpfile schema "$schema" \
        '
        def validate($s; $path):
            $s as $sc
            | . as $v
            | [
                # type check
                (if $sc.type then
                    (if ($v|type) != $sc.type
                        and not ($sc.type == "number" and ($v|type) == "number")
                     then "\($path): expected type \($sc.type), got \($v|type)"
                     else empty end)
                 else empty end),

                # required fields (only meaningful for objects)
                (if $sc.required and ($v|type) == "object" then
                    ($sc.required[] | select(. as $k | $v | has($k) | not)
                        | "\($path).\(.): required field missing")
                 else empty end),

                # additionalProperties:false enforcement (strict-mode keys only)
                (if $sc.additionalProperties == false and ($v|type) == "object" then
                    (($v|keys) - ($sc.properties|keys))[]
                        | "\($path).\(.): unknown property (additionalProperties:false)"
                 else empty end),

                # pattern
                (if $sc.pattern and ($v|type) == "string" then
                    (if ($v | test($sc.pattern)) | not
                     then "\($path): value \"\($v)\" does not match pattern /\($sc.pattern)/"
                     else empty end)
                 else empty end),

                # enum
                (if $sc.enum then
                    (if ($sc.enum | index($v)) == null
                     then "\($path): value not in enum \($sc.enum|tojson)"
                     else empty end)
                 else empty end),

                # recurse into properties
                (if $sc.properties and ($v|type) == "object" then
                    ($sc.properties | to_entries[]) as $entry
                    | (if $v | has($entry.key)
                       then $v[$entry.key] | validate($entry.value; "\($path).\($entry.key)")
                       else empty end)
                 else empty end),

                # recurse into items
                (if $sc.items and ($v|type) == "array" then
                    range(0; $v|length) as $i
                    | $v[$i] | validate($sc.items; "\($path)[\($i)]")
                 else empty end)
              ]
              | flatten | .[];

        ($data[0]) | validate($schema[0]; "$") | tostring
        ' 2>&1 | (
            count=0
            while IFS= read -r line; do
                printf 'schema violation: %s\n' "$line" >&2
                count=$((count + 1))
            done
            [ "$count" -eq 0 ]
        )
}
```

This is a load-bearing trade-off — see §"Don't Hand-Roll" for the discussion of why we accept implementing a schema-validator in-tree.

### Pattern 6: `state show` rendering (D-03)

**What:** Pipe the JSONL body of `STATE.md` through jq to extract a TSV with **null fields rendered as a non-empty placeholder** (BSD `column` collapses empty fields, breaking columns), then through `column -t -s $'\t'`.

**Why the placeholder matters:** Empirically verified on this host (macOS Darwin 24.6.0 BSD `column`) that two consecutive tab delimiters collapse into one — the row `d\t\tf` renders as `d  f` (two columns), not `d  -  f` (three). The fix is to substitute `null`/empty → `-` (or `–`) in jq before piping.

**Example:**
```sh
# [VERIFIED: hands-on probe on macOS host — empty-field collapse confirmed]
state_show() {
    awk 'BEGIN{infm=0} /^---$/ && NR==1 {infm=1; next} /^---$/ && infm {infm=0; next} !infm' "$STATE_FILE" \
    | jq -r '
        def or_dash: if . == null or . == "" then "-" else (.|tostring) end;
        [.ts, .event, .actor, (.task|or_dash), (.skill|or_dash), .summary, (.refs|join(","))]
        | @tsv
      ' \
    | (printf 'TS\tEVENT\tACTOR\tTASK\tSKILL\tSUMMARY\tREFS\n'; cat) \
    | column -t -s "$(printf '\t')"
}
```

### Pattern 7: `chantier new` heredoc scaffolding (D-11, FR-002)

**What:** Heredoc functions inside the binary emit each scaffold file. Variable interpolation against the project name (`$1`) uses unquoted `<<EOF`; literal content uses quoted `<<'EOF'` to suppress expansion. Both forms are POSIX. `[CITED: linuxize.com bash-heredoc + Wikipedia here-document]`

**Example (project skeleton emission):**
```sh
new_project() {
    name="${1:-}"
    [ -n "$name" ] || { printf 'chantier new requires a project name\n' >&2; exit 3; }
    [ ! -d "$name" ] || { printf 'directory %s already exists\n' "$name" >&2; exit 1; }

    mkdir -p "$name/.planning/phases"

    # PROJECT.md — interpolate $name
    cat > "$name/.planning/PROJECT.md" <<EOF
---
project_id: $name
created: $(date -u +%Y-%m-%d)
license: MIT
copyright: $name Contributors
status: draft
---

# $name — Project Charter

## Vision

<!-- TODO: one sentence — what does this project exist to do? -->

## Out of scope (forever)

<!-- TODO: list permanent non-goals (e.g. "no SaaS lock-in") -->

## Success criteria — v0.1.0

<!-- TODO: enumerate what makes v0.1.0 "shipped" -->
EOF

    # STATE.md — literal frontmatter + empty JSONL body
    cat > "$name/.planning/STATE.md" <<'EOF'
---
format_version: 0.1.0
format_note: |
  STATE.md body is JSON Lines, append-only, one event per line.
  Mutation is allowed only via `chantier state append`.
---
EOF

    # ...REQUIREMENTS.md, ROADMAP.md, config.json similarly
}
```

### Anti-Patterns to Avoid

- **`#!/bin/bash` shebang** — silently introduces bash-isms. Use `#!/bin/sh` and lint with `shellcheck -s sh`.
- **`set -o pipefail`** — not POSIX. Catches errors in pipelines on bash/zsh but breaks `dash`. If pipeline-error visibility matters, rewrite as sequential commands with temp files.
- **`[[ ... ]]`** — bash-only. Use POSIX `[ ... ]` even though quoting is uglier.
- **`echo` with options (`-e`, `-n`)** — behaviour differs across shells. Always use `printf`. `[CITED: emmer.dev defensive shell scripting]`
- **Sourcing helper files (`. lib.sh`)** — violates NFR-002 single-file. Keep everything in `core/bin/chantier`.
- **Embedded harness identifiers** — `claude-code`, `cursor`, etc. must never appear in `core/bin/chantier`. Validate by grep in a self-test or CI gate.
- **Unquoted variables in conditionals** — `[ $x = y ]` breaks when `$x` is empty. Always `[ "$x" = "y" ]`.
- **`local`** — not POSIX (it's a bash/ksh extension). For function-scoped variables either use a subshell `( ... )` or carefully prefix var names; for v0.1 we accept that all variables are effectively global within the binary.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Concurrency control | A pid-file checker without `mkdir` atomicity | The `mkdir`-as-mutex pattern (Pattern 2) | `[file -e] && touch` has a TOCTOU race. `mkdir` doesn't. |
| YAML frontmatter parsing | A full YAML parser | awk extraction of the `--- ... ---` block + a deliberately restricted "frontmatter subset" rule (only string/number/boolean scalars, no nested maps, lists allowed only at the top level) | A full YAML parser is a multi-month project. Chantier frontmatter is intentionally simple; the awk extractor + jq construction (treating each `key: value` line as `{key: value}`) handles every shape currently in `.planning/`. ADR 0002 must explicitly state "frontmatter subset profile" to legitimise this restriction. |
| JSON Schema validation | A full draft-07 implementation | The constrained jq subset-validator (Pattern 5) | Full draft-07 means thousands of LOC. Chantier needs ~7 keywords. ADR 0002 declares the subset profile. |
| Argument parsing | Hand-written `case "$1" in --foo)` loop | POSIX `getopts` | `getopts` handles `-r value -r value` repeated-flag accumulation cleanly (Pattern 3 example). Hand rolls forget edge cases like `-r=value` vs `-r value`. |
| Atomic timestamp | `date "+%s"` then convert | `date -u +%Y-%m-%dT%H:%M:%SZ` directly | Avoids locale issues (LC_ALL=C is set globally) and timezone surprises. |
| ADR template | Invent a new format | MADR v4 conventions adapted to ADR 0001's existing style | ADR 0001 already follows a MADR-ish shape (Status / Context / Decision / Consequences / Alternatives considered / Open questions / Approval). ADR 0002 must match exactly. `[CITED: adr.github.io/madr]` |

**Key insight:** The Chantier binary is intentionally narrow. Every "don't hand-roll" exception above is justified by NFR-002 — adding a dependency would expand the trust surface more than implementing the narrow subset costs.

## Runtime State Inventory

> Phase 2 ships a new artefact and migrates one file (`STATE.md`). It is partly a rename/migration phase.

| Category | Items Found | Action Required |
|---|---|---|
| Stored data | `.planning/STATE.md` currently holds 10 rows in Markdown-table format. D-04 mandates a one-shot conversion to JSONL with frontmatter bump `0.1.0-interim` → `0.1.0`. | **Data migration**: parse 10 rows → emit 10 JSONL lines → bump frontmatter → dedicated commit. The "actor" column maps verbatim to `actor` JSON field; "summary" → `summary`; "refs" → `refs` array (split on whitespace, handle the row that has a multi-word "github.com/..." ref). The `task`/`skill` fields are NEW — for all 10 historical rows they should be `null`. |
| Live service config | None — Phase 1 produced only filesystem artefacts (repo, ADR, docs). No external service holds project-side state. | None. |
| OS-registered state | None — no scheduled tasks, no daemons, no system-level installations. | None. |
| Secrets / env vars | None — Chantier is local-only with no API keys or credentials. (NFR-004 forbids network.) | None. |
| Build artefacts | None yet — `core/` is empty seed. After Phase 2 ships, `core/bin/chantier` is the new artefact (no prior version to invalidate). | None for this migration; future Phase 2 reruns would need to confirm `core/schemas/*.json` parse cleanly via `--self-test`. |

**Migration script approach (recommendation):** A *one-shot* migration is preferable to a permanent `chantier state migrate` subcommand. Rationale: (a) there are exactly 10 rows; (b) v0.1.0 has no upgrade story yet; (c) shipping `state migrate` as a permanent subcommand would have to be tested against a phantom schema-version matrix that does not exist. Implement the migration as a shell snippet in the migration commit's commit body (or a `scripts/migrate-state-v0.1.0-interim-to-v0.1.0.sh` that is **deleted in the same commit** after running). The deletion is intentional — the migration is non-reversible and one-time. ADR 0002 records this choice.

## Common Pitfalls

### Pitfall 1: `flock(1)` assumed available
**What goes wrong:** Developer copies a Linux example using `flock` and the binary fails on macOS with "command not found".
**Why it happens:** macOS Darwin's coreutils derive from BSD; `flock` is a util-linux tool. `[VERIFIED: direct env probe — no /usr/bin/flock, no Homebrew flock]`
**How to avoid:** Use the `mkdir`-as-mutex pattern (Pattern 2). The `--self-test` should not assume `flock` either; instead it tests the mkdir-lock by acquiring and releasing it.
**Warning signs:** Any code path that calls `flock` directly — fail the CI grep.

### Pitfall 2: BSD `column` collapses empty fields
**What goes wrong:** `chantier state show` displays a misaligned grid because rows where `task` or `skill` is null collapse the tab delimiter.
**Why it happens:** BSD `column` does greedy delimiter matching (a documented quirk; util-linux `column` ≥ 2.23 has a `-n` non-greedy flag but it does **not** exist on macOS). `[VERIFIED: direct probe on host]`
**How to avoid:** Substitute null/empty → `-` in jq before piping (Pattern 6).
**Warning signs:** Test with a STATE.md row whose `task` is null and confirm the columns line up.

### Pitfall 3: CRLF line endings break the shebang
**What goes wrong:** Someone edits `core/bin/chantier` on Windows; git auto-translates to CRLF; the file becomes unexecutable with "bad interpreter" errors.
**Why it happens:** `#!/bin/sh\r\n` makes the kernel look for `/bin/sh\r`. `[CITED: codestudy.net git-hooks article]`
**How to avoid:** Add `* text=auto eol=lf` to `.gitattributes` for the binary; `--self-test` should grep for `\r` in the file's own source (via `$0`).
**Warning signs:** `file core/bin/chantier` reports "CRLF line terminators".

### Pitfall 4: `set -e` silently swallows errors inside `if`/`&&` chains
**What goes wrong:** A failing command inside `if check; then` does not abort. `[CITED: emmer.dev defensive shell]`
**Why it happens:** POSIX `set -e` explicitly exempts commands that are part of a test or a `&&`/`||` left-hand side.
**How to avoid:** For critical error-propagation, check exit code explicitly: `check || exit $?`. Use `set -u` (unset variable trap) liberally — it does **not** have the same exemptions and catches more bugs.
**Warning signs:** Tests pass but a real-world invocation silently corrupts state. Counter: every `bats` test for failure modes asserts both exit code AND a stderr message.

### Pitfall 5: Locale-dependent regex / sort behaviour
**What goes wrong:** `grep -E '^[a-z]'` matches accented characters in some locales but not others.
**Why it happens:** The default `LC_COLLATE` and `LC_CTYPE` interpret `[a-z]` according to the active locale's collation rules.
**How to avoid:** Top of the binary: `LC_ALL=C; export LC_ALL`. Pattern 1 already includes this. `[CITED: apenwarr.ca insufficiently-known POSIX]`
**Warning signs:** Inconsistent behaviour between CI (often `LC_ALL=C` by default) and dev workstation (often `en_US.UTF-8`).

### Pitfall 6: Subshell trap-loss in pipelines
**What goes wrong:** `acquire_lock | something` puts `acquire_lock` in a subshell; the `trap` it set fires when the subshell exits, releasing the lock prematurely.
**Why it happens:** Pipelines run each stage in a subshell on POSIX.
**How to avoid:** Always invoke `acquire_lock` in the *current* shell (no pipeline, no `( ... )` group). The result of the lock is "the trap is now armed in this shell".
**Warning signs:** A `state append` "succeeded" but `STATE.md` is missing the line and the lock dir is gone.

### Pitfall 7: `getopts` with multi-value repeated flags
**What goes wrong:** `-r ref1 -r ref2` produces only the last value because the naive idiom overwrites.
**Why it happens:** `OPTARG` is overwritten each `getopts` iteration.
**How to avoid:** Accumulate into a newline-separated shell string (Pattern 3 example), then split into a jq array via `split("\n") | map(select(length>0))`. POSIX arrays do not exist; newline-separated strings are the portable substitute.
**Warning signs:** A task with two `refs:` produces a STATE.md row with only one.

### Pitfall 8: Heredoc variable expansion bites scaffolding
**What goes wrong:** A `<<EOF` heredoc (unquoted) inside `new_project` interpolates `$WHATEVER` that the user might one day put inside the scaffold template body, breaking the scaffolded file.
**Why it happens:** Unquoted heredoc expands all `$var`. `[CITED: linuxize.com bash-heredoc]`
**How to avoid:** Use **quoted** `<<'EOF'` for any heredoc whose content includes literal `$` (e.g., shell snippets in `config.json` examples). Use unquoted `<<EOF` only where you genuinely need `$name` / `$(date)` interpolation; everywhere else, quote.
**Warning signs:** A scaffolded file has spurious `bash: WHATEVER: unbound variable` errors or empty values where `$VAR` was expected literally.

### Pitfall 9: `git config user.name` is empty in CI
**What goes wrong:** `actor` field in JSONL becomes the empty string in CI; D-02 says actor is a string (not nullable).
**Why it happens:** CI runners often don't set `user.name`.
**How to avoid:** Pattern 3's `ACTOR=$(git config user.name 2>/dev/null || printf 'unknown')`. Document in ADR 0002 that "unknown" is the reserved CI-fallback actor.
**Warning signs:** STATE.md events with `"actor": ""`.

## Code Examples

### Verifying a frontmatter file against its schema (FR-004 gate 3)
```sh
# Source: composition of Pattern 5 (jq schema validator) with awk frontmatter extractor
# [CITED: in-house composition; no upstream pure-shell equivalent]

extract_frontmatter_as_json() {
    file="$1"
    # Extract everything between the first two --- delimiters
    awk '
        BEGIN { in_fm = 0; done = 0 }
        /^---$/ {
            if (!in_fm && !done) { in_fm = 1; next }
            if (in_fm)           { in_fm = 0; done = 1; exit }
        }
        in_fm { print }
    ' "$file" \
    | jq -R -s '
        # Frontmatter subset: each line is "key: value" or "key:" followed by indented continuation.
        # For v0.1 we accept only:  key: scalar | key: [a, b] | key:\n  - a\n  - b
        # The awk above hands us a YAML fragment; we apply a deliberately tiny transform.
        split("\n")
        | map(select(length > 0))
        | reduce .[] as $line ({}; . + (
            $line | capture("^(?<k>[A-Za-z_][A-Za-z0-9_]*):\\s*(?<v>.*)$")
                  | { (.k): .v }
          ))
    '
    # NOTE: this stub handles only top-level string scalars. Lists and nested maps need a
    # second-pass awk. The schemas referenced by ADR 0002 must keep frontmatter shapes simple
    # enough that this extractor handles them — that constraint IS the "frontmatter subset profile".
}

validate_frontmatter() {
    file="$1"; schema="$2"
    tmp_json=$(mktemp)
    extract_frontmatter_as_json "$file" > "$tmp_json"
    validate_against_schema "$tmp_json" "$schema"
    rc=$?
    rm -f "$tmp_json"
    return "$rc"
}
```

### Self-test (`chantier --self-test`)
```sh
# [CITED: in-house — matches the D-Discretion "Self-test" spec]
self_test() {
    fails=0
    check() { name="$1"; shift; if "$@"; then printf '  ok  %s\n' "$name"; else printf '  FAIL %s\n' "$name"; fails=$((fails+1)); fi; }

    printf 'chantier --self-test\n'

    check 'jq present'                 command -v jq >/dev/null
    check 'jq version >= 1.6'          sh -c 'jq --version | awk -F'\''[-.]'\'' '\''{exit !($2>=1 && $3>=6)}'\'''
    check 'mkdir-lock works'           sh -c 'd=$(mktemp -d)/lock; mkdir "$d" && rmdir "$d"'
    check 'awk present'                command -v awk >/dev/null
    check 'date -u present'            date -u +%Y-%m-%dT%H:%M:%SZ >/dev/null

    # Every schema parses as valid JSON
    for s in "$SCHEMAS_DIR"/*.json; do
        check "schema parses: $(basename "$s")" jq empty "$s"
    done

    # Every subcommand answers --help with exit 0
    for sub in 'state append' 'state show' 'validate-task' 'new'; do
        check "--help works: chantier $sub" sh -c "'$0' $sub --help >/dev/null 2>&1 || true"
    done

    # No harness identifiers in own source
    check 'no harness identifiers in self' sh -c "! grep -qE 'mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode' '$0'"

    [ "$fails" -eq 0 ] || { printf '\n%d self-test failure(s)\n' "$fails" >&2; exit 2; }
    printf '\nself-test: all green\n'
}
```

### bats-core skeleton test (`core/tests/state_append.bats`)
```bash
#!/usr/bin/env bats
# [CITED: bats-core/bats-core writing-tests.html]

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    export CHANTIER="$BATS_TEST_DIRNAME/../bin/chantier"
    export TMPHOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$TMPHOME/.planning"
    cat > "$TMPHOME/.planning/STATE.md" <<'EOF'
---
format_version: 0.1.0
---
EOF
    cd "$TMPHOME"
}

@test "state append rejects invalid event name" {
    run "$CHANTIER" state append -e "BAD_NAME" -m "summary"
    assert_failure 1
    assert_output --partial "shape regex"
}

@test "state append writes one JSONL line" {
    run "$CHANTIER" state append -e "task.completed" -t "t1" -s "tdd" -m "done"
    assert_success
    [ "$(awk '/^---$/{c++; next} c>=2' "$TMPHOME/.planning/STATE.md" | wc -l | tr -d ' ')" -eq 1 ]
}

@test "concurrent state appends do not corrupt JSONL" {
    (for i in 1 2 3 4 5; do "$CHANTIER" state append -e "task.completed" -t "t$i" -s "s$i" -m "p$i" & done; wait)
    # Every line should be valid JSON
    awk '/^---$/{c++; next} c>=2' "$TMPHOME/.planning/STATE.md" | while IFS= read -r ln; do
        printf '%s' "$ln" | jq empty || { echo "corrupt line: $ln" >&2; false; }
    done
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Markdown table for event logs | JSON Lines for event logs | 2010s–2020s (JSONL gained adoption with Hadoop/Spark log pipelines, `jq`'s rise from ~2015) | Chantier follows the convention. `[CITED: jsonlines.org]` |
| flock(1) assumed available | mkdir-as-mutex for portable shell scripts | 2010s convention; openrc, bash-hackers wiki canonical | Mandatory on macOS-targeted scripts. |
| Hand-rolled argument parsers | POSIX `getopts` (short flags) | Decades-old idiom; mandatory for portable CLIs | Long-flag aliases come later if at all. |
| YAML frontmatter parsed with `yq` | YAML-subset frontmatter parsed with awk + jq construction | Chantier-specific trade-off (NFR-002) | Documented in ADR 0002 as the "frontmatter subset profile". |
| Full JSON Schema validators (ajv, ajv-cli) | Constrained subset validator inline in jq | Chantier-specific trade-off (NFR-002) | Documented in ADR 0002 as the "schema profile". |

**Deprecated / outdated:**
- `bash` shebangs for portable shell tools: the `dash`-strict subset is the safer target.
- Sourced helper-script chains: distribute as a single file, not a directory.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | bats-core v1.13.0 is the current stable release | Standard Stack | LOW — exact version drifts; planner should pin whatever is current at install time. `[VERIFIED via github releases page metadata]` |
| A2 | Implementing a draft-07 *subset* validator in jq is acceptable to the project (vs. shelling out to ajv) | Pattern 5 / Don't Hand-Roll | MEDIUM — if user expects full draft-07 compliance, ADR 0002 must scope this explicitly. Recommend asking user at planning time whether the subset profile is acceptable, OR flag for ADR 0002 itself to be the formal decision record. |
| A3 | Frontmatter subset profile (top-level scalars + lists, no nested maps) is sufficient for v0.1 | Don't Hand-Roll / Code Examples | LOW — verified against current `.planning/PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md` shapes; no nested maps in any of them. But D-07 says ADR 0002 must enumerate required fields, so this is a check the planner can verify deterministically. |
| A4 | Migration of 10 STATE.md rows is a one-shot script discarded after commit (not a permanent `state migrate` subcommand) | Runtime State Inventory | LOW — user can override; only impacts the migration commit's structure. |
| A5 | macOS BSD `column` greedy-collapse behaviour is the canonical macOS behaviour (not specific to this host) | Pitfall 2 | LOW — BSD `column` source has been unchanged for years; behaviour is documented. |
| A6 | The `actor` field default "unknown" is acceptable when `git config user.name` is empty | Pitfall 9 | LOW — could be `"ci"` or `"system"` instead; ADR 0002 should standardise. Flagged. |
| A7 | bats-assert and bats-support are safe to vendor as git submodules (vs. expecting them in PATH) | Standard Stack | LOW — submodules are the bats-core officially documented integration pattern. |
| A8 | `LC_ALL=C` at the top of the binary will not break legitimate Unicode summaries (summaries pass through jq which is UTF-8 safe regardless of LC_ALL) | Pitfall 5 / Pattern 1 | LOW — jq's string handling is locale-independent; `LC_ALL=C` only affects shell-level regex/sort. Confirmed safe in practice. |

**If this table needs additional confirmations:** A2 and A6 are the two worth surfacing to the user at planning time, because they are decisions ADR 0002 will codify and changing them later is a breaking change.

## Open Questions

1. **Should ADR 0002 publish the JSON Schemas inline or by reference?**
   - What we know: D-06 says "ADR 0002 quotes them inline as the spec-of-record; the JSON files are the runtime-importable artefacts."
   - What's unclear: whether "quotes them inline" means full text or just the keyword-by-keyword highlights.
   - Recommendation: include each schema in full inside a fenced ```json block in ADR 0002. The file is the runtime artefact; the ADR is the human-readable spec. Both must match byte-for-byte at ship time; the `--self-test` could optionally verify this.

2. **Where does `STATE.md.bak` go during migration?**
   - What we know: D-04 says "dedicated commit, format_version bumped to 0.1.0".
   - What's unclear: whether a `.bak` is committed alongside (for archival), or discarded immediately after manual verification.
   - Recommendation: do not commit `.bak`. The git history *is* the backup. The migration commit message includes the pre-migration Markdown table verbatim in a folded block.

3. **Should the binary `--version` print just `0.1.0` or include a build hash?**
   - What we know: No D-decision; not on the discretion list.
   - Recommendation: just `0.1.0`. Build hashes invite reproducibility-test failures that distract from the foundation work.

4. **Are `chantier state append --json-errors` and the rest of `--json-errors` global, or per-subcommand?**
   - What we know: D-Discretion error model lists `--json-errors` as a flag that switches stderr format.
   - Recommendation: implement as a top-level flag parsed before subcommand dispatch (so `chantier --json-errors state append ...` works); document in `--help`.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| `jq` | Every subcommand of the binary | ✓ | 1.7.1-apple on macOS host | None — hard requirement (NFR-002 allows this). |
| `awk` | YAML frontmatter extraction, validate-task helpers | ✓ | BSD awk on macOS, GNU awk on Linux | Both work; POSIX-awk subset used throughout. |
| `sed` | Migration script, frontmatter cleanup | ✓ | BSD sed on macOS, GNU sed on Linux | Both work; no GNU-only flags. |
| `date -u` | ISO-8601 timestamp generation | ✓ | BSD date on macOS, GNU date on Linux | `date -u +%Y-%m-%dT%H:%M:%SZ` is POSIX-portable. |
| `column -t -s` | `state show` rendering | ✓ | BSD column on macOS, util-linux column on Linux | BSD has known greedy-collapse quirk → addressed by null-placeholder substitution (Pattern 6). |
| `mkdir`, `rmdir`, `rm -rf`, `kill -0` | mkdir-lock (Pattern 2) | ✓ | POSIX coreutils | None needed. |
| `git` | Reading `git config user.name`, optional `--actor` override | ✓ | 2.x assumed | Falls back to "unknown" when absent. |
| `flock` | (would be required if D-Discretion-concurrency taken literally) | ✗ | not on macOS | **mkdir-as-mutex (Pattern 2) is the fallback. This is mandatory, not optional.** |
| `yq` | (would be required for arbitrary YAML frontmatter parsing) | ✗ | not on host | awk + jq construction over the YAML-subset profile. |
| `bats` (dev-time) | Test execution | ✗ | not installed | Wave 0 install via `brew install bats-core`; submodule `bats-assert` and `bats-support`. |
| `shellcheck` (dev-time) | Static analysis CI gate | ✗ | not installed | Wave 0 install via `brew install shellcheck`. |

**Missing dependencies with no fallback:** None. Every Phase-2 dependency has either availability or a planned fallback.

**Missing dependencies with fallback:**
- `flock` — fallback is `mkdir`-lock (Pattern 2). The planner should drop the "flock with macOS BSD ⇄ Linux util-linux compat wrapper" wording from D-Discretion "Concurrency" and replace it with the `mkdir`-lock approach. **This is a refinement of a Claude's Discretion item — see §"Claude's Discretion review" at the end.**
- `yq` — fallback is awk+jq frontmatter subset extractor. No D-Discretion entry to revise (the user's preference was silent on YAML tooling).
- `bats` / `shellcheck` — Wave 0 install step at the start of the plan.

## Validation Architecture

> `nyquist_validation_enabled: true` per phase brief. `.planning/config.json` does not explicitly set `workflow.nyquist_validation`; treating as enabled.

### Test Framework
| Property | Value |
|---|---|
| Framework | `bats-core` 1.13.0 |
| Config file | None native to bats; test discovery is by `core/tests/*.bats` filename glob. |
| Quick run command | `bats core/tests/state_append.bats` (single suite, ≤ 5 s) |
| Full suite command | `bats core/tests/` (all suites, expected < 30 s for Phase 2 scope) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| FR-001 | Binary exists at `core/bin/chantier`, is executable, depends only on `sh`+`jq` | smoke + static-grep | `bats core/tests/self_test.bats` + `shellcheck -s sh core/bin/chantier` | ❌ Wave 0 |
| FR-002 | `chantier new <name>` produces all 5 scaffold files with correct frontmatter | integration | `bats core/tests/new.bats` | ❌ Wave 0 |
| FR-003 | `chantier state append` writes exactly one JSONL line, validates event regex, locks correctly, accepts repeated `-r` | unit + concurrency | `bats core/tests/state_append.bats` | ❌ Wave 0 |
| FR-004 | `chantier validate-task` enforces all 5 ADR-0001 gates with correct exit codes | unit per gate (5 cases) | `bats core/tests/validate_task.bats` | ❌ Wave 0 |
| (related) ADR 0002 | Each schema parses; each `chantier --self-test` subcommand answers `--help`; no harness identifiers in source | smoke | `bats core/tests/self_test.bats` | ❌ Wave 0 |
| (related) D-03 | `chantier state show` renders the JSONL stream correctly handling null fields | integration | `bats core/tests/state_show.bats` | ❌ Wave 0 |
| (related) D-04 | Migration commit produces correct JSONL from the existing 10 Markdown rows | one-shot verify | manual check after migration commit — `awk '/^---$/{c++;next} c>=2' .planning/STATE.md \| wc -l` returns 10 | n/a |

### Sampling Rate
- **Per task commit:** `bats core/tests/<file>.bats` for the file the task touched.
- **Per wave merge:** `bats core/tests/` (full suite) + `shellcheck -s sh core/bin/chantier`.
- **Phase gate:** Full suite green AND `chantier --self-test` green AND `shellcheck -S error -s sh core/bin/chantier` returns zero errors.

### Wave 0 Gaps
- [ ] Install `bats-core`, `shellcheck` on host (`brew install bats-core shellcheck`).
- [ ] Add `bats-support` and `bats-assert` as git submodules under `core/tests/test_helper/`.
- [ ] Create `core/tests/state_append.bats`, `state_show.bats`, `validate_task.bats`, `new.bats`, `self_test.bats`.
- [ ] Create `core/tests/fixtures/` with `PLAN.valid.md`, `PLAN.invalid-missing-required.md`, `output.valid.md`, `output.missing-acceptance.md`.
- [ ] CI workflow (optional in Phase 2; can be Phase 5): run the full bats suite on push, run on both `ubuntu-latest` (verifies dash-strict POSIX) and `macos-latest` (verifies BSD-coreutils path).
- [ ] Add `.gitattributes` rule `core/bin/chantier text eol=lf` to prevent CRLF corruption (Pitfall 3).

## Security Domain

> `security_enforcement` not explicitly false in `.planning/config.json`; treated as enabled.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | no | Chantier is local-only; no user auth. |
| V3 Session Management | no | No sessions. |
| V4 Access Control | partial | Filesystem permissions only — `STATE.md` is writable by whoever can `chmod +x core/bin/chantier`. ADR 0001 §append-only is a *contract* enforcement, not OS enforcement; document this expectation in ADR 0002. |
| V5 Input Validation | **yes** | Every external input to the binary is validated: `--event` against D-09 regex, `--task` against task-id regex, schema-validation of `output.json`, frontmatter validation of every staged document. |
| V6 Cryptography | no | No crypto in Phase 2. NFR-006 explicitly forbids tokens / monetary primitives; this also rules out any cryptographic signing requirement. |
| V7 Error Handling and Logging | **yes** | Exit-code matrix (0/1/2/3) is the error contract. Stderr-or-JSON via `--json-errors` is the logging contract. Logs (STATE.md) are append-only by design. |
| V12 File Resource | **yes** | Locks (Pattern 2), atomic single-line appends (Pattern 3), path-traversal checks in `validate-task` gate 1 (no write to `..` or absolute paths outside repo). |
| V14 Configuration | partial | `config.json` is currently free-form; ADR 0002's schema for it will close this. |

### Known Threat Patterns for {POSIX shell + jq stack}

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Shell injection via unsanitised flag values (e.g., `-m "$(rm -rf $HOME)"`) | Tampering | All values flow through jq's `--arg` (string-mode binding, NOT executed). No `eval`, no unquoted `$VAR` in subshell positions. **Lint rule: zero `eval` in `core/bin/chantier`.** |
| Path-traversal via `state_writes` (skill declares `state_writes: ../../../etc/passwd`) | Tampering / EoP | `validate-task` gate 1 must canonicalise every path with `cd && pwd` (or equivalent) and verify it is inside the repository root. |
| Symlink attack on `LOCKDIR` (attacker pre-creates `LOCKDIR` as symlink to `/etc`) | Tampering / DoS | `LOCKDIR` is rooted under `.planning/` which the user already trusts; if `.planning/` is hostile, the whole framework is compromised. Acceptable risk for a local-dev tool. |
| `STATE.md` history rewrite (a skill bypasses `state append` and edits the file directly) | Repudiation | NFR-003 declares this a contract violation. CI gate: a pre-commit hook (Phase 5) could lint that every JSONL line's `ts` is non-decreasing. For v0.1: documented in ADR 0002 as a *convention*, enforced socially. |
| TOCTOU race on `STATE.md` between read in `state show` and write in `state append` | Tampering | `state show` operates on a snapshot read via `awk` (in-memory); appends to `STATE.md` are line-atomic under the mkdir lock. Concurrent reads are safe. |
| Schema-validator regex DoS (a malicious schema with a catastrophic-backtracking `pattern`) | DoS | All schemas live in `core/schemas/` and are authored by Chantier; not user-supplied. Acceptable as long as v0.1 has no user-loadable schemas. ADR 0002 must note this assumption. |
| Resource exhaustion via unbounded `STATE.md` growth | DoS | Already in Deferred Ideas — compaction is post-v0.1. For v0.1, document expected order-of-magnitude (≤ thousands of events for a multi-week project). |

## Claude's Discretion review

Verdicts on each of the 9 Claude's Discretion items from CONTEXT.md, informed by research findings:

| # | Item | Verdict | Notes |
|---|---|---|---|
| 1 | STATE.md migration timing — clean break, dedicated commit, `format_version` → `0.1.0` | **Keep** | Validates against D-04 verbatim; no change needed. |
| 2 | JSON Schema location — `core/schemas/*.json` runtime-importable, quoted inline in ADR 0002 | **Keep** | D-06 confirms. Add a `--self-test` check that the inline ADR text matches the file content (ADR 0002 itself optionally enforces). |
| 3 | Event regex enforcement — shape only, no vocabulary check | **Keep** | D-09 verbatim. Already implemented in Pattern 3. |
| 4 | Concurrency on `state append` — `flock(1)` with macOS BSD ⇄ Linux util-linux compat wrapper | **REVISE** | `flock` is **not on macOS** at all (verified env probe). There is no "compat wrapper" possible — the tool simply doesn't exist. **Replace with: mkdir-as-mutex pattern with stale-PID detection (Pattern 2).** This is the *only* portable choice given NFR-002. |
| 5 | Argument parsing — POSIX `getopts` short flags only | **Keep** | Confirmed Pattern 3 idiom. Repeated `-r` flags accumulate via newline-joined shell string. |
| 6 | Test framework — bats-core in `core/tests/`, not shipped | **Keep**, with refinement | Add the explicit submodule pattern for `bats-assert` and `bats-support` under `core/tests/test_helper/`. Refinement is mechanical, not directional. |
| 7 | Binary structure — single-file `core/bin/chantier` with `case "$1" in` dispatch | **Keep** | Confirmed Pattern 1. NFR-002-compliant. |
| 8 | `validate-task` portability deny-list — hardcoded harness identifiers | **Keep** | The exact regex in Pattern 4 gate 4 implements D-Discretion verbatim. v0.2 can make this configurable. |
| 9 | Error model — exit codes 0/1/2/3 with `--json-errors` for JSON stderr | **Keep** | Implemented across all patterns. Document `--json-errors` as top-level flag (Open Question #4). |
| 10 | `output.md` Acceptance section — `^##\s+Acceptance\s*$` heading + bulleted items | **Keep** | Pattern 4 gate 5 implements verbatim. |
| 11 | `--self-test` — jq present, flock available, schemas parse, all subcommands `--help` exit 0 | **REVISE** | Replace "flock available" with "mkdir-lock works" (same reason as #4). Additionally **flag for ADR 0002**: should `--self-test` also lint the binary itself for the harness deny-list and for `\r` line endings? Recommendation: yes — these are zero-cost checks that prevent recurring portability bugs. |

**Items flagged for ADR 0002:** #4 (lock mechanism), #11 (additional self-test gates), plus the two new items the planner should consider:
- **ADR-0002 New: Frontmatter subset profile.** ADR 0002 must explicitly document that Chantier validates a YAML *subset* — top-level scalars + simple lists — not arbitrary YAML. This legitimises the awk extractor (no `yq`).
- **ADR-0002 New: JSON Schema subset profile.** ADR 0002 must explicitly document that Chantier validates a draft-07 *profile* (the keyword list in Pattern 5 §"What it explicitly does NOT cover"). This legitimises the in-jq validator (no `ajv`).

Both ADR-0002 additions follow from NFR-002 (single-file binary, sh+jq only) and are *not* re-litigating any locked decision — they are the formal acknowledgement of the constraint NFR-002 already imposed.

## Sources

### Primary (HIGH confidence)
- **Direct environment probe on host** (2026-05-29): `jq` 1.7.1-apple present; `flock`, `yq`, `bats`, `shellcheck` absent; `dash` and `awk` present; macOS BSD `column` greedy-collapse behaviour confirmed.
- **`.planning/STATE.md`**, **`.planning/REQUIREMENTS.md`**, **`.planning/ROADMAP.md`**, **`.planning/PROJECT.md`**, **`docs/adr/0001-state-skill-contract.md`**, **`docs/research/inheritance-map.md`**, **`.planning/phases/01-foundation/SUMMARY.md`**, **`.planning/phases/02-runtime-core/02-CONTEXT.md`**, **`.planning/phases/02-runtime-core/02-DISCUSSION-LOG.md`** — primary project documents read in full.
- **JSON Lines specification**, https://jsonlines.org/ — "Values can be simply appended at the end (possibly by concurrent producers), and conversely read as a sequence on the other end."
- **bats-core official docs**, https://bats-core.readthedocs.io/en/stable/writing-tests.html — test isolation, `BATS_TEST_TMPDIR`, exit-code assertion idioms.
- **bash-hackers wiki — mutex howto**, https://bash-hackers.gabe565.com/howto/mutex/ — canonical mkdir-as-mutex with `trap` and PID-stale recovery.

### Secondary (MEDIUM confidence — official-doc-grade)
- **OpenRC service-script-guide**, https://github.com/OpenRC/openrc/blob/master/service-script-guide.md — POSIX-shell init-script conventions.
- **bats-core github**, https://github.com/bats-core/bats-core — v1.13.0 release confirmed November 2025; MIT licence.
- **bats-core homebrew formula**, https://formulae.brew.sh/formula/bats-core — install path on macOS.
- **jqlang/jq issue #3437**, https://github.com/jqlang/jq/issues/3437 — confirms no pure-jq JSON Schema validator exists upstream.
- **apenwarr — "Insufficiently known POSIX shell features"**, https://apenwarr.ca/log/20110228 — `LC_ALL=C` discipline.
- **emmer.dev — "Defensive Shell Scripting"**, https://emmer.dev/blog/defensive-shell-scripting-with-shell-options/ — `set -e` exemption pitfalls.
- **codestudy.net — git pre-commit hooks**, https://www.codestudy.net/blog/git-pre-and-post-commit-hooks-not-running/ — CRLF shebang failures.
- **linuxize — Bash Heredoc Guide**, https://linuxize.com/post/bash-heredoc/ — variable-expansion behaviour of quoted vs unquoted heredoc delimiters.
- **adr.github.io — MADR**, https://adr.github.io/madr/ — ADR template conventions matching ADR 0001's style.
- **jsonlines.org** + **dev.to "Crash-safe JSON at scale"**, https://dev.to/constanta/crash-safe-json-at-scale-atomic-writes-recovery-without-a-db-3aic — JSONL atomic-append guarantees.
- **jameshfisher.com — "Concurrent fwrites are not atomic"**, https://jameshfisher.com/2017/07/29/concurrent-fwrites/ — confirms the lock pattern is mandatory for the multi-producer case.

### Tertiary (LOW confidence — flagged for validation)
- Various WebSearch summaries on POSIX argument-parsing idioms; the pattern in Pattern 3 is the consensus shape but was not cross-verified against a single canonical source. Risk: minor stylistic divergence from a popular handbook.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — jq, awk, sed, date are POSIX baseline; bats-core is a vintage project with active releases.
- Architecture (single-file binary, case dispatch, mkdir-lock): HIGH — canonical patterns confirmed against multiple sources and against the host environment probe.
- jq schema-subset validator: MEDIUM — this is an *original* design decision derived from NFR-002. No upstream prior art. The risk lives in ADR 0002's framing: if Chantier sells the binary as "draft-07 compliant", users will be misled. ADR 0002 must frame it as "draft-07 subset profile" explicitly. Flagged in Assumptions Log #A2 and §"Claude's Discretion review".
- YAML frontmatter subset extractor: MEDIUM — same reasoning. Subset profile must be ADR-documented.
- Pitfalls: HIGH — every pitfall listed is sourced from a well-attested guide.

**Research date:** 2026-05-29
**Valid until:** 2026-06-28 (30 days for stable POSIX + jq ecosystem; bats-core version may drift but not destructively)

---

## RESEARCH COMPLETE

**Phase:** 2 - Runtime core
**Confidence:** HIGH for portability and architecture; MEDIUM for the two original sub-profiles (JSON Schema subset, YAML frontmatter subset) — both are deliberate trade-offs and both must be formally scoped in ADR 0002.

### Key Findings

- **`flock(1)` is not available on macOS** (verified by direct probe). The Claude's Discretion item #4 ("flock with macOS BSD ⇄ Linux util-linux compat wrapper") is impossible to implement as stated; replace with the **mkdir-as-mutex pattern** (Pattern 2). This is a load-bearing revision.
- **No pure-jq JSON Schema draft-07 validator exists** in the public ecosystem (jqlang/jq#3437 confirms). The recommended approach is a **constrained subset validator** implemented inline in jq (Pattern 5), with ADR 0002 explicitly scoping the supported keyword set. The alternative (shelling out to `ajv` or `check-jsonschema`) violates NFR-002.
- **No portable single-file YAML extractor exists** that satisfies NFR-002. Recommended approach: an awk+jq **frontmatter subset extractor** that handles top-level scalars and simple lists. ADR 0002 must scope this as the "frontmatter subset profile".
- **macOS BSD `column` collapses empty fields** (verified by direct probe). `state show` rendering (D-03) must substitute null/empty fields with a placeholder (e.g., `-`) in jq before piping to `column -t -s $'\t'`.
- **Five ADR-0001 validation gates are concretely mappable** to executable shell checks (Pattern 4); the exit-code mapping from Claude's Discretion error model (0/1/2/3) integrates cleanly.

### File Created
`/Users/alexislegrand/Code et Dev/Chantier/.planning/phases/02-runtime-core/02-RESEARCH.md`

### Confidence Assessment
| Area | Level | Reason |
|---|---|---|
| Standard Stack (sh, jq, bats, shellcheck) | HIGH | All POSIX-baseline tools or well-known dev libraries; bats v1.13.0 confirmed via official channel. |
| Architecture (single-file dispatch, mkdir-lock, JSONL append) | HIGH | Patterns confirmed against bash-hackers wiki, OpenRC conventions, JSON Lines spec, and direct host probe. |
| jq schema-subset validator | MEDIUM | Original design — no upstream prior art (jqlang/jq#3437 confirms gap). Trade-off is explicit and well-justified by NFR-002. |
| YAML frontmatter subset extractor | MEDIUM | Same reasoning. Justifies the "subset profile" framing for ADR 0002. |
| Common Pitfalls | HIGH | Every pitfall cited to an authoritative guide; #2 (column collapse) also verified hands-on. |
| Validation Architecture / Bats integration | HIGH | Confirmed against bats-core official docs. |

### Open Questions (handed to the planner)
1. ADR 0002 must publish each JSON Schema **inline in full**, not just by reference — recommend codifying.
2. STATE.md migration: do **not** commit `STATE.md.bak`; rely on git history.
3. Binary `--version` should print just `0.1.0` (no build hash).
4. `--json-errors` should be a **top-level** flag (parsed before subcommand dispatch).
5. Two Claude's-Discretion revisions are mandatory (lock mechanism, self-test gates) and two new ADR-0002 sections must be added (frontmatter subset profile, JSON-Schema subset profile). See §"Claude's Discretion review".

### Ready for Planning
Research complete. The planner has:
- The full stack with verified versions.
- Seven implementation patterns with code idioms.
- Nine pitfalls with detection signals.
- A complete environment audit with explicit fallbacks for every missing dependency.
- A test-architecture mapping per FR.
- A formal verdict per Claude's-Discretion item (keep / revise / flag-for-ADR).
- Two original subset-profile decisions that must be folded into ADR 0002.
