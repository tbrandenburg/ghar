#!/usr/bin/env bash
# TDD test script for Issue #14 — README wording polish
set -o errexit
set -o nounset
set -o pipefail

SNAPSHOT="$(dirname "$0")/README.md.snapshot"
README="README.md"
FAILED=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILED=1; }

check_grep() {
    local label="$1" pattern="$2"
    if grep -Fxq "$pattern" "$README"; then
        pass "$label"
    else
        echo "FAIL: $label — expected pattern not found: $pattern"
        FAILED=1
    fi
}

check_count() {
    local label="$1" pattern="$2" expected="$3"
    local actual
    actual=$(grep -c "$pattern" "$README" 2>/dev/null || echo 0)
    if [ "$actual" -eq "$expected" ]; then
        pass "$label"
    else
        echo "FAIL: $label — expected count $expected, got $actual (pattern: $pattern)"
        FAILED=1
    fi
}

# AC1: Subtitle capitalization
check_grep "AC1 — Subtitle uses 'GitHub'" 'Agent routines in GitHub workflows'

# AC2: Quick-install comment 1
check_grep "AC2 — Comment 1 is '# Standard install'" '# Standard install'

# AC3: Quick-install comment 2
check_grep "AC3 — Comment 2 is '# Force reinstall'" '# Force reinstall'

# AC4: Quick-install comment 3
check_grep "AC4 — Comment 3 is '# Commit and push'" '# Commit and push'

# AC5: Zero incidental changes — exactly 4 lines differ from snapshot
if [ -f "$SNAPSHOT" ]; then
    diff_lines=$(diff "$SNAPSHOT" "$README" 2>/dev/null | grep -c '^[<>]' || true)
    if [ "$diff_lines" -eq 8 ]; then
        pass "AC5 — Exactly 8 diff lines (4 changes) from snapshot"
    else
        echo "FAIL: AC5 — Expected 8 diff lines (4 changes) from snapshot, got $diff_lines"
        diff "$SNAPSHOT" "$README" 2>/dev/null || true
        FAILED=1
    fi
else
    echo "FAIL: AC5 — Snapshot file not found at $SNAPSHOT"
    FAILED=1
fi

# RT-1 (adversarial): No trailing whitespace on critical lines
check_no_trailing_ws() {
    local label="$1" line_nr="$2"
    local raw trimmed
    raw=$(sed -n "${line_nr}p" "$README")
    trimmed=$(printf '%s' "$raw" | sed 's/[[:space:]]*$//')
    if [ "$raw" = "$trimmed" ]; then
        pass "$label"
    else
        echo "FAIL: $label — line $line_nr has trailing whitespace"
        FAILED=1
    fi
}
check_no_trailing_ws "RT-1a — No trailing ws on subtitle (line 3)" 3
check_no_trailing_ws "RT-1b — No trailing ws on comment 1 (line 8)" 8
check_no_trailing_ws "RT-1c — No trailing ws on comment 2 (line 11)" 11
check_no_trailing_ws "RT-1d — No trailing ws on comment 3 (line 14)" 14

# AC7-N1 (negative): H1 must remain unchanged
check_count 'AC7-N1 — H1 unchanged (count = 1)' '^# GHAR - Github Agent Routines' 1

# AC8-N2 (negative): Only the H1 contains 'Github' (not the subtitle)
check_count 'AC8-N2 — Only H1 has Github (count = 1)' 'Github' 1

echo ""
if [ "$FAILED" -eq 0 ]; then
    echo "All tests passed."
    exit 0
else
    echo "Some tests failed."
    exit 1
fi
