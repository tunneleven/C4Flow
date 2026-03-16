#!/usr/bin/env bash
# test-hook-settings.sh
# Tests for INFR-03: Verify settings.json has valid hooks configuration

set -uo pipefail

SETTINGS_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/.claude/settings.json"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; ((PASS++)); }
fail() { echo "  FAIL: $1"; ((FAIL++)); }

echo "--- test-hook-settings.sh ---"

# Test 1: settings.json is valid JSON
if jq . "$SETTINGS_FILE" >/dev/null 2>&1; then
  pass "settings.json is valid JSON"
else
  fail "settings.json is not valid JSON"
  # Cannot continue if JSON is invalid
  echo ""
  echo "test-hook-settings.sh: $PASS/$((PASS + FAIL)) passed"
  exit 1
fi

# Test 2: hooks.PreToolUse exists with Bash matcher
PRETOOLUSE_MATCHER=$(jq -r '.hooks.PreToolUse[0].matcher // ""' "$SETTINGS_FILE" 2>/dev/null)
if [ "$PRETOOLUSE_MATCHER" = "Bash" ]; then
  pass "hooks.PreToolUse[0] has matcher 'Bash'"
else
  fail "hooks.PreToolUse[0] missing matcher 'Bash' (got: $PRETOOLUSE_MATCHER)"
fi

# Test 3: hooks.Stop exists
STOP_COUNT=$(jq '.hooks.Stop | length' "$SETTINGS_FILE" 2>/dev/null || echo 0)
if [ "${STOP_COUNT:-0}" -gt 0 ]; then
  pass "hooks.Stop exists and has entries"
else
  fail "hooks.Stop missing or empty"
fi

# Test 4: hooks.TaskCompleted exists
TASKCOMPLETED_COUNT=$(jq '.hooks.TaskCompleted | length' "$SETTINGS_FILE" 2>/dev/null || echo 0)
if [ "${TASKCOMPLETED_COUNT:-0}" -gt 0 ]; then
  pass "hooks.TaskCompleted exists and has entries"
else
  fail "hooks.TaskCompleted missing or empty"
fi

# Test 5: enabledPlugins still exists (merge did not clobber)
ENABLED_PLUGINS=$(jq '.enabledPlugins // null' "$SETTINGS_FILE" 2>/dev/null)
if [ "$ENABLED_PLUGINS" != "null" ] && [ -n "$ENABLED_PLUGINS" ]; then
  pass "enabledPlugins preserved (not clobbered by hooks merge)"
else
  fail "enabledPlugins missing — hooks merge may have clobbered existing config"
fi

# Test 6: PreToolUse hook command path ends with bd-close-gate.sh
BD_CLOSE_CMD=$(jq -r '.hooks.PreToolUse[0].hooks[0].command // ""' "$SETTINGS_FILE" 2>/dev/null)
if echo "$BD_CLOSE_CMD" | grep -q 'bd-close-gate\.sh$'; then
  pass "PreToolUse hook command ends with bd-close-gate.sh"
else
  fail "PreToolUse hook command unexpected: $BD_CLOSE_CMD"
fi

# Test 7: Stop hook command path ends with check-open-gates.sh
STOP_CMD=$(jq -r '.hooks.Stop[0].hooks[0].command // ""' "$SETTINGS_FILE" 2>/dev/null)
if echo "$STOP_CMD" | grep -q 'check-open-gates\.sh$'; then
  pass "Stop hook command ends with check-open-gates.sh"
else
  fail "Stop hook command unexpected: $STOP_CMD"
fi

# Test 8: TaskCompleted hook command path ends with task-complete-gate.sh
TASKCOMPLETED_CMD=$(jq -r '.hooks.TaskCompleted[0].hooks[0].command // ""' "$SETTINGS_FILE" 2>/dev/null)
if echo "$TASKCOMPLETED_CMD" | grep -q 'task-complete-gate\.sh$'; then
  pass "TaskCompleted hook command ends with task-complete-gate.sh"
else
  fail "TaskCompleted hook command unexpected: $TASKCOMPLETED_CMD"
fi

TOTAL=$((PASS + FAIL))
echo ""
echo "test-hook-settings.sh: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
