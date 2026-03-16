#!/usr/bin/env bash
# test-pr-state-write.sh
# Tests for SKIL-03: Validates atomic jq merge write of prNumber to .state.json
# Uses a temp dir with a full-schema .state.json; does not touch the real state file.

set -uo pipefail

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "--- test-pr-state-write.sh ---"

# ---------------------------------------------------------------------------
# Setup: Create a full-schema .state.json in temp dir
# ---------------------------------------------------------------------------
STATE_FILE="$TMPDIR/.state.json"
cat > "$STATE_FILE" <<'EOF'
{
  "version": 1,
  "currentState": "VERIFY",
  "feature": {"name": "test-feat", "id": "bd-task-42"},
  "startedAt": "2026-03-16T10:00:00Z",
  "completedStates": ["REVIEW", "VERIFY"],
  "failedAttempts": 0,
  "beadsEpic": "epic-001",
  "doltRemote": "origin",
  "worktree": null,
  "prNumber": null,
  "lastError": null
}
EOF

# ---------------------------------------------------------------------------
# Test 1: jq merge correctly writes prNumber and advances currentState
# ---------------------------------------------------------------------------
jq --argjson num 42 \
  '.prNumber = $num | .currentState = "PR_REVIEW_LOOP" | .completedStates += ["PR"] | .failedAttempts = 0 | .lastError = null' \
  "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

PR_NUMBER_WRITTEN=$(jq -r '.prNumber' "$STATE_FILE")
if [ "$PR_NUMBER_WRITTEN" = "42" ]; then
  pass "Test 1: prNumber written as 42"
else
  fail "Test 1: prNumber expected 42, got: '$PR_NUMBER_WRITTEN'"
fi

# ---------------------------------------------------------------------------
# Test 2: currentState advanced to PR_REVIEW_LOOP
# ---------------------------------------------------------------------------
CURRENT_STATE=$(jq -r '.currentState' "$STATE_FILE")
if [ "$CURRENT_STATE" = "PR_REVIEW_LOOP" ]; then
  pass "Test 2: currentState advanced to PR_REVIEW_LOOP"
else
  fail "Test 2: currentState expected 'PR_REVIEW_LOOP', got: '$CURRENT_STATE'"
fi

# ---------------------------------------------------------------------------
# Test 3: "PR" added to completedStates
# ---------------------------------------------------------------------------
HAS_PR=$(jq -r '.completedStates | contains(["PR"])' "$STATE_FILE")
if [ "$HAS_PR" = "true" ]; then
  pass "Test 3: completedStates contains 'PR'"
else
  fail "Test 3: completedStates does not contain 'PR'"
fi

# ---------------------------------------------------------------------------
# Test 4: Existing fields preserved (merge, not overwrite)
# ---------------------------------------------------------------------------
FEATURE_NAME=$(jq -r '.feature.name' "$STATE_FILE")
if [ "$FEATURE_NAME" = "test-feat" ]; then
  pass "Test 4: feature.name 'test-feat' preserved after merge"
else
  fail "Test 4: feature.name expected 'test-feat', got: '$FEATURE_NAME'"
fi

VERSION=$(jq -r '.version' "$STATE_FILE")
if [ "$VERSION" = "1" ]; then
  pass "Test 4: version=1 preserved after merge"
else
  fail "Test 4: version expected 1, got: '$VERSION'"
fi

# ---------------------------------------------------------------------------
# Test 5: REVIEW and VERIFY still in completedStates (not wiped)
# ---------------------------------------------------------------------------
HAS_REVIEW=$(jq -r '.completedStates | contains(["REVIEW"])' "$STATE_FILE")
HAS_VERIFY=$(jq -r '.completedStates | contains(["VERIFY"])' "$STATE_FILE")
if [ "$HAS_REVIEW" = "true" ] && [ "$HAS_VERIFY" = "true" ]; then
  pass "Test 5: prior completedStates REVIEW and VERIFY preserved"
else
  fail "Test 5: prior completedStates not preserved (HAS_REVIEW=$HAS_REVIEW HAS_VERIFY=$HAS_VERIFY)"
fi

# ---------------------------------------------------------------------------
# Test 6: beadsEpic and doltRemote preserved
# ---------------------------------------------------------------------------
EPIC=$(jq -r '.beadsEpic' "$STATE_FILE")
REMOTE=$(jq -r '.doltRemote' "$STATE_FILE")
if [ "$EPIC" = "epic-001" ] && [ "$REMOTE" = "origin" ]; then
  pass "Test 6: beadsEpic and doltRemote preserved after merge"
else
  fail "Test 6: beadsEpic expected 'epic-001' got '$EPIC'; doltRemote expected 'origin' got '$REMOTE'"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL=$((PASS + FAIL))
echo ""
echo "test-pr-state-write.sh: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
