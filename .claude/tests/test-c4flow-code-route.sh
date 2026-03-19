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

if grep -q "### If state is CODE_LOOP" "$TARGET"; then
  pass "CODE_LOOP branch heading exists in orchestrator"
else
  fail "missing CODE_LOOP branch heading in orchestrator"
fi

if grep -q "c4flow:code" "$TARGET"; then
  pass "orchestrator references c4flow:code skill"
else
  fail "orchestrator missing c4flow:code skill reference"
fi

if grep -qiE "CODE_LOOP.*DEPLOY|advance.*DEPLOY" "$TARGET"; then
  pass "CODE_LOOP advances to DEPLOY (not TEST)"
else
  fail "CODE_LOOP missing DEPLOY transition"
fi

if grep -qiE "legacy.*migration|CODE.*CODE_LOOP" "$TARGET"; then
  pass "orchestrator handles legacy CODE → CODE_LOOP migration"
else
  fail "orchestrator missing legacy CODE state migration"
fi

if grep -qiE "serial.*task.*loop|one task at a time|serial loop" "$TARGET"; then
  pass "orchestrator documents serial task loop"
else
  fail "orchestrator missing serial task loop description"
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
