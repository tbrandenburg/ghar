#!/usr/bin/env bash
set -o nounset -o pipefail

readonly BASELINE="${1:-origin/main}"
readonly README="README.md"
failures=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }

# ---------------------------------------------------------------------------
# Unit-level tests (direct string assertions on README content)
# ---------------------------------------------------------------------------

# U1 / AC2a — Title has "GitHub" (capital H)
if grep -q '^# GHAR - GitHub Agent Routines' "$README"; then
  pass "U1: Title contains 'GitHub Agent Routines'"
else
  fail "U1: Line 1 missing 'GitHub Agent Routines' — got: $(head -1 "$README")"
fi

# U2 / AC2a — Subtitle has "GitHub" and new phrasing
if grep -q 'Automated agent routines for GitHub workflows' "$README"; then
  pass "U2: Subtitle matches 'Automated agent routines for GitHub workflows'"
else
  fail "U2: Line 3 missing expected subtitle — got: $(sed -n '3p' "$README")"
fi

# U3 / AC5 — Valid Markdown (parses without error)
if python3 -c "import markdown; markdown.markdown(open('$README').read())" 2>/dev/null; then
  pass "U3: README.md parses as valid Markdown"
else
  fail "U3: README.md failed Markdown parse — python3 -c 'import markdown; markdown.markdown(open(\"README.md\").read())'"
fi

# ---------------------------------------------------------------------------
# Integration-level tests (git diff against baseline)
# ---------------------------------------------------------------------------

# I1 / AC1 — Only README.md modified
changed_files=$(git diff --name-only "$BASELINE"..HEAD)
if [ "$changed_files" = "$README" ]; then
  pass "I1: Only README.md modified"
else
  fail "I1: Expected only README.md, got: $(echo "$changed_files" | tr '\n' ' ')"
fi

# I2 / AC7 — Changed lines count ≤ 4
changed_lines=$(git diff --unified=0 "$BASELINE"..HEAD -- "$README" | grep '^[+-][^+-]' | wc -l)
if [ "$changed_lines" -ge 1 ] && [ "$changed_lines" -le 4 ]; then
  pass "I2: Changed lines = $changed_lines (within [1,4])"
else
  fail "I2: Expected 1–4 changed lines, got $changed_lines"
fi

# I3 / AC8 — No whitespace-only drift
ws_diff=$(git diff --ignore-all-space "$BASELINE"..HEAD -- "$README")
if [ -z "$ws_diff" ]; then
  pass "I3: No whitespace-only drift"
else
  fail "I3: Whitespace drift detected — run git diff --ignore-all-space to inspect"
fi

# I4 / AC3 — No whitespace-only hunks
normal_diff=$(git diff "$BASELINE"..HEAD -- "$README")
ignore_ws_diff=$(git diff -w "$BASELINE"..HEAD -- "$README")
if [ "$normal_diff" = "$ignore_ws_diff" ]; then
  pass "I4: No whitespace-only hunks"
else
  fail "I4: git diff and git diff -w differ — whitespace-only hunks present"
fi

# I5 / AC2b+AC4 — Headings preserved (same count and order)
headings_now=$(grep '^## ' "$README")
headings_base=$(git show "$BASELINE":"$README" | grep '^## ')
if [ "$headings_now" = "$headings_base" ]; then
  pass "I5: Headings preserved"
else
  fail "I5: Headings changed — expected same as $BASELINE"
fi

# I6 / AC1 — Negative: Makefile.ghar and AGENTS.md not modified
if echo "$changed_files" | grep -q 'Makefile.ghar'; then
  fail "I6: Makefile.ghar was modified"
elif echo "$changed_files" | grep -q 'AGENTS.md'; then
  fail "I6: AGENTS.md was modified"
else
  pass "I6: Makefile.ghar and AGENTS.md untouched"
fi

# ---------------------------------------------------------------------------
# Regression / Negative tests
# ---------------------------------------------------------------------------

# N1 — Diff is non-empty (change was actually made)
readme_diff=$(git diff "$BASELINE"..HEAD -- "$README")
if [ -n "$readme_diff" ]; then
  pass "N1: README.md differs from $BASELINE"
else
  fail "N1: No diff in README.md — no change was made"
fi

# N2 — No file other than README.md changed
other_changed=$(git diff --name-only "$BASELINE"..HEAD -- . | grep -v '^README.md$' || true)
if [ -z "$other_changed" ]; then
  pass "N2: No file other than README.md was changed"
else
  fail "N2: Unexpected changed files: $(echo "$other_changed" | tr '\n' ' ')"
fi

# N3 — U1 and U2 not reverted (run again as regression check)
if grep -q '^# GHAR - GitHub Agent Routines' "$README"; then
  pass "N3: Title regression check — 'GitHub Agent Routines' still present"
else
  fail "N3: Title regression — 'GitHub Agent Routines' was reverted"
fi
if grep -q 'Automated agent routines for GitHub workflows' "$README"; then
  pass "N3: Subtitle regression check — 'Automated agent routines for GitHub workflows' still present"
else
  fail "N3: Subtitle regression — expected phrasing was reverted"
fi

echo ""
if [ "$failures" -gt 0 ]; then
  echo "RESULT: $failures test(s) FAILED"
  exit 1
else
  echo "RESULT: All tests passed"
  exit 0
fi
