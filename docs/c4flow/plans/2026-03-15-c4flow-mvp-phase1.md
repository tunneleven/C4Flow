# c4flow MVP Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the c4flow Claude Code plugin skeleton with a full 14-state orchestrator and two working Phase 1 skills (research + spec).

**Architecture:** All files are markdown — this is a Claude Code skill plugin, not a software application. The plugin lives at `.claude/skills/c4flow/` with a master SKILL.md orchestrator, reference documents, spec templates, 15 phase skills (2 implemented, 13 stubs), and 2 commands.

**Tech Stack:** Claude Code plugin (SKILL.md files with YAML frontmatter), markdown templates, JSON state persistence.

**Spec:** `docs/c4flow/specs/2026-03-15-c4flow-mvp-phase1-design.md`

---

## Chunk 1: Reference Documents and Templates

These files are referenced by the orchestrator and skills. They must exist first.

### Task 1: Create directory structure

**Files:**
- Create: `.claude/skills/c4flow/references/spec-templates/` (directory)
- Create: `.claude/skills/c4flow/phases/01-research/` (directory)
- Create: `.claude/skills/c4flow/phases/02-spec/` (directory)
- Create: `.claude/skills/c4flow/phases/03-design/` through `15-deploy/` (directories)
- Create: `.claude/commands/c4flow/` (directory)

- [ ] **Step 1: Create all directories**

```bash
mkdir -p .claude/skills/c4flow/references/spec-templates
mkdir -p .claude/skills/c4flow/phases/{01-research,02-spec,03-design,04-beads,05-code,06-tdd,07-test,08-e2e,09-review,10-verify,11-pr,12-pr-review,13-infra,14-merge,15-deploy}
mkdir -p .claude/commands/c4flow
```

- [ ] **Step 2: Verify directories exist**

Run: `find .claude/skills/c4flow -type d | sort`
Expected: All directories listed above

- [ ] **Step 3: Commit**

```bash
git add .claude/
git commit -m "chore: scaffold c4flow plugin directory structure"
```

### Task 2: Create workflow-state.md reference

**Files:**
- Create: `.claude/skills/c4flow/references/workflow-state.md`

- [ ] **Step 1: Write workflow-state.md**

Use the Write tool to create this file. Note: the content below contains nested code blocks — write the content as-is, including the inner triple-backtick fences.

````markdown
# c4flow Workflow State Machine

## States (14 working states + IDLE + DONE)

| # | State | Phase | Description |
|---|-------|-------|-------------|
| 0 | IDLE | — | No active workflow |
| 1 | RESEARCH | 1: Research & Spec | Market/tech research |
| 2 | SPEC | 1: Research & Spec | Spec artifact generation |
| 3 | DESIGN | 2: Design & Beads | Design system + mockups |
| 4 | BEADS | 2: Design & Beads | Task breakdown |
| 5 | CODE | 3: Implementation | Code execution |
| 6 | TDD | 3: Implementation | Test-driven development (merged with CODE) |
| 7 | TEST | 4: Testing | Unit + integration tests |
| 8 | E2E | 4: Testing | End-to-end tests (manual trigger) |
| 9 | REVIEW | 5: Review & QA | Local AI review loop |
| 10 | VERIFY | 5: Review & QA | Quality gate |
| 11 | PR | 6: Release | Create pull request |
| 12 | PR_REVIEW_LOOP | 6: Release | PR comment review loop |
| 13 | MERGE | 6: Release | Merge to main |
| 14 | DEPLOY | 6: Release | Deploy to production |
| — | DONE | — | Workflow complete |

## Transitions (auto flow)

```
IDLE → RESEARCH → SPEC → DESIGN → BEADS → CODE → TEST
  → REVIEW → VERIFY → PR → PR_REVIEW_LOOP → MERGE → DEPLOY → DONE
```

States NOT in the auto flow (manual trigger only):
- **E2E** — User calls `/c4flow:e2e` when needed
- **INFRA** — User calls `/c4flow:infra` when needed
- **TDD** — Merged into CODE sub-agent behavior

## State-to-Skill Mapping

| State | Skill File | Agent Type |
|-------|-----------|------------|
| RESEARCH | phases/01-research/SKILL.md | Sub-agent |
| SPEC | phases/02-spec/SKILL.md | Main agent |
| DESIGN | phases/03-design/SKILL.md | Sub-agent + Main confirm |
| BEADS | phases/04-beads/SKILL.md | Main agent |
| CODE | phases/05-code/SKILL.md | Sub-agent per task |
| TDD | phases/06-tdd/SKILL.md | Sub-agent (merged with code) |
| TEST | phases/07-test/SKILL.md | Sub-agent |
| E2E | phases/08-e2e/SKILL.md | Sub-agent (manual trigger) |
| REVIEW | phases/09-review/SKILL.md | Sub-agent loop (max 5) |
| VERIFY | phases/10-verify/SKILL.md | Sub-agent |
| PR | phases/11-pr/SKILL.md | Main agent |
| PR_REVIEW_LOOP | phases/12-pr-review/SKILL.md | Sub-agent loop (max 5) |
| INFRA | phases/13-infra/SKILL.md | Sub-agent (manual trigger) |
| MERGE | phases/14-merge/SKILL.md | Main agent |
| DEPLOY | phases/15-deploy/SKILL.md | Main agent |

## State Persistence

File: `docs/c4flow/.state.json`

```json
{
  "version": 1,
  "currentState": "IDLE",
  "feature": null,
  "startedAt": null,
  "completedStates": [],
  "failedAttempts": 0,
  "beadsEpic": null,
  "worktree": null,
  "prNumber": null,
  "lastError": null
}
```

### Field Descriptions

- **version**: Schema version (always 1 for now)
- **currentState**: One of the 14 states above, or "DONE"
- **feature**: Kebab-cased feature name (e.g., "user-auth")
- **startedAt**: ISO date string (e.g., "2026-03-15")
- **completedStates**: Array of state names that have been completed
- **failedAttempts**: Counter for consecutive failures in current state
- **beadsEpic**: Beads epic ID if beads is installed (e.g., "bd-a1b2")
- **worktree**: Path to active worktree, or null
- **prNumber**: PR number if created, or null
- **lastError**: Last error message, or null
````

- [ ] **Step 2: Verify file was created**

Run: `head -5 .claude/skills/c4flow/references/workflow-state.md`
Expected: First 5 lines of the file

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/c4flow/references/workflow-state.md
git commit -m "docs: add c4flow workflow state machine reference"
```

### Task 3: Create phase-transitions.md reference

**Files:**
- Create: `.claude/skills/c4flow/references/phase-transitions.md`

- [ ] **Step 1: Write phase-transitions.md**

Use the Write tool to create this file.

````markdown
# c4flow Phase Transitions

## Gate Conditions

Each state transition requires its gate condition to be met before advancing.

| From → To | Gate Condition | How to Check |
|-----------|---------------|--------------|
| IDLE → RESEARCH | User provides feature idea | User input received |
| RESEARCH → SPEC | `research.md` exists and user confirmed | Check `docs/specs/<feature>/research.md` exists |
| SPEC → DESIGN | All spec artifacts exist and user approved | Check `proposal.md`, `tech-stack.md`, `spec.md`, `design.md` in `docs/specs/<feature>/` |
| DESIGN → BEADS | Design system + mockups approved | User confirmation |
| BEADS → CODE | Epic + tasks created, user confirmed | Check beads epic or `tasks.md` exists |
| CODE → TEST | All assigned tasks closed | Check beads or `tasks.md` all checked |
| TEST → REVIEW | Tests pass, coverage >= threshold | Test runner output |
| REVIEW → VERIFY | 0 CRITICAL + 0 HIGH issues | Review report |
| VERIFY → PR | `Ready for PR: YES` | Verify output |
| PR → PR_REVIEW_LOOP | PR created successfully | `prNumber` set in state |
| PR_REVIEW_LOOP → MERGE | 0 unresolved PR comments | `gh` CLI check |
| MERGE → DEPLOY | Merge successful | Git merge confirmed |
| DEPLOY → DONE | Deploy verified healthy | Health check passed |

## Error Handling

### Sub-Agent Status Codes

| Status | Meaning | Orchestrator Action |
|--------|---------|-------------------|
| DONE | Task completed successfully | Close task, advance state |
| DONE_WITH_CONCERNS | Completed but with noted issues | Close task, log concerns as new issue, advance |
| BLOCKED | Cannot proceed | Pause state, ask user for guidance |
| NEEDS_CONTEXT | Missing information | Pause state, ask user for info, then resume |

### Failure Recovery

| Scenario | Behavior |
|----------|----------|
| Phase fails (build, tests, etc.) | Increment `failedAttempts`, retry up to 3 times |
| 3+ consecutive failures | Escalate: suggest re-examining spec/design, offer to go back |
| User wants to go back | Set `currentState` to desired state, remove subsequent states from `completedStates` |
| State file missing | Create fresh `.state.json` with IDLE state, warn user |
| State file corrupt (invalid JSON) | Create fresh `.state.json` with IDLE state, warn user about lost state |

### Resume Behavior

When `/c4flow:run` is invoked and `.state.json` already exists:

1. Read `.state.json`
2. If `currentState` is not IDLE or DONE:
   - Ask user: "Resume from {currentState}?"
   - Check for partial output (e.g., `research.md` exists but state is still RESEARCH)
   - If partial output found, ask user: "Found existing {file}. Reuse it or regenerate?"
3. If `currentState` is DONE:
   - Ask user: "Start new feature or review completed?"
````

- [ ] **Step 2: Verify file was created**

Run: `head -5 .claude/skills/c4flow/references/phase-transitions.md`
Expected: First 5 lines of the file

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/c4flow/references/phase-transitions.md
git commit -m "docs: add c4flow phase transitions reference"
```

### Task 4: Create sub-agent-prompt-template.md reference

**Files:**
- Create: `.claude/skills/c4flow/references/sub-agent-prompt-template.md`

- [ ] **Step 1: Write sub-agent-prompt-template.md**

Use the Write tool to create this file. Note: the content below contains nested code blocks — write the content as-is.

````markdown
# Sub-Agent Prompt Template

Use this template when constructing prompts for sub-agents. Total prompt context should be ~2000 tokens max, leaving working space for the sub-agent.

## Template

```
# Task: {task_title}

## Context
{excerpt from spec relevant to this task — max 500 tokens}

## Task Description
{full description with acceptance criteria}

## Files to Modify
{list of files from task description}

## Design Reference
{excerpt from design.md relevant to this task — max 300 tokens}

## Tech Stack
{from tech-stack.md — framework, language, testing framework}

## Rules
- Follow TDD: write failing test first, then implement
- Commit after each RED-GREEN-REFACTOR cycle
- Commit message format: "feat: <desc> (bd-xxxx)" or "feat: <desc>" if no beads
- Report status: DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT

## Current Codebase Context
{auto-detected: existing patterns, imports, file structure near target files}
```

## Token Budget Guidelines

| Section | Max Tokens |
|---------|-----------|
| Context (spec excerpt) | 500 |
| Task Description | 300 |
| Design Reference | 300 |
| Tech Stack | 100 |
| Rules | 100 |
| Codebase Context | 200 |
| Template overhead | 100 |
| **Total** | **~1600** |

Remaining budget (~2400 tokens) is for the sub-agent's working space.
````

- [ ] **Step 2: Verify file was created**

Run: `head -5 .claude/skills/c4flow/references/sub-agent-prompt-template.md`
Expected: First 5 lines of the file

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/c4flow/references/sub-agent-prompt-template.md
git commit -m "docs: add c4flow sub-agent prompt template"
```

### Task 5: Create spec templates (5 files)

**Files:**
- Create: `.claude/skills/c4flow/references/spec-templates/research-template.md`
- Create: `.claude/skills/c4flow/references/spec-templates/proposal-template.md`
- Create: `.claude/skills/c4flow/references/spec-templates/tech-stack-template.md`
- Create: `.claude/skills/c4flow/references/spec-templates/spec-template.md`
- Create: `.claude/skills/c4flow/references/spec-templates/design-template.md`

- [ ] **Step 1: Write research-template.md**

```markdown
# Research: <feature-name>

## Problem Statement
What problem does this feature solve? Who has this problem?

## Competitive Landscape
- **Competitor A**: What they do, strengths, weaknesses
- **Competitor B**: ...

## User Personas
- **Persona 1**: Role, goals, pain points
- **Persona 2**: ...

## Key Requirements (Discovered)
- Requirement 1
- Requirement 2

## Technical Constraints
- Constraint 1
- Constraint 2

## Risks
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Risk 1 | ... | ... | ... |

## Recommendations
Summary of findings and suggested direction.
```

- [ ] **Step 2: Write proposal-template.md**

```markdown
# Proposal: <feature-name>

## Why
Motivation for this feature. What problem does it solve? Why now?

## What Changes
What will change. New capabilities, modifications, or removals.

## Capabilities

### New Capabilities
- `<capability-name>`: Brief description of what this capability covers

### Modified Capabilities
- `<existing-name>`: What requirement is changing

## Scope

### In Scope
- Item 1
- Item 2

### Out of Scope (Non-Goals)
- Item 1
- Item 2

## Success Criteria
- Criterion 1
- Criterion 2

## Impact
Affected code, APIs, dependencies, systems.
```

- [ ] **Step 3: Write tech-stack-template.md**

```markdown
# Tech Stack: <feature-name>

## Frontend
- **Framework**:
- **Styling**:
- **State Management**:

## Backend
- **Framework**:
- **Database**:
- **Cache**:
- **Message Queue**:

## Infrastructure
- **Cloud Provider**:
- **Container Runtime**:
- **IaC Tool**: (Terraform / Pulumi / CDK)

## CI/CD
- **Pipeline**: (GitHub Actions / GitLab CI / etc.)

## Monitoring & Logging
- **APM**:
- **Logging**:
- **Alerting**:

## Deployment Strategy
- **Strategy**: (Rolling / Blue-Green / Canary)
- **Environments**:
```

- [ ] **Step 4: Write spec-template.md**

```markdown
# Spec: <feature-name>

## ADDED Requirements

### Requirement: <requirement-name>
<requirement description>

**Priority**: MUST / SHOULD / MAY

#### Scenario: <scenario-name>
- **GIVEN** <precondition>
- **WHEN** <action>
- **THEN** <expected outcome>

#### Scenario: <scenario-name-2>
- **GIVEN** <precondition>
- **WHEN** <action>
- **THEN** <expected outcome>

## MODIFIED Requirements
(If modifying existing behavior)

### Requirement: <existing-requirement>
**Was**: <previous behavior>
**Now**: <new behavior>

#### Scenario: ...

## REMOVED Requirements
(If removing existing behavior)

### Requirement: <requirement-being-removed>
**Reason**: Why this is being removed
```

- [ ] **Step 5: Write design-template.md**

```markdown
# Design: <feature-name>

## Context
Background and current state.

## Architecture Overview
High-level architecture description.

## Components
### Component 1: <name>
- **Purpose**:
- **Interface**:
- **Dependencies**:

### Component 2: <name>
...

## Data Model
Schema, entities, relationships.

## API Design
Endpoints, request/response formats.

## Error Handling
Error types, recovery strategies.

## Goals / Non-Goals

**Goals:**
- What this design aims to achieve

**Non-Goals:**
- What is explicitly out of scope

## Decisions
Key design decisions with rationale and alternatives considered.

## Risks / Trade-offs
Known risks and trade-offs accepted.

## Testing Strategy
How this will be tested (unit, integration, e2e).
```

- [ ] **Step 6: Verify all 5 template files exist**

Run: `ls .claude/skills/c4flow/references/spec-templates/`
Expected: `design-template.md  proposal-template.md  research-template.md  spec-template.md  tech-stack-template.md`

- [ ] **Step 7: Commit**

```bash
git add .claude/skills/c4flow/references/spec-templates/
git commit -m "docs: add c4flow spec templates (forked from OpenSpec)"
```

---

## Chunk 2: Orchestrator and Commands

### Task 6: Create master SKILL.md (orchestrator)

**Files:**
- Create: `.claude/skills/c4flow/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

This is the core orchestrator. It defines the c4flow skill, its state machine behavior, and how it dispatches to phase skills. Note: content contains nested code blocks — write as-is.

````markdown
---
name: c4flow
description: Orchestrate the complete c4flow agentic development workflow — from research through deployment.
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
       "startedAt": null,
       "completedStates": [],
       "failedAttempts": 0,
       "beadsEpic": null,
       "worktree": null,
       "prNumber": null,
       "lastError": null
     }
     ```
   - If the file exists but is invalid JSON, warn the user that state was lost and create a fresh file

2. Display the current state using the format from `/c4flow:status`

3. Branch based on `currentState`:

### If IDLE
- If arguments were passed (e.g., via `/c4flow:run my feature idea`), use them as the feature name/description instead of asking
- Otherwise, ask the user for a feature name and description
- Kebab-case the feature name for the directory (e.g., "User Auth" → "user-auth")
- Update `.state.json`: set `feature`, `startedAt` to today's date, advance `currentState` to `RESEARCH`
- Proceed to RESEARCH

### If DONE
- Tell the user: "Workflow complete for '{feature}'."
- Ask: "Start a new feature or review the completed work?"
- If new feature: reset `.state.json` to IDLE state, ask for new feature info
- If review: show summary of completed states and output files

### If state is RESEARCH or SPEC (implemented skills)
- Check for partial output from a previous interrupted session:
  - RESEARCH: check if `docs/specs/{feature}/research.md` exists
  - SPEC: check which of `proposal.md`, `tech-stack.md`, `spec.md`, `design.md` exist in `docs/specs/{feature}/`
- If partial output found: present it to user, ask "Reuse existing {files} or regenerate?"
- Run the skill for the current state (see Skill Dispatch below)
- After skill completes, check the exit gate condition (see `references/phase-transitions.md`)
- If gate passes: add current state to `completedStates`, advance `currentState`, write `.state.json`
- If gate fails: tell user what's missing, ask what to do

### If state is any other (unimplemented skills: DESIGN through DEPLOY)
- Tell the user: "**{state}** (Phase {N}: {phase-name}) is not yet implemented."
- Show the gate condition that would need to pass to advance
- Offer options:
  1. Go back to a previous state
  2. Stop the workflow here

## Skill Dispatch

### RESEARCH (Sub-agent)
Dispatch a sub-agent with this prompt:

```
You are a research sub-agent for c4flow. Your task is to research a feature idea and produce a structured research document.

Feature: {feature name}
Description: {feature description from user}

Instructions:
1. Use WebSearch to research the competitive landscape, existing solutions, and best practices for this feature
2. Use WebFetch to pull key details from the most relevant pages
3. Structure your findings into the research template format (see below)
4. Write the output to: docs/specs/{feature}/research.md
5. Return a brief summary of your findings

Research Template:
{contents of references/spec-templates/research-template.md}

Report your status at the end:
- DONE: Research complete
- DONE_WITH_CONCERNS: Complete but with noted concerns (explain)
- BLOCKED: Cannot proceed (explain why)
- NEEDS_CONTEXT: Need more information from the user (explain what)
```

After sub-agent returns:
- If DONE or DONE_WITH_CONCERNS: present summary to user, ask "Does this research look complete? Ready to move to spec generation?"
- If BLOCKED or NEEDS_CONTEXT: present the issue to user, ask for guidance

### SPEC (Main agent)
This runs in the main agent (you). Follow the spec skill at `phases/02-spec/SKILL.md`.

## State Management

After each state transition:
1. Add the completed state to `completedStates`
2. Set `currentState` to the next state
3. Reset `failedAttempts` to 0
4. Clear `lastError`
5. Write the updated `.state.json`

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
````

- [ ] **Step 2: Verify file exists and has YAML frontmatter**

Run: `head -4 .claude/skills/c4flow/SKILL.md`
Expected:
```
---
name: c4flow
description: Orchestrate the complete c4flow agentic development workflow — from research through deployment.
---
```

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/c4flow/SKILL.md
git commit -m "feat: add c4flow master orchestrator skill"
```

### Task 7: Create /c4flow:run command

**Files:**
- Create: `.claude/commands/c4flow/run.md`

- [ ] **Step 1: Write run.md**

```markdown
# /c4flow:run — Start or Resume Workflow

Read the c4flow skill at `.claude/skills/c4flow/SKILL.md` and follow its instructions to start or resume the agentic development workflow.

If the user provided a feature idea with this command, pass it along. Otherwise, the orchestrator will ask for one.

$ARGUMENTS
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/c4flow/run.md
git commit -m "feat: add /c4flow:run command"
```

### Task 8: Create /c4flow:status command

**Files:**
- Create: `.claude/commands/c4flow/status.md`

- [ ] **Step 1: Write status.md**

Note: content contains nested code blocks — write as-is.

````markdown
# /c4flow:status — Show Workflow State

Read the state file at `docs/c4flow/.state.json`.

If the file does not exist, display:
```
No active c4flow workflow. Run /c4flow:run to start.
```

If the file exists, display the workflow status in this format:

```
c4flow: {feature}
State: {currentState} (Phase {N}: {phase-name})
Started: {startedAt}

Progress:
```

For each state in the workflow order (RESEARCH, SPEC, DESIGN, BEADS, CODE, TEST, REVIEW, VERIFY, PR, PR_REVIEW_LOOP, MERGE, DEPLOY), show:
- `[x]` if the state is in `completedStates`
- `[>]` if the state is the `currentState`
- `[ ]` if the state is pending

After the completed states, show what output files exist for completed phases. For example:
- RESEARCH: `research.md`
- SPEC: `proposal.md`, `tech-stack.md`, `spec.md`, `design.md`

For unimplemented states (DESIGN through DEPLOY), append "— not yet implemented".

If `lastError` is set, show it at the bottom:
```
Last error: {lastError}
Failed attempts: {failedAttempts}
```

Phase mapping:
- Phase 1 (Research & Spec): RESEARCH, SPEC
- Phase 2 (Design & Beads): DESIGN, BEADS
- Phase 3 (Implementation): CODE, (TDD)
- Phase 4 (Testing): TEST, (E2E)
- Phase 5 (Review & QA): REVIEW, VERIFY
- Phase 6 (Release): PR, PR_REVIEW_LOOP, MERGE, DEPLOY
````

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/c4flow/status.md
git commit -m "feat: add /c4flow:status command"
```

---

## Chunk 3: Implemented Phase Skills

### Task 9: Create /c4flow:research skill

**Files:**
- Create: `.claude/skills/c4flow/phases/01-research/SKILL.md`

- [ ] **Step 1: Write the research skill**

Note: content contains nested code blocks — write as-is.

````markdown
---
name: c4flow:research
description: Perform market and technical research on a feature idea using web search.
---

# /c4flow:research — Market/Tech Research

**Phase**: 1: Research & Spec
**Agent type**: Sub-agent (dispatched by orchestrator)
**Status**: Implemented

## Input
- Feature name (kebab-cased)
- Feature description from user

## Output
- `docs/specs/<feature>/research.md`

## Instructions

You are a research sub-agent. Your job is to thoroughly research a feature idea and produce a structured research document.

### Step 1: Research
Use `WebSearch` to find:
- Competitive landscape: who else has built this, what do they do well/poorly?
- Best practices: what are the established patterns for this type of feature?
- Technical approaches: what technologies and architectures are commonly used?
- User expectations: what do users typically expect from this type of feature?

### Step 2: Deep Dive
Use `WebFetch` on the most relevant results to gather detailed information:
- Feature comparisons
- Technical implementation details
- Common pitfalls and lessons learned

### Step 3: Structure Findings
Create the directory if it doesn't exist:
```bash
mkdir -p docs/specs/<feature>
```

Write your findings to `docs/specs/<feature>/research.md` using the template from `references/spec-templates/research-template.md`. Fill in every section:

- **Problem Statement**: Synthesize the core problem from your research
- **Competitive Landscape**: List 3-5 competitors/alternatives with strengths and weaknesses
- **User Personas**: Identify 2-3 key user types
- **Key Requirements**: List requirements discovered through research
- **Technical Constraints**: Note technical limitations or considerations
- **Risks**: Identify risks with likelihood, impact, and mitigation strategies
- **Recommendations**: Provide your recommended direction based on findings

### Step 4: Report Status
At the end of your work, report one of:
- **DONE**: Research complete, document written
- **DONE_WITH_CONCERNS**: Complete, but note any concerns (e.g., limited information available, conflicting sources)
- **BLOCKED**: Cannot proceed — explain why (e.g., topic is too vague, no web access)
- **NEEDS_CONTEXT**: Need more information from the user — explain what you need
````

- [ ] **Step 2: Verify the file**

Run: `head -4 .claude/skills/c4flow/phases/01-research/SKILL.md`
Expected:
```
---
name: c4flow:research
description: Perform market and technical research on a feature idea using web search.
---
```

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/c4flow/phases/01-research/SKILL.md
git commit -m "feat: add /c4flow:research skill (Phase 1)"
```

### Task 10: Create /c4flow:spec skill

**Files:**
- Create: `.claude/skills/c4flow/phases/02-spec/SKILL.md`

- [ ] **Step 1: Write the spec skill**

Note: content contains nested code blocks — write as-is.

````markdown
---
name: c4flow:spec
description: Generate structured spec artifacts (proposal, tech-stack, spec, design) through interactive collaboration.
---

# /c4flow:spec — Spec Generation

**Phase**: 1: Research & Spec
**Agent type**: Main agent (interactive with user)
**Status**: Implemented

## Input
- `docs/specs/<feature>/research.md` (from research phase)

## Output
- `docs/specs/<feature>/proposal.md`
- `docs/specs/<feature>/tech-stack.md`
- `docs/specs/<feature>/spec.md`
- `docs/specs/<feature>/design.md`

## Artifact Dependency Graph

```
proposal.md (root — generate first)
    |
    +--- tech-stack.md (requires: proposal)
    |
    +--- spec.md (requires: proposal)
    |
    +--- design.md (requires: proposal, tech-stack, spec)
```

## Instructions

You are the spec generation agent. You work interactively with the user to create four planning artifacts. Generate each artifact one at a time, in dependency order. Present each to the user for approval before moving to the next.

### Step 1: Read Research Context
Read `docs/specs/<feature>/research.md` to understand the feature context, competitive landscape, requirements, and constraints discovered during research.

### Step 2: Generate proposal.md
Using the template from `references/spec-templates/proposal-template.md`:

1. Draft the proposal based on the research findings
2. Fill in: Why (motivation), What Changes, Capabilities (New/Modified), Scope (In/Out), Success Criteria, Impact
3. Present the draft to the user
4. Iterate based on feedback until the user approves
5. Write the approved version to `docs/specs/<feature>/proposal.md`

### Step 3: Generate tech-stack.md
Using the template from `references/spec-templates/tech-stack-template.md`:

1. Based on the proposal and research, suggest technology choices for each category
2. Present the suggestions to the user with your reasoning
3. Let the user choose or modify each category
4. Skip categories that don't apply to this feature (e.g., skip Frontend if it's a backend-only feature)
5. Write the finalized choices to `docs/specs/<feature>/tech-stack.md`

### Step 4: Generate spec.md
Using the template from `references/spec-templates/spec-template.md`:

1. Based on the proposal, extract behavioral requirements
2. Write each requirement with:
   - A clear name and description
   - Priority: MUST / SHOULD / MAY
   - One or more scenarios in GIVEN/WHEN/THEN format
3. Use delta operations: ADDED (new behavior), MODIFIED (changed behavior), REMOVED (deleted behavior)
4. Present to the user for review
5. Iterate until approved
6. Write to `docs/specs/<feature>/spec.md`

### Step 5: Generate design.md
Using the template from `references/spec-templates/design-template.md`:

1. Based on proposal, tech-stack, and spec, design the technical architecture
2. Fill in: Context, Architecture Overview, Components, Data Model, API Design, Error Handling, Goals/Non-Goals, Decisions, Risks/Trade-offs, Testing Strategy
3. Present to the user for review
4. Iterate until approved
5. Write to `docs/specs/<feature>/design.md`

### Step 6: Completion
All four artifacts are written. Report back to the orchestrator that SPEC is complete. The orchestrator will check the exit gate (all 4 files exist) and advance the state.
````

- [ ] **Step 2: Verify the file**

Run: `head -4 .claude/skills/c4flow/phases/02-spec/SKILL.md`
Expected:
```
---
name: c4flow:spec
description: Generate structured spec artifacts (proposal, tech-stack, spec, design) through interactive collaboration.
---
```

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/c4flow/phases/02-spec/SKILL.md
git commit -m "feat: add /c4flow:spec skill (Phase 1)"
```

---

## Chunk 4: Stub Skills

### Task 11: Create all 13 stub skills

**Files:**
- Create: `.claude/skills/c4flow/phases/03-design/SKILL.md`
- Create: `.claude/skills/c4flow/phases/04-beads/SKILL.md`
- Create: `.claude/skills/c4flow/phases/05-code/SKILL.md`
- Create: `.claude/skills/c4flow/phases/06-tdd/SKILL.md`
- Create: `.claude/skills/c4flow/phases/07-test/SKILL.md`
- Create: `.claude/skills/c4flow/phases/08-e2e/SKILL.md`
- Create: `.claude/skills/c4flow/phases/09-review/SKILL.md`
- Create: `.claude/skills/c4flow/phases/10-verify/SKILL.md`
- Create: `.claude/skills/c4flow/phases/11-pr/SKILL.md`
- Create: `.claude/skills/c4flow/phases/12-pr-review/SKILL.md`
- Create: `.claude/skills/c4flow/phases/13-infra/SKILL.md`
- Create: `.claude/skills/c4flow/phases/14-merge/SKILL.md`
- Create: `.claude/skills/c4flow/phases/15-deploy/SKILL.md`

Each stub follows the same pattern. The exact content for each is listed below.

- [ ] **Step 1: Write 03-design stub**

```markdown
---
name: c4flow:design
description: Generate design system and mockups for the feature.
---

# /c4flow:design — Design System + Mockups

**Phase**: 2: Design & Beads
**Status**: Not yet implemented

This skill is part of the c4flow workflow but has not been implemented yet.
Run `/c4flow:status` to see the current workflow state.
```

- [ ] **Step 2: Write 04-beads stub**

```markdown
---
name: c4flow:beads
description: Break down the feature into tasks and create a beads epic.
---

# /c4flow:beads — Task Breakdown

**Phase**: 2: Design & Beads
**Status**: Not yet implemented

This skill is part of the c4flow workflow but has not been implemented yet.
Run `/c4flow:status` to see the current workflow state.
```

- [ ] **Step 3: Write 05-code stub**

```markdown
---
name: c4flow:code
description: Execute code implementation via sub-agents, one per task.
---

# /c4flow:code — Code Execution

**Phase**: 3: Implementation
**Status**: Not yet implemented

This skill is part of the c4flow workflow but has not been implemented yet.
Run `/c4flow:status` to see the current workflow state.
```

- [ ] **Step 4: Write 06-tdd stub**

```markdown
---
name: c4flow:tdd
description: Test-driven development — RED-GREEN-REFACTOR cycles.
---

# /c4flow:tdd — Test-Driven Development

**Phase**: 3: Implementation (merged with CODE sub-agent)
**Status**: Not yet implemented

This skill is part of the c4flow workflow but has not been implemented yet.
Run `/c4flow:status` to see the current workflow state.
```

- [ ] **Step 5: Write 07-test stub**

```markdown
---
name: c4flow:test
description: Run unit and integration tests, check coverage thresholds.
---

# /c4flow:test — Unit + Integration Tests

**Phase**: 4: Testing
**Status**: Not yet implemented

This skill is part of the c4flow workflow but has not been implemented yet.
Run `/c4flow:status` to see the current workflow state.
```

- [ ] **Step 6: Write 08-e2e stub**

```markdown
---
name: c4flow:e2e
description: Generate and run end-to-end tests (manual trigger).
---

# /c4flow:e2e — End-to-End Tests

**Phase**: 4: Testing (manual trigger — not part of auto flow)
**Status**: Not yet implemented

This skill is part of the c4flow workflow but has not been implemented yet.
Run `/c4flow:status` to see the current workflow state.
```

- [ ] **Step 7: Write 09-review stub**

```markdown
---
name: c4flow:review
description: Local AI code review loop — fix CRITICAL and HIGH issues automatically.
---

# /c4flow:review — Local AI Review Loop

**Phase**: 5: Review & QA
**Status**: Not yet implemented

This skill is part of the c4flow workflow but has not been implemented yet.
Run `/c4flow:status` to see the current workflow state.
```

- [ ] **Step 8: Write 10-verify stub**

```markdown
---
name: c4flow:verify
description: Quality gate — build, type check, lint, tests, debug log audit.
---

# /c4flow:verify — Quality Gate

**Phase**: 5: Review & QA
**Status**: Not yet implemented

This skill is part of the c4flow workflow but has not been implemented yet.
Run `/c4flow:status` to see the current workflow state.
```

- [ ] **Step 9: Write 11-pr stub**

```markdown
---
name: c4flow:pr
description: Create a pull request with spec summary, task list, and test results.
---

# /c4flow:pr — Create Pull Request

**Phase**: 6: Release
**Status**: Not yet implemented

This skill is part of the c4flow workflow but has not been implemented yet.
Run `/c4flow:status` to see the current workflow state.
```

- [ ] **Step 10: Write 12-pr-review stub**

```markdown
---
name: c4flow:pr-review
description: PR comment review loop — load comments, fix, push, repeat.
---

# /c4flow:pr-review — PR Comment Review Loop

**Phase**: 6: Release
**Status**: Not yet implemented

This skill is part of the c4flow workflow but has not been implemented yet.
Run `/c4flow:status` to see the current workflow state.
```

- [ ] **Step 11: Write 13-infra stub**

```markdown
---
name: c4flow:infra
description: Generate Infrastructure as Code based on tech-stack.md (manual trigger).
---

# /c4flow:infra — Infrastructure as Code

**Phase**: 6: Release (manual trigger — not part of auto flow)
**Status**: Not yet implemented

This skill is part of the c4flow workflow but has not been implemented yet.
Run `/c4flow:status` to see the current workflow state.
```

- [ ] **Step 12: Write 14-merge stub**

```markdown
---
name: c4flow:merge
description: Merge PR to main — pre-checks, merge strategy, cleanup.
---

# /c4flow:merge — Merge

**Phase**: 6: Release
**Status**: Not yet implemented

This skill is part of the c4flow workflow but has not been implemented yet.
Run `/c4flow:status` to see the current workflow state.
```

- [ ] **Step 13: Write 15-deploy stub**

```markdown
---
name: c4flow:deploy
description: Deploy to production — detect target, show plan, verify health.
---

# /c4flow:deploy — Deploy

**Phase**: 6: Release
**Status**: Not yet implemented

This skill is part of the c4flow workflow but has not been implemented yet.
Run `/c4flow:status` to see the current workflow state.
```

- [ ] **Step 14: Verify all 13 stub files exist**

Run: `find .claude/skills/c4flow/phases -name "SKILL.md" | sort`
Expected: 15 SKILL.md files (01-research through 15-deploy)

- [ ] **Step 15: Commit**

```bash
git add .claude/skills/c4flow/phases/
git commit -m "feat: add stub skills for phases 2-6 (not yet implemented)"
```

---

## Chunk 5: Verification

### Task 12: Verify complete plugin structure

**Files:** (none — verification only)

- [ ] **Step 1: Count all files**

Run: `find .claude/skills/c4flow .claude/commands/c4flow -type f | wc -l`
Expected: 26

- [ ] **Step 2: List all files**

Run: `find .claude/skills/c4flow .claude/commands/c4flow -type f | sort`
Expected:
```
.claude/commands/c4flow/run.md
.claude/commands/c4flow/status.md
.claude/skills/c4flow/SKILL.md
.claude/skills/c4flow/phases/01-research/SKILL.md
.claude/skills/c4flow/phases/02-spec/SKILL.md
.claude/skills/c4flow/phases/03-design/SKILL.md
.claude/skills/c4flow/phases/04-beads/SKILL.md
.claude/skills/c4flow/phases/05-code/SKILL.md
.claude/skills/c4flow/phases/06-tdd/SKILL.md
.claude/skills/c4flow/phases/07-test/SKILL.md
.claude/skills/c4flow/phases/08-e2e/SKILL.md
.claude/skills/c4flow/phases/09-review/SKILL.md
.claude/skills/c4flow/phases/10-verify/SKILL.md
.claude/skills/c4flow/phases/11-pr/SKILL.md
.claude/skills/c4flow/phases/12-pr-review/SKILL.md
.claude/skills/c4flow/phases/13-infra/SKILL.md
.claude/skills/c4flow/phases/14-merge/SKILL.md
.claude/skills/c4flow/phases/15-deploy/SKILL.md
.claude/skills/c4flow/references/phase-transitions.md
.claude/skills/c4flow/references/spec-templates/design-template.md
.claude/skills/c4flow/references/spec-templates/proposal-template.md
.claude/skills/c4flow/references/spec-templates/research-template.md
.claude/skills/c4flow/references/spec-templates/spec-template.md
.claude/skills/c4flow/references/spec-templates/tech-stack-template.md
.claude/skills/c4flow/references/sub-agent-prompt-template.md
.claude/skills/c4flow/references/workflow-state.md
```

- [ ] **Step 3: Verify all skills have YAML frontmatter**

Run: `for f in $(find .claude/skills/c4flow -name "SKILL.md" | sort); do echo "=== $f ==="; head -1 "$f"; done`
Expected: Every file starts with `---`

- [ ] **Step 4: Verify commands are valid markdown**

Run: `head -2 .claude/commands/c4flow/run.md .claude/commands/c4flow/status.md`
Expected: Both start with `# /c4flow:`
