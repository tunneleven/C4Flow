# c4flow

A self-contained **agentic development workflow plugin** that orchestrates a complete software development workflow — from research through deployment. Works with **Claude Code** and **OpenAI Codex CLI**.

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

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI **or** [OpenAI Codex CLI](https://github.com/openai/codex) installed

### Option 1: Install from Terminal

```bash
# Step 1: Add C4Flow as a marketplace
claude plugins marketplace add https://github.com/tunneleven/C4Flow

# Step 2: Install the plugin
claude plugins install c4flow

# (Optional) Install for current project only
claude plugins install c4flow --scope project
```

### Option 2: Install from within Claude Code REPL

While inside a Claude Code session, type:

```
/plugins
```

Then select **"Install a plugin"**, choose the c4flow marketplace, and install.

> If C4Flow marketplace is not listed, first add it from terminal:
> ```bash
> claude plugins marketplace add https://github.com/tunneleven/C4Flow
> ```

### Option 3: Install for OpenAI Codex CLI

Tell Codex:

> "Fetch and follow instructions from https://raw.githubusercontent.com/tunneleven/C4Flow/main/.codex/INSTALL.md"

Or manually:

```bash
git clone https://github.com/tunneleven/C4Flow.git ~/.codex/c4flow
mkdir -p ~/.agents/skills
ln -s ~/.codex/c4flow/skills ~/.agents/skills/c4flow
```

Restart Codex, then use `$c4flow` to start the workflow. See [Codex CLI docs](docs/README.codex.md) for details.

### Usage

```bash
# Start or resume a workflow
/c4flow:run <feature idea>

# Check current workflow status
/c4flow:status
```

The orchestrator will guide you through each phase, dispatching sub-agents for autonomous work and asking for your input on decisions.

### Init Bootstrap

```bash
/c4flow:init
```

The init flow now:

- installs and verifies Dolt + Beads
- optionally asks whether to create or manage a GitHub repository for the current project
- optionally asks whether to set up CodeRabbit for that repository

GitHub bootstrap uses Terraform and GitHub auth environment variables. CodeRabbit setup creates `.coderabbit.yaml` and can auto-attach an existing installation when an installation id is provided.

## Current Status

**MVP Phase 1 — Complete**

| Component | Status |
|-----------|--------|
| Orchestrator (14-state machine) | Shell implemented |
| `/c4flow:research` | Implemented (5 research standards, quality gate) |
| `/c4flow:spec` | Implemented (4 artifacts, interactive) |
| `/c4flow:beads` | Implemented (epic→spec linking, tasks.md fallback) |
| `/c4flow:init` | Implemented (Dolt + Beads, optional GitHub + CodeRabbit bootstrap) |
| Skills 03, 05-15 (design, code → deploy) | Stub (not yet implemented) |
| `/c4flow:run` command | Implemented |
| `/c4flow:status` command | Implemented |

Phase 1 covers the **Research & Spec** workflow: web research via sub-agent, then interactive spec generation producing `proposal.md`, `tech-stack.md`, `spec.md`, and `design.md`. The beads skill creates task epics with links back to spec documents.

## Plugin Structure

```
c4flow/
├── .claude-plugin/
│   └── plugin.json                 # Plugin manifest (v0.5.1)
├── skills/
│   ├── c4flow/SKILL.md             # Master orchestrator
│   ├── init/
│   │   ├── SKILL.md                # Project init (deps + optional remote bootstrap)
│   │   ├── init.sh                 # Auto-install script (Dolt, Beads, GitHub, CodeRabbit)
│   │   ├── templates/
│   │   │   └── coderabbit.yaml     # Starter CodeRabbit config
│   │   └── terraform/
│   │       └── github-bootstrap/   # GitHub repo bootstrap via Terraform
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
| [Beads](https://github.com/tunneleven/beads) (`bd`) | Issue tracking + task management | `tasks.md` checklist (auto-install via `/c4flow:init`) |
| Pencil MCP | Design mockups | Text-based layouts |
| UI/UX Pro Max Skill | Design system generation | Best-practice defaults |

## Design Docs

- [Full Workflow Design](docs/c4flow/specs/2026-03-13-c4flow-workflow-design.md) — complete system architecture
- [MVP Phase 1 Design](docs/c4flow/specs/2026-03-15-c4flow-mvp-phase1-design.md) — what's currently implemented
- [MVP Phase 1 Plan](docs/c4flow/plans/2026-03-15-c4flow-mvp-phase1.md) — implementation plan

## License

MIT
