---
name: c4flow:init
description: Initialize C4Flow dependencies in the current project — auto-sets up git (init repo if missing), installs Dolt and Beads. Use when setting up a new project, when bd/dolt is missing, or when the user needs to configure DoltHub sync or team collaboration.
---

# /c4flow:init — Project Initialization

**Agent type**: Main agent (interactive)
**Status**: Implemented

## What It Does

Detects, installs, and configures all C4Flow dependencies in the current project:

- **Git** — auto-installs if missing; auto-inits a repo if not inside one
- **Dolt** — version-controlled SQL database (Beads backend)
- **Beads (bd)** — issue tracking and task management CLI

- Runs `bd init` + starts Dolt server
- Installs git hooks for data consistency (`bd hooks install`)
- Optionally configures **DoltHub sync** for cloud backup
- Sets up `bd prime` for Claude context injection

## Instructions

### Step 1: Find and Run the Init Script

The init script is bundled with this skill. Find and run it:

```bash
# Search common locations (latest version first for plugin cache)
INIT_SCRIPT=""
for dir in \
  "$(pwd)" \
  $(ls -d "$HOME/.claude/plugins/cache/c4flow-marketplace/c4flow/"*/ 2>/dev/null | sort -V -r) \
  "$HOME/.codex/c4flow"; do
  if [ -f "$dir/skills/init/init.sh" ]; then
    INIT_SCRIPT="$dir/skills/init/init.sh"
    break
  fi
done

if [ -n "$INIT_SCRIPT" ]; then
  echo "Found: $INIT_SCRIPT"
  bash "$INIT_SCRIPT" "$@"
else
  echo "Init script not found"
fi
```

The script will:
1. Check/install `dolt`
2. Check/install `bd` (Beads)
3. Run `bd init` with a 30s timeout
4. Start Dolt server if not running
5. Configure DoltHub remote (if `--remote` provided)
6. Verify connectivity with `bd list`

**All steps have timeouts. Total time should be under 30 seconds.**

#### DoltHub Sync

If the user provides a DoltHub URL, pass it with `--remote`:

```bash
bash "$dir/skills/init/init.sh" --remote https://www.dolthub.com/repositories/org/repo
```

The script accepts these URL formats:
- `https://www.dolthub.com/repositories/org/repo` (web URL — auto-converted)
- `https://doltremoteapi.dolthub.com/org/repo` (API URL — used as-is)
- `org/repo` (short form — auto-expanded)

The script will:
1. Convert the URL to API format
2. Run `bd dolt remote add origin <api-url>`
3. Do an initial `bd dolt push`

If push fails (auth), it tells the user to run `dolt login` first.

### Step 2: Post-Init Configuration

After the init script completes, run these additional setup steps:

#### Install git hooks

Beads uses git hooks for data consistency. If an external hook manager (lefthook, husky, pre-commit) is detected, beads chains its hooks:

```bash
bd hooks install 2>/dev/null
```

This installs:
- `pre-commit` — data consistency checks
- `post-merge` — ensures Dolt DB stays current after pull/merge

#### Set up Claude integration (bd prime)

`bd prime` injects ~1-2k tokens of workflow context into Claude sessions. This is far more efficient than MCP tool schemas (10-50x less overhead):

```bash
bd setup claude --project 2>/dev/null
```

This installs SessionStart and PreCompact hooks that run `bd prime` to keep Claude aware of the current beads state.

#### Configure team settings (if multi-person)

For team workflows, configure the actor identity and auto-push:

```bash
# Set actor for audit trail (defaults to git user.name)
bd config set actor "$(git config user.name)" 2>/dev/null

# Enable JSONL backup (safety net behind Dolt snapshots)
bd config set backup.enabled true 2>/dev/null
```

#### Verify workspace state

```bash
bd info --json 2>/dev/null
bd list --json 2>/dev/null
```

### Step 3: Update State

If a DoltHub remote was configured, save the API URL to `docs/c4flow/.state.json`:

```json
{
  "doltRemote": "https://doltremoteapi.dolthub.com/org/repo"
}
```

Read the existing `.state.json` first (create it if missing), then merge the `doltRemote` field.

### Step 4: Report Result

The script outputs a verification summary. Just relay it to the user.

If the script is not found, run these commands manually:
```bash
# Git (if missing / no repo)
git init && git commit --allow-empty -m "chore: initial commit"

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
| `bd init` fails | Try `bd init --stealth` for minimal mode (no hooks, no AGENTS.md) |
| Dolt won't connect | `bd dolt start`, then `bd dolt status` to check |
| Hook manager conflict | `bd hooks install` auto-chains with lefthook/husky/pre-commit |
| Git worktree | All worktrees share the same `.beads/` — database discovery is automatic |
