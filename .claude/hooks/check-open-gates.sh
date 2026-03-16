#!/usr/bin/env bash
# .claude/hooks/check-open-gates.sh
# Stop hook: block session end when quality gates are unresolved

set -euo pipefail

# Guard: only activate in beads projects
[ -f ".bd" ] || exit 0

# Query open c4flow quality gates
# Use null-safe label filter (Pitfall 5: .labels may be null on some gates)
OPEN_GATES=$(bd gate list --json 2>/dev/null | \
  jq '[.[] | select((.labels // []) | map(contains("c4flow-quality-gate")) | any)]' 2>/dev/null || echo "[]")

GATE_COUNT=$(echo "$OPEN_GATES" | jq 'length' 2>/dev/null || echo 0)

if [ "${GATE_COUNT:-0}" -eq 0 ]; then
  exit 0  # No open c4flow quality gates — allow session to end
fi

# Build list of open gates for the block message
GATE_LIST=$(echo "$OPEN_GATES" | jq -r '.[] | "  " + .id + ": " + .title' 2>/dev/null)

jq -n \
  --arg gate_list "$GATE_LIST" \
  --arg count "$GATE_COUNT" \
  '{
    decision: "block",
    reason: ("Session has " + $count + " unresolved quality gate(s):\n" + $gate_list + "\n\nTo unblock this session:\n  1. Run /c4flow:review to run the Codex code review\n  2. Run /c4flow:verify to run bd preflight and confirm all checks\n  Or manually: bd gate resolve <gate-id> --reason \"your reason\"")
  }'
exit 0
