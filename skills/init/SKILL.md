---
name: c4flow:init
description: Initialize C4Flow dependencies (Dolt, Beads) in the current project.
---

# /c4flow:init — Project Initialization

**Agent type**: Main agent (interactive)
**Status**: Implemented

## What It Does

Installs and configures all C4Flow dependencies in the current project:
- **Dolt** — version-controlled SQL database (Beads backend)
- **Beads (bd)** — issue tracking and task management CLI
- Runs `bd init` to set up `.beads/` in the project

## Instructions

### Step 1: Check Current State

Run the init script with a dry check first:

```bash
# Check what's already installed
command -v git && echo "git: OK" || echo "git: MISSING"
command -v dolt && echo "dolt: OK" || echo "dolt: MISSING"
command -v bd && echo "bd: OK" || echo "bd: MISSING"
[ -d ".beads" ] && echo ".beads: OK" || echo ".beads: MISSING"
```

Tell the user what's already installed and what will be installed.

### Step 2: Run Init Script

The init script is bundled with C4Flow. Find and run it:

```bash
# Find the script relative to the skill location
C4FLOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Or use the known path if installed as a plugin
INIT_SCRIPT="${C4FLOW_DIR}/scripts/init.sh"
```

Run the appropriate command:

```bash
# Full init (installs dolt + beads + bd init)
bash /path/to/c4flow/scripts/init.sh

# With custom prefix
bash /path/to/c4flow/scripts/init.sh --prefix MyProject

# Skip beads (just verify git)
bash /path/to/c4flow/scripts/init.sh --skip-beads
```

**Finding the script**: The script lives at `scripts/init.sh` relative to the C4Flow installation. Common locations:
- Plugin install: `~/.claude/plugins/c4flow/scripts/init.sh`
- Codex install: `~/.codex/c4flow/scripts/init.sh`
- Local dev: `./scripts/init.sh` (if running from C4Flow repo)

If the script is not found, fall back to running the commands manually:

```bash
# Install Dolt
curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | sudo bash

# Install Beads
curl -sSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash

# Init Beads in project
bd init
```

### Step 3: Verify

```bash
bd doctor
```

If there are fixable issues:
```bash
bd doctor --fix --yes
```

### Step 4: Report

Tell the user the result:
- What was installed
- Whether `bd doctor` passes
- Next steps: "Run `/c4flow` to start a workflow"

## Error Handling

| Error | Solution |
|-------|----------|
| `sudo` required for Dolt | Ask user to run with sudo, or use Homebrew |
| Dolt server won't start | Check port conflicts: `lsof -i :3306` |
| `bd init` fails | Try `bd init --stealth` for git-free mode |
| Permission denied | Check `~/.local/bin` is in PATH |
