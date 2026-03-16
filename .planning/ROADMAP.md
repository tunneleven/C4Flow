# Roadmap: C4Flow Quality Gate Chain

## Overview

Three phases build the quality gate chain from the inside out: first prove the local gate
mechanism works (Codex review + bd preflight + beads gates), then add Claude Code hooks as
a safety net against agent-initiated bypasses, then wire up PR creation with gate status in
the description. Each phase delivers a verifiable enforcement capability before the next
layer is added.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Local Gate Infrastructure** - Codex review, bd preflight, beads gate creation/resolution, and the two skills that wrap them
- [ ] **Phase 2: Safety Net Hooks** - Claude Code hooks that intercept agent-initiated closes and session stops
- [ ] **Phase 3: PR Skill** - Create GitHub PR with quality gate status summary in description

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
**Plans:** 4 plans

Plans:
- [ ] 01-01-PLAN.md — Foundational contracts: quality-gate-status.json schema, code-reviewer subagent, .gitignore
- [ ] 01-02-PLAN.md — c4flow:review skill with Codex subagent dispatch and beads gate lifecycle
- [ ] 01-03-PLAN.md — c4flow:verify skill with bd preflight integration and gate aggregation
- [ ] 01-04-PLAN.md — Beads molecule formula template with quality gate steps (requires human verification)

### Phase 2: Safety Net Hooks
**Goal**: Claude Code hooks intercept agent-initiated `bd close` commands and session-end events, blocking them when quality gates are open, so that agent shortcuts cannot bypass the gate chain
**Depends on**: Phase 1
**Requirements**: HOOK-01, HOOK-02, HOOK-03, INFR-02, INFR-03
**Success Criteria** (what must be TRUE):
  1. When an agent issues `bd close` with open gates, the PreToolUse hook denies the command and explains which gates are unresolved
  2. When an agent session ends with open beads gates, the Stop hook blocks session termination and lists the open gates
  3. When a task is marked complete via TaskUpdate while its quality gates are open, the TaskCompleted hook blocks the completion
  4. All hooks are project-scoped (not global) and activate only within C4Flow projects
**Plans**: TBD

### Phase 3: PR Skill
**Goal**: The developer can invoke `c4flow:pr` to create a GitHub PR that includes a quality gate status summary in its description, with the PR number recorded in `.state.json`
**Depends on**: Phase 2
**Requirements**: SKIL-03
**Success Criteria** (what must be TRUE):
  1. Running `c4flow:pr` creates a GitHub PR using the `gh` CLI with a description that includes current gate pass/fail status from `quality-gate-status.json`
  2. The PR number is written to `.state.json` after creation
  3. If quality gates have not all passed, `c4flow:pr` warns the user before proceeding (but does not block — PR creation is informational, not a hard gate)
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Local Gate Infrastructure | 0/4 | Planning complete | - |
| 2. Safety Net Hooks | 0/TBD | Not started | - |
| 3. PR Skill | 0/TBD | Not started | - |
