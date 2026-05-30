#!/usr/bin/env bats

# Tests for chantier new -- FR-002 scaffold generator
# Covers: 5-file scaffold, frontmatter shape, JSONL-empty STATE.md,
#         TODO stubs, no example-content leakage, ASCII-only, integration.

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    export CHANTIER="$BATS_TEST_DIRNAME/../bin/chantier"
    mkdir -p "$BATS_TEST_TMPDIR/home"
    cd "$BATS_TEST_TMPDIR/home"
    # Canonicalize to avoid macOS /var -> /private/var mismatch
    export TMPHOME
    TMPHOME=$(pwd -P)
    mkdir -p "$TMPHOME/.planning"
    cat > "$TMPHOME/.planning/STATE.md" <<'EOF'
---
format_version: 0.1.0
---
EOF
}

# --------------------------------------------------------------------------
# Test 1: missing name arg exits 3 with usage message
# --------------------------------------------------------------------------
@test "new without name arg exits 3 with usage error message" {
    run "$CHANTIER" new
    assert_failure 3
    assert_output --partial "requires a project name"
}

# --------------------------------------------------------------------------
# Test 2: scaffold creates all 5 required files
# --------------------------------------------------------------------------
@test "new creates all 5 scaffold files in NAME/.planning/" {
    run "$CHANTIER" new demo-project
    assert_success
    [ -f "$TMPHOME/demo-project/.planning/PROJECT.md" ]
    [ -f "$TMPHOME/demo-project/.planning/REQUIREMENTS.md" ]
    [ -f "$TMPHOME/demo-project/.planning/ROADMAP.md" ]
    [ -f "$TMPHOME/demo-project/.planning/STATE.md" ]
    [ -f "$TMPHOME/demo-project/.planning/config.json" ]
}

# --------------------------------------------------------------------------
# Test 3: existing directory exits 1 (refuse to overwrite)
# --------------------------------------------------------------------------
@test "new refuses to overwrite existing directory, exits 1" {
    mkdir -p "$TMPHOME/demo-project"
    run "$CHANTIER" new demo-project
    assert_failure 1
    assert_output --partial "already exists"
}

# --------------------------------------------------------------------------
# Test 4: all generated .md files have valid YAML frontmatter delimiters
# --------------------------------------------------------------------------
@test "new scaffold files all have --- frontmatter delimiters" {
    run "$CHANTIER" new demo-project
    assert_success
    for f in PROJECT.md REQUIREMENTS.md ROADMAP.md STATE.md; do
        # Each file must start with --- on the first line
        first=$(head -1 "$TMPHOME/demo-project/.planning/$f")
        [ "$first" = "---" ]
    done
}

# --------------------------------------------------------------------------
# Test 5: PROJECT.md frontmatter has all 5 required fields
# --------------------------------------------------------------------------
@test "new PROJECT.md frontmatter has project_id, created, license, copyright, status" {
    run "$CHANTIER" new my-project
    assert_success
    _fm="$TMPHOME/my-project/.planning/PROJECT.md"
    grep -q "^project_id: my-project$" "$_fm"
    grep -q "^license: MIT$" "$_fm"
    grep -q "^copyright: my-project Contributors$" "$_fm"
    grep -q "^status: draft$" "$_fm"
    # created must match YYYY-MM-DD pattern
    grep -qE "^created: [0-9]{4}-[0-9]{2}-[0-9]{2}$" "$_fm"
}

# --------------------------------------------------------------------------
# Test 6: REQUIREMENTS.md frontmatter has all 4 required fields
# --------------------------------------------------------------------------
@test "new REQUIREMENTS.md frontmatter has project_id, milestone, created, status" {
    run "$CHANTIER" new my-project
    assert_success
    _fm="$TMPHOME/my-project/.planning/REQUIREMENTS.md"
    grep -q "^project_id: my-project$" "$_fm"
    grep -q "^milestone: v0.1.0$" "$_fm"
    grep -q "^status: draft$" "$_fm"
    grep -qE "^created: [0-9]{4}-[0-9]{2}-[0-9]{2}$" "$_fm"
}

# --------------------------------------------------------------------------
# Test 7: ROADMAP.md frontmatter has all 4 required fields
# --------------------------------------------------------------------------
@test "new ROADMAP.md frontmatter has project_id, created, milestone, status" {
    run "$CHANTIER" new my-project
    assert_success
    _fm="$TMPHOME/my-project/.planning/ROADMAP.md"
    grep -q "^project_id: my-project$" "$_fm"
    grep -q "^milestone: v0.1.0$" "$_fm"
    grep -q "^status: draft$" "$_fm"
    grep -qE "^created: [0-9]{4}-[0-9]{2}-[0-9]{2}$" "$_fm"
}

# --------------------------------------------------------------------------
# Test 8: STATE.md is JSONL-empty (frontmatter only, empty body)
# Body after the closing --- must be empty or a single newline (D-13).
# --------------------------------------------------------------------------
@test "new STATE.md is JSONL-empty: frontmatter only, no body lines" {
    run "$CHANTIER" new my-project
    assert_success
    _state="$TMPHOME/my-project/.planning/STATE.md"
    # Extract body lines (after the second ---): must be zero non-empty lines
    _body=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$_state" | grep -c '[^[:space:]]' || true)
    [ "$_body" -eq 0 ]
}

# --------------------------------------------------------------------------
# Test 9: Each generated .md file contains at least one TODO comment
# --------------------------------------------------------------------------
@test "new each scaffold .md file contains at least one TODO comment" {
    run "$CHANTIER" new my-project
    assert_success
    for f in PROJECT.md REQUIREMENTS.md ROADMAP.md; do
        grep -q '<!-- TODO:' "$TMPHOME/my-project/.planning/$f"
    done
}

# --------------------------------------------------------------------------
# Test 10: Each generated .md file contains at least one section heading
# --------------------------------------------------------------------------
@test "new each scaffold .md file contains at least one ## section heading" {
    run "$CHANTIER" new my-project
    assert_success
    for f in PROJECT.md REQUIREMENTS.md ROADMAP.md; do
        grep -qE "^## " "$TMPHOME/my-project/.planning/$f"
    done
}

# --------------------------------------------------------------------------
# Test 11: config.json is valid JSON
# --------------------------------------------------------------------------
@test "new config.json is valid JSON parsable by jq" {
    run "$CHANTIER" new my-project
    assert_success
    run jq empty "$TMPHOME/my-project/.planning/config.json"
    assert_success
}

# --------------------------------------------------------------------------
# Test 12: No "Chantier" or "chantier-build" leakage in scaffold files
# (uses project name "my-project", not "chantier")
# --------------------------------------------------------------------------
@test "new scaffold files do not leak Chantier or chantier-build identifiers" {
    run "$CHANTIER" new my-project
    assert_success
    run grep -rE "Chantier|chantier-build" "$TMPHOME/my-project/.planning/"
    # grep should find nothing (exit 1 = no matches = pass)
    assert_failure
}

# --------------------------------------------------------------------------
# Test 13: No non-ASCII characters in scaffold files (D-12 English-only)
# --------------------------------------------------------------------------
@test "new scaffold files contain only ASCII characters (D-12 English-only)" {
    run "$CHANTIER" new my-project
    assert_success
    # grep for non-ASCII; should find nothing
    run grep -rP "[^\x00-\x7F]" "$TMPHOME/my-project/.planning/" 2>/dev/null
    assert_failure
}

# --------------------------------------------------------------------------
# Test 14: Integration — state append succeeds on newly scaffolded STATE.md
# Proves FR-002 -> FR-003 round-trip.
# --------------------------------------------------------------------------
@test "new + state append integration: state append works on scaffolded STATE.md" {
    run "$CHANTIER" new my-project
    assert_success
    cd "$TMPHOME/my-project"
    run "$CHANTIER" state append -e bootstrap.session.started -m "init"
    assert_success
    # Verify a JSONL line was appended
    _body_count=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2 && /^\{/' .planning/STATE.md | wc -l | tr -d ' ')
    [ "$_body_count" -eq 1 ]
    cd "$TMPHOME"
}
