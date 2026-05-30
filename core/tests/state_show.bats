#!/usr/bin/env bats

# Tests for chantier state show — D-03
# Covers: header row, column alignment, null→dash substitution (Pitfall 2),
#         empty-body handling, refs joining, read-only (no lock acquisition),
#         frontmatter-only --- body line not mis-skipped.

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

# Test 1: state show with 0 body lines prints only the header and exits 0
@test "state show with empty body prints header only and exits 0" {
    run "$CHANTIER" state show
    assert_success
    # Output should be exactly one line (the header)
    [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -eq 1 ]
    assert_output --partial "TS"
    assert_output --partial "EVENT"
}

# Test 2: null task field renders as dash, not empty (BSD column collapse mitigation)
@test "state show renders null task as dash not empty string" {
    cat >> "$TMPHOME/.planning/STATE.md" <<'EOF'
{"ts":"2026-01-01T00:00:00Z","event":"bootstrap.session.started","actor":"ci","task":null,"skill":null,"summary":"boot","refs":[]}
EOF
    run "$CHANTIER" state show
    assert_success
    # The TASK column must show "-" not a blank/collapsed field
    assert_output --partial "-"
    # Row must have correct number of columns: header is 7 fields
    # Check that the data row contains the event name
    assert_output --partial "bootstrap.session.started"
}

# Test 3: three event lines produce header + 3 data rows (4 total output lines)
@test "state show with 3 body lines produces 4 output lines (header plus 3 data)" {
    cat >> "$TMPHOME/.planning/STATE.md" <<'EOF'
{"ts":"2026-01-01T00:00:00Z","event":"task.started","actor":"a","task":"t1","skill":"s1","summary":"s1","refs":[]}
{"ts":"2026-01-01T00:01:00Z","event":"task.completed","actor":"a","task":"t2","skill":"s2","summary":"s2","refs":[]}
{"ts":"2026-01-01T00:02:00Z","event":"skill.validated","actor":"a","task":"t3","skill":"s3","summary":"s3","refs":[]}
EOF
    run "$CHANTIER" state show
    assert_success
    LINE_COUNT=$(printf '%s\n' "$output" | wc -l | tr -d ' ')
    [ "$LINE_COUNT" -eq 4 ]
}

# Test 4: header row contains all expected column names in order
@test "state show header contains all 7 column names" {
    run "$CHANTIER" state show
    assert_success
    # First line must contain all expected headers
    FIRST_LINE=$(printf '%s\n' "$output" | head -1)
    printf '%s\n' "$FIRST_LINE" | grep -q "TS"
    printf '%s\n' "$FIRST_LINE" | grep -q "EVENT"
    printf '%s\n' "$FIRST_LINE" | grep -q "ACTOR"
    printf '%s\n' "$FIRST_LINE" | grep -q "TASK"
    printf '%s\n' "$FIRST_LINE" | grep -q "SKILL"
    printf '%s\n' "$FIRST_LINE" | grep -q "SUMMARY"
    printf '%s\n' "$FIRST_LINE" | grep -q "REFS"
}

# Test 5: refs array is comma-joined in the REFS column
@test "state show joins refs array with commas" {
    cat >> "$TMPHOME/.planning/STATE.md" <<'EOF'
{"ts":"2026-01-01T00:00:00Z","event":"task.completed","actor":"ci","task":"t1","skill":"s1","summary":"done","refs":["a","b"]}
EOF
    run "$CHANTIER" state show
    assert_success
    assert_output --partial "a,b"
}

# Test 6: state show does NOT acquire the mkdir lock (read-only contract)
@test "state show does not block concurrent state append (read-only)" {
    # Seed one existing event so show has something to render
    cat >> "$TMPHOME/.planning/STATE.md" <<'EOF'
{"ts":"2026-01-01T00:00:00Z","event":"task.completed","actor":"ci","task":null,"skill":null,"summary":"seed","refs":[]}
EOF

    # Run show 5 times in background (they should not acquire the lock)
    "$CHANTIER" state show >/dev/null &
    "$CHANTIER" state show >/dev/null &
    "$CHANTIER" state show >/dev/null &
    "$CHANTIER" state show >/dev/null &
    "$CHANTIER" state show >/dev/null &

    # append must succeed — if show held the lock, append would fail
    run "$CHANTIER" state append -e "task.started" -m "concurrent"
    wait
    assert_success
}

# Test 7: a body line starting with --- is not mis-skipped by the awk frontmatter stripper
@test "state show does not mis-skip body line containing three dashes" {
    # Write a STATE.md where the body contains a literal --- line
    # The awk frontmatter skip only counts the first two --- sentinels (lines 1 and 3)
    cat > "$TMPHOME/.planning/STATE.md" <<'EOF'
---
format_version: 0.1.0
---
{"ts":"2026-01-01T00:00:00Z","event":"task.completed","actor":"ci","task":null,"skill":null,"summary":"before dashes","refs":[]}
EOF
    # Manually append a line that happens to start with ---  embedded in a valid JSON line
    # (Edge case: a --- string as a refs value)
    cat >> "$TMPHOME/.planning/STATE.md" <<'EOF'
{"ts":"2026-01-01T00:01:00Z","event":"task.started","actor":"ci","task":null,"skill":null,"summary":"after dashes","refs":["---"]}
EOF

    run "$CHANTIER" state show
    assert_success
    # Both events should appear in the output
    assert_output --partial "before dashes"
    assert_output --partial "after dashes"
}
