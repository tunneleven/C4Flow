# Phase 4: Superpowers + Subagent-Driven c4flow:code - Research

**Researched:** 2026-03-16
**Domain:** C4Flow CODE-phase orchestration, Superpowers skill composition, workflow state transitions, documentation-based regression coverage
**Confidence:** HIGH (all referenced skill and workflow files exist locally; `c4flow:code` and `c4flow:tdd` are confirmed stubs; `skills/c4flow/SKILL.md` still routes CODE through the unimplemented fallback path)

---

<phase_requirements>
## Phase Requirements

This phase does not yet have formal requirement IDs in [`.planning/REQUIREMENTS.md`](/home/tunn/Documents/Research/C4Flow/.planning/REQUIREMENTS.md).
Planning must therefore derive execution scope directly from the Phase 4 goal in [`.planning/ROADMAP.md`](/home/tunn/Documents/Research/C4Flow/.planning/ROADMAP.md):

| Goal Slice | Research Support |
|------------|------------------|
| Replace the `c4flow:code` stub with an implementation-oriented skill | `skills/code/SKILL.md` is currently a placeholder only |
| Compose `using-superpowers` and `subagent-driven-development` instead of re-describing their workflows | Both Superpowers skills already exist under `.agents/skills/` and define mandatory sequencing rules |
| Make the main `c4flow` orchestrator treat CODE as implemented | `skills/c4flow/SKILL.md` currently handles CODE via the generic "unimplemented" branch |
| Keep workflow references and transition docs aligned with the new CODE behavior | `references/workflow-state.md` and `references/phase-transitions.md` still describe CODE abstractly and need concrete routing language |
| Add low-cost regression checks for documentation-driven behavior | Existing phases use shell-based test suites under `.claude/tests/` to lock down skill contracts |
</phase_requirements>

---

## Summary

Phase 4 is a workflow-integration phase, not a greenfield execution engine. The repository already has the critical building blocks:

- `skills/code/SKILL.md` exists but is only a stub.
- `.agents/skills/using-superpowers/SKILL.md` establishes the rule that relevant skills must be loaded before acting.
- `.agents/skills/subagent-driven-development/SKILL.md` defines the implementation workflow C4Flow should lean on for CODE execution.
- `skills/c4flow/SKILL.md` already owns the top-level state machine, but still treats CODE as unimplemented.

The correct implementation strategy is therefore thin orchestration:

1. `c4flow:code` should validate CODE-phase prerequisites, load the Superpowers workflow expectations, and hand execution to `subagent-driven-development`.
2. The top-level `c4flow` skill should stop advertising CODE as unimplemented and instead route the CODE state into `skills/code/SKILL.md`.
3. Workflow reference docs must be updated so the documented state machine matches the implemented dispatch path.
4. Regression tests should validate the presence of the critical instructions and routes, since the behavior here lives in skill documents rather than compiled code.

Primary recommendation: implement this phase as two plans in two waves. Wave 1 replaces the stubs and wires routing. Wave 2 adds shell-based contract tests and a human verification checkpoint.

---

## Standard Stack

### Core

| File / Tool | Purpose | Why It Is Canonical Here |
|-------------|---------|--------------------------|
| `skills/code/SKILL.md` | Defines the CODE-phase behavior | This is the user-facing skill being implemented |
| `skills/c4flow/SKILL.md` | Owns state routing for the full workflow | CODE is unreachable through the main workflow until this file is updated |
| `.agents/skills/using-superpowers/SKILL.md` | Declares mandatory skill-loading discipline | Prevents `c4flow:code` from bypassing the project’s shared workflow rules |
| `.agents/skills/subagent-driven-development/SKILL.md` | Provides the concrete implementation execution model | This is the exact workflow the user wants integrated |
| `references/workflow-state.md` | Documents CODE state semantics and skill mapping | Currently points at a non-existent `phases/05-code/SKILL.md` path |
| `references/phase-transitions.md` | Defines CODE → TEST gate language | Needs concrete wording that matches the new delegated execution path |

### Supporting

| File / Tool | Purpose | When to Use |
|-------------|---------|-------------|
| `.agents/skills/using-git-worktrees/SKILL.md` | Required by `subagent-driven-development` before implementation begins | Reference from `c4flow:code` rather than duplicating worktree logic |
| `.agents/skills/requesting-code-review/SKILL.md` | Defines review expectations inside the subagent-driven workflow | Mention as part of the downstream execution contract |
| `.claude/tests/` shell suite pattern | Low-friction validation for skill-document contracts | Reuse for plan-wave test coverage |

---

## Architecture Patterns

### Pattern 1: Thin Delegation to Existing Superpowers Skills

`c4flow:code` should not recreate the subagent execution algorithm inside its own instructions. Instead, it should:

- confirm the workflow is at CODE or is being invoked explicitly,
- locate the execution inputs (`docs/c4flow/.state.json`, beads/task artifacts, implementation plan),
- invoke the shared skill-loading expectations from `using-superpowers`,
- hand the actual implementation workflow to `subagent-driven-development`.

This keeps one source of truth for subagent orchestration and avoids drift between C4Flow and Superpowers.

### Pattern 2: CODE Must Be Reachable Through the Main Workflow

Replacing `skills/code/SKILL.md` alone is insufficient. `skills/c4flow/SKILL.md` currently groups CODE with unimplemented states, so users hitting CODE through `/c4flow` will never reach the new skill. The orchestrator must grow a dedicated CODE branch analogous to RESEARCH, BEADS, and TEST.

### Pattern 3: Documentation and References Must Agree on the Skill Path

`references/workflow-state.md` maps CODE to `phases/05-code/SKILL.md`, but the real file in this repository is `skills/code/SKILL.md`. Leaving that mismatch in place would make the workflow self-contradictory and cause future planning or implementation agents to read the wrong target.

### Pattern 4: Contract Tests Are the Right Validation Layer

This phase primarily edits markdown skills, not production runtime code. The right regression strategy is to add shell tests that assert:

- `skills/code/SKILL.md` no longer contains stub language,
- it explicitly references `using-superpowers` and `subagent-driven-development`,
- `skills/c4flow/SKILL.md` has a CODE-specific branch,
- workflow reference docs point to `skills/code/SKILL.md`,
- fallback/manual guidance remains documented if prerequisites are missing.

### Pattern 5: Keep CODE → TEST as a Gate, Not an Assumption

The current transition contract says CODE advances only when assigned tasks are closed. The new `c4flow:code` skill should preserve that gate language and should not auto-advance to TEST without checking the expected task source (`beads` or `tasks.md`).

---

## Validation Architecture

This phase should create a dedicated shell suite under `.claude/tests/`:

- `test-code-skill-file.sh`
- `test-c4flow-code-route.sh`
- `test-code-state-reference.sh`
- `test-code-fallbacks.sh`
- `run-code-skill-tests.sh`

Quick run and full run can both use:

```bash
bash .claude/tests/run-code-skill-tests.sh
```

The suite should stay grep/jq based and avoid trying to execute live skill dispatch. The goal is to lock down contract text, state routing, and documented fallbacks.

One manual verification checkpoint is still warranted: read the finished `skills/code/SKILL.md` and `skills/c4flow/SKILL.md` together and confirm the CODE path is understandable end-to-end for a human operator.

---

## Common Pitfalls

### Pitfall 1: Implementing `skills/code/SKILL.md` Without Updating `skills/c4flow/SKILL.md`

If the top-level orchestrator still treats CODE as unimplemented, the new skill becomes dead documentation.

### Pitfall 2: Re-describing Subagent Workflow Instead of Delegating to Superpowers

Duplicating `subagent-driven-development` inside `c4flow:code` creates two versions of the same workflow and invites drift. C4Flow should compose the skill, not fork it.

### Pitfall 3: Skipping `using-superpowers`

The Superpowers workflow explicitly says skill checks happen before any action. If `c4flow:code` references only `subagent-driven-development`, it bypasses the mandatory entry discipline the project already adopted.

### Pitfall 4: Leaving Reference Paths Stale

`references/workflow-state.md` currently names a non-existent CODE skill path. Future agents will follow that bad reference unless it is corrected in the same phase.

### Pitfall 5: Treating CODE Completion as “skill invoked” Instead of “tasks closed”

The workflow gate is task completion, not merely starting execution. The implementation must preserve the state-machine expectation that CODE only hands off to TEST when the task source is complete.

---

## Recommended Phase Shape

| Wave | Plan | Focus |
|------|------|-------|
| 1 | `04-01-PLAN.md` | Implement `c4flow:code`, add CODE routing in `skills/c4flow/SKILL.md`, and align workflow references |
| 2 | `04-02-PLAN.md` | Add shell-based regression tests and human verification for the new CODE path |

This split keeps the documentation/skill implementation isolated from the validation layer and makes review simpler.
