---
phase: 01-local-gate-infrastructure
plan: "03"
subsystem: infra
tags: [skill, beads, bd-preflight, quality-gate, aggregation, atomic-write, expiry]

requires:
  - phase: 01-local-gate-infrastructure/01-01
    provides: "quality-gate-status.schema.json defining bd_preflight check structure"
  - phase: 01-local-gate-infrastructure/01-02
    provides: "skills/review/SKILL.md establishing codex_review data and gate_id in quality-gate-status.json"

provides:
  - "skills/verify/SKILL.md — complete c4flow:verify skill: runs bd preflight, aggregates with codex_review, resolves gate, declares Ready for PR"

affects:
  - 01-04
  - skills/pr

tech-stack:
  added: []
  patterns:
    - "Aggregation point: verify skill merges two independent check results (codex_review + bd_preflight) into overall_pass"
    - "Preserve-and-merge: only bd_preflight block is updated; codex_review data from review skill is never overwritten"
    - "Label-based gate_id recovery: fallback lookup via c4flow-quality-gate label when gate_id is null"
    - "Expiry guard on read: expired status file forces re-review, not just re-verify"
    - "Audit trail reminder: Ready for PR output always includes bd close --reason reminder (INFR-04)"

key-files:
  created: []
  modified:
    - skills/verify/SKILL.md

key-decisions:
  - "Verify skill reads codex_review data from file (written by review skill) — no re-dispatch of Codex subagent"
  - "overall_pass=false when either check is null or false — same locked rule as review skill"
  - "Gate resolved in verify skill when overall_pass becomes true, preventing race if review skill already partially resolved"
  - "bd close --reason reminder printed on Ready for PR: YES — INFR-04 audit trail compliance"
  - "Label-based fallback (c4flow-quality-gate) recovers gate_id if null — same defensive pattern as review skill"

patterns-established:
  - "Verify-as-aggregator: the verify step is the single source of truth for overall readiness, not review or preflight individually"
  - "Graceful no-bd: manual preflight checklist printed when bd missing, exits cleanly without crashing"

requirements-completed: [SKIL-02, GATE-02, INFR-04]

duration: 3min
completed: 2026-03-16
---

# Phase 01 Plan 03: c4flow:verify Skill Summary

**Skill markdown orchestrating bd preflight aggregation with existing Codex review results: reads quality-gate-status.json, runs bd preflight --check --json, atomically merges results, auto-resolves gate on overall pass, and prints Ready for PR: YES/NO with audit trail reminder**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-16T08:06:02Z
- **Completed:** 2026-03-16T08:09:20Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Replaced the stub `skills/verify/SKILL.md` with a complete 324-line skill implementation
- Implemented all 6 ordered steps: bd tool detection with manual fallback checklist, expiry check on existing status, bd preflight execution with JSON parse fail-safe, atomic merge write preserving codex_review data, gate resolution with label-based gate_id recovery, aggregated YES/NO summary
- Enforced `overall_pass=false` whenever any check is `null` (not-yet-run) — no partial pass states
- Included `bd close --reason` reminder in Ready for PR output to satisfy INFR-04 audit trail requirement

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement c4flow:verify skill with preflight integration and aggregation** - `cc4035a` (feat)

**Plan metadata:** TBD (docs: complete plan)

## Files Created/Modified

- `skills/verify/SKILL.md` — Complete c4flow:verify skill; 6-step instruction sequence covering bd availability detection (with manual preflight checklist fallback), expiry check on existing quality-gate-status.json, bd preflight execution with JSON parse fail-safe (treats parse error as FAIL), atomic write preserving codex_review block, gate resolution when both checks pass with label-based gate_id fallback, and aggregated Ready for PR: YES/NO summary with bd close --reason reminder

## Decisions Made

- Verify skill reads existing `codex_review` from the file written by the review skill — no re-dispatching of Codex subagent (review and verify are separate concerns)
- `overall_pass` computed fresh in verify step using same null-is-false rule as review skill — consistent enforcement
- Gate resolved in verify step when `overall_pass` becomes true — this is the natural aggregation point since only verify knows both checks are done
- `bd close --reason` reminder always printed on `Ready for PR: YES` — satisfies INFR-04 without requiring enforcement logic
- Label-based fallback (`c4flow-quality-gate`) recovers `gate_id` if it is null — mirrors defensive pattern from review skill

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `skills/verify/SKILL.md` is complete; plan 01-04 (formula gate template) can now be implemented
- The full c4flow:review → c4flow:verify skill chain is now implemented; the gate lifecycle is complete end-to-end
- Open concern from STATE.md remains: Beads molecule formula gate YAML/JSON schema needs verification against beads source (01-04 concern)

---
*Phase: 01-local-gate-infrastructure*
*Completed: 2026-03-16*
