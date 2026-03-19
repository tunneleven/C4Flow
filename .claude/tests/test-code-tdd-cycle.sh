#!/usr/bin/env bash
# test-code-tdd-cycle.sh
# Verifies TDD cycle: RED gate pause, trivial-test detection, GREEN, REFACTOR
# Covers tasks 3.9, 3.10

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="$ROOT_DIR/skills/code/SKILL.md"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "--- test-code-tdd-cycle.sh ---"

# RED phase: test written before implementation
if grep -qiE "RED.*phase|Phase 1.*RED|write.*test.*first|test.*MUST fail" "$TARGET"; then
  pass "skill documents RED phase (test before implementation)"
else
  fail "skill missing RED phase documentation"
fi

# RED gate pause format documented
if grep -qiE "RED.*gate|gate.*pause|RED STATE CONFIRMED|pause.*show" "$TARGET"; then
  pass "skill documents RED gate pause"
else
  fail "skill missing RED gate pause"
fi

# RED gate shows test + failure output to user
if grep -qiE "failure output|test.*failure|show.*user|Does this test.*capture" "$TARGET"; then
  pass "skill shows test + failure output at RED gate"
else
  fail "skill missing test/failure display at RED gate"
fi

# User approval options: yes / adjust
if grep -qiE "\[yes\]|\[adjust\]|yes.*adjust|approve.*adjust" "$TARGET"; then
  pass "skill documents [yes] and [adjust] options at RED gate"
else
  fail "skill missing [yes]/[adjust] options at RED gate"
fi

# Adjust loop: revise test, re-confirm failure
if grep -qiE "adjust.*loop|revise.*test|re-confirm.*fail|adjust.*instructions" "$TARGET"; then
  pass "skill documents adjust loop (revise → re-confirm RED)"
else
  fail "skill missing adjust loop documentation"
fi

# Trivial test detection: passes immediately = invalid
if grep -qiE "trivial.*test|passes.*immediately|TRIVIAL_TEST|test.*pass.*immediately" "$TARGET"; then
  pass "skill documents trivial-test detection"
else
  fail "skill missing trivial-test detection"
fi

# GREEN: minimum code, all tests pass
if grep -qiE "GREEN.*phase|Phase.*GREEN|minimum code|minimal code" "$TARGET"; then
  pass "skill documents GREEN phase (minimum code)"
else
  fail "skill missing GREEN phase documentation"
fi

# Regression handling: existing tests must still pass
if grep -qiE "regression|existing test.*break|other tests.*pass|previously.*pass" "$TARGET"; then
  pass "skill documents regression handling in GREEN phase"
else
  fail "skill missing regression handling documentation"
fi

# REFACTOR phase documented
if grep -qiE "REFACTOR.*phase|Phase.*REFACTOR|clean.*up.*refactor|refactor.*if needed" "$TARGET"; then
  pass "skill documents REFACTOR phase"
else
  fail "skill missing REFACTOR phase"
fi

# TDD sub-agent dispatch
if grep -qiE "TDD sub-agent|dispatch.*TDD|TDD.*sub-agent|sub-agent.*TDD" "$TARGET"; then
  pass "skill documents TDD sub-agent dispatch"
else
  fail "skill missing TDD sub-agent dispatch"
fi

TOTAL=$((PASS + FAIL))
echo ""
echo "test-code-tdd-cycle.sh: $PASS/$TOTAL passed"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
