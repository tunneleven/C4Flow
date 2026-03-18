#!/usr/bin/env bash
# test-init-help.sh
# Verify init.sh exposes GitHub and CodeRabbit flags

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="$ROOT_DIR/skills/init/init.sh"

echo "--- test-init-help.sh ---"

OUTPUT="$(bash "$TARGET" --help)"

check_flag() {
  local flag="$1"
  if printf '%s\n' "$OUTPUT" | grep -q -- "$flag"; then
    echo "  PASS: help contains $flag"
  else
    echo "  FAIL: help missing $flag"
    return 1
  fi
}

check_flag "--github"
check_flag "--no-github"
check_flag "--github-owner"
check_flag "--github-repo"
check_flag "--github-visibility"
check_flag "--coderabbit"
check_flag "--no-coderabbit"
check_flag "--coderabbit-installation-id"

echo ""
echo "test-init-help.sh: all checks passed"
