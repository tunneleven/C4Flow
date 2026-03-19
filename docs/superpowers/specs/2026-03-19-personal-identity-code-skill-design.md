# Personal Identity in Code Skill

**Date:** 2026-03-19
**Status:** Draft

## Problem

The `beads` skill correctly divides tasks among team members by assigning each task an `assignee`. However, `code` skill dispatches ALL ready tasks (from `bd ready`) to sub-agents — it has no concept of "who is running this machine right now." Everyone on the team would end up doing everyone else's tasks.

## Solution Overview

Introduce a local identity file `docs/c4flow/.personal.json` (gitignored) that stores "who I am on this machine." The `code` skill checks for this file before dispatching any tasks, prompts if missing, then filters `bd ready` output to only the current person's assigned tasks in the current epic.

**Scope:** Identity checking applies to the **Beads path only**. The `tasks.md` fallback is treated as single-user and skips identity resolution entirely.

## Storage

### `docs/c4flow/.personal.json` (local, gitignored)

```json
{ "name": "Hiep" }
```

- Never committed, never pushed
- `.gitignore` entry must be added as the **first commit** before any developer creates this file
- The `name` value must match the assignee name used in beads exactly (case-sensitive)
- **Solo projects:** Use `bd update --assignee "<name>"` instead of `--claim` during the beads phase so the assignee is a human name, not a system actor value

### `.state.json` (shared, committed)

No changes. Team member names live in beads as task assignees.

### Beads

No changes to the beads skill.

## Behavior

| Situation | Behavior |
|---|---|
| `.personal.json` does not exist | Fetch unique assignees from epic, ask user to pick, save to `.personal.json`, continue |
| `.personal.json` exists | Read name silently, no prompt |
| User wants to switch person | `rm docs/c4flow/.personal.json` then re-run `/c4flow:run` |
| Task has no assignee (null) | Skip with warning: "Task `<id>` has no assignee — skipping. Assign it in beads first." |
| Assignee list from epic is empty | Warn and halt: "No assignees found — run `bd update <task-id> --assignee <name>` for each task, then re-run" |
| Filtered list is empty (none match current user) | Halt before dispatch: "No tasks assigned to `<name>` in this epic. Check beads or switch identity with `rm docs/c4flow/.personal.json`." Do not advance state. |
| Task is `in_progress` and epic-scoped to current user | Already claimed — skip re-dispatch, treat as in-flight. Use `status == "in_progress"` to detect (not `assignee`, since `--claim` may overwrite the assignee field). |
| `tasks.md` fallback mode | Skip identity resolution — run all tasks as single-user |
| CODE→TEST gate in team mode | Gate fires when ALL tasks in epic are closed (unfiltered). The last team member to finish triggers the transition. Each person's run only dispatches their own tasks but checks full-epic completion. |

## Implementation Notes

### `bd` JSON field names

The implementer must verify the exact field names in `bd ready --json` and `bd show <id> --json` output before writing the jq expressions. Key fields to confirm:

- The field that links a ready task to its parent epic (may be `epicId`, `parentId`, `parent`, etc.)
- The assignee field on tasks (expected: `assignee`)
- The structure of child tasks in `bd show` output (may be `.children[]`, `.tasks[]`, or flat array)

Run `bd ready --json | jq '.[0] | keys'` and `bd show <id> --json | jq 'keys'` to verify before coding.

### `--claim` and assignee mutation

`bd update --claim` sets `assignee` to a system actor value, overwriting the human name. To detect in-progress tasks belonging to the current user on a restart, filter by `status == "in_progress"` scoped to the epic, not by `assignee == MY_NAME`.

## Changes Required

### 1. Repo root `.gitignore`

Add as the **first change committed**:

```
docs/c4flow/.personal.json
```

### 2. `skills/code/SKILL.md`

#### 2a. Insert **Step 0: Identity Check** before the `## Prerequisites` heading

```markdown
## Step 0: Identity Check

Applies to Beads path only. Skip if operating in tasks.md fallback mode.

1. Check `docs/c4flow/.personal.json`:
   - If it exists: read `name` → set `MY_NAME`, proceed
   - If missing: run the identity prompt below

2. **Identity prompt** (runs once per machine):
   - Get the epic ID: `EPIC_ID=$(jq -r '.beadsEpic' docs/c4flow/.state.json)`
   - List unique assignees from direct task children of the epic using `bd show "$EPIC_ID" --json`
     (verify exact child field name against live output before using)
   - If list is empty: warn "No assignees found — assign tasks in beads first, then re-run" and halt
   - Ask user: "Who are you on this project? Pick one: [list]"
   - Save: `echo '{"name":"<chosen>"}' > docs/c4flow/.personal.json`
   - Set `MY_NAME` and continue

> **To switch identity:** `rm docs/c4flow/.personal.json` then re-run `/c4flow:run`
```

#### 2b. Replace `bd ready --json` at dispatch sites with a single captured, filtered call

Under `### Step 2: Get Ready Tasks` and `### Step 3: Claim and Dispatch`, capture `bd ready --json` once and derive both warnings and filtered dispatch list from it:

```bash
# Capture once — scoped to current epic (verify exact field name for epic reference)
READY_JSON=$(bd ready --json | jq --arg epic "$EPIC_ID" '[.[] | select(.<epic-field> == $epic)]')

# Warn about unassigned tasks
echo "$READY_JSON" | jq -r '.[] | select(.assignee == null) | "WARNING: Task \(.id) has no assignee — skipping."'

# Filter to current user
MY_TASKS=$(echo "$READY_JSON" | jq --arg name "$MY_NAME" '[.[] | select(.assignee == $name)]')

# Guard: halt before dispatch if nothing to do
if [ "$(echo "$MY_TASKS" | jq 'length')" -eq 0 ]; then
  echo "No tasks assigned to $MY_NAME in this epic."
  echo "Check beads assignees or switch identity: rm docs/c4flow/.personal.json"
  exit 1
fi
```

At the top of Step 3, fetch in-progress tasks separately from the full epic view (`bd ready` only returns `open` tasks, so in-flight tasks must be sourced differently):

```bash
# Open tasks to dispatch (from MY_TASKS above)
TO_DISPATCH=$MY_TASKS

# In-flight tasks: already claimed on a previous run
IN_FLIGHT=$(bd show "$EPIC_ID" --json | \
  jq --arg name "$MY_NAME" '[.<child-field>[] | select(.assignee == $name and .status == "in_progress")]')
# (verify exact <child-field> name against live bd show output)

# Skip dispatch for IN_FLIGHT — already claimed
# Dispatch only TO_DISPATCH tasks
```

**Do NOT change** `bd ready --json` in:
- `### Step 4: Monitor Progress` — progress check, not dispatch
- `## Completion Gate` description — documentation only
- `## Implementation Notes` — documentation only

**Update** `### Step 6: Completion Check` — scope to current epic but NOT filtered by assignee (last team member to finish triggers the gate):

```bash
OPEN_COUNT=$(bd list --json 2>/dev/null | \
  jq --arg epic "$EPIC_ID" '[.[] | select(.<epic-field> == $epic and .status != "closed")] | length')
```

(Verify the exact epic field name — this fixes an existing bug where `bd list` was unscoped and counted tasks from all epics.)

## Out of Scope

- No `/c4flow:identity` slash command (can be added later if needed)
- No enforcement that all team members set identity before code runs
- No UI for listing active team members
