# C4Flow Quality Gate Chain

## What This Is

A hard quality gate system for the C4Flow Claude Code plugin that chains multiple automated checks (Codex code review, bd preflight, CodeRabbit PR review) before any task can be marked complete. Built on beads' native gate primitive with Claude Code hooks as a safety net, it implements the REVIEW, VERIFY, PR, PR_REVIEW_LOOP, and MERGE phases of c4flow's 14-state workflow.

## Core Value

No task closes without passing every quality check — Codex review, bd preflight, and CodeRabbit PR review must all pass before `bd close` succeeds.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

- ✓ C4Flow plugin structure (skills, commands, references) — existing
- ✓ Orchestrator state machine (14 states, .state.json) — existing
- ✓ Research skill (sub-agent, quality gate) — existing
- ✓ Spec skill (4 artifacts, interactive) — existing
- ✓ Beads skill (epic→spec linking, tasks.md fallback) — existing

### Active

<!-- Current scope. Building toward these. -->

- [ ] Codex review integration that runs `codex review --base main` and parses output for critical/high issues
- [ ] bd preflight integration that runs `bd preflight --check --json` before PR creation
- [ ] CodeRabbit PR review integration via webhook + `gh:run` gate type
- [ ] Stop hook that blocks agent session end when quality gates are unresolved
- [ ] PreToolUse hook on Bash that intercepts agent-initiated `bd close` when gates are open
- [ ] Beads molecule formula with explicit review/verify gate steps
- [ ] Dynamic gate bead creation from skill logic at runtime for ad-hoc tasks
- [ ] Quality gate runner script that orchestrates all checks and resolves gates
- [ ] `c4flow:review` skill — local AI review loop using Codex
- [ ] `c4flow:verify` skill — quality gate aggregator (build, lint, tests, Codex pass)
- [ ] `c4flow:pr` skill — create PR with quality gate status in description
- [ ] `c4flow:pr-review` skill — PR comment review loop watching CodeRabbit + human review
- [ ] `c4flow:merge` skill — merge after all gates resolved
- [ ] `.coderabbit.yaml` configuration for automated PR reviews
- [ ] Gate resolution audit trail (reason logged on every resolve)

### Out of Scope

<!-- Explicit boundaries. Includes reasoning to prevent re-adding. -->

- CodeRabbit CLI local review — docs are sparse and CLI is unconfirmed; use PR webhook instead
- CodeRabbit MCP server integration — advertised but unconfirmed; revisit when docs stabilize
- `c4flow:deploy` skill — deployment is project-specific, not part of quality gate chain
- `c4flow:infra` skill — infrastructure provisioning is orthogonal to quality gates
- `c4flow:e2e` skill — E2E testing is a manual trigger skill, not part of the gate chain
- `c4flow:design` skill — design phase is upstream of quality gates
- `c4flow:code` and `c4flow:tdd` skills — implementation phase is upstream

## Context

C4Flow is a Claude Code plugin (v0.1.0) with 15 skills across 6 phases, driven by a 14-state orchestrator. MVP Phase 1 is complete (research, spec, beads). Skills 03-15 are stubs. This project implements Phase 5 (Review & QA) and Phase 6 (Release) — the quality enforcement layer.

Key tools available on this machine:
- `codex` CLI (v0.114.0) at `/usr/local/nodejs/bin/codex` — `codex review --base main` for code review
- `bd` (beads CLI) — native gate system with `bd gate`, `bd close` gate enforcement, molecule formulas
- CodeRabbit — SaaS PR review via GitHub webhooks, configured via `.coderabbit.yaml`
- Claude Code hooks — `PreToolUse`, `PostToolUse`, `Stop` events with JSON stdin/stdout

Beads gates are the primary enforcement mechanism:
- `bd close` refuses to close issues with unsatisfied gates unless `--force`
- Gates can be `human`, `timer`, `gh:run`, `gh:pr`, or `bead` type
- `bd gate resolve <id>` programmatically closes a gate
- Molecule formulas can declare gate steps that block advancement

Two-layer architecture:
1. **Layer 1 — Beads gates** (mandatory): blocks `bd close` natively regardless of who calls it
2. **Layer 2 — Claude Code hooks** (safety net): intercepts agent-initiated closes and session stops

## Constraints

- **Plugin format**: Must follow c4flow's existing SKILL.md structure in `skills/` directory
- **Beads dependency**: Gate functionality requires beads CLI; must gracefully fallback to tasks.md + manual verification when beads is not installed
- **Codex availability**: Codex CLI must be installed; skill should detect and warn if missing
- **CodeRabbit**: Requires GitHub repo + CodeRabbit app installed; PR_REVIEW_LOOP should skip CodeRabbit gate if not configured
- **No runtime dependencies**: Plugin is pure markdown skills + shell scripts; no npm/pip packages to install

## Key Decisions

<!-- Decisions that constrain future work. Add throughout project lifecycle. -->

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Beads gates as primary enforcement, hooks as safety net | Gates work regardless of caller (agent or human); hooks only intercept agent calls | — Pending |
| Both formula gates and dynamic gates | Formula for repeatable patterns (molecule workflows); dynamic for ad-hoc tasks | — Pending |
| Hard gate (no override without --force) | User explicitly chose strictest enforcement | — Pending |
| Codex review via structured prompt for pass/fail | `codex review` outputs prose; need structured parsing for automation | — Pending |
| CodeRabbit at PR level only (not CLI) | CLI docs are sparse/unreliable; webhook integration is proven | — Pending |

---
*Last updated: 2026-03-16 after initialization*
