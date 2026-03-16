# C4Flow for Codex CLI

## Quick Install

Tell Codex:

> "Fetch and follow instructions from https://raw.githubusercontent.com/tunneleven/C4Flow/main/.codex/INSTALL.md"

## Manual Installation

1. Clone: `git clone https://github.com/tunneleven/C4Flow.git ~/.codex/c4flow`
2. Symlink: `mkdir -p ~/.agents/skills && ln -s ~/.codex/c4flow/skills ~/.agents/skills/c4flow`
3. Restart Codex

## How It Works

Codex scans `~/.agents/skills/` at startup, parsing SKILL.md frontmatter to discover skills. The symlink makes all C4Flow skills available as `$c4flow`, `$c4flow-research`, `$c4flow-spec`, etc.

## Usage

- `$c4flow` — Start the full workflow (equivalent to `/c4flow:run` in Claude Code)
- Type your feature idea when prompted

## Skills Available

| Skill | Description | Status |
|---|---|---|
| c4flow | Orchestrator — drives the 14-state workflow | Implemented |
| c4flow:research | Web research on feature idea | Implemented |
| c4flow:spec | Interactive spec generation (4 artifacts) | Implemented |
| c4flow:beads | Task breakdown with epic/tasks | Implemented |
| c4flow:design | Design system + mockups | Stub |
| c4flow:code | Code implementation via sub-agents | Stub |
| c4flow:test | Unit + integration tests | Stub |
| c4flow:review | AI code review loop | Stub |
| c4flow:verify | Quality gate | Stub |
| c4flow:pr | Create pull request | Stub |
| c4flow:merge | Merge to main | Stub |
| c4flow:deploy | Deploy to production | Stub |

## Update

```bash
cd ~/.codex/c4flow && git pull
```

## Uninstall

```bash
rm ~/.agents/skills/c4flow
rm -rf ~/.codex/c4flow
```
