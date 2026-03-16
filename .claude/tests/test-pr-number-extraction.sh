#!/usr/bin/env bash
# test-pr-number-extraction.sh
# Tests for SKIL-03: Validates PR number extraction from GitHub URL
# Uses the pattern: echo "$PR_URL" | grep -o '[0-9]*$'

set -uo pipefail

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "--- test-pr-number-extraction.sh ---"

# Helper: extract PR number from a GitHub PR URL
extract_pr_number() {
  echo "$1" | grep -o '[0-9]*$'
}

# ---------------------------------------------------------------------------
# Test 1: Standard PR URL with number 42
# ---------------------------------------------------------------------------
URL="https://github.com/owner/repo/pull/42"
RESULT=$(extract_pr_number "$URL")
if [ "$RESULT" = "42" ]; then
  pass "Test 1: extract number 42 from pull/42 URL"
else
  fail "Test 1: expected '42', got: '$RESULT'"
fi

# ---------------------------------------------------------------------------
# Test 2: Large PR number 1337
# ---------------------------------------------------------------------------
URL="https://github.com/owner/repo/pull/1337"
RESULT=$(extract_pr_number "$URL")
if [ "$RESULT" = "1337" ]; then
  pass "Test 2: extract number 1337 from pull/1337 URL"
else
  fail "Test 2: expected '1337', got: '$RESULT'"
fi

# ---------------------------------------------------------------------------
# Test 3: Single digit PR number 1
# ---------------------------------------------------------------------------
URL="https://github.com/owner/repo/pull/1"
RESULT=$(extract_pr_number "$URL")
if [ "$RESULT" = "1" ]; then
  pass "Test 3: extract number 1 from pull/1 URL"
else
  fail "Test 3: expected '1', got: '$RESULT'"
fi

# ---------------------------------------------------------------------------
# Test 4: Large multi-digit PR number 10000
# ---------------------------------------------------------------------------
URL="https://github.com/tunneleven/C4Flow/pull/10000"
RESULT=$(extract_pr_number "$URL")
if [ "$RESULT" = "10000" ]; then
  pass "Test 4: extract number 10000 from pull/10000 URL"
else
  fail "Test 4: expected '10000', got: '$RESULT'"
fi

# ---------------------------------------------------------------------------
# Test 5: Real-looking repo with hyphenated org/name
# ---------------------------------------------------------------------------
URL="https://github.com/my-org/my-repo/pull/99"
RESULT=$(extract_pr_number "$URL")
if [ "$RESULT" = "99" ]; then
  pass "Test 5: extract number 99 from hyphenated repo URL"
else
  fail "Test 5: expected '99', got: '$RESULT'"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL=$((PASS + FAIL))
echo ""
echo "test-pr-number-extraction.sh: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
