#!/usr/bin/env bats

# Tests for core/bin/chantier self-test contract (plan 02-03)
# Covers: --self-test, --version, --help, unknown-subcommand exit code,
#         harness-deny-list (NFR-001), CRLF check, subcommand stubs, shellcheck.

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

# Test 1: --self-test exits 0 on a clean host
@test "chantier --self-test exits 0 on a clean host" {
    run "$CHANTIER" --self-test
    assert_success
    assert_output --partial "self-test: all green"
}

# Test 2: --version prints exactly 0.1.0
@test "chantier --version prints exactly 0.1.0" {
    run "$CHANTIER" --version
    assert_success
    assert_output "0.1.0"
}

# Test 3: --help exits 0 and lists expected subcommands
@test "chantier --help exits 0 and lists all subcommands" {
    run "$CHANTIER" --help
    assert_success
    assert_output --partial "state append"
    assert_output --partial "state show"
    assert_output --partial "validate-task"
    assert_output --partial "new"
    assert_output --partial "--self-test"
}

# Test 4: unknown subcommand exits 3 with descriptive stderr message
@test "unknown subcommand exits 3 with stderr message" {
    run "$CHANTIER" bogus-subcommand-xyz
    assert_failure 3
    assert_output --partial "unknown subcommand:"
}

# Test 5: no harness identifiers in binary outside deny-list marker line (NFR-001)
#   Strips lines marked HARNESS_DENY_LIST_CHECK before grepping; count must be 0.
@test "binary contains no harness identifiers outside deny-list marker" {
    _deny='mcp__|claude_ai_|@codebase|claude-code|cursor|codex-cli|copilot-cli|gemini-cli|opencode' # HARNESS_DENY_LIST_CHECK
    run sh -c "grep -v 'HARNESS_DENY_LIST_CHECK' \"$CHANTIER\" | grep -cE '$_deny' || true"
    assert_success
    assert_output "0"
}

# Test 6: binary has LF line endings, not CRLF
@test "binary has LF line endings (no CRLF)" {
    run sh -c "file \"$CHANTIER\" | grep -q CRLF && echo found || echo clean"
    assert_success
    assert_output "clean"
}

# Test 7: every subcommand stub answers --help with exit 0
@test "state append --help exits 0" {
    run "$CHANTIER" state append --help
    assert_success
}

@test "state show --help exits 0" {
    run "$CHANTIER" state show --help
    assert_success
}

@test "validate-task --help exits 0" {
    run "$CHANTIER" validate-task --help
    assert_success
}

@test "new --help exits 0" {
    run "$CHANTIER" new --help
    assert_success
}

# Test 8: shellcheck passes on the binary (zero errors; warnings tolerated for skeleton)
@test "shellcheck -s sh on binary exits 0" {
    run shellcheck -s sh "$CHANTIER"
    assert_success
}
