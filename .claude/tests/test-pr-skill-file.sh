#!/usr/bin/env bash
# test-pr-skill-file.sh
# Tests for SKIL-03: Validates skills/pr/SKILL.md file existence and content
# This test validates the SKIL-03 file artifact independently of other tests.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL_FILE="$REPO_ROOT/skills/pr/SKILL.md"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "--- test-pr-skill-file.sh ---"

# ---------------------------------------------------------------------------
# Test 1: skills/pr/SKILL.md exists and is a regular file
# ---------------------------------------------------------------------------
if [ -f "$SKILL_FILE" ]; then
  pass "Test 1: skills/pr/SKILL.md exists and is a regular file"
else
  fail "Test 1: skills/pr/SKILL.md does not exist (expected at $SKILL_FILE)"
fi

# ---------------------------------------------------------------------------
# Test 2: File contains "c4flow:pr" in the frontmatter name field
# ---------------------------------------------------------------------------
if grep -q '^name: c4flow:pr' "$SKILL_FILE" 2>/dev/null; then
  pass "Test 2: frontmatter contains 'name: c4flow:pr'"
else
  fail "Test 2: frontmatter missing 'name: c4flow:pr'"
fi

# ---------------------------------------------------------------------------
# Test 3: File contains "gh pr create" (core PR creation command)
# ---------------------------------------------------------------------------
if grep -q 'gh pr create' "$SKILL_FILE" 2>/dev/null; then
  pass "Test 3: skill contains 'gh pr create'"
else
  fail "Test 3: skill missing 'gh pr create'"
fi

# ---------------------------------------------------------------------------
# Test 4: File contains "quality-gate-status.json" (gate status integration)
# ---------------------------------------------------------------------------
if grep -q 'quality-gate-status.json' "$SKILL_FILE" 2>/dev/null; then
  pass "Test 4: skill references 'quality-gate-status.json'"
else
  fail "Test 4: skill missing reference to 'quality-gate-status.json'"
fi

# ---------------------------------------------------------------------------
# Test 5: File is at least 120 lines (non-stub)
# ---------------------------------------------------------------------------
LINE_COUNT=$(wc -l < "$SKILL_FILE" 2>/dev/null || echo 0)
if [ "$LINE_COUNT" -ge 120 ]; then
  pass "Test 5: file is $LINE_COUNT lines (>= 120, non-stub)"
else
  fail "Test 5: file is only $LINE_COUNT lines (expected >= 120 for non-stub)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL=$((PASS + FAIL))
echo ""
echo "test-pr-skill-file.sh: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
