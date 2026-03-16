---
phase: 02-safety-net-hooks
plan: "02"
subsystem: testing
tags: [bash, shell-scripts, testing, claude-hooks, beads, quality-gates, mock-stdin]

# Dependency graph
requires:
  - phase: 02-safety-net-hooks
    plan: "01"
    provides: bd-close-gate.sh, check-open-gates.sh, task-complete-gate.sh, settings.json hooks config
provides:
  - .claude/tests/test-hook-bd-close.sh — 13 assertions for PreToolUse bd-close-gate hook (HOOK-01)
  - .claude/tests/test-hook-stop.sh — 12 assertions for Stop check-open-gates hook (HOOK-02)
  - .claude/tests/test-hook-taskcompleted.sh — 6 assertions for TaskCompleted task-complete-gate hook (HOOK-03)
  - .claude/tests/test-hook-files.sh — 9 assertions for hook file existence and permissions (INFR-02)
  - .claude/tests/test-hook-settings.sh — 8 assertions for settings.json hooks config (INFR-03)
  - .claude/tests/run-hooks-tests.sh — Suite runner, 48 total assertions, all pass
affects: [03-integration-tests, any phase modifying hook scripts]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Mock bd command pattern: create fake bd script in TMPDIR/bin/, prepend to PATH in test subshell"
    - "Hook test pattern: pipe mock stdin JSON to hook script via echo '$json' | bash hook.sh"
    - "Subshell env export pattern: ( export VAR=val; cd dir; echo json | bash script ) 2>stderr — avoids env-only-applies-to-echo pitfall"
    - "Suite runner pattern: set -uo pipefail (not -euo) with arithmetic via $((N+1)) to avoid exit-1 on zero increment"

key-files:
  created:
    - .claude/tests/run-hooks-tests.sh
    - .claude/tests/test-hook-bd-close.sh
    - .claude/tests/test-hook-stop.sh
    - .claude/tests/test-hook-taskcompleted.sh
    - .claude/tests/test-hook-files.sh
    - .claude/tests/test-hook-settings.sh
  modified: []

key-decisions:
  - "Used subshell with explicit export for env vars in test — inline VAR=val echo ... | bash only applies vars to echo, not bash (pitfall discovered and fixed)"
  - "Suite runner uses $((N+1)) not ((N++)) to avoid set -e exit-1 on zero arithmetic result"
  - "run_hook function takes mandatory arg (no default) — default parameter with embedded braces causes double-} in echo output"

patterns-established:
  - "Subshell export pattern: ( export CLAUDE_PROJECT_DIR=...; export PATH=...; cd dir; echo json | bash hook ) 2>file"
  - "Mock bd: write_mock_bd function writes canned JSON output into TMPDIR/bin/bd"

requirements-completed: [HOOK-01, HOOK-02, HOOK-03, INFR-02, INFR-03]

# Metrics
duration: 6min
completed: 2026-03-16
---

# Phase 2 Plan 02: Hook Test Suite Summary

**Bash test suite with 48 assertions covering all three Claude Code hooks via mock stdin JSON — validates deny/allow/force/skip behaviors without needing a live Claude Code session**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-16T09:23:57Z
- **Completed:** 2026-03-16T09:29:55Z
- **Tasks:** 1 (Task 2 is a human-verify checkpoint — pending)
- **Files modified:** 6

## Accomplishments

- Created six test scripts in .claude/tests/ covering all five requirements (HOOK-01, HOOK-02, HOOK-03, INFR-02, INFR-03)
- 48 total test assertions, all passing — confirms hooks deny/allow/block/skip as designed
- Discovered and fixed inline env var scoping pitfall: `VAR=val echo | bash` only applies env to `echo`, not `bash`; fixed via subshell export pattern
- Suite runner handles script-level failures without aborting (set -uo not -euo)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create hook test suite with mock stdin testing** - `9513670` (feat)

**Plan metadata:** (docs commit — pending after checkpoint resolution)

## Files Created/Modified

- `.claude/tests/run-hooks-tests.sh` — Suite runner: runs all 5 test scripts sequentially, reports pass/fail count
- `.claude/tests/test-hook-bd-close.sh` — 13 assertions for bd-close-gate.sh: deny on open gates, allow on passed, allow --force, allow non-bd-close, deny missing file, skip non-beads
- `.claude/tests/test-hook-stop.sh` — 12 assertions for check-open-gates.sh: block on c4flow label, allow non-c4flow, allow empty, null labels graceful, skip non-beads
- `.claude/tests/test-hook-taskcompleted.sh` — 6 assertions for task-complete-gate.sh: block on open gates, allow passed, block missing file+gates, allow missing file+no gates, skip non-beads
- `.claude/tests/test-hook-files.sh` — 9 assertions for INFR-02: all 3 hook scripts exist, executable, correct shebang
- `.claude/tests/test-hook-settings.sh` — 8 assertions for INFR-03: valid JSON, all 3 hook types registered, correct paths, enabledPlugins preserved

## Decisions Made

- Used subshell with explicit `export` for env vars — `VAR=val echo ... | bash` only applies vars to `echo` LHS of pipeline, not `bash`; correct pattern is `( export VAR=val; cd dir; echo json | bash script )`
- Suite runner uses `$((N+1))` not `((N++))` — arithmetic `((0++))` returns exit 1 in bash with `set -e`, causing the runner to abort prematurely
- `run_hook` function takes a required argument (no default) — `${1:-{"key":"val"}}` default parameter with embedded `}` causes extra `}` appended to the echo output, producing malformed JSON

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed env var scoping in run_hook function (test-hook-taskcompleted.sh)**
- **Found during:** Task 1 (test suite creation), discovered at first test run
- **Issue:** `cd dir && VAR=val echo json | bash hook` — env vars only apply to `echo`, not `bash`. Hook resolved `CLAUDE_PROJECT_DIR` via git-toplevel fallback, reading wrong project's files, causing jq parse errors and wrong exit codes
- **Fix:** Changed run_hook to use `( export CLAUDE_PROJECT_DIR=...; export PATH=...; cd dir; echo json | bash hook ) 2>file`
- **Files modified:** .claude/tests/test-hook-taskcompleted.sh
- **Verification:** All 6 TaskCompleted tests pass with correct exit codes
- **Committed in:** 9513670 (Task 1 commit)

**2. [Rule 1 - Bug] Fixed arithmetic increment in suite runner (run-hooks-tests.sh)**
- **Found during:** Task 1 (test suite creation), discovered at first suite run
- **Issue:** `set -euo pipefail` combined with `((PASS_COUNT++))` — when PASS_COUNT is 0, `((0++))` evaluates as arithmetic false (exit 1), triggering `set -e` abort after first test script
- **Fix:** Changed `set -euo pipefail` to `set -uo pipefail` and replaced `((N++))` with `N=$((N+1))`
- **Files modified:** .claude/tests/run-hooks-tests.sh
- **Verification:** Suite runner now runs all 5 scripts and reports 5/5 passed
- **Committed in:** 9513670 (Task 1 commit)

**3. [Rule 1 - Bug] Fixed default parameter with embedded braces in run_hook (test-hook-taskcompleted.sh)**
- **Found during:** Task 1, second debug iteration
- **Issue:** `${1:-{"task_subject":"Implement auth"}}` — the trailing `}` of the JSON is consumed by the `${...}` parameter expansion, then an extra `}` is appended, producing `{"task_subject":"Implement auth"}}` which jq rejects
- **Fix:** Removed default value from parameter; all callers pass explicit JSON string
- **Files modified:** .claude/tests/test-hook-taskcompleted.sh
- **Verification:** Test 1 receives valid JSON, hook parses correctly, exit 2 as expected
- **Committed in:** 9513670 (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (3 Rule 1 bugs)
**Impact on plan:** All three bugs were in the test harness itself, not in the hook scripts being tested. No scope creep.

## Issues Encountered

None beyond the auto-fixed issues above — all resolved in the same commit.

## User Setup Required

None — test suite runs with `bash .claude/tests/run-hooks-tests.sh` from project root. No external dependencies beyond bash and jq (already required by hooks).

## Next Phase Readiness

- All hook test infrastructure is in place
- Task 2 (human-verify checkpoint) pending — user should review hook behavior and run the smoke test
- Phase 3 (integration tests) can build on this test infrastructure pattern

## Self-Check: PASSED

- FOUND: .claude/tests/run-hooks-tests.sh
- FOUND: .claude/tests/test-hook-bd-close.sh
- FOUND: .claude/tests/test-hook-stop.sh
- FOUND: .claude/tests/test-hook-taskcompleted.sh
- FOUND: .claude/tests/test-hook-files.sh
- FOUND: .claude/tests/test-hook-settings.sh
- FOUND commit: 9513670

---
*Phase: 02-safety-net-hooks*
*Completed: 2026-03-16*
