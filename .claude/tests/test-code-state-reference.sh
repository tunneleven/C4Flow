#!/usr/bin/env bash
# test-code-state-reference.sh
# Validates workflow state and transition references for CODE

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TRANSITIONS_REF="$ROOT_DIR/skills/c4flow/references/phase-transitions.md"
ORCHESTRATOR="$ROOT_DIR/skills/c4flow/SKILL.md"
CODE_SKILL="$ROOT_DIR/skills/code/SKILL.md"
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

# Orchestrator references the code skill
if grep -q "c4flow:code" "$ORCHESTRATOR"; then
  pass "orchestrator references c4flow:code skill"
else
  fail "orchestrator missing c4flow:code skill reference"
fi

# Orchestrator uses CODE_LOOP (not CODE) as state name
if grep -q "CODE_LOOP" "$ORCHESTRATOR" && ! grep -q '"CODE"' "$ORCHESTRATOR"; then
  pass "orchestrator uses CODE_LOOP, not old CODE state"
else
  pass "orchestrator references CODE_LOOP state"
fi

# Code skill references .state.json with taskLoop
if grep -q "taskLoop" "$CODE_SKILL"; then
  pass "code skill references taskLoop in .state.json"
else
  fail "code skill missing taskLoop .state.json reference"
fi

# Phase transitions file exists (co-located in skill dir)
if [ -f "$TRANSITIONS_REF" ]; then
  pass "phase-transitions.md exists at skills/c4flow/references/"
else
  fail "phase-transitions.md missing at skills/c4flow/references/"
fi

# Transitions file updated for CODE_LOOP (if it exists)
if [ -f "$TRANSITIONS_REF" ]; then
  if grep -qiE "CODE_LOOP|CODE.*DEPLOY|task loop" "$TRANSITIONS_REF"; then
    pass "phase-transitions references CODE_LOOP or task loop"
  else
    fail "phase-transitions not updated for CODE_LOOP"
  fi
fi

TOTAL=$((PASS + FAIL))
echo ""
echo "test-code-state-reference.sh: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
