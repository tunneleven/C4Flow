#!/usr/bin/env bash
# test-code-actor-resolution.sh
# Verifies the code skill documents actor resolution with all three fallback paths
# Covers tasks 1.6, 1.7: actor resolution and claim conflict scenarios

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="$ROOT_DIR/skills/code/SKILL.md"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "--- test-code-actor-resolution.sh ---"

# 1.6a: explicit arg path documented
if grep -q "\-\-assignee" "$TARGET" && grep -qE "from <name>|from <actor>" "$TARGET"; then
  pass "skill documents explicit --assignee / 'from <name>' arg path"
else
  fail "skill missing explicit assignee arg documentation"
fi

# 1.6b: BD_ACTOR fallback documented
if grep -q "BD_ACTOR" "$TARGET"; then
  pass "skill documents BD_ACTOR env var fallback"
else
  fail "skill missing BD_ACTOR fallback"
fi

# 1.6c: git config fallback documented
if grep -q "git config user.name" "$TARGET"; then
  pass "skill documents git config user.name fallback"
else
  fail "skill missing git config user.name fallback"
fi

# 1.6d: priority order correct (arg first, git last)
ARG_LINE=$(grep -n "assignee\|from <name>" "$TARGET" | head -1 | cut -d: -f1)
GIT_LINE=$(grep -n "git config user.name" "$TARGET" | head -1 | cut -d: -f1)
if [ -n "$ARG_LINE" ] && [ -n "$GIT_LINE" ] && [ "$ARG_LINE" -lt "$GIT_LINE" ]; then
  pass "actor resolution priority order is correct (arg before git config)"
else
  fail "actor resolution priority order incorrect or not documented"
fi

# 1.7: claim conflict / retry documented
if grep -qiE "claim fails|already claimed|conflict|re-run.*bd ready|re-running bd ready" "$TARGET"; then
  pass "skill documents claim conflict retry logic"
else
  fail "skill missing claim conflict / retry documentation"
fi

# Bonus: bd ready uses --assignee (not just bd ready)
if grep -q "bd ready --assignee" "$TARGET"; then
  pass "skill uses 'bd ready --assignee' (actor-filtered)"
else
  fail "skill uses plain 'bd ready' without --assignee filter"
fi

TOTAL=$((PASS + FAIL))
echo ""
echo "test-code-actor-resolution.sh: $PASS/$TOTAL passed"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
