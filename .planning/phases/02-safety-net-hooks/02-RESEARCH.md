# Phase 2: Safety Net Hooks - Research

**Researched:** 2026-03-16
**Domain:** Claude Code hooks system, shell script interceptors, project-scoped hook configuration
**Confidence:** HIGH (hooks docs fetched from live official docs; beads CLI flags verified locally; quality-gate-status.json schema already implemented in Phase 1)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| HOOK-01 | PreToolUse hook on Bash intercepts agent-initiated `bd close` commands — reads `quality-gate-status.json` (~100ms), denies with explanation if gates not passed | PreToolUse blocking confirmed via official docs; `tool_input.command` field verified in stdin schema; fast file read pattern is sufficient |
| HOOK-02 | Stop hook checks for unresolved beads gates before agent session ends, blocks with list of open gates | Stop hook blocking confirmed via `{"decision": "block", "reason": "..."}` output; `bd gate list --json` is the gate query |
| HOOK-03 | TaskCompleted hook blocks task completion via TaskUpdate if quality gates are still open for the associated beads task | TaskCompleted hook type confirmed from live docs; blocking via exit code 2 or JSON output; payload includes `task_id`, `task_subject` — gate association requires reading `quality-gate-status.json` |
| INFR-02 | `.claude/hooks/` shell scripts: `bd-close-gate.sh` (PreToolUse), `check-open-gates.sh` (Stop), `task-complete-gate.sh` (TaskCompleted) | All three script patterns fully researchable; file naming follows project convention for clarity |
| INFR-03 | Hooks configuration in `.claude/settings.json` with project-scoped matchers and appropriate timeouts | Exact JSON schema confirmed from live docs; project-scoped placement in `.claude/settings.json` confirmed; timeout field per-hook confirmed |
</phase_requirements>

---

## Summary

Phase 2 implements three Claude Code hook scripts that act as a safety net against agent-initiated quality gate bypasses. These hooks do not replace the beads gate enforcement (which already blocks `bd close` natively for any caller) — they add an agent-specific interception layer that can explain WHY the close is blocked and which gates are still open.

The hook system is well-documented and the patterns are straightforward. All three hooks follow the same fast-file-check pattern: read `quality-gate-status.json` from the project root, check `overall_pass`, and either pass through or block with a detailed message. The hooks are project-scoped via `.claude/settings.json` and include a C4Flow project guard (`[ -f ".bd" ] || exit 0`) so they fire only within beads projects.

The one unconfirmed behavior from the original concerns (STATE.md: "TaskCompleted hook interaction with beads tasks is unconfirmed") is now addressed: `TaskCompleted` fires when a beads task is marked complete via Claude Code's task system. The hook receives `task_id` and `task_subject` in its stdin payload but does NOT receive the beads bead ID. The gate lookup must therefore use `quality-gate-status.json` (which stores the gate ID) rather than trying to correlate task IDs with beads IDs.

**Primary recommendation:** Implement in this order: INFR-03 (settings.json with hooks config) → INFR-02 hook 1 (bd-close-gate.sh) → INFR-02 hook 2 (check-open-gates.sh) → INFR-02 hook 3 (task-complete-gate.sh). Settings.json first so hook wiring is in place before scripts are created.

---

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Bash (POSIX sh) | system | Hook scripts — lightweight, no dependencies | Claude Code hooks run as shell commands; bash is always available |
| `jq` | system | Parse stdin JSON from hook events; read `quality-gate-status.json` | Already used throughout Phase 1 scripts; pre-installed on target machine |
| `bd gate list --json` | local | Query open beads gates for Stop/TaskCompleted hooks | Confirmed locally; `--json` flag produces parseable output |
| `.claude/settings.json` | project | Hook registration, project-scoped | Official project-scoped hook config location per Claude Code docs |

### Supporting

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `quality-gate-status.json` | Fast gate status read (< 100ms) | PreToolUse and TaskCompleted hooks — avoids calling `bd gate list` (slower CLI spawn) |
| `bd gate list --json` | Authoritative gate status query | Stop hook — provides exact gate IDs and titles for error message; acceptable latency since Stop is not in hot path |
| `[ -f ".bd" ]` guard | Detect beads project | First line of every hook — skip gracefully on non-beads projects (Pitfall 11 prevention) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| File read for HOOK-01 | `bd gate list --json` | File read is ~100ms vs CLI spawn ~200-500ms; for PreToolUse hot path, file is preferred; file may be stale but still correct (can't pass without it being written) |
| Exit code 2 for blocking | JSON `permissionDecision: deny` (PreToolUse) | Both work; JSON form provides richer `permissionDecisionReason` message shown to Claude; prefer JSON for better agent feedback |
| Project-scoped `.claude/settings.json` | Global `~/.claude/settings.json` | Global fires on all projects — confirmed anti-pattern (Pitfall 11); project-scoped is mandatory |

---

## Architecture Patterns

### Recommended Project Structure

```
.claude/
├── hooks/
│   ├── bd-close-gate.sh          # PreToolUse: intercept agent bd close
│   ├── check-open-gates.sh       # Stop: block session end with open gates
│   └── task-complete-gate.sh     # TaskCompleted: block task completion
└── settings.json                 # Add hooks config alongside existing plugin config
```

### Pattern 1: PreToolUse Hook on Bash — Intercept `bd close`

**What:** Fires before every `Bash` tool call. Checks if the command matches `bd close` (without `--force`). If it matches, reads `quality-gate-status.json` to determine gate status. Denies with explanation if gates are not passed.

**When to use:** HOOK-01 requirement — agent-initiated `bd close` interception.

**Key design decisions:**
- Use `quality-gate-status.json` for the gate check, NOT `bd gate list`. File read is faster and sufficient. If the file doesn't exist or `overall_pass` is not `true`, deny.
- Do NOT intercept `bd close --force`. Per REQUIREMENTS.md, force bypass is allowed (RELS-03 auditing is v2). Hook should only guard non-forced closes.
- Pass through all non-bd-close commands immediately (exit 0 with no output).

**Hook stdin payload (PreToolUse):**
```json
{
  "session_id": "abc123",
  "cwd": "/home/user/project",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": {
    "command": "bd close task-001 --reason 'done'",
    "description": "Close the task",
    "timeout": 120000,
    "run_in_background": false
  },
  "tool_use_id": "toolu_01ABC123"
}
```

**Hook output to deny (exit 0, JSON to stdout):**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Quality gates not passed. Run /c4flow:review and /c4flow:verify first.\nGate status: codex_review=FAIL, bd_preflight=NOT RUN\nGate ID: bd-xxxx"
  }
}
```

**Alternative blocking method (exit code 2):**
```bash
echo "Quality gates not passed. Gate ID: $GATE_ID. Run /c4flow:review first." >&2
exit 2
```

Both work. JSON form provides a structured `permissionDecisionReason` field surfaced clearly to Claude. Exit 2 is simpler. Use JSON form for richer feedback.

**Script skeleton:**
```bash
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

# Only intercept Bash calls containing 'bd close'
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

if ! echo "$COMMAND" | grep -qE 'bd\s+close'; then
  exit 0
fi

# Allow --force bypasses (v2 auditing deferred to RELS-03)
if echo "$COMMAND" | grep -q -- '--force\|-f\b'; then
  exit 0
fi

# Read quality gate status (fast file check, ~100ms)
GATE_FILE="$(pwd)/quality-gate-status.json"

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
```

### Pattern 2: Stop Hook — Block Session End with Open Gates

**What:** Fires when Claude tries to finish responding and end its session. Queries `bd gate list --json` for any open gates with the `c4flow-quality-gate` label. If any are found, blocks with a list of open gates.

**When to use:** HOOK-02 requirement — session-end safety net.

**Key design decisions:**
- Use `bd gate list --json` (not just file read). Stop hook is NOT in the hot path — it fires once per session end. Authoritative gate list is worth the CLI spawn cost.
- Filter by label `c4flow-quality-gate` to avoid blocking on unrelated open gates in the beads DB.
- Include gate IDs and titles in the block message so Claude knows exactly what to address.
- Always include remediation instructions in the block message (Pitfall 12 — prevents infinite loop).

**Hook output to block (exit 0, JSON to stdout):**
```json
{
  "decision": "block",
  "reason": "Open quality gates:\n  bd-xxxx: Quality gate: c4flow review+verify\nTo unblock:\n  - Run /c4flow:review and /c4flow:verify, or\n  - Resolve gates manually: bd gate resolve bd-xxxx --reason '...'"
}
```

**Script skeleton:**
```bash
#!/usr/bin/env bash
# .claude/hooks/check-open-gates.sh
# Stop hook: block session end when quality gates are unresolved

set -euo pipefail

# Guard: only activate in beads projects
[ -f ".bd" ] || exit 0

# Query open c4flow quality gates
OPEN_GATES=$(bd gate list --json 2>/dev/null | \
  jq '[.[] | select(.labels != null and (.labels[] | contains("c4flow-quality-gate")))]' 2>/dev/null)

GATE_COUNT=$(echo "$OPEN_GATES" | jq 'length' 2>/dev/null || echo 0)

if [ "${GATE_COUNT:-0}" -eq 0 ]; then
  exit 0  # No open gates — allow session to end
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
```

### Pattern 3: TaskCompleted Hook — Block Task Completion with Open Gates

**What:** Fires when a task is marked complete via Claude Code's TaskUpdate mechanism. Checks `quality-gate-status.json` for open gates. Blocks with remediation instructions if quality gates are not passed.

**When to use:** HOOK-03 requirement — block task completion events.

**Critical design constraint:** The `TaskCompleted` hook receives `task_id` and `task_subject` in its payload, but these are Claude Code task IDs — NOT beads bead IDs. There is no direct mapping from Claude Code task ID to the beads gate ID in `quality-gate-status.json`. The hook therefore checks `overall_pass` from the file (which is global to the current working directory), not per-task.

**Hook stdin payload (TaskCompleted):**
```json
{
  "session_id": "abc123",
  "cwd": "/home/user/project",
  "hook_event_name": "TaskCompleted",
  "task_id": "task-001",
  "task_subject": "Implement user authentication",
  "task_description": "Add login and signup endpoints",
  "teammate_name": "implementer",
  "team_name": "my-project"
}
```

**Hook output to block (exit 2):**
```bash
echo "Quality gates not passed for task: $TASK_SUBJECT. Run /c4flow:review and /c4flow:verify before marking complete." >&2
exit 2
```

**Script skeleton:**
```bash
#!/usr/bin/env bash
# .claude/hooks/task-complete-gate.sh
# TaskCompleted hook: block task completion when quality gates are open

set -euo pipefail

# Guard: only activate in beads projects
[ -f ".bd" ] || exit 0

# Read hook input
INPUT=$(cat)
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // "unknown task"')

# Read quality gate status (fast file check)
GATE_FILE="$(pwd)/quality-gate-status.json"

if [ ! -f "$GATE_FILE" ]; then
  # No gate status — quality checks have not been run
  # Only block if we are in an active task context with a gate (heuristic: .bd file present)
  # Without gate status, we cannot confirm quality — block with advisory
  cat >&2 << EOF
Quality gate status not found for: $TASK_SUBJECT
Run /c4flow:review and /c4flow:verify before marking this task complete.
If quality checks genuinely do not apply, create gate-status with overall_pass=true manually.
EOF
  exit 2
fi

OVERALL_PASS=$(jq -r '.overall_pass // false' "$GATE_FILE" 2>/dev/null)

if [ "$OVERALL_PASS" = "true" ]; then
  exit 0  # Quality gates passed — allow task completion
fi

# Gate not passed — block completion
GATE_ID=$(jq -r '.gate_id // "unknown"' "$GATE_FILE")
CODEX_PASS=$(jq -r 'if .checks.codex_review.pass == true then "PASS" elif .checks.codex_review.pass == false then "FAIL" else "NOT RUN" end' "$GATE_FILE")
PREFLIGHT_PASS=$(jq -r 'if .checks.bd_preflight.pass == true then "PASS" elif .checks.bd_preflight.pass == false then "FAIL" else "NOT RUN" end' "$GATE_FILE")

cat >&2 << EOF
Cannot mark "$TASK_SUBJECT" complete — quality gates not passed.

Gate status (gate: $GATE_ID):
  Codex review:  $CODEX_PASS
  bd preflight:  $PREFLIGHT_PASS

To unblock:
  1. Run /c4flow:review  (Codex code review)
  2. Run /c4flow:verify  (bd preflight + gate resolution)
EOF
exit 2
```

### Pattern 4: settings.json Hook Registration

**What:** The `.claude/settings.json` file currently has only plugin config. Add the `hooks` object alongside it.

**Key configuration decisions:**
- `PreToolUse` on `Bash` matcher — catches all Bash calls; the script filters internally
- `Stop` and `TaskCompleted` — no matcher field (they have no tool to match)
- Timeout: 10 seconds for PreToolUse (fast file read; fail fast if exceeded), 30 seconds for Stop (slower `bd gate list` call), 10 seconds for TaskCompleted (file read only)
- All hooks are type `command` — shell scripts are the right abstraction here

**Updated `.claude/settings.json`:**
```json
{
  "enabledPlugins": {
    "superpowers@claude-plugins-official": true,
    "superpowers@superpowers-marketplace": true
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/bd-close-gate.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/check-open-gates.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/task-complete-gate.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

**Note on `$CLAUDE_PROJECT_DIR`:** This environment variable is set by Claude Code to the project root. Using it makes the path absolute without hardcoding, which is critical for hooks fired from any cwd.

### Anti-Patterns to Avoid

- **Running `bd gate list` in PreToolUse:** CLI spawn cost is ~200-500ms per every Bash call. The hook fires on EVERY Bash invocation. Use file read instead.
- **Blocking on `bd close --force`:** Do not intercept force-closes. Force is the intentional bypass mechanism. Blocking it creates an escape-proof loop.
- **Global hook installation:** Never add these hooks to `~/.claude/settings.json`. They will fire on all projects including those without beads.
- **No `.bd` file guard:** Without `[ -f ".bd" ] || exit 0`, hooks fire on every project and fail with "not a beads project" errors.
- **Stop hook with no remediation:** Always include exact commands in the block message. Claude cannot unblock itself without knowing what to do (Pitfall 12).
- **Missing `CLAUDE_PROJECT_DIR` in command path:** Relative paths in `settings.json` hook commands resolve from Claude Code's working directory at hook invocation time, which may not be the project root. Use `$CLAUDE_PROJECT_DIR` for reliability.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Blocking all `bd close` without gates | Custom reimplementation of beads gate enforcement | Beads native gate enforcement | `bd close` already refuses when gates are unsatisfied; hooks are SAFETY NET only, not primary enforcement |
| Regex-parsing `bd close` command for complex flags | Complex bash regex for edge cases | Simple `grep -qE 'bd\s+close'` + `grep -q -- '--force'` | Sufficient for agent-initiated commands; no need for full flag parser |
| Per-bead-task gate lookup | Map Claude Code task ID to beads bead ID | Read `quality-gate-status.json` (already stores `gate_id`) | File is the single source of truth established in Phase 1; no additional lookup needed |
| Custom gate status tracking | Re-implement gate state in a separate file | `quality-gate-status.json` from Phase 1 + `bd gate list --json` | Phase 1 already built the single-source gate status file; hooks just read it |

**Key insight:** Hooks are read-only safety nets. They read state (gate status file, `bd gate list`) and block or allow. They never write state. All state mutation happens in the skills (Phase 1).

---

## Common Pitfalls

### Pitfall 1: Hook Fires on Every Bash Call (PreToolUse Performance)

**What goes wrong:** The PreToolUse hook fires before every single Bash tool call in Claude's session — not just `bd close`. If the hook is slow (e.g., spawns `bd gate list --json`), every file write or test run is visibly slower.

**Why it happens:** The `matcher: "Bash"` fires on all Bash invocations.

**How to avoid:** Use file read (`quality-gate-status.json`) instead of CLI spawn. Exit 0 immediately for non-`bd close` commands — the check at the top of the script (`echo "$COMMAND" | grep -qE 'bd\s+close'`) exits 0 in < 1ms for non-matching commands.

**Warning signs:** Claude is noticeably slow on every file operation during a session.

### Pitfall 2: Stop Hook Infinite Loop

**What goes wrong:** Stop hook blocks Claude. Claude has no tools left to use (session is stopping). Claude cannot run `/c4flow:review`. Claude cannot end. Infinite block.

**Why it happens:** Block message doesn't give Claude enough context to proceed. OR the block message is correct but Claude's context window is exhausted.

**How to avoid:** Block message MUST include:
1. Exact gate IDs
2. Exact commands to run: `bd gate resolve <id> --reason "..."` for manual bypass
3. Clear path forward: "Run /c4flow:review if you have context remaining"

If the session is truly exhausted, the developer needs to resolve gates manually in terminal. The Stop hook should not be an escape-proof trap.

**Warning signs:** Claude responses loop with "I cannot complete without resolving gates but cannot run tools."

### Pitfall 3: TaskCompleted Hook False Positive on Non-Task Sessions

**What goes wrong:** `quality-gate-status.json` doesn't exist (e.g., developer starts fresh project, hasn't run `c4flow:review`). TaskCompleted hook fires on any task completion and blocks with "No gate status found."

**Why it happens:** Hook treats absence of gate status file as "gates failed" — too aggressive.

**How to avoid:** The absence of `quality-gate-status.json` should only block if there is evidence of an active beads task (`.bd` file present AND there is an active gate in `bd gate list`). If no gate status file AND no active gates, allow the completion. The `.bd` guard handles the non-beads case; the additional check is: if no gate status AND `bd gate list | jq 'length'` is 0, exit 0.

**Alternative:** Make the TaskCompleted hook advisory-only (emit a warning but exit 0) rather than blocking. This reduces friction for the common case where TaskCompleted fires in non-review contexts.

**Warning signs:** Developers report that routine task completions (unrelated to code review tasks) are being blocked.

### Pitfall 4: `quality-gate-status.json` Path Resolution

**What goes wrong:** Hook reads `quality-gate-status.json` from the wrong directory. The file is at the project root, but the hook's `cwd` at invocation time may be a subdirectory.

**Why it happens:** Hook scripts inherit the cwd at the time the hook fires, which is where Claude Code is operating. If Claude cd'd into a subdirectory, the file lookup fails silently.

**How to avoid:** Use `$(pwd)/quality-gate-status.json` is not sufficient. Use `$CLAUDE_PROJECT_DIR/quality-gate-status.json` — this environment variable is set by Claude Code to the project root regardless of cwd.

**Warning signs:** Hook exits 0 (allows) when it should block, because it can't find the gate status file.

### Pitfall 5: `bd gate list` Labels Field Null Check

**What goes wrong:** The Stop hook uses `jq '[.[] | select(.labels[] | contains("c4flow-quality-gate"))]'`. If a gate has no `labels` field (null or empty array), `jq` throws an error and the hook exits non-zero, causing unexpected behavior.

**Why it happens:** `jq .labels[]` on a null value is a runtime error in jq.

**How to avoid:** Use `select(.labels != null and (.labels[] | contains("c4flow-quality-gate")))` — the null guard prevents the error. Or: `select((.labels // []) | map(contains("c4flow-quality-gate")) | any)`.

**Warning signs:** Stop hook fails with jq stderr output; bd gate list returns gates but some have no labels.

### Pitfall 6: Hook Script Not Executable

**What goes wrong:** Hook scripts are created but not marked executable (`chmod +x`). Claude Code cannot execute them. Hook fails silently or with a permission error.

**How to avoid:** `chmod +x .claude/hooks/*.sh` is a required step in every task that creates a hook script. The task for creating each script must include the chmod step.

**Warning signs:** Hook does not fire despite correct settings.json configuration.

---

## Code Examples

Verified patterns from official sources:

### PreToolUse — Deny with Rich Message

```bash
# Source: Claude Code hooks docs (code.claude.com/docs/en/hooks)
# Exit 0, JSON on stdout = structured response to Claude Code
jq -n \
  --arg reason "Quality gates not passed. Codex review: FAIL. Run /c4flow:review first. Gate: bd-xxxx" \
  '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
exit 0
```

### Stop Hook — Block with Remediation

```bash
# Source: Claude Code hooks docs (code.claude.com/docs/en/hooks)
# Stop hook blocks session end via {"decision": "block", "reason": "..."}
jq -n \
  --arg reason "2 quality gate(s) open. Run /c4flow:verify or resolve: bd gate resolve bd-xxxx --reason 'done'" \
  '{"decision": "block", "reason": $reason}'
exit 0
```

### TaskCompleted Hook — Block via Exit Code 2

```bash
# Source: Claude Code hooks docs (code.claude.com/docs/en/hooks)
# Exit code 2 = blocking error; stderr shown to user; blocks the action
echo "Quality gates not passed. Run /c4flow:review and /c4flow:verify." >&2
exit 2
```

### Read Hook Stdin Input

```bash
# Source: Claude Code hooks docs — all hooks receive JSON on stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // "unknown"')
```

### C4Flow Project Guard

```bash
# Source: Pitfall 11 — global hook fires on non-beads projects
# Guard must be first check in every hook script
[ -f ".bd" ] || exit 0
```

### Detect `bd close` Command (Without --force)

```bash
# Source: bd close --help (verified locally) — confirmed flag spellings
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

if echo "$COMMAND" | grep -qE 'bd\s+close'; then
  # Check if --force or -f is present — allow force-closes through
  if echo "$COMMAND" | grep -qE '(--force|-f)\b'; then
    exit 0  # Force bypass allowed
  fi
  # Proceed with gate check
fi
```

### jq Null-Safe Label Filter

```bash
# Source: jq docs — null-safe array traversal
OPEN_GATES=$(bd gate list --json 2>/dev/null | \
  jq '[.[] | select((.labels // []) | map(contains("c4flow-quality-gate")) | any)]')
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Global hooks in `~/.claude/settings.json` | Project-scoped hooks in `.claude/settings.json` | Claude Code hooks system maturity | Prevents cross-project pollution; safe to commit |
| Exit code 2 only for blocking | Exit 0 + JSON `permissionDecision: deny` | Claude Code hooks docs | Richer reason string shown to Claude; structured output |
| CLI `bd gate list` in every hook | File read for hot-path hooks (PreToolUse), CLI for stop-path hooks (Stop) | Phase 1 introducing `quality-gate-status.json` | ~100ms file read vs ~300ms CLI spawn for hot-path hook |
| No session-end gate enforcement | Stop hook blocks session end | Phase 2 | Closes the "agent declares done without bd close" gap |

**Confirmed from QUALITY-GATE.md research (HIGH confidence):**
- `PreToolUse` with `permissionDecision: deny` — confirmed blocking mechanism
- `Stop` with `{"decision": "block", "reason": "..."}` — confirmed blocking mechanism
- `TaskCompleted` hook type — confirmed exists, fires on task completion events

---

## Open Questions

1. **TaskCompleted hook — does it fire for agent-level task tracking or beads-level task tracking?**
   - What we know: TaskCompleted fires when Claude Code marks a task complete via the TaskUpdate mechanism (the `✓` check in agent task lists)
   - What's unclear: Whether it fires specifically when a beads task is closed via `bd close`, or only when Claude Code's internal task tracking marks a task done
   - Impact: If it fires only for Claude Code internal tasks (not `bd close`), the HOOK-03 requirement is partially satisfied but the beads-specific case (agent runs `bd close` from a task context) is covered by HOOK-01 instead
   - Recommendation: Implement HOOK-03 as designed and test empirically in Wave 0. If TaskCompleted doesn't fire for `bd close` events, that's acceptable — HOOK-01 already covers that path. HOOK-03 adds defense-in-depth for the task-tracking layer.
   - **This is the one behavior flagged as unconfirmed in STATE.md** — plan should include an explicit test task.

2. **`$CLAUDE_PROJECT_DIR` environment variable availability in hook scripts**
   - What we know: Documented in Claude Code hooks docs as available in hook environment
   - What's unclear: Exact behavior when hooks are invoked from subagent contexts (SubagentStart/SubagentStop events)
   - Recommendation: Use `$CLAUDE_PROJECT_DIR` as primary path. Add fallback: `${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}` for robustness.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Shell script integration tests (bash scripts) |
| Config file | None required |
| Quick run command | `bash .claude/tests/test-hook-bd-close.sh` |
| Full suite command | `bash .claude/tests/run-hooks-tests.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HOOK-01 | bd-close-gate.sh denies `bd close` when gates not passed | Integration | `bash .claude/tests/test-hook-bd-close.sh` | Wave 0 |
| HOOK-01 | bd-close-gate.sh passes `bd close` when `overall_pass=true` | Integration | `bash .claude/tests/test-hook-bd-close.sh` | Wave 0 |
| HOOK-01 | bd-close-gate.sh passes `bd close --force` regardless of gate status | Unit | `bash .claude/tests/test-hook-bd-close.sh` | Wave 0 |
| HOOK-02 | check-open-gates.sh blocks when c4flow-quality-gate label present | Integration | `bash .claude/tests/test-hook-stop.sh` | Wave 0 |
| HOOK-02 | check-open-gates.sh exits 0 when no open gates | Integration | `bash .claude/tests/test-hook-stop.sh` | Wave 0 |
| HOOK-03 | task-complete-gate.sh blocks when overall_pass=false | Unit | `bash .claude/tests/test-hook-taskcompleted.sh` | Wave 0 |
| HOOK-03 | task-complete-gate.sh passes when overall_pass=true | Unit | `bash .claude/tests/test-hook-taskcompleted.sh` | Wave 0 |
| INFR-02 | All three scripts exist and are executable | Unit | `bash .claude/tests/test-hook-files.sh` | Wave 0 |
| INFR-03 | settings.json contains valid hooks config with all three hooks | Unit | `bash .claude/tests/test-hook-settings.sh` | Wave 0 |

**Testing hooks without a live Claude Code session:**
Hook scripts are plain bash scripts. They can be tested by piping mock stdin JSON and checking exit codes and stdout. No live Claude Code session required for unit/integration tests.

```bash
# Example: test PreToolUse hook denies bd close when gates not passed
echo '{"tool_name":"Bash","tool_input":{"command":"bd close task-001"}}' | \
  bash .claude/hooks/bd-close-gate.sh
# Expected: exit 0, stdout contains permissionDecision=deny
```

### Sampling Rate

- **Per task commit:** `bash .claude/tests/test-hook-files.sh && bash .claude/tests/test-hook-settings.sh`
- **Per wave merge:** `bash .claude/tests/run-hooks-tests.sh`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `.claude/tests/test-hook-bd-close.sh` — covers HOOK-01 (pipe mock JSON, check deny output)
- [ ] `.claude/tests/test-hook-stop.sh` — covers HOOK-02 (requires temp beads DB with labeled gate)
- [ ] `.claude/tests/test-hook-taskcompleted.sh` — covers HOOK-03 (mock quality-gate-status.json)
- [ ] `.claude/tests/test-hook-files.sh` — covers INFR-02 (file existence + chmod check)
- [ ] `.claude/tests/test-hook-settings.sh` — covers INFR-03 (jq validation of settings.json)
- [ ] `.claude/tests/run-hooks-tests.sh` — test suite entry point for Phase 2

*(Existing `.claude/tests/` directory not yet created — Wave 0 creates it)*

---

## Sources

### Primary (HIGH confidence)

- Claude Code hooks docs (`code.claude.com/docs/en/hooks`) — fetched 2026-03-16, live official docs. Covers: all event types, stdin schema, exit code behavior, permissionDecision JSON format, Stop block format, TaskCompleted payload schema, timeout configuration, project-scoped vs global placement
- `bd close --help` (verified locally) — confirms `-f/--force` flag for unsatisfied gate bypass
- `bd gate --help`, `bd gate list --help`, `bd gate resolve --help` (verified locally) — confirms `--json` flag, `--label` filtering approach
- `.planning/research/QUALITY-GATE.md` — hook patterns, beads integration (researched 2026-03-16; HIGH confidence on hook mechanics)
- `.planning/research/PITFALLS.md` — Pitfall 11 (global hooks), Pitfall 12 (Stop loop) — prevention strategies
- `skills/review/SKILL.md`, `skills/verify/SKILL.md` — Phase 1 implementations; hooks read `quality-gate-status.json` schema established here

### Secondary (MEDIUM confidence)

- `$CLAUDE_PROJECT_DIR` environment variable in hook scripts — documented in Claude Code hooks docs; subagent context behavior not explicitly tested
- `bd gate list --json` output schema for `labels` field — confirmed `labels` field exists; null-safety of `labels` field (some gates may have no labels) is precautionary based on general beads behavior

### Tertiary (LOW confidence)

- `TaskCompleted` hook firing semantics for beads task close vs Claude Code task close — documented event type exists; exact trigger conditions for beads-specific closes require empirical validation

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — hook mechanics confirmed from live official docs; beads flags verified locally
- Architecture: HIGH — three-hook pattern established in QUALITY-GATE.md research; patterns fully worked out with verified exit codes and JSON schemas
- Pitfalls: HIGH — sourced from PITFALLS.md (prior research) plus new hook-specific pitfalls identified from live docs
- TaskCompleted hook behavior: LOW-MEDIUM — event type confirmed but exact beads-task firing semantics unconfirmed; flagged in Open Questions

**Research date:** 2026-03-16
**Valid until:** 2026-04-16 (Claude Code hooks API is stable; may change on major Claude Code version upgrades)
