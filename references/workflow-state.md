# c4flow Workflow State Machine

## States (14 working states + IDLE + DONE)

| # | State | Phase | Description |
|---|-------|-------|-------------|
| 0 | IDLE | — | No active workflow |
| 1 | RESEARCH | 1: Research & Spec | Market/tech research |
| 2 | SPEC | 1: Research & Spec | Spec artifact generation |
| 3 | DESIGN | 2: Design & Beads | Design system + mockups |
| 4 | BEADS | 2: Design & Beads | Task breakdown |
| 5 | CODE | 3: Implementation | Delegated implementation via the Superpowers subagent-driven workflow |
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

IDLE → RESEARCH → SPEC → DESIGN → BEADS → CODE → TEST → REVIEW → VERIFY → PR → PR_REVIEW_LOOP → MERGE → DEPLOY → DONE

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
| CODE | skills/code/SKILL.md | Main coordinator delegating to Superpowers sub-agents |
| TDD | phases/06-tdd/SKILL.md | Sub-agent (merged with code) |
| TEST | skills/test/SKILL.md | Sub-agent |
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
  "doltRemote": null,
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
- **doltRemote**: DoltHub remote URL for beads sync (e.g., "https://doltremoteapi.dolthub.com/org/repo")
- **worktree**: Path to active worktree, or null
- **prNumber**: PR number if created, or null
- **lastError**: Last error message, or null
