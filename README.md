# c4flow

A self-contained **Claude Code plugin** that orchestrates a complete agentic software development workflow — from research through deployment.

## What It Does

c4flow provides **15 skills** grouped into **6 phases**, driven by an auto-orchestrator with a **14-state** state machine. Sub-agents handle autonomous execution; the main agent handles user interaction.

```
IDLE → RESEARCH → SPEC → DESIGN → BEADS → CODE → TEST
  → REVIEW → VERIFY → PR → PR_REVIEW_LOOP → MERGE → DEPLOY → DONE
```

### Phases

| Phase | Skills | Description |
|-------|--------|-------------|
| 1. Research & Spec | `research`, `spec` | Market research + spec generation |
| 2. Design & Beads | `design`, `beads` | Design system + task breakdown |
| 3. Implementation | `code`, `tdd` | TDD-driven code via sub-agents |
| 4. Testing | `test`, `e2e` | Unit/integration + end-to-end tests |
| 5. Review & QA | `review`, `verify` | AI review loop + quality gate |
| 6. Release | `pr`, `pr-review`, `infra`, `merge`, `deploy` | PR → review → merge → deploy |

## Installation

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed

### Install as Plugin

```bash
# Open your project directory
cd your-project

# Install c4flow plugin from GitHub
claude plugins install c4flow --marketplace https://github.com/tunneleven/C4Flow

# Enable for current project
claude plugins enable c4flow
```

Or manually: add to your project's `.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "c4flow@your-marketplace": true
  }
}
```

### Usage

```bash
# Start or resume a workflow
/c4flow:run <feature idea>

# Check current workflow status
/c4flow:status
```

The orchestrator will guide you through each phase, dispatching sub-agents for autonomous work and asking for your input on decisions.

## Current Status

**MVP Phase 1 — Complete**

| Component | Status |
|-----------|--------|
| Orchestrator (14-state machine) | Shell implemented |
| `/c4flow:research` | Implemented (5 research standards, quality gate) |
| `/c4flow:spec` | Implemented (4 artifacts, interactive) |
| `/c4flow:beads` | Implemented (epic→spec linking, tasks.md fallback) |
| Skills 03, 05-15 (design, code → deploy) | Stub (not yet implemented) |
| `/c4flow:run` command | Implemented |
| `/c4flow:status` command | Implemented |

Phase 1 covers the **Research & Spec** workflow: web research via sub-agent, then interactive spec generation producing `proposal.md`, `tech-stack.md`, `spec.md`, and `design.md`. The beads skill creates task epics with links back to spec documents.

## Plugin Structure

```
c4flow/
├── .claude-plugin/
│   └── plugin.json                 # Plugin manifest (v0.1.0)
├── skills/
│   ├── c4flow/SKILL.md             # Master orchestrator
│   ├── research/SKILL.md           # Web research (implemented)
│   ├── spec/SKILL.md               # Spec generation (implemented)
│   ├── beads/SKILL.md              # Task breakdown (implemented)
│   ├── design/SKILL.md             # Stubs for future phases
│   ├── code/ tdd/ test/ e2e/       #   ...
│   ├── review/ verify/             #   ...
│   └── pr/ pr-review/ infra/ merge/ deploy/
├── commands/
│   ├── run.md                      # /c4flow:run entry point
│   └── status.md                   # /c4flow:status display
└── references/
    ├── workflow-state.md            # State machine definition
    ├── phase-transitions.md         # Gate rules + error handling
    ├── sub-agent-prompt-template.md # Sub-agent prompt template
    └── spec-templates/              # 5 artifact templates
```

## Spec Output

Spec artifacts are generated at `docs/specs/<feature>/`:

```
docs/specs/user-auth/
  research.md       # Market/tech research
  proposal.md       # Why + what (forked from OpenSpec)
  tech-stack.md     # Technology selections
  spec.md           # Behavioral specs (GIVEN/WHEN/THEN)
  design.md         # Technical design
```

## Optional Dependencies

These enhance the workflow but are not required (graceful fallbacks exist):

| Dependency | Purpose | Fallback |
|-----------|---------|----------|
| [Beads](https://github.com/tunneleven/beads) (`bd`) | Issue tracking + task management | `tasks.md` checklist |
| Pencil MCP | Design mockups | Text-based layouts |
| UI/UX Pro Max Skill | Design system generation | Best-practice defaults |

## Design Docs

- [Full Workflow Design](docs/c4flow/specs/2026-03-13-c4flow-workflow-design.md) — complete system architecture
- [MVP Phase 1 Design](docs/c4flow/specs/2026-03-15-c4flow-mvp-phase1-design.md) — what's currently implemented
- [MVP Phase 1 Plan](docs/c4flow/plans/2026-03-15-c4flow-mvp-phase1.md) — implementation plan

## License

MIT
