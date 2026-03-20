# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

C4Flow is a Claude Code plugin — a pure markdown + shell skills system that drives an agentic development workflow from idea to deployment. There is no build step, no package manager, and no compilation. Everything is markdown skills and bash scripts.

## Running Tests

All tests are bash scripts in `.claude/tests/`. There are four suite runners:

```bash
# Hook tests (PreToolUse, Stop, TaskCompleted)
bash .claude/tests/run-hooks-tests.sh

# CODE_LOOP skill regression tests
bash .claude/tests/run-code-skill-tests.sh

# Init skill tests
bash .claude/tests/run-init-tests.sh

# PR skill tests
bash .claude/tests/run-pr-tests.sh
```

Run a single test directly:
```bash
bash .claude/tests/test-hook-bd-close.sh
bash .claude/tests/test-code-tdd-cycle.sh
```

## Architecture

### Skill System

Skills live in `skills/<name>/SKILL.md`. Each skill is a markdown prompt file loaded by Claude Code when invoked. Skills may dispatch sub-agents or run entirely in the main agent.

```
skills/
  c4flow/        # Orchestrator — the main state machine driver
  research/      # Web research sub-agent (has prompt.md + references/)
  spec/          # Interactive spec generation
  design/        # Design system + Pencil screen mockups
  beads/         # Task breakdown into beads epic
  code/          # Serial task loop implementation
  tdd/           # TDD sub-agent (RED→GREEN→REFACTOR)
  review/        # Codex code review sub-agent
  verify/        # Quality gate aggregator (build + lint + Codex)
  pr/            # PR creation with gate status
  test/          # Test runner with framework detection
  init/          # Bootstrap project tooling
  sync/          # DoltHub + GitHub sync
  ...
```

Commands in `commands/` are the user-facing entry points (`run.md`, `status.md`).

### State Machine

The orchestrator (`skills/c4flow/SKILL.md`) drives a state machine persisted at `docs/c4flow/.state.json`.

**State flow:** `IDLE → RESEARCH → SPEC → DESIGN → BEADS → CODE_LOOP → DEPLOY → DONE`

> TEST, REVIEW, VERIFY, PR, and MERGE are **not** top-level states — they run per-task inside `CODE_LOOP`.

State file fields that matter:
- `currentState` — active phase
- `completedStates` — array of finished phases
- `feature` — `{ name, slug, description }` object
- `mode` — `"research"` or `"fast"`
- `taskLoop` — in-progress task context for CODE_LOOP
- `beadsEpic` — beads epic ID (or null if using `tasks.md` fallback)
- `worktree`, `prNumber`, `doltRemote` — release phase fields

### Quality Gate System

Two-layer enforcement around task closure:

**Layer 1 — Beads gates** (primary): `bd close` refuses to close tasks with unsatisfied gates unless `--force` is passed.

**Layer 2 — Claude Code hooks** (safety net):
- `PreToolUse` on Bash → `bd-close-gate.sh`: intercepts `bd close` commands, checks `quality-gate-status.json`
- `Stop` → `check-open-gates.sh`: blocks session end when gates are open
- `TaskCompleted` → `task-complete-gate.sh`

The gate status file `quality-gate-status.json` (schema at `quality-gate-status.schema.json`) is written by `c4flow:verify`. It tracks pass/fail for: `codex_review`, `bd_preflight`.

### External Tool Dependencies

- `bd` — beads CLI: task management, gate enforcement, `bd ready`, `bd close`, `bd preflight`, `bd dolt push`
- `codex` — Codex CLI at `/usr/local/nodejs/bin/codex`: `codex review --base main` for AI code review
- `gh` — GitHub CLI: PR creation, branch operations
- Dolt — version-controlled database backing the beads task graph

### Beads Viewer App

`apps/beads-viewer/` — a Cloudflare Workers app (`wrangler.jsonc`) that renders the beads task graph visually.

### OpenSpec

`openspec/` — change management system with `config.yaml`, `specs/`, and `changes/`. Used for tracking planned changes to the plugin itself.

## Skill Conventions

- Each skill directory may contain a `references/` subdirectory with context files the orchestrator reads before dispatching
- Research skill uses `prompt.md` as its execution steps (separate from `SKILL.md` overview)
- Skills that run as sub-agents receive structured parameters via the agent prompt; they return structured status (`DONE`, `DONE_WITH_CONCERNS`, `BLOCKED`, `NEEDS_CONTEXT`)
- Spec output always goes to `docs/specs/<feature.slug>/`
- Design output goes to `docs/c4flow/designs/<feature.slug>/`

## Key Constraints

- No runtime dependencies — plugin is pure markdown + shell scripts
- Beads graceful fallback: when `bd` is not installed, fall back to `docs/specs/<slug>/tasks.md`
- Codex graceful fallback: detect missing CLI and warn; don't hard-fail
- CodeRabbit: webhook-only (no CLI); skip `PR_REVIEW_LOOP` CodeRabbit gate if not configured
- Hook scripts must read JSON from stdin and output JSON to stdout per Claude Code hook protocol
