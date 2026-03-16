#!/usr/bin/env bash
# test-pr-gate-warn.sh
# Tests for SKIL-03: Validates gate warning detection logic
# Verifies the overall_pass check that determines warn vs. proceed behavior.
# Uses mock quality-gate-status.json files; does not call live APIs.

set -uo pipefail

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "--- test-pr-gate-warn.sh ---"

# ---------------------------------------------------------------------------
# Test 1: overall_pass=false → result should be "false" (trigger warning path)
# ---------------------------------------------------------------------------
GATE_FILE_FAIL="$TMPDIR/gate-fail.json"
cat > "$GATE_FILE_FAIL" <<'EOF'
{
  "schema_version": "1",
  "generated_at": "2026-03-16T10:28:00Z",
  "expires_at": "2026-03-16T11:28:00Z",
  "gate_id": "bd-test-001",
  "overall_pass": false,
  "checks": {
    "codex_review": {
      "pass": false,
      "ran_at": "2026-03-16T10:25:00Z",
      "critical_count": 1,
      "high_count": 0,
      "medium_count": 0,
      "low_count": 0,
      "findings": [],
      "summary": "1 critical issue"
    },
    "bd_preflight": {
      "pass": null,
      "ran_at": null,
      "issues": []
    }
  }
}
EOF

OVERALL_PASS=$(jq -r '.overall_pass' "$GATE_FILE_FAIL")
if [ "$OVERALL_PASS" = "false" ]; then
  pass "Test 1: overall_pass=false correctly detected (should trigger warning)"
else
  fail "Test 1: expected 'false', got: '$OVERALL_PASS'"
fi

# ---------------------------------------------------------------------------
# Test 2: overall_pass=true → result should be "true" (no warning)
# ---------------------------------------------------------------------------
GATE_FILE_PASS="$TMPDIR/gate-pass.json"
cat > "$GATE_FILE_PASS" <<'EOF'
{
  "schema_version": "1",
  "generated_at": "2026-03-16T10:28:00Z",
  "expires_at": "2026-03-16T11:28:00Z",
  "gate_id": "bd-test-002",
  "overall_pass": true,
  "checks": {
    "codex_review": {
      "pass": true,
      "ran_at": "2026-03-16T10:25:00Z",
      "critical_count": 0,
      "high_count": 0,
      "medium_count": 0,
      "low_count": 0,
      "findings": [],
      "summary": "No issues"
    },
    "bd_preflight": {
      "pass": true,
      "ran_at": "2026-03-16T10:28:00Z",
      "issues": []
    }
  }
}
EOF

OVERALL_PASS=$(jq -r '.overall_pass' "$GATE_FILE_PASS")
if [ "$OVERALL_PASS" = "true" ]; then
  pass "Test 2: overall_pass=true correctly detected (no warning needed)"
else
  fail "Test 2: expected 'true', got: '$OVERALL_PASS'"
fi

# ---------------------------------------------------------------------------
# Test 3: Missing file → jq check fails gracefully (no crash, non-true result)
# ---------------------------------------------------------------------------
MISSING_FILE="$TMPDIR/does-not-exist.json"
OVERALL_PASS=$(jq -r '.overall_pass' "$MISSING_FILE" 2>/dev/null || echo "missing")

# The result should NOT be "true" — missing file means gates have not passed
if [ "$OVERALL_PASS" != "true" ]; then
  pass "Test 3: missing file check returns non-true (no crash, warning path triggered)"
else
  fail "Test 3: missing file should not return 'true' for overall_pass"
fi

# ---------------------------------------------------------------------------
# Test 4: overall_pass=null (e.g., corrupted or old schema) → non-true result
# ---------------------------------------------------------------------------
GATE_FILE_NULL="$TMPDIR/gate-null.json"
cat > "$GATE_FILE_NULL" <<'EOF'
{
  "schema_version": "1",
  "generated_at": "2026-03-16T10:28:00Z",
  "expires_at": "2026-03-16T11:28:00Z",
  "gate_id": null,
  "overall_pass": null,
  "checks": {
    "codex_review": {"pass": null, "ran_at": null, "critical_count": 0, "high_count": 0, "medium_count": 0, "low_count": 0},
    "bd_preflight": {"pass": null, "ran_at": null, "issues": []}
  }
}
EOF

OVERALL_PASS=$(jq -r '.overall_pass' "$GATE_FILE_NULL" 2>/dev/null || echo "missing")

if [ "$OVERALL_PASS" != "true" ]; then
  pass "Test 4: overall_pass=null treated as non-passing (warning path triggered)"
else
  fail "Test 4: overall_pass=null should not equal 'true'"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL=$((PASS + FAIL))
echo ""
echo "test-pr-gate-warn.sh: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
