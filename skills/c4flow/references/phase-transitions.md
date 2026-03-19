# c4flow Phase Transitions

## Gate Conditions

Each state transition requires its gate condition to be met before advancing.

| From → To | Gate Condition | How to Check |
|-----------|---------------|--------------|
| IDLE → RESEARCH | User provides feature idea | User input received |
| RESEARCH → SPEC | `research.md` exists and user confirmed | Check `docs/specs/<feature>/research.md` exists |
| SPEC → DESIGN | All spec artifacts exist and user approved | Check `proposal.md`, `tech-stack.md`, `spec.md`, `design.md` in `docs/specs/<feature>/` |
| DESIGN → BEADS | (1) `MASTER.md` exists, (2) `screen-map.md` exists, (3) `.pen` file has Design System frame with reusable components, (4) `.pen` file has ≥1 screen frame, (5) all screens in `screen-map.md` have frames in `.pen`, (6) AI Slop Test + squint test passed on hero screen, (7) user approved final review | Check files exist + user approval |
| BEADS → CODE | Epic + tasks created, user confirmed | Check beads epic or `tasks.md` exists |
| CODE → TEST | All tasks closed (per-task reviews passed) | Check beads issues closed or `tasks.md` items checked |
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
