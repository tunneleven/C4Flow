---
name: c4flow:code
description: Execute code implementation via sub-agents, one per task. Uses the beads agent loop (bd ready → claim → implement → close → repeat) to coordinate parallel work across sub-agents. Trigger when the user wants to start coding, implement tasks, or run the implementation phase.
---

# /c4flow:code — Subagent-Driven Code Execution

**Phase**: 3: Implementation
**Agent type**: Main agent (coordinator), dispatches subagents per task

Execute plan by dispatching a fresh subagent per task, with two-stage review after each: spec compliance first, then code quality.

**Why subagents:** Fresh context per task prevents pollution. You construct exactly what each subagent needs — they never inherit session history. This preserves your context for coordination.

**Core principle:** Parallel dispatch for independent tasks + two-stage review (spec then quality) per task = high quality, fast iteration

**Parallel by default:** Dispatch all ready (unblocked) tasks simultaneously. `bd ready` surfaces tasks with no open blockers — these can safely run in parallel. Sequential execution only when tasks have explicit dependencies.


## Step 0: Identity Check

Applies to Beads path only. Skip entirely if `taskSource` in `.state.json` is not `beads` (i.e., operating in `tasks.md` fallback mode — run all tasks as single-user).

1. **Check `docs/c4flow/.personal.json`:**
   - If it exists: `MY_NAME=$(jq -r '.name' docs/c4flow/.personal.json)` — proceed to Prerequisites
   - If missing: run the identity prompt below

2. **Identity prompt** (runs once per machine):

   ```bash
   EPIC_ID=$(jq -r '.beadsEpic' docs/c4flow/.state.json)

   # List unique assignees from epic children
   ASSIGNEES=$(bd children "$EPIC_ID" --json 2>/dev/null \
     | jq -r '[.[].assignee // empty] | unique[]')
   ```

   - If `$ASSIGNEES` is empty: print `"No assignees found in epic — assign tasks in beads first: bd update <task-id> --assignee <name>, then re-run."` and exit.
   - Present the list and ask the user: **"Who are you on this project? Pick one: [list]"**
   - Save the choice:
     ```bash
     printf '{"name":"%s"}\n' "<chosen-name>" > docs/c4flow/.personal.json
     ```
   - Set `MY_NAME` and continue to Prerequisites.

> **To switch identity:** `rm docs/c4flow/.personal.json` then re-run `/c4flow:run`

---

## Prerequisites

Before dispatching any subagent:

1. **Read workflow state** — `docs/c4flow/.state.json`
   - Confirm `currentState` is `CODE`
   - Extract `feature.slug`, `taskSource`, `beadsEpic`

2. **Load tasks** — from Beads or `tasks.md`:

   **Beads path** (preferred):
   ```bash
   # MY_NAME resolved in Step 0 — only load tasks for current user
   bd list --parent "$EPIC_ID" --ready --assignee "$MY_NAME" --json
   ```
   For full epic view (all members):
   ```bash
   bd children "$EPIC_ID" --json
   ```

   **Fallback path** (single-user, skip identity):
   Read `docs/specs/<feature-slug>/tasks.md`

3. **Load execution plan** — resolve in order:
   - `.state.json` → `implementationPlan` field
   - `.planning/phases/...` current phase plan
   - `docs/c4flow/plans/YYYY-MM-DD-<feature-slug>.md`

   If no plan exists, create one under `docs/c4flow/plans/` before writing code.

4. **Extract all tasks with full text** — read the plan once, extract every task with its complete description, acceptance criteria, and context. Do not make subagents read the plan file.

## Execution Flow

```
┌─────────────────────────────────────────────────────┐
│ Read plan → Extract all tasks → Claim in Beads      │
│                                                     │
│ For each task:                                      │
│   ├── Dispatch implementer subagent                 │
│   │   ├── Asks questions? → Answer, re-dispatch     │
│   │   └── Implements, tests, commits, self-reviews  │
│   ├── Dispatch spec reviewer subagent               │
│   │   ├── Issues? → Implementer fixes → re-review   │
│   │   └── Spec compliant                            │
│   ├── Dispatch code quality reviewer subagent       │
│   │   ├── Issues? → Implementer fixes → re-review   │
│   │   └── Quality approved                          │
│   └── Close task in Beads (or check off tasks.md)   │
│                                                     │
│ After all tasks closed:                             │
│   └── Advance state CODE → TEST                     │
│       (full-branch review deferred to REVIEW phase) │
└─────────────────────────────────────────────────────┘
```

## Task Lifecycle (Beads)

For each task being executed:

```bash
# 1. Claim before starting
bd update <task-id> --claim --json

# 2. After implementation + review passes
bd close <task-id> --reason "CODE: implemented and reviewed" --json

# 3. If follow-up work discovered during implementation
bd create "Follow-up: <title>" --description="..." -p 1 \
  --deps discovered-from:<parent-id> --json

# 4. When all tasks done, sync
bd dolt push
```

**If Beads is unavailable**, fall back to `tasks.md`: mark items with `[x]` as complete.

## Task Lifecycle (tasks.md fallback)

For each task in `docs/specs/<feature-slug>/tasks.md`:
1. Note which task you're starting
2. After implementation + review passes, mark `[x]` in the file
3. Continue to next task

## Dispatching Subagents

### Implementer

For each task, dispatch a fresh subagent using the template at `skills/code/implementer-prompt.md`.

Provide:
- Full task text (from your extracted plan — don't make them read files)
- Scene-setting context (where this fits, dependencies, architecture)
- Working directory
- Beads task ID (if using Beads)

### Model Selection

**Mechanical tasks** (isolated functions, clear specs, 1-2 files): use `model: "haiku"`.
**Integration tasks** (multi-file coordination, pattern matching): use `model: "sonnet"`.
**Architecture/design tasks** (broad codebase understanding): use default model.

Complexity signals:
- 1-2 files with complete spec → haiku
- Multiple files with integration → sonnet
- Design judgment or broad understanding → default

### Handling Implementer Status

**DONE:** Proceed to spec compliance review.

**DONE_WITH_CONCERNS:** Read concerns. If about correctness/scope, address before review. If observations, note and proceed.

**NEEDS_CONTEXT:** Provide missing context, re-dispatch.

**BLOCKED:** Assess:
1. Context problem → provide more context, re-dispatch same model
2. Task too hard → re-dispatch with more capable model
3. Task too large → break into smaller pieces
4. Plan wrong → ask the user

Never force retry without changes.

### Spec Compliance Reviewer

After implementer reports DONE, dispatch a reviewer using `skills/code/spec-reviewer-prompt.md`.

Provide:
- Full task requirements (same text given to implementer)
- Implementer's report (what they claim they built)

If issues found → implementer fixes → re-review. Repeat until ✅.

### Code Quality Reviewer

After spec compliance passes, dispatch using `skills/code/code-quality-reviewer-prompt.md`.

Provide:
- Implementer's report
- Task requirements
- Git SHAs (base and head)

If issues found → implementer fixes → re-review. Repeat until ✅.

## Completion Gate

CODE is complete when:
- **Beads**: every assigned task is closed (`bd ready --json` returns empty for this epic)
- **tasks.md**: every task item is checked `[x]`

Each task was already spec-reviewed and quality-reviewed inline. The full-branch review happens in `c4flow:review` (after TEST), not here.

Only then advance state:

```bash
jq '
  .currentState = "TEST"
  | .completedStates += ["CODE"]
  | .failedAttempts = 0
  | .lastError = null
' docs/c4flow/.state.json > docs/c4flow/.state.json.tmp \
  && mv -f docs/c4flow/.state.json.tmp docs/c4flow/.state.json
```

## What Happens Next

```
CODE (you are here)
  → TEST    — c4flow:test runs full test suite, checks coverage
  → REVIEW  — c4flow:review runs Codex review on full branch diff vs main
  → VERIFY  — c4flow:verify runs bd preflight, combines with Codex results
  → PR      — c4flow:pr creates the pull request
```

The per-task reviews in CODE catch task-level issues. The full-branch Codex review in REVIEW catches cross-task integration issues, security concerns, and anything the per-task reviews missed.

## Rules

**Never:**
- Start on main/master without explicit user consent
- Skip reviews (spec compliance OR code quality)
- Proceed with unfixed issues
- Run tasks with dependencies in parallel — `bd ready` ensures only unblocked tasks are dispatched; trust it
- Make subagent read plan file (provide full text)
- Skip scene-setting context
- Ignore subagent questions
- Start code quality review before spec compliance passes
- Move to next task while review has open issues

**If subagent asks questions:** Answer clearly and completely. Don't rush.

**If reviewer finds issues:** Implementer fixes → reviewer re-reviews → repeat until approved.

**If subagent fails:** Dispatch fix subagent with specific instructions. Don't fix manually (context pollution).

## Prompt Templates

- `skills/code/implementer-prompt.md`
- `skills/code/spec-reviewer-prompt.md`
- `skills/code/code-quality-reviewer-prompt.md`

---

## Beads Agent Loop Integration

**Agent type**: Main agent (dispatches sub-agents)
**Status**: Implemented

## Overview

This skill drives the implementation phase by following the beads agent loop pattern. It queries `bd ready` for unblocked tasks, dispatches sub-agents to implement them in parallel, and closes tasks as they complete — naturally unblocking downstream work.

The key insight from the beads architecture: tasks are **parallel by default**. The `bd ready` command surfaces all tasks with no open blockers, so multiple sub-agents can work simultaneously on independent tasks. As each task closes, `bd ready` automatically surfaces newly unblocked downstream tasks.

## Input
- Beads epic ID from `docs/c4flow/.state.json` (`beadsEpic` field)
- `docs/specs/<feature>/spec.md` — feature requirements
- `docs/specs/<feature>/design.md` — architecture decisions
- `docs/specs/<feature>/tech-stack.md` — technology choices

## Output
- Implemented code for all tasks in the epic
- Each task closed with `--reason` for audit trail
- Issues discovered during work tracked via `discovered-from` dependency

## Gate Condition
```
CODE -> TEST: All tasks in epic are closed (status: closed)
```

## Instructions

You are the code execution agent. You coordinate sub-agents to implement all tasks in the beads epic, following the agent loop pattern.

### Step 1: Read Context and Verify State

```bash
# Read the epic ID from state
EPIC_ID=$(jq -r '.beadsEpic // empty' docs/c4flow/.state.json 2>/dev/null)
FEATURE_SLUG=$(jq -r '.feature.slug // empty' docs/c4flow/.state.json 2>/dev/null)

if [ -z "$EPIC_ID" ]; then
  echo "ERROR: No beads epic found. Run /c4flow:beads first."
  exit 1
fi

# Verify the epic exists and has tasks
bd show "$EPIC_ID" --json
bd dep tree "$EPIC_ID"
```

Read the spec files:
- `docs/specs/<feature>/spec.md`
- `docs/specs/<feature>/design.md`
- `docs/specs/<feature>/tech-stack.md`

### Step 2: Get Ready Tasks

Query beads for tasks that are ready **for the current user** in the current epic:

```bash
# MY_NAME is set in Step 0
# EPIC_ID is read from .state.json
MY_TASKS=$(bd list --parent "$EPIC_ID" --ready --assignee "$MY_NAME" --json 2>/dev/null)

# Warn about unassigned tasks in the epic that may be skipped by everyone
bd list --parent "$EPIC_ID" --ready --no-assignee --json 2>/dev/null \
  | jq -r '.[] | "WARNING: Task \(.id) has no assignee — skipping. Assign it in beads first."'

# Guard: halt if no tasks for this user
if [ "$(echo "$MY_TASKS" | jq 'length')" -eq 0 ]; then
  echo "No ready tasks assigned to $MY_NAME in this epic."
  echo "Either all your tasks are done, blocked, or wrong identity."
  echo "To switch identity: rm docs/c4flow/.personal.json"
  exit 1
fi
```

If no tasks are ready but tasks remain open, check what's blocking:

```bash
bd blocked --json
```

### Step 3: Claim and Dispatch — The Agent Loop

Before dispatching, split tasks into new work and already-claimed in-flight work (handles restart scenarios):

```bash
# Separate open tasks (to dispatch) from in-flight tasks (already claimed on a previous run)
# Filter in-flight by status only — NOT assignee, since --claim may overwrite the assignee field
TO_DISPATCH=$(echo "$MY_TASKS" | jq '[.[] | select(.status == "open")]')

IN_FLIGHT=$(bd children "$EPIC_ID" --json 2>/dev/null \
  | jq '[.[] | select(.status == "in_progress")]')

# For IN_FLIGHT tasks: skip dispatch — they are already being worked on
# For TO_DISPATCH tasks: claim and dispatch as normal
```

For each batch of ready tasks, follow this loop:

```
┌─────────────────────────────────────┐
│  MY_TASKS (filtered to current user)│
│  ↓                                  │
│  For each task in TO_DISPATCH:      │
│    1. bd update <id> --claim        │
│    2. Dispatch sub-agent            │
│    3. Sub-agent implements          │
│    4. bd close <id> --reason "..."  │
│  ↓                                  │
│  New tasks unblocked → loop back    │
└─────────────────────────────────────┘
```

#### Claiming a task

Before dispatching, claim the task so other agents don't pick it up:

```bash
bd update <task-id> --claim --json
```

This sets `status: in_progress` and `assignee` to the current actor.

#### Dispatching sub-agents

Dispatch one sub-agent per ready task. Independent tasks (all returned by `bd ready`) run in **parallel** — this is the key advantage of the dependency graph model.

**Sub-agent prompt template:** Use `skills/code/implementer-prompt.md`. Fill in the task ID, title, full description, feature context paths, and working directory. Do not make the subagent read the plan file — paste the full task text directly into the prompt.

#### Handling discovered issues

When a sub-agent reports discovering a new issue during implementation, create it with a `discovered-from` link:

```bash
bd create "Discovered: <issue-title>" \
  -t bug \
  -p <priority> \
  --description="<issue-description>
Discovered while implementing: <source-task-id>" \
  --deps discovered-from:<source-task-id> \
  -l "discovered,needs-triage" \
  --json
```

The `discovered-from` dependency is **non-blocking** — it's a traceability link, not a gate. The discovered issue will be triaged separately.

#### Closing completed tasks

After a sub-agent finishes successfully:

```bash
bd close <task-id> --reason "Implemented: <brief summary of what was done>. Files: <key files changed>"
```

The `--reason` flag is required for audit trail. Without it, the closure lacks context for future reference.

### Step 4: Monitor Progress

After each batch of sub-agents completes, check progress:

```bash
# See what's newly unblocked
bd ready --json

# Check overall epic progress
bd dep tree "$EPIC_ID"

# Quick stats
bd stats --json 2>/dev/null
```

If new tasks became ready (because their blockers just closed), loop back to Step 3.

### Step 5: Handle Edge Cases

#### All tasks blocked (circular dependency)

```bash
bd dep cycles --json 2>/dev/null
```

If cycles exist, present them to the user and ask which dependency to remove.

#### Sub-agent fails

If a sub-agent cannot complete its task:
1. Do NOT close the task
2. Add a comment with the failure reason:
   ```bash
   bd comment <task-id> "Implementation failed: <reason>"
   ```
3. Update the task with error context:
   ```bash
   bd update <task-id> --status open -l "blocked,needs-help"
   ```
4. Report to the user and ask for guidance

#### Task depends on external input

If a task is blocked on something outside the codebase (API key, external service, user decision):
1. Add a comment explaining the blocker
2. Move on to other ready tasks
3. Report the blocked task to the user

### Step 6: Completion Check

When `bd ready --json` returns empty AND no tasks are `in_progress`:

```bash
# Verify all tasks under the epic are closed
OPEN_COUNT=$(bd list --json 2>/dev/null | \
  jq --arg epic "$EPIC_ID" '[.[] | select(.status != "closed")] | length')

if [ "$OPEN_COUNT" -eq 0 ]; then
  echo "All tasks complete. Ready for testing phase."
else
  echo "$OPEN_COUNT tasks still open."
fi
```

If all tasks are closed, report completion to the orchestrator.

If discovered issues remain open, present them to the user:
```bash
bd list --json 2>/dev/null | \
  jq '[.[] | select(.status != "closed") | select(.labels[]? | contains("discovered"))]'
```

Ask: "These issues were discovered during implementation. Should we address them now or defer to a follow-up?"

### Step 7: Sync (Team Mode)

If working with a team or DoltHub remote:

```bash
bd dolt push 2>/dev/null
```

This syncs task state to the remote so other team members see the progress.

## Implementation Notes

- **Parallel dispatch is the default.** If `bd ready` returns 3 tasks, dispatch 3 sub-agents simultaneously. Sequential execution is a last resort.
- **`bd ready` is the source of truth.** Never manually decide what to work on — let the dependency graph determine readiness.
- **Claim before starting.** `bd update --claim` prevents duplicate work when multiple agents run concurrently.
- **Always close with `--reason`.** The audit trail is valuable for review and debugging later.
- **`discovered-from` for traceability.** New issues found during work get linked back to the source task, building a traceable web of work.
- **Never resolve issues you didn't work on.** Each sub-agent closes only its own task.
