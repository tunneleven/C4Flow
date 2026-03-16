---
name: c4flow:code
description: Execute code implementation via Superpowers subagent-driven workflow
---

# /c4flow:code — Code Execution

**Phase**: 3: Implementation
**Purpose**: turn approved planning artifacts into finished implementation work
**Role**: coordinator only; task execution happens downstream in Superpowers

## Overview

CODE is the implementation phase of C4Flow.

TDD behavior is merged into CODE through the downstream Superpowers execution path.
Do not build a second implementation workflow here.
This skill validates inputs, routes into the shared Superpowers process, and only advances when implementation work is actually closed.

Use this skill when:
- the top-level `c4flow` workflow has moved `docs/c4flow/.state.json` to `currentState = "CODE"`
- a previous CODE run needs to be resumed
- recovery is needed after interrupted implementation work

Direct invocation is allowed for recovery and manual resume, but the operator must still satisfy the same CODE prerequisites and exit gate.

## Inputs This Skill Requires

Implementation work must already be defined in one of these sources:

1. Beads issue graph and assigned tasks
2. `docs/specs/<feature-slug>/tasks.md`

Execution guidance must also already exist in one of these forms:

1. A GSD phase plan such as `.planning/phases/<phase>/<plan>.md`
2. A written implementation plan under `docs/superpowers/plans/`
3. Another project-approved planning artifact with concrete tasks

If neither a task source nor an execution plan exists, stop and recover the missing artifact before doing any implementation work.

## Prerequisite Checks

Run these checks in order before loading any implementation skill:

### 1. Read workflow state

Read `docs/c4flow/.state.json`.

Confirm:
- the file exists and is valid JSON
- `currentState` is `CODE` when this skill is reached from `c4flow`
- `feature.slug` is present so task paths can be resolved

If `docs/c4flow/.state.json` is missing:
- recover the workflow state file first
- if the workflow was never started, return to the orchestrator and run `/c4flow`

If `currentState` is not `CODE`:
- direct invocation is still allowed for recovery or manual resume
- explain that this run is outside the normal orchestrator path
- do not advance state until the CODE exit gate is satisfied

### 2. Confirm task source

Check for one of:
- a beads epic or assigned beads tasks linked from `docs/c4flow/.state.json`
- `docs/specs/<feature-slug>/tasks.md`

If both are missing, stop and recover task definition first.

Recovery commands:
- `/c4flow:beads`
- `bd ready --json`
- `bd show <id> --json`
- create `docs/specs/<feature-slug>/tasks.md`

### 3. Confirm execution plan

Check for a concrete implementation plan before dispatching work.

Accepted inputs include:
- `.planning/phases/<phase>/<plan>.md`
- `docs/superpowers/plans/<feature>-plan.md`
- a project-specific implementation plan already referenced by the current task source

If the plan is missing, stop and recover planning first.

Recovery commands:
- `$gsd-plan-phase <phase>`
- write the missing plan under `docs/superpowers/plans/`
- return to the planning step that should have produced the artifact

### 4. Confirm partial implementation context

Before starting new work, inspect whether CODE is already in progress:
- open beads task state if using beads
- read `docs/specs/<feature-slug>/tasks.md` if using checklist tracking
- look for a current worktree path in `docs/c4flow/.state.json`
- look for partial implementation commits or in-progress plan summaries

If partial work exists, prefer resume over restart.

## Superpowers Integration

This skill composes existing workflow skills. It does not replace them.

### Required skill order

1. Load `using-superpowers` first.
2. Then route implementation through `subagent-driven-development`.
3. Require `using-git-worktrees` before execution begins.

`using-superpowers` is mandatory because it enforces the project rule that relevant skills are checked before action.

`subagent-driven-development` is mandatory because it is the implementation engine for CODE.
That downstream workflow owns task-by-task execution, fresh subagents, review loops, and implementation sequencing.

`using-git-worktrees` is required setup before execution begins.
Implementation should not start on the main workspace unless the user explicitly accepts that risk.

### Downstream execution contract

After the prerequisite checks pass:

1. Load `using-superpowers`
2. Load `using-git-worktrees`
3. Load `subagent-driven-development`
4. Hand the chosen plan and task source to the Superpowers workflow

The downstream implementation/review agents follow the review loops defined by `subagent-driven-development`.
Do not restate those review prompts here.
Use that skill as the single source of truth.

## Execution Flow

Follow this route exactly:

1. Validate workflow state in `docs/c4flow/.state.json`
2. Confirm tasks exist in beads or `docs/specs/<feature-slug>/tasks.md`
3. Confirm a usable implementation plan exists
4. Enter the Superpowers workflow by loading `using-superpowers`
5. Set up an isolated execution environment with `using-git-worktrees`
6. Run the plan through `subagent-driven-development`
7. Verify all assigned tasks are closed
8. Only then advance CODE to TEST

The CODE → TEST transition is contingent on task completion, not on invocation of this skill.
If the implementation workflow ran but tasks are still open, remain in CODE.

### How to verify closure

Use the task source that drove execution:

- Beads: verify every assigned issue is closed
- `tasks.md`: verify every assigned task item is checked complete

If the plan created follow-up work that is not yet closed, CODE is still incomplete.

## State Update When CODE Is Finished

When the CODE gate passes, update `docs/c4flow/.state.json` with these exact effects:

- set `currentState` to `"TEST"`
- append `"CODE"` to `completedStates`
- reset `failedAttempts` to `0`
- clear `lastError`

Do not write those state changes before the task-closure check passes.

## Fallback and Failure Handling

### If Superpowers skills are unavailable

Stop and say that the CODE workflow cannot delegate safely.
Do not silently improvise a replacement workflow.

Manual fallback:
- execute from the existing approved plan
- keep work scoped to the same tasks
- preserve the same CODE → TEST gate
- document that Superpowers delegation was unavailable

### If task source is missing

Return to the task-definition step:
- `/c4flow:beads`
- `bd ready --json`
- create or repair `docs/specs/<feature-slug>/tasks.md`

### If execution plan is missing

Return to planning:
- `$gsd-plan-phase <phase>`
- create the missing implementation plan artifact

### If worktree setup is blocked

Do not continue into implementation until the workspace decision is explicit.
Resolve the worktree requirement via `using-git-worktrees` first.

### If implementation is partially complete but gate is not met

Resume the existing work instead of creating duplicate execution.
Stay in CODE until all assigned tasks are closed.

## Operator Checklist

- [ ] Read `docs/c4flow/.state.json`
- [ ] Confirm `currentState` is `CODE`, or note manual recovery mode
- [ ] Confirm beads or `docs/specs/<feature-slug>/tasks.md` exists
- [ ] Confirm an execution plan exists
- [ ] Load `using-superpowers`
- [ ] Run `using-git-worktrees`
- [ ] Delegate implementation to `subagent-driven-development`
- [ ] Verify all assigned tasks are closed
- [ ] Update `currentState` to `TEST`
- [ ] Append `CODE` to `completedStates`
- [ ] Reset `failedAttempts` to `0`
- [ ] Clear `lastError`

## Recovery Guidance

Use these exact recovery paths when prerequisites are missing:

- Missing workflow state: run `/c4flow`
- Missing task graph: run `/c4flow:beads`
- Missing GSD implementation plan: run `$gsd-plan-phase <phase>`
- Missing manual task file: create `docs/specs/<feature-slug>/tasks.md`
- Missing Superpowers skill availability: stop and execute manually from the approved plan

The skill is complete only when implementation is done and the workflow can truthfully move from CODE to TEST.
