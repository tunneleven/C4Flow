#!/usr/bin/env bash
# test-hook-files.sh
# Tests for INFR-02: Verify all hook scripts exist and are executable

set -uo pipefail

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../hooks" && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; ((PASS++)); }
fail() { echo "  FAIL: $1"; ((FAIL++)); }

echo "--- test-hook-files.sh ---"

check_hook_file() {
  local name="$1"
  local path="$HOOKS_DIR/$name"

  if [ -f "$path" ]; then
    pass "$name exists"
  else
    fail "$name missing at $path"
    return
  fi

  if [ -x "$path" ]; then
    pass "$name is executable"
  else
    fail "$name is not executable"
  fi

  local shebang
  shebang=$(head -1 "$path")
  if [ "$shebang" = "#!/usr/bin/env bash" ]; then
    pass "$name has correct shebang (#!/usr/bin/env bash)"
  else
    fail "$name has wrong shebang: $shebang"
  fi
}

check_hook_file "bd-close-gate.sh"
check_hook_file "check-open-gates.sh"
check_hook_file "task-complete-gate.sh"

TOTAL=$((PASS + FAIL))
echo ""
echo "test-hook-files.sh: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
