  ---
name: c4flow:sync
description: Sync local project with remote sources — pulls DoltHub beads and GitHub repo to local. Handles the "no common ancestor" Dolt error that occurs when bd init creates a fresh local DB that conflicts with an existing DoltHub history. Use when local beads are out of sync, after a fresh init on a project that already has DoltHub data, or to pull the latest GitHub changes.
---

# /c4flow:sync — Remote Sync (DoltHub + GitHub)

**Agent type**: Main agent (interactive)
**Status**: Implemented

## What It Does

Safely syncs both Dolt beads and GitHub code to the local workspace:

1. **Dolt sync** — reads remote from `.state.json`, finds correct DB path, fetches from DoltHub, resets if needed
2. **GitHub sync** — pulls latest code from origin

## Understanding the Dolt DB Structure

`bd` uses a **multi-repo Dolt server** layout. The server is started with `bd dolt start` and serves from `.beads/dolt/`. Inside that directory are named sub-repos:

```
.beads/dolt/                      ← server data root (NOT a dolt repo itself)
.beads/dolt/<project-name>/       ← actual dolt repo that bd connects to
```

Where `<project-name>` is the last segment of the DoltHub remote URL (e.g., `https://doltremoteapi.dolthub.com/org/uml_diagram` → `uml_diagram`).

**This matters**: all `dolt` CLI commands must be run from `.beads/dolt/<project-name>/`, not from `.beads/dolt/`. Running from the wrong directory silently targets a different (empty) DB.

## The "No Common Ancestor" Problem

When `c4flow:init` runs `bd init` on a project that *already has DoltHub data*, it creates a fresh local Dolt DB with an independent commit history. Dolt then refuses to pull because the two histories never shared a root commit.

```
DoltHub:  [dolthub-init] → [bead.1] → [bead.2] → ... → [HEAD]
Local:    [local-init]   → (empty)
                 ↑ no shared ancestor — pull fails
```

**Fix**: abandon the empty local history and replace it with the remote's history using `dolt reset --hard remotes/origin/main`.

## Instructions

### Step 1: Detect Local Dolt State

First, check if `.beads/` exists:

```bash
[ -d ".beads" ] && echo "BEADS_PRESENT" || echo "NO_BEADS"
```

If no `.beads/`, stop and tell user to run `c4flow:init` first.

**Read `.state.json` for DoltHub config** — this is the source of truth:

```bash
cat .beads/.state.json 2>/dev/null || cat .state.json 2>/dev/null
```

Extract `doltRemote` from the JSON. If `doltRemote` is present and non-null, use it. This is the URL to sync against.

**Derive the correct Dolt DB path** from the remote URL:

```
https://doltremoteapi.dolthub.com/org/uml_diagram
                                              ↑
                                    project-name = "uml_diagram"
Dolt DB path = .beads/dolt/<project-name>/
```

**Check the actual Dolt DB** (the inner one, not the root):

```bash
DOLT_DB=".beads/dolt/<project-name>"

# Check remote configured in inner DB
cd "$DOLT_DB" && dolt remote -v 2>/dev/null

# Get local commit count
cd "$DOLT_DB" && dolt log --oneline 2>/dev/null | wc -l
```

Classify local state:

| `.beads/` | `doltRemote` in `.state.json` | Remote in inner DB | Local commits | State |
|-----------|-------------------------------|-------------------|---------------|-------|
| No | — | — | — | `NO_BEADS` — run `c4flow:init` first |
| Yes | No | No | any | `LOCAL_ONLY` — no sync possible |
| Yes | Yes | No | any | `NEEDS_REMOTE` — configure remote from `.state.json`, then sync |
| Yes | Yes | Yes | 1 (fresh init) | `FRESH_LOCAL` — likely conflict |
| Yes | Yes | Yes | >1 | `HAS_HISTORY` — normal pull |

**If `NEEDS_REMOTE`**: automatically add the remote from `.state.json`:

```bash
cd .beads/dolt/<project-name> && dolt remote add origin <doltRemote-from-state-json>
```

Then proceed to Step 2.

### Step 2: Fetch from DoltHub

```bash
cd .beads/dolt/<project-name> && dolt fetch origin 2>&1
```

Capture output. If fetch fails:
- `authentication required` → tell user to run `dolt login` first
- `not found` → remote URL may be wrong; show `dolt remote -v`
- Any other error → show full error and stop

### Step 3: Detect Conflict

After fetch succeeds, check for common ancestor:

```bash
cd .beads/dolt/<project-name> && dolt merge-base HEAD remotes/origin/main 2>&1
```

- **Returns a commit hash** → histories share a root → normal pull (Step 4a)
- **Returns error / empty** → no common ancestor → conflict reset (Step 4b)

### Step 4a: Normal Pull (shared history)

```bash
cd .beads/dolt/<project-name> && dolt pull origin main 2>&1
```

If pull succeeds, continue to Step 5.

If pull shows conflicts:

```bash
cd .beads/dolt/<project-name> && dolt conflicts cat issues 2>/dev/null
```

Report conflicts to user and ask how to resolve. Do NOT auto-resolve.

### Step 4b: Conflict Reset (no common ancestor)

Warn the user before resetting:

> ⚠️ Local Dolt history has no common ancestor with DoltHub. This means `bd init` created a fresh local DB after DoltHub already had data.
>
> The local DB appears empty (fresh init, no real beads). Safe to replace with DoltHub's history.
>
> Running: `dolt reset --hard remotes/origin/main`

Only proceed automatically if local commit count is ≤3 (fresh init with schema migration commits, no real bead data). If local has more commits, stop and ask the user before resetting — they may have local-only beads that would be lost.

```bash
cd .beads/dolt/<project-name> && dolt reset --hard remotes/origin/main 2>&1
```

Verify reset succeeded:

```bash
cd .beads/dolt/<project-name> && dolt log -n 3 2>/dev/null
cd .beads/dolt/<project-name> && dolt status 2>/dev/null
```

### Step 5: Restart bd server and Verify Beads

After any reset or fetch, restart the bd server so it picks up the new HEAD:

```bash
bd dolt stop 2>&1; sleep 1; bd dolt start 2>&1; sleep 3
bd list 2>&1
```

Show the bead count and top-level epics. If `bd list` is still empty after restart, check that the reset succeeded and the server is serving the right database.

### Step 6: Sync GitHub (git pull)

Check git status first:

```bash
git status --short 2>&1
git remote -v 2>&1 | head -4
```

If there are uncommitted local changes, show them and ask the user:
- Stash and pull?
- Commit first?
- Skip GitHub sync?

If clean (or user approves), pull:

```bash
git pull origin $(git rev-parse --abbrev-ref HEAD) 2>&1
```

Handle common errors:

| Error | Action |
|-------|--------|
| `no tracking information` | `git branch --set-upstream-to=origin/main main` then retry |
| `merge conflict` | Show conflicting files, tell user to resolve manually |
| `not a git repository` | Skip GitHub sync, note it |
| `already up to date` | Report as success |

### Step 7: Report

Print a sync summary:

```
✅ Dolt sync complete
   Remote: https://doltremoteapi.dolthub.com/org/repo
   HEAD: <short-hash> (<commit message>)
   Beads: <N> open issues

✅ GitHub sync complete
   Branch: main
   HEAD: <short-hash> (<commit message>)
```

Or per-item status if one failed.

## Error Reference

| Error | Root Cause | Fix |
|-------|-----------|-----|
| `no common ancestor` | `bd init` ran locally after DoltHub already had data | Step 4b reset |
| `authentication required` | Not logged into DoltHub | `dolt login` |
| `remote not found` | No DoltHub remote configured | Read from `.state.json`, add via `dolt remote add` |
| `bd list` empty after reset | Reset ran on wrong (outer) DB | Make sure commands run in `.beads/dolt/<project-name>/` |
| `merge conflict` in Dolt | Concurrent edits to same bead | Report to user, no auto-resolve |
| git `merge conflict` | Diverged branches | Report to user, no auto-resolve |

## IMPORTANT Rules

1. **Always target `.beads/dolt/<project-name>/`** — never `.beads/dolt/` directly. The outer directory is the server root, not a Dolt repo.
2. **Read `doltRemote` from `.state.json` first** — don't give up if the inner DB has no remote; configure it from `.state.json` automatically.
3. **Never `dolt reset --hard` if local has many commits** — data loss risk. Always confirm with user if >3 local commits.
4. **Never `git reset --hard`** — only `git pull`.
5. **Restart bd server after any dolt reset** — the server caches state; a restart is needed to serve the new HEAD.
6. **Never run `bd doctor`** — hangs indefinitely.
