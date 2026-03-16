#!/usr/bin/env bash
# test-c4flow-code-route.sh
# Contract checks for the CODE branch in the top-level c4flow workflow

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="$ROOT_DIR/skills/c4flow/SKILL.md"
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

echo "--- test-c4flow-code-route.sh ---"

CODE_BRANCH=$(awk '
  /^### If state is CODE$/ { in_section=1; next }
  /^### If state is any other/ { in_section=0 }
  in_section { print }
' "$TARGET")

if grep -q "### If state is CODE" "$TARGET"; then
  pass "CODE branch heading exists"
else
  fail "missing CODE branch heading"
fi

if grep -q "Load the c4flow:code skill" "$TARGET"; then
  pass "CODE branch loads c4flow:code"
else
  fail "missing Load the c4flow:code skill guidance"
fi

if printf '%s\n' "$CODE_BRANCH" | grep -q "implementationPlan"; then
  pass "CODE branch references implementationPlan"
else
  fail "CODE branch missing implementationPlan reference"
fi

if printf '%s\n' "$CODE_BRANCH" | grep -q "TEST"; then
  pass "CODE branch advances to TEST"
else
  fail "CODE branch missing TEST transition"
fi

if printf '%s\n' "$CODE_BRANCH" | grep -q "taskSource"; then
  pass "CODE branch references taskSource"
else
  fail "CODE branch missing taskSource reference"
fi

if grep -q "unimplemented skills: DESIGN, CODE, REVIEW through DEPLOY" "$TARGET"; then
  fail "CODE still listed in unimplemented-state fallback"
else
  pass "CODE removed from unimplemented-state fallback"
fi

TOTAL=$((PASS + FAIL))
echo ""
echo "test-c4flow-code-route.sh: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
