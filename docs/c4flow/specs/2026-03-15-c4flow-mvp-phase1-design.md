# c4flow MVP — Phase 1 Implementation Design

**Date:** 2026-03-15
**Status:** Draft
**Scope:** Full orchestrator shell + Phase 1 skills (Research & Spec)
**Base design:** [c4flow Workflow Design](2026-03-13-c4flow-workflow-design.md)

## Overview

Build the complete c4flow plugin skeleton with a full 14-state orchestrator and two implemented Phase 1 skills (`/c4flow:research` and `/c4flow:spec`). All other skills are stubs that report "not yet implemented." Spec artifact generation is forked from OpenSpec's templates and schema concepts — no `openspec` CLI dependency.

### Decisions

- **Scope**: Full 14-state orchestrator shell, only Phase 1 skills implemented
- **OpenSpec integration**: Fork templates and concepts, no CLI dependency
- **Spec output path**: `docs/specs/<feature>/` — supersedes `docs/c4flow/specs/<feature>/` from the base design for all phases, not just Phase 1
- **Research**: Full web research via sub-agent using WebSearch + WebFetch
- **Feature naming**: Feature names are kebab-cased for directory names (e.g., `user-auth`, `payment-flow`)
- **GitHub Action**: Deferred to Phase 6 (Release) implementation
- **Concurrency**: Claude Code is single-session; `.state.json` is not designed for concurrent access

## Plugin File Structure

```
.claude/skills/c4flow/
  SKILL.md                          # Master skill — full 14-state orchestrator
  references/
    workflow-state.md               # State machine definition (all 14 states)
    phase-transitions.md            # Gate rules + error handling
    sub-agent-prompt-template.md    # Template for constructing sub-agent prompts
    spec-templates/
      research-template.md          # Research output format
      proposal-template.md          # Forked from OpenSpec
      tech-stack-template.md        # c4flow-specific
      spec-template.md              # Forked from OpenSpec (Given/When/Then)
      design-template.md            # Forked from OpenSpec
  phases/
    01-research/SKILL.md            # /c4flow:research — IMPLEMENTED
    02-spec/SKILL.md                # /c4flow:spec — IMPLEMENTED
    03-design/SKILL.md              # Stub
    04-beads/SKILL.md               # Stub
    05-code/SKILL.md                # Stub
    06-tdd/SKILL.md                 # Stub
    07-test/SKILL.md                # Stub
    08-e2e/SKILL.md                 # Stub
    09-review/SKILL.md              # Stub
    10-verify/SKILL.md              # Stub
    11-pr/SKILL.md                  # Stub
    12-pr-review/SKILL.md           # Stub
    13-infra/SKILL.md               # Stub (manual trigger, not in state machine)
    14-merge/SKILL.md               # Stub
    15-deploy/SKILL.md              # Stub

.claude/commands/c4flow/
  run.md                            # /c4flow:run — orchestrator entry point
  status.md                         # /c4flow:status — show workflow state

docs/c4flow/
  .state.json                       # State persistence (runtime, created on first run)

docs/specs/                         # Generated spec artifacts per feature (runtime)
```

## Component 1: Orchestrator (SKILL.md)

### State Machine

14 states with linear transitions:

```
IDLE → RESEARCH → SPEC → DESIGN → BEADS → CODE → TEST
  → REVIEW → VERIFY → PR → PR_REVIEW_LOOP → MERGE → DEPLOY → DONE
```

### State Persistence

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

### State-to-Skill Mapping

| State | Skill Path | Agent | Implemented |
|-------|-----------|-------|-------------|
| RESEARCH | phases/01-research/SKILL.md | Sub-agent | Yes |
| SPEC | phases/02-spec/SKILL.md | Main | Yes |
| DESIGN | phases/03-design/SKILL.md | Sub-agent + Main confirm | No (stub) |
| BEADS | phases/04-beads/SKILL.md | Main | No (stub) |
| CODE | phases/05-code/SKILL.md | Sub-agent per task | No (stub) |
| TDD | phases/06-tdd/SKILL.md | Sub-agent (merged with code) | No (stub) |
| TEST | phases/07-test/SKILL.md | Sub-agent | No (stub) |
| E2E | phases/08-e2e/SKILL.md | Sub-agent (manual trigger) | No (stub) |
| REVIEW | phases/09-review/SKILL.md | Sub-agent loop | No (stub) |
| VERIFY | phases/10-verify/SKILL.md | Sub-agent | No (stub) |
| PR | phases/11-pr/SKILL.md | Main | No (stub) |
| PR_REVIEW_LOOP | phases/12-pr-review/SKILL.md | Sub-agent loop | No (stub) |
| INFRA | phases/13-infra/SKILL.md | Sub-agent (manual trigger) | No (stub) |
| MERGE | phases/14-merge/SKILL.md | Main | No (stub) |
| DEPLOY | phases/15-deploy/SKILL.md | Main | No (stub) |

### Gate Conditions

| From → To | Gate Condition |
|-----------|---------------|
| IDLE → RESEARCH | User provides feature idea |
| RESEARCH → SPEC | `docs/specs/<feature>/research.md` exists and user confirmed |
| SPEC → DESIGN | `proposal.md`, `tech-stack.md`, `spec.md`, `design.md` exist in `docs/specs/<feature>/` and user approved |
| DESIGN → BEADS | Design system + mockups approved by user |
| BEADS → CODE | Epic + tasks created, user confirmed |
| CODE → TEST | All assigned tasks closed |
| TEST → REVIEW | Tests pass, coverage >= threshold |
| REVIEW → VERIFY | 0 CRITICAL + 0 HIGH issues |
| VERIFY → PR | `Ready for PR: YES` |
| PR → PR_REVIEW_LOOP | PR created successfully |
| PR_REVIEW_LOOP → MERGE | 0 unresolved PR comments |
| MERGE → DEPLOY | Merge successful |
| DEPLOY → DONE | Deploy verified healthy |

### Orchestrator Behavior

```
1. Read docs/c4flow/.state.json
   - If missing → create with IDLE state
   - If corrupt → warn user, start fresh from IDLE
2. Display current state summary
3. If currentState is IDLE:
   - Ask user for feature name and description
   - Set feature, startedAt, advance to RESEARCH
4. If currentState maps to an unimplemented skill:
   - Tell user: "Phase X: {name} is not yet implemented."
   - Show what would need to happen to proceed
   - Offer: go back to previous state, or stop
5. If currentState maps to an implemented skill:
   - Run the skill for the current state
   - On completion → check exit gate (gate to transition to next state)
   - If exit gate passes → update completedStates, advance currentState
   - If exit gate fails → skill output is incomplete, ask user what to do
6. If currentState is DONE:
   - Ask: "Start new feature or review completed?"
7. Resume behavior:
   - If invoked mid-workflow → read .state.json, ask "Resume from {state}?"
   - Check for partial output (e.g., research.md exists but not confirmed)
   - If partial output found → present it to user, ask if it should be reused or regenerated
   - This avoids re-running expensive operations like web research
```

### Error Handling

| Scenario | Behavior |
|----------|----------|
| Sub-agent reports BLOCKED | Pause state, ask user for guidance |
| Sub-agent reports NEEDS_CONTEXT | Pause state, ask user for info, resume |
| Phase fails | Increment failedAttempts, retry up to 3x, then pause |
| 3+ consecutive failures | Suggest re-examining earlier phases, offer to go back |
| User wants to go back | Set currentState to desired state, mark subsequent as incomplete |
| State file missing/corrupt | Start fresh from IDLE, warn user |

## Component 2: /c4flow:research Skill

### Overview

Sub-agent skill that performs web research on a feature idea and produces a structured research document.

- **Agent type**: Sub-agent (dispatched by orchestrator)
- **Input**: Feature idea/description (from user via orchestrator)
- **Output**: `docs/specs/<feature>/research.md`
- **Status codes**: DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT

### Behavior

1. Receive feature idea from orchestrator prompt
2. Use `WebSearch` to research competitive landscape, existing solutions, best practices
3. Use `WebFetch` to pull details from relevant pages
4. Structure findings into `research.md` using the research template
5. Return summary + status to orchestrator

### Research Template

The canonical template is stored in `references/spec-templates/research-template.md`. The content below is the source of truth — the reference file must contain exactly this:

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

### Post-Research (Orchestrator)

After sub-agent returns, orchestrator:
1. Presents research summary to user
2. Asks: "Does this research look complete? Ready to move to spec generation?"
3. If yes → advance to SPEC state
4. If no → user can request more research or modify findings

## Component 3: /c4flow:spec Skill (Forked from OpenSpec)

### Overview

Main-agent skill that generates structured planning artifacts through interactive collaboration with the user.

- **Agent type**: Main agent (interactive)
- **Input**: `docs/specs/<feature>/research.md`
- **Output**: 4 artifacts in `docs/specs/<feature>/`

### Artifact Dependency Graph

Forked from OpenSpec's DAG model:

```
proposal.md (root — generated first)
    |
    +--- tech-stack.md (requires: proposal)
    |
    +--- spec.md (requires: proposal)
    |
    +--- design.md (requires: proposal, tech-stack, spec)
```

Each artifact is generated one at a time, presented to the user for approval, and iterated until confirmed. The inline template content below is the source of truth — corresponding files in `references/spec-templates/` must match exactly.

### Artifact: proposal.md

**Template** (forked from OpenSpec):

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

### Artifact: tech-stack.md

**Template** (c4flow-specific, not from OpenSpec):

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

**Behavior**: Present tech categories to user, let them choose or suggest options for each. Skip categories that don't apply to the feature.

### Artifact: spec.md

**Template** (forked from OpenSpec — Given/When/Then with delta operations):

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

### Artifact: design.md

**Template** (forked from OpenSpec):

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

### Spec Skill Behavior

```
1. Read docs/specs/<feature>/research.md for context
2. Generate proposal.md from template
   → Present to user
   → Iterate until user approves
   → Write to docs/specs/<feature>/proposal.md
3. Generate tech-stack.md
   → Present tech categories
   → User chooses/confirms each category
   → Skip irrelevant categories
   → Write to docs/specs/<feature>/tech-stack.md
4. Generate spec.md from template
   → Present requirements with Given/When/Then scenarios
   → Iterate until user approves
   → Write to docs/specs/<feature>/spec.md
5. Generate design.md from template
   → Present architecture, components, data model, APIs
   → Iterate until user approves
   → Write to docs/specs/<feature>/design.md
6. All artifacts written → return to orchestrator
```

## Component 4: /c4flow:run Command

Entry point for the orchestrator. File: `.claude/commands/c4flow/run.md`

Behavior:
1. Invoke the master SKILL.md orchestrator
2. The command file contains instructions to read `.state.json` and either start a new workflow or resume an existing one

## Component 5: /c4flow:status Command

Read-only status display. File: `.claude/commands/c4flow/status.md`

Reads `docs/c4flow/.state.json` and displays:

```
c4flow: <feature-name>
State: <current-state> (Phase X: <phase-name>)
Started: <date>

Progress:
  [x] RESEARCH  — research.md
  [x] SPEC      — proposal.md, tech-stack.md, spec.md, design.md
  [ ] DESIGN    — not yet implemented
  [ ] BEADS     — not yet implemented
  [ ] CODE      — not yet implemented
  [ ] TEST      — not yet implemented
  [ ] REVIEW    — not yet implemented
  [ ] VERIFY    — not yet implemented
  [ ] PR             — not yet implemented
  [ ] PR_REVIEW_LOOP — not yet implemented
  [ ] MERGE          — not yet implemented
  [ ] DEPLOY         — not yet implemented
```

If no `.state.json` exists, displays: "No active c4flow workflow. Run /c4flow:run to start."

## Component 6: Stub Skills (03-15)

Each stub skill file contains:

```markdown
---
name: c4flow:<skill-name>
description: <one-line description>
---

# /c4flow:<skill-name> — <Full Name>

**Phase**: <phase-number>: <phase-name>
**Status**: Not yet implemented

This skill is part of the c4flow workflow but has not been implemented yet.
Run `/c4flow:status` to see the current workflow state.
```

## Component 7: Reference Documents

### workflow-state.md

Documents the complete state machine: all 14 states, their transitions, gate conditions, and which phase each belongs to. Used by the orchestrator for reference.

### phase-transitions.md

Documents gate rules for each transition and error handling/recovery procedures. Used by the orchestrator for decision-making.

### sub-agent-prompt-template.md

Template for constructing sub-agent prompts (~2000 tokens max total context):

```markdown
# Task: {task_title}

## Context
{excerpt from relevant spec — max 500 tokens}

## Task Description
{full description with acceptance criteria}

## Files to Modify
{list of target files}

## Design Reference
{excerpt from design.md — max 300 tokens}

## Tech Stack
{from tech-stack.md}

## Rules
- Report status: DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT
```

Only used by implemented skills (research for MVP). Included for completeness and future phases.

## File Count Summary

| Category | Count |
|----------|-------|
| Master SKILL.md | 1 |
| Reference docs | 3 |
| Spec templates | 5 |
| Implemented skills | 2 |
| Stub skills | 13 |
| Commands | 2 |
| **Total files** | **26** |
