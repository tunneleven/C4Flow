#!/usr/bin/env bash
# test-code-branch-strategy.sh
# Verifies branch strategy: one branch per task, feat/<id>-<slug> naming, cut from main
# Covers task 2.5: slug derivation edge cases + branch naming

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="$ROOT_DIR/skills/code/SKILL.md"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "--- test-code-branch-strategy.sh ---"

# Branch naming convention documented
if grep -qE "feat/.*bead-id|feat/.*TASK_ID|feat/.*task-slug" "$TARGET"; then
  pass "skill documents feat/<bead-id>-<task-slug> naming"
else
  fail "skill missing branch naming convention"
fi

# Always cut from main
if grep -q "git checkout main" "$TARGET" && grep -q "git pull" "$TARGET"; then
  pass "skill documents git checkout main && git pull before branching"
else
  fail "skill missing 'git checkout main && git pull' before branch creation"
fi

# BLOCKED on pull failure documented
if grep -qiE "pull.*fail|BLOCKED.*git pull|git pull.*fail" "$TARGET"; then
  pass "skill documents BLOCKED state on git pull failure"
else
  fail "skill missing BLOCKED handling for git pull failure"
fi

# Existing branch detection documented
if grep -qiE "already exists|show-ref|existing branch" "$TARGET"; then
  pass "skill documents existing branch detection"
else
  fail "skill missing existing branch detection"
fi

# Slug derivation (kebab-case) documented
if grep -qiE "kebab|tr.*lower|sed.*-/g|slug" "$TARGET"; then
  pass "skill documents slug derivation (kebab-case)"
else
  fail "skill missing slug derivation logic"
fi

# One branch per task (not feature branch)
if grep -qE "one branch per task|serial.*loop|One task at a time" "$TARGET"; then
  pass "skill enforces one-branch-per-task (serial loop)"
else
  fail "skill missing one-branch-per-task enforcement"
fi

TOTAL=$((PASS + FAIL))
echo ""
echo "test-code-branch-strategy.sh: $PASS/$TOTAL passed"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
