#!/usr/bin/env bash
# run-code-skill-tests.sh
# Suite runner for CODE workflow regression checks

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

run_test_script() {
  local script="$1"
  echo ""
  if bash "$script"; then
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

echo "=============================="
echo " C4Flow CODE Skill Test Suite"
echo "=============================="

run_test_script "$SCRIPT_DIR/test-code-skill-file.sh"
run_test_script "$SCRIPT_DIR/test-c4flow-code-route.sh"
run_test_script "$SCRIPT_DIR/test-code-state-reference.sh"
run_test_script "$SCRIPT_DIR/test-code-fallbacks.sh"
run_test_script "$SCRIPT_DIR/test-code-actor-resolution.sh"
run_test_script "$SCRIPT_DIR/test-code-branch-strategy.sh"
run_test_script "$SCRIPT_DIR/test-code-tdd-cycle.sh"
run_test_script "$SCRIPT_DIR/test-code-verify-review.sh"
run_test_script "$SCRIPT_DIR/test-code-task-loop-state.sh"

TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo ""
echo "=============================="
echo " Suite Results: $PASS_COUNT/$TOTAL scripts passed"
echo "=============================="

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo " $FAIL_COUNT script(s) FAILED"
  exit 1
fi

echo " All tests passed."
exit 0
