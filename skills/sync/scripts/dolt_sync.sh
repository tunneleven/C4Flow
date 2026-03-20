#!/usr/bin/env bash
# dolt_sync.sh — sync beads from DoltHub
# Usage: bash dolt_sync.sh [project-root]
# Must be run from the project root, or pass project root as $1

set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
cd "$PROJECT_ROOT"

# ── helpers ─────────────────────────────────────────────────────────────────
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
[ -f "$STATE_FILE" ] || err "No .state.json found (checked docs/c4flow/, .beads/, root). Cannot determine DoltHub remote."

DOLT_REMOTE=$(python3 -c "import json,sys; d=json.load(open('$STATE_FILE')); print(d.get('doltRemote',''))" 2>/dev/null)
[ -n "$DOLT_REMOTE" ] || err "No doltRemote in $STATE_FILE — Dolt sync not configured."

# derive project name from URL last segment
PROJECT_NAME=$(basename "$DOLT_REMOTE")
DOLT_DB="$PROJECT_ROOT/.beads/dolt/$PROJECT_NAME"

info "DoltHub remote : $DOLT_REMOTE"
info "Dolt DB path   : $DOLT_DB"

# ── 3. ensure server is STOPPED before touching files ────────────────────────
# We'll start it fresh at the right time. Stop gently so journal is flushed.
bd dolt stop 2>/dev/null || true
sleep 1

# ── 4. handle MISSING_DB — init empty repo, start server, then run bd init --force ──
# bd init --force must run AFTER the server is up so it creates the schema via the server.
MISSING_DB=false
if [ ! -d "$DOLT_DB" ]; then
  warn "Inner DB missing — initializing fresh at $DOLT_DB"
  mkdir -p "$DOLT_DB"
  (cd "$DOLT_DB" && dolt init) || err "dolt init failed"
  MISSING_DB=true
fi

# ── 5. start server BEFORE any fetch/reset ───────────────────────────────────
# Critical: dolt reset --hard MUST run while server is live, or journal corrupts.
info "Starting bd server..."
bd dolt start 2>/dev/null || true
sleep 3

# Confirm server is up
if ! bd dolt status 2>/dev/null | grep -q "running"; then
  err "bd server failed to start. Check: bd dolt status"
fi

# If we just created a fresh DB, run bd init --force to create the schema through the server
if [ "$MISSING_DB" = true ]; then
  info "Creating DB schema via bd init --force..."
  bd init --force 2>/dev/null || err "bd init --force failed"
fi

# ── 6. ensure remote is configured in inner DB ──────────────────────────────
EXISTING_REMOTE=$(cd "$DOLT_DB" && dolt remote -v 2>/dev/null | head -1 | awk '{print $2}' || true)
if [ -z "$EXISTING_REMOTE" ]; then
  info "Adding DoltHub remote..."
  (cd "$DOLT_DB" && dolt remote add origin "$DOLT_REMOTE") || err "Failed to add remote"
elif [ "$EXISTING_REMOTE" != "$DOLT_REMOTE" ]; then
  warn "Remote mismatch: local=$EXISTING_REMOTE, state=$DOLT_REMOTE"
  warn "Updating remote to match .state.json..."
  (cd "$DOLT_DB" && dolt remote remove origin && dolt remote add origin "$DOLT_REMOTE")
fi

# ── 7. fetch from DoltHub ────────────────────────────────────────────────────
info "Fetching from DoltHub..."
FETCH_OUT=$((cd "$DOLT_DB" && dolt fetch origin 2>&1) || true)
if echo "$FETCH_OUT" | grep -qi "authentication"; then
  err "DoltHub authentication required. Run: dolt login"
fi
if echo "$FETCH_OUT" | grep -qi "not found\|does not exist"; then
  err "Remote repo not found: $DOLT_REMOTE"
fi

# ── 8. check for common ancestor ─────────────────────────────────────────────
MERGE_BASE=$((cd "$DOLT_DB" && dolt merge-base HEAD remotes/origin/main 2>&1) || true)

if echo "$MERGE_BASE" | grep -qi "no common ancestor\|error"; then
  # No shared history — check if local is safe to discard
  LOCAL_COMMITS=$((cd "$DOLT_DB" && dolt log --oneline 2>/dev/null | wc -l | tr -d ' ') || echo "0")

  if [ "$LOCAL_COMMITS" -gt 5 ]; then
    warn "Local DB has $LOCAL_COMMITS commits and no common ancestor with DoltHub."
    warn "This could mean local-only beads exist. Aborting — please review manually."
    warn "If safe, run: cd $DOLT_DB && dolt reset --hard remotes/origin/main"
    exit 1
  fi

  info "Fresh local DB ($LOCAL_COMMITS commits, schema-only). Resetting to DoltHub history..."
  # Reset WHILE server is running — this is critical to avoid journal corruption
  (cd "$DOLT_DB" && dolt reset --hard remotes/origin/main) || err "dolt reset --hard failed"

  # After hard reset, journal.idx becomes stale (HEAD changed but journal wasn't rebuilt).
  # Delete it so dolt rebuilds a clean journal on next start.
  find "$PROJECT_ROOT/.beads/dolt" -name "journal.idx" -delete 2>/dev/null || true

else
  # Shared history — normal pull
  info "Pulling from DoltHub (shared history)..."
  PULL_OUT=$((cd "$DOLT_DB" && dolt pull origin main 2>&1) || true)
  if echo "$PULL_OUT" | grep -qi "conflict"; then
    warn "Merge conflicts detected — resolve manually."
    echo "$PULL_OUT"
    exit 1
  fi
fi

# ── 9. restart server to pick up new HEAD ────────────────────────────────────
info "Restarting bd server to pick up new HEAD..."
bd dolt stop 2>/dev/null || true
sleep 2
bd dolt start 2>/dev/null || err "Server failed to restart after sync"
sleep 3

# ── 10. verify ───────────────────────────────────────────────────────────────
HEAD_HASH=$(cd "$DOLT_DB" && dolt log --oneline -n 1 2>/dev/null | awk '{print substr($1,1,8)}' || echo "unknown")
HEAD_MSG=$(cd "$DOLT_DB" && dolt log --oneline -n 1 2>/dev/null | cut -d' ' -f2- || echo "")
BEAD_COUNT=$(bd list 2>/dev/null | grep -c "^[│├└]" || echo "0")

ok "Dolt sync complete"
echo "   Remote : $DOLT_REMOTE"
echo "   HEAD   : $HEAD_HASH ($HEAD_MSG)"
echo "   Beads  : $BEAD_COUNT issues"
