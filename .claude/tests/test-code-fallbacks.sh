#!/usr/bin/env bash
# test-code-fallbacks.sh
# Validates fallback and recovery guidance in the c4flow:code skill

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="$ROOT_DIR/skills/code/SKILL.md"
PASS=0
FAIL=0

pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  FAIL: $1"
  FAIL=$((FAIL + 1))
}

echo "--- test-code-fallbacks.sh ---"

if grep -q 'bd dolt push' "$TARGET"; then
  pass "skill includes Beads sync step"
else
  fail "skill missing Beads sync step"
fi

if grep -qiE "Resume Logic|resume.*subState|taskLoop.*non-null" "$TARGET"; then
  pass "skill documents resume logic from saved subState"
else
  fail "skill missing resume logic"
fi

if grep -qiE "no.*task.*ready|READY_COUNT.*0|No unblocked tasks" "$TARGET"; then
  pass "skill handles empty task list gracefully"
else
  fail "skill missing empty task list handling"
fi

if grep -qiE "claim.*fail|already claimed|claim.*conflict" "$TARGET"; then
  pass "skill handles claim conflict (task already taken)"
else
  fail "skill missing claim conflict handling"
fi

if grep -qiE "pull.*fail|BLOCKED.*git pull|git pull.*error" "$TARGET"; then
  pass "skill handles git pull failure as BLOCKED"
else
  fail "skill missing git pull failure handling"
fi

if grep -qiE "bd ready.*empty|REMAINING.*0|no more task|tasks.*done" "$TARGET"; then
  pass "skill handles completion: no more tasks → advance to DEPLOY"
else
  fail "skill missing completion/advance-to-DEPLOY logic"
fi

TOTAL=$((PASS + FAIL))
echo ""
echo "test-code-fallbacks.sh: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
