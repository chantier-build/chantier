#!/usr/bin/env bats

# Tests for chantier state append — FR-003
# Covers: event regex enforcement (D-09), single-line atomicity, repeated -r,
#         null task/skill (D-02), concurrent-append safety, actor fallback (Pitfall 9),
#         timestamp format, exit-code matrix.

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

# Helper: count JSONL body lines (lines after the second --- sentinel)
body_line_count() {
    awk '/^---$/{c++; next} c>=2' "$TMPHOME/.planning/STATE.md" | wc -l | tr -d ' '
}

# Helper: get the Nth body line (1-indexed)
body_line() {
    awk '/^---$/{c++; next} c>=2' "$TMPHOME/.planning/STATE.md" | sed -n "${1}p"
}

# Test 1: bad event name with underscore exits 1 and mentions shape regex
@test "state append rejects underscore event name (exit 1, stderr mentions shape regex)" {
    run "$CHANTIER" state append -e "BAD_NAME" -m "summary"
    assert_failure 1
    assert_output --partial "shape regex"
}

# Test 2: uppercase characters rejected
@test "state append rejects uppercase event name (exit 1)" {
    run "$CHANTIER" state append -e "BadCase" -m "x"
    assert_failure 1
    assert_output --partial "shape regex"
}

# Test 3: leading dot rejected
@test "state append rejects leading-dot event name (exit 1)" {
    run "$CHANTIER" state append -e ".leading.dot" -m "x"
    assert_failure 1
    assert_output --partial "shape regex"
}

# Test 4: trailing dot rejected
@test "state append rejects trailing-dot event name (exit 1)" {
    run "$CHANTIER" state append -e "trailing." -m "x"
    assert_failure 1
    assert_output --partial "shape regex"
}

# Test 5: missing -e exits 3 (usage error)
@test "state append exits 3 when -e is missing" {
    run "$CHANTIER" state append -m "summary"
    assert_failure 3
}

# Test 6: missing -m exits 3 (usage error)
@test "state append exits 3 when -m is missing" {
    run "$CHANTIER" state append -e "task.completed"
    assert_failure 3
}

# Test 7: valid append exits 0 and writes exactly one body line
@test "state append writes exactly one JSONL body line on success" {
    run "$CHANTIER" state append -e "task.completed" -t "t1" -s "tdd" -m "done"
    assert_success
    [ "$(body_line_count)" -eq 1 ]
}

# Test 8: the appended line is valid JSON parsable by jq empty
@test "state append writes a valid JSON line" {
    "$CHANTIER" state append -e "task.completed" -t "t1" -s "tdd" -m "done"
    LINE="$(body_line 1)"
    [ -n "$LINE" ]
    run sh -c 'printf "%s\n" "$1" | jq empty' -- "$LINE"
    assert_success
}

# Test 9: task and skill appear as strings when provided
@test "state append stores task and skill as JSON strings" {
    "$CHANTIER" state append -e "task.completed" -t "t1" -s "tdd" -m "done"
    LINE="$(body_line 1)"
    TASK_VAL=$(printf '%s\n' "$LINE" | jq -r '.task')
    SKILL_VAL=$(printf '%s\n' "$LINE" | jq -r '.skill')
    [ "$TASK_VAL" = "t1" ]
    [ "$SKILL_VAL" = "tdd" ]
}

# Test 10: task and skill are JSON null when not provided
@test "state append stores task and skill as null when omitted" {
    "$CHANTIER" state append -e "bootstrap.session.started" -m "x"
    LINE="$(body_line 1)"
    TASK_VAL=$(printf '%s\n' "$LINE" | jq '.task')
    SKILL_VAL=$(printf '%s\n' "$LINE" | jq '.skill')
    [ "$TASK_VAL" = "null" ]
    [ "$SKILL_VAL" = "null" ]
}

# Test 11: repeated -r flags accumulate into a refs array of the correct length
@test "state append accumulates repeated -r flags into refs array" {
    "$CHANTIER" state append -e "task.completed" -m "x" -r "ref1" -r "ref2" -r "ref3"
    LINE="$(body_line 1)"
    REF_COUNT=$(printf '%s\n' "$LINE" | jq '.refs | length')
    [ "$REF_COUNT" -eq 3 ]
    # Verify actual values
    REF1=$(printf '%s\n' "$LINE" | jq -r '.refs[0]')
    REF2=$(printf '%s\n' "$LINE" | jq -r '.refs[1]')
    REF3=$(printf '%s\n' "$LINE" | jq -r '.refs[2]')
    [ "$REF1" = "ref1" ]
    [ "$REF2" = "ref2" ]
    [ "$REF3" = "ref3" ]
}

# Test 12: five concurrent state appends produce 5 valid JSONL lines (no corruption)
@test "concurrent state appends produce 5 valid JSONL lines" {
    # Spawn 5 background appends; each runs in its own subshell per bats-core isolation
    "$CHANTIER" state append -e "task.started" -t "t1" -m "p1" &
    "$CHANTIER" state append -e "task.started" -t "t2" -m "p2" &
    "$CHANTIER" state append -e "task.started" -t "t3" -m "p3" &
    "$CHANTIER" state append -e "task.started" -t "t4" -m "p4" &
    "$CHANTIER" state append -e "task.started" -t "t5" -m "p5" &
    wait

    # Assert exactly 5 body lines
    [ "$(body_line_count)" -eq 5 ]

    # Assert every body line is valid JSON
    awk '/^---$/{c++; next} c>=2' "$TMPHOME/.planning/STATE.md" | while IFS= read -r ln; do
        printf '%s\n' "$ln" | jq empty || { printf 'corrupt line: %s\n' "$ln" >&2; false; }
    done
}

# Test 13: actor field is "unknown" when git config user.name is unset
@test "state append uses unknown actor when git config user.name is absent" {
    # env -i clears inherited environment; pass only HOME (pointing at TMPHOME) and PATH
    # so git config user.name returns empty and the fallback triggers (Pitfall 9)
    run env -i HOME="$TMPHOME" PATH="$PATH" "$CHANTIER" state append \
        -e "task.completed" -m "ci run"
    assert_success
    LINE="$(body_line 1)"
    ACTOR_VAL=$(printf '%s\n' "$LINE" | jq -r '.actor')
    [ "$ACTOR_VAL" = "unknown" ]
}

# Test 14: ts field matches ISO-8601 UTC pattern
@test "state append ts field matches ISO-8601 UTC pattern" {
    "$CHANTIER" state append -e "task.completed" -m "ts check"
    LINE="$(body_line 1)"
    TS_VAL=$(printf '%s\n' "$LINE" | jq -r '.ts')
    printf '%s\n' "$TS_VAL" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
}

# Test 15: valid dotted-namespace event with 3 segments is accepted
@test "state append accepts valid 3-segment dotted event name" {
    run "$CHANTIER" state append -e "bootstrap.session.started" -m "ok"
    assert_success
}

# Test 16: double-dot in event name is rejected
@test "state append rejects double-dot event name (exit 1)" {
    run "$CHANTIER" state append -e "task..completed" -m "x"
    assert_failure 1
}

# Test 17: single-segment event name (no dot) is rejected
@test "state append rejects single-segment event name with no dot" {
    run "$CHANTIER" state append -e "nodot" -m "x"
    assert_failure 1
}

# Test 18: refs array is empty array (not null) when no -r provided
@test "state append stores refs as empty array when no -r flags given" {
    "$CHANTIER" state append -e "task.completed" -m "no refs"
    LINE="$(body_line 1)"
    REFS_VAL=$(printf '%s\n' "$LINE" | jq '.refs')
    [ "$REFS_VAL" = "[]" ]
}
