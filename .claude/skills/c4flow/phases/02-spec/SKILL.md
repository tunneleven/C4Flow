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
