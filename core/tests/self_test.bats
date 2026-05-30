#!/usr/bin/env bats

# Real tests added in plan 02-03-PLAN.md

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
