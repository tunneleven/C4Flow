#!/usr/bin/env bash
# c4flow init — install and configure dependencies for C4Flow workflow
# Usage: scripts/init.sh [--skip-beads] [--prefix PREFIX]
#
# Installs Dolt + Beads, runs bd init, verifies connectivity.
# Designed to complete in under 30 seconds.

set -euo pipefail

# Colors (disable if not a terminal)
if [ -t 1 ]; then
  RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m' BLUE='\033[0;34m' NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

info()  { echo -e "${BLUE}[c4flow]${NC} $*"; }
ok()    { echo -e "${GREEN}[c4flow]${NC} $*"; }
warn()  { echo -e "${YELLOW}[c4flow]${NC} $*"; }
err()   { echo -e "${RED}[c4flow]${NC} $*" >&2; }

# Run a command with a timeout (default 15s)
run_with_timeout() {
  local timeout="${1:-15}"
  shift
  if command -v timeout &>/dev/null; then
    timeout "$timeout" "$@" 2>&1
  else
    # macOS fallback: use perl
    perl -e "alarm $timeout; exec @ARGV" -- "$@" 2>&1
  fi
}

# Parse args
SKIP_BEADS=false
PREFIX=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-beads) SKIP_BEADS=true; shift ;;
    --prefix)     PREFIX="$2"; shift 2 ;;
    --prefix=*)   PREFIX="${1#*=}"; shift ;;
    -h|--help)
      echo "Usage: scripts/init.sh [--skip-beads] [--prefix PREFIX]"
      echo ""
      echo "Options:"
      echo "  --skip-beads    Skip Beads (bd) installation"
      echo "  --prefix NAME   Set beads issue prefix (default: directory name)"
      echo "  -h, --help      Show this help"
      exit 0
      ;;
    *) err "Unknown option: $1"; exit 1 ;;
  esac
done

has() { command -v "$1" &>/dev/null; }

# ─── Git ──────────────────────────────────────────────────────────────────────

check_git() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    err "Not inside a git repository. Run from a git project root."
    exit 1
  fi
  ok "git: $(git --version)"
}

# ─── Dolt ─────────────────────────────────────────────────────────────────────

install_dolt() {
  if has dolt; then
    ok "dolt: $(dolt version 2>&1 | head -1)"
    return 0
  fi

  info "Installing Dolt..."
  if has brew; then
    brew install dolt
  elif has curl; then
    sudo bash -c 'curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash'
  else
    err "Cannot install Dolt: no brew or curl. Install manually: https://docs.dolthub.com/introduction/installation"
    exit 1
  fi

  has dolt && ok "dolt: $(dolt version 2>&1 | head -1)" || { err "Dolt installation failed"; exit 1; }
}

# ─── Beads (bd) ───────────────────────────────────────────────────────────────

install_beads() {
  if has bd; then
    ok "bd: $(bd --version 2>&1)"
    return 0
  fi

  info "Installing Beads (bd)..."
  if has curl; then
    curl -sSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash
  elif has npm; then
    npm install -g @beads/bd
  else
    err "Cannot install Beads: no curl or npm. Install manually: https://github.com/steveyegge/beads"
    exit 1
  fi

  export PATH="$HOME/.local/bin:$HOME/.beads/bin:$PATH"
  has bd && ok "bd: $(bd --version 2>&1)" || { err "Beads installation failed"; exit 1; }
}

# ─── bd init + Dolt server ────────────────────────────────────────────────────

init_beads() {
  # Already initialized?
  if [ -d ".beads" ] && [ -f ".beads/metadata.json" ]; then
    ok ".beads/ already initialized"
    ensure_dolt_server
    return 0
  fi

  info "Running bd init..."

  local init_args=()
  [ -n "$PREFIX" ] && init_args+=(--prefix "$PREFIX")

  # bd init with timeout — it can hang if Dolt server has issues
  if run_with_timeout 30 bd init "${init_args[@]}"; then
    ok "bd init completed"
  else
    local exit_code=$?
    if [ $exit_code -eq 124 ]; then
      warn "bd init timed out (30s). Continuing with manual setup..."
    else
      warn "bd init exited with code $exit_code. Continuing..."
    fi
  fi

  # Ensure .beads/ was created
  if [ ! -d ".beads" ]; then
    err ".beads/ directory was not created. bd init may have failed."
    exit 1
  fi

  ensure_dolt_server
}

ensure_dolt_server() {
  # Check if Dolt server is already responding
  if check_dolt_connection; then
    ok "Dolt server: connected"
    return 0
  fi

  info "Dolt server not responding. Starting..."

  # Kill any stale server
  if [ -f ".beads/dolt-server.pid" ]; then
    local old_pid
    old_pid=$(cat .beads/dolt-server.pid 2>/dev/null || true)
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
      info "Killing stale Dolt server (PID $old_pid)..."
      kill "$old_pid" 2>/dev/null || true
      sleep 1
    fi
    rm -f .beads/dolt-server.pid .beads/dolt-server.port .beads/dolt-server.lock 2>/dev/null || true
  fi

  # Find a free port
  local port
  port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1]); s.close()' 2>/dev/null || echo "3307")

  # Start Dolt server from .beads/dolt directory
  if [ -d ".beads/dolt" ]; then
    (cd .beads/dolt && dolt sql-server --host 127.0.0.1 --port "$port" &>/dev/null &)
    echo $! > .beads/dolt-server.pid
    echo "$port" > .beads/dolt-server.port

    # Wait for server to be ready (max 5s)
    local retries=10
    while [ $retries -gt 0 ]; do
      if check_dolt_connection "$port"; then
        ok "Dolt server: started on port $port"
        return 0
      fi
      sleep 0.5
      retries=$((retries - 1))
    done
  fi

  warn "Dolt server could not be started. Beads will work in degraded mode."
  warn "You can start it manually: cd .beads/dolt && dolt sql-server"
}

check_dolt_connection() {
  local port="${1:-}"

  # Try reading port from .beads if not provided
  if [ -z "$port" ] && [ -f ".beads/dolt-server.port" ]; then
    port=$(cat .beads/dolt-server.port 2>/dev/null || true)
  fi

  [ -z "$port" ] && return 1

  # Quick SQL check with 3s timeout
  if run_with_timeout 3 dolt sql --host 127.0.0.1 --port "$port" --user root -q "SELECT 1" &>/dev/null; then
    return 0
  fi
  return 1
}

# ─── Verify (fast, no bd doctor) ─────────────────────────────────────────────

verify() {
  echo ""
  info "Verification:"

  local all_ok=true

  has git  && echo -e "  ${GREEN}✓${NC} git"  || { echo -e "  ${RED}✗${NC} git"; all_ok=false; }
  has dolt && echo -e "  ${GREEN}✓${NC} dolt" || { echo -e "  ${RED}✗${NC} dolt"; all_ok=false; }

  if [ "$SKIP_BEADS" = true ]; then
    echo -e "  ${YELLOW}⊘${NC} bd (skipped)"
    echo -e "  ${YELLOW}⊘${NC} .beads/ (skipped)"
  else
    has bd && echo -e "  ${GREEN}✓${NC} bd" || { echo -e "  ${RED}✗${NC} bd"; all_ok=false; }
    [ -d ".beads" ] && echo -e "  ${GREEN}✓${NC} .beads/" || { echo -e "  ${RED}✗${NC} .beads/"; all_ok=false; }

    # Quick bd connectivity test (3s timeout, don't use bd doctor)
    if has bd && [ -d ".beads" ]; then
      if run_with_timeout 5 bd list --json &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} bd connected to Dolt"
      else
        echo -e "  ${YELLOW}⚠${NC} bd cannot reach Dolt (tasks will work after server starts)"
      fi
    fi
  fi

  echo ""
  if [ "$all_ok" = true ]; then
    ok "Ready! Run /c4flow to start a workflow."
  else
    warn "Some checks failed. See above."
    return 1
  fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
  echo ""
  echo -e "${BLUE}━━━ C4Flow Init ━━━${NC}"
  echo ""

  check_git

  if [ "$SKIP_BEADS" = false ]; then
    install_dolt
    install_beads
    init_beads
  else
    info "Skipping Beads (--skip-beads)"
  fi

  verify
}

main "$@"
