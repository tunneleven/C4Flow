#!/usr/bin/env bash
# test-hook-bd-close.sh
# Tests for HOOK-01: PreToolUse bd-close-gate hook
# Tests mock stdin JSON piped to hook script, checks exit code and stdout

set -uo pipefail

HOOK_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../hooks" && pwd)/bd-close-gate.sh"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; ((PASS++)); }
fail() { echo "  FAIL: $1"; ((FAIL++)); }

assert_exit_zero() {
  local label="$1" actual_exit="$2"
  if [ "$actual_exit" -eq 0 ]; then
    pass "$label (exit 0)"
  else
    fail "$label (expected exit 0, got $actual_exit)"
  fi
}

assert_stdout_contains() {
  local label="$1" output="$2" expected="$3"
  if echo "$output" | grep -q "$expected"; then
    pass "$label (stdout contains '$expected')"
  else
    fail "$label (stdout missing '$expected')"
  fi
}

assert_stdout_empty() {
  local label="$1" output="$2"
  if [ -z "$output" ]; then
    pass "$label (stdout empty — allow)"
  else
    fail "$label (expected empty stdout, got: $output)"
  fi
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Create beads project marker
touch "$TMPDIR/.bd"

# Fixture: quality-gate-status.json with overall_pass=false
cat > "$TMPDIR/quality-gate-status.json" <<'EOF'
{
  "schema_version": "1",
  "generated_at": "2026-03-16T10:30:00Z",
  "expires_at": "2026-03-16T11:30:00Z",
  "gate_id": "bd-test-001",
  "overall_pass": false,
  "checks": {
    "codex_review": {
      "pass": false,
      "ran_at": "2026-03-16T10:28:00Z",
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

echo "--- test-hook-bd-close.sh ---"

# ---------------------------------------------------------------------------
# Test 1: Deny bd close when gates not passed
# ---------------------------------------------------------------------------
OUTPUT=$(cd "$TMPDIR" && CLAUDE_PROJECT_DIR="$TMPDIR" \
  echo '{"tool_name":"Bash","tool_input":{"command":"bd close task-001 --reason done"}}' | \
  bash "$HOOK_SCRIPT" 2>/dev/null)
EXIT_CODE=$?

assert_exit_zero "Test 1: deny bd close (exit code)" "$EXIT_CODE"
assert_stdout_contains "Test 1: deny bd close (permissionDecision)" "$OUTPUT" '"permissionDecision"'
assert_stdout_contains "Test 1: deny bd close (deny)" "$OUTPUT" '"deny"'

# ---------------------------------------------------------------------------
# Test 2: Allow bd close when gates passed
# ---------------------------------------------------------------------------
cat > "$TMPDIR/quality-gate-status.json" <<'EOF'
{
  "schema_version": "1",
  "generated_at": "2026-03-16T10:30:00Z",
  "expires_at": "2026-03-16T11:30:00Z",
  "gate_id": "bd-test-001",
  "overall_pass": true,
  "checks": {
    "codex_review": { "pass": true, "ran_at": "2026-03-16T10:28:00Z", "critical_count": 0, "high_count": 0, "medium_count": 0, "low_count": 0, "findings": [], "summary": "No issues" },
    "bd_preflight": { "pass": true, "ran_at": "2026-03-16T10:29:00Z", "issues": [] }
  }
}
EOF

OUTPUT=$(cd "$TMPDIR" && CLAUDE_PROJECT_DIR="$TMPDIR" \
  echo '{"tool_name":"Bash","tool_input":{"command":"bd close task-001 --reason done"}}' | \
  bash "$HOOK_SCRIPT" 2>/dev/null)
EXIT_CODE=$?

assert_exit_zero "Test 2: allow bd close (gates passed)" "$EXIT_CODE"
assert_stdout_empty "Test 2: allow bd close (no denial JSON)" "$OUTPUT"

# ---------------------------------------------------------------------------
# Test 3: Allow bd close --force regardless of gate state
# ---------------------------------------------------------------------------
cat > "$TMPDIR/quality-gate-status.json" <<'EOF'
{
  "schema_version": "1",
  "generated_at": "2026-03-16T10:30:00Z",
  "expires_at": "2026-03-16T11:30:00Z",
  "gate_id": "bd-test-001",
  "overall_pass": false,
  "checks": {
    "codex_review": { "pass": false, "ran_at": "2026-03-16T10:28:00Z", "critical_count": 1, "high_count": 0, "medium_count": 0, "low_count": 0, "findings": [], "summary": "1 critical issue" },
    "bd_preflight": { "pass": null, "ran_at": null, "issues": [] }
  }
}
EOF

OUTPUT=$(cd "$TMPDIR" && CLAUDE_PROJECT_DIR="$TMPDIR" \
  echo '{"tool_name":"Bash","tool_input":{"command":"bd close task-001 --force --reason skip"}}' | \
  bash "$HOOK_SCRIPT" 2>/dev/null)
EXIT_CODE=$?

assert_exit_zero "Test 3: allow --force" "$EXIT_CODE"
assert_stdout_empty "Test 3: allow --force (no denial JSON)" "$OUTPUT"

# ---------------------------------------------------------------------------
# Test 4: Allow non-bd-close commands
# ---------------------------------------------------------------------------
OUTPUT=$(cd "$TMPDIR" && CLAUDE_PROJECT_DIR="$TMPDIR" \
  echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' | \
  bash "$HOOK_SCRIPT" 2>/dev/null)
EXIT_CODE=$?

assert_exit_zero "Test 4: allow non-bd-close command" "$EXIT_CODE"
assert_stdout_empty "Test 4: allow non-bd-close (no denial JSON)" "$OUTPUT"

# ---------------------------------------------------------------------------
# Test 5: Deny when gate status file missing
# ---------------------------------------------------------------------------
rm "$TMPDIR/quality-gate-status.json"

OUTPUT=$(cd "$TMPDIR" && CLAUDE_PROJECT_DIR="$TMPDIR" \
  echo '{"tool_name":"Bash","tool_input":{"command":"bd close task-001 --reason done"}}' | \
  bash "$HOOK_SCRIPT" 2>/dev/null)
EXIT_CODE=$?

assert_exit_zero "Test 5: deny on missing file (exit code)" "$EXIT_CODE"
assert_stdout_contains "Test 5: deny on missing file (deny)" "$OUTPUT" '"deny"'

# ---------------------------------------------------------------------------
# Test 6: Skip on non-beads project (no .bd file)
# ---------------------------------------------------------------------------
rm "$TMPDIR/.bd"

OUTPUT=$(cd "$TMPDIR" && CLAUDE_PROJECT_DIR="$TMPDIR" \
  echo '{"tool_name":"Bash","tool_input":{"command":"bd close task-001 --reason done"}}' | \
  bash "$HOOK_SCRIPT" 2>/dev/null)
EXIT_CODE=$?

assert_exit_zero "Test 6: skip non-beads project" "$EXIT_CODE"
assert_stdout_empty "Test 6: skip non-beads (no output)" "$OUTPUT"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL=$((PASS + FAIL))
echo ""
echo "test-hook-bd-close.sh: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
