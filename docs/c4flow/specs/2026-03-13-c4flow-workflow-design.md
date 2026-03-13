# c4flow — Agentic Development Workflow Design

**Date:** 2026-03-13
**Status:** Draft
**Approach:** Self-Contained Claude Code Plugin
**Version:** 1.0

## Overview

c4flow is a self-contained Claude Code plugin that orchestrates a complete agentic software development workflow — from research through deployment. It provides **15 skills** grouped into **6 phases**, driven by an **auto-orchestrator** with a **14-state** state machine. Sub-agents handle autonomous execution; the main agent handles user interaction.

**External dependencies (user-installed, instructions in README):**
- **Beads (bd)** — issue tracking / task management
- **Pencil** — design mockups via MCP
- **UI/UX Pro Max Skill** — design system generation

Each has a graceful fallback when not installed.

### Glossary

| Term | Definition |
|---|---|
| **Phase** | High-level grouping of related work (6 total: Research & Spec, Design & Beads, Implementation, Testing, Review & QA, Release) |
| **Skill** | An individual `/c4flow:X` command that performs a specific action (15 total) |
| **State** | A position in the orchestrator's state machine (14 states: IDLE through DONE) |

A phase contains 1-4 skills. The state machine has 1 state per skill in the auto flow, plus IDLE and DONE.

## Architecture

### Plugin Structure

```
.claude/skills/c4flow/
  SKILL.md                          # Master skill — orchestrator
  references/
    workflow-state.md               # State machine definition
    phase-transitions.md            # Phase gate rules + error handling
    sub-agent-prompt-template.md    # Template for constructing sub-agent prompts
    tasks-md-format.md              # Fallback tasks.md format spec
  phases/
    01-research/SKILL.md            # /c4flow:research
    01-research/references/
      market-research-template.md
      tech-stack-selection.md
    02-spec/SKILL.md                # /c4flow:spec
    02-spec/references/
      spec-template.md
      infra-template.md
    03-design/SKILL.md              # /c4flow:design
    03-design/references/
      pencil-workflow.md
      uiux-promax-workflow.md
    04-beads/SKILL.md               # /c4flow:beads
    04-beads/references/
      task-breakdown-rules.md
    05-code/SKILL.md                # /c4flow:code
    05-code/references/
      sub-agent-prompt.md
    06-tdd/SKILL.md                 # /c4flow:tdd
    07-test/SKILL.md                # /c4flow:test
    08-e2e/SKILL.md                 # /c4flow:e2e
    09-review/SKILL.md              # /c4flow:review
    10-verify/SKILL.md              # /c4flow:verify
    11-pr/SKILL.md                  # /c4flow:pr
    12-pr-review/SKILL.md           # /c4flow:pr-review
    13-infra/SKILL.md               # /c4flow:infra
    14-deploy/SKILL.md              # /c4flow:deploy
    15-merge/SKILL.md               # /c4flow:merge

.claude/commands/c4flow/
  run.md                            # /c4flow:run (orchestrator entry point)
  status.md                         # /c4flow:status (show workflow state)

.github/workflows/
  c4flow-review.yml                 # GitHub Action — auto AI review on PR

docs/c4flow/
  specs/                            # Generated specs
  designs/                          # Design system + .pen files
```

**Note on commands vs skills:** Commands (`run.md`, `status.md`) are user-facing entry points invoked via `/c4flow:run` and `/c4flow:status`. Skills are the workflow definitions that commands and the orchestrator invoke internally.

### Orchestrator State Machine

The orchestrator (`/c4flow:run`) drives the workflow as a state machine. State is persisted in `docs/c4flow/.state.json`:

```json
{
  "version": 1,
  "currentState": "SPEC",
  "feature": "user-auth",
  "startedAt": "2026-03-13",
  "completedStates": ["RESEARCH"],
  "failedAttempts": 0,
  "beadsEpic": "bd-a1b2",
  "worktree": null,
  "prNumber": null,
  "lastError": null
}
```

**States and transitions:**

```
IDLE → RESEARCH → SPEC → DESIGN → BEADS → CODE → TEST
  → REVIEW → VERIFY → PR → PR_REVIEW_LOOP → MERGE → DEPLOY → DONE
```

**Gate conditions per transition:**

| From → To | Gate Condition |
|---|---|
| IDLE → RESEARCH | User provides feature idea |
| RESEARCH → SPEC | `research.md` exists and user confirmed |
| SPEC → DESIGN | `proposal.md`, `tech-stack.md`, `spec.md`, `design.md` exist and user approved |
| DESIGN → BEADS | Design system + mockups approved by user |
| BEADS → CODE | Epic + tasks created in beads (or tasks.md), user confirmed |
| CODE → TEST | All assigned tasks closed in beads |
| TEST → REVIEW | Tests pass, coverage >= threshold |
| REVIEW → VERIFY | 0 CRITICAL + 0 HIGH issues |
| VERIFY → PR | `Ready for PR: YES` |
| PR → PR_REVIEW_LOOP | PR created successfully |
| PR_REVIEW_LOOP → MERGE | 0 unresolved PR comments |
| MERGE → DEPLOY | Merge successful |
| DEPLOY → DONE | Deploy verified healthy |

**Error handling and recovery:**

| Scenario | Behavior |
|---|---|
| Sub-agent reports `BLOCKED` | Pause state, return to main agent, ask user for guidance |
| Sub-agent reports `NEEDS_CONTEXT` | Pause state, ask user for missing info, resume |
| Phase fails (build, tests) | Increment `failedAttempts`, retry up to 3 times, then pause and ask user |
| 3+ consecutive failures | Escalate: suggest re-examining spec/design, offer to go back to a previous state |
| User wants to go back | Set `currentState` to desired state, mark subsequent states as incomplete |
| State file missing/corrupt | Start fresh from IDLE, warn user about lost state |
| `/c4flow:run` invoked mid-workflow | Read `.state.json`, resume from `currentState`. Ask user: "Resume from {state}?" |
| `/c4flow:run` invoked with existing DONE state | Ask user: "Start new feature or review completed?" |

**Manual-trigger skills (not in state machine):**
- `/c4flow:e2e` — E2E tests, user calls when needed
- `/c4flow:infra` — IaC generation, user calls when needed (typically after spec or before deploy)

These can be invoked at any point without affecting the state machine.

### Main Agent vs Sub-Agent Distribution

| Skill | Agent | Reason |
|---|---|---|
| `/c4flow:run` (orchestrator) | **Main** | Coordinates, asks user |
| `/c4flow:research` | Sub-agent | Autonomous research |
| `/c4flow:spec` | **Main** | User chooses tech stack, confirms spec |
| `/c4flow:design` | Sub-agent + **Main** confirm | Sub-agent generates, main asks approve |
| `/c4flow:beads` | **Main** | Asks team size, confirms task assignment |
| `/c4flow:code` | Sub-agent per task | Each task gets a fresh sub-agent |
| `/c4flow:tdd` | Sub-agent (merged with code) | TDD is part of the code sub-agent |
| `/c4flow:test` | Sub-agent | Runs tests automatically |
| `/c4flow:e2e` | Sub-agent | **Manual trigger only** |
| `/c4flow:review` | Sub-agent | Autonomous review loop (max 5 iterations) |
| `/c4flow:verify` | Sub-agent | Autonomous quality gate |
| `/c4flow:pr` | **Main** | Confirm before creating PR |
| `/c4flow:pr-review` | Sub-agent loop | Load comments → fix → push (max 5 iterations) |
| `/c4flow:infra` | Sub-agent | **Manual trigger**, main reviews output |
| `/c4flow:merge` | **Main** | Confirm merge |
| `/c4flow:deploy` | **Main** | Confirm deploy |

### `/c4flow:status` — Show Workflow State

Reads `docs/c4flow/.state.json` and beads data to display:

```
c4flow: user-auth
State: CODE (Phase 3: Implementation)
Started: 2026-03-13

Progress:
  [x] RESEARCH  — research.md
  [x] SPEC      — proposal.md, tech-stack.md, spec.md, design.md
  [x] DESIGN    — MASTER.md, 3 .pen files
  [x] BEADS     — Epic bd-a1b2, 9 tasks (3 people)
  [ ] CODE      — 4/9 tasks done, 2 in progress, 3 pending
  [ ] TEST
  [ ] REVIEW
  [ ] VERIFY
  [ ] PR
  [ ] MERGE
  [ ] DEPLOY

Worktree: .claude/worktrees/user-auth (feat/user-auth)
Beads: bd ready --json | 3 tasks ready for current user
```

If beads not installed, shows task counts from `tasks.md` instead.

### Sub-Agent Prompt Construction

Each sub-agent receives a constructed prompt (never inherited session history):

```markdown
# Task: {task_title}

## Context
{excerpt from spec.md relevant to this task — max 500 tokens}

## Task Description
{full description from beads, including acceptance criteria}

## Files to Modify
{list of files from task description}

## Design Reference
{excerpt from design.md relevant to this task — max 300 tokens}

## Tech Stack
{from tech-stack.md — framework, language, testing framework}

## Rules
- Follow TDD: write failing test first, then implement
- Commit after each RED-GREEN-REFACTOR cycle
- Commit message format: "feat: <desc> (bd-xxxx)"
- Report status: DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT

## Current Codebase Context
{auto-detected: existing patterns, imports, file structure near target files}
```

Token budget: prompt context ~2000 tokens max, leaving working space for the sub-agent.

## Phase 1: Research & Spec

### `/c4flow:research` — Market/Tech Research (sub-agent)

**Input:** Feature idea description from user
**Output:** `docs/c4flow/specs/<feature>/research.md`

The sub-agent:
- Uses WebSearch + WebFetch to research competitive landscape
- Identifies user personas and key requirements
- Documents constraints and risks
- Returns summary to main agent for user confirmation

### `/c4flow:spec` — Spec Generation (main agent)

Generates structured planning artifacts (concepts from OpenSpec):

```
docs/c4flow/specs/<feature>/
  research.md          # From research phase
  proposal.md          # Why + What (motivation, scope, success criteria)
  tech-stack.md        # Tech stack + infrastructure selection
  spec.md              # Behavioral specs (MUST/SHOULD/MAY + Given/When/Then)
  design.md            # Technical design (architecture, data flow, APIs)
```

**`tech-stack.md` includes:**
- FE: framework, styling, state management
- BE: framework, database, cache, message queue
- Infrastructure: cloud provider, container runtime, IaC tool (Terraform/Pulumi/CDK)
- CI/CD: pipeline choice (GitHub Actions, GitLab CI, etc.)
- Monitoring & logging stack
- Deployment strategy (rolling, blue-green, canary)

Each artifact has a standard template in `references/`. Agent generates from template, user reviews and approves each section.

**Tasks are NOT created here** — task breakdown happens in the Beads phase after design is complete.

## Phase 2: Design & Beads

### `/c4flow:design` — Design System + Mockups

**Step 1: Design System (UI/UX Pro Max) — sub-agent**

Reads `spec.md` + `proposal.md` to understand product type, then:

```bash
python search.py "<product-description>" --design-system -p "<project-name>" --persist
```

Output: `docs/c4flow/designs/<feature>/MASTER.md` containing:
- Style recommendation (glassmorphism, minimalism, brutalism, etc.)
- Color palette (primary, secondary, accent, background, foreground, card, muted, border, destructive)
- Typography (heading + body font pairs, Google Fonts URL, CSS import, Tailwind config)
- Landing/layout pattern (section order, CTA placement, conversion strategy)
- UX guidelines and anti-patterns
- Effects & animations
- Per-page overrides in `docs/c4flow/designs/<feature>/pages/`

**Step 2: Mockup (Pencil MCP) — sub-agent**

Uses Pencil MCP tools to create wireframes/mockups based on the generated design system:
- Creates `.pen` files for each screen/page
- Output: `docs/c4flow/designs/<feature>/<screen>.pen`

**Step 3: User review — main agent**

Presents design system + mockups for user confirmation. Revises until approved.

**Fallbacks:**
- No UI/UX Pro Max → agent selects design system from best practices, notes install instructions
- No Pencil → text-based layout descriptions, notes install instructions

### `/c4flow:beads` — Task Breakdown (main agent)

**Pre-breakdown questions:**
1. How many people on the team? (name/role of each)
2. Expected timeline?
3. Confirm spec + design are complete?

**Breakdown logic:**

Reads `spec.md` + `design.md` + `.pen` files, then:

1. Creates 1 epic in beads:
   ```bash
   bd create "<feature>" -t epic -p 1 --json
   ```

2. Breaks into tasks following these rules:
   - **Minimize cross-person dependencies** — each person gets an independent group of tasks
   - **Parallel-first** — tasks across different people can run in parallel
   - **Dependencies only within same person** — if task A must finish before task B, assign both to the same person
   - **Integration tasks separate** — final integration/wiring tasks assigned to lead or shared

3. Each task created with full detail:
   ```bash
   bd create "Task title" \
     -t task \
     -p <0-4> \
     --description="Context: why this task is needed
   Input: what is needed to start (files, APIs, data)
   Output: expected deliverables
   Acceptance criteria: conditions for completion
   Files to modify: list of files
   Technical notes: implementation hints" \
     --deps parent-child:<epic-id> \
     --json

   bd update <task-id> --assignee "<person-name>"
   bd dep add <task-id> <depends-on-id>
   ```

**Example output for a 3-person team:**

```
Epic: bd-a1b2 "User Authentication"
├── Person A (Backend):
│   ├── bd-c3d4 [P1] "Setup auth database schema"
│   ├── bd-e5f6 [P1] "Implement JWT service" (depends: bd-c3d4)
│   └── bd-g7h8 [P2] "Add rate limiting middleware" (depends: bd-e5f6)
├── Person B (Frontend):
│   ├── bd-i9j0 [P1] "Create login/register UI components"
│   ├── bd-k1l2 [P1] "Implement auth state management"
│   └── bd-m3n4 [P2] "Add protected route wrapper" (depends: bd-k1l2)
├── Person C (Infra):
│   ├── bd-o5p6 [P1] "Setup auth service Terraform module"
│   └── bd-q7r8 [P2] "Configure secrets management"
└── Integration (shared):
    └── bd-s9t0 [P1] "Wire FE ↔ BE auth flow" (depends: bd-e5f6, bd-m3n4)
```

**Fallback if beads not installed:**

Creates `docs/c4flow/specs/<feature>/tasks.md` using this format:

```markdown
# Tasks: <feature>

## Person A (Backend)
### [ ] Task 1: Setup auth database schema [P1]
- **Depends on:** none
- **Assignee:** Person A
- **Description:** ...
- **Acceptance criteria:** ...
- **Files:** ...

### [ ] Task 2: Implement JWT service [P1]
- **Depends on:** Task 1
- ...
```

Task claiming = changing `[ ]` to `[x]`. No atomic claim or dependency resolution — user prompted to install beads for full functionality.

## Phase 3: Implementation

### `/c4flow:code` — Code Execution (sub-agent per task)

**Step 1: Setup worktree**
- Uses Claude Code `EnterWorktree` tool if available, otherwise `git worktree add`
- Branch: `feat/<feature>` or `fix/<feature>`
- Auto-detect tech stack from `tech-stack.md`, install dependencies
- If worktree already exists for this feature (resuming work), reuse it
- State file `worktree` field tracks the active worktree path

**Step 2: Load tasks from beads**
```bash
bd ready --assignee <current-user> --json  # Priority: current user's tasks first
```

If beads not installed, reads `tasks.md` and picks next unchecked task.

**Step 3: Sub-agent execution per task**

For each task:
1. **Claim**: `bd update <id> --claim`
2. **Dispatch sub-agent** with constructed context (see Sub-Agent Prompt Construction above)
3. **Sub-agent implements via TDD** (see below)
4. **Sub-agent reports**: `DONE` / `DONE_WITH_CONCERNS` / `BLOCKED` / `NEEDS_CONTEXT`
5. **Handle report:**
   - `DONE` → close task: `bd close <id> --reason "Completed: <summary>"`, next task
   - `DONE_WITH_CONCERNS` → close task, log concerns as new beads issue
   - `BLOCKED` → pause, return to main agent, ask user
   - `NEEDS_CONTEXT` → pause, ask user for info, re-dispatch sub-agent
6. **Next task**: load next ready task, repeat

**Multi-person mode:** Agent only works on tasks assigned to current user. Other people's tasks shown as read-only context.

### `/c4flow:tdd` — Test-Driven Development (part of code sub-agent)

Each task follows strict RED-GREEN-REFACTOR:

```
1. RED      — Write 1 failing test from acceptance criteria
2. VERIFY   — Run test, confirm it fails for the right reason
3. GREEN    — Write minimal code to pass
4. VERIFY   — Run test, confirm it passes
5. REFACTOR — Clean up, keep tests green
6. COMMIT   — git commit with task ID: "feat: <desc> (bd-xxxx)"
```

**Rules:**
- No code before tests
- One test at a time
- Commit after each RED-GREEN-REFACTOR cycle
- Complex tasks: multiple cycles

## Phase 4: Testing

### `/c4flow:test` — Unit + Integration Tests (sub-agent)

- Runs full test suite after implementation
- Checks coverage against threshold (configurable, default 80%)
- Report:
  ```
  Tests: 42 passed, 0 failed
  Coverage: 87% (branches: 82%, functions: 91%, lines: 89%)
  Uncovered: src/auth/edge-case.ts:45-52
  ```
- Low coverage → agent writes additional tests
- Test failures → systematic debugging (root cause first, not trial-and-error)

### `/c4flow:e2e` — End-to-End Tests (sub-agent, MANUAL TRIGGER)

**Not part of the auto flow.** User calls `/c4flow:e2e` explicitly when needed.

- Reads spec.md for user journeys (Given/When/Then scenarios)
- Generates test files using the project's E2E framework (detected from `tech-stack.md`, defaults to Playwright)
- Patterns:
  - Page Object Model
  - `data-testid` locators (no CSS selectors)
  - Each test isolated
  - Screenshots on failure
- Runs tests, fixes failures, reports results

## Phase 5: Review & QA

### `/c4flow:review` — Local AI Review Loop (sub-agent, max 5 iterations)

```
┌─→ Review code diff against base branch
│     ├─ Security: OWASP patterns, hardcoded secrets, injection
│     ├─ Quality: complexity, naming, SOLID, DRY
│     ├─ Spec compliance: code vs spec.md
│     └─ Output: issues [CRITICAL / HIGH / MEDIUM / LOW]
│
├─ CRITICAL or HIGH found?
│     YES → Fix automatically → increment iteration → loop ↑
│     NO  → Done
│
├─ 5 iterations reached?
│     YES → Stop, return to main agent with remaining issues
└──────────────────────────────────────────────────────────┘
```

- Auto-loops until 0 CRITICAL + 0 HIGH, max 5 iterations
- After 5 iterations: escalate to main agent, ask user for guidance
- MEDIUM/LOW: logged as new beads issues (`bd create --deps discovered-from:<epic>`)
- Final report returned to main agent

### `/c4flow:verify` — Quality Gate (sub-agent)

Sequential checks:
1. **Build** — fail → stop
2. **Type check** — report errors with `file:line`
3. **Lint** — warnings + errors
4. **Tests** — pass/fail count + coverage %
5. **Debug log audit** — scan source files for leftover debug statements (language-aware: `console.log` for JS/TS, `print()` for Python, `fmt.Println` for Go, etc.)
6. **Git status** — uncommitted changes

Output: `Ready for PR: YES / NO` with details

## Phase 6: Release

### `/c4flow:pr` — Create PR (main agent)

- Drafts PR title + body from:
  - Spec summary
  - List of completed beads tasks
  - Test results + coverage
  - Review summary
- Asks user to confirm → creates PR via `gh pr create`

### `/c4flow:pr-review` — PR Comment Review Loop (sub-agent, max 5 iterations)

```
┌─→ Load PR comments: gh api repos/{owner}/{repo}/pulls/{pr}/comments
│
├─ Parse comments into action items
│
├─ Fix each comment:
│     ├─ Modify code
│     ├─ Commit: "fix: address PR review - <summary> (bd-xxxx)"
│     └─ Reply on GitHub (optional)
│
├─ Run local review (/c4flow:review)
│
├─ Push to git
│
├─ Wait for GitHub auto-review
│
├─ New comments? → increment iteration → loop ↑
│   No more → Done, report to main agent
│
├─ 5 iterations reached?
│     YES → Stop, report remaining comments to main agent
└──────────────────────────────────────────────────────────┘
```

### `/c4flow:infra` — Infrastructure as Code (sub-agent, MANUAL TRIGGER)

**Not part of the auto flow.** User calls `/c4flow:infra` when needed (typically after spec or before deploy).

- Reads `tech-stack.md` infrastructure section
- Generates IaC files based on cloud provider:
  - **Terraform:** `infra/main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`
  - **Pulumi:** `infra/index.ts` or `__main__.py`
  - **AWS CDK:** `infra/lib/stack.ts`
- Covers: compute, database, networking, secrets, monitoring, IAM
- Sub-agent generates → main agent reviews before commit

### `/c4flow:merge` — Merge (main agent)

Pre-checks:
- PR approved?
- CI passed?
- All beads tasks closed?

User confirms merge strategy (squash / merge / rebase). Executes merge. Closes epic in beads:
```bash
bd close <epic-id> --reason "Merged to main"
```

Cleans up worktree:
- If using `EnterWorktree`: calls `ExitWorktree` with action `remove`
- If using manual worktree: `git worktree remove <path>`, delete branch if squash-merged
- Warns if uncommitted changes exist, asks user before discarding

### `/c4flow:deploy` — Deploy (main agent)

- Detects deployment target from `tech-stack.md`
- Displays deploy plan for user
- User confirms → triggers deploy
- Verifies deployment health
- Reports success/failure

## GitHub Action: Auto Review on PR

`.github/workflows/c4flow-review.yml`:

```yaml
name: c4flow AI Review
on:
  pull_request:
    types: [opened, synchronize]

permissions:
  contents: read
  pull-requests: write

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Run Claude Code Review
        uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          review_mode: true
          review_instructions: |
            Review for: security (OWASP), code quality (SOLID, DRY),
            spec compliance (check docs/c4flow/specs/), test coverage.
            Post comments on specific lines. Categorize as
            CRITICAL / HIGH / MEDIUM / LOW.
```

**Requirements:**
- `ANTHROPIC_API_KEY` stored as GitHub secret
- PR write permission for posting review comments
- Advisory only — does not block merge

## Fallback Behavior

| Dependency | If Missing | Fallback |
|---|---|---|
| Beads (bd) | Tasks stored in `tasks.md` (markdown checklist format), no atomic claiming or dependency resolution | User prompted to install |
| Pencil | Text-based layout descriptions in markdown | User prompted to install |
| UI/UX Pro Max | Agent selects design system from general best practices | User prompted to install |
| gh CLI | PR/merge operations described as manual steps for user to execute | User prompted to install |

## Data Flow

```
User idea
  → /c4flow:research (sub-agent) → research.md
  → /c4flow:spec (main) → proposal.md, tech-stack.md, spec.md, design.md
  → /c4flow:design (sub-agent + main confirm) → MASTER.md, .pen files
  → /c4flow:beads (main) → beads epic + tasks
  → /c4flow:code (sub-agents) → implementation + tests + commits
  → /c4flow:test (sub-agent) → test results
  → /c4flow:review (sub-agent loop, max 5) → 0 critical/high issues
  → /c4flow:verify (sub-agent) → Ready for PR: YES
  → /c4flow:pr (main) → PR created
  → /c4flow:pr-review (sub-agent loop, max 5) → all comments resolved
  → /c4flow:merge (main) → merged, epic closed
  → /c4flow:deploy (main) → deployed, verified
```

Manual triggers (not in auto flow, can be called at any point):
- `/c4flow:e2e` — E2E tests
- `/c4flow:infra` — IaC generation
- `/c4flow:status` — show current workflow state
