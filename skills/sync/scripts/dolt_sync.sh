#!/usr/bin/env bash
# dolt_sync.sh — sync beads from DoltHub
# Usage: bash dolt_sync.sh [project-root]
# Must be run from the project root, or pass project root as $1
#
# KEY INSIGHT: dolt CLI (fetch, reset) must run with server STOPPED.
# When server is running, refs are managed in-memory; CLI cannot see them
# after server stops. Running CLI offline writes refs to disk directly.

set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
cd "$PROJECT_ROOT"

# ── helpers ──────────────────────────────────────────────────────────────────
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }
err()  { echo "❌ $*" >&2; exit 1; }
info() { echo "ℹ️  $*"; }

# ── 1. check .beads exists ───────────────────────────────────────────────────
[ -d ".beads" ] || err "No .beads/ directory found. Run c4flow:init first."

# ── 2. read .state.json ──────────────────────────────────────────────────────
STATE_FILE="docs/c4flow/.state.json"
[ -f "$STATE_FILE" ] || STATE_FILE=".beads/.state.json"
[ -f "$STATE_FILE" ] || STATE_FILE=".state.json"
[ -f "$STATE_FILE" ] || err "No .state.json found (checked docs/c4flow/, .beads/, root)."

DOLT_REMOTE=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('doltRemote',''))" 2>/dev/null)
[ -n "$DOLT_REMOTE" ] || err "No doltRemote in $STATE_FILE — Dolt sync not configured."

PROJECT_NAME=$(basename "$DOLT_REMOTE")
DOLT_DB="$PROJECT_ROOT/.beads/dolt/$PROJECT_NAME"

info "DoltHub remote : $DOLT_REMOTE"
info "Dolt DB path   : $DOLT_DB"

# ── 3. stop server — ALL dolt CLI ops must run offline ───────────────────────
# When server is running, dolt manages refs in-memory. Fetched refs from the
# server session are NOT accessible to CLI after server stops. Running everything
# offline makes dolt write refs directly to disk, which persists correctly.
info "Stopping bd server (all sync ops run offline)..."
bd dolt stop 2>/dev/null || true
sleep 1

# ── 4. create inner DB if missing ───────────────────────────────────────────
if [ ! -d "$DOLT_DB" ]; then
  warn "Inner DB missing — initializing at $DOLT_DB"
  mkdir -p "$DOLT_DB"
  (cd "$DOLT_DB" && dolt init) || err "dolt init failed"
fi

# ── 5. ensure remote is configured (offline CLI) ─────────────────────────────
EXISTING_REMOTE=$(cd "$DOLT_DB" && dolt remote -v 2>/dev/null | head -1 | awk '{print $2}' || true)
if [ -z "$EXISTING_REMOTE" ]; then
  info "Adding DoltHub remote..."
  (cd "$DOLT_DB" && dolt remote add origin "$DOLT_REMOTE") || err "Failed to add remote"
elif [ "$EXISTING_REMOTE" != "$DOLT_REMOTE" ]; then
  warn "Remote mismatch — updating to match .state.json..."
  (cd "$DOLT_DB" && dolt remote remove origin && dolt remote add origin "$DOLT_REMOTE")
fi

# ── 6. fetch from DoltHub (offline CLI — refs written to disk) ───────────────
info "Fetching from DoltHub..."
FETCH_OUT=$((cd "$DOLT_DB" && dolt fetch origin 2>&1) || true)
if echo "$FETCH_OUT" | grep -qi "authentication"; then
  err "DoltHub authentication required. Run: dolt login"
fi
if echo "$FETCH_OUT" | grep -qi "not found\|does not exist"; then
  err "Remote repo not found: $DOLT_REMOTE"
fi

# ── 7. merge or reset ────────────────────────────────────────────────────────
MERGE_BASE=$((cd "$DOLT_DB" && dolt merge-base HEAD remotes/origin/main 2>&1) || true)

if echo "$MERGE_BASE" | grep -qi "no common ancestor\|error"; then
  LOCAL_COMMITS=$((cd "$DOLT_DB" && dolt log --oneline 2>/dev/null | wc -l | tr -d ' ') || echo "0")

  if [ "$LOCAL_COMMITS" -gt 5 ]; then
    warn "Local DB has $LOCAL_COMMITS commits, no common ancestor with DoltHub."
    warn "May have local-only beads. Aborting — review manually."
    warn "To force: cd $DOLT_DB && dolt reset --hard remotes/origin/main"
    exit 1
  fi

  info "Fresh local DB ($LOCAL_COMMITS commits). Resetting to DoltHub history..."
  (cd "$DOLT_DB" && dolt reset --hard remotes/origin/main) || err "dolt reset --hard failed"

else
  info "Pulling from DoltHub (shared history)..."
  PULL_OUT=$((cd "$DOLT_DB" && dolt pull origin main 2>&1) || true)
  if echo "$PULL_OUT" | grep -qi "conflict"; then
    warn "Merge conflicts — resolve manually."
    echo "$PULL_OUT"
    exit 1
  fi
fi

# ── 8. start server ──────────────────────────────────────────────────────────
info "Starting bd server..."
bd dolt start 2>/dev/null || err "Server failed to start"
sleep 3

if ! bd dolt status 2>/dev/null | grep -q "running"; then
  err "Server started but not responding. Check: cat $PROJECT_ROOT/.beads/dolt-server.log | tail -20"
fi

# ── 9. verify ────────────────────────────────────────────────────────────────
HEAD_HASH=$(cd "$DOLT_DB" && dolt log --oneline -n 1 2>/dev/null | awk '{print substr($1,1,8)}' || echo "unknown")
HEAD_MSG=$(cd "$DOLT_DB" && dolt log --oneline -n 1 2>/dev/null | cut -d' ' -f2- || echo "")
BEAD_COUNT=$(bd list 2>/dev/null | grep -c "^[│├└○]" || echo "0")

ok "Dolt sync complete"
echo "   Remote : $DOLT_REMOTE"
echo "   HEAD   : $HEAD_HASH ($HEAD_MSG)"
echo "   Beads  : $BEAD_COUNT issues"
