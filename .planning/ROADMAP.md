# Roadmap: C4Flow Quality Gate Chain

## Overview

The roadmap first proves the local quality-gate chain (Codex review + bd preflight + beads
gates), then adds Claude Code hooks as a safety net, then wires up PR creation, then repairs
the CODE execution contract so implementation is standalone and beads-driven, and finally
extends the workflow with a dedicated TDD phase. Each phase delivers a verifiable capability
before the next layer is added.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3, 4, 5): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Local Gate Infrastructure** - Codex review, bd preflight, beads gate creation/resolution, and the two skills that wrap them
- [x] **Phase 2: Safety Net Hooks** - Claude Code hooks that intercept agent-initiated closes and session stops (completed 2026-03-16)
- [x] **Phase 3: PR Skill** - Create GitHub PR with quality gate status summary in description
- [x] **Phase 4: Superpowers + Subagent-Driven c4flow:code** - Initial CODE routing through external Superpowers skills (completed 2026-03-16)
- [x] **Phase 4.1 (INSERTED): Standalone beads-driven c4flow:code** - Replace the broken Superpowers dependency with a standalone CODE workflow and richer state/task contracts (completed 2026-03-17)
- [ ] **Phase 5: add tdd flow from superpowers into ours c4flow** - Extend the C4Flow workflow to adopt the Superpowers TDD flow

## Phase Details

### Phase 1: Local Gate Infrastructure
**Goal**: The local quality gate chain runs end-to-end — developer can invoke `c4flow:review` and `c4flow:verify`, gates are created and resolved via beads, and `bd close` is blocked until all checks pass
**Depends on**: Nothing (first phase)
**Requirements**: GATE-01, GATE-02, GATE-03, GATE-04, SKIL-01, SKIL-02, INFR-01, INFR-04, INFR-05, INFR-06
**Success Criteria** (what must be TRUE):
  1. Running `c4flow:review` causes a Codex subagent to run, produces structured JSON in `quality-gate-status.json`, and resolves the beads review gate on pass
  2. Running `c4flow:verify` runs `bd preflight --check --json`, aggregates all gate results, and outputs "Ready for PR: YES/NO" with a findings summary
  3. `bd close` refuses to close an issue when any quality gate is unresolved (without `--force`)
  4. If `codex` or `bd` is not installed, skills warn the user and fall back to manual verification instructions rather than silently failing
  5. Every `bd gate resolve` and `bd close` call writes a reason string to the gate resolution audit trail
**Plans:** 4/4 plans complete

Plans:
- [x] 01-01-PLAN.md — Foundational contracts: quality-gate-status.json schema, code-reviewer subagent, .gitignore
- [x] 01-02-PLAN.md — c4flow:review skill with Codex subagent dispatch and beads gate lifecycle
- [x] 01-03-PLAN.md — c4flow:verify skill with bd preflight integration and gate aggregation
- [x] 01-04-PLAN.md — Beads molecule formula template with quality gate steps (requires human verification)

### Phase 2: Safety Net Hooks
**Goal**: Claude Code hooks intercept agent-initiated `bd close` commands and session-end events, blocking them when quality gates are open, so that agent shortcuts cannot bypass the gate chain
**Depends on**: Phase 1
**Requirements**: HOOK-01, HOOK-02, HOOK-03, INFR-02, INFR-03
**Success Criteria** (what must be TRUE):
  1. When an agent issues `bd close` with open gates, the PreToolUse hook denies the command and explains which gates are unresolved
  2. When an agent session ends with open beads gates, the Stop hook blocks session termination and lists the open gates
  3. When a task is marked complete via TaskUpdate while its quality gates are open, the TaskCompleted hook blocks the completion
  4. All hooks are project-scoped (not global) and activate only within C4Flow projects
**Plans:** 2/2 plans complete

Plans:
- [ ] 02-01-PLAN.md — Hook scripts and settings.json config (bd-close-gate, check-open-gates, task-complete-gate)
- [ ] 02-02-PLAN.md — Hook test suite with mock stdin testing and human verification checkpoint

### Phase 3: PR Skill
**Goal**: The developer can invoke `c4flow:pr` to create a GitHub PR that includes a quality gate status summary in its description, with the PR number recorded in `.state.json`
**Depends on**: Phase 2
**Requirements**: SKIL-03
**Success Criteria** (what must be TRUE):
  1. Running `c4flow:pr` creates a GitHub PR using the `gh` CLI with a description that includes current gate pass/fail status from `quality-gate-status.json`
  2. The PR number is written to `.state.json` after creation
  3. If quality gates have not all passed, `c4flow:pr` warns the user before proceeding (but does not block — PR creation is informational, not a hard gate)
**Plans:** 1/1 plan complete

Plans:
- [x] 03-01-PLAN.md — c4flow:pr skill implementation with test suite and human verification

### Phase 4: Superpowers + Subagent-Driven c4flow:code
**Goal**: Integrate `superpowers` and `subagent-driven-development` into the `c4flow:code` skill so workflow execution consistently uses the shared skill-loading and subagent orchestration patterns
**Depends on**: Phase 3
**Requirements**: TBD
**Plans:** 2/2 plans complete

Plans:
- [x] 04-01-PLAN.md — Implement `c4flow:code` orchestration and CODE-state routing through Superpowers
- [x] 04-02-PLAN.md — Add regression tests and human verification for the new CODE workflow

### Phase 4.1 (INSERTED): Standalone beads-driven c4flow:code
**Goal**: Replace the unavailable Superpowers delegation path with a standalone `c4flow:code` workflow that uses local planning artifacts, persists CODE task identity, and drives the full beads lifecycle directly
**Depends on**: Phase 4
**Requirements**: SKIL-04, SKIL-05, SKIL-06
**Success Criteria** (what must be TRUE):
  1. `c4flow:code` no longer relies on `using-superpowers`, `using-git-worktrees`, or `subagent-driven-development`
  2. CODE accepts implementation plans from `.planning/phases/...` or `docs/c4flow/plans/`, and its local plan guidance points to `docs/c4flow/plans/`
  3. `.state.json` documents and preserves enough task metadata for CODE resume and CODE → TEST gating (`taskSource`, `taskQuery`, `taskIds`, `claimedTasks`, `implementationPlan`)
  4. The documented beads lifecycle includes ready/show/claim/close/discovered-from/dolt-push instead of a vague "beads-aware" flow
  5. The CODE regression suite validates the standalone contract rather than the removed Superpowers dependency
**Plans:** 1/1 plans complete

Plans:
- [x] 04.1-01-PLAN.md — Rewrite CODE as a standalone beads-driven workflow and align state/reference contracts

### Phase 5: add tdd flow from superpowers into ours c4flow

**Goal:** [To be planned]
**Requirements**: TBD
**Depends on:** Phase 4.1
**Plans:** 0 plans

Plans:
- [ ] TBD (run `$gsd-plan-phase 5` to break down)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 4.1 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Local Gate Infrastructure | 4/4 | Complete | 2026-03-16 |
| 2. Safety Net Hooks | 2/2 | Complete   | 2026-03-16 |
| 3. PR Skill | 1/1 | Complete | 2026-03-16 |
| 4. Superpowers + Subagent-Driven c4flow:code | 2/2 | Complete | 2026-03-16 |
| 4.1. Standalone beads-driven c4flow:code | 1/1 | Complete | 2026-03-17 |
| 5. add tdd flow from superpowers into ours c4flow | 0/0 | Not planned | - |
