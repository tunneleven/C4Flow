#!/usr/bin/env bash
# test-init-skill-file.sh
# Contract checks for the c4flow:init skill documentation

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="$ROOT_DIR/skills/init/SKILL.md"
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

echo "--- test-init-skill-file.sh ---"

if [ -f "$TARGET" ] && [ -r "$TARGET" ]; then
  pass "skills/init/SKILL.md exists"
else
  fail "skills/init/SKILL.md missing or unreadable"
fi

if grep -q "Do you want to create/manage a GitHub repository for this project?" "$TARGET"; then
  pass "skill documents GitHub bootstrap prompt"
else
  fail "skill missing GitHub bootstrap prompt"
fi

if grep -q "Do you want to set up CodeRabbit for this repository?" "$TARGET"; then
  pass "skill documents CodeRabbit prompt"
else
  fail "skill missing CodeRabbit prompt"
fi

if grep -q "Terraform" "$TARGET"; then
  pass "skill references Terraform bootstrap"
else
  fail "skill missing Terraform bootstrap reference"
fi

if grep -q "GITHUB_TOKEN" "$TARGET"; then
  pass "skill documents GITHUB_TOKEN"
else
  fail "skill missing GITHUB_TOKEN"
fi

if grep -q "GITHUB_APP_ID" "$TARGET"; then
  pass "skill documents GitHub App env vars"
else
  fail "skill missing GitHub App env vars"
fi

if grep -q ".coderabbit.yaml" "$TARGET"; then
  pass "skill references .coderabbit.yaml"
else
  fail "skill missing .coderabbit.yaml reference"
fi

TOTAL=$((PASS + FAIL))
echo ""
echo "test-init-skill-file.sh: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
