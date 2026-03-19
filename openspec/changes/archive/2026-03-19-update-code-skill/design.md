## Context

`c4flow:code` and `c4flow:tdd` are stubs. The orchestrator's flat state machine (CODE → TEST → REVIEW → PR → MERGE) defers all quality enforcement until after all tasks complete. This means a broken task can block the entire feature at the end, with no mid-flight recovery.

The beads CLI provides atomic task claiming (`bd update --claim`), dependency-aware ready-work discovery (`bd ready`), and DoltHub sync (`bd dolt push`). These primitives make a strict per-task loop feasible.

## Goals / Non-Goals

**Goals:**
- Per-task loop: each task gets its own TDD cycle, verify, review, PR, and merge before the next task starts
- Atomic task claiming — no double-pickup in multi-agent or multi-session scenarios
- Resumability — if Claude crashes, `.state.json` has enough context to resume at the right sub-state
- RED gate — human approves the test before implementation begins, preventing trivial tests
- One branch per task with strict naming: `feat/<bead-id>-<task-slug>`
- Dolt sync at claim and close (two points per task, no more)

**Non-Goals:**
- Parallel task execution (serial loop only for now)
- Subtask-level branching
- Changing the beads schema or `bd` CLI
- Modifying `c4flow:review`, `c4flow:pr`, or `c4flow:verify` internals

## Decisions

### D1: Merge `c4flow:tdd` into `c4flow:code`

**Decision**: TDD cycle lives inside the code skill as a sub-agent phase, not a separate skill.

**Rationale**: The orchestrator already marks them as merged ("TDD merged with CODE sub-agent"). Keeping them separate adds indirection with no benefit — the TDD cycle is not invokable standalone in this workflow.

**Alternative considered**: Keep `c4flow:tdd` as standalone skill invoked from code. Rejected: adds a skill-dispatch hop with no user-facing value.

### D2: Sub-agent for TDD with one interactive checkpoint (RED gate)

**Decision**: TDD runs as a sub-agent. Only the RED phase pauses for user confirmation.

**Rationale**: Full autonomy risks trivial tests (`assert True`). Full interactivity adds friction at every step. The RED gate is the only load-bearing checkpoint — it confirms the test captures the right behavior before implementation begins. GREEN and REFACTOR output is visible in the PR review anyway.

**Checkpoint format**:
```
── RED STATE CONFIRMED ────────────────────────────
Test file: tests/test_auth.py::test_login_returns_jwt

Failure: FAILED - 404 Not Found (endpoint doesn't exist yet)

Does this test correctly capture the requirement? [yes / adjust]
───────────────────────────────────────────────────
```

**Alternative considered**: No checkpoints (fully autonomous). Rejected: too easy to produce passing-but-meaningless tests.

### D3: Actor resolution order

**Decision**: `explicit arg` → `BD_ACTOR` env var → `git config user.name`

**Rationale**: Allows override at invocation time ("pickup task from Alice"), respects the beads environment convention, and falls back to git identity which is always present in a dev environment.

**Implementation**:
```bash
ACTOR=$(parse_assignee_from_args "$@")
ACTOR=${ACTOR:-$BD_ACTOR}
ACTOR=${ACTOR:-$(git config user.name)}
```

### D4: One branch per task, always cut from `main`

**Decision**: Branch name `feat/<bead-id>-<task-slug>`. Always `git checkout main && git pull` before creating branch.

**Rationale**: Maps 1:1 bead→branch→PR. PRs stay small and reviewable. Beads dependency graph enforces sequence — `bd ready` only surfaces tasks whose blockers are resolved, so branches naturally build on merged predecessors.

**Alternative considered**: One branch per epic. Rejected: large PRs, harder review, no per-task revert granularity.

### D5: taskLoop schema in `.state.json`

**Decision**: Add `taskLoop` object tracking `subState`, `currentTaskId`, `currentBranch`, `completedTasks`, `failedTasks`.

```json
"taskLoop": {
  "currentTaskId": "bd-a1b2",
  "currentTaskSlug": "add-login-endpoint",
  "currentBranch": "feat/bd-a1b2-add-login-endpoint",
  "subState": "VERIFYING",
  "completedTasks": [
    { "id": "bd-0001", "pr": 12, "mergedAt": "2026-03-19T10:00:00Z" }
  ],
  "failedTasks": []
}
```

**subState values**: `CODING` → `VERIFYING` → `REVIEWING` → `CLOSING`

**Rationale**: Without subState, a crash mid-task loses position. With it, resume logic is deterministic.

### D6: Orchestrator CODE_LOOP replaces CODE + TEST + REVIEW + PR + MERGE

**Decision**: These five states collapse into `CODE_LOOP`. After all tasks complete, state advances directly to `DEPLOY`.

**Rationale**: TEST, REVIEW, PR, MERGE all happen per-task inside the loop. Keeping them as top-level states would require the orchestrator to re-enter CODE for each task, which is awkward. CODE_LOOP makes the loop explicit.

**Migration**: Existing `.state.json` files with `currentState: "CODE"` should be treated as `CODE_LOOP` with `taskLoop: null` (start from first ready task).

### D7: Dolt sync at claim and close only

**Decision**: `bd dolt push` runs twice per task — after claim (status visible to others) and after close (completion visible to others).

**Rationale**: Over-syncing mid-TDD adds latency for no observability benefit. The two critical state transitions (started, done) are sufficient for team visibility.

## Risks / Trade-offs

**[Risk] RED gate can be bypassed by impatient user** → Mitigation: gate is a pause, not a hard block. Document that skipping it defeats TDD discipline. Consider logging skip events to `.state.json`.

**[Risk] `bd update --claim` fails if task already claimed** → Mitigation: treat claim failure as a signal to re-run `bd ready` and pick a different task. Surface the error clearly, don't silently retry.

**[Risk] Branch cut from stale `main`** → Mitigation: always `git pull` before branching. If pull fails (offline, conflict), surface as BLOCKED with clear message.

**[Risk] `.state.json` `taskLoop` grows unbounded on large epics** → Mitigation: `completedTasks` stores minimal fields (id, pr, mergedAt). 100 tasks ≈ ~5KB. Acceptable.

**[Risk] Orchestrator migration — existing CODE state** → Mitigation: resume handler maps `CODE` → `CODE_LOOP` with `taskLoop: null`. No data loss.

## Migration Plan

1. Update `skills/code/SKILL.md` (full rewrite)
2. Update `skills/tdd/SKILL.md` (redirect to code skill)
3. Update `skills/c4flow/SKILL.md` (orchestrator state machine)
4. Document `taskLoop` schema addition — backward compatible (field is optional, defaults to `null`)
5. No runtime migration needed — `.state.json` is project-local and regenerated on workflow start

## Open Questions

- Should `failedTasks` in `taskLoop` trigger a hard stop, or allow the user to skip and continue with next task?
- Should the RED gate pause include a diff of files the test touches, to help the user evaluate coverage?
