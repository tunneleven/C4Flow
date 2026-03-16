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

if grep -q 'using-git-worktrees' "$TARGET"; then
  pass "skill requires using-git-worktrees"
else
  fail "skill missing using-git-worktrees"
fi

if grep -q '/c4flow:beads' "$TARGET"; then
  pass "skill includes /c4flow:beads recovery command"
else
  fail "skill missing /c4flow:beads recovery command"
fi

if grep -q '\$gsd-plan-phase <phase>' "$TARGET"; then
  pass "skill includes gsd-plan-phase recovery command"
else
  fail "skill missing gsd-plan-phase recovery command"
fi

if grep -qi 'manual fallback' "$TARGET" || grep -qi 'execute manually from the approved plan' "$TARGET"; then
  pass "skill documents manual fallback guidance"
else
  fail "skill missing manual fallback guidance"
fi

if grep -q 'Direct invocation is allowed' "$TARGET"; then
  pass "skill documents direct invocation recovery mode"
else
  fail "skill missing direct invocation recovery guidance"
fi

TOTAL=$((PASS + FAIL))
echo ""
echo "test-code-fallbacks.sh: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
