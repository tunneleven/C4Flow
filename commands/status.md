---
description: Show current C4Flow workflow state and progress
allowed-tools: ["Read", "Glob"]
---

Read the state file at `docs/c4flow/.state.json`.

If the file does not exist, display:

> No active c4flow workflow. Run `/c4flow:run` to start.

If the file exists, display the workflow status in this format:

```
c4flow: {feature}
State: {currentState} (Phase {N}: {phase-name})
Started: {startedAt}
```

Progress:

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
