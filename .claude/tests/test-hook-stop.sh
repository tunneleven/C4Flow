#!/usr/bin/env bash
# test-hook-stop.sh
# Tests for HOOK-02: Stop check-open-gates hook
# Mocks the `bd` command to avoid needing a real beads DB

set -uo pipefail

HOOK_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../hooks" && pwd)/check-open-gates.sh"
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

assert_stderr_clean() {
  local label="$1" err="$2"
  # Only fail on jq-specific errors (jq: error / parse error)
  if echo "$err" | grep -qE '^jq: (error|parse error)'; then
    fail "$label (jq error in stderr: $err)"
  else
    pass "$label (no jq errors in stderr)"
  fi
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
  cd "$TMPDIR" && PATH="$MOCK_BIN:$PATH" bash "$HOOK_SCRIPT" 2>/tmp/test-stop-stderr
}

echo "--- test-hook-stop.sh ---"

# ---------------------------------------------------------------------------
# Test 1: Block when c4flow gates open
# ---------------------------------------------------------------------------
write_mock_bd '[{"id":"bd-001","title":"Quality gate","labels":["c4flow-quality-gate"]}]'

OUTPUT=$(run_hook 2>/dev/null)
EXIT_CODE=$?

assert_exit_zero "Test 1: block on labeled gate (exit code)" "$EXIT_CODE"
assert_stdout_contains "Test 1: block on labeled gate (block)" "$OUTPUT" '"block"'
assert_stdout_contains "Test 1: block on labeled gate (gate id)" "$OUTPUT" 'bd-001'

# ---------------------------------------------------------------------------
# Test 2: Allow when no c4flow labeled gates
# ---------------------------------------------------------------------------
write_mock_bd '[{"id":"bd-002","title":"Other gate","labels":["unrelated"]}]'

OUTPUT=$(run_hook 2>/dev/null)
EXIT_CODE=$?

assert_exit_zero "Test 2: allow non-c4flow gates" "$EXIT_CODE"
assert_stdout_empty "Test 2: allow non-c4flow gates (no block JSON)" "$OUTPUT"

# ---------------------------------------------------------------------------
# Test 3: Allow when gate list is empty
# ---------------------------------------------------------------------------
write_mock_bd '[]'

OUTPUT=$(run_hook 2>/dev/null)
EXIT_CODE=$?

assert_exit_zero "Test 3: allow empty gate list" "$EXIT_CODE"
assert_stdout_empty "Test 3: allow empty gate list (no output)" "$OUTPUT"

# ---------------------------------------------------------------------------
# Test 4: Handle null labels gracefully (no jq errors)
# ---------------------------------------------------------------------------
write_mock_bd '[{"id":"bd-003","title":"No labels gate"}]'

OUTPUT=$(run_hook 2>/tmp/test-stop-stderr)
EXIT_CODE=$?
STDERR_CONTENT=$(cat /tmp/test-stop-stderr 2>/dev/null || echo "")

assert_exit_zero "Test 4: null labels graceful (exit code)" "$EXIT_CODE"
assert_stdout_empty "Test 4: null labels graceful (allow — no labeled gates)" "$OUTPUT"
assert_stderr_clean "Test 4: null labels graceful (no jq errors)" "$STDERR_CONTENT"

# ---------------------------------------------------------------------------
# Test 5: Skip on non-beads project
# ---------------------------------------------------------------------------
rm "$TMPDIR/.bd"

OUTPUT=$(run_hook 2>/dev/null)
EXIT_CODE=$?

assert_exit_zero "Test 5: skip non-beads project" "$EXIT_CODE"
assert_stdout_empty "Test 5: skip non-beads (no output)" "$OUTPUT"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL=$((PASS + FAIL))
echo ""
echo "test-hook-stop.sh: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
