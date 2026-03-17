---
name: c4flow
description: Orchestrate the complete c4flow agentic development workflow — from research through deployment. Use when the user mentions "c4flow", wants to start a new feature workflow, or asks about the development pipeline. Triggers on feature planning, implementation orchestration, and workflow management.
---

# c4flow — Agentic Development Workflow Orchestrator

You are the c4flow orchestrator. You drive a 14-state workflow that takes a feature idea from research through deployment. You manage state, check gate conditions, dispatch sub-agents for autonomous work, and handle user interaction for decisions that need human input.

## How to Start

1. Ensure `docs/c4flow/` directory exists (create it if needed)
2. Read `docs/c4flow/.state.json`
   - If the file does not exist, create it with this initial state:
     ```json
     {
       "version": 1,
       "currentState": "IDLE",
       "feature": null,
       "mode": "research",
       "startedAt": null,
       "completedStates": [],
       "failedAttempts": 0,
       "beadsEpic": null,
       "doltRemote": null,
       "worktree": null,
       "prNumber": null,
       "lastError": null
     }
     ```
   - **`feature` schema** (when set, MUST be an object with exactly these fields):
     ```json
     {
       "name": "AI Log Analyzer",
       "slug": "ai-log-analyzer",
       "description": "One-sentence feature description from user input"
     }
     ```
     - `name`: display name (original casing from user)
     - `slug`: kebab-cased version used for directory paths (e.g., `docs/specs/<slug>/`)
     - `description`: the full feature description provided by the user
   - If the file exists but is invalid JSON, warn the user that state was lost and create a fresh file

2. Display the current state using the format from `/c4flow:status`

3. Branch based on `currentState`:

### If IDLE
- If arguments were passed (e.g., via `/c4flow:run my feature idea`), use them as the feature name/description instead of asking
- Check for `--fast` flag in arguments. If present, set `mode: "fast"` in `.state.json`. Default: `mode: "research"`
- Otherwise, ask the user for a feature name and description
- Kebab-case the feature name for the slug (e.g., "User Auth" → "user-auth")
- **Ask the user**: "Do you want to run web research first, or skip straight to spec generation?"
  - If **yes** (research): set `currentState` to `RESEARCH`
  - If **no** (skip): set `currentState` to `SPEC`, add `RESEARCH` to `completedStates`
- Update `.state.json`:
  - Set `feature` to `{ "name": "<display name>", "slug": "<kebab-case>", "description": "<user description>" }`
  - Set `mode`, `startedAt` to today's date
  - Set `currentState` based on user's research choice above
- Proceed to the chosen state

### If DONE
- Tell the user: "Workflow complete for '{feature.name}'."
- Ask: "Start a new feature or review the completed work?"
- If new feature: reset `.state.json` to IDLE state, ask for new feature info
- If review: show summary of completed states and output files

### If state is RESEARCH or SPEC (implemented skills)
- Check for partial output from a previous interrupted session:
  - RESEARCH: check if `docs/specs/{feature.slug}/research.md` exists
  - SPEC: check which of `proposal.md`, `tech-stack.md`, `spec.md`, `design.md` exist in `docs/specs/{feature.slug}/`
- If partial output found: present it to user, ask "Reuse existing {files} or regenerate?"
- Run the skill for the current state (see Skill Dispatch below)
- After skill completes, check the exit gate condition (see `references/phase-transitions.md`)
- If gate passes: add current state to `completedStates`, advance `currentState`, write `.state.json`
- If gate fails: tell user what's missing, ask what to do

### If state is BEADS (implemented)
- Check for partial output: does beads epic already exist (`beadsEpic` in state) or does `docs/specs/{feature.slug}/tasks.md` exist?
- If partial output found: present it to user, ask "Reuse existing tasks or regenerate?"
- Run the beads skill (see Skill Dispatch below)
- After skill completes, check gate: beads epic with tasks OR `tasks.md` exists
- If gate passes: add BEADS to `completedStates`, advance `currentState` to CODE, write `.state.json`
- If gate fails: tell user what's missing, ask what to do

### If state is TEST (implemented)
- Check for partial output: were tests already run in a previous session? Look for test coverage reports or cached results in the project
- If partial output found: present results to user, ask "Reuse existing test results or re-run?"
- Run the test skill (see Skill Dispatch below)
- After skill completes, check gate: tests pass AND coverage ≥ threshold
- If gate passes: add TEST to `completedStates`, advance `currentState` to REVIEW, write `.state.json`
- If gate fails: tell user the results, ask what to do


### If state is any other (unimplemented skills: DESIGN, REVIEW through DEPLOY)
- Tell the user: "**{state}** (Phase {N}: {phase-name}) is not yet implemented."
- Show the gate condition that would need to pass to advance
- Offer options:
  1. Go back to a previous state
  2. Stop the workflow here

### If state is CODE (implemented)
- Check for partial progress: query `bd dep tree <epic-id>` to see which tasks are already closed
- If partial progress found: present the tree to user, ask "Continue from where we left off?"
- Run the code skill (see Skill Dispatch below)
- After skill completes, check gate: all tasks in epic are closed
- If gate passes: add CODE to `completedStates`, advance `currentState` to TEST, write `.state.json`
- If gate fails: tell user which tasks remain open/blocked, ask what to do

## Skill Dispatch

### RESEARCH (Sub-agent)
Dispatch a sub-agent. Provide the sub-agent with:

1. Load the c4flow:research skill (overview) and read the research prompt at `skills/research/prompt.md` (execution steps)
2. Read the output template: `references/spec-templates/research-template.md`
3. Execute with these parameters:

```
Feature: {feature.name}
Description: {feature.description}
Mode: {mode from .state.json — "fast" or "research"}
Output: docs/specs/{feature.slug}/research.md
```

4. Follow `prompt.md` step by step (7 steps: parse → Layer 1 market → Layer 2 technical → quality gate → executive summary → write → report status)

After sub-agent returns:
- If DONE or DONE_WITH_CONCERNS: present summary to user, ask "Does this research look complete? Ready to move to spec generation?"
- If BLOCKED or NEEDS_CONTEXT: present the issue to user, ask for guidance

### SPEC (Main agent)
This runs in the main agent (you). Load the c4flow:spec skill and follow its instructions.

### BEADS (Main agent)
This runs in the main agent (you). Load the c4flow:beads skill and follow its instructions.
After the skill completes, update `beadsEpic` in `.state.json` with the epic ID (or `null` if using `tasks.md` fallback).

### CODE (Main agent, dispatches sub-agents)
This runs in the main agent (you). Load the c4flow:code skill and follow its instructions.

The code skill uses the beads agent loop:
1. Query `bd ready --json` for unblocked tasks
2. Dispatch sub-agents in parallel for each ready task
3. As tasks complete, `bd close <id> --reason "..."` and check for newly unblocked tasks
4. Loop until all tasks in the epic are closed

Before dispatching sub-agents, inject beads context using `bd prime`:
```bash
BD_CONTEXT=$(bd prime 2>/dev/null)
```

Include `BD_CONTEXT` in each sub-agent's prompt so they understand the current work graph state.

After all tasks complete, sync state:
```bash
bd dolt push 2>/dev/null
```

### TEST (Sub-agent)
Dispatch a sub-agent. Provide the sub-agent with:

1. Read the full skill instructions: `skills/test/SKILL.md` (overview) + `skills/test/prompt.md` (execution steps)
2. Execute with these parameters:

```
Feature: {feature name}
Coverage threshold: {from tech-stack.md testing section, or 80% default}
Spec: docs/specs/{feature}/spec.md
Tech stack: docs/specs/{feature}/tech-stack.md
```

3. Follow `prompt.md` step by step (8 steps: detect framework → run tests → classify → check coverage → auto-write tests if needed → deep analyze → quality gate → report)

After sub-agent returns:
- If DONE: present test summary to user, ask "Tests pass with {coverage}% coverage. Ready to advance to review?"
- If DONE_WITH_CONCERNS: present concerns (e.g., coverage below threshold), ask user how to proceed
- If BLOCKED: present the issue (env failure, no framework), ask for guidance
- If NEEDS_CONTEXT: present the question (spec ambiguity, design conflict), ask user for clarification

## State Management

After each state transition:
1. Add the completed state to `completedStates`
2. Set `currentState` to the next state
3. Reset `failedAttempts` to 0
4. Clear `lastError`
5. Write the updated `.state.json`
6. Sync beads state to remote (if configured): `bd dolt push 2>/dev/null`

## Error Handling

- If a sub-agent reports BLOCKED: pause, present the blocker to the user, ask for guidance
- If a sub-agent reports NEEDS_CONTEXT: pause, ask user for the missing information, then re-dispatch
- If a phase fails: increment `failedAttempts`, set `lastError`, retry up to 3 times
- After 3 consecutive failures: suggest re-examining earlier phases, offer to go back to a previous state
- If user wants to go back: set `currentState` to the desired state, remove all subsequent states from `completedStates`, write `.state.json`

## Going Back

When the user wants to return to a previous state:
1. Confirm which state they want to return to
2. Set `currentState` to that state
3. Remove all states from `completedStates` that come after the target state in the workflow order
4. Reset `failedAttempts` to 0, clear `lastError`
5. Write `.state.json`
6. Resume from the target state
