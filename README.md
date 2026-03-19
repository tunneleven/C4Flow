# c4flow

An **agentic development workflow** plugin for Claude Code — orchestrates your entire dev process from idea to deployment, one phase at a time.

```
IDLE → RESEARCH → SPEC → DESIGN → BEADS → CODE → TEST
     → REVIEW → VERIFY → PR → PR_REVIEW_LOOP → MERGE → DEPLOY → DONE
```

## Install

```bash
claude plugins marketplace add https://github.com/tunneleven/C4Flow
claude plugins install c4flow
```

> **Codex CLI:** Tell Codex to fetch and follow `https://raw.githubusercontent.com/tunneleven/C4Flow/main/.codex/INSTALL.md`

## Usage

```bash
# Start a new feature workflow
/c4flow:run "user authentication with OAuth"

# Resume where you left off
/c4flow:run

# Check current state
/c4flow:status
```

That's it. The orchestrator picks up the current phase, dispatches sub-agents for heavy lifting, and asks for your input at key decisions.

---

## How the Workflow Works

Each `/c4flow:run` call advances one phase. The state machine persists to `docs/c4flow/.state.json` so you can stop and resume anytime.

### Phase 1 — Research & Spec
**`/c4flow:research`** — Web research via sub-agent. Produces `research.md` with market analysis, competitive landscape, and tech options.

**`/c4flow:spec`** — Interactive spec generation. Produces 4 artifacts:
```
docs/specs/<feature>/
  proposal.md     # Why + what to build
  tech-stack.md   # Technology decisions
  spec.md         # Behavioral specs (GIVEN/WHEN/THEN)
  design.md       # Technical architecture
```

### Phase 2 — Design & Tasks
**`/c4flow:design`** — Generates a design system (OKLCH tokens, typography, spacing) and screen mockups via [Pencil MCP](https://docs.pencil.dev/getting-started/ai-integration). Produces:
```
docs/c4flow/designs/<feature>/
  MASTER.md         # Design tokens + component list
  screen-map.md     # Screen breakdown
  <feature>.pen     # Pencil file with all screens
```

**`/c4flow:beads`** — Breaks spec into a tracked task epic with linked issues.

### Phase 3–6 — Code → Deploy
**`code` → `tdd` → `test` → `e2e` → `review` → `verify` → `pr` → `merge` → `deploy`**

Sub-agents implement features task-by-task using TDD, run tests, create PRs, and deploy — while you review and approve at gates.

---

## Setup

```bash
# Bootstrap project tooling (Dolt + Beads + optional GitHub/CodeRabbit)
/c4flow:init
```

### Optional: Pencil MCP (for Design phase)

Install from [pencil.dev](https://docs.pencil.dev/getting-started/ai-integration) to get visual mockups. Without it, the DESIGN phase is skipped gracefully.

### Optional: Beads (`bd`)

```bash
# Install task tracker
npm install -g @tunneleven/beads
```

Without Beads, task breakdowns fall back to `tasks.md`.

---

## Skills

| Phase | Skill | Status |
|-------|-------|--------|
| Orchestrator | `c4flow` | ✅ |
| Init | `init` | ✅ |
| Research | `research` | ✅ |
| Spec | `spec` | ✅ |
| Design | `design` | ✅ |
| Task Breakdown | `beads` | ✅ |
| Implementation | `code`, `tdd` | ✅ |
| Testing | `test`, `e2e` | ✅ |
| Review & QA | `review`, `verify` | ✅ |
| Release | `pr`, `infra`, `merge`, `deploy` | ✅ |

## License

MIT
