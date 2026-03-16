---
phase: 02-safety-net-hooks
plan: "01"
subsystem: infra
tags: [bash, claude-hooks, beads, quality-gates, shell-scripts]

# Dependency graph
requires:
  - phase: 01-local-gate-infrastructure
    provides: quality-gate-status.json schema with overall_pass, gate_id, checks fields
provides:
  - .claude/hooks/bd-close-gate.sh — PreToolUse hook intercepting bd close commands
  - .claude/hooks/check-open-gates.sh — Stop hook blocking session end with open gates
  - .claude/hooks/task-complete-gate.sh — TaskCompleted hook blocking task completion with open gates
  - .claude/settings.json — Hook registration config with PreToolUse, Stop, and TaskCompleted entries
affects: [03-integration-tests, any phase adding bd close automation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Hook safety net pattern: read-only hooks that read quality-gate-status.json and bd gate list; never write state"
    - "CLAUDE_PROJECT_DIR with git-toplevel fallback for robust path resolution in hook scripts"
    - "Null-safe jq label filter: (.labels // []) | map(contains(...)) | any"
    - ".bd project guard as first check in every hook script for project scoping"

key-files:
  created:
    - .claude/hooks/bd-close-gate.sh
    - .claude/hooks/check-open-gates.sh
    - .claude/hooks/task-complete-gate.sh
  modified:
    - .claude/settings.json

key-decisions:
  - "bd close --force bypasses hook (intentional escape hatch per RELS-03; auditing deferred to v2)"
  - "PreToolUse hook uses quality-gate-status.json file read (~100ms) not bd gate list CLI (~300ms) to avoid hot-path slowdown"
  - "Stop hook uses bd gate list --json for authoritative gate state (acceptable latency on stop path)"
  - "TaskCompleted missing-file case checks active gate count via bd gate list before blocking (Pitfall 3 prevention)"
  - "All hooks are project-scoped via .claude/settings.json (not global ~/.claude/settings.json)"

patterns-established:
  - "Hook guard pattern: [ -f '.bd' ] || exit 0 as first check in every hook"
  - "Path resolution: PROJECT_ROOT=${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
  - "PreToolUse deny: exit 0 with hookSpecificOutput JSON containing permissionDecision: deny"
  - "Stop block: exit 0 with JSON {decision: block, reason: ...} including exact gate IDs and remediation steps"
  - "TaskCompleted block: exit 2 with detailed stderr message"

requirements-completed: [INFR-02, INFR-03, HOOK-01, HOOK-02, HOOK-03]

# Metrics
duration: 2min
completed: 2026-03-16
---

# Phase 2 Plan 01: Safety Net Hooks Summary

**Three Claude Code hook scripts wiring quality-gate-status.json and bd gate list into PreToolUse/Stop/TaskCompleted event interception with .bd project-scoped guards**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-16T09:17:50Z
- **Completed:** 2026-03-16T09:19:53Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Created .claude/hooks/ directory with three executable hook scripts covering all three Claude Code hook event types required by Phase 2
- Updated .claude/settings.json to register all three hooks while preserving existing enabledPlugins config
- Implemented null-safe jq label filter in check-open-gates.sh to prevent runtime errors on gates without labels (Pitfall 5)
- Implemented missing-file heuristic in task-complete-gate.sh: if no gate status file AND no active gates, allow completion (Pitfall 3 prevention)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create hooks directory, settings.json config, and bd-close-gate.sh PreToolUse hook** - `570fef3` (feat)
2. **Task 2: Create check-open-gates.sh Stop hook and task-complete-gate.sh TaskCompleted hook** - `2b53926` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `.claude/settings.json` — Updated with hooks object (PreToolUse/Stop/TaskCompleted); existing enabledPlugins preserved
- `.claude/hooks/bd-close-gate.sh` — PreToolUse hook: intercepts bd close (not --force), reads quality-gate-status.json, denies with structured JSON showing codex/preflight status and gate ID
- `.claude/hooks/check-open-gates.sh` — Stop hook: queries bd gate list with null-safe c4flow-quality-gate label filter, blocks with gate list and remediation instructions
- `.claude/hooks/task-complete-gate.sh` — TaskCompleted hook: reads quality-gate-status.json, handles missing-file case with active gate count check, blocks via exit 2 with detailed status

## Decisions Made

- Used file read (not `bd gate list`) in PreToolUse and TaskCompleted hooks — file read is ~100ms vs ~300ms CLI spawn; prevents noticeable slowdown on every Bash tool call
- Stop hook uses `bd gate list --json` for authoritative state — acceptable latency since Stop fires once at session end
- TaskCompleted missing-file check queries active gate count before blocking — prevents false positives when working in a beads project that has no active review gates (Pitfall 3)
- `bd close --force` bypasses hook without logging — RELS-03 audit trail deferred to v2 per plan spec

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None — all scripts and verifications passed first attempt.

## User Setup Required

None — no external service configuration required. Hooks activate automatically via .claude/settings.json when Claude Code is used in this project.

## Next Phase Readiness

- All three hooks are in place and registered in settings.json
- Phase 3 (integration tests) can now test these hook scripts by piping mock stdin JSON
- Known open question: TaskCompleted hook firing semantics for beads-specific closes vs Claude Code internal task closes — requires empirical testing in Phase 3

## Self-Check: PASSED

- FOUND: .claude/settings.json
- FOUND: .claude/hooks/bd-close-gate.sh
- FOUND: .claude/hooks/check-open-gates.sh
- FOUND: .claude/hooks/task-complete-gate.sh
- FOUND: .planning/phases/02-safety-net-hooks/02-01-SUMMARY.md
- FOUND commit: 570fef3
- FOUND commit: 2b53926

---
*Phase: 02-safety-net-hooks*
*Completed: 2026-03-16*
