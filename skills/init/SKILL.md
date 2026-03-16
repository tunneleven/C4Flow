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
- Runs `bd init` + starts Dolt server

## Instructions

### Step 1: Find and Run the Init Script

The init script handles everything automatically. Find and run it:

```bash
# Search common locations
for dir in \
  "$(pwd)" \
  "$HOME/.claude/plugins/cache/c4flow-marketplace/c4flow/"*/ \
  "$HOME/.codex/c4flow"; do
  if [ -f "$dir/scripts/init.sh" ]; then
    echo "Found: $dir/scripts/init.sh"
    bash "$dir/scripts/init.sh"
    exit 0
  fi
done
echo "Init script not found"
```

The script will:
1. Check/install `dolt`
2. Check/install `bd` (Beads)
3. Run `bd init` with a 30s timeout
4. Start Dolt server if not running
5. Verify connectivity with `bd list`

**All steps have timeouts. Total time should be under 30 seconds.**

### Step 2: Report Result

The script outputs a verification summary. Just relay it to the user.

If the script is not found, run these commands manually:
```bash
# Install Dolt (if missing)
curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | sudo bash

# Install Beads (if missing)
curl -sSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash

# Init in project
bd init
```

## IMPORTANT Rules

1. **Never run `bd doctor` or `bd doctor --fix`** — hangs indefinitely. The init script verifies with `bd list` instead.
2. **Use `bd dolt start`** to start the server — never run `dolt sql-server` manually. Beads manages its own server lifecycle.
3. **Default Dolt port is 3307** (not 3306) — avoids MySQL conflicts.
4. Dolt server **auto-starts** when needed — calling `bd list` triggers it.

If Dolt connection fails after init, tell the user:
> "Run `bd dolt start` to start the Dolt server, or `bd dolt status` to check."

## Error Handling

| Error | Solution |
|-------|----------|
| `sudo` required for Dolt | Ask user to run with sudo, or use `brew install dolt` |
| `bd init` times out | Script continues, uses `bd dolt start` |
| Port conflict | Beads picks port automatically (default 3307) |
| `bd init` fails | Try `bd init --stealth` for minimal mode |
| Dolt won't connect | `bd dolt start`, then `bd dolt status` to check |
