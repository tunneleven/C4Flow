#!/usr/bin/env bash
# test-code-verify-review.sh
# Verifies VERIFY (tests + preflight) and REVIEW (severity routing) sections
# Covers tasks 4.6, 4.7, 5.6

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="$ROOT_DIR/skills/code/SKILL.md"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "--- test-code-verify-review.sh ---"

# VERIFY section exists
if grep -qiE "VERIFY|Step 4|tests \+ coverage|coverage threshold" "$TARGET"; then
  pass "skill documents VERIFY phase"
else
  fail "skill missing VERIFY phase"
fi

# Coverage threshold check (read from tech-stack.md, default 80%)
if grep -qiE "coverage.*threshold|threshold.*80|tech-stack.*coverage|default.*80" "$TARGET"; then
  pass "skill documents coverage threshold (tech-stack.md / default 80%)"
else
  fail "skill missing coverage threshold documentation"
fi

# Below-threshold user prompt
if grep -qiE "below.*threshold|coverage.*<.*threshold|add.*more.*test|proceed.*anyway" "$TARGET"; then
  pass "skill documents below-threshold user prompt"
else
  fail "skill missing below-threshold user prompt"
fi

# Test failure routing back to CODING
if grep -qiE "test.*fail.*CODING|failure.*route.*back|set.*subState.*CODING" "$TARGET"; then
  pass "skill routes test failures back to CODING sub-state"
else
  fail "skill missing test failure routing to CODING"
fi

# bd preflight --check
if grep -q "bd preflight --check" "$TARGET"; then
  pass "skill documents bd preflight --check"
else
  fail "skill missing bd preflight --check"
fi

# Preflight failure routing back to CODING
if grep -qiE "preflight.*fail.*CODING|preflight.*block|fix.*preflight" "$TARGET"; then
  pass "skill routes preflight failures back to CODING"
else
  fail "skill missing preflight failure routing"
fi

# REVIEW section exists (c4flow:review)
if grep -qiE "c4flow:review|REVIEW.*phase|Step 5.*REVIEW" "$TARGET"; then
  pass "skill documents REVIEW phase (c4flow:review)"
else
  fail "skill missing REVIEW phase"
fi

# CRITICAL/HIGH blocks advancement
if grep -qiE "CRITICAL.*block|HIGH.*block|CRITICAL.*HIGH.*block|block.*CRITICAL" "$TARGET"; then
  pass "skill blocks on CRITICAL/HIGH review findings"
else
  fail "skill missing CRITICAL/HIGH blocking logic"
fi

# MEDIUM/LOW advisory (non-blocking)
if grep -qiE "MEDIUM.*advisory|LOW.*advisory|non-blocking|proceed.*MEDIUM|proceed.*LOW" "$TARGET"; then
  pass "skill treats MEDIUM/LOW findings as advisory (non-blocking)"
else
  fail "skill missing MEDIUM/LOW advisory handling"
fi

# CRITICAL/HIGH routes back to TDD sub-agent
if grep -qiE "CRITICAL.*CODING|HIGH.*CODING|route.*back.*TDD|CODING.*review.*finding" "$TARGET"; then
  pass "skill routes CRITICAL/HIGH findings back to CODING"
else
  fail "skill missing routing for CRITICAL/HIGH findings"
fi

TOTAL=$((PASS + FAIL))
echo ""
echo "test-code-verify-review.sh: $PASS/$TOTAL passed"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
