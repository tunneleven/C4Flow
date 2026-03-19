## ADDED Requirements

### Requirement: Per-task Codex review
The skill SHALL invoke `c4flow:review` as a sub-agent after VERIFY passes. Review runs on the current branch diff against main.

#### Scenario: Review dispatched
- **WHEN** VERIFY passes
- **THEN** code skill dispatches `c4flow:review` sub-agent for the current task branch

### Requirement: CRITICAL and HIGH findings block advancement
If `c4flow:review` returns any CRITICAL or HIGH findings, the skill SHALL block advancement to PR and route back to CODING.

#### Scenario: Blocking findings
- **WHEN** review returns CRITICAL or HIGH findings
- **THEN** skill surfaces each finding, sets subState to CODING, routes back to TDD sub-agent with review context

#### Scenario: Only MEDIUM/LOW findings
- **WHEN** review returns only MEDIUM or LOW findings
- **THEN** skill surfaces them as advisory, proceeds to PR phase

#### Scenario: Clean review
- **WHEN** review returns no findings
- **THEN** skill proceeds directly to PR phase

### Requirement: PR and merge per task
After review passes, the skill SHALL invoke `c4flow:pr` to create a PR for the task branch, then merge to main.

#### Scenario: PR created and merged
- **WHEN** review passes
- **THEN** `c4flow:pr` is invoked, PR is created, merged to main, and task is recorded in `completedTasks`
