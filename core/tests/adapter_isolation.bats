#!/usr/bin/env bats

# Cross-tree NFR-001 carve-out audit (Phase 4 D-09, D-10, D-11, D-12).
#
# Audits the source tree for harness identifier leaks. The deny-list pattern
# is byte-identical to core/bin/chantier --self-test (HARNESS_DENY_LIST_CHECK
# marker convention from ADR 0002). Path-only carve-out per D-10: the
# directory adapters/claude-code/ may legitimately contain the substrings
# `claude-code` and `mcp__claude_ai_` (the directory IS the harness's
# adapter); everywhere else those tokens are forbidden alongside the other
# harness names (cursor, codex-cli, copilot-cli, gemini-cli, opencode,
# bare mcp__, bare claude_ai_, @codebase).
#
# Scope walked: core/, skills/, adapters/. Out of scope (per D-11): docs/
# and .planning/ (free-form, may name any harness). Two explicit case-arm
# exemptions document D-11 exempt paths:
#   - core/bin/chantier         : carries its own HARNESS_DENY_LIST_CHECK
#                                 self-scan in --self-test (D-11 explicit).
#   - core/schemas/skill.json   : the JSON schema's `harness_adapters` enum
#                                 lists every harness name as metadata, not
#                                 as an invocation (D-11 explicit; documented
#                                 at core/bin/chantier:908-909).
#
# Self-exemption (per D-11 / RESEARCH A3): every line in this file that
# contains a deny-list token carries a trailing `# HARNESS_DENY_LIST_CHECK`
# comment. For every other file scanned, the audit mirrors the binary's
# --self-test approach (core/bin/chantier:913): the per-file `grep -v
# HARNESS_DENY_LIST_CHECK` step strips marker-tagged lines from each file's
# content before applying the deny-list pattern. A `case` arm also
# explicitly skips this audit file as a double-belt guard against future
# edits that drop a marker.
#
# Setup mirrors core/tests/skill_uniformity.bats for the cd-to-repo-root
# pattern and POSIX find walk (Pitfall 4 — no GNU-only find flags).

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    cd "$BATS_TEST_DIRNAME/../.."
}

@test "adapter_isolation: cross-tree NFR-001 carve-out — deny-list tokens absent outside adapters/claude-code/" { # HARNESS_DENY_LIST_CHECK
    # Full deny-list (byte-identical to core/bin/chantier:687 and :912).
    # Marker on each line keeps the audit's per-file grep step from ever
    # matching this file's own deny-list literals.
    _full='mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode' # HARNESS_DENY_LIST_CHECK

    # Narrow deny-list applied INSIDE adapters/claude-code/ only (D-10  # HARNESS_DENY_LIST_CHECK
    # carve-out): drop `claude-code` and `mcp__claude_ai_` from the set,  # HARNESS_DENY_LIST_CHECK
    # keep the other harness names + @codebase + bare mcp__ outside  # HARNESS_DENY_LIST_CHECK
    # mcp__claude_ai_. Cross-adapter-pollution guard.  # HARNESS_DENY_LIST_CHECK
    _narrow='@codebase|cursor|codex-cli|copilot-cli|gemini-cli|opencode' # HARNESS_DENY_LIST_CHECK

    _violations=""
    while IFS= read -r _file; do
        [ -n "$_file" ] || continue
        case "$_file" in
            core/bin/chantier)
                # D-11 explicit exemption: the binary has its own
                # HARNESS_DENY_LIST_CHECK self-scan in --self-test.
                continue
                ;;
            core/schemas/skill.json)
                # D-11 explicit exemption: the schema's harness_adapters
                # enum names every harness as metadata (not invocation).
                # Documented at core/bin/chantier:908-909.
                continue
                ;;
            core/tests/adapter_isolation.bats)
                # Double-belt self-exemption (RESEARCH A3). The per-file
                # marker filter below already strips this file's deny-list
                # literals, but if a future edit ever loses a marker on a
                # single line this case arm guarantees the audit still
                # does not flag itself.
                continue
                ;;
            skills/*/SKILL.md)
                # The sanctioned `harness_adapters: - claude-code` YAML  # HARNESS_DENY_LIST_CHECK
                # frontmatter line is allowed in every SKILL.md (D-14 from
                # Phase 3). Filter that exact line AND any line carrying
                # the HARNESS_DENY_LIST_CHECK marker, then apply the full
                # deny-list to everything else.
                _filter_claude='^[[:space:]]*-[[:space:]]*claude-code$' # HARNESS_DENY_LIST_CHECK
                if grep -v 'HARNESS_DENY_LIST_CHECK' "$_file" \
                   | grep -vE "$_filter_claude" \
                   | grep -qE "$_full"; then
                    _violations="${_violations}${_file}
"
                fi
                ;;
            adapters/claude-code/*) # HARNESS_DENY_LIST_CHECK
                # D-10 carve-out: only the narrow list applies inside  # HARNESS_DENY_LIST_CHECK
                # adapters/claude-code/. The substrings `claude-code` and  # HARNESS_DENY_LIST_CHECK
                # `mcp__claude_ai_` are sanctioned here.  # HARNESS_DENY_LIST_CHECK
                if grep -v 'HARNESS_DENY_LIST_CHECK' "$_file" \
                   | grep -qE "$_narrow"; then # HARNESS_DENY_LIST_CHECK
                    _violations="${_violations}${_file}
"
                fi
                ;;
            *)
                # Default arm: full deny-list applies. Per-file marker
                # filter mirrors core/bin/chantier:913 so any line tagged
                # HARNESS_DENY_LIST_CHECK is excluded from the scan.
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
        printf 'adapter_isolation: deny-list violations:\n%b' "$_violations" >&2
        false
    fi
}

# Decisions implemented: D-09 / D-10 / D-11 / D-12 — per D-09 and D-11.
