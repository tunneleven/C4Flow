---
phase: 1
slug: local-gate-infrastructure
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-16
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Shell script integration tests (bash scripts testing bash skills) |
| **Config file** | none — Wave 0 creates test directory |
| **Quick run command** | `bash .claude/tests/test-schema-validation.sh && bash .claude/tests/test-tool-detection.sh` |
| **Full suite command** | `bash .claude/tests/run-all.sh` |
| **Estimated runtime** | ~15 seconds (excluding codex-live tests) |

---

## Sampling Rate

- **After every task commit:** Run `bash .claude/tests/test-schema-validation.sh && bash .claude/tests/test-tool-detection.sh`
- **After every plan wave:** Run `bash .claude/tests/run-all.sh`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 0 | INFR-06 | unit | `bash .claude/tests/test-schema-validation.sh` | ❌ W0 | ⬜ pending |
| 1-01-02 | 01 | 0 | GATE-04 | unit | `bash .claude/tests/test-tool-detection.sh` | ❌ W0 | ⬜ pending |
| 1-02-01 | 02 | 1 | GATE-01 | integration | `bash .claude/tests/test-review-output.sh` | ❌ W0 | ⬜ pending |
| 1-02-02 | 02 | 1 | INFR-01 | integration | `bash .claude/tests/test-review-output.sh` | ❌ W0 | ⬜ pending |
| 1-03-01 | 03 | 1 | GATE-02, SKIL-02 | integration | `bash .claude/tests/test-preflight-integration.sh` | ❌ W0 | ⬜ pending |
| 1-04-01 | 04 | 2 | GATE-03 | integration | `bash .claude/tests/test-gate-blocking.sh` | ❌ W0 | ⬜ pending |
| 1-04-02 | 04 | 2 | INFR-04 | integration | `bash .claude/tests/test-audit-trail.sh` | ❌ W0 | ⬜ pending |
| 1-05-01 | 05 | 2 | INFR-05 | integration | `bash .claude/tests/test-formula-template.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `.claude/tests/` directory — create test infrastructure
- [ ] `.claude/tests/test-schema-validation.sh` — validates quality-gate-status.json schema (INFR-06)
- [ ] `.claude/tests/test-tool-detection.sh` — verifies tool availability detection and fallback (GATE-04)
- [ ] `.claude/tests/test-review-output.sh` — verifies Codex subagent produces valid JSON output (GATE-01, INFR-01)
- [ ] `.claude/tests/test-preflight-integration.sh` — verifies bd preflight integration (GATE-02)
- [ ] `.claude/tests/test-gate-blocking.sh` — verifies bd close blocked by open gates (GATE-03)
- [ ] `.claude/tests/test-audit-trail.sh` — verifies reason strings on gate resolve/close (INFR-04)
- [ ] `.claude/tests/test-formula-template.sh` — verifies formula dry-run (INFR-05)
- [ ] `.claude/tests/run-all.sh` — test suite entry point

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Codex review produces meaningful findings | GATE-01 | Requires live LLM call with real code diff | Run `c4flow:review` on a branch with known issues; verify findings match |
| Subagent context isolation | INFR-01 | Requires observing Claude Code context window | Dispatch code-reviewer subagent; verify main context is not polluted |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
