## ADDED Requirements

### Requirement: Branch naming convention
Every task SHALL get its own git branch named `feat/<bead-id>-<task-slug>` where `task-slug` is the task title converted to kebab-case.

#### Scenario: Branch name derivation
- **WHEN** task id is `bd-a1b2` and title is "Add login endpoint"
- **THEN** branch name is `feat/bd-a1b2-add-login-endpoint`

#### Scenario: Special characters in title
- **WHEN** task title contains spaces, slashes, or special characters
- **THEN** branch slug strips non-alphanumeric characters and collapses to kebab-case

### Requirement: Branch always cut from main
The skill SHALL run `git checkout main && git pull` before creating the task branch. If `git pull` fails, the skill SHALL surface a BLOCKED status and not proceed.

#### Scenario: Clean branch creation
- **WHEN** `git pull` succeeds on main
- **THEN** `git checkout -b feat/<id>-<slug>` creates a fresh branch from latest main

#### Scenario: Pull failure
- **WHEN** `git pull` fails (network error, conflict, etc.)
- **THEN** skill sets subState to BLOCKED, reports the error, and does not create the branch

### Requirement: One branch per task
The skill SHALL create exactly one branch per task. It SHALL NOT reuse an existing feature branch across multiple tasks.

#### Scenario: Existing branch detected
- **WHEN** a branch named `feat/<id>-<slug>` already exists locally
- **THEN** skill asks user: "Branch already exists — resume or recreate?" before proceeding
