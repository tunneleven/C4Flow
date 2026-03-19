## Why

The `c4flow:code` and `c4flow:tdd` skills are stubs — they do nothing. The orchestrator treats CODE as a single flat phase, forcing TEST → REVIEW → PR as separate top-level states after all tasks are done. This means no per-task quality enforcement, no atomic traceability between beads and branches, and no resumability mid-task.

## What Changes

- Replace `c4flow:code` stub with a full task loop implementation
- Replace `c4flow:tdd` stub (merged into code skill as a sub-agent phase)
- **BREAKING**: Orchestrator `currentState: "CODE"` replaced by `"CODE_LOOP"`
- **BREAKING**: Top-level states `TEST`, `REVIEW`, `PR`, `MERGE` collapse into task loop sub-states
- Add `taskLoop` object to `.state.json` schema for per-task tracking
- Actor resolution: explicit arg → `BD_ACTOR` → `git config user.name`
- Branch strategy: one branch per task, named `feat/<bead-id>-<task-slug>`
- TDD cycle: sub-agent execution with mandatory RED gate pause for user approval
- Dolt sync on claim and on close (two sync points per task)
- Final state after all tasks complete advances to `DEPLOY` (skips old `PR` top-level state)

## Capabilities

### New Capabilities

- `task-pickup`: Actor-resolved task discovery via `bd ready`, atomic claim via `bd update --claim`, Dolt sync
- `task-branch-strategy`: One branch per task, `feat/<bead-id>-<task-slug>` naming, always cut from `main`
- `tdd-cycle`: Sub-agent TDD with RED gate pause, GREEN implementation, REFACTOR cleanup
- `task-verify`: Per-task validation — test suite + coverage + `bd preflight --check`
- `task-review`: Per-task Codex review via `c4flow:review`, CRITICAL/HIGH blocking
- `task-loop-state`: `taskLoop` schema in `.state.json` — subState, currentTaskId, currentBranch, completedTasks, failedTasks

### Modified Capabilities

- `orchestrator-states`: CODE_LOOP replaces CODE; TEST/REVIEW/PR/MERGE removed as top-level states; DEPLOY follows CODE_LOOP directly

## Impact

- `skills/code/SKILL.md` — full rewrite from stub
- `skills/tdd/SKILL.md` — merged into code skill, stub replaced with reference
- `skills/c4flow/SKILL.md` — orchestrator state machine updated (CODE_LOOP, removed intermediate states)
- `docs/c4flow/.state.json` — schema addition: `taskLoop` object
- No external API or dependency changes — uses existing `bd`, `git`, `c4flow:review`, `c4flow:pr`
