#!/usr/bin/env bash
# .claude/hooks/bd-close-gate.sh
# PreToolUse hook: intercept agent-initiated bd close when quality gates are open

set -euo pipefail

# Guard: only activate in beads projects
[ -f ".bd" ] || exit 0

# Read hook input from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only intercept Bash calls
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

# Only intercept commands containing 'bd close'
if ! echo "$COMMAND" | grep -qE 'bd\s+close'; then
  exit 0
fi

# Allow --force or -f bypasses (v2 auditing deferred to RELS-03)
if echo "$COMMAND" | grep -qE '(--force|-f)\b'; then
  exit 0
fi

# Resolve quality-gate-status.json path using CLAUDE_PROJECT_DIR with git-toplevel fallback
# (Pitfall 4: bare pwd may be a subdirectory)
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
GATE_FILE="${PROJECT_ROOT}/quality-gate-status.json"

if [ ! -f "$GATE_FILE" ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "No quality gate status found. Run /c4flow:review before closing this task."
    }
  }'
  exit 0
fi

OVERALL_PASS=$(jq -r '.overall_pass // false' "$GATE_FILE" 2>/dev/null)

if [ "$OVERALL_PASS" = "true" ]; then
  exit 0  # Gate passed — allow the close
fi

# Build denial message from gate status
GATE_ID=$(jq -r '.gate_id // "unknown"' "$GATE_FILE")
CODEX_PASS=$(jq -r 'if .checks.codex_review.pass == true then "PASS" elif .checks.codex_review.pass == false then "FAIL" else "NOT RUN" end' "$GATE_FILE")
PREFLIGHT_PASS=$(jq -r 'if .checks.bd_preflight.pass == true then "PASS" elif .checks.bd_preflight.pass == false then "FAIL" else "NOT RUN" end' "$GATE_FILE")

jq -n \
  --arg gate_id "$GATE_ID" \
  --arg codex "$CODEX_PASS" \
  --arg preflight "$PREFLIGHT_PASS" \
  '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("Quality gates not passed. Cannot close this task.\n  Codex review: " + $codex + "\n  bd preflight: " + $preflight + "\nNext steps:\n  - Run /c4flow:review to run the Codex code review\n  - Run /c4flow:verify to run bd preflight and confirm all checks\n  Gate ID: " + $gate_id)
    }
  }'
exit 0
