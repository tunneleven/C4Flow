---
phase: 01-local-gate-infrastructure
plan: "04"
subsystem: infra
tags: [beads, formula, workflow, gates, c4flow]

# Dependency graph
requires:
  - phase: 01-local-gate-infrastructure/01-01
    provides: "Gate lifecycle pattern (create/resolve/expire) and quality-gate-status.json schema"
provides:
  - "TOML workflow formula template mol-c4flow-task with three sequential gate steps"
  - "Repeatable `bd mol pour mol-c4flow-task --var task_name=...` pattern for c4flow tasks"
affects:
  - 02-claude-code-hooks
  - onboarding
  - developer-workflow

# Tech tracking
tech-stack:
  added: [beads formula TOML schema]
  patterns:
    - "Acceptance criteria on workflow steps as gate contract substitute (no native gate type in beads Step schema)"
    - "Three-step sequential formula: implement → review-gate → verify-gate using `needs` field for ordering"

key-files:
  created:
    - .beads/formulas/mol-c4flow-task.formula.toml
  modified: []

key-decisions:
  - "TOML format used instead of YAML — beads formula schema uses TOML (Step struct confirmed; YAML plan was incorrect)"
  - "No native gate step type in beads schema — gates are created dynamically by c4flow skills; formula steps use acceptance criteria to communicate gate contract"
  - "Three-step structure: implement → review-gate (needs implement) → verify-gate (needs review-gate) enforces sequential quality flow"

patterns-established:
  - "Formula gate pattern: workflow steps with acceptance criteria act as gate contract; actual gate beads created/resolved by c4flow:review and c4flow:verify skills at runtime"

requirements-completed: [INFR-05]

# Metrics
duration: 15min
completed: 2026-03-16
---

# Phase 01 Plan 04: Beads Molecule Formula Template Summary

**TOML workflow formula mol-c4flow-task with three sequential steps (implement → review-gate → verify-gate) using acceptance criteria as gate contracts, since beads Step schema has no native gate type**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-16
- **Completed:** 2026-03-16
- **Tasks:** 2 (1 auto + 1 human-verify)
- **Files modified:** 1

## Accomplishments
- Formula template at `.beads/formulas/mol-c4flow-task.formula.toml` with full task/gate descriptions
- Three-step sequential workflow (implement → review-gate → verify-gate) enforced via `needs` field
- Acceptance criteria on gate steps document the gate contract: c4flow skills must resolve before advancement
- Detailed descriptions guide agents and humans through the quality gate workflow at each step
- User verified the three-step structure and TOML schema deviation as acceptable

## Task Commits

Each task was committed atomically:

1. **Task 1: Create and validate beads molecule formula template** - `4f63767` (feat)
2. **Task 2: Verify formula template works with beads CLI** - human-verify checkpoint, approved by user

**Plan metadata:** (docs commit below)

## Files Created/Modified
- `.beads/formulas/mol-c4flow-task.formula.toml` - Workflow formula with implement, review-gate, and verify-gate steps; acceptance criteria encode gate contract; full descriptions guide c4flow skill usage

## Decisions Made
- **TOML instead of YAML:** The beads formula schema uses TOML, not YAML as assumed in research. The plan's interface block specified YAML — the executor discovered the actual schema and switched to TOML. Accepted by user at checkpoint.
- **No native gate type:** The beads Step struct has no `type: gate` field. Instead, gate semantics are expressed via `needs` (ordering) and `acceptance` (exit criteria). Actual gate beads are created and resolved dynamically by the c4flow:review and c4flow:verify skills.
- **Three-step structure confirmed:** User approved the implement → review-gate → verify-gate sequential structure at the human-verify checkpoint.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] TOML schema used instead of YAML**
- **Found during:** Task 1 (Create formula template)
- **Issue:** Plan specified `.formula.yaml` extension and YAML syntax for the formula file. Empirical exploration revealed beads uses TOML for formula files (`.formula.toml` extension).
- **Fix:** Created formula as TOML with correct syntax; renamed file to `.formula.toml`; updated formula structure to match TOML schema (array of tables `[[steps]]`, `[vars]` block)
- **Files modified:** `.beads/formulas/mol-c4flow-task.formula.toml` (created; `.yaml` path in plan frontmatter was never created)
- **Verification:** File created with valid TOML syntax; reviewed at checkpoint and approved by user
- **Committed in:** `4f63767` (Task 1 commit)

**2. [Rule 1 - Bug] No native gate type in beads Step schema**
- **Found during:** Task 1 (schema exploration)
- **Issue:** Plan interface proposed `type: gate` and `gate:` sub-fields. Beads Step struct has no gate type — only `id`, `title`, `description`, `needs`, `parallel`, `acceptance`.
- **Fix:** Expressed gate semantics via `acceptance` criteria and `needs` ordering. Added detailed descriptions explaining how c4flow skills create/resolve actual gate beads. Schema note added at top of formula explaining the design.
- **Files modified:** `.beads/formulas/mol-c4flow-task.formula.toml`
- **Verification:** Reviewed at checkpoint; user approved the acceptance-criteria approach
- **Committed in:** `4f63767` (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (2 schema corrections — TOML format and no native gate type)
**Impact on plan:** Both corrections reflect actual beads schema; the gate contract intent is preserved via acceptance criteria. No scope creep. INFR-05 requirement satisfied: formula has explicit review and verify gate steps.

## Issues Encountered
- Beads formula YAML schema in RESEARCH.md was a hypothesis, not confirmed. Empirical validation in Task 1 discovered the actual schema. The plan correctly anticipated this risk in the NOTE comment and the "if gate steps cannot be validated" fallback — the fallback path was followed successfully.

## User Setup Required
None - no external service configuration required. Formula file is in repo at `.beads/formulas/mol-c4flow-task.formula.toml`.

## Next Phase Readiness
- Wave 2 of Phase 1 is complete: all four plans (01-01 through 01-04) are done
- Formula template available for developer use: `bd mol pour mol-c4flow-task --var task_name="..."`
- The remaining blocker from STATE.md — beads formula gate YAML/JSON schema verification — is now resolved (TOML confirmed, acceptance criteria approach documented)
- Phase 2 (Claude Code hooks integration) can proceed; hooks will need to invoke c4flow:review and c4flow:verify via the formula gate pattern

---
*Phase: 01-local-gate-infrastructure*
*Completed: 2026-03-16*
