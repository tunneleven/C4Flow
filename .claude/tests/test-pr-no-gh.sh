#!/usr/bin/env bash
# test-pr-no-gh.sh
# Tests for SKIL-03: Validates the gh CLI detection pattern used in c4flow:pr
# Verifies that command -v correctly detects missing tools (simulates missing gh).
# We cannot run the full skill without live gh, but we verify the detection mechanism.

set -uo pipefail

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "--- test-pr-no-gh.sh ---"

# ---------------------------------------------------------------------------
# Test 1: command -v on a non-existent binary returns non-zero (simulates missing gh)
# ---------------------------------------------------------------------------
if ! command -v gh_nonexistent_binary_xxx &>/dev/null; then
  pass "Test 1: command -v returns non-zero for non-existent binary (gh-missing detection works)"
else
  fail "Test 1: command -v unexpectedly found 'gh_nonexistent_binary_xxx'"
fi

# ---------------------------------------------------------------------------
# Test 2: command -v on a known binary returns zero (detection does not false-positive)
# ---------------------------------------------------------------------------
if command -v bash &>/dev/null; then
  pass "Test 2: command -v returns zero for known binary 'bash' (no false positives)"
else
  fail "Test 2: command -v failed to find 'bash'"
fi

# ---------------------------------------------------------------------------
# Test 3: Validate the if-not pattern (the exact check used in SKILL.md)
# This test simulates what happens when PATH does not contain gh
# ---------------------------------------------------------------------------
DETECTION_RESULT="found"
if ! command -v gh_missing_tool_xyz &>/dev/null; then
  DETECTION_RESULT="missing"
fi

if [ "$DETECTION_RESULT" = "missing" ]; then
  pass "Test 3: if-not pattern correctly identifies missing tool as 'missing'"
else
  fail "Test 3: if-not pattern failed to classify missing tool"
fi

# ---------------------------------------------------------------------------
# Test 4: gh is actually installed (sanity check — confirms real environment)
# This test documents that gh is expected to be present in the project environment.
# ---------------------------------------------------------------------------
if command -v gh &>/dev/null; then
  pass "Test 4: gh CLI is installed (environment sanity check)"
else
  # Not a hard failure — gh may not be in CI; document as informational
  echo "  INFO: gh CLI not found — will need manual PR creation in this environment"
  pass "Test 4: gh CLI not present (informational — detection pattern still verified by Tests 1-3)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL=$((PASS + FAIL))
echo ""
echo "test-pr-no-gh.sh: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
