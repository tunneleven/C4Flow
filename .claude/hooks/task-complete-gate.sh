#!/usr/bin/env bash
# .claude/hooks/task-complete-gate.sh
# TaskCompleted hook: block task completion when quality gates are open

set -euo pipefail

# Guard: only activate in beads projects
[ -f ".bd" ] || exit 0

# Read hook input
INPUT=$(cat)
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // "unknown task"')

# Resolve quality-gate-status.json path using CLAUDE_PROJECT_DIR with git-toplevel fallback
# (Pitfall 4: bare pwd may be a subdirectory)
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
GATE_FILE="${PROJECT_ROOT}/quality-gate-status.json"

if [ ! -f "$GATE_FILE" ]; then
  # No gate status file — check if there are active gates before blocking (Pitfall 3 prevention)
  # If no gates exist at all, allow completion (no gate context to enforce)
  ACTIVE_GATE_COUNT=$(bd gate list --json 2>/dev/null | jq 'length' 2>/dev/null || echo 0)
  if [ "${ACTIVE_GATE_COUNT:-0}" -eq 0 ]; then
    exit 0  # No active gates — allow task completion
  fi
  # Gates exist but no status file — quality checks have not been run; block
  cat >&2 <<EOF
Quality gate status not found for: $TASK_SUBJECT
Run /c4flow:review and /c4flow:verify before marking this task complete.
If quality checks genuinely do not apply, resolve open gates manually: bd gate resolve <id> --reason "..."
EOF
  exit 2
fi

OVERALL_PASS=$(jq -r '.overall_pass // false' "$GATE_FILE" 2>/dev/null)

if [ "$OVERALL_PASS" = "true" ]; then
  exit 0  # Quality gates passed — allow task completion
fi

# Gate not passed — block completion with detailed status
GATE_ID=$(jq -r '.gate_id // "unknown"' "$GATE_FILE")
CODEX_PASS=$(jq -r 'if .checks.codex_review.pass == true then "PASS" elif .checks.codex_review.pass == false then "FAIL" else "NOT RUN" end' "$GATE_FILE")
PREFLIGHT_PASS=$(jq -r 'if .checks.bd_preflight.pass == true then "PASS" elif .checks.bd_preflight.pass == false then "FAIL" else "NOT RUN" end' "$GATE_FILE")

cat >&2 <<EOF
Cannot mark "$TASK_SUBJECT" complete — quality gates not passed.

Gate status (gate: $GATE_ID):
  Codex review:  $CODEX_PASS
  bd preflight:  $PREFLIGHT_PASS

To unblock:
  1. Run /c4flow:review  (Codex code review)
  2. Run /c4flow:verify  (bd preflight + gate resolution)
EOF
exit 2
