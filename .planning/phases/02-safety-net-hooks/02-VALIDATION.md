---
phase: 2
slug: safety-net-hooks
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-16
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Shell script integration tests (bash scripts) |
| **Config file** | none — Wave 0 installs |
| **Quick run command** | `bash .claude/tests/test-hook-files.sh && bash .claude/tests/test-hook-settings.sh` |
| **Full suite command** | `bash .claude/tests/run-hooks-tests.sh` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash .claude/tests/test-hook-files.sh && bash .claude/tests/test-hook-settings.sh`
- **After every plan wave:** Run `bash .claude/tests/run-hooks-tests.sh`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 0 | INFR-02 | unit | `bash .claude/tests/test-hook-files.sh` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 0 | INFR-03 | unit | `bash .claude/tests/test-hook-settings.sh` | ❌ W0 | ⬜ pending |
| 02-01-03 | 01 | 1 | HOOK-01 | integration | `bash .claude/tests/test-hook-bd-close.sh` | ❌ W0 | ⬜ pending |
| 02-01-04 | 01 | 1 | HOOK-01 | integration | `bash .claude/tests/test-hook-bd-close.sh` | ❌ W0 | ⬜ pending |
| 02-01-05 | 01 | 1 | HOOK-02 | integration | `bash .claude/tests/test-hook-stop.sh` | ❌ W0 | ⬜ pending |
| 02-01-06 | 01 | 1 | HOOK-03 | unit | `bash .claude/tests/test-hook-taskcompleted.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `.claude/tests/test-hook-bd-close.sh` — stubs for HOOK-01 (pipe mock JSON, check deny output)
- [ ] `.claude/tests/test-hook-stop.sh` — stubs for HOOK-02 (requires temp beads DB with labeled gate)
- [ ] `.claude/tests/test-hook-taskcompleted.sh` — stubs for HOOK-03 (mock quality-gate-status.json)
- [ ] `.claude/tests/test-hook-files.sh` — stubs for INFR-02 (file existence + chmod check)
- [ ] `.claude/tests/test-hook-settings.sh` — stubs for INFR-03 (jq validation of settings.json)
- [ ] `.claude/tests/run-hooks-tests.sh` — test suite entry point for Phase 2

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| TaskCompleted fires on beads task close | HOOK-03 | Requires live Claude Code session to verify trigger semantics | 1. Create beads task with gate 2. Mark complete via TaskUpdate 3. Verify hook fires |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
