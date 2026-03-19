# Personal Identity in Code Skill

**Date:** 2026-03-19
**Status:** Approved

## Problem

The `beads` skill correctly divides tasks among team members by assigning each task an `assignee`. However, `code` skill dispatches ALL ready tasks (from `bd ready`) to sub-agents sequentially or in parallel — it has no concept of "who is running this machine right now." Everyone on the team would end up doing everyone else's tasks.

## Solution Overview

Introduce a local identity file `.personal.json` (gitignored) that stores "who I am on this machine." The `code` skill checks for this file before dispatching any tasks, prompts if missing, then filters `bd ready` output to only the current person's tasks.

## Storage

### `.personal.json` (local, gitignored)

Location: `docs/c4flow/.personal.json`

```json
{ "name": "Hiep" }
```

- Never committed, never pushed
- Added to `.gitignore`
- The `name` value must match the assignee name used in beads

### `.state.json` (shared, committed)

No changes. Team member names continue to live in beads as task assignees — no duplication into `.state.json`.

### Beads

No changes. The `beads` skill already asks "Team members?" in Step 2 and assigns tasks via `bd update --assignee "<name>"`. This is the source of truth for who is on the team and who owns which task.

## Behavior

| Situation | Behavior |
|---|---|
| `.personal.json` does not exist | `code` skill detects this, fetches unique assignees from the epic, asks user to pick, saves to `.personal.json`, continues |
| `.personal.json` exists | Read name silently, no prompt |
| User wants to switch person | Delete `docs/c4flow/.personal.json` and re-run |

## Changes Required

### 1. `.gitignore`

Add:
```
docs/c4flow/.personal.json
```

### 2. `skills/code/SKILL.md` — Add Step 0: Identity Check

Insert before the current "Prerequisites" section:

```
## Step 0: Identity Check

Check if the current user's identity is known:

```bash
PERSONAL_FILE="docs/c4flow/.personal.json"
if [ -f "$PERSONAL_FILE" ]; then
  MY_NAME=$(jq -r '.name' "$PERSONAL_FILE")
  echo "Identity: $MY_NAME"
else
  echo "NO_IDENTITY"
fi
```

If `NO_IDENTITY`:
1. Read the epic to get all unique assignees:
   ```bash
   bd show <epic-id> --json | jq -r '[.children[].assignee // empty] | unique[]'
   ```
2. Present the list to the user: "Who are you on this project? Pick one:"
3. Save their choice:
   ```bash
   echo '{"name": "<chosen-name>"}' > docs/c4flow/.personal.json
   ```
4. Continue with `MY_NAME` set.

### Task Filtering

After identity is resolved, filter `bd ready` to only this person's tasks:

```bash
bd ready --json | jq --arg name "$MY_NAME" '[.[] | select(.assignee == $name)]'
```

Only dispatch sub-agents for tasks in this filtered list. Tasks assigned to others are ignored — they will be picked up when those team members run `code` on their own machines.

## Out of Scope

- No `/c4flow:identity` slash command (can be added later if needed)
- No UI for listing who is currently active
- No enforcement that all team members have set identity before code runs
