---
phase: 1
slug: local-gate-infrastructure
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-16
updated: 2026-03-16
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Inline automated verify commands (bash one-liners in each task's `<verify>` block) |
| **Config file** | none — no external test directory needed |
| **Quick run command** | Each task has its own `<automated>` verify command |
| **Full suite command** | Run all plan verify commands sequentially (see per-task map below) |
| **Estimated runtime** | ~15 seconds per task verify |

**Strategy note:** Plans use inline `<automated>` verify commands rather than external test scripts. Each task's verify block contains a self-contained bash command that checks file existence, content patterns, and structural validity. This is the appropriate strategy for a skill-based project where artifacts are markdown files with specific content patterns, not compiled code with unit test suites.

---

## Sampling Rate

- **After every task commit:** Run the task's `<automated>` verify command
- **After every plan wave:** Run all verify commands for plans in that wave
- **Before `/gsd:verify-work`:** All verify commands must pass
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 1-01-01 | 01 | 1 | INFR-06, GATE-04 | unit | `cat quality-gate-status.schema.json \| python3 -c "import json,sys; s=json.load(sys.stdin); assert s.get('properties',{}).get('schema_version'); print('Schema valid')" && grep -q 'quality-gate-status.json' .gitignore` | ⬜ pending |
| 1-01-02 | 01 | 1 | INFR-01 | unit | `test -f .claude/agents/code-reviewer.md && grep -q "code-reviewer" .claude/agents/code-reviewer.md && grep -q "timeout 120 codex review" .claude/agents/code-reviewer.md` | ⬜ pending |
| 1-02-01 | 02 | 2 | SKIL-01, GATE-01, GATE-03, GATE-04, INFR-04 | integration | `test -f skills/review/SKILL.md && grep -q "c4flow:review" skills/review/SKILL.md && grep -q "bd gate resolve" skills/review/SKILL.md && grep -q "command -v" skills/review/SKILL.md` | ⬜ pending |
| 1-03-01 | 03 | 2 | SKIL-02, GATE-02, INFR-04 | integration | `test -f skills/verify/SKILL.md && grep -q "bd preflight" skills/verify/SKILL.md && grep -q "Ready for PR" skills/verify/SKILL.md && grep -q "close.*reason\|bd close.*--reason" skills/verify/SKILL.md` | ⬜ pending |
| 1-04-01 | 04 | 2 | INFR-05 | integration | `test -f .beads/formulas/mol-c4flow-task.formula.yaml && bd cook --dry-run .beads/formulas/mol-c4flow-task.formula.yaml 2>&1 \| head -20` | ⬜ pending |
| 1-04-02 | 04 | 2 | INFR-05 | checkpoint | Human verification of formula template (checkpoint:human-verify) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Requirement Coverage Cross-Check

| Requirement | Plan(s) | How Covered |
|-------------|---------|-------------|
| GATE-01 | 02 | c4flow:review dispatches Codex subagent, receives structured JSON |
| GATE-02 | 03 | c4flow:verify runs bd preflight --check --json |
| GATE-03 | 02 | Gate creation/reuse with ID persistence in quality-gate-status.json |
| GATE-04 | 01, 02 | Tool availability checks (command -v) with graceful fallback |
| SKIL-01 | 02 | c4flow:review skill implementation |
| SKIL-02 | 03 | c4flow:verify skill implementation |
| INFR-01 | 01 | code-reviewer subagent with structured JSON output contract |
| INFR-04 | 02, 03 | bd gate resolve --reason in both skills; bd close --reason reminder in verify output |
| INFR-05 | 04 | Beads molecule formula template with gate steps |
| INFR-06 | 01 | quality-gate-status.json schema definition |

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Codex review produces meaningful findings | GATE-01 | Requires live LLM call with real code diff | Run `c4flow:review` on a branch with known issues; verify findings match |
| Subagent context isolation | INFR-01 | Requires observing Claude Code context window | Dispatch code-reviewer subagent; verify main context is not polluted |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify commands (inline in plan files)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 strategy resolved: inline verify commands ARE the test strategy (no external test scripts needed)
- [x] No watch-mode flags
- [x] Feedback latency < 15s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated (2026-03-16, revision pass)
