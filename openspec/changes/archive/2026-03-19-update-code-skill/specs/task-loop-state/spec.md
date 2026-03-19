## ADDED Requirements

### Requirement: taskLoop schema in .state.json
The `.state.json` file SHALL include a `taskLoop` object when `currentState` is `CODE_LOOP`. The object SHALL be `null` when no task is active.

#### Scenario: taskLoop structure
- **WHEN** a task is claimed
- **THEN** `.state.json` taskLoop contains: `currentTaskId`, `currentTaskSlug`, `currentBranch`, `subState`, `completedTasks`, `failedTasks`

#### Scenario: taskLoop null on start
- **WHEN** CODE_LOOP state is entered for the first time
- **THEN** `taskLoop` is `null` until first task is claimed

### Requirement: subState tracking
The `taskLoop.subState` field SHALL reflect the current phase within the task loop. Valid values are `CODING`, `VERIFYING`, `REVIEWING`, `CLOSING`.

#### Scenario: subState transitions
- **WHEN** TDD sub-agent dispatched → subState is `CODING`
- **WHEN** TDD done, running tests → subState is `VERIFYING`
- **WHEN** verify passes, review dispatched → subState is `REVIEWING`
- **WHEN** review passes, PR merged → subState is `CLOSING`

### Requirement: completedTasks log
Each completed task SHALL be appended to `taskLoop.completedTasks` with `id`, `pr` number, and `mergedAt` timestamp.

#### Scenario: Task completion recorded
- **WHEN** task PR is merged and `bd close` succeeds
- **THEN** `{ "id": "<bead-id>", "pr": <number>, "mergedAt": "<ISO timestamp>" }` is appended to `completedTasks`

### Requirement: Resumability
If the skill is interrupted, resuming with the same `currentState: CODE_LOOP` SHALL read `taskLoop` and continue from `subState` rather than starting over.

#### Scenario: Resume from VERIFYING
- **WHEN** skill resumes and `taskLoop.subState` is `VERIFYING`
- **THEN** skill re-runs test suite and bd preflight without re-doing the TDD cycle

#### Scenario: Resume from REVIEWING
- **WHEN** skill resumes and `taskLoop.subState` is `REVIEWING`
- **THEN** skill re-dispatches `c4flow:review` without re-running TDD or verify
