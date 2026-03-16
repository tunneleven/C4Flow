#!/usr/bin/env bash
# run-hooks-tests.sh
# Suite runner: executes all hook test scripts and reports results

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
echo " C4Flow Hook Test Suite"
echo "=============================="

run_test_script "$SCRIPT_DIR/test-hook-files.sh"
run_test_script "$SCRIPT_DIR/test-hook-settings.sh"
run_test_script "$SCRIPT_DIR/test-hook-bd-close.sh"
run_test_script "$SCRIPT_DIR/test-hook-stop.sh"
run_test_script "$SCRIPT_DIR/test-hook-taskcompleted.sh"

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
