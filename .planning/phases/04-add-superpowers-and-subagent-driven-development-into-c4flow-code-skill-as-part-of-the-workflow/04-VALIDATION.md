---
phase: 4
slug: add-superpowers-and-subagent-driven-development-into-c4flow-code-skill-as-part-of-the-workflow
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-16
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash + grep + jq |
| **Config file** | none — standalone shell suite under `.claude/tests/` |
| **Quick run command** | `bash .claude/tests/run-code-skill-tests.sh` |
| **Full suite command** | `bash .claude/tests/run-code-skill-tests.sh` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash .claude/tests/run-code-skill-tests.sh`
- **After every plan wave:** Run `bash .claude/tests/run-code-skill-tests.sh`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | Phase goal: `c4flow:code` uses Superpowers workflow | contract | `grep -q "using-superpowers" skills/code/SKILL.md && grep -q "subagent-driven-development" skills/code/SKILL.md` | ✅ | ✅ green |
| 04-01-02 | 01 | 1 | Phase goal: CODE is reachable from main workflow | contract | `grep -q "### If state is CODE" skills/c4flow/SKILL.md && grep -q "Load the c4flow:code skill" skills/c4flow/SKILL.md` | ✅ | ✅ green |
| 04-01-03 | 01 | 1 | Phase goal: workflow references match implementation | contract | `grep -q "skills/code/SKILL.md" references/workflow-state.md && grep -q "CODE → TEST" references/phase-transitions.md` | ✅ | ✅ green |
| 04-02-01 | 02 | 2 | Regression coverage for skill contracts | shell suite | `bash .claude/tests/run-code-skill-tests.sh` | ✅ | ✅ green |
| 04-02-02 | 02 | 2 | Human confirmation of end-to-end CODE workflow clarity | manual | `grep -n "CODE" skills/c4flow/SKILL.md && sed -n '1,220p' skills/code/SKILL.md` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `.claude/tests/test-code-skill-file.sh` — validates `skills/code/SKILL.md` contract
- [x] `.claude/tests/test-c4flow-code-route.sh` — validates orchestrator CODE routing
- [x] `.claude/tests/test-code-state-reference.sh` — validates workflow reference alignment
- [x] `.claude/tests/test-code-fallbacks.sh` — validates fallback/manual guidance text
- [x] `.claude/tests/run-code-skill-tests.sh` — suite runner for all CODE-skill checks

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| CODE path reads as a coherent workflow from `/c4flow` into `c4flow:code` and then into Superpowers | Phase 4 goal | Final correctness depends on human judgment about workflow clarity and sequencing, not just string presence | 1. Read `skills/c4flow/SKILL.md` CODE branch. 2. Read `skills/code/SKILL.md`. 3. Confirm the route is: state validation → prerequisite check → Superpowers skill loading → subagent-driven execution → CODE completion gate |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 10s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved (2026-03-16)
