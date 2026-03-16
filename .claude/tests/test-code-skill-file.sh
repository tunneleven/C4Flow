#!/usr/bin/env bash
# test-code-skill-file.sh
# Contract checks for the implemented c4flow:code skill file

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

echo "--- test-code-skill-file.sh ---"

if [ -f "$TARGET" ] && [ -r "$TARGET" ]; then
  pass "skills/code/SKILL.md exists"
else
  fail "skills/code/SKILL.md missing or unreadable"
fi

if grep -q "using-superpowers" "$TARGET"; then
  pass "skill references using-superpowers"
else
  fail "skill missing using-superpowers"
fi

if grep -q "subagent-driven-development" "$TARGET"; then
  pass "skill references subagent-driven-development"
else
  fail "skill missing subagent-driven-development"
fi

if grep -q "docs/c4flow/.state.json" "$TARGET"; then
  pass "skill references docs/c4flow/.state.json"
else
  fail "skill missing docs/c4flow/.state.json"
fi

if grep -q "This skill is part of the c4flow workflow but has not been implemented yet." "$TARGET"; then
  fail "old stub sentence still present"
else
  pass "old stub sentence removed"
fi

LINE_COUNT=$(wc -l < "$TARGET")
if [ "$LINE_COUNT" -ge 120 ]; then
  pass "skill file length is at least 120 lines ($LINE_COUNT)"
else
  fail "skill file too short ($LINE_COUNT lines)"
fi

TOTAL=$((PASS + FAIL))
echo ""
echo "test-code-skill-file.sh: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
