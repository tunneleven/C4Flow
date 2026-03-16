---
phase: 3
slug: pr-skill
status: complete
nyquist_compliant: true
wave_0_complete: true
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
| **Full suite command** | `bash .claude/tests/run-pr-tests.sh` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash .claude/tests/test-pr-body-construction.sh && bash .claude/tests/test-pr-number-extraction.sh`
- **After every plan wave:** Run `bash .claude/tests/run-pr-tests.sh`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 3-01-01 | 01 | 0 | SKIL-03 | unit | `bash .claude/tests/test-pr-skill-file.sh` | :white_check_mark: W0 | :white_check_mark: green |
| 3-01-02 | 01 | 0 | SKIL-03 | unit | `bash .claude/tests/test-pr-body-construction.sh` | :white_check_mark: W0 | :white_check_mark: green |
| 3-01-03 | 01 | 0 | SKIL-03 | unit | `bash .claude/tests/test-pr-gate-warn.sh` | :white_check_mark: W0 | :white_check_mark: green |
| 3-01-04 | 01 | 0 | SKIL-03 | unit | `bash .claude/tests/test-pr-number-extraction.sh` | :white_check_mark: W0 | :white_check_mark: green |
| 3-01-05 | 01 | 0 | SKIL-03 | unit | `bash .claude/tests/test-pr-state-write.sh` | :white_check_mark: W0 | :white_check_mark: green |
| 3-01-06 | 01 | 0 | SKIL-03 | unit | `bash .claude/tests/test-pr-no-gh.sh` | :white_check_mark: W0 | :white_check_mark: green |

*Status: :white_large_square: pending · :white_check_mark: green · :x: red · :warning: flaky*

---

## Wave 0 Requirements

- [x] `.claude/tests/test-pr-skill-file.sh` — covers SKIL-03 file existence and content checks
- [x] `.claude/tests/test-pr-body-construction.sh` — covers PR body markdown from mock `quality-gate-status.json`
- [x] `.claude/tests/test-pr-gate-warn.sh` — covers warn-not-block behavior (mock overall_pass=false)
- [x] `.claude/tests/test-pr-number-extraction.sh` — covers URL -> number parse
- [x] `.claude/tests/test-pr-state-write.sh` — covers `.state.json` atomic merge write with `jq`
- [x] `.claude/tests/test-pr-no-gh.sh` — covers graceful degradation when `gh` is not installed

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full PR creation on GitHub | SKIL-03 | Requires live GitHub remote and auth | Run `c4flow:pr` on a real branch with a remote, verify PR appears on GitHub |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved (2026-03-16)
