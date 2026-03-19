## ADDED Requirements

### Requirement: Test suite validation
After TDD cycle completes, the skill SHALL run the full test suite and verify coverage meets the threshold defined in `docs/specs/<feature>/tech-stack.md` (default 80%).

#### Scenario: Tests pass with sufficient coverage
- **WHEN** all tests pass and coverage >= threshold
- **THEN** skill proceeds to REVIEW phase

#### Scenario: Coverage below threshold
- **WHEN** tests pass but coverage < threshold
- **THEN** skill surfaces the gap, asks user: "Coverage is X%. Add more tests or proceed anyway?"

#### Scenario: Test failures
- **WHEN** any test fails after TDD cycle
- **THEN** skill sets subState back to CODING and routes back to TDD sub-agent with failure details

### Requirement: bd preflight check
The skill SHALL run `bd preflight --check` as part of verification. Preflight failures SHALL block advancement to REVIEW.

#### Scenario: Preflight passes
- **WHEN** `bd preflight --check` returns pass
- **THEN** skill proceeds to REVIEW

#### Scenario: Preflight fails
- **WHEN** `bd preflight --check` returns failures
- **THEN** skill surfaces each failing check, sets subState to CODING, routes back for fixes
