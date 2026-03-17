---
name: c4flow:beads
description: Break down the feature into tasks and create a beads epic. Use when the user wants to plan work, decompose features into tasks, or set up a beads work graph for implementation. Also triggers when the user mentions task breakdown, epic creation, or work planning.
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

You are the task breakdown agent. You read the spec and design documents, ask the user a few planning questions, then break the feature into trackable tasks using the beads molecule model.

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
4. Any tasks that should run in a specific order, or are all tasks parallel? (beads defaults to parallel)

### Step 3: Check if Beads is installed and initialized

```bash
command -v bd 2>/dev/null && echo "BD_INSTALLED" || echo "BD_MISSING"
[ -d ".beads" ] && echo "BEADS_INIT" || echo "BEADS_NOT_INIT"
```

Branch based on result:

| `bd` installed? | `.beads/` exists? | Action |
|-----------------|-------------------|--------|
| Yes | Yes | → Step 4a (use Beads) |
| Yes | No | Run `bd init`, then → Step 4a |
| No | — | Offer to run `c4flow:init` skill. If user declines → Step 4b |

**If bd is missing**, tell the user:
> "Beads (bd) is not installed. I can set it up automatically with `/c4flow:init`, or fall back to tasks.md. Which do you prefer?"

If they choose init, invoke the `c4flow:init` skill, then return here.

**If bd is installed but .beads/ missing**, invoke the `c4flow:init` skill (it handles `bd init` + Dolt server with proper timeouts), then continue to Step 4a.

### Step 4a: Create Epic + Tasks (Beads path)

#### Check for duplicates first

Before creating anything, check for existing issues that might overlap:

```bash
bd duplicates --json 2>/dev/null
bd list --json 2>/dev/null | jq '[.[] | select(.status != "closed")]'
```

If open issues overlap with the planned work, present them to the user and ask whether to reuse, merge, or create fresh.

#### Create the epic

```bash
bd create "<feature-name>" -t epic -p 1 \
  --description="Spec: docs/specs/<feature>/
Proposal: docs/specs/<feature>/proposal.md
Tech Stack: docs/specs/<feature>/tech-stack.md
Spec: docs/specs/<feature>/spec.md
Design: docs/specs/<feature>/design.md" \
  -l "c4flow-epic,phase:beads" \
  --json
```

Save the epic ID (e.g., `bd-a1b2`) — this gets stored in `.state.json` as `beadsEpic`.

#### Break into tasks — the molecule model

Beads treats work graphs as **molecules**: children of an epic are parallel by default. Only add explicit `blocks` dependencies when a task genuinely cannot start until another finishes. This is a common mistake — numbered steps *feel* sequential but often aren't. Ask yourself: "Would starting task B *actually fail* if task A isn't done yet?" If not, leave them parallel.

Read `spec.md` requirements and `design.md` components, then create tasks following these rules:

- **Parallel by default** — tasks run concurrently unless explicitly sequenced
- **Use `blocks` for hard gates** — task B literally cannot start without task A's output (e.g., DB schema must exist before API layer)
- **Use `parent-child` for hierarchy** — all tasks belong to the epic via this dep type
- **Use `discovered-from`** when new tasks emerge during implementation — links back to the source task for traceability
- **Minimize cross-person dependencies** — each person gets an independent group of tasks
- **Integration tasks separate** — final integration/wiring tasks assigned to lead or shared

#### Dependency types reference

| Type | When to use | Effect on `bd ready` |
|------|-------------|---------------------|
| `parent-child` | Every task → epic | Hierarchy only, no blocking |
| `blocks` | Task B needs Task A's output | Task B hidden from `bd ready` until A closed |
| `discovered-from` | Bug found while working on a task | Non-blocking link for traceability |
| `related` | Loose connection between tasks | Non-blocking link |

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
  -l "<component-label>" \
  --json
```

Then assign and set dependencies:
```bash
bd update <task-id> --assignee "<person-name>"
# Only add blocks dep when task genuinely cannot start without the other
bd dep add <task-id> <depends-on-id>   # defaults to 'blocks' type
```

#### Labels for task categorization

Use lowercase, hyphen-separated labels to categorize tasks. Keep the set small (5-10 labels per project):

- **Component labels**: `backend`, `frontend`, `api`, `database`, `infra`
- **Size estimates**: `small` (<1 day), `medium` (1-3 days), `large` (>3 days)
- **Quality gates**: `needs-review`, `needs-tests`
- **C4Flow markers**: `c4flow-epic`, `phase:beads`, `phase:code`, `phase:test`

```bash
bd label add <task-id> backend,medium
```

#### Verify the work graph

After creating all tasks, verify the dependency graph is sound:

```bash
# Check for dependency cycles
bd dep cycles --json 2>/dev/null

# View the dependency tree
bd dep tree <epic-id>

# See what's ready to work on right now
bd ready --json
```

If cycles exist, fix them before proceeding.

#### Present task tree to user

Show the full breakdown in tree format:
```
Epic: bd-a1b2 "Feature Name"
  Spec: docs/specs/<feature>/
├── Person A (Role):
│   ├── bd-xxxx [P1] "Task title" [backend,medium]
│   └── bd-xxxx [P1] "Task title" (blocked by: bd-xxxx) [backend,small]
├── Person B (Role):
│   └── bd-xxxx [P1] "Task title" [frontend,medium]
└── Integration (shared):
    └── bd-xxxx [P1] "Wire components" (blocked by: bd-xxxx, bd-xxxx) [small]

Ready now: bd-xxxx, bd-xxxx, bd-xxxx (3 tasks can start in parallel)
Blocked: bd-xxxx, bd-xxxx (2 tasks waiting on dependencies)
```

Also show the output of `bd ready --json` to highlight which tasks can start immediately.

Ask user to review and approve. Iterate if they want changes (add/remove/reorder tasks).

### Step 4b: Fallback to tasks.md (no Beads)

Create `docs/specs/<feature>/tasks.md`:

```markdown
# Tasks: <feature-name>

> Spec: docs/specs/<feature>/

## Person A (Role)
### [ ] Task 1: <title> [P1]
- **Depends on:** none (parallel)
- **Assignee:** Person A
- **Description:** ...
- **Acceptance criteria:** ...
- **Files:** ...
- **Spec ref:** docs/specs/<feature>/spec.md#<requirement>

### [ ] Task 2: <title> [P1]
- **Depends on:** Task 1 (blocks — needs DB schema)
- ...
```

Tell user: "Using `tasks.md` fallback. Run `/c4flow:init` to install Beads for atomic task claiming and dependency resolution."

Present the task list to user for review. Iterate if needed.

### Step 5: Update State

Update `docs/c4flow/.state.json`:
- Set `beadsEpic` to the epic ID (or `null` if using fallback)
- Orchestrator will handle state transition after gate check

### Step 6: Report Completion

Report back to the orchestrator that BEADS is complete. The gate condition is:
- **Beads path**: epic exists with at least 1 task
- **Fallback path**: `tasks.md` exists with at least 1 task

Also report:
```bash
bd stats --json 2>/dev/null   # project-wide stats for context
```
