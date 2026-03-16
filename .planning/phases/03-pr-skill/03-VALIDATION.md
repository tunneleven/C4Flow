---
phase: 3
slug: pr-skill
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-16
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Shell script integration tests (bash — consistent with Phase 1/2) |
| **Config file** | None required |
| **Quick run command** | `bash .claude/tests/test-pr-body-construction.sh && bash .claude/tests/test-pr-number-extraction.sh` |
| **Full suite command** | `bash .claude/tests/run-all-tests.sh` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash .claude/tests/test-pr-body-construction.sh && bash .claude/tests/test-pr-number-extraction.sh`
- **After every plan wave:** Run `bash .claude/tests/run-all-tests.sh`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 3-01-01 | 01 | 0 | SKIL-03 | unit | `bash .claude/tests/test-pr-skill-file.sh` | ❌ W0 | ⬜ pending |
| 3-01-02 | 01 | 0 | SKIL-03 | unit | `bash .claude/tests/test-pr-body-construction.sh` | ❌ W0 | ⬜ pending |
| 3-01-03 | 01 | 0 | SKIL-03 | unit | `bash .claude/tests/test-pr-gate-warn.sh` | ❌ W0 | ⬜ pending |
| 3-01-04 | 01 | 0 | SKIL-03 | unit | `bash .claude/tests/test-pr-number-extraction.sh` | ❌ W0 | ⬜ pending |
| 3-01-05 | 01 | 0 | SKIL-03 | unit | `bash .claude/tests/test-state-json-write.sh` | ❌ W0 | ⬜ pending |
| 3-01-06 | 01 | 0 | SKIL-03 | unit | `bash .claude/tests/test-pr-no-gh.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `.claude/tests/test-pr-skill-file.sh` — covers SKIL-03 file existence check
- [ ] `.claude/tests/test-pr-body-construction.sh` — covers PR body markdown from mock `quality-gate-status.json`
- [ ] `.claude/tests/test-pr-gate-warn.sh` — covers warn-not-block behavior (mock overall_pass=false)
- [ ] `.claude/tests/test-pr-number-extraction.sh` — covers URL → number parse
- [ ] `.claude/tests/test-state-json-write.sh` — covers `.state.json` atomic merge write with `jq`
- [ ] `.claude/tests/test-pr-no-gh.sh` — covers graceful degradation when `gh` is not installed

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full PR creation on GitHub | SKIL-03 | Requires live GitHub remote and auth | Run `c4flow:pr` on a real branch with a remote, verify PR appears on GitHub |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
