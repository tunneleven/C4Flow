## ADDED Requirements

### Requirement: Actor resolution
The skill SHALL resolve the acting user identity in order: explicit argument → `BD_ACTOR` env var → `git config user.name`. The resolved actor SHALL be used for both task filtering and claiming.

#### Scenario: Explicit assignee in argument
- **WHEN** skill is invoked with "pickup task from Alice" or `--assignee Alice`
- **THEN** actor is set to "Alice" for both `bd ready --assignee` and `bd update --claim`

#### Scenario: BD_ACTOR fallback
- **WHEN** no explicit assignee is provided and `BD_ACTOR` env var is set
- **THEN** actor is set to `BD_ACTOR` value

#### Scenario: git config fallback
- **WHEN** no explicit assignee and no `BD_ACTOR` set
- **THEN** actor is set to `git config user.name`

### Requirement: Unblocked task discovery
The skill SHALL use `bd ready --assignee <actor> --json` to find truly unblocked tasks. It SHALL NOT use `bd list --status open` as it does not apply blocker-aware semantics.

#### Scenario: Tasks available
- **WHEN** `bd ready --assignee <actor>` returns one or more tasks
- **THEN** skill presents the list and prompts user to confirm or select

#### Scenario: No tasks available
- **WHEN** `bd ready --assignee <actor>` returns empty
- **THEN** skill reports "No unblocked tasks assigned to <actor>" and exits cleanly

### Requirement: Atomic task claim
The skill SHALL claim the selected task using `bd update <id> --claim`. If the claim fails (task already claimed), the skill SHALL re-run discovery and present an updated list.

#### Scenario: Successful claim
- **WHEN** `bd update <id> --claim` succeeds
- **THEN** task status is `in_progress`, assignee is set, and skill proceeds to branch creation

#### Scenario: Claim conflict
- **WHEN** `bd update <id> --claim` fails because task is already claimed
- **THEN** skill surfaces the conflict, re-runs `bd ready`, and prompts user to pick again

### Requirement: Dolt sync after claim
The skill SHALL run `bd dolt push` immediately after a successful claim so team members can see the task is in progress.

#### Scenario: Sync on claim
- **WHEN** task is successfully claimed
- **THEN** `bd dolt push` runs before branch creation begins
