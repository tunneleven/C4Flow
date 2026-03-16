#!/usr/bin/env bash
# test-code-state-reference.sh
# Validates workflow state and transition references for CODE

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_REF="$ROOT_DIR/references/workflow-state.md"
TRANSITIONS_REF="$ROOT_DIR/references/phase-transitions.md"
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

echo "--- test-code-state-reference.sh ---"

if grep -q "skills/code/SKILL.md" "$STATE_REF"; then
  pass "workflow-state references skills/code/SKILL.md"
else
  fail "workflow-state missing skills/code/SKILL.md"
fi

if grep -q "| 5 | CODE |" "$STATE_REF"; then
  pass "workflow-state CODE row still exists"
else
  fail "workflow-state CODE row missing"
fi

if grep -q "CODE → TEST" "$TRANSITIONS_REF"; then
  pass "phase-transitions keeps CODE → TEST row"
else
  fail "phase-transitions missing CODE → TEST row"
fi

if grep -q 'beads or `tasks.md`' "$TRANSITIONS_REF"; then
  pass "phase-transitions references beads or tasks.md"
else
  fail "phase-transitions missing beads or tasks.md wording"
fi

TOTAL=$((PASS + FAIL))
echo ""
echo "test-code-state-reference.sh: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
