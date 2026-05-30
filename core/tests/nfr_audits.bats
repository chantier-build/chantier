#!/usr/bin/env bats

# core/tests/nfr_audits.bats
#
# Consolidated NFR-001..NFR-006 audit harness for Phase 5 (D-05, D-06).
# Six independent @test blocks, one per NFR. Each @test reads files from
# disk only -- never executes them -- and asserts pass/fail with bats-assert.
#
# Source: ADR 0001 + REQUIREMENTS.md NFR-001..NFR-006 + Phase 5 CONTEXT.md D-05/D-06.
# Relationship to adapter_isolation.bats: the NFR-001 @test duplicates the
# deny-list grep logic inline (per RESEARCH Open Question 4 recommendation)
# rather than sourcing a shared helper. The two audits coexist by design --
# adapter_isolation.bats is the Phase 4 NFR-001 cross-tree carve-out audit;
# this file is the Phase 5 SC#4-explicit consolidated six-NFR gate.
#
# Self-exemption convention: every line in this file that contains a deny-list
# token or a forbidden network primitive carries a trailing HARNESS_DENY_LIST_CHECK
# comment. The audits filter that marker (and a case-arm self-exemption is the
# double-belt) so the file never flags itself.
#
# Setup mirrors skill_uniformity.bats (cd to repo root; no TMPHOME needed for
# static audits).

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    cd "$BATS_TEST_DIRNAME/../.."
}

@test "nfr_audits: NFR-001 -- no harness identifiers in skill bodies or core (cross-tree deny-list)" { # HARNESS_DENY_LIST_CHECK
    # Full deny-list (byte-identical to core/bin/chantier:687 and :912).
    _full='mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode' # HARNESS_DENY_LIST_CHECK

    # Narrow deny-list applied inside adapters/claude-code/ only (D-10  # HARNESS_DENY_LIST_CHECK
    # carve-out): the substrings claude-code and mcp__claude_ai_ are sanctioned  # HARNESS_DENY_LIST_CHECK
    # there because the directory IS the harness's adapter.  # HARNESS_DENY_LIST_CHECK
    _narrow='@codebase|cursor|codex-cli|copilot-cli|gemini-cli|opencode' # HARNESS_DENY_LIST_CHECK

    _violations=""
    while IFS= read -r _file; do
        [ -n "$_file" ] || continue
        case "$_file" in
            core/bin/chantier)
                # Sanctioned harness-name carrier per the binary's own --self-test.
                continue
                ;;
            core/schemas/skill.json)
                # Schema enum lists harness names as metadata, not invocation.
                continue
                ;;
            core/tests/adapter_isolation.bats|core/tests/nfr_audits.bats)
                # Audit-source self-exemption (double-belt with marker filter).
                continue
                ;;
            skills/*/SKILL.md)
                # Sanctioned `harness_adapters: - claude-code` YAML frontmatter  # HARNESS_DENY_LIST_CHECK
                # line per Phase 3 D-14. Filter that exact line plus any
                # marker-tagged line before applying the full deny-list.
                _filter_claude='^[[:space:]]*-[[:space:]]*claude-code$' # HARNESS_DENY_LIST_CHECK
                if grep -v 'HARNESS_DENY_LIST_CHECK' "$_file" \
                   | grep -vE "$_filter_claude" \
                   | grep -qE "$_full"; then
                    _violations="${_violations}${_file}
"
                fi
                ;;
            adapters/claude-code/*) # HARNESS_DENY_LIST_CHECK
                # D-10 path-only carve-out: only the narrow list applies  # HARNESS_DENY_LIST_CHECK
                # inside the adapter directory.  # HARNESS_DENY_LIST_CHECK
                if grep -v 'HARNESS_DENY_LIST_CHECK' "$_file" \
                   | grep -qE "$_narrow"; then # HARNESS_DENY_LIST_CHECK
                    _violations="${_violations}${_file}
"
                fi
                ;;
            *)
                if grep -v 'HARNESS_DENY_LIST_CHECK' "$_file" \
                   | grep -qE "$_full"; then # HARNESS_DENY_LIST_CHECK
                    _violations="${_violations}${_file}
"
                fi
                ;;
        esac
    done <<EOF
$(find core skills adapters -type f 2>/dev/null \
    | grep -v 'test_helper/' \
    | sort)
EOF

    if [ -n "$_violations" ]; then
        printf 'nfr_audits: NFR-001 violations:\n%b' "$_violations" >&2
        false
    fi
}

@test "nfr_audits: NFR-002 -- POSIX sh + jq only (shellcheck + bash-ism grep)" {
    command -v shellcheck >/dev/null 2>&1 || skip "shellcheck not installed"

    _sh_files=$(find core/bin core/tests adapters skills tests -type f \
        \( -name '*.sh' -o -name 'chantier' \) 2>/dev/null \
        | grep -v 'test_helper/' \
        | sort)

    _violations=""
    for _f in $_sh_files; do
        if ! shellcheck --shell=sh "$_f" >/dev/null 2>&1; then
            _violations="${_violations}${_f}
"
        fi
    done
    if [ -n "$_violations" ]; then
        printf 'nfr_audits: NFR-002 shellcheck violations:\n%b' "$_violations" >&2
        false
    fi

    # Bash-only constructs forbidden in POSIX sh sources.
    _bash_pat='\[\[ |<<<|mapfile|declare -a|local -a'
    _bash_violations=""
    for _f in $_sh_files; do
        if grep -E "$_bash_pat" "$_f" >/dev/null 2>&1; then
            _bash_violations="${_bash_violations}${_f}
"
        fi
    done
    if [ -n "$_bash_violations" ]; then
        printf 'nfr_audits: NFR-002 bash-only constructs in:\n%b' "$_bash_violations" >&2
        false
    fi
}

@test "nfr_audits: NFR-003 -- STATE.md append-only (no single-> redirect outside state_append)" {
    # Single-redirect to STATE.md (not >> append, not 2>&1). The runtime
    # mkdir-mutex inside core/bin/chantier state_append() is the dynamic
    # guard; this audit is the static guard. Scope: production .sh sources
    # in core/bin, adapters, and skills. Bats test files are excluded
    # because they scaffold isolated STATE.md fixtures inside
    # $BATS_TEST_TMPDIR for test setup -- not the production runtime path.
    _pat='>[[:space:]]*[^&].*STATE\.md'
    _violations=""
    while IFS= read -r _file; do
        [ -n "$_file" ] || continue
        case "$_file" in
            core/bin/chantier)
                # Exempt: state_append() inside the binary IS the sanctioned writer.
                continue
                ;;
        esac
        if grep -qE "$_pat" "$_file"; then
            _violations="${_violations}${_file}
"
        fi
    done <<EOF
$(find core/bin core/tests adapters skills -type f -name '*.sh' 2>/dev/null \
    | grep -v 'test_helper/' \
    | sort)
EOF

    if [ -n "$_violations" ]; then
        printf 'nfr_audits: NFR-003 violations (single-> to STATE.md outside state_append):\n%b' "$_violations" >&2
        false
    fi
}

@test "nfr_audits: NFR-004 -- no network primitives in executable code" { # HARNESS_DENY_LIST_CHECK
    # Forbidden in executable code: curl, wget, http://, https://, nc -, telnet  # HARNESS_DENY_LIST_CHECK
    # Documentation .md files are exempt by file-extension scope (the find walk  # HARNESS_DENY_LIST_CHECK
    # below includes only *.sh and the bare `chantier` filename). Comment lines  # HARNESS_DENY_LIST_CHECK
    # containing URLs are stripped before the deny-list pattern is applied.  # HARNESS_DENY_LIST_CHECK
    _net_pat='curl[[:space:]]|wget[[:space:]]|http[s]?://|nc[[:space:]]-|telnet[[:space:]]' # HARNESS_DENY_LIST_CHECK
    _violations=""
    while IFS= read -r _file; do
        [ -n "$_file" ] || continue
        case "$_file" in
            core/tests/nfr_audits.bats)
                # Self-exemption: this audit's own deny-list pattern.
                continue
                ;;
        esac
        if grep -v 'HARNESS_DENY_LIST_CHECK' "$_file" \
           | grep -vE '^[[:space:]]*#.*http' \
           | grep -qE "$_net_pat"; then
            _violations="${_violations}${_file}
"
        fi
    done <<EOF
$(find core/bin adapters skills -type f \
    \( -name '*.sh' -o -name 'chantier' \) 2>/dev/null \
    | grep -v 'test_helper/' \
    | sort)
EOF

    if [ -n "$_violations" ]; then
        printf 'nfr_audits: NFR-004 violations (network primitives in executable code):\n%b' "$_violations" >&2
        false
    fi
}

@test "nfr_audits: NFR-005 -- English-only public artifacts (French stop-word density)" {
    # Density-based detection avoids false positives on isolated loanwords
    # (naive, cafe, resume) by requiring >= 5 hits per file (RESEARCH
    # Pitfall 5 recommended approach). Word-boundary \b constraints; the
    # `.` in c.est / n.est accepts both straight and curly apostrophe.
    # Scope: public artifacts only. Exempt by scope (NOT walked):
    # .planning/ (legitimate French in session prose) and docs/strategy/
    # (sketches may quote conversation).
    _stop_words='\bavec\b|\bdonc\b|\bainsi\b|\bpour\b|\bdans\b|\bc.est\b|\bn.est\b|\bcette\b|\bnous\b'
    _scan_paths='README.md LICENSE LICENSE-CREDITS CONTRIBUTING.md'
    _scan_dirs='docs/adr docs/vision.md docs/research core skills adapters tests'

    _violations=""
    _existing=""
    for _p in $_scan_paths; do
        [ -e "$_p" ] && _existing="$_existing $_p"
    done
    for _d in $_scan_dirs; do
        [ -e "$_d" ] && _existing="$_existing $_d"
    done

    # shellcheck disable=SC2086
    while IFS= read -r _file; do
        [ -n "$_file" ] || continue
        case "$_file" in
            */test_helper/*) continue ;;
            core/tests/nfr_audits.bats) continue ;;
        esac
        _hits=$(grep -cE "$_stop_words" "$_file" 2>/dev/null || true)
        [ -z "$_hits" ] && _hits=0
        if [ "$_hits" -ge 5 ]; then
            _violations="${_violations}${_file}: $_hits French stop-words
"
        fi
    done <<EOF
$(find $_existing -type f 2>/dev/null | sort)
EOF

    if [ -n "$_violations" ]; then
        printf 'nfr_audits: NFR-005 violations (>=5 French stop-words per file):\n%b' "$_violations" >&2
        false
    fi
}

@test "nfr_audits: NFR-006 -- MIT license, collective copyright, SPDX headers" {
    # Five independent assertions (D-06 NFR-006).

    # 1. LICENSE first line is exactly "MIT License".
    if ! head -1 LICENSE | grep -qx 'MIT License'; then
        printf 'nfr_audits: NFR-006 LICENSE first line is not exactly "MIT License"\n' >&2
        false
    fi

    # 2. LICENSE-CREDITS file exists.
    if [ ! -f LICENSE-CREDITS ]; then
        printf 'nfr_audits: NFR-006 LICENSE-CREDITS missing\n' >&2
        false
    fi

    # 3. Every *.sh under our own source tree carries SPDX-License-Identifier: MIT
    # per Phase 4 D-NFR-006 convention. Vendored submodules (test_helper/) are
    # outside our authorship and exempt.
    _sh_files=$(find core/bin core/tests adapters skills tests -type f -name '*.sh' 2>/dev/null \
        | grep -v 'test_helper/' \
        | sort)
    _missing=""
    for _f in $_sh_files; do
        if ! grep -q 'SPDX-License-Identifier: MIT' "$_f"; then
            _missing="${_missing}${_f}
"
        fi
    done
    if [ -n "$_missing" ]; then
        printf 'nfr_audits: NFR-006 missing SPDX header in:\n%b' "$_missing" >&2
        false
    fi

    # 4. LICENSE contains collective "Chantier Contributors".
    if ! grep -q 'Chantier Contributors' LICENSE; then
        printf 'nfr_audits: NFR-006 LICENSE missing collective "Chantier Contributors"\n' >&2
        false
    fi

    # 5. No per-person copyright "(c) FirstName LastName" in LICENSE.
    if grep -qE '\(c\)[[:space:]]+[A-Z][a-z]+[[:space:]]+[A-Z][a-z]+' LICENSE; then
        printf 'nfr_audits: NFR-006 LICENSE contains per-person attribution (collective copyright required)\n' >&2
        false
    fi
}

# Decisions implemented: D-05 (single consolidated file) + D-06 (per-NFR audit shapes).
# RESEARCH Open Question 4: NFR-001 deny-list literal duplicated inline (not sourced).
