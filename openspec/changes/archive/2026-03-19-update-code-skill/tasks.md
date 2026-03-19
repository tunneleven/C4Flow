## 1. Task Pickup

- [x] 1.1 Implement actor resolution: parse `--assignee`/`from <name>` arg → `BD_ACTOR` → `git config user.name`
- [x] 1.2 Implement `bd ready --assignee <actor> --json` call with empty-list handling
- [x] 1.3 Implement task selection: present list to user, wait for confirmation
- [x] 1.4 Implement atomic claim via `bd update <id> --claim` with conflict retry logic
- [x] 1.5 Implement `bd dolt push` after successful claim
- [x] 1.6 Write tests for actor resolution (all three fallback paths)
- [x] 1.7 Write tests for claim conflict scenario (re-run discovery)

## 2. Branch Strategy

- [x] 2.1 Implement task slug derivation (title → kebab-case, strip special chars)
- [x] 2.2 Implement branch name construction: `feat/<bead-id>-<task-slug>`
- [x] 2.3 Implement `git checkout main && git pull` with BLOCKED handling on failure
- [x] 2.4 Implement existing branch detection with user prompt (resume or recreate)
- [x] 2.5 Write tests for slug derivation edge cases (special chars, long titles)

## 3. TDD Sub-agent

- [x] 3.1 Write TDD sub-agent prompt: read task description + acceptance criteria + spec refs
- [x] 3.2 Implement RED phase: write test file, run suite, verify failure
- [x] 3.3 Implement trivial-test detection (test passes immediately → flag as invalid)
- [x] 3.4 Implement RED gate pause: format and display test + failure output, await user approval
- [x] 3.5 Implement RED gate adjust loop: revise test on user request, re-confirm failure
- [x] 3.6 Implement GREEN phase: implement minimum code, run suite, verify all pass
- [x] 3.7 Implement regression handling: detect broken existing tests, fix before REFACTOR
- [x] 3.8 Implement REFACTOR phase: cleanup pass, re-run suite, report DONE
- [x] 3.9 Write tests for RED gate pause format and approval flow
- [x] 3.10 Write tests for trivial-test detection logic

## 4. Task Verify

- [x] 4.1 Implement test suite run + coverage threshold check (read from tech-stack.md, default 80%)
- [x] 4.2 Implement below-threshold user prompt (add tests or proceed anyway)
- [x] 4.3 Implement test failure routing: set subState CODING, return to TDD sub-agent with failure context
- [x] 4.4 Implement `bd preflight --check` invocation and result parsing
- [x] 4.5 Implement preflight failure routing: surface each failing check, set subState CODING
- [x] 4.6 Write tests for coverage threshold logic (above, below, exactly at threshold)
- [x] 4.7 Write tests for preflight failure routing

## 5. Task Review

- [x] 5.1 Implement `c4flow:review` sub-agent dispatch from code skill
- [x] 5.2 Implement CRITICAL/HIGH blocking logic: surface findings, set subState CODING
- [x] 5.3 Implement MEDIUM/LOW advisory output: surface as non-blocking, proceed to PR
- [x] 5.4 Implement `c4flow:pr` invocation for the task branch
- [x] 5.5 Implement merge to main after PR created
- [x] 5.6 Write tests for finding severity routing (blocking vs advisory)

## 6. Loop State and .state.json

- [x] 6.1 Implement `taskLoop` object initialization on CODE_LOOP entry (`null` until first claim)
- [x] 6.2 Implement subState write on each transition (CODING → VERIFYING → REVIEWING → CLOSING)
- [x] 6.3 Implement `completedTasks` append on task close: `{ id, pr, mergedAt }`
- [x] 6.4 Implement `bd close <id> --reason "..."` + `bd dolt push` in CLOSING sub-state
- [x] 6.5 Write tests for `.state.json` taskLoop schema across all subState transitions
- [x] 6.6 Write tests for completedTasks append correctness

## 7. Resumability

- [x] 7.1 Implement resume detection: on CODE_LOOP entry, check if `taskLoop` is non-null
- [x] 7.2 Implement resume from VERIFYING: skip TDD, re-run tests and preflight
- [x] 7.3 Implement resume from REVIEWING: skip TDD and verify, re-dispatch review
- [x] 7.4 Implement resume from CODING: prompt user to re-run TDD from RED or continue
- [x] 7.5 Write tests for each resume path

## 8. Orchestrator Updates

- [x] 8.1 Update `skills/c4flow/SKILL.md`: replace CODE with CODE_LOOP in state machine
- [x] 8.2 Remove TEST, REVIEW, PR, MERGE as top-level orchestrator states
- [x] 8.3 Add CODE_LOOP → DEPLOY transition (when `bd ready` returns empty)
- [x] 8.4 Implement legacy migration: `currentState: "CODE"` → `"CODE_LOOP"` with `taskLoop: null`
- [x] 8.5 Update `skills/tdd/SKILL.md`: replace stub with redirect to code skill
- [x] 8.6 Write tests for state machine transitions (BEADS→CODE_LOOP, CODE_LOOP→DEPLOY)
- [x] 8.7 Write test for legacy CODE state migration

## 9. Skill File Rewrite

- [x] 9.1 Rewrite `skills/code/SKILL.md` with full task loop instructions
- [x] 9.2 Add actor resolution section to code skill
- [x] 9.3 Add branch strategy section to code skill
- [x] 9.4 Add TDD sub-agent dispatch section with RED gate pause format
- [x] 9.5 Add VERIFY section with test + preflight steps
- [x] 9.6 Add REVIEW section with severity routing
- [x] 9.7 Add CLOSING section with bd close + dolt push + completedTasks update
- [x] 9.8 Add loop continuation logic: check `bd ready` after each close, advance to DEPLOY when empty
