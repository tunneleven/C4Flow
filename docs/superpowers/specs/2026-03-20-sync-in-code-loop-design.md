# Design: Auto-sync on CODE_LOOP Entry

**Date:** 2026-03-20
**Status:** Approved

## Problem

When a team member clones the repo and runs `c4flow:code` to pick up a task, their local Dolt beads database and git branch may be stale. Without syncing first, `bd ready` may show an outdated task list — tasks already claimed by others, or new tasks not yet visible.

Currently `c4flow:code` only does outbound sync (`bd dolt push`) after claiming and closing tasks. There is no inbound sync at session start.

## Decision

Add **Step 0.5: Pre-flight Sync** to `skills/code/SKILL.md`, between Step 0 (Read State) and Step 1 (PICKUP). This step invokes `c4flow:sync` automatically before any task discovery.

## Assumptions

- Members clone the repo; `.state.json` and Dolt DB are already initialized with `doltRemote` configured
- `c4flow:init` has been run previously (not part of this change)
- `c4flow:sync` is the single source of truth for sync logic — no duplication

## Design

### Location of Change

One file only: `skills/code/SKILL.md`

New step order:
```
Step 0   → Read State + Resolve Actor
Step 0.5 → Pre-flight Sync            ← NEW
Step 1   → PICKUP: Find and Claim Task
...
```

### Step 0.5 Logic

```
Invoke c4flow:sync.

On success:
→ Proceed to Step 1: PICKUP

On failure (any sync error):
→ Show error verbatim
→ Ask user:
    [continue] Proceed with local data (may be stale)
    [stop]     Exit CODE_LOOP to fix sync issue

If [continue]: proceed to Step 1, carry warning in session context
If [stop]: exit skill, leave .state.json unchanged
```

### Resume Behavior

Step 0.5 runs on both fresh starts and resumes, **except** when `taskLoop.subState == "CLOSING"`:

| subState on resume | Run Step 0.5? | Reason |
|--------------------|---------------|--------|
| null (fresh start) | ✅ Yes | Always sync on entry |
| CODING | ✅ Yes | Session resumed after gap |
| VERIFYING | ✅ Yes | Session resumed after gap |
| REVIEWING | ✅ Yes | Session resumed after gap |
| CLOSING | ❌ Skip | Only needs outbound push, no pull needed |
| BLOCKED | ✅ Yes | Sync may unblock if issue was remote state |

### Sync Frequency

Step 0.5 runs **once per CODE_LOOP session entry**, not once per task. Per-task sync is already handled by:
- `bd dolt push` at claim (Step 1)
- `bd dolt push` at close (Step 7)

## Files Changed

| File | Change |
|------|--------|
| `skills/code/SKILL.md` | Add Step 0.5 between Step 0 and Step 1 |

`skills/sync/SKILL.md` — **no changes**. Called as-is.

## Out of Scope

- Modifying `c4flow:sync` itself
- Adding sync to other phases (RESEARCH, SPEC, BEADS, etc.)
- Hook-based automatic sync
- Sync on every task iteration (not needed given per-task `bd dolt push`)
