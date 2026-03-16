#!/usr/bin/env bash
# test-pr-body-construction.sh
# Tests for SKIL-03: Validates PR body construction from quality-gate-status.json
# Uses mock gate status files in a temp dir; does not call live GitHub API.

set -uo pipefail

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "--- test-pr-body-construction.sh ---"

# Helper: extract CODEX_PASS from a gate status file using the SKILL.md jq pattern
extract_codex_pass() {
  local gate_file="$1"
  jq -r 'if .checks.codex_review.pass == true then "PASS" elif .checks.codex_review.pass == false then "FAIL" else "NOT RUN" end' \
    "$gate_file" 2>/dev/null || echo "NO STATUS FILE"
}

# Helper: extract BD_PASS from a gate status file
extract_bd_pass() {
  local gate_file="$1"
  jq -r 'if .checks.bd_preflight.pass == true then "PASS" elif .checks.bd_preflight.pass == false then "FAIL" else "NOT RUN" end' \
    "$gate_file" 2>/dev/null || echo "NO STATUS FILE"
}

# Helper: extract OVERALL_STATUS from a gate status file
extract_overall_status() {
  local gate_file="$1"
  jq -r 'if .overall_pass then "Ready for PR" else "PR created before all gates passed" end' \
    "$gate_file" 2>/dev/null || echo "No gate status file"
}

# ---------------------------------------------------------------------------
# Test 1: Mock with codex pass=true, bd pass=true — all fields should be PASS
# ---------------------------------------------------------------------------
GATE_FILE_1="$TMPDIR/gate-pass.json"
cat > "$GATE_FILE_1" <<'EOF'
{
  "schema_version": "1",
  "generated_at": "2026-03-16T10:28:00Z",
  "expires_at": "2026-03-16T11:28:00Z",
  "gate_id": "bd-test-001",
  "overall_pass": true,
  "checks": {
    "codex_review": {
      "pass": true,
      "ran_at": "2026-03-16T10:25:00Z",
      "critical_count": 0,
      "high_count": 0,
      "medium_count": 2,
      "low_count": 1,
      "findings": [],
      "summary": "No blocking issues"
    },
    "bd_preflight": {
      "pass": true,
      "ran_at": "2026-03-16T10:28:00Z",
      "issues": []
    }
  }
}
EOF

CODEX_PASS=$(extract_codex_pass "$GATE_FILE_1")
BD_PASS=$(extract_bd_pass "$GATE_FILE_1")
OVERALL_STATUS=$(extract_overall_status "$GATE_FILE_1")

if echo "$CODEX_PASS" | grep -q "PASS"; then
  pass "Test 1: CODEX_PASS contains 'PASS' when codex.pass=true"
else
  fail "Test 1: CODEX_PASS expected 'PASS', got: '$CODEX_PASS'"
fi

if echo "$BD_PASS" | grep -q "PASS"; then
  pass "Test 1: BD_PASS contains 'PASS' when bd_preflight.pass=true"
else
  fail "Test 1: BD_PASS expected 'PASS', got: '$BD_PASS'"
fi

if echo "$OVERALL_STATUS" | grep -q "Ready for PR"; then
  pass "Test 1: OVERALL_STATUS contains 'Ready for PR' when overall_pass=true"
else
  fail "Test 1: OVERALL_STATUS expected 'Ready for PR', got: '$OVERALL_STATUS'"
fi

# ---------------------------------------------------------------------------
# Test 2: Mock with codex pass=false — CODEX_PASS should contain "FAIL"
# ---------------------------------------------------------------------------
GATE_FILE_2="$TMPDIR/gate-codex-fail.json"
cat > "$GATE_FILE_2" <<'EOF'
{
  "schema_version": "1",
  "generated_at": "2026-03-16T10:28:00Z",
  "expires_at": "2026-03-16T11:28:00Z",
  "gate_id": "bd-test-002",
  "overall_pass": false,
  "checks": {
    "codex_review": {
      "pass": false,
      "ran_at": "2026-03-16T10:25:00Z",
      "critical_count": 2,
      "high_count": 1,
      "medium_count": 0,
      "low_count": 0,
      "findings": [],
      "summary": "2 critical issues found"
    },
    "bd_preflight": {
      "pass": true,
      "ran_at": "2026-03-16T10:28:00Z",
      "issues": []
    }
  }
}
EOF

CODEX_PASS=$(extract_codex_pass "$GATE_FILE_2")

if echo "$CODEX_PASS" | grep -q "FAIL"; then
  pass "Test 2: CODEX_PASS contains 'FAIL' when codex.pass=false"
else
  fail "Test 2: CODEX_PASS expected 'FAIL', got: '$CODEX_PASS'"
fi

# ---------------------------------------------------------------------------
# Test 3: No quality-gate-status.json — fallback values used
# ---------------------------------------------------------------------------
MISSING_FILE="$TMPDIR/does-not-exist.json"

CODEX_PASS=$(jq -r 'if .checks.codex_review.pass == true then "PASS" elif .checks.codex_review.pass == false then "FAIL" else "NOT RUN" end' \
  "$MISSING_FILE" 2>/dev/null || echo "NO STATUS FILE")

if echo "$CODEX_PASS" | grep -q "NO STATUS FILE"; then
  pass "Test 3: missing gate file produces 'NO STATUS FILE' fallback"
else
  fail "Test 3: expected 'NO STATUS FILE' fallback, got: '$CODEX_PASS'"
fi

# ---------------------------------------------------------------------------
# Test 4: Mock with bd_preflight pass=null (not run) — BD_PASS should be "NOT RUN"
# ---------------------------------------------------------------------------
GATE_FILE_4="$TMPDIR/gate-bd-null.json"
cat > "$GATE_FILE_4" <<'EOF'
{
  "schema_version": "1",
  "generated_at": "2026-03-16T10:28:00Z",
  "expires_at": "2026-03-16T11:28:00Z",
  "gate_id": null,
  "overall_pass": false,
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
      "pass": null,
      "ran_at": null,
      "issues": []
    }
  }
}
EOF

BD_PASS=$(extract_bd_pass "$GATE_FILE_4")

if echo "$BD_PASS" | grep -q "NOT RUN"; then
  pass "Test 4: BD_PASS contains 'NOT RUN' when bd_preflight.pass=null"
else
  fail "Test 4: BD_PASS expected 'NOT RUN', got: '$BD_PASS'"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL=$((PASS + FAIL))
echo ""
echo "test-pr-body-construction.sh: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
