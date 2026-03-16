---
name: c4flow:code
description: Execute code implementation via subagents, one task per agent, with two-stage review
---

# /c4flow:code — Subagent-Driven Code Execution

**Phase**: 3: Implementation
**Agent type**: Main agent (coordinator), dispatches subagents per task

Execute plan by dispatching a fresh subagent per task, with two-stage review after each: spec compliance first, then code quality.

**Why subagents:** Fresh context per task prevents pollution. You construct exactly what each subagent needs — they never inherit session history. This preserves your context for coordination.

**Core principle:** Fresh subagent per task + two-stage review (spec then quality) = high quality, fast iteration

## Prerequisites

Before dispatching any subagent:

1. **Read workflow state** — `docs/c4flow/.state.json`
   - Confirm `currentState` is `CODE`
   - Extract `feature.slug`, `taskSource`, `beadsEpic`

2. **Load tasks** — from Beads or `tasks.md`:

   **Beads path** (preferred):
   ```bash
   bd ready --json
   ```
   This returns unclaimed tasks. For full epic view:
   ```bash
   bd show <epic-id> --json
   ```

   **Fallback path**:
   Read `docs/specs/<feature-slug>/tasks.md`

3. **Load execution plan** — resolve in order:
   - `.state.json` → `implementationPlan` field
   - `.planning/phases/...` current phase plan
   - `docs/c4flow/plans/YYYY-MM-DD-<feature-slug>.md`

   If no plan exists, create one under `docs/c4flow/plans/` before writing code.

4. **Extract all tasks with full text** — read the plan once, extract every task with its complete description, acceptance criteria, and context. Do not make subagents read the plan file.

## Execution Flow

```
┌─────────────────────────────────────────────────────┐
│ Read plan → Extract all tasks → Claim in Beads      │
│                                                     │
│ For each task:                                      │
│   ├── Dispatch implementer subagent                 │
│   │   ├── Asks questions? → Answer, re-dispatch     │
│   │   └── Implements, tests, commits, self-reviews  │
│   ├── Dispatch spec reviewer subagent               │
│   │   ├── Issues? → Implementer fixes → re-review   │
│   │   └── Spec compliant                            │
│   ├── Dispatch code quality reviewer subagent       │
│   │   ├── Issues? → Implementer fixes → re-review   │
│   │   └── Quality approved                          │
│   └── Close task in Beads (or check off tasks.md)   │
│                                                     │
│ After all tasks closed:                             │
│   └── Advance state CODE → TEST                     │
│       (full-branch review deferred to REVIEW phase) │
└─────────────────────────────────────────────────────┘
```

## Task Lifecycle (Beads)

For each task being executed:

```bash
# 1. Claim before starting
bd update <task-id> --claim --json

# 2. After implementation + review passes
bd close <task-id> --reason "CODE: implemented and reviewed" --json

# 3. If follow-up work discovered during implementation
bd create "Follow-up: <title>" --description="..." -p 1 \
  --deps discovered-from:<parent-id> --json

# 4. When all tasks done, sync
bd dolt push
```

**If Beads is unavailable**, fall back to `tasks.md`: mark items with `[x]` as complete.

## Task Lifecycle (tasks.md fallback)

For each task in `docs/specs/<feature-slug>/tasks.md`:
1. Note which task you're starting
2. After implementation + review passes, mark `[x]` in the file
3. Continue to next task

## Dispatching Subagents

### Implementer

For each task, dispatch a fresh subagent using the template at `skills/code/implementer-prompt.md`.

Provide:
- Full task text (from your extracted plan — don't make them read files)
- Scene-setting context (where this fits, dependencies, architecture)
- Working directory
- Beads task ID (if using Beads)

### Model Selection

**Mechanical tasks** (isolated functions, clear specs, 1-2 files): use `model: "haiku"`.
**Integration tasks** (multi-file coordination, pattern matching): use `model: "sonnet"`.
**Architecture/design tasks** (broad codebase understanding): use default model.

Complexity signals:
- 1-2 files with complete spec → haiku
- Multiple files with integration → sonnet
- Design judgment or broad understanding → default

### Handling Implementer Status

**DONE:** Proceed to spec compliance review.

**DONE_WITH_CONCERNS:** Read concerns. If about correctness/scope, address before review. If observations, note and proceed.

**NEEDS_CONTEXT:** Provide missing context, re-dispatch.

**BLOCKED:** Assess:
1. Context problem → provide more context, re-dispatch same model
2. Task too hard → re-dispatch with more capable model
3. Task too large → break into smaller pieces
4. Plan wrong → ask the user

Never force retry without changes.

### Spec Compliance Reviewer

After implementer reports DONE, dispatch a reviewer using `skills/code/spec-reviewer-prompt.md`.

Provide:
- Full task requirements (same text given to implementer)
- Implementer's report (what they claim they built)

If issues found → implementer fixes → re-review. Repeat until ✅.

### Code Quality Reviewer

After spec compliance passes, dispatch using `skills/code/code-quality-reviewer-prompt.md`.

Provide:
- Implementer's report
- Task requirements
- Git SHAs (base and head)

If issues found → implementer fixes → re-review. Repeat until ✅.

## Completion Gate

CODE is complete when:
- **Beads**: every assigned task is closed (`bd ready --json` returns empty for this epic)
- **tasks.md**: every task item is checked `[x]`

Each task was already spec-reviewed and quality-reviewed inline. The full-branch review happens in `c4flow:review` (after TEST), not here.

Only then advance state:

```bash
jq '
  .currentState = "TEST"
  | .completedStates += ["CODE"]
  | .failedAttempts = 0
  | .lastError = null
' docs/c4flow/.state.json > docs/c4flow/.state.json.tmp \
  && mv -f docs/c4flow/.state.json.tmp docs/c4flow/.state.json
```

## What Happens Next

```
CODE (you are here)
  → TEST    — c4flow:test runs full test suite, checks coverage
  → REVIEW  — c4flow:review runs Codex review on full branch diff vs main
  → VERIFY  — c4flow:verify runs bd preflight, combines with Codex results
  → PR      — c4flow:pr creates the pull request
```

The per-task reviews in CODE catch task-level issues. The full-branch Codex review in REVIEW catches cross-task integration issues, security concerns, and anything the per-task reviews missed.

## Rules

**Never:**
- Start on main/master without explicit user consent
- Skip reviews (spec compliance OR code quality)
- Proceed with unfixed issues
- Dispatch multiple implementer subagents in parallel (conflicts)
- Make subagent read plan file (provide full text)
- Skip scene-setting context
- Ignore subagent questions
- Start code quality review before spec compliance passes
- Move to next task while review has open issues

**If subagent asks questions:** Answer clearly and completely. Don't rush.

**If reviewer finds issues:** Implementer fixes → reviewer re-reviews → repeat until approved.

**If subagent fails:** Dispatch fix subagent with specific instructions. Don't fix manually (context pollution).

## Prompt Templates

- `skills/code/implementer-prompt.md`
- `skills/code/spec-reviewer-prompt.md`
- `skills/code/code-quality-reviewer-prompt.md`
