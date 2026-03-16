# Requirements: C4Flow Quality Gate Chain

**Defined:** 2026-03-16
**Core Value:** No task closes without passing every quality check — Codex review, bd preflight, and beads gates must all pass before `bd close` succeeds.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Local Quality Gates

- [x] **GATE-01**: Subagent runs `codex review --base main` and writes structured pass/fail JSON to `quality-gate-status.json`
- [x] **GATE-02**: Skill runs `bd preflight --check --json` and fails VERIFY phase if issues found
- [x] **GATE-03**: Beads gates created programmatically (formula steps for repeatable patterns + dynamic creation for ad-hoc tasks) and resolved by quality runner script
- [x] **GATE-04**: Tool availability detection warns if codex or bd not installed; graceful fallback to manual verification when tools are missing

### Hooks (Fast File Check Pattern)

- [ ] **HOOK-01**: PreToolUse hook on Bash intercepts agent-initiated `bd close` commands — reads `quality-gate-status.json` (~100ms), denies with explanation if gates not passed
- [ ] **HOOK-02**: Stop hook checks for unresolved beads gates before agent session ends, blocks with list of open gates
- [ ] **HOOK-03**: TaskCompleted hook blocks task completion via TaskUpdate if quality gates are still open for the associated beads task

### Skills

- [x] **SKIL-01**: `c4flow:review` skill — orchestrates Codex subagent review, parses structured output, writes gate status file, resolves beads gate on pass, reports findings on fail
- [x] **SKIL-02**: `c4flow:verify` skill — runs bd preflight, aggregates all gate results (Codex + preflight), declares "Ready for PR: YES/NO" with summary
- [ ] **SKIL-03**: `c4flow:pr` skill — creates GitHub PR with quality gate status summary in description, updates .state.json with PR number

### Infrastructure

- [x] **INFR-01**: `.claude/agents/code-reviewer.md` subagent definition that runs Codex review in isolated context, returns structured JSON
- [ ] **INFR-02**: `.claude/hooks/` shell scripts: `bd-close-gate.sh` (PreToolUse), `check-open-gates.sh` (Stop), `task-complete-gate.sh` (TaskCompleted)
- [ ] **INFR-03**: Hooks configuration in `.claude/settings.json` with project-scoped matchers and appropriate timeouts
- [x] **INFR-04**: Gate resolution audit trail — reason string logged on every `bd gate resolve` and `bd close --reason`
- [x] **INFR-05**: Beads molecule formula template with explicit review and verify gate steps that block task advancement
- [x] **INFR-06**: `quality-gate-status.json` schema definition — includes per-check pass/fail, timestamps, expiry, and findings summary

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### CodeRabbit Integration

- **CRAB-01**: CodeRabbit PR review gate via gh:run beads gate type
- **CRAB-02**: `.coderabbit.yaml` configuration template for c4flow projects
- **CRAB-03**: Async polling with configurable timeout cap for CodeRabbit check completion

### Release Phase

- **RELS-01**: `c4flow:pr-review` skill — PR_REVIEW_LOOP state watching CodeRabbit + human review
- **RELS-02**: `c4flow:merge` skill — merge to main after all gates resolved
- **RELS-03**: Force-bypass audit — detect and log `--force` flag usage on `bd close`

### Advanced

- **ADVN-01**: Agent team reviewer — dedicated reviewer teammate using experimental agent teams
- **ADVN-02**: Weighted scoring gate (not just all-must-pass)

## Out of Scope

| Feature | Reason |
|---------|--------|
| CodeRabbit CLI local review | Docs sparse and CLI unconfirmed; webhook integration is the reliable path |
| Running `codex review` inside hooks | Proven anti-pattern — 30-120s blocking per tool call destroys performance |
| Global hook installation | Risk of breaking non-beads projects; project-scoped only |
| `c4flow:deploy` skill | Deployment is project-specific, orthogonal to quality gates |
| `c4flow:infra` skill | Infrastructure provisioning is orthogonal to quality gates |
| `c4flow:e2e` skill | E2E testing is a manual trigger, not part of the gate chain |
| `c4flow:design` skill | Design phase is upstream of quality gates |
| `c4flow:code` and `c4flow:tdd` skills | Implementation phase is upstream of quality gates |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| GATE-01 | Phase 1 | Complete |
| GATE-02 | Phase 1 | Complete |
| GATE-03 | Phase 1 | Complete |
| GATE-04 | Phase 1 | Complete |
| HOOK-01 | Phase 2 | Pending |
| HOOK-02 | Phase 2 | Pending |
| HOOK-03 | Phase 2 | Pending |
| SKIL-01 | Phase 1 | Complete |
| SKIL-02 | Phase 1 | Complete |
| SKIL-03 | Phase 3 | Pending |
| INFR-01 | Phase 1 | Complete |
| INFR-02 | Phase 2 | Pending |
| INFR-03 | Phase 2 | Pending |
| INFR-04 | Phase 1 | Complete |
| INFR-05 | Phase 1 | Complete |
| INFR-06 | Phase 1 | Complete |

**Coverage:**
- v1 requirements: 16 total
- Mapped to phases: 16
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-16*
*Last updated: 2026-03-16 after roadmap creation — phase mapping confirmed*
