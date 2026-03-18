#!/usr/bin/env bash
# test-init-github-contract.sh
# Contract checks for GitHub and CodeRabbit bootstrap wiring

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="$ROOT_DIR/skills/init/init.sh"
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

assert_contains() {
  local pattern="$1"
  local label="$2"
  if grep -q "$pattern" "$TARGET"; then
    pass "$label"
  else
    fail "$label"
  fi
}

echo "--- test-init-github-contract.sh ---"

assert_contains "Do you want to create/manage a GitHub repository for this project?" "GitHub prompt exists"
assert_contains "Do you want to set up CodeRabbit for this repository?" "CodeRabbit prompt exists"
assert_contains "This repo already has an origin remote. Do you want to replace it?" "origin replacement prompt exists"

assert_contains "terraform" "script references terraform"
assert_contains "github_repository" "script references github_repository"
assert_contains ".coderabbit.yaml" "script references .coderabbit.yaml"
assert_contains "GITHUB_TOKEN" "script references GITHUB_TOKEN"
assert_contains "GITHUB_APP_ID" "script references GITHUB_APP_ID"
assert_contains "GITHUB_APP_INSTALLATION_ID" "script references GITHUB_APP_INSTALLATION_ID"
assert_contains "GITHUB_APP_PEM_FILE" "script references GITHUB_APP_PEM_FILE"

TOTAL=$((PASS + FAIL))
echo ""
echo "test-init-github-contract.sh: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
