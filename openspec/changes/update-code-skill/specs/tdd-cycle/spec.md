## ADDED Requirements

### Requirement: TDD sub-agent execution
The TDD cycle SHALL run as a sub-agent dispatched from the code skill. The sub-agent SHALL read the task description, acceptance criteria, and spec references before writing any test.

#### Scenario: Sub-agent dispatch
- **WHEN** branch is created and task is claimed
- **THEN** code skill dispatches a TDD sub-agent with task id, description, acceptance criteria, and spec file paths

### Requirement: RED phase — test written before implementation
The sub-agent SHALL write the test file before writing any implementation code. The test SHALL reference the acceptance criteria from the task description.

#### Scenario: Test file created
- **WHEN** sub-agent starts TDD cycle
- **THEN** test file is created and committed before any implementation file is touched

#### Scenario: RED confirmed — test must fail
- **WHEN** test file is written
- **THEN** sub-agent runs the test suite and verifies the new test FAILS
- **THEN** if test passes immediately, sub-agent flags it as invalid (implementation already exists or test is trivial) and reports back to user

### Requirement: RED gate pause
After confirming RED state, the sub-agent SHALL pause and show the user the test and failure output, asking for approval before proceeding to implementation.

#### Scenario: User approves RED
- **WHEN** user confirms the test correctly captures the requirement
- **THEN** sub-agent proceeds to GREEN phase

#### Scenario: User requests adjustment
- **WHEN** user asks to adjust the test
- **THEN** sub-agent revises the test, re-runs, confirms failure, and pauses again

### Requirement: GREEN phase — minimal implementation
The sub-agent SHALL implement the minimum code needed to make the failing test pass. It SHALL NOT implement functionality not covered by the current test.

#### Scenario: Tests pass after implementation
- **WHEN** implementation is complete
- **THEN** sub-agent runs full test suite and all tests (new + existing) pass

#### Scenario: Existing tests broken
- **WHEN** implementation causes a previously passing test to fail
- **THEN** sub-agent fixes the regression before proceeding to REFACTOR

### Requirement: REFACTOR phase
After GREEN, the sub-agent SHALL review the implementation for code quality (naming, duplication, complexity) and refactor if needed. Tests SHALL still pass after refactor.

#### Scenario: Refactor complete
- **WHEN** refactor is done
- **THEN** sub-agent runs full test suite, all tests pass, and reports DONE to the code skill
