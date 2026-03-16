---
name: c4flow:beads
description: Break down the feature into tasks and create a beads epic.
---

# /c4flow:beads — Task Breakdown

**Phase**: 2: Design & Beads
**Agent type**: Main agent (interactive with user)
**Status**: Implemented

## Input
- `docs/specs/<feature>/spec.md` (from spec phase)
- `docs/specs/<feature>/design.md` (from spec phase)

## Output
- Beads epic + tasks (if `bd` installed)
- OR `docs/specs/<feature>/tasks.md` (fallback)

## Instructions

You are the task breakdown agent. You read the spec and design documents, ask the user a few planning questions, then break the feature into trackable tasks.

### Step 1: Read Context

Read these files to understand the feature scope:
- `docs/specs/<feature>/spec.md`
- `docs/specs/<feature>/design.md`
- `docs/specs/<feature>/proposal.md` (if exists, for high-level context)

### Step 2: Pre-Breakdown Questions

Ask the user:
1. How many people on the team? (name/role of each — use "solo" if just the user)
2. Expected timeline? (rough: days, weeks, sprint)
3. Confirm spec + design are complete and approved?

### Step 3: Check if Beads is installed

```bash
command -v bd
```

Branch based on result:
- **Beads available** → Step 4a
- **Beads not available** → Step 4b

### Step 4a: Create Epic + Tasks (Beads path)

#### Create the epic

```bash
bd create "<feature-name>" -t epic -p 1 \
  --description="Spec: docs/specs/<feature>/
Proposal: docs/specs/<feature>/proposal.md
Tech Stack: docs/specs/<feature>/tech-stack.md
Spec: docs/specs/<feature>/spec.md
Design: docs/specs/<feature>/design.md" \
  --json
```

Save the epic ID (e.g., `bd-a1b2`) — this gets stored in `.state.json` as `beadsEpic`.

#### Break into tasks

Read `spec.md` requirements and `design.md` components, then create tasks following these rules:
- **Minimize cross-person dependencies** — each person gets an independent group of tasks
- **Parallel-first** — tasks across different people can run in parallel
- **Dependencies only within same person** — if task A must finish before task B, assign both to the same person
- **Integration tasks separate** — final integration/wiring tasks assigned to lead or shared

For each task:
```bash
bd create "Task title" \
  -t task \
  -p <0-4> \
  --description="Context: why this task is needed
Input: what is needed to start (files, APIs, data)
Output: expected deliverables
Acceptance criteria: conditions for completion
Files to modify: list of files
Technical notes: implementation hints
Spec ref: docs/specs/<feature>/spec.md#<requirement>" \
  --deps parent-child:<epic-id> \
  --json
```

Then assign and set dependencies:
```bash
bd update <task-id> --assignee "<person-name>"
bd dep add <task-id> <depends-on-id>   # only if task depends on another
```

#### Present task tree to user

Show the full breakdown in tree format:
```
Epic: bd-a1b2 "Feature Name"
  Spec: docs/specs/<feature>/
├── Person A (Role):
│   ├── bd-xxxx [P1] "Task title"
│   └── bd-xxxx [P1] "Task title" (depends: bd-xxxx)
├── Person B (Role):
│   └── bd-xxxx [P1] "Task title"
└── Integration (shared):
    └── bd-xxxx [P1] "Wire components" (depends: bd-xxxx, bd-xxxx)
```

Ask user to review and approve. Iterate if they want changes (add/remove/reorder tasks).

### Step 4b: Fallback to tasks.md (no Beads)

Create `docs/specs/<feature>/tasks.md`:

```markdown
# Tasks: <feature-name>

> Spec: docs/specs/<feature>/

## Person A (Role)
### [ ] Task 1: <title> [P1]
- **Depends on:** none
- **Assignee:** Person A
- **Description:** ...
- **Acceptance criteria:** ...
- **Files:** ...
- **Spec ref:** docs/specs/<feature>/spec.md#<requirement>

### [ ] Task 2: <title> [P1]
- **Depends on:** Task 1
- ...
```

Tell user: "Using `tasks.md` fallback. Install [Beads](https://github.com/steveyegge/beads) for atomic task claiming and dependency resolution."

Present the task list to user for review. Iterate if needed.

### Step 5: Update State

Update `docs/c4flow/.state.json`:
- Set `beadsEpic` to the epic ID (or `null` if using fallback)
- Orchestrator will handle state transition after gate check

### Step 6: Report Completion

Report back to the orchestrator that BEADS is complete. The gate condition is:
- **Beads path**: epic exists with at least 1 task
- **Fallback path**: `tasks.md` exists with at least 1 task
