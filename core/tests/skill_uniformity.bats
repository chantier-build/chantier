#!/usr/bin/env bats

# Cross-skill structural compliance check (Phase 3, Wave 1).
#
# Implements three checks that read the live skills/ tree:
#   1. harness_adapters across all SKILL.md files are identical and equal to
#      the reference value declared by Phase 3 policy.
#   2. every PRESSURE.md ships at least two scenarios.
#   3. every skill ships an executable run.sh.
#
# When skills/ contains only .gitkeep (Wave 1 state), every @test emits skip.
# As soon as Wave 2 lands the four skill directories, the same three blocks
# flip to strict assertions without further edits. See 03-RESEARCH.md
# Pattern 5 for the canonical exemplar this file follows.

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    cd "$BATS_TEST_DIRNAME/../.."
}

@test "every shipped skill declares harness_adapters: [claude-code]" {
    _skill_dirs=$(find skills -mindepth 1 -maxdepth 1 -type d | sort)
    if [ -z "$_skill_dirs" ]; then
        skip "no skills shipped yet"
    fi

    _reference="claude-code"
    _all_arrays=""
    for _d in $_skill_dirs; do
        _skill_md="$_d/SKILL.md"
        [ -f "$_skill_md" ] || fail "$_d missing SKILL.md"

        _arr=$(awk '
            BEGIN { in_fm=0; in_ha=0 }
            /^---$/ { in_fm = !in_fm; next }
            in_fm && /^harness_adapters:/ { in_ha=1; next }
            in_fm && in_ha && /^[a-z_]+:/ { in_ha=0 }
            in_fm && in_ha && /^[[:space:]]+-/ {
                sub(/^[[:space:]]+-[[:space:]]*/, "")
                gsub(/"/, "")
                print
            }
        ' "$_skill_md" | sort | tr '\n' ',' | sed 's/,$//')
        _all_arrays="${_all_arrays}${_arr}|"
    done

    for _entry in $(echo "$_all_arrays" | tr '|' '\n'); do
        [ -z "$_entry" ] && continue
        [ "$_entry" = "$_reference" ] || \
            fail "harness_adapters drift detected: got '$_entry', expected '$_reference'"
    done
}

@test "every shipped skill has a PRESSURE.md with at least two scenarios" {
    _skill_dirs=$(find skills -mindepth 1 -maxdepth 1 -type d | sort)
    if [ -z "$_skill_dirs" ]; then
        skip "no skills shipped yet"
    fi

    for _d in $_skill_dirs; do
        _pf="$_d/PRESSURE.md"
        [ -f "$_pf" ] || fail "$_d missing PRESSURE.md (FR-010)"
        _count=$(grep -cE '^## Scenario [0-9]' "$_pf" || true)
        [ "$_count" -ge 2 ] || \
            fail "$_d PRESSURE.md has $_count scenarios; need >= 2 (FR-010)"
    done
}

@test "every shipped skill ships a run.sh per D-01" {
    _skill_dirs=$(find skills -mindepth 1 -maxdepth 1 -type d | sort)
    if [ -z "$_skill_dirs" ]; then
        skip "no skills shipped yet"
    fi

    for _d in $_skill_dirs; do
        [ -f "$_d/run.sh" ] || fail "$_d missing run.sh (D-01: uniform mandate)"
        [ -x "$_d/run.sh" ] || fail "$_d/run.sh is not executable"
    done
}

# Decisions implemented: D-01 / D-16 / FR-010
