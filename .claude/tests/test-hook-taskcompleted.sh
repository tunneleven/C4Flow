#!/usr/bin/env bash
# test-hook-taskcompleted.sh
# Tests for HOOK-03: TaskCompleted task-complete-gate hook

set -uo pipefail

HOOK_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../hooks" && pwd)/task-complete-gate.sh"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; ((PASS++)); }
fail() { echo "  FAIL: $1"; ((FAIL++)); }

assert_exit_code() {
  local label="$1" actual_exit="$2" expected_exit="$3"
  if [ "$actual_exit" -eq "$expected_exit" ]; then
    pass "$label (exit $expected_exit)"
  else
    fail "$label (expected exit $expected_exit, got $actual_exit)"
  fi
}

assert_stderr_contains() {
  local label="$1" err="$2" expected="$3"
  if echo "$err" | grep -qi "$expected"; then
    pass "$label (stderr contains '$expected')"
  else
    fail "$label (stderr missing '$expected')"
  fi
}

assert_exit_zero() {
  local label="$1" actual_exit="$2"
  assert_exit_code "$label" "$actual_exit" 0
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Create beads project marker
touch "$TMPDIR/.bd"

# Bin dir for mock bd script
MOCK_BIN="$TMPDIR/bin"
mkdir -p "$MOCK_BIN"

write_mock_bd() {
  local output="$1"
  cat > "$MOCK_BIN/bd" <<EOF
#!/usr/bin/env bash
echo '$output'
EOF
  chmod +x "$MOCK_BIN/bd"
}

run_hook() {
  local stdin_json="$1"
  (
    export CLAUDE_PROJECT_DIR="$TMPDIR"
    export PATH="$MOCK_BIN:$PATH"
    cd "$TMPDIR"
    echo "$stdin_json" | bash "$HOOK_SCRIPT"
  ) 2>/tmp/test-task-stderr
}

# Default mock: no active gates
write_mock_bd '[]'

# Fixture: gate status with overall_pass=false
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

echo "--- test-hook-taskcompleted.sh ---"

# ---------------------------------------------------------------------------
# Test 1: Block when gates not passed (overall_pass=false)
# ---------------------------------------------------------------------------
run_hook '{"task_subject":"Implement auth"}'
EXIT_CODE=$?
STDERR=$(cat /tmp/test-task-stderr 2>/dev/null || echo "")

assert_exit_code "Test 1: block on open gates (exit code 2)" "$EXIT_CODE" 2
assert_stderr_contains "Test 1: block on open gates (stderr message)" "$STDERR" "quality gates not passed"

# ---------------------------------------------------------------------------
# Test 2: Allow when gates passed (overall_pass=true)
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

run_hook '{"task_subject":"Implement auth"}'
EXIT_CODE=$?

assert_exit_zero "Test 2: allow when gates passed" "$EXIT_CODE"

# ---------------------------------------------------------------------------
# Test 3: Block when file missing but gates exist
# ---------------------------------------------------------------------------
rm "$TMPDIR/quality-gate-status.json"
write_mock_bd '[{"id":"bd-004","title":"Active gate","labels":["c4flow-quality-gate"]}]'

run_hook '{"task_subject":"Implement auth"}'
EXIT_CODE=$?
STDERR=$(cat /tmp/test-task-stderr 2>/dev/null || echo "")

assert_exit_code "Test 3: block missing file + active gates (exit code 2)" "$EXIT_CODE" 2

# ---------------------------------------------------------------------------
# Test 4: Allow when file missing and no active gates
# ---------------------------------------------------------------------------
write_mock_bd '[]'

run_hook '{"task_subject":"Implement auth"}'
EXIT_CODE=$?

assert_exit_zero "Test 4: allow missing file + no active gates" "$EXIT_CODE"

# ---------------------------------------------------------------------------
# Test 5: Skip on non-beads project
# ---------------------------------------------------------------------------
rm "$TMPDIR/.bd"

run_hook '{"task_subject":"Implement auth"}'
EXIT_CODE=$?

assert_exit_zero "Test 5: skip non-beads project" "$EXIT_CODE"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL=$((PASS + FAIL))
echo ""
echo "test-hook-taskcompleted.sh: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
