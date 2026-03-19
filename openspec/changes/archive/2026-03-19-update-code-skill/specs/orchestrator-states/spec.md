## MODIFIED Requirements

### Requirement: CODE_LOOP replaces CODE as orchestrator state
The orchestrator `currentState` value `"CODE"` SHALL be replaced by `"CODE_LOOP"`. The states `TEST`, `REVIEW`, `PR`, and `MERGE` SHALL be removed as top-level orchestrator states. These phases occur as sub-states within `CODE_LOOP`.

#### Scenario: State machine advancement after BEADS
- **WHEN** BEADS phase gate passes
- **THEN** orchestrator advances `currentState` to `CODE_LOOP` (not `CODE`)

#### Scenario: Removed states no longer reachable
- **WHEN** orchestrator reads `.state.json`
- **THEN** states `TEST`, `REVIEW`, `PR`, `MERGE` are not valid `currentState` values

#### Scenario: CODE_LOOP completion
- **WHEN** `bd ready --assignee <actor>` returns empty (all tasks done)
- **THEN** orchestrator advances `currentState` to `DEPLOY`

### Requirement: Migration — existing CODE state
If an existing `.state.json` has `currentState: "CODE"`, the orchestrator SHALL treat it as `CODE_LOOP` with `taskLoop: null` and proceed from first ready task.

#### Scenario: Legacy state migration
- **WHEN** orchestrator reads `currentState: "CODE"` from `.state.json`
- **THEN** it writes `currentState: "CODE_LOOP"` and `taskLoop: null` before entering the loop
