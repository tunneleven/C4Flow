  ---
name: c4flow:sync
description: Sync local project with remote sources — pulls DoltHub beads and GitHub repo to local. Handles the "no common ancestor" Dolt error that occurs when bd init creates a fresh local DB that conflicts with an existing DoltHub history. Use when local beads are out of sync, after a fresh init on a project that already has DoltHub data, or to pull the latest GitHub changes.
---

# /c4flow:sync — Remote Sync (DoltHub + GitHub)

**Agent type**: Main agent (interactive)
**Status**: Implemented

## What It Does

Safely syncs both Dolt beads and GitHub code to the local workspace:

1. **Dolt sync** — detects history conflicts, fetches from DoltHub, resets if needed
2. **GitHub sync** — pulls latest code from origin

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

```bash
# Check if inside a beads project
[ -d ".beads" ] && echo "BEADS_PRESENT" || echo "NO_BEADS"

# Check configured remote
cd .beads 2>/dev/null && dolt remote -v 2>/dev/null || echo "NO_REMOTE"

# Get local commit count
cd .beads 2>/dev/null && dolt log --oneline 2>/dev/null | wc -l || echo "0"
```

Classify local state:

| `.beads/` | Remote configured | Local commits | State |
|-----------|------------------|---------------|-------|
| No | — | — | `NO_BEADS` — run `c4flow:init` first |
| Yes | No | any | `LOCAL_ONLY` — no sync possible |
| Yes | Yes | 1 (fresh init) | `FRESH_LOCAL` — likely conflict |
| Yes | Yes | >1 | `HAS_HISTORY` — normal pull |

### Step 2: Fetch from DoltHub

```bash
cd .beads && dolt fetch origin 2>&1
```

Capture output. If fetch fails:
- `authentication required` → tell user to run `dolt login` first
- `not found` → remote URL may be wrong; show `dolt remote -v`
- Any other error → show full error and stop

### Step 3: Detect Conflict

After fetch succeeds, check for common ancestor:

```bash
cd .beads && dolt merge-base HEAD remotes/origin/main 2>&1
```

- **Returns a commit hash** → histories share a root → normal pull (Step 4a)
- **Returns error / empty** → no common ancestor → conflict reset (Step 4b)

Also confirm whether local is simply behind (fast-forward case):

```bash
cd .beads && dolt log remotes/origin/main --oneline -n 1 2>/dev/null
cd .beads && dolt log HEAD --oneline -n 1 2>/dev/null
```

### Step 4a: Normal Pull (shared history)

```bash
cd .beads && dolt pull origin main 2>&1
```

If pull succeeds, continue to Step 5.

If pull shows conflicts:

```bash
# Show conflicting rows
cd .beads && dolt conflicts cat issues 2>/dev/null
```

Report conflicts to user and ask how to resolve. Do NOT auto-resolve.

### Step 4b: Conflict Reset (no common ancestor)

Warn the user before resetting:

> ⚠️ Local Dolt history has no common ancestor with DoltHub. This means `bd init` created a fresh local DB after DoltHub already had data.
>
> The local DB appears empty (fresh init, no real beads). Safe to replace with DoltHub's history.
>
> Running: `dolt reset --hard remotes/origin/main`

Only proceed automatically if local commit count is 1 (fresh init with no real data). If local has >1 commit, stop and ask the user before resetting — they may have local-only beads that would be lost.

```bash
cd .beads && dolt reset --hard remotes/origin/main 2>&1
```

Verify reset succeeded:

```bash
cd .beads && dolt log -n 3 2>/dev/null
cd .beads && dolt status 2>/dev/null
```

### Step 5: Verify Beads

```bash
bd list 2>&1
```

Show the bead count and top-level epics. If `bd list` fails, try `bd dolt start` first, then retry.

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
| `remote not found` | No DoltHub remote configured | Run `c4flow:init --remote <url>` |
| `merge conflict` in Dolt | Concurrent edits to same bead | Report to user, no auto-resolve |
| git `merge conflict` | Diverged branches | Report to user, no auto-resolve |

## IMPORTANT Rules

1. **Never `dolt reset --hard` if local has >1 commit** — data loss risk. Always confirm with user.
2. **Never `git reset --hard`** — only `git pull`.
3. **`bd dolt start` auto-starts** the server — no need to run `dolt sql-server` manually.
4. **Never run `bd doctor`** — hangs indefinitely.
5. After reset, always verify with `bd list` before declaring success.
