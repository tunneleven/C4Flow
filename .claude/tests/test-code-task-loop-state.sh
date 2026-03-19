#!/usr/bin/env bash
# test-code-task-loop-state.sh
# Verifies taskLoop schema, subState transitions, completedTasks, resume logic
# Covers tasks 6.5, 6.6, 7.5, 8.6, 8.7

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="$ROOT_DIR/skills/code/SKILL.md"
ORCHESTRATOR="$ROOT_DIR/skills/c4flow/SKILL.md"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "--- test-code-task-loop-state.sh ---"

# taskLoop schema documented in code skill
if grep -q "taskLoop" "$TARGET"; then
  pass "code skill documents taskLoop schema"
else
  fail "code skill missing taskLoop schema"
fi

# All four subState values present
for state in CODING VERIFYING REVIEWING CLOSING; do
  if grep -q "$state" "$TARGET"; then
    pass "subState '$state' documented"
  else
    fail "subState '$state' missing"
  fi
done

# subState written on every transition
if grep -c "taskLoop.subState" "$TARGET" | grep -qv "^[01]$"; then
  pass "taskLoop.subState written at multiple transition points"
else
  # Count manually
  COUNT=$(grep -c "taskLoop.subState" "$TARGET" 2>/dev/null || echo 0)
  if [ "$COUNT" -ge 4 ]; then
    pass "taskLoop.subState written at $COUNT transition points"
  else
    fail "taskLoop.subState only written at $COUNT points (need ≥4)"
  fi
fi

# completedTasks append with id, pr, mergedAt
if grep -q "completedTasks" "$TARGET" && grep -q "mergedAt" "$TARGET"; then
  pass "completedTasks records id + pr + mergedAt"
else
  fail "completedTasks missing id/pr/mergedAt fields"
fi

# bd close with --reason
if grep -q "bd close.*--reason" "$TARGET"; then
  pass "skill uses bd close --reason (audit trail)"
else
  fail "skill missing bd close --reason"
fi

# dolt push after close
if grep -qE "dolt push.*close|close.*dolt push|bd dolt push.*Sync.*closed" "$TARGET"; then
  pass "skill syncs to DoltHub after close"
else
  fail "skill missing dolt push after close"
fi

# Resume logic documented
if grep -qiE "Resume Logic|resume.*subState|subState.*resume" "$TARGET"; then
  pass "skill documents resume logic"
else
  fail "skill missing resume logic"
fi

# Resume from VERIFYING skips TDD
if grep -qiE "resume.*VERIFYING|VERIFYING.*skip.*TDD|VERIFYING.*re-run.*test" "$TARGET"; then
  pass "skill documents resume from VERIFYING (skip TDD)"
else
  fail "skill missing resume from VERIFYING"
fi

# Resume from REVIEWING skips TDD + verify
if grep -qiE "resume.*REVIEWING|REVIEWING.*skip|REVIEWING.*re-dispatch" "$TARGET"; then
  pass "skill documents resume from REVIEWING"
else
  fail "skill missing resume from REVIEWING"
fi

# Orchestrator: CODE_LOOP state (task 8.6)
if grep -q "CODE_LOOP" "$ORCHESTRATOR"; then
  pass "orchestrator uses CODE_LOOP state"
else
  fail "orchestrator missing CODE_LOOP state"
fi

# Orchestrator: DEPLOY follows CODE_LOOP (not TEST) (task 8.6)
if grep -qiE "CODE_LOOP.*DEPLOY|advance.*DEPLOY|currentState.*DEPLOY" "$TARGET" || \
   grep -qiE "CODE_LOOP.*DEPLOY|advance.*DEPLOY" "$ORCHESTRATOR"; then
  pass "CODE_LOOP advances to DEPLOY (not TEST)"
else
  fail "missing CODE_LOOP → DEPLOY transition"
fi

# Orchestrator: legacy CODE migration (task 8.7)
if grep -qiE "legacy.*migration|currentState.*CODE.*CODE_LOOP|CODE.*to.*CODE_LOOP" "$ORCHESTRATOR"; then
  pass "orchestrator handles legacy CODE → CODE_LOOP migration"
else
  fail "orchestrator missing legacy CODE state migration"
fi

# Code skill: taskLoop null on start
if grep -qiE "null.*first.*claim|taskLoop.*null|null.*until.*claim" "$TARGET"; then
  pass "taskLoop is null until first task claimed"
else
  fail "skill missing taskLoop null initialization"
fi

TOTAL=$((PASS + FAIL))
echo ""
echo "test-code-task-loop-state.sh: $PASS/$TOTAL passed"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
